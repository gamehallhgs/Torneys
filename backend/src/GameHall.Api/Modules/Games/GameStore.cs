using Dapper;
using GameHall.Api.Modules.Tournaments;
using Npgsql;

namespace GameHall.Api.Modules.Games;

/// <summary>SQL de leitura dos jogos, classificação e estatísticas. Rascunhos nunca são públicos.</summary>
public sealed class GameStore(NpgsqlDataSource db)
{
    private const string GameSelect =
        """
        SELECT g.id, g.tournament_id, t.name AS tournament_name, g.stage, g.group_name, g.round_number,
               g.round_label, g.match_number, g.scheduled_at, g.field_name, g.status,
               g.home_team_id, h.name AS home_name, h.color_hex AS home_color,
               g.away_team_id, a.name AS away_name, a.color_hex AS away_color,
               g.home_goals, g.away_goals, g.home_penalties, g.away_penalties,
               (SELECT count(*)::int FROM game_highlights x WHERE x.game_id = g.id) AS highlights_count
        FROM games g
        JOIN tournaments t ON t.id = g.tournament_id AND t.status <> 'draft'
        LEFT JOIN teams h ON h.id = g.home_team_id
        LEFT JOIN teams a ON a.id = g.away_team_id
        """;

    public async Task<IReadOnlyList<GameRow>> ListGamesAsync(Guid tournamentId, string? status, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<GameRow>(new CommandDefinition(
            $"""
            {GameSelect}
            WHERE g.tournament_id = @T AND (@Status::text IS NULL OR g.status = @Status::text)
            ORDER BY g.scheduled_at NULLS LAST, g.round_number, g.match_number
            """,
            new { T = tournamentId, Status = status }, cancellationToken: ct))).ToList();
    }

    public async Task<GameRow?> FindGameAsync(Guid gameId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<GameRow>(new CommandDefinition(
            $"{GameSelect} WHERE g.id = @Id", new { Id = gameId }, cancellationToken: ct));
    }

    public async Task<IReadOnlyList<EventRow>> EventsAsync(Guid gameId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<EventRow>(new CommandDefinition(
            """
            SELECT id, team_id, player_name, type, minute
            FROM game_events WHERE game_id = @Id
            ORDER BY minute NULLS LAST, created_at, id
            """,
            new { Id = gameId }, cancellationToken: ct))).ToList();
    }

    public async Task<IReadOnlyList<HighlightRow>> HighlightsAsync(Guid gameId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<HighlightRow>(new CommandDefinition(
            "SELECT id, url, title, duration_seconds FROM game_highlights WHERE game_id = @Id ORDER BY created_at, id",
            new { Id = gameId }, cancellationToken: ct))).ToList();
    }

    /// <summary>Dados para a classificação: equipas, jogos de grupo/liga e cartões desses jogos.</summary>
    public async Task<(IReadOnlyList<StandingTeam> Teams, IReadOnlyList<StandingsGameRow> Games,
        IReadOnlyDictionary<Guid, (int Yellow, int Red)> Cards)> StandingsDataAsync(Guid tournamentId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);

        var teams = (await conn.QueryAsync<TeamRow>(new CommandDefinition(
            "SELECT id, name, color_hex FROM teams WHERE tournament_id = @T",
            new { T = tournamentId }, cancellationToken: ct)))
            .Select(t => new StandingTeam(t.Id, t.Name, t.ColorHex)).ToList();

        var games = (await conn.QueryAsync<StandingsGameRow>(new CommandDefinition(
            """
            SELECT home_team_id, away_team_id, home_goals, away_goals, status, group_name
            FROM games WHERE tournament_id = @T AND stage IN ('group', 'league')
            """,
            new { T = tournamentId }, cancellationToken: ct))).ToList();

        var counts = await conn.QueryAsync<CardCountRow>(new CommandDefinition(
            """
            SELECT e.team_id, e.type, count(*)::int AS total
            FROM game_events e
            JOIN games g ON g.id = e.game_id
            WHERE g.tournament_id = @T AND g.stage IN ('group', 'league') AND g.status = 'finished'
              AND e.type IN ('yellow_card', 'red_card')
            GROUP BY e.team_id, e.type
            """,
            new { T = tournamentId }, cancellationToken: ct));

        var cards = new Dictionary<Guid, (int Yellow, int Red)>();
        foreach (var c in counts)
        {
            cards.TryGetValue(c.TeamId, out var current);
            cards[c.TeamId] = c.Type == GameRules.Yellow
                ? (c.Total, current.Red)
                : (current.Yellow, c.Total);
        }

        return (teams, games, cards);
    }

    /// <summary>Melhores marcadores/assistentes/cartões. Jogos a decorrer e terminados contam.</summary>
    public async Task<IReadOnlyList<StatLineRow>> TopAsync(Guid tournamentId, string type, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<StatLineRow>(new CommandDefinition(
            """
            SELECT max(e.player_name) AS player_name, e.team_id, t.name AS team_name, t.color_hex, count(*)::int AS total
            FROM game_events e
            JOIN games g ON g.id = e.game_id
            JOIN teams t ON t.id = e.team_id
            WHERE g.tournament_id = @T AND g.status IN ('running', 'finished') AND e.type = @Type
            GROUP BY coalesce(e.user_id::text, 'n:' || e.team_id::text || ':' || e.player_name),
                     e.team_id, t.name, t.color_hex
            ORDER BY total DESC, player_name
            LIMIT @Limit
            """,
            new { T = tournamentId, Type = type, Limit = GameRules.StatsTopN },
            cancellationToken: ct))).ToList();
    }
}
