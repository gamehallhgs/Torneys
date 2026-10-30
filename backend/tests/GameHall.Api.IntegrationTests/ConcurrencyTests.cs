using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Voting;
using Xunit;

namespace GameHall.Api.IntegrationTests;

/// <summary>Várias pessoas (ou tarefas) ao mesmo tempo: o resultado tem de ser sempre o mesmo que em fila.</summary>
public class ConcurrencyTests : DbTest
{
    [PgFact]
    public async Task Parallel_sweeps_never_reserve_more_slots_than_the_tournament_has()
    {
        var t = await Seed.TournamentAsync(Src, maxTeams: 2);
        var teams = new List<Guid>();
        for (var i = 0; i < 5; i++)
        {
            var host = await Seed.UserAsync(Src);
            teams.Add(await Seed.TeamAsync(Src, t, host, closedAgo: TimeSpan.FromMinutes(50 - i)));   // mais antiga primeiro
        }

        await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Reservations().SweepAsync(t, CancellationToken.None)));

        Assert.Equal(2, await ScalarAsync<int>(
            "SELECT count(*)::int FROM teams WHERE tournament_id = @T AND reserved_at IS NOT NULL", new { T = t }));

        // As duas primeiras da fila (as que fecharam há mais tempo) ficaram com a vaga.
        var reserved = (await ScalarAsync<Guid[]>(
            "SELECT array_agg(id) FROM teams WHERE tournament_id = @T AND reserved_at IS NOT NULL", new { T = t })).ToHashSet();
        Assert.Contains(teams[0], reserved);
        Assert.Contains(teams[1], reserved);

        // Cada membro das equipas com vaga foi avisado uma só vez.
        Assert.Equal(2, await ScalarAsync<int>("SELECT count(*)::int FROM notifications WHERE type = 'slot_reserved'"));
    }

    [PgFact]
    public async Task Everyone_paying_at_the_same_time_confirms_the_team_exactly_once()
    {
        var t = await Seed.TournamentAsync(Src, maxTeams: 4);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host, closedAgo: TimeSpan.FromMinutes(5), reserved: true);
        var members = new List<Guid> { host };
        for (var i = 0; i < 4; i++)
        {
            var m = await Seed.UserAsync(Src);
            members.Add(m);
            await Seed.MemberAsync(Src, team, t, m);
        }

        var results = await Task.WhenAll(members.Select(m => Teams().PayAsync(m, team, CancellationToken.None)));

        Assert.All(results, r => Assert.Null(r));
        Assert.Equal(5, await ScalarAsync<int>(
            "SELECT count(*)::int FROM team_members WHERE team_id = @Id AND paid_at IS NOT NULL", new { Id = team }));
        Assert.True(await ScalarAsync<bool>("SELECT confirmed_at IS NOT NULL FROM teams WHERE id = @Id", new { Id = team }));
        Assert.Equal(5, await ScalarAsync<int>("SELECT count(*)::int FROM notifications WHERE type = 'team_confirmed'"));
    }

    [PgFact]
    public async Task Paying_twice_at_the_same_time_is_refused_once()
    {
        var t = await Seed.TournamentAsync(Src);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host, closedAgo: TimeSpan.FromMinutes(5), reserved: true);
        await Seed.MemberAsync(Src, team, t, await Seed.UserAsync(Src));

        var results = await Task.WhenAll(Enumerable.Range(0, 2).Select(_ => Teams().PayAsync(host, team, CancellationToken.None)));

        Assert.Equal(1, results.Count(r => r is null));
        Assert.Equal(1, results.Count(r => r is { Code: "already_paid" }));
    }

    [PgFact]
    public async Task Two_players_racing_for_the_same_username_only_one_wins()
    {
        var a = await Seed.UserAsync(Src);
        var b = await Seed.UserAsync(Src);
        var store = new UsernameStore(Src);

        var results = await Task.WhenAll(
            store.ChangeAsync(a, "nome.disputado", DateTime.UtcNow, CancellationToken.None),
            store.ChangeAsync(b, "nome.disputado", DateTime.UtcNow, CancellationToken.None));

        Assert.Equal(1, results.Count(r => r.Result == UsernameChangeResult.Changed));
        Assert.Equal(1, results.Count(r => r.Result == UsernameChangeResult.Taken));
        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM users WHERE username = 'nome.disputado'"));
    }

    [PgFact]
    public async Task One_player_changing_username_twice_at_once_only_gets_the_free_change_once()
    {
        var a = await Seed.UserAsync(Src);
        var store = new UsernameStore(Src);

        var results = await Task.WhenAll(
            store.ChangeAsync(a, "primeiro.nome", DateTime.UtcNow, CancellationToken.None),
            store.ChangeAsync(a, "segundo.nome", DateTime.UtcNow, CancellationToken.None));

        Assert.Equal(1, results.Count(r => r.Result == UsernameChangeResult.Changed));
        Assert.Equal(1, results.Count(r => r.Result == UsernameChangeResult.ChangeUsed));
    }

    [PgFact]
    public async Task Many_parallel_votes_from_one_voter_leave_a_single_vote()
    {
        var (t, round, candidates, voter) = await VotingFlowTests.OpenRoundAsync(Src, Voting());
        var service = Voting();

        await Task.WhenAll(candidates.Take(4).Select(c =>
            service.VoteAsync(t, voter, VotingCategories.BestPlayer, c, CancellationToken.None)));

        Assert.Equal(1, await ScalarAsync<int>(
            "SELECT count(*)::int FROM votes WHERE round_id = @R AND voter_id = @V", new { R = round, V = voter }));
    }
}
