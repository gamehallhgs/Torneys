using GameHall.Api.Common;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Equipas, lobby, pedidos para entrar, convites, líder e posições. Todos exigem sessão e termos em dia
/// (política por defeito). Erros no formato habitual: ProblemDetails com "code" estável.
/// </summary>
public static class TeamEndpoints
{
    public static void MapTeamEndpoints(this IEndpointRouteBuilder app)
    {
        // ---------- Criar equipa ----------
        app.MapPost("/api/v1/tournaments/{tournamentId:guid}/teams", async (
            Guid tournamentId, CreateTeamRequest req, HttpContext ctx, TeamService svc, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var created = await svc.CreateTeamAsync(uid, tournamentId, req, ct);
            if (!created.IsOk)
            {
                return created.Error!.ToResult();
            }

            return await LobbyResult(svc, uid, created.Value, ct, StatusCodes.Status201Created);
        }).RequireRateLimiting("auth");

        // ---------- Lobby ----------
        app.MapGet("/api/v1/teams/{teamId:guid}", async (
            Guid teamId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            return await LobbyResult(svc, uid, teamId, ct, StatusCodes.Status200OK);
        });

        var teams = app.MapGroup("/api/v1/teams/{teamId:guid}");

        teams.MapPost("/join-requests", (Guid teamId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.RequestJoinAsync(uid, teamId, ct))).RequireRateLimiting("auth");

        teams.MapPost("/invites", (Guid teamId, InviteRequest req, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.InviteAsync(uid, teamId, req.Email, req.Username, ct), StatusCodes.Status202Accepted))
            .RequireRateLimiting("auth");

        teams.MapPatch("/settings", (Guid teamId, UpdateTeamSettingsRequest req, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.UpdateSettingsAsync(uid, teamId, req, ct)));

        teams.MapPost("/position", (Guid teamId, SetPositionRequest req, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.SetPositionAsync(uid, teamId, req.Position, ct)));

        teams.MapPost("/transfer-host", (Guid teamId, TransferHostRequest req, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.TransferHostAsync(uid, teamId, req.UserId, ct)));

        teams.MapPost("/leave", (Guid teamId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.LeaveAsync(uid, teamId, ct)));

        teams.MapPost("/members/{memberId:guid}/remove", (Guid teamId, Guid memberId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.RemoveMemberAsync(uid, teamId, memberId, ct)));

        // ---------- Pedidos ----------
        var requests = app.MapGroup("/api/v1/join-requests/{requestId:guid}");

        requests.MapPost("/accept", (Guid requestId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.DecideRequestAsync(uid, requestId, true, ct)));

        requests.MapPost("/reject", (Guid requestId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.DecideRequestAsync(uid, requestId, false, ct)));

        requests.MapPost("/cancel", (Guid requestId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.CancelRequestAsync(uid, requestId, ct)));

        // ---------- Convites ----------
        var invites = app.MapGroup("/api/v1/invites/{inviteId:guid}");

        invites.MapPost("/accept", (Guid inviteId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.RespondInviteAsync(uid, inviteId, true, ct)));

        invites.MapPost("/decline", (Guid inviteId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.RespondInviteAsync(uid, inviteId, false, ct)));

        invites.MapPost("/cancel", (Guid inviteId, HttpContext ctx, TeamService svc, CancellationToken ct) =>
            Act(ctx, uid => svc.CancelInviteAsync(uid, inviteId, ct)));

        // ---------- Listas do utilizador ----------
        var my = app.MapGroup("/api/v1/my");

        my.MapGet("/teams", async (HttpContext ctx, TeamService svc, CancellationToken ct) =>
            ctx.UserId() is { } uid ? Results.Ok(await svc.MyTeamsAsync(uid, ct)) : Results.Unauthorized());

        my.MapGet("/invites", async (HttpContext ctx, TeamService svc, CancellationToken ct) =>
            ctx.UserId() is { } uid ? Results.Ok(await svc.MyInvitesAsync(uid, ct)) : Results.Unauthorized());

        my.MapGet("/join-requests", async (HttpContext ctx, TeamService svc, CancellationToken ct) =>
            ctx.UserId() is { } uid ? Results.Ok(await svc.MyRequestsAsync(uid, ct)) : Results.Unauthorized());
    }

    private static async Task<IResult> Act(
        HttpContext ctx, Func<Guid, Task<ApiError?>> action, int successStatus = StatusCodes.Status204NoContent)
    {
        if (ctx.UserId() is not { } uid)
        {
            return Results.Unauthorized();
        }

        var error = await action(uid);
        return error is null ? Results.StatusCode(successStatus) : error.ToResult();
    }

    private static async Task<IResult> LobbyResult(
        TeamService svc, Guid userId, Guid teamId, CancellationToken ct, int status)
    {
        var lobby = await svc.GetLobbyAsync(userId, teamId, ct);
        return lobby.IsOk ? Results.Json(lobby.Value, statusCode: status) : lobby.Error!.ToResult();
    }
}
