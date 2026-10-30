using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.Tests;

public class ReservationRulesTests
{
    private static readonly DateTime T0 = new(2026, 10, 26, 10, 0, 0, DateTimeKind.Utc);

    private static QueuedTeam Q(int closedMinutes, int createdMinutes = 0) =>
        new(Guid.NewGuid(), T0.AddMinutes(closedMinutes), T0.AddMinutes(createdMinutes));

    // ---------- Estado ----------

    [Fact]
    public void State_follows_the_lifecycle()
    {
        Assert.Equal("forming", ReservationRules.StateOf(null, null, null));
        Assert.Equal("queued", ReservationRules.StateOf(T0, null, null));
        Assert.Equal("reserved", ReservationRules.StateOf(T0, T0, null));
        Assert.Equal("confirmed", ReservationRules.StateOf(T0, T0, T0));
    }

    // ---------- Valores ----------

    [Theory]
    [InlineData("split", 5000, 7, 715)]   // 50 € / 7 = 7,142... -> 7,15 €
    [InlineData("split", 6000, 12, 500)]  // divide certo
    [InlineData("split", 6000, 9, 667)]   // 6,666... -> 6,67 €
    [InlineData("split", 1, 14, 1)]
    [InlineData("split", 0, 9, 0)]        // torneio gratuito
    [InlineData("total", 5000, 7, 5000)]  // o líder paga tudo
    [InlineData("total", 0, 7, 0)]
    public void Share_is_rounded_up(string mode, int fee, int members, int expected) =>
        Assert.Equal(expected, ReservationRules.ShareCents(mode, fee, members));

    [Fact]
    public void Rounding_extra_is_reported_to_the_leader()
    {
        // 50 € por 7 jogadores: pagam 7 x 7,15 = 50,05 € (5 cêntimos a mais).
        Assert.Equal(5005, ReservationRules.CollectedCents("split", 5000, 7));
        Assert.Equal(5, ReservationRules.ExtraCents("split", 5000, 7));
        // Divide certo: nada a mais. Pagamento total: nunca há arredondamento.
        Assert.Equal(0, ReservationRules.ExtraCents("split", 6000, 12));
        Assert.Equal(0, ReservationRules.ExtraCents("total", 5000, 7));
        Assert.Equal(5000, ReservationRules.CollectedCents("total", 5000, 7));
    }

    [Fact]
    public void Split_never_collects_less_than_the_fee()
    {
        for (var members = 1; members <= 30; members++)
        {
            foreach (var fee in new[] { 1, 99, 3500, 5000, 6000, 12345 })
            {
                var collected = ReservationRules.CollectedCents("split", fee, members);
                Assert.True(collected >= fee);
                Assert.True(collected - fee < members, $"fee={fee} members={members}");
            }
        }
    }

    [Theory]
    [InlineData("split", true)]
    [InlineData("total", true)]
    [InlineData("outro", false)]
    [InlineData(null, false)]
    [InlineData("", false)]
    public void Payment_mode_validation(string? mode, bool valid) =>
        Assert.Equal(valid, ReservationRules.IsValidMode(mode));

    // ---------- Fechar a equipa ----------

    [Fact]
    public void Leader_can_close_when_minimum_reached_and_everyone_ready() =>
        Assert.Null(ReservationRules.WhyCannotClose("registration_open", false, 9, 9, 0, 0));

    [Theory]
    [InlineData("registration_closed", false, 9, 9, 0, 0, "registration_closed")]
    [InlineData("registration_open", true, 9, 9, 0, 0, "team_closed")]
    [InlineData("registration_open", false, 8, 9, 0, 0, "below_min_players")]
    [InlineData("registration_open", false, 9, 9, 2, 0, "members_not_ready")]
    [InlineData("registration_open", false, 9, 9, 0, 1, "members_penalized")]
    // Ordem dos motivos: inscrições, já fechada, mínimo, preparados, penalizados.
    [InlineData("registration_open", false, 8, 9, 3, 1, "below_min_players")]
    [InlineData("registration_open", false, 9, 9, 3, 1, "members_not_ready")]
    public void Close_blocked_reasons(
        string status, bool closed, int members, int min, int notReady, int penalized, string reason) =>
        Assert.Equal(reason, ReservationRules.WhyCannotClose(status, closed, members, min, notReady, penalized));

    // ---------- Vagas e fila ----------

    [Fact]
    public void Free_slots_never_negative() =>
        Assert.Equal(new[] { 3, 0, 0 }, new[]
        {
            ReservationRules.FreeSlots(8, 5), ReservationRules.FreeSlots(8, 8), ReservationRules.FreeSlots(8, 11)
        });

    [Fact]
    public void Full_when_reserved_slots_reach_the_maximum()
    {
        Assert.False(ReservationRules.IsFull(8, 7));
        Assert.True(ReservationRules.IsFull(8, 8));
        Assert.False(ReservationRules.IsFull(0, 0));
    }

    [Fact]
    public void Queue_is_served_by_arrival_order()
    {
        var late = Q(closedMinutes: 9);
        var first = Q(closedMinutes: 1);
        var second = Q(closedMinutes: 4);

        var picked = ReservationRules.NextToReserve(new[] { late, first, second }, 2);

        Assert.Equal(new[] { first.TeamId, second.TeamId }, picked.ToArray());
    }

