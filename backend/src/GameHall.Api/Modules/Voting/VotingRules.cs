namespace GameHall.Api.Modules.Voting;

public static class VotingCategories
{
    public const string BestPlayer = "best_player";
    public const string BestGoalkeeper = "best_goalkeeper";
    public static readonly string[] All = [BestPlayer, BestGoalkeeper];

    /// <summary>Posição (team_members.position) do guarda-redes.</summary>
    public const string GoalkeeperPosition = "GK";
}

/// <summary>Votos de um candidato numa categoria de uma ronda.</summary>
public sealed record Tally(Guid UserId, int Votes);

/// <summary>pending = há empate e ainda pode haver desempate; final = vencedores decididos (um ou co-vencedores).</summary>
public sealed record CategoryResult(string Status, IReadOnlyList<Guid> Winners)
{
    public const string Pending = "pending";
    public const string Final = "final";
    public static readonly CategoryResult None = new("none", []);
}

/// <summary>
/// Regras da votação do melhor jogador e do melhor guarda-redes (classes puras, com testes).
/// Ronda 1: todos os jogadores. Se houver empate no topo, o gestor pode abrir a ronda 2 só com os empatados
/// (e só nas categorias empatadas). Se a ronda 2 voltar a empatar, ficam os N empatados (co-vencedores).
/// As duas rondas têm de acontecer inteiras dentro da janela (por defeito 6 horas depois de o torneio terminar):
/// abrem e fecham antes de ela acabar.
/// </summary>
public static class VotingRules
{
    public const int DefaultWindowHours = 6;
    public const int DefaultMinVoterEmailHours = 24;
    public const int DefaultMinDurationMinutes = 30;
    public const int DefaultMaxDurationMinutes = 180;

    public static DateTime WindowEnd(DateTime finishedAt, int windowHours) => finishedAt.AddHours(windowHours);

    public static bool WindowOpen(DateTime? finishedAt, int? windowHours, DateTime now) =>
        finishedAt is not null && now <= WindowEnd(finishedAt.Value, windowHours ?? DefaultWindowHours);

    public static bool IsOpen(DateTime openedAt, DateTime closesAt, DateTime now) => now >= openedAt && now < closesAt;

    public static bool IsClosed(DateTime closesAt, DateTime now) => now >= closesAt;

    /// <summary>Quem tem mais votos (só conta quem tem pelo menos 1). Vários = empate.</summary>
    public static IReadOnlyList<Guid> Leaders(IEnumerable<Tally> tallies)
    {
        var list = tallies.Where(t => t.Votes > 0).ToList();
        if (list.Count == 0)
        {
            return [];
        }

        var max = list.Max(t => t.Votes);
        return list.Where(t => t.Votes == max).Select(t => t.UserId).ToList();
    }

    /// <summary>
    /// Resultado de uma categoria. [round1] = votos da ronda 1 (null = ronda 1 não existe ou ainda aberta),
    /// [round2] = votos da ronda 2 (null = ainda aberta); [round2HasCategory] = a ronda 2 inclui esta categoria.
    /// </summary>
    public static CategoryResult Resolve(
        IReadOnlyList<Tally>? round1, bool round2HasCategory, IReadOnlyList<Tally>? round2, bool windowOpen)
    {
        if (round1 is null)
        {
            return CategoryResult.None;
        }

        var first = Leaders(round1);
        if (first.Count == 0)
        {
            return CategoryResult.None;
        }

        if (first.Count == 1)
        {
            return new CategoryResult(CategoryResult.Final, first);
        }

        // Empate na ronda 1.
        if (round2HasCategory)
        {
            if (round2 is null)
            {
                return new CategoryResult(CategoryResult.Pending, first);   // desempate em curso
            }

            var second = Leaders(round2);
            return new CategoryResult(CategoryResult.Final, second.Count == 0 ? first : second);
        }

        // Sem desempate para esta categoria: enquanto o gestor ainda o puder abrir, fica pendente.
        return windowOpen
            ? new CategoryResult(CategoryResult.Pending, first)
            : new CategoryResult(CategoryResult.Final, first);
    }

    /// <summary>Categorias empatadas no topo na ronda 1 (candidatas à ronda 2) e os empatados de cada uma.</summary>
    public static IReadOnlyDictionary<string, IReadOnlyList<Guid>> TiedCategories(
        IReadOnlyDictionary<string, IReadOnlyList<Tally>> round1)
    {
        var result = new Dictionary<string, IReadOnlyList<Guid>>();
        foreach (var (category, tallies) in round1)
        {
            var leaders = Leaders(tallies);
            if (leaders.Count > 1)
            {
                result[category] = leaders;
            }
        }

        return result;
    }

    /// <summary>
    /// Abrir uma ronda (gestor). Null = pode. [roundNumber] 1 ou 2; [round1ClosesAt] = fecho da ronda 1 (se existir);
    /// [hasTies] = há categorias empatadas (só interessa à ronda 2).
    /// </summary>
    public static string? WhyCannotOpen(
        string tournamentStatus, DateTime? finishedAt, int? windowHours, DateTime now, int roundNumber,
        bool roundAlreadyExists, DateTime? round1ClosesAt, bool hasTies, int durationMinutes, int minMinutes, int maxMinutes)
    {
        if (tournamentStatus != "finished" || finishedAt is null)
        {
            return "tournament_not_finished";
        }

        if (!WindowOpen(finishedAt, windowHours, now))
        {
            return "voting_window_closed";
        }

        if (roundAlreadyExists)
        {
            return "round_already_exists";
        }

        if (roundNumber == 2)
        {
            if (round1ClosesAt is null)
            {
                return "no_first_round";
            }

            if (!IsClosed(round1ClosesAt.Value, now))
            {
                return "previous_round_open";
            }

            if (!hasTies)
            {
                return "no_tie";
            }
        }

        if (durationMinutes < minMinutes || durationMinutes > maxMinutes)
        {
            return "invalid_duration";
        }

        // Cada ronda tem de acabar dentro da janela: o fecho não pode passar do fim da janela.
        return now.AddMinutes(durationMinutes) > WindowEnd(finishedAt.Value, windowHours ?? DefaultWindowHours)
            ? "round_exceeds_window"
            : null;
    }

    /// <summary>Votar. Null = pode. Participantes votam sempre; os outros precisam de email verificado há tempo suficiente.</summary>
    public static string? WhyCannotVote(
        bool isParticipant, DateTime? emailVerifiedAt, DateTime now, int minVoterEmailHours,
        bool roundOpen, bool votingForSelf)
    {
        if (!roundOpen)
        {
            return "voting_closed";
        }

        if (votingForSelf)
        {
            return "cannot_vote_self";
        }

        if (isParticipant)
        {
            return null;
        }

        return emailVerifiedAt is not null && now - emailVerifiedAt.Value >= TimeSpan.FromHours(minVoterEmailHours)
            ? null
            : "email_not_verified_long_enough";
    }
}
