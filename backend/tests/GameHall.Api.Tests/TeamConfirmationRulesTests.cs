using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.Tests;

public class TeamConfirmationRulesTests
{
    private static readonly DateTime T0 = new(2026, 10, 20, 12, 0, 0, DateTimeKind.Utc);

    private static ConfirmationCandidate C(int members, int paid, int lastPaidMin, int createdMin = 0, Guid? id = null) =>
        new(id ?? Guid.NewGuid(), members, paid, paid > 0 ? T0.AddMinutes(lastPaidMin) : null, T0.AddMinutes(createdMin));

    [Fact]
    public void Ready_needs_minimum_and_everyone_paid()
    {
        Assert.True(TeamConfirmationRules.IsReady(C(9, 9, 1), 9));
        Assert.False(TeamConfirmationRules.IsReady(C(8, 8, 1), 9));   // abaixo do mínimo
        Assert.False(TeamConfirmationRules.IsReady(C(9, 8, 1), 9));   // falta um pagamento
        Assert.False(TeamConfirmationRules.IsReady(C(0, 0, 0), 0));   // equipa vazia nunca
    }

    [Fact]
    public void Full_lobby_with_all_paid_is_ready()
    {
        Assert.True(TeamConfirmationRules.IsReady(C(14, 14, 5), 9));
    }

    [Fact]
    public void Selects_only_ready_teams()
    {
        var ready = C(9, 9, 3);
        var partial = C(14, 11, 4);
        var small = C(5, 5, 2);
        var picked = TeamConfirmationRules.SelectReady(new[] { partial, small, ready }, 9, 8);
        Assert.Equal(new[] { ready.TeamId }, picked);
    }

    [Fact]
    public void Orders_by_last_payment_then_creation()
    {
        var late = C(9, 9, 30, createdMin: 0);
        var early = C(9, 9, 10, createdMin: 5);
        var tieOlder = C(9, 9, 20, createdMin: 1);
        var tieNewer = C(9, 9, 20, createdMin: 2);
        var picked = TeamConfirmationRules.SelectReady(new[] { late, tieNewer, early, tieOlder }, 9, 10);
        Assert.Equal(new[] { early.TeamId, tieOlder.TeamId, tieNewer.TeamId, late.TeamId }, picked);
    }

    [Fact]
    public void Respects_slot_limit()
    {
        var a = C(7, 7, 1);
        var b = C(7, 7, 2);
        var c = C(7, 7, 3);
        var picked = TeamConfirmationRules.SelectReady(new[] { c, b, a }, 7, 2);
        Assert.Equal(new[] { a.TeamId, b.TeamId }, picked);
    }

    [Fact]
    public void Zero_or_negative_slots_select_nothing()
    {
        var a = C(7, 7, 1);
        Assert.Empty(TeamConfirmationRules.SelectReady(new[] { a }, 7, 0));
        Assert.Empty(TeamConfirmationRules.SelectReady(new[] { a }, 7, -3));
    }

    [Fact]
    public void Free_slots_never_negative()
    {
        Assert.Equal(3, TeamConfirmationRules.FreeSlots(8, 5));
        Assert.Equal(0, TeamConfirmationRules.FreeSlots(8, 8));
        Assert.Equal(0, TeamConfirmationRules.FreeSlots(8, 10));
    }

    [Fact]
    public void Full_when_confirmed_reaches_max()
    {
        Assert.False(TeamConfirmationRules.IsFull(8, 7));
        Assert.True(TeamConfirmationRules.IsFull(8, 8));
        Assert.True(TeamConfirmationRules.IsFull(8, 9));
        Assert.False(TeamConfirmationRules.IsFull(0, 0));
    }

    [Fact]
    public void Eight_slots_scenario_from_the_spec()
    {
        // 10 equipas prontas, 8 vagas: confirmam as 8 primeiras a ficar completas; as outras ficam de fora.
        var teams = Enumerable.Range(0, 10).Select(i => C(7, 7, lastPaidMin: i * 2)).ToList();
        var picked = TeamConfirmationRules.SelectReady(teams.AsEnumerable().Reverse(), 7, 8);
        Assert.Equal(teams.Take(8).Select(t => t.TeamId), picked);
        Assert.True(TeamConfirmationRules.IsFull(8, 0 + picked.Count));
    }
}
