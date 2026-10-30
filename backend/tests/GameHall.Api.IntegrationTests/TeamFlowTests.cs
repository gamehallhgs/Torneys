using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.IntegrationTests;

public class TeamFlowTests : DbTest
{
    private static CreateTeamRequest Req(string name, string color = "#E53935") => new(name, color);

    private async Task EnableCodeAsync(Guid teamId, bool direct = true) =>
        await ExecAsync(
            "UPDATE teams SET invite_code_enabled = true, code_direct_entry = @D WHERE id = @Id", new { Id = teamId, D = direct });

    private Task<string> CodeOfAsync(Guid teamId) =>
        ScalarAsync<string>("SELECT invite_code FROM teams WHERE id = @Id", new { Id = teamId });

    // ----- Criar equipa -----

    [PgFact]
    public async Task A_player_creates_a_team_and_becomes_its_leader_and_member()
    {
        var t = await Seed.TournamentAsync(Src);
        var u = await Seed.UserAsync(Src);

        var r = await Teams().CreateTeamAsync(u, t, Req("Os Tubarões"), CancellationToken.None);

        Assert.True(r.IsOk, r.Error?.Code);
        Assert.Equal(u, await ScalarAsync<Guid>("SELECT host_user_id FROM teams WHERE id = @Id", new { Id = r.Value }));
        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM team_members WHERE team_id = @Id", new { Id = r.Value }));
    }

    [PgFact]
    public async Task A_player_cannot_be_in_two_teams_of_the_same_tournament()
    {
        var t = await Seed.TournamentAsync(Src);
        var u = await Seed.UserAsync(Src);
        await Teams().CreateTeamAsync(u, t, Req("Os Tubarões"), CancellationToken.None);

        var second = await Teams().CreateTeamAsync(u, t, Req("Os Falcões", "#1E88E5"), CancellationToken.None);

        Assert.Equal(TeamErrors.AlreadyInTeam, second.Error);
    }

    [PgFact]
    public async Task Team_names_and_colors_are_unique_per_tournament()
    {
        var t = await Seed.TournamentAsync(Src);
        await Teams().CreateTeamAsync(await Seed.UserAsync(Src), t, Req("Os Tubarões"), CancellationToken.None);

        var sameName = await Teams().CreateTeamAsync(await Seed.UserAsync(Src), t, Req("Os Tubarões", "#1E88E5"), CancellationToken.None);
        var sameColor = await Teams().CreateTeamAsync(await Seed.UserAsync(Src), t, Req("Os Falcões"), CancellationToken.None);

        Assert.Equal(TeamErrors.NameTaken, sameName.Error);
        Assert.Equal(TeamErrors.ColorTaken, sameColor.Error);
    }

    [PgFact]
    public async Task Team_names_with_bad_words_are_refused_but_real_names_pass()
    {
        var t = await Seed.TournamentAsync(Src);

        var bad = await Teams().CreateTeamAsync(await Seed.UserAsync(Src), t, Req("Os Caralhos"), CancellationToken.None);
        var fine = await Teams().CreateTeamAsync(await Seed.UserAsync(Src), t, Req("Computador FC", "#1E88E5"), CancellationToken.None);

        Assert.Equal("validation_error", bad.Error?.Code);
        Assert.True(fine.IsOk, fine.Error?.Code);
    }

    [PgFact]
    public async Task Too_young_players_cannot_create_teams_in_an_adults_tournament()
    {
        var t = await Seed.TournamentAsync(Src, minAge: 18);
        var teen = await Seed.UserAsync(Src, age: 16);

        var r = await Teams().CreateTeamAsync(teen, t, Req("Os Jovens"), CancellationToken.None);

        Assert.Equal(TeamErrors.AgeTooYoung, r.Error);
    }

    [PgFact]
    public async Task Nobody_can_create_a_team_once_registration_is_closed()
    {
        var t = await Seed.TournamentAsync(Src, status: "registration_closed");

        var r = await Teams().CreateTeamAsync(await Seed.UserAsync(Src), t, Req("Tarde Demais"), CancellationToken.None);

        Assert.False(r.IsOk);
    }

