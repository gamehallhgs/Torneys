using GameHall.Api.Modules.Voting;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Xunit;

namespace GameHall.Api.IntegrationTests;

public class VotingFlowTests : DbTest
{
    /// <summary>Torneio terminado há 1 hora com 2 equipas confirmadas (uma com guarda-redes), mais um votante participante.</summary>
    private sealed record Setup(Guid Tournament, Guid TeamA, Guid TeamB, List<Guid> Players, Guid Keeper, Guid Outsider);

    private async Task<Setup> FinishedTournamentAsync(TimeSpan? finishedAgo = null, int windowHours = 6)
    {
        var t = await Seed.TournamentAsync(Src, status: "finished", finishedAgo: finishedAgo ?? TimeSpan.FromHours(1), windowHours: windowHours);
        var hostA = await Seed.UserAsync(Src);
        var hostB = await Seed.UserAsync(Src);
        var teamA = await Seed.TeamAsync(Src, t, hostA, closedAgo: TimeSpan.FromDays(1), confirmed: true);
        var teamB = await Seed.TeamAsync(Src, t, hostB, closedAgo: TimeSpan.FromDays(1), confirmed: true);
        var players = new List<Guid> { hostA, hostB };
        for (var i = 0; i < 2; i++)
        {
            var p = await Seed.UserAsync(Src);
            players.Add(p);
            await Seed.MemberAsync(Src, i == 0 ? teamA : teamB, t, p, "CM", paid: true);
        }

        var keeper = await Seed.UserAsync(Src);
        await Seed.MemberAsync(Src, teamA, t, keeper, "GK", paid: true);
        var outsider = await Seed.UserAsync(Src, verifiedAgo: TimeSpan.FromDays(5));
        return new Setup(t, teamA, teamB, players, keeper, outsider);
    }

    /// <summary>Usado por outros testes: abre a ronda 1 e devolve (torneio, ronda, candidatos a melhor jogador, um votante).</summary>
    internal static async Task<(Guid Tournament, Guid Round, List<Guid> Candidates, Guid Voter)> OpenRoundAsync(
        NpgsqlDataSource src, VotingService voting)
    {
        var t = await Seed.TournamentAsync(src, status: "finished", finishedAgo: TimeSpan.FromHours(1));
        var host = await Seed.UserAsync(src);
        var team = await Seed.TeamAsync(src, t, host, closedAgo: TimeSpan.FromDays(1), confirmed: true);
        var candidates = new List<Guid> { host };
        for (var i = 0; i < 5; i++)
        {
            var p = await Seed.UserAsync(src);
            candidates.Add(p);
            await Seed.MemberAsync(src, team, t, p, "CM", paid: true);
        }

        var voter = await Seed.UserAsync(src);
        await Seed.MemberAsync(src, team, t, voter, "CM", paid: true);
        var opened = await voting.OpenRoundAsync(t, 60, CancellationToken.None);
        Assert.True(opened.IsOk, opened.Error?.Code);
        await using var c = await src.OpenConnectionAsync();
        var round = await Dapper.SqlMapper.ExecuteScalarAsync<Guid>(c, "SELECT id FROM voting_rounds WHERE tournament_id = @T", new { T = t });
        return (t, round, candidates, voter);
    }

    private Task CloseRoundAsync(Guid tournament, int number) => ExecAsync(
        "UPDATE voting_rounds SET opened_at = now() - interval '2 hours', closes_at = now() - interval '1 minute' WHERE tournament_id = @T AND round_number = @N",
        new { T = tournament, N = number });

    // ----- Abrir rondas -----

    [PgFact]
    public async Task A_round_cannot_open_before_the_tournament_finishes()
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");

        var r = await Voting().OpenRoundAsync(t, 60, CancellationToken.None);

