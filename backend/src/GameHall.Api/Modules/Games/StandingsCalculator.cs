namespace GameHall.Api.Modules.Games;

public sealed record StandingTeam(Guid Id, string Name, string ColorHex);

/// <summary>Resultado de um jogo terminado.</summary>
public sealed record StandingGame(Guid HomeId, Guid AwayId, int HomeGoals, int AwayGoals);

/// <summary>
/// Classificação de uma liga ou de um grupo. Vitória 3 pontos, empate 1, derrota 0.
/// Os desempates aplicam-se pela ordem configurada pelo gestor: quando um critério separa as equipas
/// empatadas, as que continuam empatadas passam ao critério seguinte.
/// "Pontos" é sempre o primeiro critério. "draw" (sorteio) e "penalties" não se aplicam a tabelas:
/// se sobrar um empate, ordena-se por nome até o gestor decidir.
/// Fair play: cada amarelo vale 1 e cada vermelho 3 (ganha quem tiver menos).
/// </summary>
public static class StandingsCalculator
{
    public const int RedCardFairPlayPoints = 3;

    private static readonly string[] TableCriteria =
        ["points", "head_to_head", "goal_difference", "goals_for", "goals_against", "wins", "fair_play"];

    private sealed class Acc(StandingTeam team)
    {
        public StandingTeam Team { get; } = team;
        public int Won, Drawn, Lost, GoalsFor, GoalsAgainst, Yellow, Red;
        public int Played => Won + Drawn + Lost;
        public int Points => (3 * Won) + Drawn;
        public int GoalDifference => GoalsFor - GoalsAgainst;
        public int FairPlay => Yellow + (RedCardFairPlayPoints * Red);
    }

    public static IReadOnlyList<StandingRowDto> Compute(
        IReadOnlyList<StandingTeam> teams,
        IReadOnlyList<StandingGame> games,
        IReadOnlyDictionary<Guid, (int Yellow, int Red)> cards,
        IReadOnlyList<string> tiebreakers)
    {
        var accs = teams.DistinctBy(t => t.Id).ToDictionary(t => t.Id, t => new Acc(t));
        var counted = new List<StandingGame>();

        foreach (var g in games)
        {
            if (!accs.TryGetValue(g.HomeId, out var home) || !accs.TryGetValue(g.AwayId, out var away))
            {
                continue;
            }

            counted.Add(g);
            home.GoalsFor += g.HomeGoals;
            home.GoalsAgainst += g.AwayGoals;
            away.GoalsFor += g.AwayGoals;
            away.GoalsAgainst += g.HomeGoals;

            if (g.HomeGoals > g.AwayGoals)
            {
                home.Won++;
                away.Lost++;
            }
            else if (g.HomeGoals < g.AwayGoals)
            {
                away.Won++;
                home.Lost++;
            }
            else
            {
                home.Drawn++;
                away.Drawn++;
            }
        }

        foreach (var (teamId, c) in cards)
        {
            if (accs.TryGetValue(teamId, out var acc))
            {
                acc.Yellow = c.Yellow;
                acc.Red = c.Red;
            }
        }

        var criteria = tiebreakers.Where(TableCriteria.Contains).Distinct().ToList();
        criteria.Remove("points");
        criteria.Insert(0, "points");

        var ranked = Rank(accs.Values.ToList(), criteria, 0, counted);

        return ranked
            .Select((a, i) => new StandingRowDto(
                i + 1, a.Team.Id, a.Team.Name, a.Team.ColorHex, a.Played, a.Won, a.Drawn, a.Lost,
                a.GoalsFor, a.GoalsAgainst, a.GoalDifference, a.Points, a.Yellow, a.Red))
            .ToList();
    }

    private static List<Acc> Rank(List<Acc> items, List<string> criteria, int index, List<StandingGame> games)
    {
        if (items.Count <= 1)
        {
            return items;
        }

        if (index >= criteria.Count)
        {
            return items.OrderBy(a => SortKey(a.Team.Name), StringComparer.Ordinal).ToList();
        }

        var key = KeyFor(criteria[index], items, games);
        var result = new List<Acc>();
        foreach (var group in items.GroupBy(key).OrderByDescending(g => g.Key))
        {
            result.AddRange(Rank(group.ToList(), criteria, index + 1, games));
        }

        return result;
    }