    // ----- Género -----

    public static IEnumerable<object[]> GenderCombos() =>
        from tournament in new[] { "mixed", "male", "female", "non_binary", "other" }
        from user in new[] { "male", "female", "non_binary", "other" }
        select new object[] { tournament, user };

    [PgTheory]
    [MemberData(nameof(GenderCombos))]
    public async Task Only_the_matching_gender_enters_a_non_mixed_tournament(string tournamentGender, string userGender)
    {
        var t = await Seed.TournamentAsync(Src, gender: tournamentGender);
        var u = await Seed.UserAsync(Src, gender: userGender);

        var r = await Teams().CreateTeamAsync(u, t, Req("Equipa Teste"), CancellationToken.None);

        if (Genders.Allowed(tournamentGender, userGender))
        {
            Assert.True(r.IsOk, r.Error?.Code);
        }
        else
        {
            Assert.Equal(TeamErrors.GenderNotAllowed, r.Error);
        }
    }

    [PgFact]
    public async Task A_wrong_gender_cannot_join_by_code_either()
    {
        var t = await Seed.TournamentAsync(Src, gender: "female");
        var host = await Seed.UserAsync(Src, gender: "female");
        var team = await Seed.TeamAsync(Src, t, host);
        await EnableCodeAsync(team);

        var r = await Teams().JoinByCodeAsync(await Seed.UserAsync(Src, gender: "male"), await CodeOfAsync(team), CancellationToken.None);

        Assert.Equal(TeamErrors.GenderNotAllowed, r.Error);
    }

    // ----- Código de convite -----

    [PgFact]
    public async Task Joining_with_the_code_adds_the_player_and_tells_the_leader()
    {
        var t = await Seed.TournamentAsync(Src);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host);
        await EnableCodeAsync(team);
        var player = await Seed.UserAsync(Src);

        var r = await Teams().JoinByCodeAsync(player, (await CodeOfAsync(team)).ToLowerInvariant(), CancellationToken.None);

