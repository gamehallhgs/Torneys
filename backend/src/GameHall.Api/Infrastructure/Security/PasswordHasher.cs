using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using GameHall.Api.Common;
using Konscious.Security.Cryptography;
using Microsoft.Extensions.Options;

namespace GameHall.Api.Infrastructure.Security;

/// <summary>
/// Argon2id (64 MiB, 3 iterações, 2 threads) sobre HMAC-SHA256(pepper, palavra-passe).
/// O "pepper" vive só na configuração do servidor: mesmo que a base de dados seja roubada,
/// os hashes não podem ser atacados sem ele.
/// Formato guardado: $argon2id$v=19$m=65536,t=3,p=2$&lt;salt b64&gt;$&lt;hash b64&gt;
/// </summary>
public sealed class PasswordHasher
{
    private const int SaltSize = 16;
    private const int HashSize = 32;
    private const int MemoryKiB = 65536;
    private const int Iterations = 3;
    private const int Parallelism = 2;

    private readonly byte[] _pepper;
    private readonly Lazy<string> _dummyHash;

    public PasswordHasher(IOptions<SecurityOptions> options)
    {
        _pepper = Encoding.UTF8.GetBytes(options.Value.Pepper);
        _dummyHash = new Lazy<string>(() => Hash("gamehall-dummy-password-for-timing"));
    }

    public string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Compute(password, salt, MemoryKiB, Iterations, Parallelism, HashSize);
        return $"$argon2id$v=19$m={MemoryKiB},t={Iterations},p={Parallelism}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    public bool Verify(string password, string stored)
    {
        if (!TryParse(stored, out var m, out var t, out var p, out var salt, out var expected))
        {
            return false;
        }

        var actual = Compute(password, salt, m, t, p, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    /// <summary>
    /// Gasta o mesmo tempo que uma verificação real. Usado quando o utilizador não existe,
    /// para que o tempo de resposta não revele se o email está registado.
    /// </summary>
    public void VerifyDummy(string password) => Verify(password, _dummyHash.Value);

    /// <summary>True se o hash guardado usa parâmetros mais fracos que os atuais (re-hash no próximo login).</summary>
    public bool NeedsRehash(string stored)
    {
        if (!TryParse(stored, out var m, out var t, out var p, out _, out var hash))
        {
            return true;
        }

        return m < MemoryKiB || t < Iterations || p != Parallelism || hash.Length != HashSize;
    }

    private byte[] Compute(string password, byte[] salt, int memoryKiB, int iterations, int parallelism, int length)
    {
        var peppered = HMACSHA256.HashData(_pepper, Encoding.UTF8.GetBytes(password));
        using var argon = new Argon2id(peppered)
        {
            Salt = salt,
            DegreeOfParallelism = parallelism,
            Iterations = iterations,
            MemorySize = memoryKiB
        };
        return argon.GetBytes(length);
    }

    private static bool TryParse(string stored, out int m, out int t, out int p, out byte[] salt, out byte[] hash)
    {
        m = t = p = 0;
        salt = [];
        hash = [];

        var parts = stored.Split('$', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length != 5 || parts[0] != "argon2id" || parts[1] != "v=19")
        {
            return false;
        }

        try
        {
            foreach (var kv in parts[2].Split(','))
            {
                var pair = kv.Split('=');
                var value = int.Parse(pair[1], CultureInfo.InvariantCulture);
                switch (pair[0])
                {
                    case "m": m = value; break;
                    case "t": t = value; break;
                    case "p": p = value; break;
                }
            }

            salt = Convert.FromBase64String(parts[3]);
            hash = Convert.FromBase64String(parts[4]);
        }
        catch (Exception ex) when (ex is FormatException or IndexOutOfRangeException or OverflowException)
        {
            return false;
        }

        return m > 0 && t > 0 && p > 0 && salt.Length > 0 && hash.Length > 0;
    }
}
