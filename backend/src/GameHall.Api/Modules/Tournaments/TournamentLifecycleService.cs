using Npgsql;

namespace GameHall.Api.Modules.Tournaments;

/// <summary>
/// Faz avançar o estado dos torneios com base nos jogos (minuto a minuto, e ao arranque):
///   * "inscrições fechadas" -> "a decorrer" quando chega a hora do primeiro jogo (ou um jogo já começou);
///   * "a decorrer" -> "terminado" quando o resultado do último jogo é publicado (todos os jogos terminados
///     ou cancelados e pelo menos um terminado). finished_at = quando o último jogo foi atualizado e
///     voting_window_hours = a janela atual dos admins (a partir daqui o gestor tem esse tempo para abrir votações).
/// O fecho das inscrições faz-se em RegistrationLifecycleService.
/// </summary>
public sealed class TournamentLifecycleService(
    NpgsqlDataSource db, IConfiguration config, ILogger<TournamentLifecycleService> log) : BackgroundService
{
    private const string Sql =
        """
        WITH started AS (
            UPDATE tournaments t
            SET status = 'ongoing', updated_at = now()
            WHERE t.status = 'registration_closed'
              AND EXISTS (SELECT 1 FROM games g
                          WHERE g.tournament_id = t.id AND g.status <> 'cancelled'
                            AND (g.status IN ('running', 'finished') OR g.scheduled_at <= now()))
            RETURNING 1
        ),
        done AS (
            UPDATE tournaments t
            SET status = 'finished', updated_at = now(),
                finished_at = COALESCE(
                    (SELECT max(g.updated_at) FROM games g WHERE g.tournament_id = t.id AND g.status = 'finished'), now()),
                voting_window_hours = COALESCE(
                    (SELECT value::int FROM platform_settings WHERE key = 'voting_window_hours'), 6)
            WHERE t.status = 'ongoing'
              AND EXISTS (SELECT 1 FROM games g WHERE g.tournament_id = t.id AND g.status = 'finished')
              AND NOT EXISTS (SELECT 1 FROM games g
                              WHERE g.tournament_id = t.id AND g.status IN ('scheduled', 'running', 'postponed'))
            RETURNING 1
        )
        SELECT (SELECT count(*) FROM started)::int AS started, (SELECT count(*) FROM done)::int AS finished
        """;

    /// <summary>Uma volta (também usada pelos testes). Devolve (passaram a decorrer, terminaram).</summary>
    public async Task<(int Started, int Finished)> RunOnceAsync(CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var cmd = new NpgsqlCommand(Sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        await reader.ReadAsync(ct);
        return (reader.GetInt32(0), reader.GetInt32(1));
    }

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
                var (started, finished) = await RunOnceAsync(stoppingToken);
                if (started > 0 || finished > 0)
                {
                    log.LogInformation("Torneios: {Started} a decorrer, {Finished} terminado(s)", started, finished);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Falha ao atualizar o estado dos torneios");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
