using System.Data;
using System.Text.Json;
using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Notifications;

/// <summary>SQL das notificações. A criação recebe a ligação/transação para ser atómica com o que a gerou.</summary>
public sealed class NotificationStore(NpgsqlDataSource db)
{
    public const int MaxItems = 50;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    // Convites e pedidos só contam/aparecem enquanto existirem (se a equipa for eliminada, desaparecem com ela).
    // Os eventos de equipa (fechada, vaga reservada, confirmada) guardam o texto e ficam sempre.
    private const string Visible =
        """
        n.user_id = @U AND (
          n.type NOT IN ('team_invite', 'join_request')
          OR (n.type = 'team_invite' AND EXISTS (SELECT 1 FROM team_invites i WHERE i.id = (n.data->>'inviteId')::uuid))
          OR (n.type = 'join_request' AND EXISTS (SELECT 1 FROM join_requests r WHERE r.id = (n.data->>'requestId')::uuid))
        )
        """;

    public static Task<int> InsertTeamInviteAsync(IDbConnection c, IDbTransaction tx, Guid userId, Guid inviteId) =>
        c.ExecuteAsync(
            """
            INSERT INTO notifications (id, user_id, type, data)
            VALUES (@Id, @U, 'team_invite', jsonb_build_object('inviteId', @Invite::text))
            """,
            new { Id = Guid.NewGuid(), U = userId, Invite = inviteId }, tx);

    /// <summary>O líder recebe o pedido para entrar na equipa (com aceitar/recusar).</summary>
    public static Task<int> InsertJoinRequestAsync(IDbConnection c, IDbTransaction tx, Guid hostId, Guid requestId) =>
        c.ExecuteAsync(
            """
            INSERT INTO notifications (id, user_id, type, data)
            VALUES (@Id, @U, 'join_request', jsonb_build_object('requestId', @Request::text))
            """,
            new { Id = Guid.NewGuid(), U = hostId, Request = requestId }, tx);

    /// <summary>Evento de equipa com o texto já composto (type em <see cref="NotificationTypes.EventTypes"/>).</summary>
    /// <param name="deliver">false = só aparece na app (marca já como entregue: sem push nem email).</param>
    public static Task<int> InsertTeamEventAsync(
        IDbConnection c, IDbTransaction tx, Guid userId, string type, TeamEventData data, bool deliver = true) =>
        c.ExecuteAsync(
            """
            INSERT INTO notifications (id, user_id, type, data, pushed_at, emailed_at)
            VALUES (@Id, @U, @Type, @Data::jsonb, CASE WHEN @Deliver THEN NULL ELSE now() END,
                    CASE WHEN @Deliver THEN NULL ELSE now() END)
            """,
            new { Id = Guid.NewGuid(), U = userId, Type = type, Data = JsonSerializer.Serialize(data, Json), Deliver = deliver }, tx);

    /// <summary>Aviso sobre um torneio/jogo (votação, jogo a começar, jogo alterado). Type em <see cref="NotificationTypes.InfoTypes"/>.</summary>
    public static Task<int> InsertInfoAsync(IDbConnection c, IDbTransaction? tx, Guid userId, string type, InfoEventData data) =>
        c.ExecuteAsync(
            "INSERT INTO notifications (id, user_id, type, data) VALUES (@Id, @U, @Type, @Data::jsonb)",
            new { Id = Guid.NewGuid(), U = userId, Type = type, Data = JsonSerializer.Serialize(data, Json) }, tx);

    public async Task<IReadOnlyList<NotificationDto>> ListAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var rows = (await conn.QueryAsync<RawNotificationRow>(new CommandDefinition(
            $"""
            SELECT n.id, n.type, n.created_at, (n.read_at IS NOT NULL) AS is_read, n.data::text AS data
            FROM notifications n
            WHERE {Visible}
            ORDER BY n.created_at DESC
            LIMIT {MaxItems}
            """,
            new { U = userId }, cancellationToken: ct))).ToList();

        var inviteIds = rows.Where(r => r.Type == NotificationTypes.TeamInvite).Select(r => RefId(r, "inviteId")).OfType<Guid>().ToArray();
        var requestIds = rows.Where(r => r.Type == NotificationTypes.JoinRequest).Select(r => RefId(r, "requestId")).OfType<Guid>().ToArray();
        var eventTeamIds = rows.Where(r => NotificationTypes.EventTypes.Contains(r.Type))
            .Select(r => Event(r)?.TeamId).OfType<Guid>().Distinct().ToArray();

        var invites = inviteIds.Length == 0
            ? new Dictionary<Guid, InviteInfoRow>()
            : (await conn.QueryAsync<InviteInfoRow>(new CommandDefinition(
                """
                SELECT i.id AS invite_id, i.status AS invite_status, t.id AS team_id, t.name AS team_name, t.color_hex,
                       tr.id AS tournament_id, tr.name AS tournament_name,
                       ub.display_name AS invited_by_name, ub.username AS invited_by_username
                FROM team_invites i
                JOIN teams t ON t.id = i.team_id
                JOIN tournaments tr ON tr.id = t.tournament_id
                JOIN users ub ON ub.id = i.invited_by
                WHERE i.id = ANY(@Ids)
                """,
                new { Ids = inviteIds }, cancellationToken: ct))).ToDictionary(r => r.InviteId);