    [Fact]
    public void Same_closing_instant_is_resolved_by_creation_time()
    {
        var newer = Q(closedMinutes: 5, createdMinutes: 3);
        var older = Q(closedMinutes: 5, createdMinutes: -20);

        Assert.Equal(new[] { older.TeamId }, ReservationRules.NextToReserve(new[] { newer, older }, 1).ToArray());
    }

    [Fact]
    public void No_free_slot_means_nobody_is_picked()
    {
        var a = Q(1);
        Assert.Empty(ReservationRules.NextToReserve(new[] { a }, 0));
        Assert.Empty(ReservationRules.NextToReserve(new[] { a }, -2));
        Assert.Empty(ReservationRules.NextToReserve(Array.Empty<QueuedTeam>(), 3));
    }

    [Fact]
    public void Queue_position_is_one_based_and_null_outside_the_queue()
    {
        var a = Q(1);
        var b = Q(2);
        var c = Q(3);

        Assert.Equal(1, ReservationRules.QueuePosition(new[] { c, a, b }, a.TeamId));
        Assert.Equal(3, ReservationRules.QueuePosition(new[] { c, a, b }, c.TeamId));
        Assert.Null(ReservationRules.QueuePosition(new[] { a, b }, Guid.NewGuid()));
    }

    // ---------- Prazos ----------

    [Fact]
    public void Reservation_lasts_30_minutes_and_penalty_15()
    {
        Assert.Equal(T0.AddMinutes(30), ReservationRules.ExpiresAt(T0));
        Assert.Equal(T0.AddMinutes(15), ReservationRules.PenaltyUntil(T0));
    }

    [Fact]
    public void Reservation_expires_exactly_at_the_deadline()
    {
        var expires = ReservationRules.ExpiresAt(T0);
        Assert.False(ReservationRules.IsExpired(expires, expires.AddSeconds(-1)));
        Assert.True(ReservationRules.IsExpired(expires, expires));
        Assert.False(ReservationRules.IsExpired(null, expires));
    }

    [Fact]
    public void Penalty_ends_at_the_deadline()
    {
        var until = ReservationRules.PenaltyUntil(T0);
        Assert.True(ReservationRules.IsPenalized(until, until.AddSeconds(-1)));
        Assert.False(ReservationRules.IsPenalized(until, until));
        Assert.False(ReservationRules.IsPenalized(null, T0));
    }

    [Theory]
    [InlineData("split", false, false, true)]   // dividido: quem não pagou é penalizado
    [InlineData("split", true, false, true)]
    [InlineData("split", false, true, false)]   // quem pagou nunca
    [InlineData("total", true, false, true)]    // total: só o líder (era ele que pagava)
    [InlineData("total", false, false, false)]
    [InlineData("total", true, true, false)]
    public void Who_is_penalized_on_expiry(string mode, bool isHost, bool paid, bool penalized) =>
        Assert.Equal(penalized, ReservationRules.IsPenalizedOnExpiry(mode, isHost, paid));

    // ---------- Pagar ----------

    [Theory]
    [InlineData("forming", false, null, true, false, "team_not_closed")]
    [InlineData("queued", false, "split", true, false, "team_in_queue")]
    [InlineData("confirmed", false, "split", true, true, "team_confirmed")]
    [InlineData("reserved", true, "split", true, false, "reservation_expired")]
    [InlineData("reserved", false, "total", false, false, "only_host_pays")]
    [InlineData("reserved", false, "split", false, true, "already_paid")]
    public void Pay_blocked_reasons(string state, bool expired, string? mode, bool host, bool paid, string reason) =>
        Assert.Equal(reason, ReservationRules.WhyCannotPay(state, expired, mode, host, paid));

    [Theory]
    [InlineData("split", false)]
    [InlineData("split", true)]
    [InlineData("total", true)]
    public void Pay_allowed_while_reserved(string mode, bool host) =>
        Assert.Null(ReservationRules.WhyCannotPay("reserved", false, mode, host, false));

    [Fact]
    public void Team_is_confirmed_only_when_everyone_paid()
    {
        Assert.True(ReservationRules.AllPaid(9, 9));
        Assert.False(ReservationRules.AllPaid(9, 8));
        Assert.False(ReservationRules.AllPaid(0, 0));
    }

    // ---------- Equipa fechada: ninguém entra ----------

    [Fact]
    public void Closed_team_blocks_join_requests()
    {
        Assert.Equal("team_closed",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 9, 14, false, teamClosed: true));
        // Quem já é membro continua a ver "já és membro"; confirmada tem o seu próprio motivo.
        Assert.Equal("already_member",
            TeamRules.JoinBlockedReason(true, true, "registration_open", false, 16, null, 20, 9, 14, false, teamClosed: true));
        Assert.Equal("team_confirmed",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 9, 14, false,
                teamConfirmed: true, teamClosed: true));
    }

    [Fact]
    public void Penalized_player_cannot_join_any_team()
    {
        Assert.Equal("player_penalized",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 5, 14, false, isPenalized: true));
        // Quem já é membro, quem está noutra equipa ou numa equipa fechada vê o motivo mais específico.
        Assert.Equal("already_member",
            TeamRules.JoinBlockedReason(true, true, "registration_open", false, 16, null, 20, 5, 14, false, isPenalized: true));
        Assert.Equal("already_in_team",
            TeamRules.JoinBlockedReason(true, false, "registration_open", true, 16, null, 20, 5, 14, false, isPenalized: true));
        Assert.Equal("team_closed",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 5, 14, false, teamClosed: true, isPenalized: true));
        Assert.Null(
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 5, 14, false, isPenalized: false));
    }
}
