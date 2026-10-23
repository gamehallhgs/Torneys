using Npgsql;

namespace GameHall.Api.Database;

/// <summary>
/// Aplica os ficheiros Database/Migrations/*.sql por ordem, uma única vez cada, dentro de uma transação.
/// Usa um "advisory lock" para que duas instâncias da API a arrancar em simultâneo não colidam.
/// </summary>
public sealed class Migrator(NpgsqlDataSource db, ILogger<Migrator> log)
{
    private const long LockKey = 727274;

    public async Task RunAsync(CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await ExecuteAsync(conn, $"SELECT pg_advisory_lock({LockKey})", ct);
        try
        {
            await ExecuteAsync(conn,
                "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
                ct);

            var applied = new HashSet<string>(StringComparer.Ordinal);
            await using (var cmd = new NpgsqlCommand("SELECT version FROM schema_migrations", conn))
            await using (var reader = await cmd.ExecuteReaderAsync(ct))
            {
                while (await reader.ReadAsync(ct))
                {
                    applied.Add(reader.GetString(0));
                }
            }

            var dir = Path.Combine(AppContext.BaseDirectory, "Database", "Migrations");
            if (!Directory.Exists(dir))
            {
                throw new InvalidOperationException($"Pasta de migrações não encontrada: {dir}");
            }

            var files = Directory.GetFiles(dir, "*.sql")
                .OrderBy(f => Path.GetFileName(f), StringComparer.Ordinal);

            foreach (var file in files)
            {
                var version = Path.GetFileNameWithoutExtension(file);
                if (applied.Contains(version))
                {
                    continue;
                }

                log.LogInformation("A aplicar migração {Version}", version);
                var sql = await File.ReadAllTextAsync(file, ct);

                await using var tx = await conn.BeginTransactionAsync(ct);
                await using (var run = new NpgsqlCommand(sql, conn, tx))
                {
                    await run.ExecuteNonQueryAsync(ct);
                }

                await using (var mark = new NpgsqlCommand("INSERT INTO schema_migrations (version) VALUES (@v)", conn, tx))
                {
                    mark.Parameters.AddWithValue("v", version);
                    await mark.ExecuteNonQueryAsync(ct);
                }

                await tx.CommitAsync(ct);
            }
        }
        finally
        {
            await ExecuteAsync(conn, $"SELECT pg_advisory_unlock({LockKey})", CancellationToken.None);
        }
    }

    private static async Task ExecuteAsync(NpgsqlConnection conn, string sql, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(sql, conn);
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