        Assert.True(r.IsOk, r.Error?.Code);
        Assert.True(r.Value!.Joined);
        Assert.Equal(2, await ScalarAsync<int>("SELECT count(*)::int FROM team_members WHERE team_id = @Id", new { Id = team }));
        Assert.Equal(1, await NotificationsAsync(host, "member_joined"));
    }

    [PgFact]
    public async Task Without_direct_entry_the_code_creates_a_request_for_the_leader()
    {
        var t = await Seed.TournamentAsync(Src);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host);
        await EnableCodeAsync(team, direct: false);
        var player = await Seed.UserAsync(Src);

        var r = await Teams().JoinByCodeAsync(player, await CodeOfAsync(team), CancellationToken.None);

        Assert.True(r.IsOk, r.Error?.Code);
        Assert.False(r.Value!.Joined);
        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM team_members WHERE team_id = @Id", new { Id = team }));
        Assert.Equal(1, await NotificationsAsync(host, "join_request"));
    }

    [PgFact]
    public async Task Wrong_disabled_and_old_codes_do_not_work()
    {
        var t = await Seed.TournamentAsync(Src);
        var team = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src));
        var code = await CodeOfAsync(team);
        var player = await Seed.UserAsync(Src);

        // Código desligado (por defeito).
        Assert.Equal("invite_code_invalid", (await Teams().JoinByCodeAsync(player, code, CancellationToken.None)).Error?.Code);

        // Código que não existe.
        await EnableCodeAsync(team);
        Assert.Equal("invite_code_invalid", (await Teams().JoinByCodeAsync(player, "GH-ZZZZ", CancellationToken.None)).Error?.Code);
        Assert.Equal("invite_code_invalid", (await Teams().JoinByCodeAsync(player, "lixo", CancellationToken.None)).Error?.Code);
    }

    [PgFact]
    public async Task A_full_team_refuses_new_players()
    {
        var t = await Seed.TournamentAsync(Src, maxPlayers: 2);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host);
        await Seed.MemberAsync(Src, team, t, await Seed.UserAsync(Src));
        await EnableCodeAsync(team);

        var r = await Teams().JoinByCodeAsync(await Seed.UserAsync(Src), await CodeOfAsync(team), CancellationToken.None);

        Assert.Equal(TeamErrors.TeamFull, r.Error);
    }

    [PgFact]
    public async Task A_player_already_in_a_team_of_the_tournament_cannot_use_a_code()
    {
        var t = await Seed.TournamentAsync(Src);
        var teamA = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src));
        var player = await Seed.UserAsync(Src);
        await Seed.TeamAsync(Src, t, player);
        await EnableCodeAsync(teamA);

        var r = await Teams().JoinByCodeAsync(player, await CodeOfAsync(teamA), CancellationToken.None);

        Assert.Equal(TeamErrors.AlreadyInTeam, r.Error);
    }

    [PgFact]
    public async Task The_leader_can_regenerate_the_code_three_times_per_hour_and_the_old_code_stops_working()
    {
        var t = await Seed.TournamentAsync(Src);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host);
        await EnableCodeAsync(team);
        var first = await CodeOfAsync(team);

        var codes = new List<string>();
        for (var i = 0; i < 3; i++)
        {
            var r = await Teams().RegenerateCodeAsync(host, team, CancellationToken.None);
            Assert.True(r.IsOk, r.Error?.Code);
            codes.Add(r.Value!.Code);
        }

        var fourth = await Teams().RegenerateCodeAsync(host, team, CancellationToken.None);
        Assert.Equal(429, fourth.Error?.Status);
        Assert.Equal("invite_code_regen_limit", fourth.Error?.Code);

        // O código antigo já não entra.
        var old = await Teams().JoinByCodeAsync(await Seed.UserAsync(Src), first, CancellationToken.None);
        Assert.Equal("invite_code_invalid", old.Error?.Code);

        // Uma hora depois volta a ser possível.
        Clock.Advance(TimeSpan.FromMinutes(61));
        Assert.True((await Teams().RegenerateCodeAsync(host, team, CancellationToken.None)).IsOk);
    }

    [PgFact]
    public async Task Only_the_leader_can_regenerate_the_code()
    {
        var t = await Seed.TournamentAsync(Src);
        var host = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, host);
        var member = await Seed.UserAsync(Src);
        await Seed.MemberAsync(Src, team, t, member);

        var r = await Teams().RegenerateCodeAsync(member, team, CancellationToken.None);

        Assert.Equal(TeamErrors.NotHost, r.Error);
    }

    [PgFact]
    public async Task Guessing_codes_is_rate_limited()
    {
        var t = await Seed.TournamentAsync(Src);
        var team = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src));
        await EnableCodeAsync(team);
        var player = await Seed.UserAsync(Src);

        for (var i = 0; i < 10; i++)
        {
            await Teams().PreviewCodeAsync(player, "GH-ZZZZ", CancellationToken.None);
        }

        // Mesmo com o código certo, depois de 10 falhas fica bloqueado durante uma hora.
        var r = await Teams().PreviewCodeAsync(player, await CodeOfAsync(team), CancellationToken.None);
        Assert.Equal(TeamErrors.TooManyFailedLookups, r.Error);
    }

    [PgFact]
    public async Task Preview_shows_the_team_without_joining()
    {
        var t = await Seed.TournamentAsync(Src);
        var team = await Seed.TeamAsync(Src, t, await Seed.UserAsync(Src), name: "Águias do Tejo");
        await EnableCodeAsync(team);
        var player = await Seed.UserAsync(Src);

        var r = await Teams().PreviewCodeAsync(player, await CodeOfAsync(team), CancellationToken.None);

        Assert.True(r.IsOk, r.Error?.Code);
        Assert.Equal("Águias do Tejo", r.Value!.TeamName);
        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM team_members WHERE team_id = @Id", new { Id = team }));
    }
}
