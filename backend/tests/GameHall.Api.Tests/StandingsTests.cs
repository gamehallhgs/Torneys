using GameHall.Api.Modules.Games;
using Xunit;

namespace GameHall.Api.Tests;

public class StandingsTests
{
    private static readonly StandingTeam A = new(Guid.NewGuid(), "Águias", "#E53935");
    private static readonly StandingTeam B = new(Guid.NewGuid(), "Bravos", "#1E88E5");
    private static readonly StandingTeam C = new(Guid.NewGuid(), "Cometas", "#43A047");
    private static readonly StandingTeam D = new(Guid.NewGuid(), "Dragões", "#FDD835");

    private static readonly IReadOnlyDictionary<Guid, (int Yellow, int Red)> NoCards =
        new Dictionary<Guid, (int Yellow, int Red)>();

    private static StandingGame G(StandingTeam h, int hg, int ag, StandingTeam a) => new(h.Id, a.Id, hg, ag);

    private static string[] Order(IReadOnlyList<StandingRowDto> rows) => rows.Select(r => r.Name).ToArray();

    [Fact]
    public void Points_are_3_for_a_win_and_1_for_a_draw()
    {
        var rows = StandingsCalculator.Compute(
            [A, B], [G(A, 2, 1, B), G(B, 1, 1, A)], NoCards, ["points"]);

        var a = rows.Single(r => r.TeamId == A.Id);
        Assert.Equal(4, a.Points);
        Assert.Equal((2, 1, 1, 0), (a.Played, a.Won, a.Drawn, a.Lost));
        Assert.Equal((3, 2, 1), (a.GoalsFor, a.GoalsAgainst, a.GoalDifference));
        Assert.Equal(1, rows.Single(r => r.TeamId == B.Id).Points);
        Assert.Equal(1, rows[0].Position);
        Assert.Equal(2, rows[1].Position);
    }

    [Fact]
    public void Teams_without_games_still_appear()
    {
        var rows = StandingsCalculator.Compute([A, B, C], [G(A, 1, 0, B)], NoCards, ["points"]);
        Assert.Equal(3, rows.Count);
        Assert.Equal(0, rows.Single(r => r.TeamId == C.Id).Played);
    }

    [Fact]
    public void Goal_difference_breaks_a_points_tie_then_name_decides()
    {
        // Todos com 3 pontos. Diferenças: A +2, B 0, C -2, D 0 (B e D desempatam por nome).
        var games = new[] { G(A, 3, 0, C), G(B, 1, 0, D), G(C, 1, 0, B), G(D, 1, 0, A) };
        var rows = StandingsCalculator.Compute([A, B, C, D], games, NoCards, ["points", "goal_difference"]);
        Assert.Equal(new[] { "Águias", "Bravos", "Dragões", "Cometas" }, Order(rows));
    }

    [Fact]
    public void Head_to_head_and_goal_difference_follow_the_configured_order()
    {
        // A e B ficam com 6 pontos. B ganhou o jogo entre os dois; A tem muito melhor diferença de golos.
        var games = new[]
        {
            G(B, 1, 0, A),
            G(A, 5, 0, C),
            G(A, 5, 0, D),
            G(B, 1, 0, C),
            G(D, 1, 0, B),
        };

        var h2hFirst = StandingsCalculator.Compute([A, B, C, D], games, NoCards, ["points", "head_to_head", "goal_difference"]);
        var gdFirst = StandingsCalculator.Compute([A, B, C, D], games, NoCards, ["points", "goal_difference", "head_to_head"]);

        Assert.Equal(6, h2hFirst.Single(r => r.TeamId == A.Id).Points);
        Assert.Equal(6, h2hFirst.Single(r => r.TeamId == B.Id).Points);
        Assert.Equal("Bravos", h2hFirst[0].Name);
        Assert.Equal("Águias", h2hFirst[1].Name);
        Assert.Equal("Águias", gdFirst[0].Name);
        Assert.Equal("Bravos", gdFirst[1].Name);
    }

    [Fact]
    public void Fair_play_prefers_fewer_cards_and_a_red_counts_triple()
    {
        var cards = new Dictionary<Guid, (int Yellow, int Red)>
        {
            [A.Id] = (0, 1),  // 3 pontos de fair play
            [B.Id] = (2, 0),  // 2 pontos de fair play
        };
        var rows = StandingsCalculator.Compute([A, B], [G(A, 1, 1, B)], cards, ["points", "fair_play"]);
        Assert.Equal("Bravos", rows[0].Name);
        Assert.Equal(1, rows.Single(r => r.TeamId == A.Id).RedCards);
        Assert.Equal(2, rows.Single(r => r.TeamId == B.Id).YellowCards);
    }

