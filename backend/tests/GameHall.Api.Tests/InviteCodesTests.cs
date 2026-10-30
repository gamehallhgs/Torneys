using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.Tests;

public class InviteCodesTests
{
    [Theory]
    [InlineData("GH-7K3Q", "GH-7K3Q")]
    [InlineData("gh-7k3q", "GH-7K3Q")]
    [InlineData("GH7K3Q", "GH-7K3Q")]
    [InlineData("  7k3q ", "GH-7K3Q")]
    [InlineData("gh 7k3q", "GH-7K3Q")]
    public void Normalize_accepts_common_ways_of_typing_a_code(string raw, string expected) =>
        Assert.Equal(expected, InviteCodes.Normalize(raw));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("GH-7K3")]       // curto
    [InlineData("GH-7K3QX")]     // longo
    [InlineData("GH-7K30")]      // 0 não existe no alfabeto
    [InlineData("GH-7KIQ")]      // I não existe no alfabeto
    [InlineData("XX-7K3Q")]      // prefixo errado
    public void Normalize_rejects_impossible_codes(string? raw) => Assert.Null(InviteCodes.Normalize(raw));

    [Theory]
    [InlineData(0, 3)]
    [InlineData(1, 2)]
    [InlineData(3, 0)]
    [InlineData(5, 0)]
    public void RegensLeft_counts_down_to_zero(int used, int left) => Assert.Equal(left, InviteCodes.RegensLeft(used));

    [Fact]
    public void MinutesUntilRegen_rounds_up_and_is_at_least_one()
    {
        var now = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
        Assert.Equal(21, InviteCodes.MinutesUntilRegen(now.AddMinutes(-39).AddSeconds(-30), now));
        Assert.Equal(1, InviteCodes.MinutesUntilRegen(now.AddHours(-1), now));
    }
}
