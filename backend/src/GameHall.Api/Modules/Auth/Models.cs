namespace GameHall.Api.Modules.Auth;

/// <summary>
/// Perfil global do utilizador. No futuro, funções por entidade (ex.: gestor da associação X,
/// árbitro com permissões limitadas) serão tabelas próprias; aqui fica só o papel base.
/// </summary>
public enum UserRole
{
    Player = 0,
    Referee = 1,
    Manager = 2,
    Admin = 3
}

public enum EmailCodePurpose
{
    VerifyEmail = 0,
    ResetPassword = 1
}

public sealed class User
{
    public Guid Id { get; set; }
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public DateOnly BirthDate { get; set; }
    public UserRole Role { get; set; }
    public DateTime? EmailVerifiedAt { get; set; }
    public int FailedLoginCount { get; set; }
    public DateTime? LockedUntil { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
}

public sealed class RefreshTokenRow
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid FamilyId { get; set; }
    public DateTime FamilyCreatedAt { get; set; }
    public string TokenHash { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public Guid? ReplacedBy { get; set; }
    public string? DeviceName { get; set; }
}

public sealed class EmailCodeRow
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public int Purpose { get; set; }
    public string CodeHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public DateTime? UsedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class ConsentRow
{
    public string DocumentType { get; set; } = "";
    public string Version { get; set; } = "";
    public string ContentHash { get; set; } = "";
    public bool Granted { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class AuditRow
{
    public string Action { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public sealed record ConsentInsert(string DocumentType, string Version, string ContentHash, bool Granted);

// ---------- Pedidos ----------

public sealed record RegisterRequest(
    string? Email,
    string? Password,
    string? DisplayName,
    string? BirthDate,
    bool AcceptTerms,
    bool AcceptPrivacy,
    string? TermsVersion,
    string? PrivacyVersion);

public sealed record EmailCodeRequest(string? Email, string? Code);

public sealed record EmailOnlyRequest(string? Email);

public sealed record LoginRequest(string? Email, string? Password, string? DeviceName);

public sealed record RefreshRequest(string? RefreshToken);

public sealed record ResetPasswordRequest(string? Email, string? Code, string? NewPassword);

public sealed record ChangePasswordRequest(string? CurrentPassword, string? NewPassword);

public sealed record AcceptLegalRequest(string? TermsVersion, string? PrivacyVersion);

public sealed record DeleteAccountRequest(string? Password);

// ---------- Respostas ----------

public sealed record UserDto(Guid Id, string Email, string DisplayName, string Role, bool EmailVerified, DateOnly BirthDate);

public sealed record LegalStatusDto(string TermsVersion, string PrivacyVersion, bool RequiresAcceptance);

public sealed record AuthResponse(
    string TokenType,
    string AccessToken,
    int ExpiresIn,
    string RefreshToken,
    UserDto User,
    LegalStatusDto Legal);
