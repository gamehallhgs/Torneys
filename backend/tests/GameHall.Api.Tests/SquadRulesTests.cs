using GameHall.Api.Modules.Games;
using Xunit;

namespace GameHall.Api.Tests;

public class SquadRulesTests
{
    private static SquadRow Row(string name, string? pos, int? slot, string? formation = "2-3-1") =>
        new() { DisplayName = name, Position = pos, Slot = slot, Formation = formation, Sport = "football7" };

    [Fact]
    public void Without_lineup_it_is_a_list_ordered_goalkeeper_to_striker()
    {
        var squad = SquadRules.Build([
            Row("Avançado", "ST", null, null), Row("Sem posição", null, null, null),
            Row("Defesa", "CB", null, null), Row("Guarda", "GK", null, null)]);
        Assert.False(squad.IsFormal);
        Assert.Null(squad.Formation);
        Assert.Equal(["Guarda", "Defesa", "Avançado", "Sem posição"], squad.Players.Select(p => p.DisplayName));
        Assert.All(squad.Players, p => Assert.Null(p.Slot));
    }

    [Fact]
    public void Incomplete_lineup_is_still_a_list()
    {
        var squad = SquadRules.Build([Row("A", "GK", 0), Row("B", "ST", null), Row("C", "CB", null)]);
        Assert.False(squad.IsFormal);
    }

    [Fact]
    public void Complete_lineup_is_formal_with_starters_first()
    {
        var rows = Enumerable.Range(0, 7).Select(i => Row($"J{i}", null, i)).Append(Row("Suplente", "GK", null)).ToList();
        var squad = SquadRules.Build(rows);
        Assert.True(squad.IsFormal);
        Assert.Equal("2-3-1", squad.Formation);
        Assert.Equal("Suplente", squad.Players[^1].DisplayName);
        Assert.False(squad.Players[^1].IsStarter);
        Assert.True(squad.Players[0].IsStarter);
    }
}
