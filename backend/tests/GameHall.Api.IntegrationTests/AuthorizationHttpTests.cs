using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using GameHall.Api.Infrastructure.Security;
using GameHall.Api.Modules.Auth;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GameHall.Api.IntegrationTests;

/// <summary>
/// Autorização pela API de verdade (o programa completo, contra uma base de dados nova). Os tokens são criados
/// com o TokenService, como o login faz, para não depender do envio de emails.
/// </summary>
public class AuthorizationHttpTests : IAsyncLifetime
{
    private TestDb _db = null!;
    private WebApplicationFactory<Program>? _factory;

    public async Task InitializeAsync()
    {
        if (!Pg.Available)
        {
            return;
        }

        _db = await TestDb.CreateAsync(migrate: false);   // a API migra no arranque
        Environment.SetEnvironmentVariable("ConnectionStrings__Default", _db.ConnectionString);
        Environment.SetEnvironmentVariable("Jwt__SigningKey", "integration-test-signing-key-0123456789abcdef");
        Environment.SetEnvironmentVariable("Security__Pepper", "integration-test-pepper-0123456789abcdef");
        Environment.SetEnvironmentVariable("Security__CheckPwnedPasswords", "false");
        Environment.SetEnvironmentVariable("Lifecycle__Enabled", "false");
        _factory = new WebApplicationFactory<Program>();
        _ = _factory.Server;   // a fábrica é preguiçosa: arranca já (e migra) antes de os testes semearem dados
    }

    public async Task DisposeAsync()
    {
        if (_factory is not null)
        {
            await _factory.DisposeAsync();
        }

        if (Pg.Available)
        {
            await _db.DisposeAsync();
        }
    }

