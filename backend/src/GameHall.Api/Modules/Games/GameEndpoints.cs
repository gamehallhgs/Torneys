using GameHall.Api.Common;
using GameHall.Api.Modules.Tournaments;

namespace GameHall.Api.Modules.Games;

/// <summary>
/// Jogos, classificação e estatísticas (só leitura, para utilizadores normais). Sem política explícita:
/// aplica-se a política por defeito (sessão iniciada + termos em dia). O quadro de eliminatórias
/// constrói-se na app a partir da lista de jogos (stage, roundNumber, roundLabel).
/// </summary>
public static class GameEndpoints
{
    private static readonly ApiError TournamentNotFound =
        new(StatusCodes.Status404NotFound, "tournament_not_found", "Torneio não encontrado.");

    private static readonly ApiError GameNotFound =
        new(StatusCodes.Status404NotFound, "game_not_found", "Jogo não encontrado.");

    public static void MapGameEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/v1/tournaments/{tournamentId:guid}/games", async (
            Guid tournamentId, string? status, TournamentStore tournaments, GameStore games, CancellationToken ct) =>
        {
            if (status is not null && !GameRules.IsValidStatus(status))
            {
                return ApiError.Validation(new Dictionary<string, string[]>
                {
                    ["status"] = ["Estado inválido."]
                }).ToResult();
            }

            if (await tournaments.FindAsync(tournamentId, ct) is null)
            {
                return TournamentNotFound.ToResult();
            }

            var rows = await games.ListGamesAsync(tournamentId, status, ct);
            return Results.Ok(rows.Select(ToDto).ToList());
        });

        app.MapGet("/api/v1/games/{gameId:guid}", async (Guid gameId, GameStore games, CancellationToken ct) =>
        {
            var row = await games.FindGameAsync(gameId, ct);
            if (row is null)
            {
                return GameNotFound.ToResult();
            }

            var events = await games.EventsAsync(gameId, ct);
            var highlights = await games.HighlightsAsync(gameId, ct);
            return Results.Ok(new GameDetailDto(
                ToDto(row),
                row.TournamentId,
                row.TournamentName,
                events.Select(e => new GameEventDto(e.Id, e.TeamId, e.PlayerName, e.Type, e.Minute)).ToList(),
                highlights.Select(h => new HighlightDto(h.Id, h.Url, h.Title, h.DurationSeconds)).ToList()));
        });

        app.MapGet("/api/v1/tournaments/{tournamentId:guid}/standings", async (
            Guid tournamentId, TournamentStore tournaments, GameStore games, CancellationToken ct) =>
        {
            var tournament = await tournaments.FindAsync(tournamentId, ct);
            if (tournament is null)
            {
                return TournamentNotFound.ToResult();
            }

            var (teams, rows, cards) = await games.StandingsDataAsync(tournamentId, ct);
            var groups = StandingsCalculator.BuildGroups(tournament.Format, teams, rows, cards, tournament.Tiebreakers);
            return Results.Ok(new StandingsDto(tournament.Tiebreakers, groups));
        });

        app.MapGet("/api/v1/tournaments/{tournamentId:guid}/stats", async (
            Guid tournamentId, TournamentStore tournaments, GameStore games, CancellationToken ct) =>
        {
            if (await tournaments.FindAsync(tournamentId, ct) is null)
            {
                return TournamentNotFound.ToResult();
            }

            var scorers = await games.TopAsync(tournamentId, GameRules.Goal, ct);
            var assists = await games.TopAsync(tournamentId, GameRules.Assist, ct);
            var yellow = await games.TopAsync(tournamentId, GameRules.Yellow, ct);
            var red = await games.TopAsync(tournamentId, GameRules.Red, ct);
            return Results.Ok(new StatsDto(ToLines(scorers), ToLines(assists), ToLines(yellow), ToLines(red)));
        });
    }

    private static List<StatLineDto> ToLines(IEnumerable<StatLineRow> rows) =>
        rows.Select(r => new StatLineDto(r.PlayerName, r.TeamId, r.TeamName, r.ColorHex, r.Total)).ToList();

    private static GameDto ToDto(GameRow g) => new(
        g.Id, g.Stage, g.GroupName, g.RoundNumber, g.RoundLabel, g.MatchNumber, g.ScheduledAt, g.FieldName,
        g.Status,
        new GameTeamDto(g.HomeTeamId, g.HomeName, g.HomeColor),
        new GameTeamDto(g.AwayTeamId, g.AwayName, g.AwayColor),
        g.HomeGoals, g.AwayGoals, g.HomePenalties, g.AwayPenalties, g.HighlightsCount);
}
