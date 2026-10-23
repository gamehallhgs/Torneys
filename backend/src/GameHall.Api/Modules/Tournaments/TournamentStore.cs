using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Tournaments;

/// <summary>Acesso à base de dados dos torneios (SQL explícito).</summary>
public sealed class TournamentStore(NpgsqlDataSource db)
{
    // Colunas comuns + nº de equipas. Os nomes batem com TournamentRow (snake_case -> PascalCase).
    private const string SelectColumns =
        """
        t.id, t.name, t.description, t.organizer_name, t.sport, t.format, t.has_third_place, t.tiebreakers,
        t.status, t.registration_opens_at, t.registration_closes_at, t.starts_on, t.ends_on,
        t.location_name, t.district, t.municipality, t.location_address, t.entry_fee_cents, t.min_age, t.max_age, t.max_teams,
        t.min_players_per_team, t.max_players_per_team,
        (SELECT count(*)::int FROM teams x WHERE x.tournament_id = t.id) AS teams_registered,
        (SELECT count(*)::int FROM teams x WHERE x.tournament_id = t.id AND x.confirmed_at IS NOT NULL) AS teams_confirmed
        """;

    // Filtros da lista. Os "::tipo" evitam erros do Npgsql quando o valor é NULL.
    private const string WhereClause =
        """
        t.status = ANY(@Statuses)
        AND (@From::date IS NULL OR t.ends_on >= @From::date)
        AND (@To::date   IS NULL OR t.starts_on <= @To::date)
        AND (@Sport::text IS NULL OR t.sport = @Sport::text)
        AND (@District::text IS NULL OR t.district = @District::text)
        AND (@Municipality::text IS NULL OR t.municipality = @Municipality::text)
        AND (@MemberOf::uuid IS NULL OR EXISTS (
              SELECT 1 FROM team_members m WHERE m.tournament_id = t.id AND m.user_id = @MemberOf::uuid))
        """;

    /// <summary>
    /// "open" -> inscrições abertas; "ongoing" -> inscrições fechadas ou a decorrer; "finished" -> terminados;
    /// "mine" (e sem filtro) -> todos os estados públicos (o "mine" restringe-se depois aos torneios do utilizador).
    /// </summary>
    public static string[] StatusesFor(string? filter) => filter switch
    {
        "open" => ["registration_open"],
        "ongoing" => ["registration_closed", "ongoing"],
        "finished" => ["finished"],
        _ => ["registration_open", "registration_closed", "ongoing", "finished"]
    };

    public async Task<(IReadOnlyList<TournamentRow> Items, int Total)> ListAsync(TournamentFilter f, CancellationToken ct)
    {
        var args = new
        {
            Statuses = StatusesFor(f.Status),
            From = f.From,
            To = f.To,
            f.Sport,
            f.District,
            f.Municipality,
            f.MemberOf,
            Limit = f.PageSize,
            Offset = (f.Page - 1) * f.PageSize
        };

        // Terminados: mais recentes primeiro. Os outros: o que começa primeiro aparece primeiro.
        // Os meus torneios: os que ainda não terminaram primeiro.
        var order = f.Status switch
        {
            "finished" => "t.ends_on DESC, t.name",
            "mine" => "(t.status = 'finished'), t.starts_on ASC, t.name",
            _ => "t.starts_on ASC, t.name"
        };

        await using var conn = await db.OpenConnectionAsync(ct);

        var total = await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            $"SELECT count(*)::int FROM tournaments t WHERE {WhereClause}", args, cancellationToken: ct));

        var rows = (await conn.QueryAsync<TournamentRow>(new CommandDefinition(
            $"SELECT {SelectColumns} FROM tournaments t WHERE {WhereClause} ORDER BY {order} LIMIT @Limit OFFSET @Offset",
            args, cancellationToken: ct))).ToList();

        return (rows, total);
    }

    public async Task<TournamentRow?> FindAsync(Guid id, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        // Rascunhos não são públicos.
        return await conn.QuerySingleOrDefaultAsync<TournamentRow>(new CommandDefinition(
            $"SELECT {SelectColumns} FROM tournaments t WHERE t.id = @Id AND t.status <> 'draft'",
            new { Id = id }, cancellationToken: ct));
    }

    public async Task<IReadOnlyList<TeamRow>> ListTeamsAsync(Guid tournamentId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<TeamRow>(new CommandDefinition(
            "SELECT id, name, color_hex, (confirmed_at IS NOT NULL) AS confirmed FROM teams WHERE tournament_id = @Id ORDER BY (confirmed_at IS NULL), lower(name)",
            new { Id = tournamentId }, cancellationToken: ct))).ToList();
    }

    /// <summary>Equipa do utilizador neste torneio (se tiver), com o nº de membros.</summary>
    public async Task<MyTeamBriefRow?> FindMyTeamAsync(Guid tournamentId, Guid userId, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<MyTeamBriefRow>(new CommandDefinition(
            """
            SELECT tm.id, tm.name, tm.color_hex, (tm.host_user_id = @U) AS is_host, (tm.confirmed_at IS NOT NULL) AS confirmed,
                   (SELECT count(*)::int FROM team_members x WHERE x.team_id = tm.id) AS members_count
            FROM team_members m
            JOIN teams tm ON tm.id = m.team_id
            WHERE m.tournament_id = @T AND m.user_id = @U
            """,
            new { T = tournamentId, U = userId }, cancellationToken: ct));
    }
}
