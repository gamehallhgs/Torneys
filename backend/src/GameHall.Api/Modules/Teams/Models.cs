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
    public string Gender { get; set; } = "mixed";
    public int MinPlayersPerTeam { get; set; }
    public int MaxPlayersPerTeam { get; set; }
    public DateTime RegistrationClosesAt { get; set; }
    public DateTime? ConfirmedAt { get; set; }
    public int MaxTeams { get; set; }
    public int TeamsConfirmed { get; set; }
    public bool IsPrivate { get; set; }
    public bool MembersCanInvite { get; set; }
    public string Sport { get; set; } = "";
    public string? RulesText { get; set; }
    public string InviteCode { get; set; } = "";
    public bool InviteCodeEnabled { get; set; }
    public bool CodeDirectEntry { get; set; } = true;
    public bool MembersSeeCode { get; set; }
    public string? Formation { get; set; }

    // Fecho da equipa e reserva de vaga (migração 011).
    public DateTime? ClosedAt { get; set; }
    public string? PaymentMode { get; set; }
    public int? ShareCents { get; set; }
    public DateTime? ReservedAt { get; set; }
    public DateTime? ReservationExpiresAt { get; set; }
    public int EntryFeeCents { get; set; }

    /// <summary>Vagas ocupadas (reservadas ou confirmadas).</summary>
    public int TeamsReserved { get; set; }

    public string State => ReservationRules.StateOf(ClosedAt, ReservedAt, ConfirmedAt);
}

public sealed class TournamentGateRow
{
    public Guid Id { get; set; }
    public string Status { get; set; } = "";
    public int MinAge { get; set; }
    public int? MaxAge { get; set; }
    public string Gender { get; set; } = "mixed";
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
    public bool Ready { get; set; }
    public int? Slot { get; set; }
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
    public DateTime? ClosedAt { get; set; }
    public DateTime? ReservedAt { get; set; }
    public DateTime? ConfirmedAt { get; set; }
    public DateTime? ReservationExpiresAt { get; set; }
    public string State => ReservationRules.StateOf(ClosedAt, ReservedAt, ConfirmedAt);
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
public sealed record UpdateTeamSettingsRequest(
    bool? IsPrivate, bool? MembersCanInvite, bool? InviteCodeEnabled = null, bool? CodeDirectEntry = null,
    bool? MembersSeeCode = null);

/// <summary>
/// Código de convite no lobby. O líder vê tudo; os membros só veem o código se o líder o permitir (e estiver ativo).
/// RegensLeft = quantos códigos novos o líder ainda pode gerar nesta hora (só para o líder).
/// </summary>
public sealed record TeamCodeDto(string? Code, bool Enabled, bool DirectEntry, bool MembersSeeCode, int RegensLeft);

/// <summary>O que quem tem um código vê antes de entrar. BlockedReason/BlockedMessage = porque não pode entrar já.</summary>
public sealed record InviteCodePreviewDto(
    Guid TeamId, string TeamName, string ColorHex, string TournamentName, int MembersCount, int MaxPlayers,
    bool DirectEntry, string? BlockedReason, string? BlockedMessage);

/// <summary>Joined = entrou logo; senão ficou um pedido pendente para o líder aceitar.</summary>
public sealed record JoinByCodeResultDto(Guid TeamId, bool Joined);

public sealed record RegenerateCodeResultDto(string Code, int RegensLeft);

/// <summary>Fechar a equipa: "split" (cada um paga a sua parte) ou "total" (o líder paga tudo).</summary>
public sealed record CloseTeamRequest(string? PaymentMode);

/// <summary>Marcar-se como preparado (ou deixar de estar).</summary>
public sealed record SetReadyRequest(bool? Ready);

public sealed record SetPositionRequest(string? Position);

public sealed record TransferHostRequest(Guid? UserId);

// ----- Respostas -----

public sealed record TeamHeaderDto(
    Guid Id, string Name, string ColorHex, bool IsDemo, bool Confirmed, bool IsPrivate, bool MembersCanInvite);

public sealed record TeamTournamentDto(
    Guid Id, string Name, string Status, int MinPlayers, int MaxPlayers, DateTime RegistrationClosesAt,
    int TeamsConfirmed, int MaxTeams, string Rules = "");

/// <summary>Paid e Ready só são preenchidos para os membros da equipa (null para quem vê de fora).</summary>
public sealed record MemberDto(
    Guid UserId, string DisplayName, string Username, string? Position, bool IsHost, bool IsMe, bool? Paid,
    bool? Ready = null, int? Slot = null, bool? Penalized = null);

/// <summary>Formação: a escolhida, as disponíveis para a modalidade e o nº de lugares em campo.</summary>
public sealed record LineupDto(string Formation, IReadOnlyList<string> Formations, int SlotCount);

public sealed record LineupSlotRequest(Guid UserId, int Slot);

public sealed record SetLineupRequest(string? Formation, IReadOnlyList<LineupSlotRequest>? Slots);

public sealed record PendingDto(Guid Id, Guid UserId, string DisplayName, string Username, DateTime CreatedAt);

public sealed record TeamMeDto(
    bool IsMember,
    bool IsHost,
    Guid? PendingRequestId,
    Guid? PendingInviteId,
    Guid? MyTeamIdInTournament,
    bool CanRequestToJoin,
    string? JoinBlockedReason,
    bool CanInvite,
    bool Ready = false,
    DateTime? PenaltyUntil = null,
    bool CanClose = false,
    string? CloseBlockedReason = null,
    string? CloseBlockedMessage = null,
    bool CanReopen = false,
    bool CanDisband = false);

/// <summary>Estado da equipa: forming, queued (fechada, à espera de vaga), reserved (a pagar) ou confirmed.</summary>
public sealed record TeamReservationDto(
    string State, DateTime? ClosedAt, DateTime? ExpiresAt, int? QueuePosition, int SlotsTaken, int MaxTeams,
    int ReservationMinutes, int PenaltyMinutes);

/// <summary>
/// Valores a pagar. Antes de fechar, Mode é null e ShareCents mostra a parte dividida a título de pré-visualização
/// (arredondada para cima). RoundedUp avisa o líder de que a equipa paga ExtraCents a mais por causa do arredondamento.
/// </summary>
public sealed record TeamPaymentDto(
    int FeeCents, string? Mode, int ShareCents, int Members, int CollectedCents, int ExtraCents, bool RoundedUp,
    int PaidCount, bool IPaid, bool CanPay, string? CannotPayReason);

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
    TeamMeDto Me,
    TeamReservationDto Reservation,
    TeamPaymentDto Payment,
    LineupDto? Lineup = null,
    TeamCodeDto? InviteCode = null);

public sealed record MyTeamDto(
    Guid TeamId, string Name, string ColorHex, Guid TournamentId, string TournamentName,
    string TournamentStatus, bool IsHost, int MembersCount, int MinPlayers, int MaxPlayers, int PendingRequests,
    string State = "forming", DateTime? ReservationExpiresAt = null);

public sealed record MyInviteDto(
    Guid Id, Guid TeamId, string TeamName, string ColorHex, Guid TournamentId, string TournamentName,
    string InvitedByName, DateTime CreatedAt);

public sealed record MyRequestDto(
    Guid Id, Guid TeamId, string TeamName, string ColorHex, Guid TournamentId, string TournamentName,
    DateTime CreatedAt);
