namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Código de convite da equipa ("GH-7K3Q"): um atalho para entrar sem o líder convidar toda a gente.
/// Alfabeto sem letras confusas (sem I, L, O, 0, 1). A geração está na base de dados (gh_new_invite_code).
/// </summary>
public static class InviteCodes
{
    public const string Alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

    /// <summary>Quantas vezes por hora o líder pode gerar um código novo.</summary>
    public const int MaxRegensPerHour = 3;

    /// <summary>
    /// "gh-7k3q", "GH7K3Q", " 7k3q " -> "GH-7K3Q". Null se não é um código possível.
    /// </summary>
    public static string? Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return null;
        }

        var s = new string(raw.Where(char.IsLetterOrDigit).ToArray()).ToUpperInvariant();
        if (s.Length == 6 && s.StartsWith("GH", StringComparison.Ordinal))
        {
            s = s[2..];
        }

        return s.Length == 4 && s.All(ch => Alphabet.Contains(ch)) ? "GH-" + s : null;
    }

    public static int RegensLeft(int usedInLastHour) => Math.Max(0, MaxRegensPerHour - usedInLastHour);

    /// <summary>Minutos (para cima) até a geração mais antiga da última hora deixar de contar.</summary>
    public static int MinutesUntilRegen(DateTime oldestInLastHour, DateTime now) =>
        Math.Max(1, (int)Math.Ceiling((oldestInLastHour.AddHours(1) - now).TotalMinutes));
}
