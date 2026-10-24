using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Auth;

public enum UsernameAvailability
{
    Available,
    Taken,

    /// <summary>Foi o username de outra pessoa há menos de 30 dias e está reservado.</summary>
    RecentlyUsed
}

public enum UsernameChangeResult
{
    Changed,
    Unchanged,
    Taken,
    RecentlyUsed,
    Cooldown,
    UserNotFound
}

public sealed class CurrentUsernameRow
{
    public string Username { get; set; } = "";
    public DateTime? UsernameChangedAt { get; set; }
}

public sealed record UsernameChange(UsernameChangeResult Result, DateTime? NextChangeAt = null, string? Username = null);

/// <summary>SQL dos usernames (disponibilidade, mudança, procura por username#tag e falhas de procura).</summary>
public sealed class UsernameStore(NpgsqlDataSource db)
{
    private const string TakenSql =
        "SELECT EXISTS (SELECT 1 FROM users WHERE username = @U AND (@Me::uuid IS NULL OR id <> @Me::uuid))";

    private const string RecentSql =
        """
        SELECT EXISTS (SELECT 1 FROM username_history
                       WHERE username = @U AND released_at > @Since AND (@Me::uuid IS NULL OR user_id <> @Me::uuid))
        """;

    /// <summary>O username (já normalizado e válido) está livre para este utilizador (null = ainda sem conta)?</summary>
    public async Task<UsernameAvailability> CheckAsync(string username, Guid? me, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var args = new { U = username, Me = me, Since = now.AddDays(-UsernameRules.ReservedAfterChangeDays) };
        if (await conn.ExecuteScalarAsync<bool>(new CommandDefinition(TakenSql, args, cancellationToken: ct)))
        {
            return UsernameAvailability.Taken;
        }

        return await conn.ExecuteScalarAsync<bool>(new CommandDefinition(RecentSql, args, cancellationToken: ct))
            ? UsernameAvailability.RecentlyUsed
            : UsernameAvailability.Available;
    }

    /// <summary>Muda o username (1 vez por mês). O antigo fica reservado 30 dias. Tudo numa transação.</summary>
    public async Task<UsernameChange> ChangeAsync(Guid userId, string newUsername, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        var current = await conn.QuerySingleOrDefaultAsync<CurrentUsernameRow>(new CommandDefinition(
            "SELECT username, username_changed_at FROM users WHERE id = @Id AND deleted_at IS NULL FOR UPDATE",
            new { Id = userId }, tx, cancellationToken: ct));
        if (current is null)
        {
            return new UsernameChange(UsernameChangeResult.UserNotFound);
        }

        if (current.Username == newUsername)
        {
            return new UsernameChange(UsernameChangeResult.Unchanged, Username: newUsername);
        }

        var next = UsernameRules.NextChangeAt(current.UsernameChangedAt, now);
        if (next is not null)
        {
            return new UsernameChange(UsernameChangeResult.Cooldown, next);
        }

        var args = new { U = newUsername, Me = (Guid?)userId, Since = now.AddDays(-UsernameRules.ReservedAfterChangeDays) };
        if (await conn.ExecuteScalarAsync<bool>(new CommandDefinition(TakenSql, args, tx, cancellationToken: ct)))
        {
            return new UsernameChange(UsernameChangeResult.Taken);
        }

        if (await conn.ExecuteScalarAsync<bool>(new CommandDefinition(RecentSql, args, tx, cancellationToken: ct)))
        {
            return new UsernameChange(UsernameChangeResult.RecentlyUsed);
        }

        try
        {
            await conn.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO username_history (username, user_id, released_at) VALUES (@Old, @Id, @Now)
                ON CONFLICT (username) DO UPDATE SET user_id = EXCLUDED.user_id, released_at = EXCLUDED.released_at
                """,
                new { Old = current.Username, Id = userId, Now = now }, tx, cancellationToken: ct));

            // Se o novo username era um antigo dele próprio, deixa de estar "reservado".
            await conn.ExecuteAsync(new CommandDefinition(
                "DELETE FROM username_history WHERE username = @U",
                new { U = newUsername }, tx, cancellationToken: ct));

            await conn.ExecuteAsync(new CommandDefinition(
                "UPDATE users SET username = @U, username_changed_at = @Now, updated_at = @Now WHERE id = @Id",
                new { U = newUsername, Now = now, Id = userId }, tx, cancellationToken: ct));

            await tx.CommitAsync(ct);
            return new UsernameChange(UsernameChangeResult.Changed, Username: newUsername);
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return new UsernameChange(UsernameChangeResult.Taken); // corrida com outro registo
        }
    }

    /// <summary>Utilizador com este username E esta tag, com o email verificado (senão não pode iniciar sessão).</summary>
    public async Task<User?> FindByHandleAsync(string username, string tag, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<User>(new CommandDefinition(
            """
            SELECT * FROM users
            WHERE username = @U AND username_tag = @T AND deleted_at IS NULL AND email_verified_at IS NOT NULL
            """,
            new { U = username, T = tag }, cancellationToken: ct));
    }

    // ---------- Limite de tentativas falhadas (convidar por username#tag) ----------

    public async Task<int> CountFailuresAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT count(*)::int FROM username_lookup_failures WHERE user_id = @U AND created_at > @Since",
            new { U = userId, Since = now.AddHours(-1) }, cancellationToken: ct));
    }

    public async Task RecordFailureAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            """
            DELETE FROM username_lookup_failures WHERE user_id = @U AND created_at < @Old;
            INSERT INTO username_lookup_failures (user_id, created_at) VALUES (@U, @Now);
            """,
            new { U = userId, Now = now, Old = now.AddHours(-24) }, cancellationToken: ct));
    }
}
