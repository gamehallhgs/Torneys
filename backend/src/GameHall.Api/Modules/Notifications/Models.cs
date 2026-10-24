namespace GameHall.Api.Modules.Notifications;

public static class NotificationTypes
{
    /// <summary>Alguém convidou o utilizador para a sua equipa. data = {"inviteId": "..."}.</summary>
    public const string TeamInvite = "team_invite";
}

public sealed class NotificationRow
{
    public Guid Id { get; set; }
    public string Type { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public bool IsRead { get; set; }
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

/// <summary>Convite de equipa dentro de uma notificação. Status: pending, accepted, declined, cancelled.</summary>
public sealed record TeamInviteDto(
    Guid InviteId, string Status, Guid TeamId, string TeamName, string ColorHex,
    Guid TournamentId, string TournamentName, string InvitedByName, string InvitedByUsername);

public sealed record NotificationDto(Guid Id, string Type, DateTime CreatedAt, bool Read, TeamInviteDto? Invite);

public sealed record NotificationListDto(int UnreadCount, IReadOnlyList<NotificationDto> Items);

public sealed record UnreadCountDto(int Count);