        var requests = requestIds.Length == 0
            ? new Dictionary<Guid, RequestInfoRow>()
            : (await conn.QueryAsync<RequestInfoRow>(new CommandDefinition(
                """
                SELECT r.id AS request_id, r.status AS request_status, t.id AS team_id, t.name AS team_name, t.color_hex,
                       tr.id AS tournament_id, tr.name AS tournament_name,
                       u.display_name AS requester_name, u.username AS requester_username
                FROM join_requests r
                JOIN teams t ON t.id = r.team_id
                JOIN tournaments tr ON tr.id = t.tournament_id
                JOIN users u ON u.id = r.user_id
                WHERE r.id = ANY(@Ids)
                """,
                new { Ids = requestIds }, cancellationToken: ct))).ToDictionary(r => r.RequestId);

        var existingTeams = eventTeamIds.Length == 0
            ? new HashSet<Guid>()
            : (await conn.QueryAsync<Guid>(new CommandDefinition(
                "SELECT id FROM teams WHERE id = ANY(@Ids)", new { Ids = eventTeamIds }, cancellationToken: ct))).ToHashSet();

        var infoTournamentIds = rows.Where(r => NotificationTypes.InfoTypes.Contains(r.Type))
            .Select(r => Info(r)?.TournamentId).OfType<Guid>().Distinct().ToArray();
        var existingTournaments = infoTournamentIds.Length == 0
            ? new HashSet<Guid>()
            : (await conn.QueryAsync<Guid>(new CommandDefinition(
                "SELECT id FROM tournaments WHERE id = ANY(@Ids)", new { Ids = infoTournamentIds }, cancellationToken: ct))).ToHashSet();

        var items = new List<NotificationDto>();
        foreach (var r in rows)
        {
            switch (r.Type)
            {
                case NotificationTypes.TeamInvite
                    when RefId(r, "inviteId") is { } iid && invites.TryGetValue(iid, out var i):
                    items.Add(new NotificationDto(
                        r.Id, r.Type, r.CreatedAt, r.IsRead,
                        new TeamInviteDto(
                            i.InviteId, i.InviteStatus, i.TeamId, i.TeamName, i.ColorHex,
                            i.TournamentId, i.TournamentName, i.InvitedByName, i.InvitedByUsername)));
                    break;
                case NotificationTypes.JoinRequest
                    when RefId(r, "requestId") is { } rid && requests.TryGetValue(rid, out var q):
                    items.Add(new NotificationDto(
                        r.Id, r.Type, r.CreatedAt, r.IsRead, null,
                        new JoinRequestDto(
                            q.RequestId, q.RequestStatus, q.TeamId, q.TeamName, q.ColorHex,
                            q.TournamentId, q.TournamentName, q.RequesterName, q.RequesterUsername)));
                    break;
                default:
                    if (NotificationTypes.InfoTypes.Contains(r.Type) && Info(r) is { } n)
                    {
                        items.Add(new NotificationDto(
                            r.Id, r.Type, r.CreatedAt, r.IsRead, null, null, null,
                            new InfoEventDto(
                                n.TournamentId, n.TournamentName, n.GameId, n.Title, n.Message,
                                existingTournaments.Contains(n.TournamentId))));
                    }
                    else if (NotificationTypes.EventTypes.Contains(r.Type) && Event(r) is { } e)
                    {
                        items.Add(new NotificationDto(
                            r.Id, r.Type, r.CreatedAt, r.IsRead, null, null,
                            new TeamEventDto(
                                e.TeamId, e.TeamName, e.ColorHex, e.TournamentName, e.Title, e.Message,
                                existingTeams.Contains(e.TeamId))));
                    }

                    break;
            }
        }

        return items;
    }

    public async Task<int> UnreadCountAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            $"SELECT count(*)::int FROM notifications n WHERE {Visible} AND n.read_at IS NULL",
            new { U = userId }, cancellationToken: ct));
    }

    /// <summary>Apaga uma notificação do utilizador (só as dele). Devolve false se não existe.</summary>
    public async Task<bool> DeleteAsync(Guid userId, Guid notificationId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM notifications WHERE id = @Id AND user_id = @U",
            new { Id = notificationId, U = userId }, cancellationToken: ct)) > 0;
    }

    /// <summary>"Limpar tudo": apaga todas as notificações do utilizador.</summary>
    public async Task<int> DeleteAllAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM notifications WHERE user_id = @U", new { U = userId }, cancellationToken: ct));
    }

    public async Task MarkAllReadAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE notifications SET read_at = now() WHERE user_id = @U AND read_at IS NULL",
            new { U = userId }, cancellationToken: ct));
    }

    private static Guid? RefId(RawNotificationRow r, string key)
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

    private static InfoEventData? Info(RawNotificationRow r)
    {
        try
        {
            return JsonSerializer.Deserialize<InfoEventData>(r.Data, Json);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static TeamEventData? Event(RawNotificationRow r)
    {
        try
        {
            return JsonSerializer.Deserialize<TeamEventData>(r.Data, Json);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
