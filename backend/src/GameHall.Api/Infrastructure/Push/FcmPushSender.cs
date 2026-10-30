using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace GameHall.Api.Infrastructure.Push;

/// <summary>
/// Firebase Cloud Messaging (API HTTP v1). Autentica com a conta de serviço (JWT RS256 trocado por um access token
/// que dura 1 hora e fica em cache). Só é usado com Push:Provider = "fcm"; ver docs/NOTIFICACOES.md.
/// </summary>
public sealed class FcmPushSender(HttpClient http, IOptions<PushOptions> options, TimeProvider clock, ILogger<FcmPushSender> log)
    : IPushSender
{
    private static readonly string[] Scopes = ["https://www.googleapis.com/auth/firebase.messaging"];

    private readonly SemaphoreSlim _lock = new(1, 1);
    private string? _accessToken;
    private DateTime _accessTokenExpires;
    private ServiceAccount? _account;

    private sealed record ServiceAccount(string ClientEmail, string PrivateKey, string TokenUri);

    public async Task<IReadOnlyList<string>> SendAsync(PushMessage message, IReadOnlyCollection<string> tokens, CancellationToken ct)
    {
        var invalid = new List<string>();
        var o = options.Value.Fcm;
        if (string.IsNullOrWhiteSpace(o.ProjectId))
        {
            log.LogWarning("Push:Fcm:ProjectId em falta: push não enviado.");
            return invalid;
        }

        var access = await AccessTokenAsync(ct);
        foreach (var token in tokens)
        {
            var body = JsonSerializer.Serialize(new
            {
                message = new
                {
                    token,
                    notification = new { title = message.Title, body = message.Body },
                    data = message.Data,
                    android = new { priority = "high" },
                }
            });

            using var req = new HttpRequestMessage(
                HttpMethod.Post, $"https://fcm.googleapis.com/v1/projects/{o.ProjectId}/messages:send")
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json"),
            };
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", access);

            using var res = await http.SendAsync(req, ct);
            if (res.IsSuccessStatusCode)
            {
                continue;
            }

            var text = await res.Content.ReadAsStringAsync(ct);
            if (IsDeadToken(res.StatusCode, text))
            {
                invalid.Add(token);
            }
            else
            {
                log.LogWarning("FCM recusou o push ({Status}): {Body}", (int)res.StatusCode, text);
            }
        }

        return invalid;
    }

    /// <summary>404 UNREGISTERED ou 400 INVALID_ARGUMENT (token inválido): o token já não serve.</summary>
    public static bool IsDeadToken(HttpStatusCode status, string responseBody) =>
        status == HttpStatusCode.NotFound
        || (status == HttpStatusCode.BadRequest && responseBody.Contains("INVALID_ARGUMENT", StringComparison.Ordinal)
            && responseBody.Contains("token", StringComparison.OrdinalIgnoreCase))
        || responseBody.Contains("UNREGISTERED", StringComparison.Ordinal);

    private async Task<string> AccessTokenAsync(CancellationToken ct)
    {
        await _lock.WaitAsync(ct);
        try
        {
            var now = clock.GetUtcNow().UtcDateTime;
            if (_accessToken is not null && now < _accessTokenExpires.AddMinutes(-5))
            {
                return _accessToken;
            }

            _account ??= LoadAccount(options.Value.Fcm.ServiceAccountFile);
            var assertion = BuildJwt(_account, now);
            using var res = await http.PostAsync(
                _account.TokenUri,
                new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ["assertion"] = assertion,
                }), ct);
            res.EnsureSuccessStatusCode();
            using var doc = JsonDocument.Parse(await res.Content.ReadAsStringAsync(ct));
            _accessToken = doc.RootElement.GetProperty("access_token").GetString()!;
            _accessTokenExpires = now.AddSeconds(doc.RootElement.GetProperty("expires_in").GetInt32());
            return _accessToken;
        }
        finally
        {
            _lock.Release();
        }
    }

    private static ServiceAccount LoadAccount(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            throw new InvalidOperationException("Push:Fcm:ServiceAccountFile não aponta para um ficheiro existente.");
        }

        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        var r = doc.RootElement;
        return new ServiceAccount(
            r.GetProperty("client_email").GetString()!,
            r.GetProperty("private_key").GetString()!,
            r.TryGetProperty("token_uri", out var uri) ? uri.GetString()! : "https://oauth2.googleapis.com/token");
    }

    private static string BuildJwt(ServiceAccount a, DateTime now)
    {
        static string B64(byte[] b) => Convert.ToBase64String(b).TrimEnd('=').Replace('+', '-').Replace('/', '_');

        var iat = new DateTimeOffset(now).ToUnixTimeSeconds();
        var header = B64(Encoding.UTF8.GetBytes("""{"alg":"RS256","typ":"JWT"}"""));
        var claims = B64(JsonSerializer.SerializeToUtf8Bytes(new
        {
            iss = a.ClientEmail,
            scope = string.Join(' ', Scopes),
            aud = a.TokenUri,
            iat,
            exp = iat + 3600,
        }));

        using var rsa = RSA.Create();
        rsa.ImportFromPem(a.PrivateKey);
        var signature = rsa.SignData(Encoding.UTF8.GetBytes($"{header}.{claims}"), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return $"{header}.{claims}.{B64(signature)}";
    }
}
