using GameHall.Api.Common;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Geo;

namespace GameHall.Api.Modules.Tournaments;

/// <summary>
/// Torneios (leitura, para utilizadores normais). Sem política explícita: aplica-se a política por
/// defeito (sessão iniciada + termos em dia).
/// </summary>
public static class TournamentEndpoints
{
    private static readonly string[] StatusFilters = ["open", "ongoing", "finished", "mine"];

    public static void MapTournamentEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/v1/tournaments");

        g.MapGet("", async (
            string? status, DateOnly? from, DateOnly? to, string? sport, string? district, string? municipality,
            int? page, int? pageSize,
            HttpContext ctx, TournamentStore store, CancellationToken ct) =>
        {
            var fields = new Dictionary<string, string[]>();
            if (status is not null && !StatusFilters.Contains(status))
            {
                fields["status"] = ["Estado inválido. Usa: open, ongoing, finished ou mine."];
            }

            if (sport is not null && !TournamentRules.Sports.Contains(sport))
            {
                fields["sport"] = ["Modalidade inválida."];
            }

            district = string.IsNullOrWhiteSpace(district) ? null : district.Trim();
            municipality = string.IsNullOrWhiteSpace(municipality) ? null : municipality.Trim();
            if (district is not null && !PortugalGeo.IsDistrict(district))
            {
                fields["district"] = ["Distrito inválido."];
            }
            else if (municipality is not null && !PortugalGeo.IsMunicipality(district, municipality))
            {
                fields["municipality"] = [district is null
                    ? "Indica o distrito do concelho."
                    : "Concelho inválido para este distrito."];
            }

            if (from is not null && to is not null && to < from)
            {
                fields["to"] = ["A data final não pode ser anterior à inicial."];
            }

            if (fields.Count > 0)
            {
                return ApiError.Validation(fields).ToResult();
            }

            // "mine": só os torneios em que o utilizador está numa equipa.
            Guid? memberOf = null;
            if (status == "mine")
            {
                memberOf = ctx.UserId();
                if (memberOf is null)
                {
                    return Results.Unauthorized();
                }
            }

            var p = Math.Max(page ?? 1, 1);
            var size = Math.Clamp(pageSize ?? 20, 1, 50);
            var (rows, total) = await store.ListAsync(
                new TournamentFilter(status, from, to, sport, p, size, memberOf, district, municipality), ct);

            return Results.Ok(new TournamentPageDto(rows.Select(ToSummary).ToList(), total, p, size));
        });

        g.MapGet("/{id:guid}", async (
            Guid id, HttpContext ctx, TournamentStore store, AuthStore users, TimeProvider clock, CancellationToken ct) =>
        {
            var row = await store.FindAsync(id, ct);
            if (row is null)
            {
                return NotFound.ToResult();
            }

            var userId = ctx.UserId();
            var user = userId is null ? null : await users.FindUserByIdAsync(userId.Value, ct);
            if (user is null)
            {
                return Results.Unauthorized();
            }

            var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
            var age = AgeCalculator.AgeOn(user.BirthDate, today);
            var reason = TournamentRules.WhyCannotCreateTeam(
                row.Status, row.TeamsConfirmed, row.MaxTeams, row.MinAge, row.MaxAge, age);

            var teams = await store.ListTeamsAsync(id, ct);
            var myTeam = await store.FindMyTeamAsync(id, user.Id, ct);

            return Results.Ok(new TournamentDetailDto(
                ToSummary(row),
                row.Description,
                row.HasThirdPlace,
                row.Tiebreakers,
                row.LocationAddress,
                row.RegistrationOpensAt,
                row.MinPlayersPerTeam,
                row.MaxPlayersPerTeam,
                teams.Select(t => new TeamDto(t.Id, t.Name, t.ColorHex, t.Confirmed)).ToList(),
                new EligibilityDto(reason is null, reason),
                myTeam?.Id,
                myTeam is null
                    ? null
                    : new MyTeamBriefDto(myTeam.Id, myTeam.Name, myTeam.ColorHex, myTeam.IsHost, myTeam.MembersCount, myTeam.Confirmed)));
        });
    }

    private static readonly ApiError NotFound =
        new(StatusCodes.Status404NotFound, "tournament_not_found", "Torneio não encontrado.");

    private static TournamentSummaryDto ToSummary(TournamentRow r) => new(
        r.Id, r.Name, r.OrganizerName, r.Sport, r.Format, r.Status, r.StartsOn, r.EndsOn,
        r.LocationName, r.District, r.Municipality, r.EntryFeeCents, r.TeamsRegistered, r.MaxTeams, r.MinAge, r.MaxAge,
        TournamentRules.AgeLabel(r.MinAge, r.MaxAge), r.RegistrationClosesAt,
        r.TeamsConfirmed, r.TeamsConfirmed >= r.MaxTeams);
}
