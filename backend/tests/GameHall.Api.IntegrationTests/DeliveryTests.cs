using GameHall.Api.Modules.Games;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace GameHall.Api.IntegrationTests;

/// <summary>Push, email e avisos de jogo, ponta a ponta contra a base de dados.</summary>
public class DeliveryTests : DbTest
{
    private static string TeamEventJson(Guid team, string title, string message) =>
        $$"""{"teamId":"{{team}}","teamName":"Os Tubarões","colorHex":"#E53935","tournamentName":"Taça","title":"{{title}}","message":"{{message}}"}""";

    private static string InfoJson(Guid tournament, string title, string message) =>
        $$"""{"tournamentId":"{{tournament}}","tournamentName":"Taça","title":"{{title}}","message":"{{message}}"}""";

    private async Task<(Guid User, Guid Team, Guid Tournament)> PlayerWithDeviceAsync(bool pushEnabled = true, bool confirmed = false)
    {
        var t = await Seed.TournamentAsync(Src);
        var u = await Seed.UserAsync(Src, pushEnabled: pushEnabled);
        var team = await Seed.TeamAsync(Src, t, u, closedAgo: TimeSpan.FromMinutes(5), reserved: true, confirmed: confirmed);
        await Seed.DeviceAsync(Src, u, "token-" + Guid.NewGuid().ToString("N") + "-xxxxxxxxxx");
        return (u, team, t);
    }

    [PgFact]
    public async Task Confirmed_team_sends_push_and_email_once()
    {
        var (u, team, _) = await PlayerWithDeviceAsync();
        await Seed.NotificationAsync(Src, u, "team_confirmed", TeamEventJson(team, "Equipa confirmada", "Estão dentro!"));
        var push = new RecordingPush();

        var first = await Dispatcher(push).RunOnceAsync();
        var second = await Dispatcher(push).RunOnceAsync();

        Assert.Equal((1, 1), first);
        Assert.Equal((0, 0), second);
        Assert.Equal("Equipa confirmada", Assert.Single(push.Sent).Message.Title);
        var mail = Assert.Single(Email.Sent);
        Assert.Contains("Estão dentro!", mail.Body);
        Assert.Contains("Equipa confirmada", mail.Subject);
    }

    [PgFact]
    public async Task Reservation_expired_is_push_only()
    {
        var (u, team, _) = await PlayerWithDeviceAsync();
        await Seed.NotificationAsync(Src, u, "reservation_expired", TeamEventJson(team, "Reserva expirada", "Acabou o tempo."));
        var push = new RecordingPush();

        var run = await Dispatcher(push).RunOnceAsync();

        Assert.Equal((1, 0), run);
        Assert.Empty(Email.Sent);
    }

    [PgFact]
    public async Task Voting_notifications_never_leave_the_app()
    {
        var (u, _, t) = await PlayerWithDeviceAsync();
        foreach (var type in new[] { "voting_opened", "voting_second_round", "voting_results" })
        {
            await Seed.NotificationAsync(Src, u, type, InfoJson(t, "Votação", "Vota!"));
        }

        var push = new RecordingPush();
        var run = await Dispatcher(push).RunOnceAsync();

        Assert.Equal((0, 0), run);
        Assert.Empty(push.Sent);
        Assert.Empty(Email.Sent);
    }

    [PgFact]
    public async Task Types_outside_the_push_list_are_never_pushed()
    {
        var (u, team, _) = await PlayerWithDeviceAsync();
        foreach (var type in new[] { "team_closed", "request_decided", "team_eliminated", "removed_from_team", "now_leader", "member_joined" })
        {
            await Seed.NotificationAsync(Src, u, type, TeamEventJson(team, "Aviso", "Texto"));
        }

        var run = await Dispatcher(new RecordingPush()).RunOnceAsync();

        Assert.Equal((0, 0), run);
    }

    [PgFact]
    public async Task The_general_switch_turns_push_off_but_not_email()
    {
        var (u, team, _) = await PlayerWithDeviceAsync(pushEnabled: false);
        await Seed.NotificationAsync(Src, u, "slot_reserved", TeamEventJson(team, "Vaga reservada", "Há vaga!"));
        var push = new RecordingPush();

        await Dispatcher(push).RunOnceAsync();

        Assert.Empty(push.Sent);
        Assert.Single(Email.Sent);
    }

