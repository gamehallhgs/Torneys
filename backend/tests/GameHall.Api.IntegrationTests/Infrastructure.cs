using Dapper;
using GameHall.Api.Database;
using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Infrastructure.Push;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Games;
using GameHall.Api.Modules.Teams;
using GameHall.Api.Modules.Tournaments;
using GameHall.Api.Modules.Voting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using Xunit;

namespace GameHall.Api.IntegrationTests;

/// <summary>
/// Testes com um PostgreSQL de verdade. Precisam da variável de ambiente GAMEHALL_TEST_PG com a ligação de um
/// utilizador que possa criar bases de dados, por exemplo:
///   Host=localhost;Username=postgres;Password=test;Database=postgres
/// Cada teste cria a sua própria base de dados (migrações todas aplicadas) e apaga-a no fim.
/// Sem a variável, os testes aparecem como "skipped". Ver README.md.
/// </summary>
public static class Pg
{
    public const string EnvVar = "GAMEHALL_TEST_PG";
    public static string? Admin => Environment.GetEnvironmentVariable(EnvVar);
    public static bool Available => !string.IsNullOrWhiteSpace(Admin);
    public const string SkipReason = "Define GAMEHALL_TEST_PG (ligação a um PostgreSQL) para correr os testes de integração.";
}

public sealed class PgFactAttribute : FactAttribute
{
    public PgFactAttribute()
    {
        if (!Pg.Available)
        {
            Skip = Pg.SkipReason;
        }
    }
}

public sealed class PgTheoryAttribute : TheoryAttribute
{
    public PgTheoryAttribute()
    {
        if (!Pg.Available)
        {
            Skip = Pg.SkipReason;
        }
    }
}

public sealed class FakeClock : TimeProvider
{
    private DateTimeOffset _now = DateTimeOffset.UtcNow;

    public override DateTimeOffset GetUtcNow() => _now;

    public void Advance(TimeSpan by) => _now += by;
}

public sealed class RecordingEmail : IEmailSender
{
    public List<(string To, string Subject, string Body)> Sent { get; } = [];

    public Task SendAsync(string to, string subject, string textBody, CancellationToken ct)
    {
        lock (Sent)
        {
            Sent.Add((to, subject, textBody));
        }

        return Task.CompletedTask;
    }
}

public sealed class RecordingPush : IPushSender
{
    public List<(PushMessage Message, IReadOnlyCollection<string> Tokens)> Sent { get; } = [];

    /// <summary>Tokens que o "Firebase" diz que já não existem.</summary>
    public HashSet<string> Dead { get; } = [];

    public Task<IReadOnlyList<string>> SendAsync(PushMessage message, IReadOnlyCollection<string> tokens, CancellationToken ct)
    {
        Sent.Add((message, tokens));
        return Task.FromResult<IReadOnlyList<string>>(tokens.Where(Dead.Contains).ToList());
    }
}

/// <summary>Uma base de dados nova só para um teste.</summary>
public sealed class TestDb : IAsyncDisposable
{
    static TestDb() => DapperConfig.Register();

    private TestDb(string name, string connectionString, NpgsqlDataSource source)
    {
        Name = name;
        ConnectionString = connectionString;
        Source = source;
    }

    public string Name { get; }
    public NpgsqlDataSource Source { get; }

    public static async Task<TestDb> CreateAsync(bool migrate = true)
    {
        var name = "gh_it_" + Guid.NewGuid().ToString("N");
        await using (var admin = new NpgsqlConnection(Pg.Admin))
        {
            await admin.OpenAsync();
            await admin.ExecuteAsync($"CREATE DATABASE \"{name}\"");
        }

        var cs = new NpgsqlConnectionStringBuilder(Pg.Admin) { Database = name, Pooling = true, MaxPoolSize = 40 }.ConnectionString;
        var db = new TestDb(name, cs, NpgsqlDataSource.Create(cs));
        if (migrate)
        {
            await new Migrator(db.Source, NullLogger<Migrator>.Instance).RunAsync(CancellationToken.None);
        }

        return db;
    }

    /// <summary>Com a palavra-passe (o NpgsqlDataSource.ConnectionString esconde-a).</summary>
    public string ConnectionString { get; }

    public async ValueTask DisposeAsync()
    {
        await Source.DisposeAsync();
        NpgsqlConnection.ClearAllPools();
        await using var admin = new NpgsqlConnection(Pg.Admin);
        await admin.OpenAsync();
        await admin.ExecuteAsync($"DROP DATABASE IF EXISTS \"{Name}\" WITH (FORCE)");
    }
}

/// <summary>Base dos testes: base de dados nova + serviços reais ligados a ela.</summary>
public abstract class DbTest : IAsyncLifetime
{
    protected TestDb Db = null!;
    protected NpgsqlDataSource Src => Db.Source;
    protected FakeClock Clock { get; } = new();
    protected RecordingEmail Email { get; } = new();

    public virtual async Task InitializeAsync() => Db = await TestDb.CreateAsync();

