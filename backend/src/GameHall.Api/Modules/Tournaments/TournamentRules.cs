namespace GameHall.Api.Modules.Tournaments;

/// <summary>Regras puras (sem base de dados), fáceis de testar.</summary>
public static class TournamentRules
{
    public static readonly string[] Sports = ["football7", "football9", "football11", "futsal"];

    /// <summary>"13+", "18+", "16-18"...</summary>
    public static string AgeLabel(int minAge, int? maxAge) =>
        maxAge is null ? $"{minAge}+" : $"{minAge}-{maxAge}";

    /// <summary>Estado do torneio e idade (comuns a criar equipa e a entrar numa). Null = pode.</summary>
    public static string? WhyCannotParticipate(string status, int minAge, int? maxAge, int userAge)
    {
        if (status != "registration_open")
        {
            return "registration_closed";
        }

        if (userAge < minAge)
        {
            return "age_too_young";
        }

        if (maxAge is not null && userAge > maxAge)
        {
            return "age_too_old";
        }

        return null;
    }

    /// <summary>
    /// Devolve null se o utilizador pode criar uma equipa neste torneio; caso contrário o código do motivo.
    /// Criar equipas é ilimitado: só deixa de ser possível quando as equipas CONFIRMADAS (completas e pagas)
    /// já ocupam todas as vagas. A idade conta na data de hoje.
    /// </summary>
    public static string? WhyCannotCreateTeam(
        string status, int teamsConfirmed, int maxTeams, int minAge, int? maxAge, int userAge)
    {
        var reason = WhyCannotParticipate(status, minAge, maxAge, userAge);
        if (reason is not null)
        {
            return reason;
        }

        return teamsConfirmed >= maxTeams ? "tournament_full" : null;
    }
}
