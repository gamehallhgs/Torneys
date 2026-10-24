using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using GameHall.Api.Common;
using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Infrastructure.Security;
using GameHall.Api.Modules.Legal;
using Microsoft.Extensions.Options;

namespace GameHall.Api.Modules.Auth;

/// <summary>
/// Regras de negócio da autenticação. Princípios:
///  - respostas uniformes para não revelar se um email existe (registo, esquecimento, verificação);
///  - tempo de resposta uniforme (hash falso quando o utilizador não existe);
///  - bloqueio temporário após falhas repetidas, com aviso por email;
///  - refresh tokens rotativos com deteção de reutilização (revoga a sessão inteira);
///  - nunca registar emails, palavras-passe ou tokens nos logs.
/// </summary>
public sealed class AuthService(
    AuthStore store,
    UsernameStore usernames,
    PasswordHasher hasher,
    PwnedPasswordChecker pwned,
    TokenService tokens,
    IEmailSender email,
    LegalDocuments legal,
    IOptions<SecurityOptions> securityOptions,
    IOptions<JwtOptions> jwtOptions,
    TimeProvider clock,
    ILogger<AuthService> log)
{
    private readonly SecurityOptions _sec = securityOptions.Value;
    private readonly JwtOptions _jwt = jwtOptions.Value;

    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    // ======================= Registo e verificação =======================

    /// <summary>Devolve null em sucesso. A resposta HTTP é igual quer o email exista ou não.</summary>
    public async Task<ApiError?> RegisterAsync(RegisterRequest req, string ip, CancellationToken ct)
    {
        var now = Now;
        var errors = new Dictionary<string, string[]>();

        var emailNorm = AuthValidation.NormalizeEmail(req.Email);
        if (emailNorm is null)
        {
            errors["email"] = ["Email inválido."];
        }

        var displayName = (req.DisplayName ?? "").Trim();
        if (!AuthValidation.IsValidDisplayName(displayName))
        {
            errors["displayName"] = ["O nome deve ter entre 2 e 40 caracteres."];
        }

        var username = UsernameRules.Normalize(req.Username);
        var usernameProblem = UsernameRules.Validate(username);
        if (usernameProblem is not null)
        {
            errors["username"] = [usernameProblem];
        }

        var birthDate = default(DateOnly);
        if (!DateOnly.TryParseExact(req.BirthDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out birthDate))
        {
            errors["birthDate"] = ["Data de nascimento inválida (formato AAAA-MM-DD)."];
        }
        else
        {
            var today = DateOnly.FromDateTime(now);
            var age = AgeCalculator.AgeOn(birthDate, today);
            if (birthDate > today || age > 120)
            {
                errors["birthDate"] = ["Data de nascimento inválida."];
            }
            else if (age < _sec.MinimumAge)
            {
                // Não guardamos nada de quem não cumpre a idade mínima.
                return Errors.AgeTooYoung(_sec.MinimumAge);
            }
        }

        var passwordProblems = PasswordPolicy.Validate(req.Password, emailNorm, displayName);
        if (passwordProblems.Count > 0)
        {
            errors["password"] = passwordProblems.Select(PasswordPolicy.Describe).ToArray();
        }

        if (errors.Count > 0)
        {
            return ApiError.Validation(errors);
        }

        if (!req.AcceptTerms || !req.AcceptPrivacy)
        {
            return Errors.LegalNotAccepted;
        }

        if (req.TermsVersion != legal.Terms.Version || req.PrivacyVersion != legal.Privacy.Version)
        {
            return Errors.LegalVersionOutdated;
        }

        if (await pwned.IsPwnedAsync(req.Password!, ct))
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["password"] = ["Esta palavra-passe apareceu em fugas de dados conhecidas. Escolhe outra."]
            });
        }

        // O username tem de estar livre (os usernames não são segredo; ao contrário do email, podemos dizê-lo).
        var availability = await usernames.CheckAsync(username, null, now, ct);
        if (availability != UsernameAvailability.Available)
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["username"] = [availability == UsernameAvailability.Taken
                    ? "Este username já está em uso."
                    : "Este username foi usado há pouco tempo e está reservado."]
            });
        }

        // O hash é calculado sempre (mesmo que o email exista) para o tempo de resposta ser igual.
        var passwordHash = hasher.Hash(req.Password!);

        var existing = await store.FindUserByEmailAsync(emailNorm!, ct);
        if (existing is not null)
        {
            var (subject, body) = EmailTemplates.AlreadyRegistered(existing.DisplayName);
            await TrySendAsync(existing.Email, subject, body, ct);
            return null;
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = emailNorm!,
            PasswordHash = passwordHash,
            DisplayName = displayName,
            Username = username,
            UsernameTag = UsernameRules.NewTag(),
            BirthDate = birthDate,
            Role = UserRole.Player,
            CreatedAt = now,
            UpdatedAt = now
        };

        var consents = new[]
        {
            new ConsentInsert("terms", legal.Terms.Version, legal.Terms.Hash, true),
            new ConsentInsert("privacy", legal.Privacy.Version, legal.Privacy.Hash, true)
        };

        var ipHash = IpHash(ip);
        var inserted = await store.InsertUserAsync(user, consents, ipHash, now, ct);
        if (inserted == InsertUserResult.UsernameTaken)
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["username"] = ["Este username já está em uso."]
            });
        }

        if (inserted == InsertUserResult.EmailTaken)
        {
            return null; // pedido concorrente com o mesmo email: tratado como "já existe"
        }

        await store.AuditAsync(user.Id, "register", ipHash, now, ct);
        await SendCodeAsync(user, EmailCodePurpose.VerifyEmail, ct);
        return null;
    }

    public async Task<ApiError?> VerifyEmailAsync(string? emailInput, string? code, string ip, CancellationToken ct)
    {
        var user = await FindByEmailInputAsync(emailInput, ct);
        if (user is null || user.EmailVerifiedAt is not null)
        {
            return Errors.InvalidCode;
        }

        if (!await ConsumeCodeAsync(user, EmailCodePurpose.VerifyEmail, code, ct))
        {
            return Errors.InvalidCode;
        }

        await store.MarkEmailVerifiedAsync(user.Id, Now, ct);
        await store.AuditAsync(user.Id, "email_verified", IpHash(ip), Now, ct);
        return null;
    }

    public async Task ResendVerificationAsync(string? emailInput, CancellationToken ct)
    {
        var user = await FindByEmailInputAsync(emailInput, ct);
        if (user is null || user.EmailVerifiedAt is not null)
        {
            return;
        }

        await SendCodeAsync(user, EmailCodePurpose.VerifyEmail, ct);
    }

    // ======================= Sessões =======================

    public async Task<Outcome<AuthResponse>> LoginAsync(LoginRequest req, string ip, CancellationToken ct)
    {
        var now = Now;
        var ipHash = IpHash(ip);
        var password = req.Password ?? "";
        var user = await FindByEmailInputAsync(req.Email, ct);

        if (user is null)
        {
            hasher.VerifyDummy(password);
            return Outcome<AuthResponse>.Fail(Errors.InvalidCredentials);
        }

        // Conta bloqueada: resposta idêntica a credenciais erradas (não confirma que a conta existe).
        if (user.LockedUntil is not null && user.LockedUntil > now)
        {
            hasher.VerifyDummy(password);
            return Outcome<AuthResponse>.Fail(Errors.InvalidCredentials);
        }

        if (!hasher.Verify(password, user.PasswordHash))
        {
            var failures = user.FailedLoginCount + 1;
            DateTime? lockedUntil = null;
            if (failures >= _sec.MaxFailedLogins)
            {
                lockedUntil = now.AddMinutes(_sec.LockoutMinutes);
                failures = 0;
                await store.AuditAsync(user.Id, "account_locked", ipHash, now, ct);
                var (subject, body) = EmailTemplates.AccountLocked(user.DisplayName, _sec.LockoutMinutes);
                await TrySendAsync(user.Email, subject, body, ct);
            }

            await store.SetLoginFailuresAsync(user.Id, failures, lockedUntil, now, ct);
            return Outcome<AuthResponse>.Fail(Errors.InvalidCredentials);
        }

        // Palavra-passe certa: a partir daqui já podemos dizer o que falta.
        if (user.EmailVerifiedAt is null)
        {
            return Outcome<AuthResponse>.Fail(Errors.EmailNotVerified);
        }

        if (user.FailedLoginCount > 0 || user.LockedUntil is not null)
        {
            await store.SetLoginFailuresAsync(user.Id, 0, null, now, ct);
        }

        if (hasher.NeedsRehash(user.PasswordHash))
        {
            await store.SetPasswordHashAsync(user.Id, hasher.Hash(password), now, ct);
        }

        var refreshToken = TokenService.NewRefreshToken();
        var familyId = Guid.NewGuid();
        await store.InsertRefreshTokenAsync(new RefreshTokenRow
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            FamilyId = familyId,
            FamilyCreatedAt = now,
            TokenHash = Hashing.Sha256Hex(refreshToken),
            CreatedAt = now,
            ExpiresAt = now.AddDays(_jwt.RefreshTokenDays),
            DeviceName = Truncate(req.DeviceName, 80)
        }, ipHash, ct);

        await store.AuditAsync(user.Id, "login", ipHash, now, ct);
        return Outcome<AuthResponse>.Ok(await BuildResponseAsync(user, refreshToken, ct));
    }

    public async Task<Outcome<AuthResponse>> RefreshAsync(string? refreshToken, string ip, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(refreshToken) || refreshToken.Length > 200)
        {
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        var now = Now;
        var ipHash = IpHash(ip);
        var row = await store.FindRefreshTokenAsync(Hashing.Sha256Hex(refreshToken), ct);
        if (row is null)
        {
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        if (row.RevokedAt is not null)
        {
            // Um token já rodado foi apresentado outra vez: pode ter sido roubado.
            // Revogamos a sessão inteira; o utilizador legítimo terá de iniciar sessão de novo.
            await store.RevokeFamilyAsync(row.FamilyId, now, ct);
            await store.AuditAsync(row.UserId, "refresh_token_reuse_detected", ipHash, now, ct);
            log.LogWarning("Reutilização de refresh token detetada; sessão revogada.");
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        if (row.ExpiresAt <= now)
        {
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        var user = await store.FindUserByIdAsync(row.UserId, ct);
        if (user is null)
        {
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        var familyLimit = row.FamilyCreatedAt.AddDays(_jwt.RefreshFamilyMaxDays);
        var expires = now.AddDays(_jwt.RefreshTokenDays);
        if (expires > familyLimit)
        {
            expires = familyLimit;
        }

        if (expires <= now)
        {
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        var newToken = TokenService.NewRefreshToken();
        var newRow = new RefreshTokenRow
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            FamilyId = row.FamilyId,
            FamilyCreatedAt = row.FamilyCreatedAt,
            TokenHash = Hashing.Sha256Hex(newToken),
            CreatedAt = now,
            ExpiresAt = expires,
            DeviceName = row.DeviceName
        };

        await store.InsertRefreshTokenAsync(newRow, ipHash, ct);
        if (!await store.RevokeRefreshTokenAsync(row.Id, newRow.Id, now, ct))
        {
            // Outro pedido rodou o mesmo token ao mesmo tempo.
            await store.RevokeFamilyAsync(row.FamilyId, now, ct);
            return Outcome<AuthResponse>.Fail(Errors.InvalidRefreshToken);
        }

        return Outcome<AuthResponse>.Ok(await BuildResponseAsync(user, newToken, ct));
    }

    public async Task LogoutAsync(string? refreshToken, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(refreshToken) || refreshToken.Length > 200)
        {
            return;
        }

        var row = await store.FindRefreshTokenAsync(Hashing.Sha256Hex(refreshToken), ct);
        if (row is not null)
        {
            await store.RevokeFamilyAsync(row.FamilyId, Now, ct);
        }
    }

    public async Task LogoutAllAsync(Guid userId, string ip, CancellationToken ct)
    {
        await store.RevokeAllTokensAsync(userId, Now, ct);
        await store.AuditAsync(userId, "logout_all", IpHash(ip), Now, ct);
    }

    // ======================= Palavra-passe =======================

    public async Task ForgotPasswordAsync(string? emailInput, CancellationToken ct)
    {
        var user = await FindByEmailInputAsync(emailInput, ct);
        if (user is null)
        {
            return;
        }

        await SendCodeAsync(user, EmailCodePurpose.ResetPassword, ct);
    }

    public async Task<ApiError?> ResetPasswordAsync(ResetPasswordRequest req, string ip, CancellationToken ct)
    {
        // A palavra-passe é validada ANTES de procurar o utilizador, para que a resposta
        // não revele se o email existe.
        var problems = PasswordPolicy.Validate(req.NewPassword, AuthValidation.NormalizeEmail(req.Email), null);
        if (problems.Count > 0)
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["newPassword"] = problems.Select(PasswordPolicy.Describe).ToArray()
            });
        }

        if (await pwned.IsPwnedAsync(req.NewPassword!, ct))
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["newPassword"] = ["Esta palavra-passe apareceu em fugas de dados conhecidas. Escolhe outra."]
            });
        }

        var user = await FindByEmailInputAsync(req.Email, ct);
        if (user is null)
        {
            return Errors.InvalidCode;
        }

        if (!await ConsumeCodeAsync(user, EmailCodePurpose.ResetPassword, req.Code, ct))
        {
            return Errors.InvalidCode;
        }

        var now = Now;
        await store.SetPasswordHashAsync(user.Id, hasher.Hash(req.NewPassword!), now, ct);
        await store.MarkEmailVerifiedAsync(user.Id, now, ct); // o código chegou ao email: prova de posse
        await store.RevokeAllTokensAsync(user.Id, now, ct);
        await store.AuditAsync(user.Id, "password_reset", IpHash(ip), now, ct);

        var (subject, body) = EmailTemplates.PasswordChanged(user.DisplayName);
        await TrySendAsync(user.Email, subject, body, ct);
        return null;
    }

    public async Task<ApiError?> ChangePasswordAsync(Guid userId, ChangePasswordRequest req, string ip, CancellationToken ct)
    {
        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null)
        {
            return Errors.UserNotFound;
        }

        if (string.IsNullOrEmpty(req.CurrentPassword) || !hasher.Verify(req.CurrentPassword, user.PasswordHash))
        {
            return Errors.InvalidCredentials;
        }

        var problems = PasswordPolicy.Validate(req.NewPassword, user.Email, user.DisplayName);
        if (problems.Count > 0)
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["newPassword"] = problems.Select(PasswordPolicy.Describe).ToArray()
            });
        }

        if (await pwned.IsPwnedAsync(req.NewPassword!, ct))
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["newPassword"] = ["Esta palavra-passe apareceu em fugas de dados conhecidas. Escolhe outra."]
            });
        }

        var now = Now;
        await store.SetPasswordHashAsync(user.Id, hasher.Hash(req.NewPassword!), now, ct);
        await store.RevokeAllTokensAsync(user.Id, now, ct);
        await store.AuditAsync(user.Id, "password_changed", IpHash(ip), now, ct);

        var (subject, body) = EmailTemplates.PasswordChanged(user.DisplayName);
        await TrySendAsync(user.Email, subject, body, ct);
        return null;
    }

    // ======================= Termos e consentimentos =======================

    public async Task<ApiError?> AcceptLegalAsync(Guid userId, AcceptLegalRequest req, string ip, CancellationToken ct)
    {
        if (req.TermsVersion != legal.Terms.Version || req.PrivacyVersion != legal.Privacy.Version)
        {
            return Errors.LegalVersionOutdated;
        }

        var now = Now;
        var ipHash = IpHash(ip);
        await store.AddConsentsAsync(userId,
        [
            new ConsentInsert("terms", legal.Terms.Version, legal.Terms.Hash, true),
            new ConsentInsert("privacy", legal.Privacy.Version, legal.Privacy.Hash, true)
        ], ipHash, now, ct);
        await store.AuditAsync(userId, "legal_accepted", ipHash, now, ct);
        return null;
    }

    public LegalStatusDto LegalStatus(bool accepted) =>
        new(legal.Terms.Version, legal.Privacy.Version, RequiresAcceptance: !accepted);

    // ======================= Eliminar conta =======================

    public async Task<ApiError?> DeleteAccountAsync(Guid userId, string? password, string ip, CancellationToken ct)
    {
        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null)
        {
            return Errors.UserNotFound;
        }

        if (string.IsNullOrEmpty(password) || !hasher.Verify(password, user.PasswordHash))
        {
            return Errors.InvalidCredentials;
        }

        var now = Now;
        var (subject, body) = EmailTemplates.AccountDeleted(user.DisplayName);
        var originalEmail = user.Email;

        // TODO (fases seguintes): antes de anonimizar, tratar equipas onde o utilizador é host
        // (transferir o cargo ou dissolver a equipa) e inscrições em torneios a decorrer.
        await store.AnonymizeUserAsync(userId, now, ct);
        await store.AuditAsync(userId, "account_deleted", IpHash(ip), now, ct);

        await TrySendAsync(originalEmail, subject, body, ct);
        return null;
    }

    // ======================= Auxiliares =======================

    private async Task<User?> FindByEmailInputAsync(string? emailInput, CancellationToken ct)
    {
        var normalized = AuthValidation.NormalizeEmail(emailInput);
        return normalized is null ? null : await store.FindUserByEmailAsync(normalized, ct);
    }

    public async Task<bool> IsLegalCurrentAsync(Guid userId, CancellationToken ct)
    {
        var rows = await store.GetCurrentLegalConsentsAsync(userId, ct);
        var terms = rows.FirstOrDefault(r => r.DocumentType == "terms");
        var privacy = rows.FirstOrDefault(r => r.DocumentType == "privacy");
        return terms is { Granted: true } && terms.Version == legal.Terms.Version &&
               privacy is { Granted: true } && privacy.Version == legal.Privacy.Version;
    }

    private async Task<AuthResponse> BuildResponseAsync(User user, string refreshToken, CancellationToken ct)
    {
        var legalOk = await IsLegalCurrentAsync(user.Id, ct);
        var (accessToken, expiresIn) = tokens.CreateAccessToken(user, legalOk);
        return new AuthResponse(
            "Bearer",
            accessToken,
            expiresIn,
            refreshToken,
            ToDto(user),
            LegalStatus(legalOk));
    }

    public static UserDto ToDto(User user) =>
        new(user.Id, user.Email, user.DisplayName, user.Role.ToString(), user.EmailVerifiedAt is not null, user.BirthDate,
            user.Username, user.UsernameTag,
            UsernameRules.NextChangeAt(user.UsernameChangedAt, DateTime.UtcNow));

    private async Task SendCodeAsync(User user, EmailCodePurpose purpose, CancellationToken ct)
    {
        var now = Now;

        // No máximo um código por minuto (evita spam de emails e abuso do envio).
        var last = await store.GetLastCodeCreatedAtAsync(user.Id, purpose, ct);
        if (last is not null && (now - last.Value).TotalSeconds < _sec.EmailResendSeconds)
        {
            return;
        }

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6", CultureInfo.InvariantCulture);
        await store.CreateEmailCodeAsync(
            Guid.NewGuid(), user.Id, purpose, CodeHash(user.Id, purpose, code),
            now.AddMinutes(_sec.EmailCodeMinutes), now, ct);

        var (subject, body) = purpose == EmailCodePurpose.VerifyEmail
            ? EmailTemplates.VerifyEmail(user.DisplayName, code, _sec.EmailCodeMinutes)
            : EmailTemplates.ResetPassword(user.DisplayName, code, _sec.EmailCodeMinutes);
        await TrySendAsync(user.Email, subject, body, ct);
    }

    private async Task<bool> ConsumeCodeAsync(User user, EmailCodePurpose purpose, string? code, CancellationToken ct)
    {
        if (code is null || code.Length != 6 || !code.All(char.IsAsciiDigit))
        {
            return false;
        }

        var row = await store.GetActiveCodeAsync(user.Id, purpose, Now, _sec.EmailCodeMaxAttempts, ct);
        if (row is null)
        {
            return false;
        }

        var expected = Encoding.UTF8.GetBytes(row.CodeHash);
        var actual = Encoding.UTF8.GetBytes(CodeHash(user.Id, purpose, code));
        if (!CryptographicOperations.FixedTimeEquals(expected, actual))
        {
            await store.IncrementCodeAttemptsAsync(row.Id, ct);
            return false;
        }

        return await store.MarkCodeUsedAsync(row.Id, Now, ct);
    }

    private string CodeHash(Guid userId, EmailCodePurpose purpose, string code) =>
        Hashing.Hmac(_sec.Pepper, $"emailcode:{(int)purpose}:{userId:N}", code);

    private string IpHash(string ip) => Hashing.Hmac(_sec.Pepper, "ip", ip)[..16];

    private static string? Truncate(string? value, int max) =>
        string.IsNullOrWhiteSpace(value) ? null : (value.Length <= max ? value : value[..max]);

    /// <summary>Falhas de envio nunca devem partir o pedido nem revelar nada ao cliente.</summary>
    private async Task TrySendAsync(string to, string subject, string body, CancellationToken ct)
    {
        try
        {
            await email.SendAsync(to, subject, body, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            log.LogError(ex, "Falha ao enviar email (assunto: {Subject}).", subject);
        }
    }
}
