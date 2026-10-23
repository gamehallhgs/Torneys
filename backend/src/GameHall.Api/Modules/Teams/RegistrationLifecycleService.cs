using Npgsql;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Quando o prazo de inscrições de um torneio termina: o torneio passa a "inscrições fechadas" e as
/// equipas abaixo do mínimo de jogadores são removidas. Em cada ciclo confirma também as equipas completas e
/// pagas (ver TeamConfirmationService). (Mais tarde o gestor poderá abrir um período
/// suplementar.) Corre ao arranque e depois de minuto a minuto. As equipas de demonstração nunca são removidas.
/// </summary>
public sealed class RegistrationLifecycleService(
    NpgsqlDataSource db, IConfiguration config, TeamConfirmationService confirmation,
    ILogger<RegistrationLifecycleService> log) : BackgroundService
{
    private const string Sql =
        """
        WITH closing AS (
            UPDATE tournaments
            SET status = 'registration_closed', updated_at = now()
            WHERE status = 'registration_open' AND registration_closes_at <= now()
            RETURNING id, min_players_per_team
        ),
        removed AS (
            DELETE FROM teams t
            USING closing c
            WHERE t.tournament_id = c.id
              AND NOT t.is_demo
              AND (SELECT count(*) FROM team_members m WHERE m.team_id = t.id) < c.min_players_per_team
            RETURNING t.id
        )
        SELECT (SELECT count(*) FROM closing)::int AS closed, (SELECT count(*) FROM removed)::int AS removed_teams
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
                // Primeiro confirmam-se as equipas prontas (antes de o prazo as apanhar), depois fecham-se os torneios.
                await confirmation.ConfirmAllAsync(stoppingToken);

                await using var conn = await db.OpenConnectionAsync(stoppingToken);
                await using var cmd = new NpgsqlCommand(Sql, conn);
                await using var reader = await cmd.ExecuteReaderAsync(stoppingToken);
                if (await reader.ReadAsync(stoppingToken) && reader.GetInt32(0) > 0)
                {
                    log.LogInformation(
                        "Inscrições fechadas em {Closed} torneio(s); {Removed} equipa(s) abaixo do mínimo removida(s)",
                        reader.GetInt32(0), reader.GetInt32(1));
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Falha ao fechar inscrições");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
