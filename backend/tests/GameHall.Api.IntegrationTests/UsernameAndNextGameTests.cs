using Dapper;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Games;
using Xunit;

namespace GameHall.Api.IntegrationTests;

public class UsernameTests : DbTest
{
    private UsernameStore Store() => new(Src);

    [PgFact]
    public async Task The_free_change_works_once_and_the_second_is_refused()
    {
        var u = await Seed.UserAsync(Src);

        var first = await Store().ChangeAsync(u, "novo.nome", DateTime.UtcNow, CancellationToken.None);
        var second = await Store().ChangeAsync(u, "outro.nome", DateTime.UtcNow, CancellationToken.None);

        Assert.Equal(UsernameChangeResult.Changed, first.Result);
        Assert.Equal(UsernameChangeResult.ChangeUsed, second.Result);
        Assert.Equal("novo.nome", await ScalarAsync<string>("SELECT username FROM users WHERE id = @Id", new { Id = u }));
    }

    [PgFact]
    public async Task Even_a_year_later_the_second_change_is_still_refused()
    {
        var u = await Seed.UserAsync(Src);
        await Store().ChangeAsync(u, "novo.nome", DateTime.UtcNow, CancellationToken.None);

        var later = await Store().ChangeAsync(u, "outro.nome", DateTime.UtcNow.AddYears(1), CancellationToken.None);

        Assert.Equal(UsernameChangeResult.ChangeUsed, later.Result);
    }

    [PgFact]
    public async Task The_old_username_stays_reserved_for_30_days_for_everyone_else()
    {
        var a = await Seed.UserAsync(Src);
        var b = await Seed.UserAsync(Src);
        var old = await ScalarAsync<string>("SELECT username FROM users WHERE id = @Id", new { Id = a });
        await Store().ChangeAsync(a, "novo.nome", DateTime.UtcNow, CancellationToken.None);

        var tooSoon = await Store().ChangeAsync(b, old, DateTime.UtcNow.AddDays(10), CancellationToken.None);
        Assert.Equal(UsernameChangeResult.RecentlyUsed, tooSoon.Result);

        var later = await Store().ChangeAsync(b, old, DateTime.UtcNow.AddDays(31), CancellationToken.None);
        Assert.Equal(UsernameChangeResult.Changed, later.Result);
    }

    [PgFact]
    public async Task A_taken_username_is_refused_and_does_not_burn_the_free_change()
    {
        var a = await Seed.UserAsync(Src);
        var b = await Seed.UserAsync(Src);
        var taken = await ScalarAsync<string>("SELECT username FROM users WHERE id = @Id", new { Id = a });

        var r = await Store().ChangeAsync(b, taken, DateTime.UtcNow, CancellationToken.None);
        Assert.Equal(UsernameChangeResult.Taken, r.Result);

        var ok = await Store().ChangeAsync(b, "livre.mesmo", DateTime.UtcNow, CancellationToken.None);
        Assert.Equal(UsernameChangeResult.Changed, ok.Result);
    }

    [PgFact]
    public async Task Changing_to_the_same_username_changes_nothing()
    {
        var u = await Seed.UserAsync(Src);
        var same = await ScalarAsync<string>("SELECT username FROM users WHERE id = @Id", new { Id = u });

        var r = await Store().ChangeAsync(u, same, DateTime.UtcNow, CancellationToken.None);

        Assert.Equal(UsernameChangeResult.Unchanged, r.Result);
        Assert.Equal(1, UsernameRules.ChangesLeft(null));
    }
}

public class NextGamesTests : DbTest
{
    [PgFact]
    public async Task Shows_the_next_tournament_game_and_the_players_own_next_game()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        var me = await Seed.UserAsync(Src);
        var other = await Seed.UserAsync(Src);
        var mine = await Seed.TeamAsync(Src, t, me, confirmed: true);
        var rival = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), confirmed: true);
        var c = await Seed.TeamAsync(Src, t, other, confirmed: true);
        var d = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), confirmed: true);

        var earliestNotMine = await Seed.GameAsync(Src, t, c, d, TimeSpan.FromHours(1));
        var myNext = await Seed.GameAsync(Src, t, mine, rival, TimeSpan.FromHours(2));
        await Seed.GameAsync(Src, t, mine, c, TimeSpan.FromHours(5));
        await Seed.GameAsync(Src, t, mine, d, TimeSpan.FromHours(-3), status: "finished", homeGoals: 1, awayGoals: 0);

        var (next, mineNext) = await new GameStore(Src).NextGamesAsync(t, me, CancellationToken.None);

        Assert.Equal(earliestNotMine, next!.Id);
        Assert.Equal(myNext, mineNext!.Id);
    }

    [PgFact]
    public async Task A_running_game_comes_first_and_postponed_or_dateless_games_are_ignored()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        var a = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), confirmed: true);
        var b = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), confirmed: true);
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromHours(1));
        var running = await Seed.GameAsync(Src, t, a, b, TimeSpan.FromMinutes(-20), status: "running");
        await Seed.GameAsync(Src, t, a, b, null, status: "postponed");
        await Seed.GameAsync(Src, t, a, b, null);

        var (next, _) = await new GameStore(Src).NextGamesAsync(t, Guid.NewGuid(), CancellationToken.None);

        Assert.Equal(running, next!.Id);
    }

    [PgFact]
    public async Task A_spectator_gets_no_personal_next_game_and_an_empty_tournament_has_none()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        var a = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), confirmed: true);
        var b = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), confirmed: true);
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromHours(1));
        var empty = await Seed.TournamentAsync(Src, status: "ongoing");

        var watching = await new GameStore(Src).NextGamesAsync(t, await Seed.UserAsync(Src), CancellationToken.None);
        var none = await new GameStore(Src).NextGamesAsync(empty, await Seed.UserAsync(Src), CancellationToken.None);

        Assert.NotNull(watching.Next);
        Assert.Null(watching.Mine);
        Assert.Null(none.Next);
        Assert.Null(none.Mine);
    }
}