        Assert.Equal("tournament_not_finished", r.Error?.Code);
    }

    [PgFact]
    public async Task A_round_cannot_open_after_the_window_closes()
    {
        var s = await FinishedTournamentAsync(finishedAgo: TimeSpan.FromHours(7));

        var r = await Voting().OpenRoundAsync(s.Tournament, 60, CancellationToken.None);

        Assert.Equal("voting_window_closed", r.Error?.Code);
    }

    [PgFact]
    public async Task Both_rounds_must_end_inside_the_window()
    {
        // Terminou há 5 h com janela de 6 h: uma ronda de 90 min acabaria depois da janela.
        var s = await FinishedTournamentAsync(finishedAgo: TimeSpan.FromHours(5));

        var r = await Voting().OpenRoundAsync(s.Tournament, 90, CancellationToken.None);
        Assert.Equal("round_exceeds_window", r.Error?.Code);

        Assert.True((await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None)).IsOk);
    }

    [PgFact]
    public async Task Duration_must_be_inside_the_admin_limits()
    {
        var s = await FinishedTournamentAsync();

        Assert.Equal("invalid_duration", (await Voting().OpenRoundAsync(s.Tournament, 5, CancellationToken.None)).Error?.Code);
        Assert.Equal("invalid_duration", (await Voting().OpenRoundAsync(s.Tournament, 600, CancellationToken.None)).Error?.Code);
    }

    [PgFact]
    public async Task Round_two_needs_round_one_closed_and_a_tie()
    {
        var s = await FinishedTournamentAsync();
        Assert.True((await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None)).IsOk);

        // Ronda 1 ainda aberta.
        Assert.Equal("previous_round_open", (await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None)).Error?.Code);

        // Ronda 1 fechada mas sem votos nenhuns: não há empate.
        await CloseRoundAsync(s.Tournament, 1);
        Assert.Equal("no_tie", (await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None)).Error?.Code);
    }

    // ----- Votar -----

    [PgFact]
    public async Task Participants_vote_even_with_a_new_email_and_outsiders_need_one_day()
    {
        var s = await FinishedTournamentAsync();
        await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None);
        var candidate = s.Players[2];

        var newbie = await Seed.UserAsync(Src, verifiedAgo: TimeSpan.FromHours(1));
        var fresh = await Voting().VoteAsync(s.Tournament, newbie, VotingCategories.BestPlayer, candidate, CancellationToken.None);
        Assert.Equal("email_not_verified_long_enough", fresh?.Code);

        var unverified = await Seed.UserAsync(Src, verified: false);
        Assert.Equal("email_not_verified_long_enough",
            (await Voting().VoteAsync(s.Tournament, unverified, VotingCategories.BestPlayer, candidate, CancellationToken.None))?.Code);

        Assert.Null(await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestPlayer, candidate, CancellationToken.None));

        // Um jogador que participou com o email acabado de verificar também vota.
        await ExecAsync("UPDATE users SET email_verified_at = now() WHERE id = @Id", new { Id = s.Players[3] });
        Assert.Null(await Voting().VoteAsync(s.Tournament, s.Players[3], VotingCategories.BestPlayer, candidate, CancellationToken.None));
    }

    [PgFact]
    public async Task Nobody_votes_for_themselves()
    {
        var s = await FinishedTournamentAsync();
        await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None);

        var r = await Voting().VoteAsync(s.Tournament, s.Players[2], VotingCategories.BestPlayer, s.Players[2], CancellationToken.None);

        Assert.Equal("cannot_vote_self", r?.Code);
    }

    [PgFact]
    public async Task The_goalkeeper_category_only_has_goalkeepers_and_a_vote_can_be_changed()
    {
        var s = await FinishedTournamentAsync();
        await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None);

        // Um jogador de campo não é candidato a guarda-redes.
        var notKeeper = await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestGoalkeeper, s.Players[2], CancellationToken.None);
        Assert.Equal("candidate_not_found", notKeeper?.Code);

        Assert.Null(await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestGoalkeeper, s.Keeper, CancellationToken.None));
        Assert.Null(await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestPlayer, s.Players[2], CancellationToken.None));
        Assert.Null(await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestPlayer, s.Players[3], CancellationToken.None));

        Assert.Equal(1, await ScalarAsync<int>(
            "SELECT count(*)::int FROM votes WHERE voter_id = @V AND category = 'best_player'", new { V = s.Outsider }));
        Assert.Equal(s.Players[3], await ScalarAsync<Guid>(
            "SELECT candidate_id FROM votes WHERE voter_id = @V AND category = 'best_player'", new { V = s.Outsider }));
    }

    [PgFact]
    public async Task Voting_is_refused_when_no_round_is_open_or_after_it_closes()
    {
        var s = await FinishedTournamentAsync();
        Assert.Equal("voting_closed",
            (await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestPlayer, s.Players[2], CancellationToken.None))?.Code);

        await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None);
        await CloseRoundAsync(s.Tournament, 1);
        Assert.Equal("voting_closed",
            (await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestPlayer, s.Players[2], CancellationToken.None))?.Code);
    }

    // ----- Resultados, empate e avisos -----

    [PgFact]
    public async Task Full_flow_with_a_tie_second_round_and_notifications()
    {
        var s = await FinishedTournamentAsync();
        using var sp = VotingServices();
        var notifier = VotingNotifier(sp);
        var voters = new[] { s.Outsider, await Seed.UserAsync(Src, verifiedAgo: TimeSpan.FromDays(2)) };
        var (a, b) = (s.Players[2], s.Players[3]);

        // Ronda 1: abre e avisa quem participou (e só esses).
        Assert.True((await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None)).IsOk);
        await notifier.RunOnceAsync(CancellationToken.None);
        foreach (var p in s.Players.Append(s.Keeper))
        {
            Assert.Equal(1, await NotificationsAsync(p, "voting_opened"));
        }

        Assert.Equal(0, await NotificationsAsync(s.Outsider, "voting_opened"));

        // Empate 1-1 em melhor jogador.
        Assert.Null(await Voting().VoteAsync(s.Tournament, voters[0], VotingCategories.BestPlayer, a, CancellationToken.None));
        Assert.Null(await Voting().VoteAsync(s.Tournament, voters[1], VotingCategories.BestPlayer, b, CancellationToken.None));

        // Correr outra vez não repete o aviso.
        await notifier.RunOnceAsync(CancellationToken.None);
        Assert.Equal(1, await NotificationsAsync(s.Players[0], "voting_opened"));

        // Ronda 1 fechada: o empate ainda pode ser desempatado, por isso não há resultados.
        await CloseRoundAsync(s.Tournament, 1);
        await notifier.RunOnceAsync(CancellationToken.None);
        Assert.Equal(0, await NotificationsAsync(s.Players[0], "voting_results"));

        // Ronda 2: só os empatados.
        Assert.True((await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None)).IsOk);
        await notifier.RunOnceAsync(CancellationToken.None);
        Assert.Equal(1, await NotificationsAsync(s.Players[0], "voting_second_round"));
        Assert.Equal(2, await ScalarAsync<int>(
            "SELECT count(*)::int FROM voting_candidates c JOIN voting_rounds r ON r.id = c.round_id WHERE r.tournament_id = @T AND r.round_number = 2 AND c.category = 'best_player'",
            new { T = s.Tournament }));
        Assert.Equal("candidate_not_found",
            (await Voting().VoteAsync(s.Tournament, voters[0], VotingCategories.BestPlayer, s.Players[0], CancellationToken.None))?.Code);

        Assert.Null(await Voting().VoteAsync(s.Tournament, voters[0], VotingCategories.BestPlayer, a, CancellationToken.None));
        Assert.Null(await Voting().VoteAsync(s.Tournament, voters[1], VotingCategories.BestPlayer, a, CancellationToken.None));

        // Ronda 2 ainda aberta: sem resultados. Depois de fechar: resultados, uma só vez.
        await notifier.RunOnceAsync(CancellationToken.None);
        Assert.Equal(0, await NotificationsAsync(s.Players[0], "voting_results"));
        await CloseRoundAsync(s.Tournament, 2);
        await notifier.RunOnceAsync(CancellationToken.None);
        await notifier.RunOnceAsync(CancellationToken.None);

        Assert.Equal(1, await NotificationsAsync(s.Players[0], "voting_results"));
        Assert.Equal(1, await NotificationsAsync(voters[0], "voting_results"));   // quem votou também
        var text = await ScalarAsync<string>(
            "SELECT data->>'message' FROM notifications WHERE user_id = @U AND type = 'voting_results'", new { U = s.Players[0] });
        Assert.Contains("Melhor jogador:", text);

        // Os resultados da página: o vencedor é o 'a'.
        var results = await Voting().GetResultsAsync(s.Tournament, voters[0], CancellationToken.None);
        Assert.True(results.IsOk);
        Assert.Equal("final", results.Value!.BestPlayer!.Status);
        Assert.Equal(a, Assert.Single(results.Value.BestPlayer.Winners).UserId);
    }

    [PgFact]
    public async Task A_voting_nobody_voted_in_publishes_no_results_notification()
    {
        var s = await FinishedTournamentAsync();
        using var sp = VotingServices();
        await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None);
        await CloseRoundAsync(s.Tournament, 1);

        await VotingNotifier(sp).RunOnceAsync(CancellationToken.None);

        Assert.Equal(0, await ScalarAsync<int>("SELECT count(*)::int FROM notifications WHERE type = 'voting_results'"));
        Assert.True(await ScalarAsync<bool>(
            "SELECT voting_results_notified_at IS NOT NULL FROM tournaments WHERE id = @T", new { T = s.Tournament }));
    }

    [PgFact]
    public async Task Without_a_voting_the_tournament_page_has_no_awards()
    {
        var s = await FinishedTournamentAsync();

        var results = await Voting().GetResultsAsync(s.Tournament, s.Outsider, CancellationToken.None);

        Assert.True(results.IsOk);
        Assert.Null(results.Value!.BestPlayer);
        Assert.Null(results.Value.BestGoalkeeper);
        Assert.Null(results.Value.Voting);
    }

    [PgFact]
    public async Task A_tie_with_no_second_round_becomes_final_when_the_window_closes()
    {
        var s = await FinishedTournamentAsync();
        await Voting().OpenRoundAsync(s.Tournament, 30, CancellationToken.None);
        await Voting().VoteAsync(s.Tournament, s.Outsider, VotingCategories.BestPlayer, s.Players[2], CancellationToken.None);
        var other = await Seed.UserAsync(Src, verifiedAgo: TimeSpan.FromDays(2));
        await Voting().VoteAsync(s.Tournament, other, VotingCategories.BestPlayer, s.Players[3], CancellationToken.None);
        await CloseRoundAsync(s.Tournament, 1);

        var during = await Voting().GetResultsAsync(s.Tournament, other, CancellationToken.None);
        Assert.Equal("pending", during.Value!.BestPlayer!.Status);

        // A janela acaba sem o gestor abrir a ronda 2: ficam os dois como co-vencedores.
        await ExecAsync("UPDATE tournaments SET finished_at = now() - interval '7 hours' WHERE id = @T", new { T = s.Tournament });
        var after = await Voting().GetResultsAsync(s.Tournament, other, CancellationToken.None);
        Assert.Equal("final", after.Value!.BestPlayer!.Status);
        Assert.Equal(2, after.Value.BestPlayer.Winners.Count);
    }
}
