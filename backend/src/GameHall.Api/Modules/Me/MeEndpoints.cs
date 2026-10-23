using GameHall.Api.Common;
using GameHall.Api.Modules.Auth;

namespace GameHall.Api.Modules.Me;

/// <summary>
/// Endpoints do próprio utilizador. Usam a política "Authenticated" (não exigem os termos em dia)
/// para que seja sempre possível aceitar termos, exportar dados e eliminar a conta.
/// </summary>
public static class MeEndpoints
{
    public static void MapMeEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/v1/me").RequireAuthorization("Authenticated");

        g.MapGet("", async (HttpContext ctx, AuthStore store, CancellationToken ct) =>
        {
            var id = ctx.UserId();
            var user = id is null ? null : await store.FindUserByIdAsync(id.Value, ct);
            return user is null ? Results.Unauthorized() : Results.Ok(AuthService.ToDto(user));
        });

        // Depois de aceitar, a app deve chamar /auth/refresh para obter um token com legal_ok=true.
        g.MapPost("/consents", async (AcceptLegalRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var id = ctx.UserId();
            if (id is null)
            {
                return Results.Unauthorized();
            }

            var error = await svc.AcceptLegalAsync(id.Value, req, ctx.Ip(), ct);
            return error is null ? Results.NoContent() : error.ToResult();
        }).RequireRateLimiting("sensitive");

        g.MapPost("/change-password", async (ChangePasswordRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var id = ctx.UserId();
            if (id is null)
            {
                return Results.Unauthorized();
            }

            var error = await svc.ChangePasswordAsync(id.Value, req, ctx.Ip(), ct);
            return error is null ? Results.NoContent() : error.ToResult();
        }).RequireRateLimiting("sensitive");

        g.MapPost("/logout-all", async (AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var id = ctx.UserId();
            if (id is null)
            {
                return Results.Unauthorized();
            }

            await svc.LogoutAllAsync(id.Value, ctx.Ip(), ct);
            return Results.NoContent();
        });

        // Direito de acesso/portabilidade (RGPD): todos os dados que temos sobre o utilizador.
        g.MapGet("/export", async (HttpContext ctx, AuthStore store, CancellationToken ct) =>
        {
            var id = ctx.UserId();
            var user = id is null ? null : await store.FindUserByIdAsync(id.Value, ct);
            if (user is null)
            {
                return Results.Unauthorized();
            }

            var consents = await store.GetAllConsentsAsync(user.Id, ct);
            var audit = await store.GetAuditAsync(user.Id, ct);
            return Results.Ok(new
            {
                exportedAt = DateTime.UtcNow,
                profile = new
                {
                    user.Id,
                    user.Email,
                    user.DisplayName,
                    user.BirthDate,
                    role = user.Role.ToString(),
                    user.EmailVerifiedAt,
                    user.CreatedAt
                },
                consents = consents.Select(c => new { c.DocumentType, c.Version, c.Granted, c.CreatedAt }),
                activity = audit.Select(a => new { a.Action, a.CreatedAt })
            });
        }).RequireRateLimiting("sensitive");

        // Direito ao apagamento. POST (e não DELETE) porque leva corpo com a palavra-passe.
        g.MapPost("/delete", async (DeleteAccountRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var id = ctx.UserId();
            if (id is null)
            {
                return Results.Unauthorized();
            }

            var error = await svc.DeleteAccountAsync(id.Value, req.Password, ctx.Ip(), ct);
            return error is null ? Results.NoContent() : error.ToResult();
        }).RequireRateLimiting("sensitive");
    }
}
