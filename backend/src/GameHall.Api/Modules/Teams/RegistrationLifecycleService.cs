using Npgsql;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Quando o prazo de inscrições de um torneio termina: o torneio passa a "inscrições fechadas" e as
/// equipas que não fecharam até ao prazo são eliminadas. Ficam as confirmadas, as com vaga reservada
/// (a pagar) e as fechadas em fila (estas só enquanto houver vagas por confirmar; ver ReservationService).
/// Corre ao arranque e depois de minuto a minuto. As equipas de demonstração nunca são removidas.
/// </summary>
public sealed class RegistrationLifecycleService(
    NpgsqlDataSource db, IConfiguration config, ILogger<RegistrationLifecycleService> log) : BackgroundService
{
    private const string Sql =
        """
        WITH closing AS (
            UPDATE tournaments
            SET status = 'registration_closed', updated_at = now()
            WHERE status = 'registration_open' AND registration_closes_at <= now()
            RETURNING id, name
        ),
        notified AS (
            INSERT INTO notifications (id, user_id, type, data)
            SELECT gen_random_uuid(), m.user_id, 'team_eliminated',
                   jsonb_build_object(
                       'teamId', t.id, 'teamName', t.name, 'colorHex', t.color_hex, 'tournamentName', c.name,
                       'title', 'Equipa eliminada',
                       'message', 'A equipa ' || t.name || ' foi eliminada de ' || c.name
                                  || ': as inscrições terminaram sem a equipa estar fechada.')
            FROM teams t
            JOIN closing c ON c.id = t.tournament_id
            JOIN team_members m ON m.team_id = t.id
            WHERE NOT t.is_demo AND t.closed_at IS NULL
            RETURNING 1
        ),
        removed AS (
            DELETE FROM teams t
            USING closing c
            WHERE t.tournament_id = c.id
              AND NOT t.is_demo
              AND t.closed_at IS NULL
            RETURNING t.id
        )
        SELECT (SELECT count(*) FROM closing)::int AS closed, (SELECT count(*) FROM removed)::int AS removed_teams
        """;

    /// <summary>Uma volta (também usada pelos testes). Devolve (torneios fechados, equipas removidas).</summary>
    public async Task<(int Closed, int Removed)> RunOnceAsync(CancellationToken ct)
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
                var (closed, removed) = await RunOnceAsync(stoppingToken);
                if (closed > 0)
                {
                    log.LogInformation(
                        "Inscrições fechadas em {Closed} torneio(s); {Removed} equipa(s) que não fecharam removida(s)",
                        closed, removed);
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
