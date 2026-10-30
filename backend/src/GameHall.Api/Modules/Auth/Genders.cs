namespace GameHall.Api.Modules.Auth;

/// <summary>
/// Géneros dos utilizadores (male, female, non_binary, other) e categorias de torneio (os mesmos + mixed).
/// Num torneio não misto só entram utilizadores do mesmo género.
/// </summary>
public static class Genders
{
    public const string Mixed = "mixed";

    public static readonly string[] User = ["male", "female", "non_binary", "other"];

    public static readonly string[] Tournament = [.. User, Mixed];

    public static bool IsValidUser(string? gender) => gender is not null && User.Contains(gender);

    /// <summary>Misto aceita todos; caso contrário o género tem de ser igual ao do torneio.</summary>
    public static bool Allowed(string tournamentGender, string? userGender) =>
        tournamentGender == Mixed || tournamentGender == userGender;
}
