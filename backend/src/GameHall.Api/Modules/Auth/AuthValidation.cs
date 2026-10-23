using System.Net.Mail;

namespace GameHall.Api.Modules.Auth;

public static class AgeCalculator
{
    /// <summary>Idade completa em anos numa data de referência.</summary>
    public static int AgeOn(DateOnly birthDate, DateOnly today)
    {
        var age = today.Year - birthDate.Year;
        if (today < birthDate.AddYears(age))
        {
            age--;
        }

        return age;
    }
}

public static class AuthValidation
{
    /// <summary>Devolve o email em minúsculas e sem espaços, ou null se for inválido.</summary>
    public static string? NormalizeEmail(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return null;
        }

        var email = input.Trim().ToLowerInvariant();
        if (email.Length > 254 || email.Any(char.IsControl) || email.Any(char.IsWhiteSpace))
        {
            return null;
        }

        if (!MailAddress.TryCreate(email, out var address) || address.Address != email)
        {
            return null;
        }

        var at = email.LastIndexOf('@');
        if (at < 1 || !email[(at + 1)..].Contains('.'))
        {
            return null;
        }

        return email;
    }

    public static bool IsValidDisplayName(string name) =>
        name.Length is >= 2 and <= 40 && !name.Any(char.IsControl);
}
