using System.Data;
using Dapper;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Dá vagas livres às equipas fechadas em fila, por ordem de chegada. Tem de ser chamado com o TORNEIO já
/// bloqueado na transação (TeamStore.GateAsync ou o bloqueio do ReservationService): assim duas equipas
/// nunca ficam com a mesma vaga. Regra de bloqueios em todo o código: primeiro o torneio, depois a equipa.
/// </summary>
public static class ReservationAllocator
{
    private sealed class TournamentSlots
    {
        public string Status { get; set; } = "";
        public int MaxTeams { get; set; }
        public int Reserved { get; set; }
    }

    /// <summary>
    /// Devolve os ids das equipas que acabaram de receber vaga e avisa os seus membros. [skipNotify] é a
    /// equipa que acabou de fechar (essa recebe o aviso "equipa fechada", que já diz que há vaga).
    /// </summary>
    public static async Task<IReadOnlyList<Guid>> AllocateAsync(
        IDbConnection c, IDbTransaction tx, Guid tournamentId, DateTime now, Guid? skipNotify = null)
    {
        var t = await c.QuerySingleOrDefaultAsync<TournamentSlots>(
            """
            SELECT status, max_teams,
                   (SELECT count(*)::int FROM teams x WHERE x.tournament_id = @T AND x.reserved_at IS NOT NULL) AS reserved
            FROM tournaments WHERE id = @T
            """,
            new { T = tournamentId }, tx);

        // A fila continua a andar depois do prazo das inscrições (as equipas fechadas em fila não são eliminadas
        // enquanto houver vagas por confirmar).
        if (t is null || t.Status is not ("registration_open" or "registration_closed"))
        {
            return [];
        }

        var free = ReservationRules.FreeSlots(t.MaxTeams, t.Reserved);
        if (free <= 0)
        {
            return [];
        }

        var queue = (await c.QueryAsync<QueuedTeam>(
            """
            SELECT id AS team_id, closed_at, created_at
            FROM teams
            WHERE tournament_id = @T AND closed_at IS NOT NULL AND reserved_at IS NULL
            """,
            new { T = tournamentId }, tx)).ToList();

        var picked = ReservationRules.NextToReserve(queue, free);
        if (picked.Count == 0)
        {
            return [];
        }

        await c.ExecuteAsync(
            "UPDATE teams SET reserved_at = @Now, reservation_expires_at = @Exp, expiry_warned_at = NULL WHERE id = ANY(@Ids)",
            new { Now = now, Exp = ReservationRules.ExpiresAt(now), Ids = picked.ToArray() }, tx);
        await TeamNotifier.NotifySlotReservedAsync(c, tx, picked.Where(id => id != skipNotify).ToArray());
        return picked;
    }

    /// <summary>
    /// Liberta a equipa para voltar à formação: limpa o fecho, a vaga e os pagamentos (o saldo que estava
    /// reservado é libertado sem custos). Mantém os membros e os "preparados".
    /// </summary>
    public static async Task ResetToFormingAsync(IDbConnection c, IDbTransaction tx, Guid teamId)
    {
        await c.ExecuteAsync(
            """
            UPDATE teams
            SET closed_at = NULL, payment_mode = NULL, share_cents = NULL,
                reserved_at = NULL, reservation_expires_at = NULL, confirmed_at = NULL, expiry_warned_at = NULL
            WHERE id = @Id
            """,
            new { Id = teamId }, tx);
        await c.ExecuteAsync("UPDATE team_members SET paid_at = NULL WHERE team_id = @Id", new { Id = teamId }, tx);
    }
}
