using GameHall.Api.Modules.Teams;
using GameHall.Api.Modules.Tournaments;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace GameHall.Api.IntegrationTests;

/// <summary>O ciclo de vida de um torneio: inscrições abertas → fechadas → a decorrer → terminado.</summary>
public class LifecycleTests : DbTest
{
    private RegistrationLifecycleService Registration() =>
        new(Src, Config(), NullLogger<RegistrationLifecycleService>.Instance);

    private TournamentLifecycleService Tournaments() =>
        new(Src, Config(), NullLogger<TournamentLifecycleService>.Instance);

    private Task<string> StatusAsync(Guid id) => ScalarAsync<string>("SELECT status FROM tournaments WHERE id = @Id", new { Id = id });

    [PgFact]
    public async Task Deadline_closes_registration_and_removes_teams_that_never_closed()
    {
        var t = await Seed.TournamentAsync(Src, closesIn: TimeSpan.FromHours(-1));
        var hostA = await Seed.UserAsync(Src);
        var hostB = await Seed.UserAsync(Src);
        var open = await Seed.TeamAsync(Src, t, hostA);                                  // nunca fechou
        var closed = await Seed.TeamAsync(Src, t, hostB, closedAgo: TimeSpan.FromHours(2)); // fechada (em fila)

        var (closedCount, removed) = await Registration().RunOnceAsync(CancellationToken.None);

        Assert.Equal(1, closedCount);
        Assert.Equal(1, removed);
        Assert.Equal("registration_closed", await StatusAsync(t));
        Assert.Equal(0, await ScalarAsync<int>("SELECT count(*)::int FROM teams WHERE id = @Id", new { Id = open }));
        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM teams WHERE id = @Id", new { Id = closed }));
        Assert.Equal(1, await NotificationsAsync(hostA, "team_eliminated"));
        Assert.Equal(0, await NotificationsAsync(hostB, "team_eliminated"));
    }

    [PgFact]
    public async Task Demo_teams_are_never_removed()
    {
        var t = await Seed.TournamentAsync(Src, closesIn: TimeSpan.FromHours(-1));
        var demo = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), demo: true);

        await Registration().RunOnceAsync(CancellationToken.None);

        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM teams WHERE id = @Id", new { Id = demo }));
    }

    [PgFact]
    public async Task Registration_stays_open_before_the_deadline_and_a_second_run_changes_nothing()
    {
        var future = await Seed.TournamentAsync(Src, closesIn: TimeSpan.FromDays(1));
        var past = await Seed.TournamentAsync(Src, closesIn: TimeSpan.FromHours(-1));

        var first = await Registration().RunOnceAsync(CancellationToken.None);
        var second = await Registration().RunOnceAsync(CancellationToken.None);

        Assert.Equal(1, first.Closed);
        Assert.Equal(0, second.Closed);
        Assert.Equal("registration_open", await StatusAsync(future));
        Assert.Equal("registration_closed", await StatusAsync(past));
    }

    [PgFact]
    public async Task Tournament_goes_ongoing_when_the_first_game_time_arrives()
    {
        var early = await Seed.TournamentAsync(Src, status: "registration_closed");
        await Seed.GameAsync(Src, early, null, null, TimeSpan.FromMinutes(-5));
        var later = await Seed.TournamentAsync(Src, status: "registration_closed");
        await Seed.GameAsync(Src, later, null, null, TimeSpan.FromHours(3));
        var noGames = await Seed.TournamentAsync(Src, status: "registration_closed");

        var (started, _) = await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal(1, started);
        Assert.Equal("ongoing", await StatusAsync(early));
        Assert.Equal("registration_closed", await StatusAsync(later));
        Assert.Equal("registration_closed", await StatusAsync(noGames));
    }

    [PgFact]
    public async Task Cancelled_games_do_not_start_the_tournament()
    {
        var t = await Seed.TournamentAsync(Src, status: "registration_closed");
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromMinutes(-5), status: "cancelled");

        await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal("registration_closed", await StatusAsync(t));
    }

    [PgFact]
    public async Task Tournament_finishes_when_the_last_result_is_published_and_records_the_voting_window()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(-3), status: "finished", homeGoals: 2, awayGoals: 1);
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(-1), status: "cancelled");

        var (_, finished) = await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal(1, finished);
        Assert.Equal("finished", await StatusAsync(t));
        Assert.True(await ScalarAsync<bool>("SELECT finished_at IS NOT NULL FROM tournaments WHERE id = @Id", new { Id = t }));
        Assert.Equal(6, await ScalarAsync<int>("SELECT voting_window_hours FROM tournaments WHERE id = @Id", new { Id = t }));
    }

    [PgFact]
    public async Task Voting_window_uses_the_current_admin_setting()
    {
        await ExecAsync("UPDATE platform_settings SET value = '3' WHERE key = 'voting_window_hours'");
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(-1), status: "finished", homeGoals: 1, awayGoals: 0);

        await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal(3, await ScalarAsync<int>("SELECT voting_window_hours FROM tournaments WHERE id = @Id", new { Id = t }));
    }

    /// <summary>
    /// Documentado em docs/PAPEIS_E_PERMISSOES.md: um jogo adiado ou por jogar mantém o torneio "a decorrer"
    /// para sempre; o painel do gestor tem de o cancelar ou terminar o torneio à mão.
    /// </summary>
    [PgFact]
    public async Task A_postponed_game_keeps_the_tournament_ongoing_until_it_is_cancelled()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(-3), status: "finished", homeGoals: 1, awayGoals: 0);
        var postponed = await Seed.GameAsync(Src, t, null, null, null, status: "postponed");

        for (var i = 0; i < 3; i++)
        {
            await Tournaments().RunOnceAsync(CancellationToken.None);
        }

        Assert.Equal("ongoing", await StatusAsync(t));

        await ExecAsync("UPDATE games SET status = 'cancelled' WHERE id = @Id", new { Id = postponed });
        await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal("finished", await StatusAsync(t));
    }

    [PgFact]
    public async Task A_tournament_with_only_cancelled_games_never_finishes_by_itself()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(-3), status: "cancelled");

        await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal("ongoing", await StatusAsync(t));
    }

    [PgFact]
    public async Task A_running_or_scheduled_game_blocks_the_end()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(-3), status: "finished", homeGoals: 1, awayGoals: 0);
        await Seed.GameAsync(Src, t, null, null, TimeSpan.FromHours(2), status: "scheduled");

        await Tournaments().RunOnceAsync(CancellationToken.None);

        Assert.Equal("ongoing", await StatusAsync(t));
    }
}
