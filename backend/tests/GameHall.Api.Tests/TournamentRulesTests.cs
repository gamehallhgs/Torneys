using GameHall.Api.Modules.Tournaments;
using Xunit;

namespace GameHall.Api.Tests;

public class TournamentRulesTests
{
    [Theory]
    [InlineData(13, null, "13+")]
    [InlineData(18, null, "18+")]
    [InlineData(16, 18, "16-18")]
    public void AgeLabel_formats_range(int min, int? max, string expected) =>
        Assert.Equal(expected, TournamentRules.AgeLabel(min, max));

    [Fact]
    public void Can_create_team_when_open_age_ok_and_not_full() =>
        Assert.Null(TournamentRules.WhyCannotCreateTeam("registration_open", 3, 8, 16, null, 20));

    [Theory]
    [InlineData("registration_closed", 3, 8, 16, null, 20, "registration_closed")]
    [InlineData("ongoing", 3, 8, 16, null, 20, "registration_closed")]
    [InlineData("finished", 3, 8, 16, null, 20, "registration_closed")]
    [InlineData("registration_open", 3, 8, 18, null, 17, "age_too_young")]
    [InlineData("registration_open", 3, 8, 13, 17, 18, "age_too_old")]
    [InlineData("registration_open", 8, 8, 13, null, 20, "tournament_full")]
    public void Cannot_create_team_reasons(
        string status, int teams, int maxTeams, int minAge, int? maxAge, int userAge, string reason) =>
        Assert.Equal(reason, TournamentRules.WhyCannotCreateTeam(status, teams, maxTeams, minAge, maxAge, userAge));

    [Fact]
    public void Age_limits_are_inclusive()
    {
        Assert.Null(TournamentRules.WhyCannotCreateTeam("registration_open", 0, 8, 16, 18, 16));
        Assert.Null(TournamentRules.WhyCannotCreateTeam("registration_open", 0, 8, 16, 18, 18));
    }

    [Theory]
    [InlineData(null, new[] { "registration_open", "registration_closed", "ongoing", "finished" })]
    [InlineData("open", new[] { "registration_open" })]
    [InlineData("ongoing", new[] { "registration_closed", "ongoing" })]
    [InlineData("finished", new[] { "finished" })]
    [InlineData("mine", new[] { "registration_open", "registration_closed", "ongoing", "finished" })]
    public void Status_filters_map_to_statuses(string? filter, string[] expected) =>
        Assert.Equal(expected, TournamentStore.StatusesFor(filter));
}
