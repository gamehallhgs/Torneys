using System.Security.Cryptography;
using System.Text;

namespace GameHall.Api.Infrastructure.Security;

public static class Hashing
{
    public static string Sha256Hex(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    /// <summary>
    /// HMAC-SHA256 com chave do servidor. O parâmetro "purpose" separa domínios (ip, emailcode, ...)
    /// para que um hash de um uso nunca possa ser reutilizado noutro.
    /// </summary>
    public static string Hmac(string key, string purpose, string value) =>
        Convert.ToHexString(
            HMACSHA256.HashData(Encoding.UTF8.GetBytes(key), Encoding.UTF8.GetBytes($"{purpose}:{value}")))
            .ToLowerInvariant();
}
