using System.Data;
using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Notifications;

/// <summary>SQL das notificações. A criação recebe a ligação/transação para ser atómica com o que a gerou.</summary>
public sealed class NotificationStore(NpgsqlDataSource db)
{
    public const int MaxItems = 50;

    // Só conta/mostra convites que ainda existem (se a equipa for eliminada, o convite e a notificação desaparecem).
    private const string InviteJoin =
        """
        FROM notifications n
        JOIN team_invites i ON i.id = (n.data->>'inviteId')::uuid
        JOIN teams t ON t.id = i.team_id
        JOIN tournaments tr ON tr.id = t.tournament_id
        JOIN users ub ON ub.id = i.invited_by
        WHERE n.user_id = @U AND n.type = 'team_invite'
        """;

    public static Task<int> InsertTeamInviteAsync(IDbConnection c, IDbTransaction tx, Guid userId, Guid inviteId) =>
        c.ExecuteAsync(
            """
            INSERT INTO notifications (id, user_id, type, data)
            VALUES (@Id, @U, 'team_invite', jsonb_build_object('inviteId', @Invite::text))
            """,
            new { Id = Guid.NewGuid(), U = userId, Invite = inviteId }, tx);

    public async Task<IReadOnlyList<NotificationRow>> ListAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<NotificationRow>(new CommandDefinition(
            $"""
            SELECT n.id, n.type, n.created_at, (n.read_at IS NOT NULL) AS is_read,
                   i.id AS invite_id, i.status AS invite_status,
                   t.id AS team_id, t.name AS team_name, t.color_hex,
                   tr.id AS tournament_id, tr.name AS tournament_name, ub.display_name AS invited_by_name, ub.username AS invited_by_username
            {InviteJoin}
            ORDER BY n.created_at DESC
            LIMIT {MaxItems}
            """,
            new { U = userId }, cancellationToken: ct))).ToList();
    }

    public async Task<int> UnreadCountAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            $"SELECT count(*)::int {InviteJoin} AND n.read_at IS NULL",
            new { U = userId }, cancellationToken: ct));
    }

    public async Task MarkAllReadAsync(Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE notifications SET read_at = now() WHERE user_id = @U AND read_at IS NULL",
            new { U = userId }, cancellationToken: ct));
    }
}
