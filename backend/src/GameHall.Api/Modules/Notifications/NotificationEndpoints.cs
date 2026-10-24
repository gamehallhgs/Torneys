using GameHall.Api.Common;

namespace GameHall.Api.Modules.Notifications;

/// <summary>
/// Central de notificações do utilizador (exige sessão e termos em dia). Para já só existem convites de equipa;
/// aceitar/recusar usa os endpoints de convites das equipas (POST /api/v1/invites/{id}/accept|decline).
/// </summary>
public static class NotificationEndpoints
{
    public static void MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/v1/notifications");

        g.MapGet("", async (HttpContext ctx, NotificationStore store, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var rows = await store.ListAsync(uid, ct);
            var items = rows.Select(r => new NotificationDto(
                r.Id, r.Type, r.CreatedAt, r.IsRead,
                new TeamInviteDto(
                    r.InviteId, r.InviteStatus, r.TeamId, r.TeamName, r.ColorHex,
                    r.TournamentId, r.TournamentName, r.InvitedByName, r.InvitedByUsername))).ToList();
            return Results.Ok(new NotificationListDto(rows.Count(r => !r.IsRead), items));
        });

        // Leve: a app pergunta de tempos a tempos para mostrar (ou não) o pontinho vermelho.
        g.MapGet("/unread-count", async (HttpContext ctx, NotificationStore store, CancellationToken ct) =>
            ctx.UserId() is { } uid
                ? Results.Ok(new UnreadCountDto(await store.UnreadCountAsync(uid, ct)))
                : Results.Unauthorized());

        g.MapPost("/read-all", async (HttpContext ctx, NotificationStore store, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            await store.MarkAllReadAsync(uid, ct);
            return Results.NoContent();
        });
    }
}
