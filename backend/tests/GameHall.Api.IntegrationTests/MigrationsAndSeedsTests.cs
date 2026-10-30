using System.Text.RegularExpressions;
using Dapper;
using GameHall.Api.Database;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using Xunit;

namespace GameHall.Api.IntegrationTests;

public class MigrationFilesTests
{
    private static string Dir => Path.Combine(AppContext.BaseDirectory, "Database", "Migrations");

    [Fact]
    public void Migration_files_are_numbered_without_gaps_or_duplicates()
    {
        var names = Directory.GetFiles(Dir, "*.sql").Select(Path.GetFileName).OrderBy(n => n, StringComparer.Ordinal).ToList();
        Assert.NotEmpty(names);
        for (var i = 0; i < names.Count; i++)
        {
            Assert.Matches(new Regex(@"^\d{3}_[a-z0-9_]+\.sql$"), names[i]!);
            Assert.Equal(i + 1, int.Parse(names[i]![..3]));
        }
    }
}

public class MigrationsAndSeedsTests : IAsyncLifetime
{
    private TestDb _db = null!;

    public async Task InitializeAsync()
    {
        if (Pg.Available)
        {
            _db = await TestDb.CreateAsync(migrate: false);
        }
    }

    public async Task DisposeAsync()
    {
        if (Pg.Available)
        {
            await _db.DisposeAsync();
        }
    }

    private static async Task RunFileAsync(NpgsqlDataSource src, string file)
    {
        var sql = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "seed", file));
        await using var c = await src.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand(sql, c);
        await cmd.ExecuteNonQueryAsync();
    }

    [PgFact]
    public async Task All_migrations_apply_from_scratch_and_running_again_changes_nothing()
    {
        var migrator = new Migrator(_db.Source, NullLogger<Migrator>.Instance);
        await migrator.RunAsync(CancellationToken.None);

        await using var c = await _db.Source.OpenConnectionAsync();
        var files = Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, "Database", "Migrations"), "*.sql").Length;
        Assert.Equal(files, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM schema_migrations"));

        await migrator.RunAsync(CancellationToken.None);
        Assert.Equal(files, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM schema_migrations"));

        foreach (var table in new[]
                 {
                     "users", "tournaments", "teams", "team_members", "games", "notifications", "device_tokens",
                     "voting_rounds", "votes", "platform_settings", "username_history"
                 })
        {
            Assert.True(
                await c.ExecuteScalarAsync<bool>("SELECT to_regclass(@T) IS NOT NULL", new { T = "public." + table }),
                $"falta a tabela {table}");
        }
    }

    [PgFact]
    public async Task Two_instances_starting_together_do_not_clash()
    {
        var tasks = Enumerable.Range(0, 4)
            .Select(_ => new Migrator(_db.Source, NullLogger<Migrator>.Instance).RunAsync(CancellationToken.None));
        await Task.WhenAll(tasks);

        await using var c = await _db.Source.OpenConnectionAsync();
        var files = Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, "Database", "Migrations"), "*.sql").Length;
        Assert.Equal(files, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM schema_migrations"));
    }

    [PgFact]
    public async Task Demo_seeds_run_twice_and_are_fully_removed()
    {
        await new Migrator(_db.Source, NullLogger<Migrator>.Instance).RunAsync(CancellationToken.None);

        foreach (var _ in new[] { 1, 2 })
        {
            await RunFileAsync(_db.Source, "demo_tournaments.sql");
            await RunFileAsync(_db.Source, "demo_voting.sql");
        }

        await using var c = await _db.Source.OpenConnectionAsync();
        Assert.True(await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM tournaments WHERE is_demo") > 0);
        Assert.True(await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM voting_rounds") > 0);

        await RunFileAsync(_db.Source, "remove_demo.sql");
        Assert.Equal(0, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM tournaments WHERE is_demo"));
        Assert.Equal(0, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM teams WHERE is_demo"));
        Assert.Equal(0, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM users WHERE is_demo"));
    }

    [PgFact]
    public async Task Demo_seeds_do_not_create_notifications_for_anyone()
    {
        await new Migrator(_db.Source, NullLogger<Migrator>.Instance).RunAsync(CancellationToken.None);
        await RunFileAsync(_db.Source, "demo_tournaments.sql");
        await RunFileAsync(_db.Source, "demo_voting.sql");

        await using var c = await _db.Source.OpenConnectionAsync();
        Assert.Equal(0, await c.ExecuteScalarAsync<int>("SELECT count(*)::int FROM notifications"));
    }
}
