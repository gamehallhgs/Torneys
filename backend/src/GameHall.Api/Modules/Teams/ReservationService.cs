using Dapper;
using GameHall.Api.Modules.Notifications;
using Npgsql;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Trabalho em segundo plano das reservas: reservas que passaram dos 30 minutos sem todos pagarem voltam à
/// formação (quem não pagou fica 15 minutos penalizado), as vagas libertadas passam à fila por ordem de
/// chegada e, se todas as vagas do torneio estiverem confirmadas, as equipas sem vaga são eliminadas
/// (as de demonstração nunca).
/// </summary>
public sealed class ReservationService(NpgsqlDataSource db, TimeProvider clock, ILogger<ReservationService> log)
{
    private sealed class ExpiredRow
    {
        public Guid Id { get; set; }
    }

    public const int ExpiringWarningMinutes = 5;

    public sealed record SweepResult(int Expired, int Allocated, int Removed);

    public async Task<SweepResult> SweepAsync(Guid tournamentId, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        // Bloqueia o torneio primeiro (ordem de bloqueios: torneio, depois equipas).
        var status = await conn.QuerySingleOrDefaultAsync<string?>(new CommandDefinition(
            """
            SELECT status FROM tournaments
            WHERE id = @T AND status IN ('registration_open', 'registration_closed')
            FOR UPDATE
            """,
            new { T = tournamentId }, tx, cancellationToken: ct));
        if (status is null)
        {
            return new SweepResult(0, 0, 0);
        }

        var expired = (await conn.QueryAsync<ExpiredRow>(new CommandDefinition(
            """
            SELECT id FROM teams
            WHERE tournament_id = @T AND reserved_at IS NOT NULL AND confirmed_at IS NULL
              AND reservation_expires_at <= @Now AND NOT is_demo
            FOR UPDATE
            """,
            new { T = tournamentId, Now = now }, tx, cancellationToken: ct))).Select(r => r.Id).ToArray();

        if (expired.Length > 0)
        {
            await NotifyExpiredAsync(conn, tx, expired, now, ct);

            // Penaliza quem devia ter pago e não pagou (e tira-lhe o "preparado": volta a confirmar quando acabar).
            await conn.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO reservation_penalties (user_id, tournament_id, until_at)
                SELECT m.user_id, m.tournament_id, @Until
                FROM team_members m JOIN teams t ON t.id = m.team_id
                WHERE m.team_id = ANY(@Ids) AND m.paid_at IS NULL
                  AND (t.payment_mode = 'split' OR m.user_id = t.host_user_id)
                ON CONFLICT (user_id, tournament_id) DO UPDATE SET until_at = EXCLUDED.until_at, created_at = now()
                """,
                new { Ids = expired, Until = ReservationRules.PenaltyUntil(now) }, tx, cancellationToken: ct));
            await conn.ExecuteAsync(new CommandDefinition(
                """
                UPDATE team_members m SET ready = false
                FROM teams t
                WHERE m.team_id = ANY(@Ids) AND t.id = m.team_id AND m.paid_at IS NULL
                  AND (t.payment_mode = 'split' OR m.user_id = t.host_user_id)
                """,
                new { Ids = expired }, tx, cancellationToken: ct));

            foreach (var id in expired)
            {
                await ReservationAllocator.ResetToFormingAsync(conn, tx, id);
            }
        }

        var allocated = await ReservationAllocator.AllocateAsync(conn, tx, tournamentId, now);
        await WarnExpiringAsync(conn, tx, tournamentId, now, ct);

        // Depois do prazo das inscrições, quem voltou à formação (reserva expirada) é eliminado.
        var late = 0;
        if (status == "registration_closed")
        {
            var lateIds = (await conn.QueryAsync<Guid>(new CommandDefinition(
                "SELECT id FROM teams WHERE tournament_id = @T AND closed_at IS NULL AND NOT is_demo FOR UPDATE",
                new { T = tournamentId }, tx, cancellationToken: ct))).ToArray();
            await TeamNotifier.NotifyEliminatedAsync(conn, tx, lateIds, deadline: true);
            late = await conn.ExecuteAsync(new CommandDefinition(
                "DELETE FROM teams WHERE id = ANY(@Ids)", new { Ids = lateIds }, tx, cancellationToken: ct));
        }

        // Todas as vagas confirmadas: já não há esperança para as outras equipas.
        var doomed = (await conn.QueryAsync<Guid>(new CommandDefinition(
            """
            SELECT t.id FROM teams t
            JOIN tournaments tr ON tr.id = t.tournament_id
            WHERE t.tournament_id = @T AND t.reserved_at IS NULL AND NOT t.is_demo
              AND (SELECT count(*) FROM teams x WHERE x.tournament_id = tr.id AND x.confirmed_at IS NOT NULL) >= tr.max_teams
            FOR UPDATE OF t
            """,
            new { T = tournamentId }, tx, cancellationToken: ct))).ToArray();
        await TeamNotifier.NotifyEliminatedAsync(conn, tx, doomed, deadline: false);
        var removed = late + await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM teams WHERE id = ANY(@Ids)", new { Ids = doomed }, tx, cancellationToken: ct));

        await tx.CommitAsync(ct);

        if (expired.Length > 0 || allocated.Count > 0 || removed > 0)
        {
            log.LogInformation(
                "Torneio {Tournament}: {Expired} reserva(s) expirada(s), {Allocated} vaga(s) atribuída(s) da fila, {Removed} equipa(s) eliminada(s)",
                tournamentId, expired.Length, allocated.Count, removed);
        }

        return new SweepResult(expired.Length, allocated.Count, removed);
    }

    private sealed class PayRow
    {
        public Guid TeamId { get; set; }
        public Guid UserId { get; set; }
        public bool MustPay { get; set; }
    }

    /// <summary>Quem tinha de pagar numa equipa (dividido: todos os que não pagaram; total: o líder se não pagou).</summary>
    private static async Task<List<PayRow>> UnpaidAsync(
        System.Data.IDbConnection c, System.Data.IDbTransaction tx, IEnumerable<Guid> teamIds, CancellationToken ct) =>
        (await c.QueryAsync<PayRow>(new CommandDefinition(
            """
            SELECT m.team_id, m.user_id,
                   (m.paid_at IS NULL AND (t.payment_mode = 'split' OR m.user_id = t.host_user_id)) AS must_pay
            FROM team_members m JOIN teams t ON t.id = m.team_id
            WHERE m.team_id = ANY(@Ids)
            """,
            new { Ids = teamIds.ToArray() }, tx, cancellationToken: ct))).ToList();

    /// <summary>Reservas expiradas: todos os membros sabem que acabou; quem não pagou sabe da penalização.</summary>
    private static async Task NotifyExpiredAsync(
        System.Data.IDbConnection c, System.Data.IDbTransaction tx, Guid[] teamIds, DateTime now, CancellationToken ct)
    {
        foreach (var row in await UnpaidAsync(c, tx, teamIds, ct))
        {
            await TeamNotifier.NotifyUserAsync(
                c, tx, row.UserId, row.TeamId, NotificationTypes.ReservationExpired, NotificationTexts.ExpiredTitle,
                (team, _) => NotificationTexts.Expired(team, row.MustPay, ReservationRules.PenaltyMinutes));
        }
    }

    /// <summary>Avisa uma só vez, quando faltam 5 minutos, quem ainda tem de pagar (e os restantes membros).</summary>
    private static async Task WarnExpiringAsync(
        System.Data.IDbConnection c, System.Data.IDbTransaction tx, Guid tournamentId, DateTime now, CancellationToken ct)
    {
        var teamIds = (await c.QueryAsync<Guid>(new CommandDefinition(
            """
            UPDATE teams SET expiry_warned_at = @Now
            WHERE tournament_id = @T AND reserved_at IS NOT NULL AND confirmed_at IS NULL AND NOT is_demo
              AND expiry_warned_at IS NULL AND reservation_expires_at > @Now
              AND reservation_expires_at <= @Soon
            RETURNING id
            """,
            new { T = tournamentId, Now = now, Soon = now.AddMinutes(ExpiringWarningMinutes) },
            tx, cancellationToken: ct))).ToArray();
        if (teamIds.Length == 0)
        {
            return;
        }

        foreach (var row in await UnpaidAsync(c, tx, teamIds, ct))
        {
            await TeamNotifier.NotifyUserAsync(
                c, tx, row.UserId, row.TeamId, NotificationTypes.ReservationExpiring, NotificationTexts.ExpiringTitle,
                (team, _) => NotificationTexts.Expiring(team, ExpiringWarningMinutes, row.MustPay),
                deliver: row.MustPay);   // push/email só a quem ainda tem de pagar
        }
    }

    /// <summary>Corre a limpeza nos torneios que têm reservas por expirar, fila ou equipas a eliminar.</summary>
    public async Task SweepAllAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        Guid[] ids;
        await using (var conn = await db.OpenConnectionAsync(ct))
        {
            ids = (await conn.QueryAsync<Guid>(new CommandDefinition(
                """
                SELECT tr.id FROM tournaments tr
                WHERE tr.status IN ('registration_open', 'registration_closed')
                  AND (
                    EXISTS (SELECT 1 FROM teams t WHERE t.tournament_id = tr.id AND NOT t.is_demo
                            AND t.reserved_at IS NOT NULL AND t.confirmed_at IS NULL AND t.reservation_expires_at <= @Now)
                    OR EXISTS (SELECT 1 FROM teams t WHERE t.tournament_id = tr.id AND NOT t.is_demo
                            AND t.reserved_at IS NOT NULL AND t.confirmed_at IS NULL AND t.expiry_warned_at IS NULL
                            AND t.reservation_expires_at <= @Soon)
                    OR EXISTS (
                            SELECT 1 FROM teams t WHERE t.tournament_id = tr.id AND t.closed_at IS NOT NULL AND t.reserved_at IS NULL)
                    OR (tr.status = 'registration_closed' AND EXISTS (
                            SELECT 1 FROM teams t WHERE t.tournament_id = tr.id AND NOT t.is_demo AND t.closed_at IS NULL))
                    OR (EXISTS (SELECT 1 FROM teams t WHERE t.tournament_id = tr.id AND NOT t.is_demo AND t.reserved_at IS NULL)
                        AND (SELECT count(*) FROM teams x WHERE x.tournament_id = tr.id AND x.confirmed_at IS NOT NULL) >= tr.max_teams)
                  )
                """,
                new { Now = now, Soon = now.AddMinutes(ExpiringWarningMinutes) }, cancellationToken: ct))).ToArray();
        }

        foreach (var id in ids)
        {
            await SweepAsync(id, ct);
        }
    }
}

/// <summary>Chama o ReservationService de 15 em 15 segundos (expirar reservas, avançar a fila).</summary>
public sealed class ReservationWorker(
    ReservationService reservations, IConfiguration config, ILogger<ReservationWorker> log) : BackgroundService
{
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
                await reservations.SweepAllAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Falha ao processar as reservas de vagas");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
