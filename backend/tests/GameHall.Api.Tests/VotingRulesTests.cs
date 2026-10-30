using GameHall.Api.Modules.Voting;
using Xunit;

namespace GameHall.Api.Tests;

public class VotingRulesTests
{
    private static readonly Guid A = Guid.NewGuid();
    private static readonly Guid B = Guid.NewGuid();
    private static readonly Guid C = Guid.NewGuid();
    private static readonly DateTime Finished = new(2026, 10, 1, 20, 0, 0, DateTimeKind.Utc);

    private static List<Tally> T(params (Guid, int)[] v) => v.Select(x => new Tally(x.Item1, x.Item2)).ToList();

    [Fact]
    public void Leaders_ignores_zero_votes_and_returns_all_tied()
    {
        Assert.Empty(VotingRules.Leaders(T((A, 0), (B, 0))));
        Assert.Equal(new[] { A }, VotingRules.Leaders(T((A, 5), (B, 3), (C, 0))).ToArray());
        Assert.Equal(new[] { A, B }, VotingRules.Leaders(T((A, 4), (B, 4), (C, 1))).ToArray());
    }

    [Fact]
    public void Resolve_without_first_round_closed_is_none() =>
        Assert.Equal("none", VotingRules.Resolve(null, false, null, true).Status);

    [Fact]
    public void Resolve_clear_winner_is_final()
    {
        var r = VotingRules.Resolve(T((A, 5), (B, 3)), false, null, true);
        Assert.Equal(CategoryResult.Final, r.Status);
        Assert.Equal(new[] { A }, r.Winners.ToArray());
    }

    [Fact]
    public void Resolve_no_votes_is_none() =>
        Assert.Equal("none", VotingRules.Resolve(T((A, 0), (B, 0)), false, null, false).Status);

    [Fact]
    public void Resolve_tie_while_window_open_and_no_second_round_is_pending()
    {
        var r = VotingRules.Resolve(T((A, 4), (B, 4)), false, null, windowOpen: true);
        Assert.Equal(CategoryResult.Pending, r.Status);
        Assert.Equal(2, r.Winners.Count);
    }

    [Fact]
    public void Resolve_tie_after_window_without_second_round_gives_co_winners()
    {
        var r = VotingRules.Resolve(T((A, 4), (B, 4), (C, 2)), false, null, windowOpen: false);
        Assert.Equal(CategoryResult.Final, r.Status);
        Assert.Equal(new[] { A, B }, r.Winners.ToArray());
    }

    [Fact]
    public void Resolve_second_round_still_open_is_pending() =>
        Assert.Equal("pending", VotingRules.Resolve(T((A, 4), (B, 4)), true, null, true).Status);

    [Fact]
    public void Resolve_second_round_decides_one_winner()
    {
        var r = VotingRules.Resolve(T((A, 4), (B, 4)), true, T((A, 2), (B, 7)), false);
        Assert.Equal(CategoryResult.Final, r.Status);
        Assert.Equal(new[] { B }, r.Winners.ToArray());
    }

    [Fact]
    public void Resolve_second_round_tie_keeps_all_tied()
    {
        var r = VotingRules.Resolve(T((A, 4), (B, 4), (C, 4)), true, T((A, 3), (B, 3), (C, 1)), false);
        Assert.Equal(CategoryResult.Final, r.Status);
        Assert.Equal(new[] { A, B }, r.Winners.ToArray());
    }

    [Fact]
    public void Resolve_second_round_without_votes_falls_back_to_first_round_tie()
    {
        var r = VotingRules.Resolve(T((A, 4), (B, 4)), true, T((A, 0), (B, 0)), false);
        Assert.Equal(new[] { A, B }, r.Winners.ToArray());
    }

    [Fact]
    public void TiedCategories_only_lists_categories_with_a_tie()
    {
        var tied = VotingRules.TiedCategories(new Dictionary<string, IReadOnlyList<Tally>>
        {
            [VotingCategories.BestPlayer] = T((A, 3), (B, 3)),
            [VotingCategories.BestGoalkeeper] = T((C, 5), (A, 1)),
        });
        Assert.Single(tied);
        Assert.Equal(new[] { A, B }, tied[VotingCategories.BestPlayer].ToArray());
    }

    [Theory]
    [InlineData(0, 6, true)]
    [InlineData(5.9, 6, true)]
    [InlineData(6.0, 6, true)]
    [InlineData(6.1, 6, false)]
    [InlineData(3.0, 2, false)]
    public void Window_is_counted_from_the_last_result(double hoursAfter, int window, bool open) =>
        Assert.Equal(open, VotingRules.WindowOpen(Finished, window, Finished.AddHours(hoursAfter)));

    [Fact]
    public void Window_is_closed_when_the_tournament_has_not_finished() =>
        Assert.False(VotingRules.WindowOpen(null, 6, Finished));

    [Fact]
    public void WhyCannotOpen_covers_each_rule()
    {
        string? Why(string status = "finished", double hours = 1, int round = 1, bool exists = false,
                    DateTime? r1Closes = null, bool ties = false, int minutes = 60) =>
            VotingRules.WhyCannotOpen(
                status, status == "finished" ? Finished : null, 6, Finished.AddHours(hours), round, exists, r1Closes,
                ties, minutes, 30, 180);

        Assert.Null(Why());
        Assert.Equal("tournament_not_finished", Why(status: "ongoing"));
        Assert.Equal("voting_window_closed", Why(hours: 7));
        Assert.Equal("round_already_exists", Why(exists: true));
        Assert.Equal("invalid_duration", Why(minutes: 10));
        Assert.Equal("invalid_duration", Why(minutes: 600));
        Assert.Equal("no_first_round", Why(round: 2, ties: true));
        Assert.Equal("previous_round_open", Why(round: 2, r1Closes: Finished.AddHours(2), hours: 1.5, ties: true));
        Assert.Equal("no_tie", Why(round: 2, r1Closes: Finished.AddHours(1), hours: 1.5));
        Assert.Null(Why(round: 2, r1Closes: Finished.AddHours(1), hours: 1.5, ties: true));
        // Cada ronda tem de acabar dentro da janela (6 h): 5 h + 60 min cabe exatamente, 5,5 h + 60 min não.
        Assert.Null(Why(hours: 5, minutes: 60));
        Assert.Equal("round_exceeds_window", Why(hours: 5.5, minutes: 60));
        Assert.Equal("round_exceeds_window", Why(round: 2, r1Closes: Finished.AddHours(1), hours: 5.2, ties: true, minutes: 60));
        // A ronda 2 também tem de ser aberta dentro da janela.
        Assert.Equal("voting_window_closed", Why(round: 2, r1Closes: Finished.AddHours(1), hours: 6.5, ties: true));
    }

    [Fact]
    public void WhyCannotVote_rules()
    {
        var now = Finished.AddHours(1);
        string? Why(bool participant = false, DateTime? verified = null, bool open = true, bool self = false) =>
            VotingRules.WhyCannotVote(participant, verified, now, 24, open, self);

        Assert.Equal("voting_closed", Why(participant: true, open: false));
        Assert.Equal("cannot_vote_self", Why(participant: true, self: true));
        Assert.Null(Why(participant: true));                                          // participantes votam sempre
        Assert.Null(Why(verified: now.AddHours(-25)));                                // email verificado há mais de 1 dia
        Assert.Equal("email_not_verified_long_enough", Why(verified: now.AddHours(-23)));
        Assert.Equal("email_not_verified_long_enough", Why());
    }
}
