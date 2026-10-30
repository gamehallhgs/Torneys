namespace GameHall.Api.Modules.Voting;

public sealed class RoundRow
{
    public Guid Id { get; set; }
    public int RoundNumber { get; set; }
    public DateTime OpenedAt { get; set; }
    public DateTime ClosesAt { get; set; }
}

public sealed class TallyRow
{
    public Guid RoundId { get; set; }
    public string Category { get; set; } = "";
    public Guid CandidateId { get; set; }
    public int Votes { get; set; }
}

public sealed class CandidateRow
{
    public string Category { get; set; } = "";
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = "";
    public string? Position { get; set; }
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
}

public sealed class MyVoteRow
{
    public string Category { get; set; } = "";
    public Guid CandidateId { get; set; }
}

public sealed class WinnerRow
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = "";
    public string? Position { get; set; }
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
}

// ----- Respostas -----

/// <summary>Perfil do vencedor: só o nome escolhido, a equipa e a posição (nunca @username#tag, email ou idade).</summary>
public sealed record AwardWinnerDto(Guid UserId, string DisplayName, string? Position, Guid TeamId, string TeamName, string ColorHex);

/// <summary>Status: "pending" (empate, ainda pode haver desempate) ou "final".</summary>
public sealed record AwardDto(string Status, IReadOnlyList<AwardWinnerDto> Winners);

public sealed record CandidateDto(
    Guid UserId, string DisplayName, string? Position, Guid TeamId, string TeamName, string ColorHex);

public sealed record VotingCategoryDto(string Category, Guid? MyVote, IReadOnlyList<CandidateDto> Candidates);

/// <summary>Votação aberta agora. CanVote/CannotVoteReason dizem se este utilizador pode votar.</summary>
public sealed record VotingDto(
    int RoundNumber, DateTime ClosesAt, bool CanVote, string? CannotVoteReason, IReadOnlyList<VotingCategoryDto> Categories);

/// <summary>
/// O que a página de um torneio terminado mostra além da informação: pódio, prémios e (se estiver aberta) a votação.
/// Os prémios são null quando o gestor não fez votação (ou ainda não há votos).
/// </summary>
public sealed record TournamentResultsDto(
    IReadOnlyList<Games.PodiumEntryDto> Podium,
    AwardDto? BestPlayer,
    AwardDto? BestGoalkeeper,
    VotingDto? Voting);

public sealed record CastVoteRequest(string? Category, Guid? CandidateUserId);