    public virtual async Task DisposeAsync() => await Db.DisposeAsync();

    protected TeamService Teams() => new(
        new TeamStore(Src), new AuthStore(Src), new UsernameStore(Src), Email, Clock, NullLogger<TeamService>.Instance);

    protected ReservationService Reservations() => new(Src, Clock, NullLogger<ReservationService>.Instance);

    protected static IConfiguration Config() => new ConfigurationBuilder().Build();

    protected ServiceProvider VotingServices()
    {
        var s = new ServiceCollection();
        s.AddSingleton(Src);
        s.AddSingleton<TimeProvider>(Clock);
        s.AddSingleton<VotingStore>();
        s.AddSingleton<TournamentStore>();
        s.AddSingleton<GameStore>();
        s.AddSingleton<AuthStore>();
        s.AddScoped<VotingService>();
        return s.BuildServiceProvider();
    }

    protected VotingService Voting() => new(
        new VotingStore(Src), new TournamentStore(Src), new GameStore(Src), new AuthStore(Src), Clock);

    protected VotingNotificationService VotingNotifier(ServiceProvider sp) => new(
        Src, sp.GetRequiredService<IServiceScopeFactory>(), Config(), NullLogger<VotingNotificationService>.Instance);

    protected NotificationDispatcherHost Dispatcher(RecordingPush push) => new(Src, push, Email);

    // ----- Consultas rápidas -----

    protected async Task<T> ScalarAsync<T>(string sql, object? args = null)
    {
        await using var c = await Src.OpenConnectionAsync();
        return (await c.ExecuteScalarAsync<T>(sql, args))!;
    }

    protected async Task ExecAsync(string sql, object? args = null)
    {
        await using var c = await Src.OpenConnectionAsync();
        await c.ExecuteAsync(sql, args);
    }

    protected Task<int> NotificationsAsync(Guid userId, string type) =>
        ScalarAsync<int>("SELECT count(*)::int FROM notifications WHERE user_id = @U AND type = @T", new { U = userId, T = type });
}

/// <summary>Cria o NotificationDispatcher com falsos de push e email.</summary>
public sealed class NotificationDispatcherHost
{
    private readonly GameHall.Api.Modules.Notifications.NotificationDispatcher _inner;

    public NotificationDispatcherHost(NpgsqlDataSource src, RecordingPush push, RecordingEmail email) =>
        _inner = new GameHall.Api.Modules.Notifications.NotificationDispatcher(
            src, push, email, new ConfigurationBuilder().Build(),
            NullLogger<GameHall.Api.Modules.Notifications.NotificationDispatcher>.Instance);

    public Task<(int Pushes, int Emails)> RunOnceAsync() => _inner.RunOnceAsync(CancellationToken.None);
}

/// <summary>Dados de teste (SQL direto: assim os testes não dependem dos serviços que estão a testar).</summary>
public static class Seed
{
    private static int _n;


