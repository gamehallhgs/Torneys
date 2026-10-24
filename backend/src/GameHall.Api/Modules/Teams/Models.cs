namespace GameHall.Api.Modules.Teams;

// ----- Linhas da base de dados -----

public sealed class TeamInfoRow
{
    public Guid Id { get; set; }
    public Guid TournamentId { get; set; }
    public string Name { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public Guid? HostUserId { get; set; }
    public bool IsDemo { get; set; }
    public string TournamentName { get; set; } = "";
    public string TournamentStatus { get; set; } = "";
    public int MinAge { get; set; }
    public int? MaxAge { get; set; }
    public int MinPlayersPerTeam { get; set; }
    public int MaxPlayersPerTeam { get; set; }
    public DateTime RegistrationClosesAt { get; set; }
    public DateTime? ConfirmedAt { get; set; }
    public int MaxTeams { get; set; }
    public int TeamsConfirmed { get; set; }
    public bool ClosedToRequests { get; set; }
    public bool MembersCanInvite { get; set; }
}

public sealed class TournamentGateRow
{
    public Guid Id { get; set; }
    public string Status { get; set; } = "";
    public int MinAge { get; set; }
    public int? MaxAge { get; set; }
    public int MaxTeams { get; set; }

    /// <summary>Equipas confirmadas (são as que ocupam vaga).</summary>
    public int TeamsConfirmed { get; set; }
}

public sealed class MemberRow
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = "";
    public string Username { get; set; } = "";
    public string? Position { get; set; }
    public DateTime JoinedAt { get; set; }
    public bool Paid { get; set; }
}

public sealed class PendingRow
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = "";
    public string Username { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public sealed class RequestRow
{
    public Guid Id { get; set; }
    public Guid TeamId { get; set; }
    public Guid TournamentId { get; set; }
    public Guid UserId { get; set; }
    public string Status { get; set; } = "";
}

public sealed class InviteRow
{
    public Guid Id { get; set; }
    public Guid TeamId { get; set; }
    public Guid TournamentId { get; set; }
    public Guid InvitedUserId { get; set; }
    public Guid InvitedBy { get; set; }
    public string Status { get; set; } = "";
}

public sealed class MyTeamRow
{
    public Guid TeamId { get; set; }
    public string Name { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public Guid TournamentId { get; set; }
    public string TournamentName { get; set; } = "";
    public string TournamentStatus { get; set; } = "";
    public bool IsHost { get; set; }
    public int MembersCount { get; set; }
    public int MinPlayersPerTeam { get; set; }
    public int MaxPlayersPerTeam { get; set; }
    public int PendingRequests { get; set; }
}

public sealed class MyInviteRow
{
    public Guid Id { get; set; }
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public Guid TournamentId { get; set; }
    public string TournamentName { get; set; } = "";
    public string InvitedByName { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public sealed class MyRequestRow
{
    public Guid Id { get; set; }
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public Guid TournamentId { get; set; }
    public string TournamentName { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

// ----- Pedidos (corpo) -----

public sealed record CreateTeamRequest(string? Name, string? ColorHex);

/// <summary>Convite por email OU por username#tag (se vier Username, é esse que conta).</summary>
public sealed record InviteRequest(string? Email, string? Username = null);

/// <summary>Definições do lobby: cada campo é opcional (só muda o que vier preenchido).</summary>
public sealed record UpdateTeamSettingsRequest(bool? ClosedToRequests, bool? MembersCanInvite);

public sealed record SetPositionRequest(string? Position);

public sealed record TransferHostRequest(Guid? UserId);

// ----- Respostas -----

public sealed record TeamHeaderDto(
    Guid Id, string Name, string ColorHex, bool IsDemo, bool Confirmed, bool ClosedToRequests, bool MembersCanInvite);

public sealed record TeamTournamentDto(
    Guid Id, string Name, string Status, int MinPlayers, int MaxPlayers, DateTime RegistrationClosesAt,
    int TeamsConfirmed, int MaxTeams);

/// <summary>Paid só é preenchido para os membros da equipa (null para quem vê de fora).</summary>
public sealed record MemberDto(
    Guid UserId, string DisplayName, string Username, string? Position, bool IsHost, bool IsMe, bool? Paid);

public sealed record PendingDto(Guid Id, Guid UserId, string DisplayName, string Username, DateTime CreatedAt);

public sealed record TeamMeDto(
    bool IsMember,
    bool IsHost,
    Guid? PendingRequestId,
    Guid? PendingInviteId,
    Guid? MyTeamIdInTournament,
    bool CanRequestToJoin,
    string? JoinBlockedReason,
    bool CanInvite);

/// <summary>
/// Lobby da equipa. Qualquer jogador autenticado vê os membros e as posições (também de outras equipas);
/// só os membros veem os pagamentos e só o líder vê pedidos e convites pendentes.
/// </summary>
public sealed record TeamLobbyDto(
    TeamHeaderDto Team,
    TeamTournamentDto Tournament,
    int MembersCount,
    IReadOnlyList<MemberDto> Members,
    int MissingPositions,
    IReadOnlyList<PendingDto> Requests,
    IReadOnlyList<PendingDto> Invites,
    TeamMeDto Me);

public sealed record MyTeamDto(
    Guid TeamId, string Name, string ColorHex, Guid TournamentId, string TournamentName,
    string TournamentStatus, bool IsHost, int MembersCount, int MinPlayers, int MaxPlayers, int PendingRequests);

public sealed record MyInviteDto(
    Guid Id, Guid TeamId, string TeamName, string ColorHex, Guid TournamentId, string TournamentName,
    string InvitedByName, DateTime CreatedAt);

public sealed record MyRequestDto(
    Guid Id, Guid TeamId, string TeamName, string ColorHex, Guid TournamentId, string TournamentName,
    DateTime CreatedAt);
