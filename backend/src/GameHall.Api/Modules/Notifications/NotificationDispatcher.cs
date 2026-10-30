using System.Text.Json;
using Dapper;
using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Infrastructure.Push;
using GameHall.Api.Modules.Teams;
using Npgsql;
using Pair = (System.Guid Id, string Team, string Who);

namespace GameHall.Api.Modules.Notifications;

/// <summary>
/// Entrega as notificações fora da app: push (tipos em <see cref="NotificationTypes.PushTypes"/>) e email (tipos em
/// <see cref="NotificationTypes.EmailTypes"/>). Quem cria a notificação não sabe nada disto: grava-a na tabela e este
/// serviço trata do resto, de 15 em 15 segundos. Cada notificação é reclamada (pushed_at / emailed_at) antes do envio:
/// no pior caso uma falha perde um aviso, nunca o repete. Avisos com mais de 1 hora já não são enviados (um push
/// "a começar" atrasado só confunde). As votações nunca saem da app.
/// </summary>
public sealed class NotificationDispatcher(
    NpgsqlDataSource db, IPushSender push, IEmailSender email, IConfiguration config, ILogger<NotificationDispatcher> log)
    : BackgroundService
{
    public const int MaxAgeMinutes = 60;
    private const int Batch = 200;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private sealed class Claimed
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string Type { get; set; } = "";
        public string Data { get; set; } = "{}";
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!config.GetValue("Lifecycle:Enabled", true))
        {
            return;
        }

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(15));
        do
        {
            try
            {
                await RunOnceAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Falha ao entregar notificações");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    /// <summary>Uma volta (também usada pelos testes). Devolve quantos push e emails foram tentados.</summary>
    public async Task<(int Pushes, int Emails)> RunOnceAsync(CancellationToken ct) =>
        (await DispatchPushAsync(ct), await DispatchEmailAsync(ct));

    private async Task<List<Claimed>> ClaimAsync(string column, string[] types, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        // O que não é deste canal ou já é antigo fica marcado como "tratado" sem enviar.
        return (await c.QueryAsync<Claimed>(new CommandDefinition(
            $"""
            WITH skipped AS (
                UPDATE notifications SET {column} = now()
                WHERE {column} IS NULL AND (NOT (type = ANY(@Types)) OR created_at < now() - make_interval(mins => @MaxAge))
                RETURNING 1
            ),
            picked AS (
                SELECT id FROM notifications
                WHERE {column} IS NULL AND type = ANY(@Types) AND created_at >= now() - make_interval(mins => @MaxAge)
                ORDER BY created_at LIMIT {Batch}
                FOR UPDATE SKIP LOCKED
            )
            UPDATE notifications n SET {column} = now()
            FROM picked WHERE n.id = picked.id
            RETURNING n.id, n.user_id, n.type, n.data::text AS data
            """,
            new { Types = types, MaxAge = MaxAgeMinutes }, cancellationToken: ct))).ToList();
    }

    // ======================= Push =======================

    private async Task<int> DispatchPushAsync(CancellationToken ct)
    {
        var rows = await ClaimAsync("pushed_at", NotificationTypes.PushTypes, ct);
        if (rows.Count == 0)
        {
            return 0;
        }

        await using var c = await db.OpenConnectionAsync(ct);
        var inviteIds = rows.Where(r => r.Type == NotificationTypes.TeamInvite).Select(r => RefId(r, "inviteId")).OfType<Guid>().ToArray();
        var requestIds = rows.Where(r => r.Type == NotificationTypes.JoinRequest).Select(r => RefId(r, "requestId")).OfType<Guid>().ToArray();
        var invites = inviteIds.Length == 0 ? new Dictionary<Guid, Pair>() : (await c.QueryAsync<Pair>(new CommandDefinition(
            """
            SELECT i.id, t.name, u.display_name FROM team_invites i
            JOIN teams t ON t.id = i.team_id JOIN users u ON u.id = i.invited_by
            WHERE i.id = ANY(@Ids) AND i.status = 'pending'
            """, new { Ids = inviteIds }, cancellationToken: ct))).ToDictionary(x => x.Id);
        var requests = requestIds.Length == 0 ? new Dictionary<Guid, Pair>() : (await c.QueryAsync<Pair>(new CommandDefinition(
            """
            SELECT r.id, t.name, u.display_name FROM join_requests r
            JOIN teams t ON t.id = r.team_id JOIN users u ON u.id = r.user_id
            WHERE r.id = ANY(@Ids) AND r.status = 'pending'
            """, new { Ids = requestIds }, cancellationToken: ct))).ToDictionary(x => x.Id);

        var sent = 0;
        foreach (var r in rows)
        {
            var message = Compose(r, invites, requests);
            if (message is null)
            {
                continue;   // convite/pedido já respondido ou apagado: não vale a pena avisar
            }

            var tokens = (await c.QueryAsync<string>(new CommandDefinition(
                """
                SELECT d.token FROM device_tokens d JOIN users u ON u.id = d.user_id
                WHERE d.user_id = @U AND u.push_enabled
                """, new { U = r.UserId }, cancellationToken: ct))).ToList();
            if (tokens.Count == 0)
            {
                continue;
            }

            try
            {
                var dead = await push.SendAsync(message, tokens, ct);
                if (dead.Count > 0)
                {
                    await c.ExecuteAsync(new CommandDefinition(
                        "DELETE FROM device_tokens WHERE token = ANY(@T)", new { T = dead.ToArray() }, cancellationToken: ct));
                }

                sent++;
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogWarning(ex, "Falha ao enviar push {Id} ({Type})", r.Id, r.Type);
            }
        }

        return sent;
    }

    private static PushMessage? Compose(
        Claimed r, Dictionary<Guid, Pair> invites, Dictionary<Guid, Pair> requests)
    {
        var data = new Dictionary<string, string> { ["type"] = r.Type, ["notificationId"] = r.Id.ToString() };
        switch (r.Type)
        {
            case NotificationTypes.TeamInvite:
                return RefId(r, "inviteId") is { } iid && invites.TryGetValue(iid, out var i)
                    ? new PushMessage(PushTexts.InviteTitle, PushTexts.Invite(i.Who, i.Team), data)
                    : null;
            case NotificationTypes.JoinRequest:
                return RefId(r, "requestId") is { } rid && requests.TryGetValue(rid, out var q)
                    ? new PushMessage(PushTexts.RequestTitle, PushTexts.Request(q.Who, q.Team), data)
                    : null;
            default:
                var (title, body) = TitleAndMessage(r.Data);
                return title is null || body is null ? null : new PushMessage(title, body, data);
        }
    }

    // ======================= Email =======================

    private sealed class EmailTarget
    {
        public Guid Id { get; set; }
        public string Type { get; set; } = "";
        public string Data { get; set; } = "{}";
        public string Email { get; set; } = "";
        public string DisplayName { get; set; } = "";
        public bool TeamUnconfirmed { get; set; }
    }

    private async Task<int> DispatchEmailAsync(CancellationToken ct)
    {
        var rows = await ClaimAsync("emailed_at", NotificationTypes.EmailTypes, ct);
        if (rows.Count == 0)
        {
            return 0;
        }

        await using var c = await db.OpenConnectionAsync(ct);
        var sent = 0;
        foreach (var r in rows)
        {
            var t = await c.QueryFirstOrDefaultAsync<EmailTarget>(new CommandDefinition(
                """
                SELECT n.id, n.type, n.data::text AS data, u.email, u.display_name,
                       EXISTS (SELECT 1 FROM teams t WHERE t.id = (n.data->>'teamId')::uuid AND t.confirmed_at IS NULL) AS team_unconfirmed
                FROM notifications n JOIN users u ON u.id = n.user_id
                WHERE n.id = @Id
                """, new { r.Id }, cancellationToken: ct));
            if (t is null)
            {
                continue;
            }

            // "Falta 5 minutos": só enquanto a equipa ainda não está confirmada (ou seja, ainda falta alguém pagar).
            if (t.Type == NotificationTypes.ReservationExpiring && !t.TeamUnconfirmed)
            {
                continue;
            }

            var (title, message) = TitleAndMessage(t.Data);
            var teamName = TeamName(t.Data);
            if (title is null || message is null || teamName is null)
            {
                continue;
            }

            try
            {
                var (subject, body) = TeamEmails.FromNotification(t.DisplayName, title, teamName, message);
                await email.SendAsync(t.Email, subject, body, ct);
                sent++;
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogWarning(ex, "Falha ao enviar email de aviso {Id} ({Type})", t.Id, t.Type);
            }
        }

        return sent;
    }

    // ======================= JSON =======================

    private static Guid? RefId(Claimed r, string key)
    {
        try
        {
            using var doc = JsonDocument.Parse(r.Data);
            return doc.RootElement.TryGetProperty(key, out var v) && Guid.TryParse(v.GetString(), out var g) ? g : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static (string? Title, string? Message) TitleAndMessage(string data)
    {
        try
        {
            using var doc = JsonDocument.Parse(data);
            var root = doc.RootElement;
            return (
                root.TryGetProperty("title", out var t) ? t.GetString() : null,
                root.TryGetProperty("message", out var m) ? m.GetString() : null);
        }
        catch (JsonException)
        {
            return (null, null);
        }
    }

    private static string? TeamName(string data)
    {
        try
        {
            using var doc = JsonDocument.Parse(data);
            return doc.RootElement.TryGetProperty("teamName", out var t) ? t.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
