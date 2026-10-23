namespace GameHall.Api.Infrastructure.Security;

/// <summary>
/// Política de palavras-passe no espírito das recomendações NIST: comprimento mínimo longo,
/// sem regras artificiais de composição (maiúscula, símbolo...), e rejeição de palavras-passe óbvias.
/// A verificação contra fugas de dados conhecidas está em <see cref="PwnedPasswordChecker"/>.
/// </summary>
public static class PasswordPolicy
{
    public const int MinLength = 12;
    public const int MaxLength = 128;

    private static readonly HashSet<string> Common = new(StringComparer.OrdinalIgnoreCase)
    {
        "password1234", "password12345", "123456789012", "1234567890123", "qwertyuiop12",
        "qwertyuiopas", "abcdefghijkl", "iloveyou1234", "letmein12345", "welcome12345",
        "palavrapasse", "palavra-passe", "gamehall1234", "gamehalltorneios", "futebol12345",
        "benfica12345", "sporting12345", "fcporto12345", "portugal1234", "portugal12345"
    };

    /// <summary>Devolve códigos de erro (vazio = palavra-passe aceitável).</summary>
    public static IReadOnlyList<string> Validate(string? password, string? email, string? displayName)
    {
        var errors = new List<string>();

        if (string.IsNullOrEmpty(password))
        {
            errors.Add("required");
            return errors;
        }

        if (password.Length < MinLength)
        {
            errors.Add("too_short");
        }

        if (password.Length > MaxLength)
        {
            errors.Add("too_long");
        }

        if (Common.Contains(password) || password.Distinct().Count() <= 2)
        {
            errors.Add("too_common");
        }

        if (!string.IsNullOrEmpty(email))
        {
            var local = email.Split('@')[0];
            if (local.Length >= 4 && password.Contains(local, StringComparison.OrdinalIgnoreCase))
            {
                errors.Add("contains_email");
            }
        }

        if (!string.IsNullOrWhiteSpace(displayName) && displayName.Trim().Length >= 4 &&
            password.Contains(displayName.Trim(), StringComparison.OrdinalIgnoreCase))
        {
            errors.Add("contains_name");
        }

        return errors;
    }

    public static string Describe(string code) => code switch
    {
        "required" => "A palavra-passe é obrigatória.",
        "too_short" => $"A palavra-passe deve ter pelo menos {MinLength} caracteres.",
        "too_long" => $"A palavra-passe não pode ter mais de {MaxLength} caracteres.",
        "too_common" => "Esta palavra-passe é demasiado comum ou previsível.",
        "contains_email" => "A palavra-passe não pode conter o teu email.",
        "contains_name" => "A palavra-passe não pode conter o teu nome.",
        _ => "Palavra-passe inválida."
    };
}
