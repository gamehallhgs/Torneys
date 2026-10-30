using GameHall.Api.Modules.Games;
using Xunit;

namespace GameHall.Api.Tests;

public class PodiumCalculatorTests
{
    private static readonly Guid A = Guid.NewGuid();
    private static readonly Guid B = Guid.NewGuid();
    private static readonly Guid C = Guid.NewGuid();
    private static readonly Guid D = Guid.NewGuid();

    private static readonly Dictionary<Guid, (string Name, string ColorHex)> Teams = new()
    {
        [A] = ("A", "#111111"), [B] = ("B", "#222222"), [C] = ("C", "#333333"), [D] = ("D", "#444444"),
    };

    private static PodiumGame G(string stage, int round, Guid h, Guid a, int hg, int ag, int? hp = null, int? ap = null) =>
        new(stage, round, "finished", h, a, hg, ag, hp, ap);

    [Fact]
    public void Decide_uses_goals_then_penalties()
    {
        Assert.Equal((A, B), PodiumCalculator.Decide(G("round", 1, A, B, 2, 1)));
        Assert.Equal((B, A), PodiumCalculator.Decide(G("round", 1, A, B, 1, 1, 3, 4)));
        Assert.Null(PodiumCalculator.Decide(G("round", 1, A, B, 1, 1)));
        Assert.Null(PodiumCalculator.Decide(new PodiumGame("round", 1, "scheduled", A, B, null, null, null, null)));
    }

    [Fact]
    public void Knockout_with_third_place_game()
    {
        var podium = PodiumCalculator.FromKnockout(
            [G("round", 1, A, C, 2, 0), G("round", 1, B, D, 1, 0), G("round", 2, A, B, 1, 1, 5, 4), G("third_place", 2, C, D, 0, 3)],
            Teams);
        Assert.Equal(new[] { (1, A), (2, B), (3, D) }, podium.Select(p => (p.Place, p.TeamId)).ToArray());
    }

    [Fact]
    public void Knockout_without_third_place_game_has_two_thirds()
    {
        var podium = PodiumCalculator.FromKnockout(
            [G("round", 1, A, C, 2, 0), G("round", 1, B, D, 1, 0), G("round", 2, A, B, 3, 0)], Teams);
        Assert.Equal(1, podium.Count(p => p.Place == 1));
        Assert.Equal(new[] { C, D }.OrderBy(x => x).ToArray(), podium.Where(p => p.Place == 3).Select(p => p.TeamId).OrderBy(x => x).ToArray());
    }

    [Fact]
    public void Knockout_without_decided_final_has_no_podium() =>
        Assert.Empty(PodiumCalculator.FromKnockout([G("round", 1, A, B, 1, 1)], Teams));

    [Fact]
    public void League_takes_the_top_three()
    {
        StandingRowDto Row(int pos, Guid id) => new(pos, id, "x", "#000000", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        var podium = PodiumCalculator.FromStandings([Row(1, A), Row(2, B), Row(3, C), Row(4, D)]);
        Assert.Equal(3, podium.Count);
        Assert.Equal(C, podium[2].TeamId);
    }
}