    public static async Task<Guid> UserAsync(
        NpgsqlDataSource db, string gender = "male", int age = 28, TimeSpan? verifiedAgo = null, bool verified = true,
        string? displayName = null, bool pushEnabled = true)
    {
        var id = Guid.NewGuid();
        var n = Interlocked.Increment(ref _n);
        var birth = DateTime.UtcNow.Date.AddYears(-age).AddDays(-30);
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            """
            INSERT INTO users (id, email, password_hash, display_name, birth_date, role, failed_login_count, created_at, updated_at,
                               is_demo, username, username_tag, gender, email_verified_at, push_enabled)
            VALUES (@Id, @Email, 'x', @Name, @Birth, 0, 0, now(), now(), false, @Username, @Tag, @Gender, @Verified, @Push)
            """,
            new
            {
                Id = id,
                Email = $"u{id:N}@teste.pt",
                Name = displayName ?? $"Jogador {n}",
                Birth = birth,
                Username = $"user{n}x{id.ToString("N")[..6]}",
                Tag = (n % 1000).ToString("D3"),
                Gender = gender,
                Verified = verified ? DateTime.UtcNow - (verifiedAgo ?? TimeSpan.FromDays(3)) : (DateTime?)null,
                Push = pushEnabled,
            });
        return id;
    }

    public static async Task<Guid> TournamentAsync(
        NpgsqlDataSource db, string status = "registration_open", int maxTeams = 4, string gender = "mixed",
        int minPlayers = 1, int maxPlayers = 7, TimeSpan? closesIn = null, TimeSpan? finishedAgo = null,
        int windowHours = 6, string format = "league", int minAge = 13, int? maxAge = null, string? name = null)
    {
        var id = Guid.NewGuid();
        var n = Interlocked.Increment(ref _n);
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            """
            INSERT INTO tournaments (id, name, organizer_name, sport, format, status, registration_closes_at, starts_on, ends_on,
                                     location_name, entry_fee_cents, min_age, max_age, max_teams, min_players_per_team,
                                     max_players_per_team, gender, finished_at, voting_window_hours)
            VALUES (@Id, @Name, 'Organização', 'futsal', @Format, @Status, @Closes, current_date, current_date + 1,
                    'Pavilhão', 1000, @MinAge, @MaxAge, @Max, @Min, @MaxP, @Gender, @Finished, @Window)
            """,
            new
            {
                Id = id,
                Name = name ?? $"Torneio {n}",
                Format = format,
                Status = status,
                Closes = DateTime.UtcNow + (closesIn ?? TimeSpan.FromDays(3)),
                MinAge = minAge,
                MaxAge = maxAge,
                Max = maxTeams,
                Min = minPlayers,
                MaxP = maxPlayers,
                Gender = gender,
                Finished = finishedAgo is null ? (DateTime?)null : DateTime.UtcNow - finishedAgo.Value,
                Window = finishedAgo is null ? (int?)null : windowHours,
            });
        return id;
    }

    /// <summary>Equipa. closedAgo = fechada há tanto tempo (fila por ordem de fecho); reserved/confirmed sobre isso.</summary>
    public static async Task<Guid> TeamAsync(
        NpgsqlDataSource db, Guid tournamentId, Guid? host = null, TimeSpan? closedAgo = null, bool reserved = false,
        bool confirmed = false, bool demo = false, string? name = null, string paymentMode = "split")
    {
        var id = Guid.NewGuid();
        var n = Interlocked.Increment(ref _n);
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            """
            INSERT INTO teams (id, tournament_id, name, color_hex, host_user_id, is_demo)
            VALUES (@Id, @T, @Name, @Color, @Host, @Demo)
            """,
            new { Id = id, T = tournamentId, Name = name ?? $"Equipa {n}", Color = $"#{(n * 7919) % 0xFFFFFF:X6}", Host = host, Demo = demo });

        if (closedAgo is not null || reserved || confirmed)
        {
            await c.ExecuteAsync(
                """
                UPDATE teams SET closed_at = @Closed, payment_mode = @Mode, share_cents = 500,
                       reserved_at = CASE WHEN @Reserved THEN now() END,
                       reservation_expires_at = CASE WHEN @Reserved THEN now() + interval '30 minutes' END,
                       confirmed_at = CASE WHEN @Confirmed THEN now() END
                WHERE id = @Id
                """,
                new
                {
                    Id = id,
                    Closed = DateTime.UtcNow - (closedAgo ?? TimeSpan.Zero),
                    Mode = paymentMode,
                    Reserved = reserved || confirmed,
                    Confirmed = confirmed,
                });
        }

        if (host is not null)
        {
            await MemberAsync(db, id, tournamentId, host.Value, paid: confirmed);
        }

        return id;
    }

    public static async Task MemberAsync(
        NpgsqlDataSource db, Guid teamId, Guid tournamentId, Guid userId, string? position = null, bool paid = false)
    {
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            """
            INSERT INTO team_members (team_id, tournament_id, user_id, position, paid_at)
            VALUES (@Team, @T, @U, @Pos, @Paid)
            """,
            new { Team = teamId, T = tournamentId, U = userId, Pos = position, Paid = paid ? DateTime.UtcNow : (DateTime?)null });
    }

    /// <summary>Jogo. startsIn negativo = já devia ter começado; null = sem data.</summary>
    public static async Task<Guid> GameAsync(
        NpgsqlDataSource db, Guid tournamentId, Guid? home, Guid? away, TimeSpan? startsIn, string status = "scheduled",
        int? homeGoals = null, int? awayGoals = null, string stage = "league", string? field = "Campo 1")
    {
        var id = Guid.NewGuid();
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            """
            INSERT INTO games (id, tournament_id, stage, home_team_id, away_team_id, scheduled_at, field_name, status, home_goals, away_goals)
            VALUES (@Id, @T, @Stage, @Home, @Away, @At, @Field, @Status, @HG, @AG)
            """,
            new
            {
                Id = id, T = tournamentId, Stage = stage, Home = home, Away = away,
                At = startsIn is null ? (DateTime?)null : DateTime.UtcNow + startsIn.Value,
                Field = field, Status = status, HG = homeGoals, AG = awayGoals,
            });
        return id;
    }

    public static async Task DeviceAsync(NpgsqlDataSource db, Guid userId, string token)
    {
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            "INSERT INTO device_tokens (id, user_id, token, platform) VALUES (gen_random_uuid(), @U, @Token, 'android')",
            new { U = userId, Token = token });
    }

    public static async Task NotificationAsync(
        NpgsqlDataSource db, Guid userId, string type, string json, TimeSpan? age = null)
    {
        await using var c = await db.OpenConnectionAsync();
        await c.ExecuteAsync(
            "INSERT INTO notifications (id, user_id, type, data, created_at) VALUES (gen_random_uuid(), @U, @Type, @Data::jsonb, @At)",
            new { U = userId, Type = type, Data = json, At = DateTime.UtcNow - (age ?? TimeSpan.Zero) });
    }
}
