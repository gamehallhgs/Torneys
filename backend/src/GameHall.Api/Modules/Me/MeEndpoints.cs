using GameHall.Api.Common;
using GameHall.Api.Modules.Auth;

namespace GameHall.Api.Modules.Me;

/// <summary>
/// Endpoints do próprio utilizador. Usam a política "Authenticated" (não exigem os termos em dia)
/// para que seja sempre possível aceitar termos, exportar dados e eliminar a conta.
/// </summary>
public sealed record ChangeNameRequest(string? DisplayName);

public sealed record PushSettingRequest(bool? Enabled);

public sealed record DeviceTokenRequest(string? Token, string? Platform);

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

        // O nome que aparece pode ser mudado sempre que o utilizador quiser (ao contrário do username).
        g.MapPost("/onboarding-seen", async (AuthStore store, TimeProvider clock, HttpContext ctx, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            await store.MarkOnboardingSeenAsync(uid, clock.GetUtcNow().UtcDateTime, ct);
            return Results.NoContent();
        });

        // Interruptor geral de push (Perfil). Desligado = nenhum push, mas a central de notificações continua igual.
        g.MapPut("/push", async (PushSettingRequest req, AuthStore store, HttpContext ctx, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            if (req.Enabled is null)
            {
                return ApiError.Validation(new Dictionary<string, string[]> { ["enabled"] = ["Indica se queres receber notificações push."] })
                    .ToResult();
            }

            await store.SetPushEnabledAsync(uid, req.Enabled.Value, ct);
            var user = await store.FindUserByIdAsync(uid, ct);
            return user is null ? Results.Unauthorized() : Results.Ok(AuthService.ToDto(user));
        });

        // A app regista o token do Firebase ao iniciar sessão e apaga-o ao terminar sessão.
        g.MapPost("/devices", async (
            DeviceTokenRequest req, AuthStore store, TimeProvider clock, HttpContext ctx, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var token = (req.Token ?? "").Trim();
            var platform = (req.Platform ?? "").Trim().ToLowerInvariant();
            if (token.Length is < 20 or > 4096 || platform is not ("android" or "ios" or "web"))
            {
                return ApiError.Validation(new Dictionary<string, string[]> { ["token"] = ["Dispositivo inválido."] }).ToResult();
            }

            await store.UpsertDeviceTokenAsync(uid, token, platform, clock.GetUtcNow().UtcDateTime, ct);
            return Results.NoContent();
        }).RequireRateLimiting("sensitive");

        g.MapPost("/devices/remove", async (DeviceTokenRequest req, AuthStore store, HttpContext ctx, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            if (!string.IsNullOrWhiteSpace(req.Token))
            {
                await store.DeleteDeviceTokenAsync(uid, req.Token.Trim(), ct);
            }

            return Results.NoContent();
        });

        g.MapPatch("/name", async (
            ChangeNameRequest req, AuthStore store, TimeProvider clock, HttpContext ctx, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var name = (req.DisplayName ?? "").Trim();
            if (AuthValidation.DisplayNameProblem(name) is { } nameProblem)
            {
                return ApiError.Validation(new Dictionary<string, string[]>
                {
                    ["displayName"] = [nameProblem]
                }).ToResult();
            }

            if (!await store.UpdateDisplayNameAsync(uid, name, clock.GetUtcNow().UtcDateTime, ct))
            {
                return Results.Unauthorized();
            }

            var user = await store.FindUserByIdAsync(uid, ct);
            return user is null ? Results.Unauthorized() : Results.Ok(AuthService.ToDto(user));
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
                    user.Username,
                    user.UsernameTag,
                    user.BirthDate,
                    user.Gender,
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
