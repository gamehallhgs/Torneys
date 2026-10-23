using System.Buffers.Text;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using GameHall.Api.Common;
using GameHall.Api.Modules.Auth;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace GameHall.Api.Infrastructure.Security;

/// <summary>
/// Access token: JWT curto (15 min), assinado com HS256.
/// Refresh token: 32 bytes aleatórios; só o hash SHA-256 é guardado na base de dados.
/// </summary>
public sealed class TokenService
{
    private readonly JwtOptions _options;
    private readonly TimeProvider _clock;
    private readonly JsonWebTokenHandler _handler = new();
    private readonly SigningCredentials _credentials;

    public TokenService(IOptions<JwtOptions> options, TimeProvider clock)
    {
        _options = options.Value;
        _clock = clock;
        _credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey)),
            SecurityAlgorithms.HmacSha256);
    }

    /// <param name="legalOk">True se o utilizador aceitou as versões atuais dos Termos e da Privacidade.</param>
    public (string Token, int ExpiresInSeconds) CreateAccessToken(User user, bool legalOk)
    {
        var now = _clock.GetUtcNow().UtcDateTime;
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _options.Issuer,
            Audience = _options.Audience,
            NotBefore = now,
            IssuedAt = now,
            Expires = now.AddMinutes(_options.AccessTokenMinutes),
            SigningCredentials = _credentials,
            Subject = new ClaimsIdentity(new[]
            {
                new Claim("sub", user.Id.ToString()),
                new Claim("role", user.Role.ToString()),
                new Claim("legal_ok", legalOk ? "true" : "false"),
                new Claim("jti", Guid.NewGuid().ToString("N"))
            })
        };

        return (_handler.CreateToken(descriptor), _options.AccessTokenMinutes * 60);
    }

    public static string NewRefreshToken() =>
        Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));
}
