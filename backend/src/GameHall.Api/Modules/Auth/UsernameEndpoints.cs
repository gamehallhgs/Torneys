using GameHall.Api.Common;

namespace GameHall.Api.Modules.Auth;

public sealed record UsernameCheckDto(bool Available, string? Reason, string? Message);

public sealed record ChangeUsernameRequest(string? Username);

public sealed record ChangeUsernameResponse(string Username, string Tag, DateTime? NextChangeAt);

/// <summary>Disponibilidade e mudança de username.</summary>
public static class UsernameEndpoints
{
    public static void MapUsernameEndpoints(this IEndpointRouteBuilder app)
    {
        // Público (também é usado no ecrã de registo, antes de haver conta). Os usernames não são segredo;
        // o que protege os convites é a tag. Limitado por IP.
        app.MapGet("/api/v1/usernames/check", async (
            string? username, HttpContext ctx, UsernameStore store, TimeProvider clock, CancellationToken ct) =>
        {
            var name = UsernameRules.Normalize(username);
            var problem = UsernameRules.Validate(name);
            if (problem is not null)
            {
                var reason = UsernameRules.IsReserved(name) ? "reserved" : "invalid";
                return Results.Ok(new UsernameCheckDto(false, reason, problem));
            }

            var availability = await store.CheckAsync(name, ctx.UserId(), clock.GetUtcNow().UtcDateTime, ct);
            return Results.Ok(availability switch
            {
                UsernameAvailability.Available => new UsernameCheckDto(true, null, null),
                UsernameAvailability.RecentlyUsed =>
                    new UsernameCheckDto(false, "recently_used", "Este username foi usado há pouco tempo e está reservado."),
                _ => new UsernameCheckDto(false, "taken", "Este username já está em uso.")
            });
        }).AllowAnonymous().RequireRateLimiting("lookup");

        // Só com sessão (não exige os termos em dia, tal como o resto de /me).
        app.MapPatch("/api/v1/me/username", async (
            ChangeUsernameRequest req, HttpContext ctx, UsernameStore store, AuthStore users,
            TimeProvider clock, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var name = UsernameRules.Normalize(req.Username);
            var problem = UsernameRules.Validate(name);
            if (problem is not null)
            {
                return ApiError.Validation(new Dictionary<string, string[]> { ["username"] = [problem] }).ToResult();
            }

            var now = clock.GetUtcNow().UtcDateTime;
            var change = await store.ChangeAsync(uid, name, now, ct);
            switch (change.Result)
            {
                case UsernameChangeResult.UserNotFound:
                    return Results.Unauthorized();
                case UsernameChangeResult.Taken:
                    return UsernameErrors.Taken.ToResult();
                case UsernameChangeResult.RecentlyUsed:
                    return UsernameErrors.RecentlyUsed.ToResult();
                case UsernameChangeResult.Cooldown:
                    return UsernameErrors.Cooldown(change.NextChangeAt!.Value).ToResult();
            }

            var user = await users.FindUserByIdAsync(uid, ct);
            return user is null
                ? Results.Unauthorized()
                : Results.Ok(new ChangeUsernameResponse(
                    user.Username, user.UsernameTag, UsernameRules.NextChangeAt(user.UsernameChangedAt, now)));
        }).RequireAuthorization("Authenticated").RequireRateLimiting("sensitive");
    }
}

internal static class UsernameErrors
{
    public static readonly ApiError Taken = new(409, "username_taken", "Este username já está em uso.");

    public static readonly ApiError RecentlyUsed =
        new(409, "username_reserved", "Este username foi usado há pouco tempo e está reservado.");

    public static ApiError Cooldown(DateTime nextChangeAt) => new(
        409, "username_change_cooldown",
        $"Só podes mudar o username uma vez por mês. Podes mudar de novo a {nextChangeAt:dd/MM/yyyy}.");
}