    [PgFact]
    public async Task Expiring_warning_email_only_while_the_team_is_not_confirmed()
    {
        var (u, team, _) = await PlayerWithDeviceAsync();
        await Seed.NotificationAsync(Src, u, "reservation_expiring", TeamEventJson(team, "Tempo a acabar", "Faltam 5 minutos."));
        await Dispatcher(new RecordingPush()).RunOnceAsync();
        Assert.Single(Email.Sent);

        // Outra equipa já confirmada: o aviso "falta 5 minutos" já não faz sentido.
        var (u2, team2, _) = await PlayerWithDeviceAsync(confirmed: true);
        await Seed.NotificationAsync(Src, u2, "reservation_expiring", TeamEventJson(team2, "Tempo a acabar", "Faltam 5 minutos."));
        await Dispatcher(new RecordingPush()).RunOnceAsync();
        Assert.Single(Email.Sent);
    }

    [PgFact]
    public async Task Old_notifications_are_skipped_not_sent_late()
    {
        var (u, team, _) = await PlayerWithDeviceAsync();
        await Seed.NotificationAsync(Src, u, "slot_reserved", TeamEventJson(team, "Vaga reservada", "Há vaga!"), age: TimeSpan.FromHours(3));
        var push = new RecordingPush();

        var run = await Dispatcher(push).RunOnceAsync();

        Assert.Equal((0, 0), run);
        Assert.Equal(0, await ScalarAsync<int>("SELECT count(*)::int FROM notifications WHERE pushed_at IS NULL OR emailed_at IS NULL"));
    }

    [PgFact]
    public async Task Dead_tokens_are_deleted_and_good_ones_kept()
    {
        var (u, team, _) = await PlayerWithDeviceAsync();
        await Seed.DeviceAsync(Src, u, "token-morto-0123456789abcdef");
        await Seed.NotificationAsync(Src, u, "slot_reserved", TeamEventJson(team, "Vaga reservada", "Há vaga!"));
        var push = new RecordingPush();
        push.Dead.Add("token-morto-0123456789abcdef");

        await Dispatcher(push).RunOnceAsync();

        Assert.Equal(0, await ScalarAsync<int>("SELECT count(*)::int FROM device_tokens WHERE token = 'token-morto-0123456789abcdef'"));
        Assert.Equal(1, await ScalarAsync<int>("SELECT count(*)::int FROM device_tokens WHERE user_id = @U", new { U = u }));
    }

    [PgFact]
    public async Task A_player_without_devices_just_gets_nothing_pushed()
    {
        var t = await Seed.TournamentAsync(Src);
        var u = await Seed.UserAsync(Src);
        var team = await Seed.TeamAsync(Src, t, u);
        await Seed.NotificationAsync(Src, u, "team_confirmed", TeamEventJson(team, "Equipa confirmada", "Estão dentro!"));
        var push = new RecordingPush();

        var run = await Dispatcher(push).RunOnceAsync();

        Assert.Equal((0, 1), run);   // sem telemóvel, mas o email sai
        Assert.Empty(push.Sent);
    }

    [PgFact]
    public async Task Invite_and_join_request_pushes_name_who_and_skip_answered_ones()
    {
        var t = await Seed.TournamentAsync(Src);
        var host = await Seed.UserAsync(Src, displayName: "Rui Líder");
        var guest = await Seed.UserAsync(Src);
        await Seed.DeviceAsync(Src, guest, "token-convidado-0123456789");
        var team = await Seed.TeamAsync(Src, t, host, name: "Falcões");
        var invite = Guid.NewGuid();
        await ExecAsync(
            "INSERT INTO team_invites (id, team_id, tournament_id, invited_user_id, invited_by, status) VALUES (@I, @T, @Tr, @G, @H, 'pending')",
            new { I = invite, T = team, Tr = t, G = guest, H = host });
        await Seed.NotificationAsync(Src, guest, "team_invite", $$"""{"inviteId":"{{invite}}"}""");
        var push = new RecordingPush();

        await Dispatcher(push).RunOnceAsync();

        var sent = Assert.Single(push.Sent);
        Assert.Contains("Rui Líder", sent.Message.Body);
        Assert.Contains("Falcões", sent.Message.Body);
    }

    // ----- Jogos -----

    private async Task<(Guid TeamA, Guid TeamB, Guid HostA, Guid HostB, Guid T)> TwoTeamsAsync(bool demo = false)
    {
        var t = await Seed.TournamentAsync(Src, status: "ongoing");
        var hostA = await Seed.UserAsync(Src);
        var hostB = await Seed.UserAsync(Src);
        var a = await Seed.TeamAsync(Src, t, hostA, confirmed: true, demo: demo);
        var b = await Seed.TeamAsync(Src, t, hostB, confirmed: true, demo: demo);
        return (a, b, hostA, hostB, t);
    }

