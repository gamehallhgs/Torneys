using GameHall.Api.Common;

namespace GameHall.Api.Modules.Auth;

public static class AuthEndpoints
{
    private const string Uniform = "Se os dados estiverem corretos, enviámos-te um email com as próximas instruções.";

    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/v1/auth").AllowAnonymous();

        g.MapPost("/register", async (RegisterRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var error = await svc.RegisterAsync(req, ctx.Ip(), ct);
            return error is null
                ? Results.Json(new { message = Uniform }, statusCode: StatusCodes.Status202Accepted)
                : error.ToResult();
        }).RequireRateLimiting("auth");

        g.MapPost("/verify-email", async (EmailCodeRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var error = await svc.VerifyEmailAsync(req.Email, req.Code, ctx.Ip(), ct);
            return error is null ? Results.NoContent() : error.ToResult();
        }).RequireRateLimiting("sensitive");

        g.MapPost("/resend-verification", async (EmailOnlyRequest req, AuthService svc, CancellationToken ct) =>
        {
            await svc.ResendVerificationAsync(req.Email, ct);
            return Results.Json(new { message = Uniform }, statusCode: StatusCodes.Status202Accepted);
        }).RequireRateLimiting("sensitive");

        g.MapPost("/login", async (LoginRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var result = await svc.LoginAsync(req, ctx.Ip(), ct);
            return result.IsOk ? Results.Ok(result.Value) : result.Error!.ToResult();
        }).RequireRateLimiting("auth");

        g.MapPost("/refresh", async (RefreshRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var result = await svc.RefreshAsync(req.RefreshToken, ctx.Ip(), ct);
            return result.IsOk ? Results.Ok(result.Value) : result.Error!.ToResult();
        }).RequireRateLimiting("auth");

        g.MapPost("/logout", async (RefreshRequest req, AuthService svc, CancellationToken ct) =>
        {
            await svc.LogoutAsync(req.RefreshToken, ct);
            return Results.NoContent();
        }).RequireRateLimiting("auth");

        g.MapPost("/forgot-password", async (EmailOnlyRequest req, AuthService svc, CancellationToken ct) =>
        {
            await svc.ForgotPasswordAsync(req.Email, ct);
            return Results.Json(new { message = Uniform }, statusCode: StatusCodes.Status202Accepted);
        }).RequireRateLimiting("sensitive");

        g.MapPost("/reset-password", async (ResetPasswordRequest req, AuthService svc, HttpContext ctx, CancellationToken ct) =>
        {
            var error = await svc.ResetPasswordAsync(req, ctx.Ip(), ct);
            return error is null ? Results.NoContent() : error.ToResult();
        }).RequireRateLimiting("sensitive");
    }
}
