namespace GameHall.Api.Modules.Games;

public sealed record PodiumEntryDto(int Place, Guid TeamId, string Name, string ColorHex);

/// <summary>Jogo para o pódio (só o necessário).</summary>
public sealed record PodiumGame(
    string Stage, int RoundNumber, string Status, Guid? HomeId, Guid? AwayId,
    int? HomeGoals, int? AwayGoals, int? HomePenalties, int? AwayPenalties);

/// <summary>
/// Pódio de um torneio terminado.
/// Liga: os 3 primeiros da classificação. Eliminatórias (inclui grupos + eliminatórias e dupla eliminação):
/// campeão e finalista saem da final (última ronda); o 3.º lugar sai do jogo de atribuição, e sem esse jogo
/// os dois derrotados das meias-finais ficam ambos em 3.º (ex aequo).
/// </summary>
public static class PodiumCalculator
{
    /// <summary>Vencedor de um jogo terminado (golos, depois penáltis). Null se não está decidido.</summary>
    public static (Guid Winner, Guid Loser)? Decide(PodiumGame g)
    {
        if (g is not { Status: "finished", HomeId: { } h, AwayId: { } a, HomeGoals: { } hg, AwayGoals: { } ag })
        {
            return null;
        }

        if (hg != ag)
        {
            return hg > ag ? (h, a) : (a, h);
        }

        if (g.HomePenalties is { } hp && g.AwayPenalties is { } ap && hp != ap)
        {
            return hp > ap ? (h, a) : (a, h);
        }

        return null;
    }

    public static IReadOnlyList<PodiumEntryDto> FromStandings(IReadOnlyList<StandingRowDto> rows) =>
        rows.Take(3).Select(r => new PodiumEntryDto(r.Position <= 3 ? r.Position : 3, r.TeamId, r.Name, r.ColorHex)).ToList();

    public static IReadOnlyList<PodiumEntryDto> FromKnockout(
        IReadOnlyList<PodiumGame> games, IReadOnlyDictionary<Guid, (string Name, string ColorHex)> teams)
    {
        PodiumEntryDto? Entry(int place, Guid id) =>
            teams.TryGetValue(id, out var t) ? new PodiumEntryDto(place, id, t.Name, t.ColorHex) : null;

        var rounds = games.Where(g => g.Stage == "round").ToList();
        if (rounds.Count == 0)
        {
            return [];
        }

        var lastRound = rounds.Max(g => g.RoundNumber);
        var final = rounds.Where(g => g.RoundNumber == lastRound).Select(Decide).FirstOrDefault(d => d is not null);
        if (final is null)
        {
            return [];
        }

        var result = new List<PodiumEntryDto?> { Entry(1, final.Value.Winner), Entry(2, final.Value.Loser) };

        var thirdGame = games.FirstOrDefault(g => g.Stage == "third_place");
        if (thirdGame is not null)
        {
            if (Decide(thirdGame) is { } third)
            {
                result.Add(Entry(3, third.Winner));
            }
        }
        else
        {
            foreach (var semi in rounds.Where(g => g.RoundNumber == lastRound - 1))
            {
                if (Decide(semi) is { } d)
                {
                    result.Add(Entry(3, d.Loser));
                }
            }
        }

        return result.OfType<PodiumEntryDto>().ToList();
    }
}
