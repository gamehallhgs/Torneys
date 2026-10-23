using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using GameHall.Api.Common;
using Microsoft.Extensions.Options;

namespace GameHall.Api.Infrastructure.Security;

/// <summary>
/// Verifica se a palavra-passe aparece em fugas de dados conhecidas (serviço "Have I Been Pwned").
/// Usa k-anonymity: só os 5 primeiros caracteres do hash SHA-1 saem do servidor; a palavra-passe nunca.
/// Se o serviço estiver indisponível, deixa passar (não bloqueia registos por falha de terceiros).
/// </summary>
public sealed class PwnedPasswordChecker(
    HttpClient http,
    IOptions<SecurityOptions> options,
    ILogger<PwnedPasswordChecker> log)
{
    public async Task<bool> IsPwnedAsync(string password, CancellationToken ct)
    {
        if (!options.Value.CheckPwnedPasswords)
        {
            return false;
        }

        try
        {
            var sha1 = Convert.ToHexString(SHA1.HashData(Encoding.UTF8.GetBytes(password)));
            var prefix = sha1[..5];
            var suffix = sha1[5..];

            using var request = new HttpRequestMessage(HttpMethod.Get, $"range/{prefix}");
            request.Headers.Add("Add-Padding", "true");
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                return false;
            }

            var body = await response.Content.ReadAsStringAsync(ct);
            foreach (var line in body.Split('\n'))
            {
                var parts = line.Trim().Split(':');
                if (parts.Length == 2 &&
                    parts[0].Equals(suffix, StringComparison.OrdinalIgnoreCase) &&
                    int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var count) &&
                    count > 0)
                {
                    return true;
                }
            }

            return false;
        }
        catch (HttpRequestException ex)
        {
            log.LogWarning(ex, "Serviço de verificação de palavras-passe indisponível.");
            return false;
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            log.LogWarning("Timeout na verificação de palavras-passe.");
            return false;
        }
    }
}
