namespace GameHall.Api.Modules.Notifications;

public static class NotificationTypes
{
    /// <summary>Alguém convidou o utilizador para a sua equipa. data = {"inviteId": "..."}.</summary>
    public const string TeamInvite = "team_invite";

    /// <summary>Alguém pediu para entrar na equipa do líder. data = {"requestId": "..."}.</summary>
    public const string JoinRequest = "join_request";

    /// <summary>O líder fechou a equipa (e quem paga o quê). data = evento de equipa (ver TeamEventData).</summary>
    public const string TeamClosed = "team_closed";

    /// <summary>Uma vaga ficou reservada para a equipa que estava em fila.</summary>
    public const string SlotReserved = "slot_reserved";

    /// <summary>Todos pagaram: a equipa está confirmada no torneio.</summary>
    public const string TeamConfirmed = "team_confirmed";

    /// <summary>O líder respondeu ao meu pedido para entrar (aceite ou recusado).</summary>
    public const string RequestDecided = "request_decided";

    /// <summary>Faltam poucos minutos para acabar o prazo de pagamento.</summary>
    public const string ReservationExpiring = "reservation_expiring";

    /// <summary>O prazo de pagamento acabou: a equipa voltou à formação (e há penalização para quem não pagou).</summary>
    public const string ReservationExpired = "reservation_expired";

    /// <summary>A equipa foi eliminada do torneio.</summary>
    public const string TeamEliminated = "team_eliminated";

    /// <summary>O líder expulsou o utilizador da equipa.</summary>
    public const string RemovedFromTeam = "removed_from_team";

    /// <summary>A liderança da equipa passou para o utilizador.</summary>
    public const string NowLeader = "now_leader";

    /// <summary>Um jogador entrou na equipa com o código de convite (visto pelo líder).</summary>
    public const string MemberJoined = "member_joined";

    /// <summary>Começou uma votação (1.ª ronda) no torneio. Só na app: nunca push nem email.</summary>
    public const string VotingOpened = "voting_opened";

    /// <summary>Houve empate e abriu a 2.ª ronda. Só na app.</summary>
    public const string VotingSecondRound = "voting_second_round";

    /// <summary>Os resultados da votação foram publicados (com os vencedores). Só na app.</summary>
    public const string VotingResults = "voting_results";

    /// <summary>Um jogo da minha equipa começa dentro de ~30 minutos. Push.</summary>
    public const string GameStarting = "game_starting";

    /// <summary>Jogo marcado, alterado (hora/campo), adiado ou cancelado. Push.</summary>
    public const string GameChanged = "game_changed";

    /// <summary>Notificações sobre um torneio ou jogo (e não sobre uma equipa): guardam <see cref="InfoEventData"/>.</summary>
    public static readonly string[] InfoTypes = [VotingOpened, VotingSecondRound, VotingResults, GameStarting, GameChanged];

    /// <summary>
    /// Quais geram push no telemóvel (se o utilizador não o desligou). Convite, pedido, equipa confirmada, vaga
    /// reservada, tempo a acabar, reserva expirada e jogos. A votação fica de fora de propósito.
    /// </summary>
    public static readonly string[] PushTypes =
    [
        TeamInvite, JoinRequest, TeamConfirmed, SlotReserved, ReservationExpiring, ReservationExpired,
        GameStarting, GameChanged
    ];

    /// <summary>Quais geram também email: falta 5 minutos (se ainda não pagou), equipa confirmada e vaga reservada.</summary>
    public static readonly string[] EmailTypes = [ReservationExpiring, TeamConfirmed, SlotReserved];

    public static readonly string[] EventTypes =
    [
        MemberJoined,
        TeamClosed, SlotReserved, TeamConfirmed, RequestDecided, ReservationExpiring, ReservationExpired,
        TeamEliminated, RemovedFromTeam, NowLeader
    ];
}

/// <summary>Dados guardados numa notificação de evento de equipa (texto já composto no momento do evento).</summary>
public sealed record TeamEventData(
    Guid TeamId, string TeamName, string ColorHex, string TournamentName, string Title, string Message);

/// <summary>Dados de uma notificação de torneio/jogo (texto já composto). GameId só nos avisos de jogo.</summary>
public sealed record InfoEventData(Guid TournamentId, string TournamentName, Guid? GameId, string Title, string Message);

public sealed class RawNotificationRow
{
    public Guid Id { get; set; }
    public string Type { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public bool IsRead { get; set; }
    public string Data { get; set; } = "{}";
}

public sealed class InviteInfoRow
{
    public Guid InviteId { get; set; }
    public string InviteStatus { get; set; } = "";
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public Guid TournamentId { get; set; }
    public string TournamentName { get; set; } = "";
    public string InvitedByName { get; set; } = "";
    public string InvitedByUsername { get; set; } = "";
}

public sealed class RequestInfoRow
{
    public Guid RequestId { get; set; }
    public string RequestStatus { get; set; } = "";
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = "";
    public string ColorHex { get; set; } = "";
    public Guid TournamentId { get; set; }
    public string TournamentName { get; set; } = "";
    public string RequesterName { get; set; } = "";
    public string RequesterUsername { get; set; } = "";
}

/// <summary>Convite de equipa dentro de uma notificação. Status: pending, accepted, declined, cancelled.</summary>
public sealed record TeamInviteDto(
    Guid InviteId, string Status, Guid TeamId, string TeamName, string ColorHex,
    Guid TournamentId, string TournamentName, string InvitedByName, string InvitedByUsername);

/// <summary>Pedido para entrar (visto pelo líder). Status: pending, accepted, rejected, cancelled.</summary>
public sealed record JoinRequestDto(
    Guid RequestId, string Status, Guid TeamId, string TeamName, string ColorHex,
    Guid TournamentId, string TournamentName, string RequesterName, string RequesterUsername);

/// <summary>Evento de equipa (fechada, vaga reservada, confirmada). TeamExists = a equipa ainda existe (dá para a abrir).</summary>
public sealed record TeamEventDto(
    Guid TeamId, string TeamName, string ColorHex, string TournamentName, string Title, string Message, bool TeamExists);

/// <summary>Aviso sobre um torneio/jogo. TournamentExists = o torneio ainda existe (dá para o abrir).</summary>
public sealed record InfoEventDto(
    Guid TournamentId, string TournamentName, Guid? GameId, string Title, string Message, bool TournamentExists);

public sealed record NotificationDto(
    Guid Id, string Type, DateTime CreatedAt, bool Read,
    TeamInviteDto? Invite, JoinRequestDto? Request = null, TeamEventDto? Event = null, InfoEventDto? Info = null);

public sealed record NotificationListDto(int UnreadCount, IReadOnlyList<NotificationDto> Items);

public sealed record UnreadCountDto(int Count);
