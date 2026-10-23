using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Confirma equipas: mínimo de jogadores + todos pagaram, pela ordem em que ficaram completas, até ao máximo
/// de equipas do torneio. Quando o torneio fica cheio, as equipas não confirmadas são eliminadas (as de
/// demonstração nunca) e deixa de ser possível criar equipas. O futuro módulo de pagamentos chama
/// <see cref="ConfirmReadyAsync"/> logo a seguir a registar um pagamento; entretanto o serviço de ciclo de vida
/// corre-o de minuto a minuto.
/// </summary>
public sealed class TeamConfirmationService(NpgsqlDataSource db, ILogger<TeamConfirmationService> log)
{
    private sealed class GateRow
    {
        public int MaxTeams { get; set; }
        public int MinPlayersPerTeam { get; set; }
    }

    /// <summary>Devolve quantas equipas foram confirmadas e quantas eliminadas por o torneio ter enchido.</summary>
    public async Task<(int Confirmed, int Removed)> ConfirmReadyAsync(Guid tournamentId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        // Bloqueia o torneio: duas confirmações em simultâneo não passam do máximo.
        var gate = await conn.QuerySingleOrDefaultAsync<GateRow>(new CommandDefinition(
            """
            SELECT max_teams, min_players_per_team FROM tournaments
            WHERE id = @T AND status = 'registration_open'
            FOR UPDATE
            """,
            new { T = tournamentId }, tx, cancellationToken: ct));
        if (gate is null)
        {
            return (0, 0);
        }

        var already = await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT count(*)::int FROM teams WHERE tournament_id = @T AND confirmed_at IS NOT NULL",
            new { T = tournamentId }, tx, cancellationToken: ct));

        var slots = TeamConfirmationRules.FreeSlots(gate.MaxTeams, already);
        IReadOnlyList<Guid> ready = [];
        if (slots > 0)
        {
            var candidates = (await conn.QueryAsync<ConfirmationCandidate>(new CommandDefinition(
                """
                SELECT t.id AS team_id, count(m.user_id)::int AS members, count(m.paid_at)::int AS paid,
                       max(m.paid_at) AS last_paid_at, t.created_at
                FROM teams t
                LEFT JOIN team_members m ON m.team_id = t.id
                WHERE t.tournament_id = @T AND t.confirmed_at IS NULL
                GROUP BY t.id, t.created_at
                """,
                new { T = tournamentId }, tx, cancellationToken: ct))).ToList();

            ready = TeamConfirmationRules.SelectReady(candidates, gate.MinPlayersPerTeam, slots);

            if (ready.Count > 0)
            {
                await conn.ExecuteAsync(new CommandDefinition(
                    "UPDATE teams SET confirmed_at = now() WHERE id = ANY(@Ids)",
                    new { Ids = ready.ToArray() }, tx, cancellationToken: ct));
            }
        }

        var removed = 0;
        if (TeamConfirmationRules.IsFull(gate.MaxTeams, already + ready.Count))
        {
            removed = await conn.ExecuteAsync(new CommandDefinition(
                "DELETE FROM teams WHERE tournament_id = @T AND confirmed_at IS NULL AND NOT is_demo",
                new { T = tournamentId }, tx, cancellationToken: ct));
        }

        await tx.CommitAsync(ct);

        if (ready.Count > 0 || removed > 0)
        {
            log.LogInformation(
                "Torneio {Tournament}: {Confirmed} equipa(s) confirmada(s), {Removed} eliminada(s) por vagas esgotadas",
                tournamentId, ready.Count, removed);
        }

        return (ready.Count, removed);
    }

    /// <summary>Corre a confirmação em todos os torneios com inscrições abertas que tenham equipas por confirmar.</summary>
    public async Task ConfirmAllAsync(CancellationToken ct)
    {
        Guid[] ids;
        await using (var conn = await db.OpenConnectionAsync(ct))
        {
            ids = (await conn.QueryAsync<Guid>(new CommandDefinition(
                """
                SELECT tr.id FROM tournaments tr
                WHERE tr.status = 'registration_open'
                  AND EXISTS (SELECT 1 FROM teams t WHERE t.tournament_id = tr.id AND t.confirmed_at IS NULL AND NOT t.is_demo)
                """,
                cancellationToken: ct))).ToArray();
        }

        foreach (var id in ids)
        {
            await ConfirmReadyAsync(id, ct);
        }
    }
}
