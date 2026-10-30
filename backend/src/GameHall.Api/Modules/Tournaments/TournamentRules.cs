namespace GameHall.Api.Modules.Tournaments;

/// <summary>Regras puras (sem base de dados), fáceis de testar.</summary>
public static class TournamentRules
{
    /// <summary>
    /// Regras do torneio mostradas ao líder ao fechar a equipa. Quando houver painel do gestor, este texto
    /// vem do torneio (tournaments.rules_text); até lá mostra-se este texto de exemplo.
    /// </summary>
    public const string PlaceholderRules =
        "1. Todos os jogadores devem apresentar-se 15 minutos antes da hora do jogo.\n" +
        "2. É obrigatório o uso de caneleiras e de equipamento da cor da equipa.\n" +
        "3. Atrasos superiores a 10 minutos podem dar o jogo como perdido (0-3).\n" +
        "4. Comportamentos antidesportivos podem levar à exclusão da equipa, sem reembolso.\n" +
        "5. As decisões do árbitro são finais.\n" +
        "(Texto de exemplo: as regras reais serão definidas pelo gestor do torneio.)";

    public static readonly string[] Genders = GameHall.Api.Modules.Auth.Genders.Tournament;

    public static readonly string[] Sports = ["football7", "football9", "football11", "futsal"];

    /// <summary>"13+", "18+", "16-18"...</summary>
    public static string AgeLabel(int minAge, int? maxAge) =>
        maxAge is null ? $"{minAge}+" : $"{minAge}-{maxAge}";

    /// <summary>Estado do torneio e idade (comuns a criar equipa e a entrar numa). Null = pode.</summary>
    public static string? WhyCannotParticipate(
        string status, int minAge, int? maxAge, int userAge, string tournamentGender = "mixed", string? userGender = null)
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

        // Torneio masculino só para homens, feminino só para mulheres, etc.; misto aceita todos.
        return Auth.Genders.Allowed(tournamentGender, userGender) ? null : "gender_not_allowed";
    }

    /// <summary>
    /// Devolve null se o utilizador pode criar uma equipa neste torneio; caso contrário o código do motivo.
    /// Criar equipas é ilimitado: só deixa de ser possível quando as equipas CONFIRMADAS (completas e pagas)
    /// já ocupam todas as vagas. A idade conta na data de hoje.
    /// </summary>
    public static string? WhyCannotCreateTeam(
        string status, int teamsConfirmed, int maxTeams, int minAge, int? maxAge, int userAge,
        string tournamentGender = "mixed", string? userGender = null)
    {
        var reason = WhyCannotParticipate(status, minAge, maxAge, userAge, tournamentGender, userGender);
        if (reason is not null)
        {
            return reason;
        }

        return teamsConfirmed >= maxTeams ? "tournament_full" : null;
    }
}
