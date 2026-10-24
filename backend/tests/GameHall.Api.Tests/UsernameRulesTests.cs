using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.Tests;

public class UsernameRulesTests
{
    [Theory]
    [InlineData("  @Hugo ", "hugo")]
    [InlineData("HUGO.Dias", "hugo.dias")]
    [InlineData("hugo", "hugo")]
    [InlineData(null, "")]
    public void Normalize_trims_removes_at_and_lowercases(string? input, string expected) =>
        Assert.Equal(expected, UsernameRules.Normalize(input));

    [Theory]
    [InlineData("hugo")]
    [InlineData("abc")]
    [InlineData("a.b")]
    [InlineData("hugo_dias")]
    [InlineData("hugo.dias.99")]
    [InlineData("jose.carlos.na_2")]
    [InlineData("12345")]
    [InlineData("aaaaaaaaaaaaaaaaaaaa")] // 20
    public void Valid_usernames(string name) => Assert.Null(UsernameRules.Validate(name));

    [Theory]
    [InlineData("ab")]                       // curto
    [InlineData("aaaaaaaaaaaaaaaaaaaaa")]    // 21
    [InlineData(".hugo")]
    [InlineData("hugo.")]
    [InlineData("_hugo")]
    [InlineData("hugo_")]
    [InlineData("hu..go")]
    [InlineData("hu go")]
    [InlineData("joão")]                     // acentos
    [InlineData("hugo-dias")]
    [InlineData("hugo#482")]
    [InlineData("")]
    public void Invalid_usernames(string name) => Assert.NotNull(UsernameRules.Validate(name));

    [Fact]
    public void Double_dot_has_its_own_message() =>
        Assert.Contains("pontos seguidos", UsernameRules.Validate("hu..go"));

    [Theory]
    [InlineData("admin")]
    [InlineData("suporte")]
    [InlineData("gamehall")]
    [InlineData("o.gamehall.oficial")]   // contém "gamehall"
    [InlineData("gamehall_equipa")]
    [InlineData("fifa")]
    public void Reserved_usernames_are_refused(string name)
    {
        Assert.True(UsernameRules.IsReserved(name));
        Assert.NotNull(UsernameRules.Validate(name));
    }

    [Theory]
    [InlineData("hugo")]
    [InlineData("hugo.admin")]   // só o nome exato "admin" é reservado
    [InlineData("liga.fut7")]
    public void Normal_names_are_not_reserved(string name) => Assert.False(UsernameRules.IsReserved(name));

    [Fact]
    public void Reserved_list_is_lowercase_and_well_formed()
    {
        foreach (var r in UsernameRules.Reserved)
        {
            Assert.Equal(r.ToLowerInvariant(), r);
            Assert.Equal(r, r.Trim());
        }
    }

    [Theory]
    [InlineData("hugo#482", "hugo", "482")]
    [InlineData("@Hugo#482", "hugo", "482")]
    [InlineData("  @HUGO.dias # 007 ", "hugo.dias", "007")]
    [InlineData("joao_silva#000", "joao_silva", "000")]
    public void ParseHandle_accepts_username_with_tag(string input, string username, string tag) =>
        Assert.Equal((username, tag), UsernameRules.ParseHandle(input));

    [Theory]
    [InlineData("hugo")]            // sem tag
    [InlineData("hugo#")]
    [InlineData("hugo#48")]
    [InlineData("hugo#4821")]
    [InlineData("hugo#abc")]
    [InlineData("#482")]
    [InlineData("hu#482")]          // username curto
    [InlineData("hu..go#482")]
    [InlineData("joão#482")]
    [InlineData("hu#go#482")]
    [InlineData("")]
    [InlineData(null)]
    public void ParseHandle_rejects_bad_input(string? input) => Assert.Null(UsernameRules.ParseHandle(input));

    [Fact]
    public void Tags_are_always_three_digits()
    {
        for (var i = 0; i < 2000; i++)
        {
            Assert.True(UsernameRules.IsValidTag(UsernameRules.NewTag()));
        }
    }

    [Theory]
    [InlineData("123", true)]
    [InlineData("000", true)]
    [InlineData("12", false)]
    [InlineData("1234", false)]
    [InlineData("12a", false)]
    [InlineData(null, false)]
    public void Tag_shape(string? tag, bool expected) => Assert.Equal(expected, UsernameRules.IsValidTag(tag));

    [Fact]
    public void Username_can_be_changed_once_a_month()
    {
        var now = new DateTime(2026, 10, 24, 12, 0, 0, DateTimeKind.Utc);
        Assert.Null(UsernameRules.NextChangeAt(null, now));                           // nunca mudou: livre
        Assert.Equal(now.AddDays(20), UsernameRules.NextChangeAt(now.AddDays(-10), now));
        Assert.Null(UsernameRules.NextChangeAt(now.AddDays(-30), now));               // passou exatamente 1 mês
        Assert.Null(UsernameRules.NextChangeAt(now.AddDays(-45), now));
        Assert.NotNull(UsernameRules.NextChangeAt(now.AddMinutes(-1), now));
    }

    [Fact]
    public void Limits_match_the_product_rules()
    {
        Assert.Equal(10, UsernameRules.MaxFailedLookupsPerHour);
        Assert.Equal(40, TeamRules.MaxPendingInvitesPerTeam);
        Assert.Equal(30, UsernameRules.ReservedAfterChangeDays);
    }
}
