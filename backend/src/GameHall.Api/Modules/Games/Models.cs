namespace GameHall.Api.Modules.Games;

// ----- Linhas da base de dados (nomes snake_case -> PascalCase pelo Dapper) -----

public sealed class GameRow
{
    public Guid Id { get; set; }
    public Guid TournamentId { get; set; }
    public string TournamentName { get; set; } = "";
    public string Stage { get; set; } = "";
    public string? GroupName { get; set; }
    public int RoundNumber { get; set; }
    public string? RoundLabel { get; set; }
    public int MatchNumber { get; set; }
    public DateTime? ScheduledAt { get; set; }
    public string? FieldName { get; set; }
    public string Status { get; set; } = "";
    public Guid? HomeTeamId { get; set; }
    public string? HomeName { get; set; }
    public string? HomeColor { get; set; }
    public Guid? AwayTeamId { get; set; }
    public string? AwayName { get; set; }
    public string? AwayColor { get; set; }
    public int? HomeGoals { get; set; }
    public int? AwayGoals { get; set; }
    public int? HomePenalties { get; set; }
    public int? AwayPenalties { get; set; }
    public int HighlightsCount { get; set; }
}

public sealed class EventRow
{
    public Guid Id { get; set; }
    public Guid TeamId { get; set; }
    public string PlayerName { get; set; } = "";
    public string Type { get; set; } = "";
    public int? Minute { get; set; }
}

public sealed class HighlightRow
{
    public Guid Id { get; set; }
    public string Url { get; set; } = "";
    public string? Title { get; set; }
    public int DurationSeconds { get; set; }
}

public sealed class StandingsGameRow
{
    public Guid? HomeTeamId { get; set; }
    public Guid? AwayTeamId { get; set; }
    public int? HomeGoals { get; set; }
    public int? AwayGoals { get; set; }
    public string Status { get; set; } = "";
    public string? GroupName { get; set; }
}

public sealed class CardCountRow
{
    public Guid TeamId { get; set; }
    public string Type { get; set; } = "";
    public int Total { get; set; }
}

public sealed class StatLineRow
{
    public string PlayerName { get; set; } = "";
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public int Total { get; set; }
}

// ----- Respostas -----

public sealed record GameTeamDto(Guid? Id, string? Name, string? ColorHex);

public sealed record GameDto(
    Guid Id,
    string Stage,
    string? GroupName,
    int RoundNumber,
    string? RoundLabel,
    int MatchNumber,
    DateTime? ScheduledAt,
    string? FieldName,
    string Status,
    GameTeamDto Home,
    GameTeamDto Away,
    int? HomeGoals,
    int? AwayGoals,
    int? HomePenalties,
    int? AwayPenalties,
    int HighlightsCount);

public sealed record GameEventDto(Guid Id, Guid TeamId, string PlayerName, string Type, int? Minute);

public sealed record HighlightDto(Guid Id, string Url, string? Title, int DurationSeconds);

public sealed record GameDetailDto(
    GameDto Game,
    Guid TournamentId,
    string TournamentName,
    IReadOnlyList<GameEventDto> Events,
    IReadOnlyList<HighlightDto> Highlights);

public sealed record StandingRowDto(
    int Position,
    Guid TeamId,
    string Name,
    string ColorHex,
    int Played,
    int Won,
    int Drawn,
    int Lost,
    int GoalsFor,
    int GoalsAgainst,
    int GoalDifference,
    int Points,
    int YellowCards,
    int RedCards);

public sealed record StandingsGroupDto(string? Name, IReadOnlyList<StandingRowDto> Rows);

public sealed record StandingsDto(IReadOnlyList<string> Tiebreakers, IReadOnlyList<StandingsGroupDto> Groups);

public sealed record StatLineDto(string PlayerName, Guid TeamId, string TeamName, string ColorHex, int Total);

public sealed record StatsDto(
    IReadOnlyList<StatLineDto> Scorers,
    IReadOnlyList<StatLineDto> Assists,
    IReadOnlyList<StatLineDto> YellowCards,
    IReadOnlyList<StatLineDto> RedCards);
