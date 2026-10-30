using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.Tests;

public class FormationsTests
{
    [Theory]
    [InlineData("football7", 7)]
    [InlineData("football9", 9)]
    [InlineData("football11", 11)]
    [InlineData("futsal", 5)]
    public void Every_formation_fills_the_pitch(string sport, int players)
    {
        Assert.NotEmpty(Formations.For(sport));
        foreach (var f in Formations.For(sport))
        {
            Assert.Equal(players, Formations.SlotCount(f));
        }
    }

    [Fact]
    public void Validate_checks_formation_slots_and_members()
    {
        var a = Guid.NewGuid();
        var b = Guid.NewGuid();
        var members = new HashSet<Guid> { a, b };
        Assert.Null(Formations.Validate("football7", "2-3-1", [(a, 0), (b, 3)], members));
        Assert.NotNull(Formations.Validate("football7", "4-4-2", [], members));
        Assert.NotNull(Formations.Validate("football7", "2-3-1", [(a, 7)], members));
        Assert.NotNull(Formations.Validate("football7", "2-3-1", [(a, -1)], members));
        Assert.NotNull(Formations.Validate("football7", "2-3-1", [(a, 1), (b, 1)], members));
        Assert.NotNull(Formations.Validate("football7", "2-3-1", [(a, 1), (a, 2)], members));
        Assert.NotNull(Formations.Validate("football7", "2-3-1", [(Guid.NewGuid(), 1)], members));
    }
}
