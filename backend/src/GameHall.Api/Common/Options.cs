namespace GameHall.Api.Common;

public sealed class JwtOptions
{
    public const string Section = "Jwt";

    public string Issuer { get; set; } = "gamehall";
    public string Audience { get; set; } = "gamehall-app";
    public string SigningKey { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 30;
    public int RefreshFamilyMaxDays { get; set; } = 90;
}

public sealed class SecurityOptions
{
    public const string Section = "Security";

    /// <summary>Segredo do servidor usado para "temperar" palavras-passe e assinar códigos/IPs (HMAC).</summary>
    public string Pepper { get; set; } = "";
    public bool CheckPwnedPasswords { get; set; } = true;
    public bool TrustProxyHeaders { get; set; } = false;
    public int MinimumAge { get; set; } = 13;
    public int MaxFailedLogins { get; set; } = 5;
    public int LockoutMinutes { get; set; } = 15;
    public int EmailCodeMinutes { get; set; } = 15;
    public int EmailCodeMaxAttempts { get; set; } = 5;
    public int EmailResendSeconds { get; set; } = 60;
}

public sealed class SmtpOptions
{
    public const string Section = "Smtp";

    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 1025;
    public bool UseTls { get; set; } = false;
    public string User { get; set; } = "";
    public string Password { get; set; } = "";
    public string FromAddress { get; set; } = "no-reply@gamehall.local";
    public string FromName { get; set; } = "GameHall Torneios";
}

public sealed class LegalOptions
{
    public const string Section = "Legal";

    /// <summary>Sobe a versão sempre que o texto muda de forma relevante: os utilizadores terão de voltar a aceitar.</summary>
    public string TermsVersion { get; set; } = "1.0.0";
    public string PrivacyVersion { get; set; } = "1.0.0";
}
