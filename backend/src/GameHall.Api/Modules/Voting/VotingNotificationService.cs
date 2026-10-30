using Dapper;
using GameHall.Api.Modules.Notifications;
using GameHall.Api.Modules.Tournaments;
using Npgsql;

namespace GameHall.Api.Modules.Voting;

/// <summary>
/// Avisos de votação, só na app (nunca push nem email): "Votação aberta" e "Segunda ronda - Votação aberta" para
/// quem participou no torneio, e "Resultados da votação" (com os vencedores) para participantes e quem votou.
/// Minuto a minuto; cada aviso sai uma só vez (voting_rounds.opened_notified_at, tournaments.voting_results_notified_at).
/// </summary>
public sealed class VotingNotificationService(
    NpgsqlDataSource db, IServiceScopeFactory scopes, IConfiguration config, ILogger<VotingNotificationService> log)
    : BackgroundService
{
    private const string OpenedSql =
        """
        WITH r AS (
            UPDATE voting_rounds SET opened_notified_at = now()
            WHERE opened_notified_at IS NULL AND opened_at <= now()
            RETURNING tournament_id, round_number, closes_at
        ),
        live AS (SELECT * FROM r WHERE closes_at > now())
        INSERT INTO notifications (id, user_id, type, data)
        SELECT gen_random_uuid(), p.user_id,
               CASE WHEN l.round_number = 1 THEN 'voting_opened' ELSE 'voting_second_round' END,
               jsonb_build_object(
                   'tournamentId', tr.id, 'tournamentName', tr.name,
                   'title', CASE WHEN l.round_number = 1 THEN 'Votação aberta' ELSE 'Segunda ronda - Votação aberta' END,
                   'message', CASE WHEN l.round_number = 1
                       THEN 'Já podes votar no melhor jogador e no melhor guarda-redes de ' || tr.name
                       ELSE 'Houve empate em ' || tr.name || ': abriu a segunda ronda, só com os empatados'
                       END || '. A votação fecha às ' || to_char(l.closes_at AT TIME ZONE 'Europe/Lisbon', 'HH24:MI') || '.')
        FROM live l
        JOIN tournaments tr ON tr.id = l.tournament_id
        CROSS JOIN LATERAL (
            SELECT DISTINCT m.user_id FROM team_members m JOIN teams t ON t.id = m.team_id
            WHERE m.tournament_id = l.tournament_id AND t.confirmed_at IS NOT NULL
        ) p
        """;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!config.GetValue("Lifecycle:Enabled", true))
        {
            return;
        }

        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
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
                log.LogError(ex, "Falha ao criar os avisos de votação");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    /// <summary>Uma volta (também usada pelos testes).</summary>
    public async Task RunOnceAsync(CancellationToken ct)
    {
        await using (var c = await db.OpenConnectionAsync(ct))
        {
            await c.ExecuteAsync(new CommandDefinition(OpenedSql, cancellationToken: ct));
        }

        await PublishResultsAsync(ct);
    }

    private async Task PublishResultsAsync(CancellationToken ct)
    {
        Guid[] candidates;
        await using (var c = await db.OpenConnectionAsync(ct))
        {
            candidates = (await c.QueryAsync<Guid>(new CommandDefinition(
                """
                SELECT t.id FROM tournaments t
                WHERE t.status = 'finished' AND t.voting_results_notified_at IS NULL
                  AND EXISTS (SELECT 1 FROM voting_rounds r WHERE r.tournament_id = t.id)
                  AND NOT EXISTS (SELECT 1 FROM voting_rounds r WHERE r.tournament_id = t.id AND r.closes_at > now())
                """, cancellationToken: ct))).ToArray();
        }

        if (candidates.Length == 0)
        {
            return;
        }

        await using var scope = scopes.CreateAsyncScope();
        var voting = scope.ServiceProvider.GetRequiredService<VotingService>();
        var tournaments = scope.ServiceProvider.GetRequiredService<TournamentStore>();
        foreach (var id in candidates)
        {
            var t = await tournaments.FindAsync(id, ct);
            if (t is null)
            {
                continue;
            }

            var winners = await voting.FinalWinnersAsync(t, ct);
            if (winners is null)
            {
                continue;   // ainda falta decidir (empate que o gestor ainda pode desempatar)
            }

            var (best, gk) = winners.Value;
            if (best.Count == 0 && gk.Count == 0)
            {
                await MarkAsync(id, ct);   // ninguém votou: não há nada para anunciar
                continue;
            }

            var data = new InfoEventData(t.Id, t.Name, null, VotingTexts.ResultsTitle, VotingTexts.Results(t.Name, best, gk));
            await using var conn = await db.OpenConnectionAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var users = (await conn.QueryAsync<Guid>(
                """
                SELECT m.user_id FROM team_members m JOIN teams x ON x.id = m.team_id
                WHERE m.tournament_id = @T AND x.confirmed_at IS NOT NULL
                UNION
                SELECT v.voter_id FROM votes v JOIN voting_rounds r ON r.id = v.round_id WHERE r.tournament_id = @T
                """, new { T = id }, tx)).ToList();
            foreach (var u in users)
            {
                await NotificationStore.InsertInfoAsync(conn, tx, u, NotificationTypes.VotingResults, data);
            }

            await conn.ExecuteAsync("UPDATE tournaments SET voting_results_notified_at = now() WHERE id = @T", new { T = id }, tx);
            await tx.CommitAsync(ct);
        }
    }

    private async Task MarkAsync(Guid tournamentId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        await c.ExecuteAsync(new CommandDefinition(
            "UPDATE tournaments SET voting_results_notified_at = now() WHERE id = @T", new { T = tournamentId }, cancellationToken: ct));
    }
}
