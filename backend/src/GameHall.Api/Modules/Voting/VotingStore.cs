using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Voting;

/// <summary>SQL da votação. A escrita das rondas e dos votos passa por aqui (os outros módulos não mexem nestas tabelas).</summary>
public sealed class VotingStore(NpgsqlDataSource db)
{
    public NpgsqlDataSource Db => db;

    public async Task<int> SettingAsync(string key, int fallback, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        var raw = await c.ExecuteScalarAsync<string?>(new CommandDefinition(
            "SELECT value FROM platform_settings WHERE key = @Key", new { Key = key }, cancellationToken: ct));
        return int.TryParse(raw, out var v) ? v : fallback;
    }

    public async Task<IReadOnlyList<RoundRow>> RoundsAsync(Guid tournamentId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<RoundRow>(new CommandDefinition(
            "SELECT id, round_number, opened_at, closes_at FROM voting_rounds WHERE tournament_id = @T ORDER BY round_number",
            new { T = tournamentId }, cancellationToken: ct))).ToList();
    }

    public async Task<IReadOnlyList<TallyRow>> TalliesAsync(Guid tournamentId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        // Inclui candidatos sem votos (0), para a lista de empatados e as contagens ficarem completas.
        return (await c.QueryAsync<TallyRow>(new CommandDefinition(
            """
            SELECT cd.round_id, cd.category, cd.user_id AS candidate_id, count(v.voter_id)::int AS votes
            FROM voting_candidates cd
            JOIN voting_rounds r ON r.id = cd.round_id
            LEFT JOIN votes v ON v.round_id = cd.round_id AND v.category = cd.category AND v.candidate_id = cd.user_id
            WHERE r.tournament_id = @T
            GROUP BY cd.round_id, cd.category, cd.user_id
            """,
            new { T = tournamentId }, cancellationToken: ct))).ToList();
    }

    public async Task<IReadOnlyList<CandidateRow>> CandidatesAsync(Guid roundId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<CandidateRow>(new CommandDefinition(
            """
            SELECT cd.category, cd.user_id, u.display_name, m.position, cd.team_id, t.name AS team_name, t.color_hex
            FROM voting_candidates cd
            JOIN users u ON u.id = cd.user_id
            JOIN teams t ON t.id = cd.team_id
            LEFT JOIN team_members m ON m.team_id = cd.team_id AND m.user_id = cd.user_id
            WHERE cd.round_id = @R
            ORDER BY t.name, u.display_name
            """,
            new { R = roundId }, cancellationToken: ct))).ToList();
    }

    public async Task<IReadOnlyList<MyVoteRow>> MyVotesAsync(Guid roundId, Guid userId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<MyVoteRow>(new CommandDefinition(
            "SELECT category, candidate_id FROM votes WHERE round_id = @R AND voter_id = @U",
            new { R = roundId, U = userId }, cancellationToken: ct))).ToList();
    }

    /// <summary>Jogador de uma equipa confirmada deste torneio?</summary>
    public async Task<bool> IsParticipantAsync(Guid tournamentId, Guid userId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return await c.ExecuteScalarAsync<bool>(new CommandDefinition(
            """
            SELECT EXISTS (SELECT 1 FROM team_members m JOIN teams t ON t.id = m.team_id
                           WHERE m.tournament_id = @T AND m.user_id = @U AND t.confirmed_at IS NOT NULL)
            """,
            new { T = tournamentId, U = userId }, cancellationToken: ct));
    }

    public async Task<bool> IsCandidateAsync(Guid roundId, string category, Guid userId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return await c.ExecuteScalarAsync<bool>(new CommandDefinition(
            "SELECT EXISTS (SELECT 1 FROM voting_candidates WHERE round_id = @R AND category = @C AND user_id = @U)",
            new { R = roundId, C = category, U = userId }, cancellationToken: ct));
    }

    public async Task UpsertVoteAsync(Guid roundId, string category, Guid voterId, Guid candidateId, DateTime now, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        await c.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO votes (round_id, category, voter_id, candidate_id, created_at, updated_at)
            VALUES (@R, @C, @V, @K, @Now, @Now)
            ON CONFLICT (round_id, category, voter_id) DO UPDATE SET candidate_id = @K, updated_at = @Now
            """,
            new { R = roundId, C = category, V = voterId, K = candidateId, Now = now }, cancellationToken: ct));
    }

    public async Task<IReadOnlyList<WinnerRow>> WinnersAsync(Guid tournamentId, IReadOnlyCollection<Guid> userIds, CancellationToken ct)
    {
        if (userIds.Count == 0)
        {
            return [];
        }

        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<WinnerRow>(new CommandDefinition(
            """
            SELECT u.id AS user_id, u.display_name, m.position, t.id AS team_id, t.name AS team_name, t.color_hex
            FROM team_members m
            JOIN users u ON u.id = m.user_id
            JOIN teams t ON t.id = m.team_id
            WHERE m.tournament_id = @T AND m.user_id = ANY(@Ids)
            ORDER BY t.name, u.display_name
            """,
            new { T = tournamentId, Ids = userIds.ToArray() }, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// Abre uma ronda (para o painel do gestor). Ronda 1: candidatos = todos os membros das equipas confirmadas
    /// (melhor jogador) e os guarda-redes (melhor guarda-redes). Ronda 2: [tied] = categoria -> empatados.
    /// </summary>
    public async Task<Guid> OpenRoundAsync(
        Guid tournamentId, int roundNumber, DateTime openedAt, DateTime closesAt,
        IReadOnlyDictionary<string, IReadOnlyList<Guid>>? tied, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        await using var tx = await c.BeginTransactionAsync(ct);
        var id = Guid.NewGuid();
        await c.ExecuteAsync(new CommandDefinition(
            "INSERT INTO voting_rounds (id, tournament_id, round_number, opened_at, closes_at) VALUES (@Id, @T, @N, @O, @C)",
            new { Id = id, T = tournamentId, N = roundNumber, O = openedAt, C = closesAt }, tx, cancellationToken: ct));

        if (tied is null)
        {
            await c.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO voting_candidates (round_id, category, user_id, team_id)
                SELECT @Id, cat.category, m.user_id, m.team_id
                FROM team_members m
                JOIN teams t ON t.id = m.team_id AND t.confirmed_at IS NOT NULL
                CROSS JOIN (VALUES ('best_player'), ('best_goalkeeper')) AS cat(category)
                WHERE m.tournament_id = @T AND (cat.category = 'best_player' OR m.position = 'GK')
                """,
                new { Id = id, T = tournamentId }, tx, cancellationToken: ct));
        }
        else
        {
            foreach (var (category, users) in tied)
            {
                await c.ExecuteAsync(new CommandDefinition(
                    """
                    INSERT INTO voting_candidates (round_id, category, user_id, team_id)
                    SELECT @Id, @Cat, m.user_id, m.team_id FROM team_members m
                    WHERE m.tournament_id = @T AND m.user_id = ANY(@Ids)
                    """,
                    new { Id = id, Cat = category, T = tournamentId, Ids = users.ToArray() }, tx, cancellationToken: ct));
            }
        }

        await tx.CommitAsync(ct);
        return id;
    }
}
