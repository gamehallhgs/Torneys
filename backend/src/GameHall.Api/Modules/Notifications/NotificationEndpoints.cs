using GameHall.Api.Common;

namespace GameHall.Api.Modules.Notifications;

/// <summary>
/// Central de notificações do utilizador (exige sessão e termos em dia). Convites e pedidos para entrar têm
/// aceitar/recusar (POST /api/v1/invites/{id}/accept|decline e /api/v1/join-requests/{id}/accept|reject);
/// os eventos de equipa (fechada, vaga reservada, confirmada) são só informativos.
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

            var items = await store.ListAsync(uid, ct);
            return Results.Ok(new NotificationListDto(items.Count(n => !n.Read), items));
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

        // Apagar uma notificação ou limpar a central. Um convite/pedido apagado continua a poder ser respondido
        // pelo lobby; só desaparece da central.
        g.MapDelete("/{id:guid}", async (Guid id, HttpContext ctx, NotificationStore store, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            return await store.DeleteAsync(uid, id, ct) ? Results.NoContent() : Results.NotFound();
        });

        g.MapDelete("", async (HttpContext ctx, NotificationStore store, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            await store.DeleteAllAsync(uid, ct);
            return Results.NoContent();
        });
    }
}
