using GameHall.Api.Modules.Teams;
using GameHall.Api.Modules.Tournaments;
using Xunit;

namespace GameHall.Api.Tests;

public class TeamRulesTests
{
    [Theory]
    [InlineData("  Águias   do  Tejo ", "Águias do Tejo")]
    [InlineData("Leões", "Leões")]
    [InlineData("", "")]
    public void NormalizeName_trims_and_collapses_spaces(string raw, string expected) =>
        Assert.Equal(expected, TeamRules.NormalizeName(raw));

    [Theory]
    [InlineData("Águias do Tejo", true)]
    [InlineData("FC 7 & Amigos", true)]
    [InlineData("O'Brien Boys", true)]
    [InlineData("abc", true)]
    [InlineData("ab", false)]
    [InlineData("", false)]
    [InlineData("<script>alert(1)</script>", false)]
    [InlineData(" começa com espaço", false)]
    [InlineData("-começa com hífen", false)]
    public void ValidateName_accepts_only_reasonable_names(string name, bool valid) =>
        Assert.Equal(valid, TeamRules.ValidateName(name) is null);

    [Fact]
    public void ValidateName_limits_length_to_30()
    {
        Assert.Null(TeamRules.ValidateName(new string('a', 30)));
        Assert.NotNull(TeamRules.ValidateName(new string('a', 31)));
    }

    [Theory]
    [InlineData("#e53935", "#E53935")]
    [InlineData(" #1e88e5 ", "#1E88E5")]
    [InlineData("#FFF", null)]
    [InlineData("red", null)]
    [InlineData("#GGGGGG", null)]
    [InlineData(null, null)]
    public void NormalizeColor_returns_uppercase_hex_or_null(string? raw, string? expected) =>
        Assert.Equal(expected, TeamRules.NormalizeColor(raw));

    [Fact]
    public void Positions_are_the_fifa_set()
    {
        Assert.Equal(15, TeamRules.Positions.Length);
        Assert.Equal(15, TeamRules.Positions.Distinct().Count());
        Assert.True(TeamRules.IsValidPosition("GK"));
        Assert.True(TeamRules.IsValidPosition("ST"));
        Assert.False(TeamRules.IsValidPosition("gk"));
        Assert.False(TeamRules.IsValidPosition("XX"));
        Assert.False(TeamRules.IsValidPosition(null));
    }

    // JoinBlockedReason(teamHasHost, isMember, status, inOtherTeam, minAge, maxAge, userAge, members, maxPlayers, pending)
    [Fact]
    public void Can_request_join_when_everything_is_ok() =>
        Assert.Null(TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 5, 14, false));

    [Theory]
    [InlineData(false, false, "registration_open", false, 20, 5, false, "team_not_joinable")]
    [InlineData(true, true, "registration_open", false, 20, 5, false, "already_member")]
    [InlineData(true, false, "registration_closed", false, 20, 5, false, "registration_closed")]
    [InlineData(true, false, "registration_open", true, 20, 5, false, "already_in_team")]
    [InlineData(true, false, "registration_open", false, 15, 5, false, "age_too_young")]
    [InlineData(true, false, "registration_open", false, 20, 14, false, "team_full")]
    [InlineData(true, false, "registration_open", false, 20, 5, true, "request_pending")]
    public void Join_blocked_reasons(
        bool hasHost, bool isMember, string status, bool otherTeam, int age, int members, bool pending, string reason) =>
        Assert.Equal(reason, TeamRules.JoinBlockedReason(hasHost, isMember, status, otherTeam, 16, null, age, members, 14, pending));

    [Fact]
    public void Confirmed_team_is_closed_to_new_members()
    {
        // Depois de "registration_closed", antes de "already_in_team".
        Assert.Equal("team_confirmed",
            TeamRules.JoinBlockedReason(true, false, "registration_open", true, 16, null, 20, 5, 14, false, teamConfirmed: true));
        Assert.Equal("registration_closed",
            TeamRules.JoinBlockedReason(true, false, "registration_closed", false, 16, null, 20, 5, 14, false, teamConfirmed: true));
        Assert.Equal("already_member",
            TeamRules.JoinBlockedReason(true, true, "registration_open", false, 16, null, 20, 5, 14, false, teamConfirmed: true));
    }

    [Fact]
    public void Team_creation_is_unlimited_until_confirmed_teams_fill_the_tournament()
    {
        // 8 vagas: com 7 confirmadas ainda se pode criar equipa (mesmo que existam 30 em formação).
        Assert.Null(TournamentRules.WhyCannotCreateTeam("registration_open", 7, 8, 16, null, 20));
        Assert.Equal("tournament_full", TournamentRules.WhyCannotCreateTeam("registration_open", 8, 8, 16, null, 20));
        Assert.Equal("tournament_full", TournamentRules.WhyCannotCreateTeam("registration_open", 9, 8, 16, null, 20));
    }

    [Fact]
    public void Join_blocked_when_too_old()
    {
        Assert.Equal("age_too_old",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 13, 17, 18, 3, 12, false));
        Assert.Null(
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 13, 17, 17, 3, 12, false));
    }

    [Fact]
    public void WhyCannotParticipate_checks_status_before_age()
    {
        Assert.Equal("registration_closed", TournamentRules.WhyCannotParticipate("ongoing", 18, null, 10));
        Assert.Equal("age_too_young", TournamentRules.WhyCannotParticipate("registration_open", 18, null, 17));
        Assert.Null(TournamentRules.WhyCannotParticipate("registration_open", 18, null, 18));
    }
}
