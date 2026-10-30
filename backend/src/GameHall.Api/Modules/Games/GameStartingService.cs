using Npgsql;

namespace GameHall.Api.Modules.Games;

/// <summary>
/// "Jogo a começar": cerca de 30 minutos antes da hora, avisa os jogadores das duas equipas (uma só vez por hora
/// marcada: se a hora mudar, o trigger da base de dados limpa start_notified_at e o aviso volta a ser possível).
/// O aviso "marcado / alterado / adiado / cancelado" nasce no trigger gh_game_change_notify (migração 019).
/// O push sai do NotificationDispatcher.
/// </summary>
public sealed class GameStartingService(NpgsqlDataSource db, IConfiguration config, ILogger<GameStartingService> log)
    : BackgroundService
{
    public const int MinutesBefore = 30;

    private const string Sql =
        """
        WITH due AS (
            UPDATE games g SET start_notified_at = now()
            WHERE g.start_notified_at IS NULL AND g.status = 'scheduled'
              AND g.scheduled_at > now() AND g.scheduled_at <= now() + make_interval(mins => @Minutes)
            RETURNING g.id, g.tournament_id, g.home_team_id, g.away_team_id, g.scheduled_at, g.field_name
        )
        INSERT INTO notifications (id, user_id, type, data)
        SELECT gen_random_uuid(), m.user_id, 'game_starting',
               jsonb_build_object(
                   'tournamentId', d.tournament_id, 'tournamentName', tr.name, 'gameId', d.id,
                   'title', 'Jogo a começar',
                   'message', COALESCE(h.name, 'A definir') || ' vs ' || COALESCE(a.name, 'A definir')
                              || ' começa às ' || to_char(d.scheduled_at AT TIME ZONE 'Europe/Lisbon', 'HH24:MI')
                              || COALESCE(' · ' || d.field_name, '') || '.')
        FROM due d
        JOIN tournaments tr ON tr.id = d.tournament_id
        LEFT JOIN teams h ON h.id = d.home_team_id
        LEFT JOIN teams a ON a.id = d.away_team_id
        JOIN team_members m ON m.team_id IN (d.home_team_id, d.away_team_id)
        JOIN teams t ON t.id = m.team_id AND NOT t.is_demo
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
                log.LogError(ex, "Falha ao criar os avisos de jogo a começar");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    /// <summary>Uma volta (também usada pelos testes). Devolve quantos avisos criou.</summary>
    public async Task<int> RunOnceAsync(CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var cmd = new NpgsqlCommand(Sql, conn);
        cmd.Parameters.AddWithValue("Minutes", MinutesBefore);
        return await cmd.ExecuteNonQueryAsync(ct);
    }
}