    [Fact]
    public void Goals_against_prefers_fewer_goals_conceded()
    {
        // A 2-1 B e C 3-2 D: A e C com 3 pontos; A sofreu 1, C sofreu 2. B sofreu 2, D sofreu 3.
        var games = new[] { G(A, 2, 1, B), G(C, 3, 2, D) };
        var rows = StandingsCalculator.Compute([A, B, C, D], games, NoCards, ["points", "goals_against"]);
        Assert.Equal(new[] { "Águias", "Cometas", "Bravos", "Dragões" }, Order(rows));
    }

    [Fact]
    public void Remaining_ties_fall_back_to_name_order_ignoring_accents()
    {
        var zebras = new StandingTeam(Guid.NewGuid(), "Zebras", "#212121");
        var rows = StandingsCalculator.Compute([zebras, B, A], [], NoCards, ["draw", "penalties", "inventado"]);
        Assert.Equal(new[] { "Águias", "Bravos", "Zebras" }, Order(rows));
    }

    [Fact]
    public void Points_always_come_first_even_if_configured_later()
    {
        // Pontos: C 3, A 3, D 1, B 1. Diferenças: C +5, A -4, D 0, B -1.
        var games = new[] { G(A, 1, 0, B), G(C, 5, 0, A), G(D, 3, 3, B) };
        var rows = StandingsCalculator.Compute([A, B, C, D], games, NoCards, ["goal_difference", "points"]);
        Assert.Equal(new[] { "Cometas", "Águias", "Dragões", "Bravos" }, Order(rows));
    }

    [Fact]
    public void Games_with_unknown_teams_are_ignored()
    {
        var rows = StandingsCalculator.Compute([A, B], [G(A, 1, 0, C)], NoCards, ["points"]);
        Assert.All(rows, r => Assert.Equal(0, r.Played));
    }

    private static StandingsGameRow Row(StandingTeam? h, StandingTeam? a, int? hg, int? ag, string status, string? group) =>
        new() { HomeTeamId = h?.Id, AwayTeamId = a?.Id, HomeGoals = hg, AwayGoals = ag, Status = status, GroupName = group };

    [Fact]
    public void League_builds_a_single_group_with_all_teams_and_only_finished_games()
    {
        var games = new[]
        {
            Row(A, B, 2, 0, "finished", null),
            Row(B, C, 1, 0, "scheduled", null),
            Row(A, C, null, null, "running", null),
        };
        var groups = StandingsCalculator.BuildGroups("league", [A, B, C], games, NoCards, ["points"]);
        var g = Assert.Single(groups);
        Assert.Null(g.Name);
        Assert.Equal(3, g.Rows.Count);
        Assert.Equal(3, g.Rows.Single(r => r.TeamId == A.Id).Points);
        Assert.Equal(1, g.Rows.Single(r => r.TeamId == B.Id).Played);
        Assert.Equal(0, g.Rows.Single(r => r.TeamId == C.Id).Played);
    }

    [Fact]
    public void Group_stage_builds_one_group_per_name_ordered_by_name()
    {
        var games = new[]
        {
            Row(C, D, 1, 0, "finished", "Grupo B"),
            Row(A, B, 0, 0, "finished", "Grupo A"),
        };
        var groups = StandingsCalculator.BuildGroups("groups_knockout", [A, B, C, D], games, NoCards, ["points"]);
        Assert.Equal(new[] { "Grupo A", "Grupo B" }, groups.Select(g => g.Name).ToArray());
        Assert.All(groups, g => Assert.Equal(2, g.Rows.Count));
    }

    [Theory]
    [InlineData("single_elimination")]
    [InlineData("double_elimination")]
    public void Knockout_formats_have_no_table(string format) =>
        Assert.Empty(StandingsCalculator.BuildGroups(format, [A, B], [], NoCards, ["points"]));

    [Theory]
    [InlineData("scheduled", true)]
    [InlineData("running", true)]
    [InlineData("finished", true)]
    [InlineData("cancelled", true)]
    [InlineData("postponed", true)]
    [InlineData("done", false)]
    [InlineData(null, false)]
    public void Game_status_validation(string? status, bool valid) =>
        Assert.Equal(valid, GameRules.IsValidStatus(status));
}
