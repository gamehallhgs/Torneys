namespace GameHall.Api.Modules.Teams;

/// <summary>Estado de uma equipa ainda não confirmada, para decidir se já pode ocupar uma vaga.</summary>
public sealed record ConfirmationCandidate(
    Guid TeamId,
    int Members,
    int Paid,
    DateTime? LastPaidAt,
    DateTime CreatedAt);

/// <summary>Regras puras da confirmação de equipas (sem base de dados, testáveis).</summary>
public static class TeamConfirmationRules
{
    /// <summary>Pronta = mínimo de jogadores atingido e todos os membros pagaram.</summary>
    public static bool IsReady(ConfirmationCandidate c, int minPlayers) =>
        c.Members > 0 && c.Members >= minPlayers && c.Paid == c.Members;

    /// <summary>
    /// Escolhe as equipas a confirmar: só as prontas, por ordem do último pagamento (quem ficou completa
    /// primeiro), desempate pela criação, até ao número de vagas livres.
    /// </summary>
    public static IReadOnlyList<Guid> SelectReady(IEnumerable<ConfirmationCandidate> candidates, int minPlayers, int slots)
    {
        if (slots <= 0)
        {
            return [];
        }

        return candidates
            .Where(c => IsReady(c, minPlayers))
            .OrderBy(c => c.LastPaidAt ?? DateTime.MaxValue)
            .ThenBy(c => c.CreatedAt)
            .Take(slots)
            .Select(c => c.TeamId)
            .ToList();
    }

    /// <summary>Vagas livres (nunca negativas).</summary>
    public static int FreeSlots(int maxTeams, int alreadyConfirmed) => Math.Max(maxTeams - alreadyConfirmed, 0);

    /// <summary>O torneio está cheio quando as equipas confirmadas atingem o máximo.</summary>
    public static bool IsFull(int maxTeams, int confirmed) => maxTeams > 0 && confirmed >= maxTeams;
}