    /// <summary>Nome sem acentos e em minúsculas, para ordenar "Águias" junto do A (e não depois do Z).</summary>
    internal static string SortKey(string name)
    {
        var decomposed = name.Normalize(System.Text.NormalizationForm.FormD);
        var sb = new System.Text.StringBuilder(decomposed.Length);
        foreach (var ch in decomposed)
        {
            if (System.Globalization.CharUnicodeInfo.GetUnicodeCategory(ch) != System.Globalization.UnicodeCategory.NonSpacingMark)
            {
                sb.Append(char.ToLowerInvariant(ch));
            }
        }

        return sb.ToString();
    }

    /// <summary>Valor por equipa (maior = melhor) para o critério.</summary>
    private static Func<Acc, int> KeyFor(string criterion, List<Acc> items, List<StandingGame> games)
    {
        switch (criterion)
        {
            case "head_to_head":
                var mini = HeadToHeadPoints(items, games);
                return a => mini[a.Team.Id];
            case "goal_difference":
                return a => a.GoalDifference;
            case "goals_for":
                return a => a.GoalsFor;
            case "goals_against":
                return a => -a.GoalsAgainst;
            case "wins":
                return a => a.Won;
            case "fair_play":
                return a => -a.FairPlay;
            default:
                return a => a.Points;
        }
    }

    /// <summary>Pontos só nos jogos entre as equipas empatadas.</summary>
    private static Dictionary<Guid, int> HeadToHeadPoints(List<Acc> items, List<StandingGame> games)
    {
        var points = items.ToDictionary(a => a.Team.Id, _ => 0);
        foreach (var g in games)
        {
            if (!points.ContainsKey(g.HomeId) || !points.ContainsKey(g.AwayId))
            {
                continue;
            }

            if (g.HomeGoals > g.AwayGoals)
            {
                points[g.HomeId] += 3;
            }
            else if (g.HomeGoals < g.AwayGoals)
            {
                points[g.AwayId] += 3;
            }
            else
            {
                points[g.HomeId]++;
                points[g.AwayId]++;
            }
        }

        return points;
    }

    /// <summary>
    /// Monta os grupos a partir dos jogos: liga = um só grupo (sem nome) com todas as equipas;
    /// fase de grupos = um grupo por nome; outros formatos não têm tabela.
    /// Só contam jogos terminados com golos registados.
    /// </summary>
    public static IReadOnlyList<StandingsGroupDto> BuildGroups(
        string format,
        IReadOnlyList<StandingTeam> allTeams,
        IReadOnlyList<StandingsGameRow> games,
        IReadOnlyDictionary<Guid, (int Yellow, int Red)> cards,
        IReadOnlyList<string> tiebreakers)
    {
        static StandingGame? Result(StandingsGameRow g) =>
            g is { Status: "finished", HomeTeamId: { } h, AwayTeamId: { } a, HomeGoals: { } hg, AwayGoals: { } ag }
                ? new StandingGame(h, a, hg, ag)
                : null;

        if (format == "league")
        {
            var results = games.Select(Result).OfType<StandingGame>().ToList();
            return [new StandingsGroupDto(null, Compute(allTeams, results, cards, tiebreakers))];
        }

        if (format != "groups_knockout")
        {
            return [];
        }

        var teamsById = allTeams.ToDictionary(t => t.Id);
        var groups = new List<StandingsGroupDto>();
        foreach (var byGroup in games.Where(g => g.GroupName is not null)
                     .GroupBy(g => g.GroupName!)
                     .OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase))
        {
            var ids = byGroup
                .SelectMany(g => new[] { g.HomeTeamId, g.AwayTeamId })
                .OfType<Guid>()
                .Distinct();
            var teams = ids.Where(teamsById.ContainsKey).Select(id => teamsById[id]).ToList();
            var results = byGroup.Select(Result).OfType<StandingGame>().ToList();
            groups.Add(new StandingsGroupDto(byGroup.Key, Compute(teams, results, cards, tiebreakers)));
        }

        return groups;
    }
}
