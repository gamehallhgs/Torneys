using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Auth;

/// <summary>Acesso à base de dados (SQL explícito com Dapper). Nenhuma regra de negócio aqui.</summary>
public sealed class AuthStore(NpgsqlDataSource db)
{
    // ---------- Utilizadores ----------

    public async Task<User?> FindUserByEmailAsync(string email, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<User>(new CommandDefinition(
            "SELECT * FROM users WHERE email = @Email AND deleted_at IS NULL",
            new { Email = email }, cancellationToken: ct));
    }

    public async Task<User?> FindUserByIdAsync(Guid id, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<User>(new CommandDefinition(
            "SELECT * FROM users WHERE id = @Id AND deleted_at IS NULL",
            new { Id = id }, cancellationToken: ct));
    }

    /// <summary>Cria o utilizador e os consentimentos iniciais. Devolve false se o email já existir.</summary>
    public async Task<bool> InsertUserAsync(
        User user, IEnumerable<ConsentInsert> consents, string ipHash, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        try
        {
            await conn.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO users (id, email, password_hash, display_name, birth_date, role, created_at, updated_at)
                VALUES (@Id, @Email, @PasswordHash, @DisplayName, @BirthDate, @Role, @CreatedAt, @UpdatedAt)
                """,
                new
                {
                    user.Id,
                    user.Email,
                    user.PasswordHash,
                    user.DisplayName,
                    user.BirthDate,
                    Role = (int)user.Role,
                    user.CreatedAt,
                    user.UpdatedAt
                },
                tx, cancellationToken: ct));

            foreach (var c in consents)
            {
                await InsertConsentAsync(conn, tx, user.Id, c, ipHash, now, ct);
            }

            await tx.CommitAsync(ct);
            return true;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return false;
        }
    }

    public async Task SetLoginFailuresAsync(Guid userId, int count, DateTime? lockedUntil, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE users SET failed_login_count = @Count, locked_until = @LockedUntil, updated_at = @Now WHERE id = @UserId",
            new { UserId = userId, Count = count, LockedUntil = lockedUntil, Now = now }, cancellationToken: ct));
    }

    public async Task SetPasswordHashAsync(Guid userId, string hash, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE users
            SET password_hash = @Hash, failed_login_count = 0, locked_until = NULL, updated_at = @Now
            WHERE id = @UserId
            """,
            new { UserId = userId, Hash = hash, Now = now }, cancellationToken: ct));
    }

    public async Task MarkEmailVerifiedAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE users SET email_verified_at = COALESCE(email_verified_at, @Now), updated_at = @Now WHERE id = @UserId",
            new { UserId = userId, Now = now }, cancellationToken: ct));
    }

    /// <summary>
    /// Direito ao apagamento: remove os dados pessoais mas mantém a linha (para não quebrar histórico
    /// de torneios e registos de consentimento). O email passa a um valor único sem significado.
    /// </summary>
    public async Task AnonymizeUserAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE users
            SET email = @Email, display_name = 'Utilizador removido', password_hash = '!',
                birth_date = DATE '1900-01-01', email_verified_at = NULL, failed_login_count = 0,
                locked_until = NULL, deleted_at = @Now, updated_at = @Now
            WHERE id = @UserId
            """,
            new { UserId = userId, Email = $"deleted-{userId:N}@deleted.invalid", Now = now }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM email_codes WHERE user_id = @UserId",
            new { UserId = userId }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE refresh_tokens SET revoked_at = @Now WHERE user_id = @UserId AND revoked_at IS NULL",
            new { UserId = userId, Now = now }, tx, cancellationToken: ct));

        // Equipas: o líder que sai passa o cargo ao membro mais antigo; equipas que ficam sem ninguém desaparecem.
        await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE teams t
            SET host_user_id = (
                SELECT m.user_id FROM team_members m
                WHERE m.team_id = t.id AND m.user_id <> @UserId
                ORDER BY m.joined_at LIMIT 1)
            WHERE t.host_user_id = @UserId
              AND EXISTS (SELECT 1 FROM team_members m WHERE m.team_id = t.id AND m.user_id <> @UserId)
            """,
            new { UserId = userId }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM teams WHERE host_user_id = @UserId AND NOT is_demo",
            new { UserId = userId }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM team_members WHERE user_id = @UserId",
            new { UserId = userId }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM join_requests WHERE user_id = @UserId",
            new { UserId = userId }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            "DELETE FROM team_invites WHERE invited_user_id = @UserId OR invited_by = @UserId",
            new { UserId = userId }, tx, cancellationToken: ct));

        // Estatísticas dos jogos ficam (são do torneio), mas deixam de identificar a pessoa.
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE game_events SET user_id = NULL, player_name = 'Jogador removido' WHERE user_id = @UserId",
            new { UserId = userId }, tx, cancellationToken: ct));

        await tx.CommitAsync(ct);
    }

    // ---------- Códigos de email ----------

    public async Task CreateEmailCodeAsync(
        Guid id, Guid userId, EmailCodePurpose purpose, string codeHash, DateTime expiresAt, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        // só o código mais recente é válido
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE email_codes SET used_at = @Now WHERE user_id = @UserId AND purpose = @Purpose AND used_at IS NULL",
            new { UserId = userId, Purpose = (int)purpose, Now = now }, tx, cancellationToken: ct));

        await conn.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO email_codes (id, user_id, purpose, code_hash, expires_at, created_at)
            VALUES (@Id, @UserId, @Purpose, @CodeHash, @ExpiresAt, @Now)
            """,
            new { Id = id, UserId = userId, Purpose = (int)purpose, CodeHash = codeHash, ExpiresAt = expiresAt, Now = now },
            tx, cancellationToken: ct));

        await tx.CommitAsync(ct);
    }

    public async Task<EmailCodeRow?> GetActiveCodeAsync(
        Guid userId, EmailCodePurpose purpose, DateTime now, int maxAttempts, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<EmailCodeRow>(new CommandDefinition(
            """
            SELECT * FROM email_codes
            WHERE user_id = @UserId AND purpose = @Purpose AND used_at IS NULL
              AND expires_at > @Now AND attempts < @MaxAttempts
            ORDER BY created_at DESC
            LIMIT 1
            """,
            new { UserId = userId, Purpose = (int)purpose, Now = now, MaxAttempts = maxAttempts }, cancellationToken: ct));
    }

    public async Task<DateTime?> GetLastCodeCreatedAtAsync(Guid userId, EmailCodePurpose purpose, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.ExecuteScalarAsync<DateTime?>(new CommandDefinition(
            "SELECT max(created_at) FROM email_codes WHERE user_id = @UserId AND purpose = @Purpose",
            new { UserId = userId, Purpose = (int)purpose }, cancellationToken: ct));
    }

    public async Task IncrementCodeAttemptsAsync(Guid codeId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE email_codes SET attempts = attempts + 1 WHERE id = @Id",
            new { Id = codeId }, cancellationToken: ct));
    }

    /// <summary>Marca o código como usado. Devolve false se outro pedido o usou entretanto.</summary>
    public async Task<bool> MarkCodeUsedAsync(Guid codeId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var affected = await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE email_codes SET used_at = @Now WHERE id = @Id AND used_at IS NULL",
            new { Id = codeId, Now = now }, cancellationToken: ct));
        return affected == 1;
    }

    // ---------- Refresh tokens ----------

    public async Task InsertRefreshTokenAsync(RefreshTokenRow row, string? ipHash, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO refresh_tokens
              (id, user_id, family_id, family_created_at, token_hash, created_at, expires_at, device_name, ip_hash)
            VALUES
              (@Id, @UserId, @FamilyId, @FamilyCreatedAt, @TokenHash, @CreatedAt, @ExpiresAt, @DeviceName, @IpHash)
            """,
            new
            {
                row.Id,
                row.UserId,
                row.FamilyId,
                row.FamilyCreatedAt,
                row.TokenHash,
                row.CreatedAt,
                row.ExpiresAt,
                row.DeviceName,
                IpHash = ipHash
            },
            cancellationToken: ct));
    }

    public async Task<RefreshTokenRow?> FindRefreshTokenAsync(string tokenHash, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<RefreshTokenRow>(new CommandDefinition(
            "SELECT * FROM refresh_tokens WHERE token_hash = @TokenHash",
            new { TokenHash = tokenHash }, cancellationToken: ct));
    }

    /// <summary>Revoga um token (rotação). Devolve false se já tinha sido revogado (pedido concorrente).</summary>
    public async Task<bool> RevokeRefreshTokenAsync(Guid tokenId, Guid replacedBy, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var affected = await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE refresh_tokens SET revoked_at = @Now, replaced_by = @ReplacedBy WHERE id = @Id AND revoked_at IS NULL",
            new { Id = tokenId, ReplacedBy = replacedBy, Now = now }, cancellationToken: ct));
        return affected == 1;
    }

    public async Task RevokeFamilyAsync(Guid familyId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE refresh_tokens SET revoked_at = @Now WHERE family_id = @FamilyId AND revoked_at IS NULL",
            new { FamilyId = familyId, Now = now }, cancellationToken: ct));
    }

    public async Task RevokeAllTokensAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE refresh_tokens SET revoked_at = @Now WHERE user_id = @UserId AND revoked_at IS NULL",
            new { UserId = userId, Now = now }, cancellationToken: ct));
    }

    // ---------- Consentimentos ----------

    public async Task AddConsentsAsync(
        Guid userId, IEnumerable<ConsentInsert> consents, string ipHash, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        foreach (var c in consents)
        {
            await InsertConsentAsync(conn, tx, userId, c, ipHash, now, ct);
        }

        await tx.CommitAsync(ct);
    }

    /// <summary>Último estado de cada documento legal obrigatório (terms, privacy).</summary>
    public async Task<IReadOnlyList<ConsentRow>> GetCurrentLegalConsentsAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<ConsentRow>(new CommandDefinition(
            """
            SELECT DISTINCT ON (document_type) document_type, version, content_hash, granted, created_at
            FROM user_consents
            WHERE user_id = @UserId AND document_type IN ('terms', 'privacy')
            ORDER BY document_type, created_at DESC
            """,
            new { UserId = userId }, cancellationToken: ct));
        return rows.ToList();
    }

    public async Task<IReadOnlyList<ConsentRow>> GetAllConsentsAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<ConsentRow>(new CommandDefinition(
            """
            SELECT document_type, version, content_hash, granted, created_at
            FROM user_consents WHERE user_id = @UserId ORDER BY created_at
            """,
            new { UserId = userId }, cancellationToken: ct));
        return rows.ToList();
    }

    private static Task InsertConsentAsync(
        NpgsqlConnection conn, NpgsqlTransaction tx, Guid userId, ConsentInsert c, string ipHash, DateTime now, CancellationToken ct) =>
        conn.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO user_consents (id, user_id, document_type, version, content_hash, granted, ip_hash, created_at)
            VALUES (@Id, @UserId, @DocumentType, @Version, @ContentHash, @Granted, @IpHash, @Now)
            """,
            new
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                c.DocumentType,
                c.Version,
                c.ContentHash,
                c.Granted,
                IpHash = ipHash,
                Now = now
            },
            tx, cancellationToken: ct));

    // ---------- Auditoria ----------

    public async Task AuditAsync(Guid? userId, string action, string? ipHash, DateTime now, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "INSERT INTO audit_log (user_id, action, ip_hash, created_at) VALUES (@UserId, @Action, @IpHash, @Now)",
            new { UserId = userId, Action = action, IpHash = ipHash, Now = now }, cancellationToken: ct));
    }

    public async Task<IReadOnlyList<AuditRow>> GetAuditAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<AuditRow>(new CommandDefinition(
            "SELECT action, created_at FROM audit_log WHERE user_id = @UserId ORDER BY created_at DESC LIMIT 500",
            new { UserId = userId }, cancellationToken: ct));
        return rows.ToList();
    }
}