    private HttpClient Client(Guid? user = null, bool legalOk = true)
    {
        var client = _factory!.CreateClient();
        if (user is not null)
        {
            var tokens = _factory.Services.GetRequiredService<TokenService>();
            var (token, _) = tokens.CreateAccessToken(new User { Id = user.Value, Role = UserRole.Player }, legalOk);
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return client;
    }

    [PgFact]
    public async Task Health_is_public()
    {
        var res = await Client().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    [PgTheory]
    [InlineData("/api/v1/tournaments")]
    [InlineData("/api/v1/notifications")]
    [InlineData("/api/v1/notifications/unread-count")]
    [InlineData("/api/v1/my/teams")]
    [InlineData("/api/v1/me")]
    public async Task Everything_needs_a_session(string url)
    {
        var res = await Client().GetAsync(url);

        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [PgFact]
    public async Task Without_accepting_the_current_terms_only_the_account_endpoints_work()
    {
        var u = await Seed.UserAsync(_db.Source);
        var client = Client(u, legalOk: false);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/v1/tournaments")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/v1/notifications")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/me")).StatusCode);
    }

    [PgFact]
    public async Task A_valid_session_reads_tournaments_and_its_own_profile()
    {
        var u = await Seed.UserAsync(_db.Source);
        var client = Client(u);

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/tournaments")).StatusCode);
        var me = await client.GetFromJsonAsync<UserDto>("/api/v1/me");
        Assert.Equal(u, me!.Id);
        Assert.True(me.PushEnabled);
    }

    [PgFact]
    public async Task A_forged_or_wrong_signed_token_is_refused()
    {
        var client = _factory!.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "eyJhbGciOiJIUzI1NiJ9.e30.assinatura-falsa");

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/me")).StatusCode);
    }

    [PgFact]
    public async Task Players_cannot_touch_other_players_notifications()
    {
        var a = await Seed.UserAsync(_db.Source);
        var b = await Seed.UserAsync(_db.Source);
        var id = Guid.NewGuid();
        await Dapper.SqlMapper.ExecuteAsync(
            await _db.Source.OpenConnectionAsync(),
            "INSERT INTO notifications (id, user_id, type, data) VALUES (@Id, @U, 'game_changed', '{\"tournamentId\":\"00000000-0000-0000-0000-000000000001\",\"tournamentName\":\"x\",\"title\":\"t\",\"message\":\"m\"}'::jsonb)",
            new { Id = id, U = a });

        var res = await Client(b).DeleteAsync($"/api/v1/notifications/{id}");

        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
        var mine = await Client(a).GetFromJsonAsync<NotificationList>("/api/v1/notifications");
        Assert.Single(mine!.Items);
    }

    private sealed record NotificationList(int UnreadCount, List<object> Items);

    [PgFact]
    public async Task Only_the_leader_can_manage_the_team_and_outsiders_cannot_use_invites()
    {
        var host = await Seed.UserAsync(_db.Source);
        var other = await Seed.UserAsync(_db.Source);
        var t = await Seed.TournamentAsync(_db.Source);
        var team = await Seed.TeamAsync(_db.Source, t, host);
        var client = Client(other);

        var regen = await client.PostAsync($"/api/v1/teams/{team}/invite-code/regenerate", null);
        var close = await client.PostAsJsonAsync($"/api/v1/teams/{team}/close", new { paymentMode = "split" });
        var disband = await client.PostAsync($"/api/v1/teams/{team}/disband", null);
        var accept = await client.PostAsync($"/api/v1/invites/{Guid.NewGuid()}/accept", null);

        Assert.True((int)regen.StatusCode is 403 or 404, regen.StatusCode.ToString());
        Assert.True((int)close.StatusCode is 403 or 404, close.StatusCode.ToString());
        Assert.True((int)disband.StatusCode is 403 or 404, disband.StatusCode.ToString());
        Assert.Equal(HttpStatusCode.NotFound, accept.StatusCode);
        Assert.Equal(host, await Dapper.SqlMapper.ExecuteScalarAsync<Guid>(
            await _db.Source.OpenConnectionAsync(), "SELECT host_user_id FROM teams WHERE id = @Id", new { Id = team }));
    }

    [PgFact]
    public async Task Push_switch_and_device_tokens_belong_to_the_caller()
    {
        var a = await Seed.UserAsync(_db.Source);
        var b = await Seed.UserAsync(_db.Source);
        var token = "token-do-telemovel-0123456789abcdef";

        Assert.Equal(HttpStatusCode.NoContent, (await Client(a).PostAsJsonAsync("/api/v1/me/devices", new { token, platform = "android" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Client(a).PostAsJsonAsync("/api/v1/me/devices", new { token = "curto", platform = "android" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Client(a).PostAsJsonAsync("/api/v1/me/devices", new { token, platform = "windows" })).StatusCode);

        // Outro utilizador não apaga o token do primeiro.
        await Client(b).PostAsJsonAsync("/api/v1/me/devices/remove", new { token });
        Assert.Equal(1, await Dapper.SqlMapper.ExecuteScalarAsync<int>(
            await _db.Source.OpenConnectionAsync(), "SELECT count(*)::int FROM device_tokens WHERE user_id = @U", new { U = a }));

        var off = await Client(a).PutAsJsonAsync("/api/v1/me/push", new { enabled = false });
        Assert.Equal(HttpStatusCode.OK, off.StatusCode);
        Assert.False((await off.Content.ReadFromJsonAsync<UserDto>())!.PushEnabled);

        await Client(a).PostAsJsonAsync("/api/v1/me/devices/remove", new { token });
        Assert.Equal(0, await Dapper.SqlMapper.ExecuteScalarAsync<int>(
            await _db.Source.OpenConnectionAsync(), "SELECT count(*)::int FROM device_tokens WHERE user_id = @U", new { U = a }));
    }

    [PgFact]
    public async Task Next_games_endpoint_needs_a_session_and_returns_the_shape()
    {
        var u = await Seed.UserAsync(_db.Source);
        var t = await Seed.TournamentAsync(_db.Source, status: "ongoing");

        Assert.Equal(HttpStatusCode.Unauthorized, (await Client().GetAsync($"/api/v1/tournaments/{t}/next-games")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await Client(u).GetAsync($"/api/v1/tournaments/{Guid.NewGuid()}/next-games")).StatusCode);
        var ok = await Client(u).GetAsync($"/api/v1/tournaments/{t}/next-games");
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        Assert.Contains("\"next\":null", await ok.Content.ReadAsStringAsync());
    }

    [PgFact]
    public async Task Bad_words_are_refused_in_the_display_name()
    {
        var u = await Seed.UserAsync(_db.Source);

        var res = await Client(u).PatchAsJsonAsync("/api/v1/me/name", new { displayName = "Puta Bonita" });

        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }
}
