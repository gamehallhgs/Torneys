namespace GameHall.Api.Modules.Voting;

/// <summary>Textos das notificações de votação (só na app). Funções puras, testáveis.</summary>
public static class VotingTexts
{
    public const string OpenedTitle = "Votação aberta";
    public const string SecondRoundTitle = "Segunda ronda - Votação aberta";
    public const string ResultsTitle = "Resultados da votação";

    public static string Winners(IReadOnlyList<string> names) => names.Count switch
    {
        0 => "sem votos",
        1 => names[0],
        _ => string.Join(", ", names.Take(names.Count - 1)) + " e " + names[^1] + " (empate)",
    };

    public static string Results(string tournamentName, IReadOnlyList<string> bestPlayer, IReadOnlyList<string> goalkeeper)
    {
        var parts = new List<string>();
        if (bestPlayer.Count > 0)
        {
            parts.Add($"Melhor jogador: {Winners(bestPlayer)}");
        }

        if (goalkeeper.Count > 0)
        {
            parts.Add($"Melhor guarda-redes: {Winners(goalkeeper)}");
        }

        return $"Os resultados da votação de {tournamentName} foram publicados. {string.Join(". ", parts)}.";
    }
}
