namespace GameHall.Api.Modules.Tournaments;

/// <summary>Linha da base de dados (lista), com o número de equipas já calculado.</summary>
public sealed class TournamentRow
{
    public Guid Id { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public string OrganizerName { get; set; } = "";
    public string Sport { get; set; } = "";
    public string Format { get; set; } = "";
    public bool HasThirdPlace { get; set; }
    public string[] Tiebreakers { get; set; } = [];
    public string Status { get; set; } = "";
    public DateTime? RegistrationOpensAt { get; set; }
    public DateTime RegistrationClosesAt { get; set; }
    public DateOnly StartsOn { get; set; }
    public DateOnly EndsOn { get; set; }
    public string LocationName { get; set; } = "";
    public string? District { get; set; }
    public string? Municipality { get; set; }
    public string? LocationAddress { get; set; }
    public int EntryFeeCents { get; set; }
    public int MinAge { get; set; }
    public int? MaxAge { get; set; }
    public int MaxTeams { get; set; }
    public int MinPlayersPerTeam { get; set; }
    public int MaxPlayersPerTeam { get; set; }
    public int TeamsRegistered { get; set; }
    public int TeamsConfirmed { get; set; }
}

public sealed class TeamRow
{
    public Guid Id { get; set; }
    public string Name { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public bool Confirmed { get; set; }
}

/// <summary>Equipa do utilizador num torneio (para o resumo no detalhe).</summary>
public sealed class MyTeamBriefRow
{
    public Guid Id { get; set; }
    public string Name { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public bool IsHost { get; set; }
    public int MembersCount { get; set; }
    public bool Confirmed { get; set; }
}

/// <param name="MemberOf">Só torneios onde este utilizador está numa equipa (filtro "mine").</param>
public sealed record TournamentFilter(
    string? Status, DateOnly? From, DateOnly? To, string? Sport, int Page, int PageSize, Guid? MemberOf = null,
    string? District = null, string? Municipality = null);

// ----- DTOs (o que a API devolve) -----

public sealed record TournamentSummaryDto(
    Guid Id,
    string Name,
    string OrganizerName,
    string Sport,
    string Format,
    string Status,
    DateOnly StartsOn,
    DateOnly EndsOn,
    string LocationName,
    string? District,
    string? Municipality,
    int EntryFeeCents,
    int TeamsRegistered,
    int MaxTeams,
    int MinAge,
    int? MaxAge,
    string AgeLabel,
    DateTime RegistrationClosesAt,
    int TeamsConfirmed,
    bool IsFull);

public sealed record TournamentPageDto(
    IReadOnlyList<TournamentSummaryDto> Items, int Total, int Page, int PageSize);

public sealed record TeamDto(Guid Id, string Name, string ColorHex, bool Confirmed);

public sealed record EligibilityDto(bool CanCreateTeam, string? Reason);

public sealed record MyTeamBriefDto(Guid Id, string Name, string ColorHex, bool IsHost, int MembersCount, bool Confirmed);

public sealed record TournamentDetailDto(
    TournamentSummaryDto Summary,
    string? Description,
    bool HasThirdPlace,
    IReadOnlyList<string> Tiebreakers,
    string? LocationAddress,
    DateTime? RegistrationOpensAt,
    int MinPlayersPerTeam,
    int MaxPlayersPerTeam,
    IReadOnlyList<TeamDto> Teams,
    EligibilityDto Eligibility,
    Guid? MyTeamId,
    MyTeamBriefDto? MyTeam);