    [PgFact]
    public async Task Scheduling_changing_postponing_and_cancelling_a_game_notifies_both_teams()
    {
        var (a, b, hostA, hostB, t) = await TwoTeamsAsync();
        var game = await Seed.GameAsync(Src, t, a, b, null);   // sem data: ainda nada

        Assert.Equal(0, await NotificationsAsync(hostA, "game_changed"));

        await ExecAsync("UPDATE games SET scheduled_at = now() + interval '2 days' WHERE id = @G", new { G = game });
        Assert.Equal(1, await ScalarAsync<int>(
            "SELECT count(*)::int FROM notifications WHERE user_id = @U AND data->>'title' = 'Jogo marcado'", new { U = hostA }));

        await ExecAsync("UPDATE games SET scheduled_at = now() + interval '3 days' WHERE id = @G", new { G = game });
        await ExecAsync("UPDATE games SET field_name = 'Campo 9' WHERE id = @G", new { G = game });
        Assert.Equal(2, await ScalarAsync<int>(
            "SELECT count(*)::int FROM notifications WHERE user_id = @U AND data->>'title' = 'Jogo alterado'", new { U = hostB }));

        await ExecAsync("UPDATE games SET status = 'postponed' WHERE id = @G", new { G = game });
        Assert.Equal(1, await ScalarAsync<int>(
            "SELECT count(*)::int FROM notifications WHERE user_id = @U AND data->>'title' = 'Jogo adiado'", new { U = hostA }));

        await ExecAsync("UPDATE games SET status = 'cancelled' WHERE id = @G", new { G = game });
        Assert.Equal(1, await ScalarAsync<int>(
            "SELECT count(*)::int FROM notifications WHERE user_id = @U AND data->>'title' = 'Jogo cancelado'", new { U = hostA }));
    }

    [PgFact]
    public async Task Results_and_other_edits_do_not_notify()
    {
        var (a, b, hostA, _, t) = await TwoTeamsAsync();
        var game = await Seed.GameAsync(Src, t, a, b, TimeSpan.FromHours(-1), status: "running");
        var before = await NotificationsAsync(hostA, "game_changed");

        await ExecAsync("UPDATE games SET home_goals = 2, away_goals = 1, status = 'finished' WHERE id = @G", new { G = game });

        Assert.Equal(before, await NotificationsAsync(hostA, "game_changed"));
    }

    [PgFact]
    public async Task Demo_teams_never_get_game_notifications()
    {
        var (a, b, hostA, _, t) = await TwoTeamsAsync(demo: true);

        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromDays(1));

        Assert.Equal(0, await NotificationsAsync(hostA, "game_changed"));
    }

    [PgFact]
    public async Task A_game_notification_becomes_a_push()
    {
        var (a, b, hostA, _, t) = await TwoTeamsAsync();
        await Seed.DeviceAsync(Src, hostA, "token-jogador-0123456789abcdef");
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromDays(1));
        var push = new RecordingPush();

        await Dispatcher(push).RunOnceAsync();

        var sent = Assert.Single(push.Sent);
        Assert.Equal("Jogo marcado", sent.Message.Title);
        Assert.Contains("vs", sent.Message.Body);
    }

    private GameStartingService Starting() => new(Src, Config(), NullLogger<GameStartingService>.Instance);

    [PgFact]
    public async Task Game_starting_warns_30_minutes_before_exactly_once_and_again_after_a_reschedule()
    {
        var (a, b, hostA, hostB, t) = await TwoTeamsAsync();
        var soon = await Seed.GameAsync(Src, t, a, b, TimeSpan.FromMinutes(20));
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromHours(5));   // ainda longe

        Assert.Equal(2, await Starting().RunOnceAsync(CancellationToken.None));   // um por jogador das duas equipas
        Assert.Equal(0, await Starting().RunOnceAsync(CancellationToken.None));   // não repete
        Assert.Equal(1, await NotificationsAsync(hostA, "game_starting"));
        Assert.Equal(1, await NotificationsAsync(hostB, "game_starting"));

        // O jogo passou para outra hora, outra vez dentro dos 30 minutos: novo aviso.
        await ExecAsync("UPDATE games SET scheduled_at = now() + interval '25 minutes' WHERE id = @G", new { G = soon });
        Assert.Equal(2, await Starting().RunOnceAsync(CancellationToken.None));
        Assert.Equal(2, await NotificationsAsync(hostA, "game_starting"));
    }

    [PgFact]
    public async Task Game_starting_skips_started_cancelled_and_postponed_games()
    {
        var (a, b, hostA, _, t) = await TwoTeamsAsync();
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromMinutes(-5));
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromMinutes(10), status: "cancelled");
        await Seed.GameAsync(Src, t, a, b, TimeSpan.FromMinutes(10), status: "postponed");

        Assert.Equal(0, await Starting().RunOnceAsync(CancellationToken.None));
        Assert.Equal(0, await NotificationsAsync(hostA, "game_starting"));
    }
}
