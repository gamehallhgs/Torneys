using GameHall.Api.Common;

namespace GameHall.Api.Modules.Voting;

/// <summary>
/// Pódio, prémios e votação de um torneio terminado (utilizadores normais). Sem política explícita:
/// aplica-se a política por defeito (sessão iniciada + termos em dia). Abrir votações é do gestor (mais tarde).
/// </summary>
public static class VotingEndpoints
{
    public static void MapVotingEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/v1/tournaments/{tournamentId:guid}/results", async (
            Guid tournamentId, HttpContext ctx, VotingService svc, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var r = await svc.GetResultsAsync(tournamentId, uid, ct);
            return r.IsOk ? Results.Ok(r.Value) : r.Error!.ToResult();
        });

        app.MapPut("/api/v1/tournaments/{tournamentId:guid}/voting/votes", async (
            Guid tournamentId, CastVoteRequest req, HttpContext ctx, VotingService svc, CancellationToken ct) =>
        {
            if (ctx.UserId() is not { } uid)
            {
                return Results.Unauthorized();
            }

            var error = await svc.VoteAsync(tournamentId, uid, req.Category, req.CandidateUserId, ct);
            return error is null ? Results.NoContent() : error.ToResult();
        }).RequireRateLimiting("auth");
    }
}
