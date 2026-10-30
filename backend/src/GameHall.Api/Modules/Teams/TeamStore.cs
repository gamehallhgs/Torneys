using System.Data;
using Dapper;
using Npgsql;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// SQL das equipas. Os métodos estáticos recebem a ligação (e a transação, se houver) para poderem
/// ser combinados dentro da mesma transação. Sem regras de negócio: essas estão no TeamService.
/// </summary>
public sealed class TeamStore(NpgsqlDataSource db)
{
    public Task<NpgsqlConnection> OpenAsync(CancellationToken ct) => db.OpenConnectionAsync(ct).AsTask();

    /// <summary>Corre o trabalho numa transação. Faz sempre commit (os erros de regra devolvem-se antes de escrever).</summary>
    public async Task<T> InTransactionAsync<T>(
        Func<NpgsqlConnection, NpgsqlTransaction, Task<T>> work, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var result = await work(conn, tx);
        await tx.CommitAsync(ct);
        return result;
    }

    // ---------- Leitura ----------

    /// <summary>Torneio (bloqueado para escrita) com o nº de equipas. Rascunhos não contam.</summary>
    public static Task<TournamentGateRow?> GateAsync(IDbConnection c, IDbTransaction tx, Guid tournamentId) =>
        c.QuerySingleOrDefaultAsync<TournamentGateRow>(
            """
            SELECT t.id, t.status, t.min_age, t.max_age, t.gender, t.max_teams,
                   (SELECT count(*)::int FROM teams x WHERE x.tournament_id = t.id AND x.confirmed_at IS NOT NULL) AS teams_confirmed
            FROM tournaments t
            WHERE t.id = @Id AND t.status <> 'draft'
            FOR UPDATE OF t
            """,
            new { Id = tournamentId }, tx);

    public static Task<TeamInfoRow?> TeamAsync(IDbConnection c, IDbTransaction? tx, Guid teamId, bool lockRow) =>
        c.QuerySingleOrDefaultAsync<TeamInfoRow>(
            $"""
            SELECT t.id, t.tournament_id, t.name, t.color_hex, t.host_user_id, t.is_demo, t.confirmed_at,
                   t.is_private, t.members_can_invite, tr.sport, tr.rules_text, t.formation, t.invite_code, t.invite_code_enabled, t.code_direct_entry, t.members_see_code,
                   t.closed_at, t.payment_mode, t.share_cents, t.reserved_at, t.reservation_expires_at,
                   tr.entry_fee_cents,
                   tr.name AS tournament_name, tr.status AS tournament_status, tr.min_age, tr.max_age, tr.gender,
                   tr.min_players_per_team, tr.max_players_per_team, tr.registration_closes_at, tr.max_teams,
                   (SELECT count(*)::int FROM teams x WHERE x.tournament_id = tr.id AND x.confirmed_at IS NOT NULL) AS teams_confirmed,
                   (SELECT count(*)::int FROM teams x WHERE x.tournament_id = tr.id AND x.reserved_at IS NOT NULL) AS teams_reserved
            FROM teams t
            JOIN tournaments tr ON tr.id = t.tournament_id
            WHERE t.id = @Id AND tr.status <> 'draft'
            {(lockRow ? "FOR UPDATE OF t" : "")}
            """,
            new { Id = teamId }, tx);

    public static Task<Guid?> MyTeamIdAsync(IDbConnection c, IDbTransaction? tx, Guid tournamentId, Guid userId) =>
        c.QuerySingleOrDefaultAsync<Guid?>(
            "SELECT team_id FROM team_members WHERE tournament_id = @T AND user_id = @U",
            new { T = tournamentId, U = userId }, tx);

    public static Task<int> CountMembersAsync(IDbConnection c, IDbTransaction? tx, Guid teamId) =>
        c.ExecuteScalarAsync<int>(
            "SELECT count(*)::int FROM team_members WHERE team_id = @T", new { T = teamId }, tx);

    public static async Task<IReadOnlyList<MemberRow>> MembersAsync(IDbConnection c, IDbTransaction? tx, Guid teamId) =>
        (await c.QueryAsync<MemberRow>(
            """
            SELECT m.user_id, u.display_name, u.username, m.position, m.joined_at, (m.paid_at IS NOT NULL) AS paid, m.ready, m.slot
            FROM team_members m JOIN users u ON u.id = m.user_id
            WHERE m.team_id = @T
            ORDER BY m.joined_at, u.display_name
            """,
            new { T = teamId }, tx)).ToList();

    public static async Task<IReadOnlyList<PendingRow>> PendingRequestsAsync(IDbConnection c, Guid teamId) =>
        (await c.QueryAsync<PendingRow>(
            """
            SELECT r.id, r.user_id, u.display_name, u.username, r.created_at
            FROM join_requests r JOIN users u ON u.id = r.user_id
            WHERE r.team_id = @T AND r.status = 'pending'
            ORDER BY r.created_at
            """,
            new { T = teamId })).ToList();

    public static async Task<IReadOnlyList<PendingRow>> PendingInvitesAsync(IDbConnection c, Guid teamId) =>
        (await c.QueryAsync<PendingRow>(
            """
            SELECT i.id, i.invited_user_id AS user_id, u.display_name, u.username, i.created_at
            FROM team_invites i JOIN users u ON u.id = i.invited_user_id
            WHERE i.team_id = @T AND i.status = 'pending'
            ORDER BY i.created_at
            """,
            new { T = teamId })).ToList();

    public static Task<int> CountPendingInvitesAsync(IDbConnection c, IDbTransaction tx, Guid teamId) =>
        c.ExecuteScalarAsync<int>(
            "SELECT count(*)::int FROM team_invites WHERE team_id = @T AND status = 'pending'",
            new { T = teamId }, tx);

    public static Task<Guid?> PendingRequestIdAsync(IDbConnection c, Guid teamId, Guid userId) =>
        c.QuerySingleOrDefaultAsync<Guid?>(
            "SELECT id FROM join_requests WHERE team_id = @T AND user_id = @U AND status = 'pending'",
            new { T = teamId, U = userId });

    public static Task<Guid?> PendingInviteIdAsync(IDbConnection c, Guid teamId, Guid userId) =>
        c.QuerySingleOrDefaultAsync<Guid?>(
            "SELECT id FROM team_invites WHERE team_id = @T AND invited_user_id = @U AND status = 'pending'",
            new { T = teamId, U = userId });

    public static Task<RequestRow?> RequestAsync(IDbConnection c, IDbTransaction? tx, Guid requestId) =>
        c.QuerySingleOrDefaultAsync<RequestRow>(
            "SELECT id, team_id, tournament_id, user_id, status FROM join_requests WHERE id = @Id",
            new { Id = requestId }, tx);

    public static Task<InviteRow?> InviteAsync(IDbConnection c, IDbTransaction? tx, Guid inviteId) =>
        c.QuerySingleOrDefaultAsync<InviteRow>(
            "SELECT id, team_id, tournament_id, invited_user_id, invited_by, status FROM team_invites WHERE id = @Id",
            new { Id = inviteId }, tx);

    // ---------- Escrita ----------

    public static Task<int> InsertTeamAsync(
        IDbConnection c, IDbTransaction tx, Guid id, Guid tournamentId, string name, string colorHex, Guid hostId) =>
        c.ExecuteAsync(
            """
            INSERT INTO teams (id, tournament_id, name, color_hex, host_user_id)
            VALUES (@Id, @T, @Name, @Color, @Host)
            """,
            new { Id = id, T = tournamentId, Name = name, Color = colorHex, Host = hostId }, tx);

    public static Task<int> InsertMemberAsync(
        IDbConnection c, IDbTransaction tx, Guid teamId, Guid tournamentId, Guid userId) =>
        c.ExecuteAsync(
            "INSERT INTO team_members (team_id, tournament_id, user_id) VALUES (@Team, @T, @U)",
            new { Team = teamId, T = tournamentId, U = userId }, tx);

    /// <summary>Devolve 1 se criou, 0 se já existia um pedido pendente.</summary>
    public static Task<int> InsertRequestAsync(
        IDbConnection c, IDbTransaction tx, Guid id, Guid teamId, Guid tournamentId, Guid userId) =>
        c.ExecuteAsync(
            """
            INSERT INTO join_requests (id, team_id, tournament_id, user_id)
            VALUES (@Id, @Team, @T, @U)
            ON CONFLICT DO NOTHING
            """,
            new { Id = id, Team = teamId, T = tournamentId, U = userId }, tx);

    /// <summary>Devolve 1 se criou, 0 se já existia um convite pendente.</summary>
    public static Task<int> InsertInviteAsync(
        IDbConnection c, IDbTransaction tx, Guid id, Guid teamId, Guid tournamentId, Guid invitedUserId, Guid invitedBy) =>
        c.ExecuteAsync(
            """
            INSERT INTO team_invites (id, team_id, tournament_id, invited_user_id, invited_by)
            VALUES (@Id, @Team, @T, @Invited, @By)
            ON CONFLICT DO NOTHING
            """,
            new { Id = id, Team = teamId, T = tournamentId, Invited = invitedUserId, By = invitedBy }, tx);

    public static Task<int> SetRequestStatusAsync(IDbConnection c, IDbTransaction tx, Guid id, string status) =>
        c.ExecuteAsync(
            "UPDATE join_requests SET status = @S, decided_at = now() WHERE id = @Id",
            new { Id = id, S = status }, tx);

    public static Task<int> SetInviteStatusAsync(IDbConnection c, IDbTransaction tx, Guid id, string status) =>
        c.ExecuteAsync(
            "UPDATE team_invites SET status = @S, decided_at = now() WHERE id = @Id",
            new { Id = id, S = status }, tx);

    /// <summary>Quando um jogador entra numa equipa, os outros pedidos e convites dele nesse torneio caducam.</summary>
    public static async Task CancelOtherPendingAsync(IDbConnection c, IDbTransaction tx, Guid tournamentId, Guid userId)
    {
        await c.ExecuteAsync(
            """
            UPDATE join_requests SET status = 'cancelled', decided_at = now()
            WHERE tournament_id = @T AND user_id = @U AND status = 'pending'
            """,
            new { T = tournamentId, U = userId }, tx);
        await c.ExecuteAsync(
            """
            UPDATE team_invites SET status = 'cancelled', decided_at = now()
            WHERE tournament_id = @T AND invited_user_id = @U AND status = 'pending'
            """,
            new { T = tournamentId, U = userId }, tx);
    }

    public static Task<int> SetPositionAsync(
        IDbConnection c, IDbTransaction tx, Guid teamId, Guid userId, string position) =>
        c.ExecuteAsync(
            "UPDATE team_members SET position = @P WHERE team_id = @T AND user_id = @U",
            new { T = teamId, U = userId, P = position }, tx);

    public static Task<int> SetHostAsync(IDbConnection c, IDbTransaction tx, Guid teamId, Guid newHostId) =>
        c.ExecuteAsync(
            "UPDATE teams SET host_user_id = @H WHERE id = @T",
            new { T = teamId, H = newHostId }, tx);

    public static Task<int> DeleteMemberAsync(IDbConnection c, IDbTransaction tx, Guid teamId, Guid userId) =>
        c.ExecuteAsync(
            "DELETE FROM team_members WHERE team_id = @T AND user_id = @U",
            new { T = teamId, U = userId }, tx);

    /// <summary>Guarda a formação e os lugares (quem não vem na lista fica suplente).</summary>
    public static async Task SetLineupAsync(
        IDbConnection c, IDbTransaction tx, Guid teamId, string formation, IReadOnlyList<(Guid UserId, int Slot)> slots)
    {
        await c.ExecuteAsync("UPDATE teams SET formation = @F WHERE id = @T", new { F = formation, T = teamId }, tx);
        await c.ExecuteAsync("UPDATE team_members SET slot = NULL WHERE team_id = @T", new { T = teamId }, tx);
        foreach (var (userId, slot) in slots)
        {
            await c.ExecuteAsync(
                "UPDATE team_members SET slot = @S WHERE team_id = @T AND user_id = @U",
                new { S = slot, T = teamId, U = userId }, tx);
        }
    }

    public static Task<int> DeleteTeamAsync(IDbConnection c, IDbTransaction tx, Guid teamId) =>
        c.ExecuteAsync("DELETE FROM teams WHERE id = @T", new { T = teamId }, tx);

    // ---------- Listas do utilizador ----------

    public async Task<IReadOnlyList<MyTeamRow>> MyTeamsAsync(Guid userId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<MyTeamRow>(new CommandDefinition(
            """
            SELECT t.id AS team_id, t.name, t.color_hex, tr.id AS tournament_id, tr.name AS tournament_name,
                   tr.status AS tournament_status, (t.host_user_id = @U) AS is_host,
                   (SELECT count(*)::int FROM team_members x WHERE x.team_id = t.id) AS members_count,
                   tr.min_players_per_team, tr.max_players_per_team,
                   t.closed_at, t.reserved_at, t.confirmed_at, t.reservation_expires_at,
                   CASE WHEN t.host_user_id = @U
                        THEN (SELECT count(*)::int FROM join_requests r WHERE r.team_id = t.id AND r.status = 'pending')
                        ELSE 0 END AS pending_requests
            FROM team_members m
            JOIN teams t ON t.id = m.team_id
            JOIN tournaments tr ON tr.id = t.tournament_id
            WHERE m.user_id = @U
            ORDER BY tr.starts_on DESC, t.name
            """,
            new { U = userId }, cancellationToken: ct))).ToList();
    }

    public async Task<IReadOnlyList<MyInviteRow>> MyInvitesAsync(Guid userId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<MyInviteRow>(new CommandDefinition(
            """
            SELECT i.id, t.id AS team_id, t.name AS team_name, t.color_hex, tr.id AS tournament_id,
                   tr.name AS tournament_name, u.display_name AS invited_by_name, i.created_at
            FROM team_invites i
            JOIN teams t ON t.id = i.team_id
            JOIN tournaments tr ON tr.id = i.tournament_id
            JOIN users u ON u.id = i.invited_by
            WHERE i.invited_user_id = @U AND i.status = 'pending' AND tr.status = 'registration_open'
            ORDER BY i.created_at DESC
            """,
            new { U = userId }, cancellationToken: ct))).ToList();
    }

    public async Task<IReadOnlyList<MyRequestRow>> MyRequestsAsync(Guid userId, CancellationToken ct)
    {
        await using var c = await db.OpenConnectionAsync(ct);
        return (await c.QueryAsync<MyRequestRow>(new CommandDefinition(
            """
            SELECT r.id, t.id AS team_id, t.name AS team_name, t.color_hex, tr.id AS tournament_id,
                   tr.name AS tournament_name, r.created_at
            FROM join_requests r
            JOIN teams t ON t.id = r.team_id
            JOIN tournaments tr ON tr.id = r.tournament_id
            WHERE r.user_id = @U AND r.status = 'pending' AND tr.status = 'registration_open'
            ORDER BY r.created_at DESC
            """,
            new { U = userId }, cancellationToken: ct))).ToList();
    }

    public static Task<int> UpdateSettingsAsync(
        IDbConnection c, IDbTransaction tx, Guid teamId, bool isPrivate, bool membersCanInvite,
        bool codeEnabled, bool codeDirectEntry, bool membersSeeCode) =>
        c.ExecuteAsync(
            """
            UPDATE teams
            SET is_private = @Private, members_can_invite = @Members,
                invite_code_enabled = @CodeEnabled, code_direct_entry = @Direct, members_see_code = @SeeCode
            WHERE id = @Id
            """,
            new
            {
                Id = teamId, Private = isPrivate, Members = membersCanInvite,
                CodeEnabled = codeEnabled, Direct = codeDirectEntry, SeeCode = membersSeeCode
            }, tx);

    // ---------- Código de convite ----------

    public static Task<Guid?> TeamIdByCodeAsync(IDbConnection c, IDbTransaction? tx, string code) =>
        c.QuerySingleOrDefaultAsync<Guid?>("SELECT id FROM teams WHERE invite_code = @Code", new { Code = code }, tx);

    /// <summary>Quantos códigos novos já foram gerados desde [since] e quando foi o mais antigo.</summary>
    public static async Task<(int Count, DateTime? Oldest)> CodeRegensAsync(
        IDbConnection c, IDbTransaction? tx, Guid teamId, DateTime since)
    {
        var row = await c.QuerySingleAsync<(int Count, DateTime? Oldest)>(
            "SELECT count(*)::int AS count, min(created_at) AS oldest FROM team_code_regens WHERE team_id = @T AND created_at > @Since",
            new { T = teamId, Since = since }, tx);
        return row;
    }

    /// <summary>Gera um código novo (o antigo deixa de funcionar) e regista a geração. Devolve o código novo.</summary>
    public static async Task<string> RegenerateCodeAsync(IDbConnection c, IDbTransaction tx, Guid teamId, DateTime now)
    {
        await c.ExecuteAsync(
            "INSERT INTO team_code_regens (team_id, created_at) VALUES (@T, @Now)", new { T = teamId, Now = now }, tx);
        await c.ExecuteAsync(
            "DELETE FROM team_code_regens WHERE team_id = @T AND created_at < @Old", new { T = teamId, Old = now.AddDays(-1) }, tx);
        return await c.QuerySingleAsync<string>(
            "UPDATE teams SET invite_code = gh_new_invite_code() WHERE id = @T RETURNING invite_code", new { T = teamId }, tx);
    }

    // ---------- Preparado, fecho, pagamento, penalização ----------

    public static Task<int> SetReadyAsync(IDbConnection c, IDbTransaction tx, Guid teamId, Guid userId, bool ready) =>
        c.ExecuteAsync(
            "UPDATE team_members SET ready = @R WHERE team_id = @T AND user_id = @U",
            new { T = teamId, U = userId, R = ready }, tx);

    /// <summary>Fecha a equipa (entra na fila). Os pedidos e convites pendentes deixam de fazer sentido.</summary>
    public static async Task CloseTeamAsync(
        IDbConnection c, IDbTransaction tx, Guid teamId, string mode, int shareCents, DateTime now)
    {
        await c.ExecuteAsync(
            "UPDATE teams SET closed_at = @Now, payment_mode = @Mode, share_cents = @Share WHERE id = @Id",
            new { Id = teamId, Now = now, Mode = mode, Share = shareCents }, tx);
        await c.ExecuteAsync(
            "UPDATE join_requests SET status = 'cancelled', decided_at = now() WHERE team_id = @Id AND status = 'pending'",
            new { Id = teamId }, tx);
        await c.ExecuteAsync(
            "UPDATE team_invites SET status = 'cancelled', decided_at = now() WHERE team_id = @Id AND status = 'pending'",
            new { Id = teamId }, tx);
    }

    /// <summary>Marca como pago (saldo reservado). userId nulo = todos os membros (pagamento total do líder).</summary>
    public static Task<int> MarkPaidAsync(IDbConnection c, IDbTransaction tx, Guid teamId, Guid? userId, DateTime now) =>
        c.ExecuteAsync(
            "UPDATE team_members SET paid_at = @Now WHERE team_id = @T AND paid_at IS NULL AND (@U::uuid IS NULL OR user_id = @U::uuid)",
            new { T = teamId, U = userId, Now = now }, tx);

    public static Task<int> CountPaidAsync(IDbConnection c, IDbTransaction? tx, Guid teamId) =>
        c.ExecuteScalarAsync<int>(
            "SELECT count(*)::int FROM team_members WHERE team_id = @T AND paid_at IS NOT NULL", new { T = teamId }, tx);

    public static Task<int> ConfirmTeamAsync(IDbConnection c, IDbTransaction tx, Guid teamId, DateTime now) =>
        c.ExecuteAsync("UPDATE teams SET confirmed_at = @Now WHERE id = @T", new { T = teamId, Now = now }, tx);

    public static Task<DateTime?> PenaltyUntilAsync(
        IDbConnection c, IDbTransaction? tx, Guid tournamentId, Guid userId, DateTime now) =>
        c.QuerySingleOrDefaultAsync<DateTime?>(
            "SELECT until_at FROM reservation_penalties WHERE tournament_id = @T AND user_id = @U AND until_at > @Now",
            new { T = tournamentId, U = userId, Now = now }, tx);

    /// <summary>Ids dos membros da equipa que ainda estão penalizados.</summary>
    public static async Task<HashSet<Guid>> PenalizedMemberIdsAsync(
        IDbConnection c, IDbTransaction? tx, Guid teamId, DateTime now) =>
        (await c.QueryAsync<Guid>(
            """
            SELECT m.user_id
            FROM team_members m
            JOIN reservation_penalties p ON p.user_id = m.user_id AND p.tournament_id = m.tournament_id
            WHERE m.team_id = @T AND p.until_at > @Now
            """,
            new { T = teamId, Now = now }, tx)).ToHashSet();

    /// <summary>Nomes dos membros da equipa que ainda estão penalizados.</summary>
    public static async Task<IReadOnlyList<string>> PenalizedMembersAsync(
        IDbConnection c, IDbTransaction? tx, Guid teamId, DateTime now) =>
        (await c.QueryAsync<string>(
            """
            SELECT u.display_name
            FROM team_members m
            JOIN users u ON u.id = m.user_id
            JOIN reservation_penalties p ON p.user_id = m.user_id AND p.tournament_id = m.tournament_id
            WHERE m.team_id = @T AND p.until_at > @Now
            ORDER BY u.display_name
            """,
            new { T = teamId, Now = now }, tx)).ToList();

    /// <summary>Posição na fila (1 = a próxima a receber vaga), para equipas fechadas sem vaga.</summary>
    public static async Task<int?> QueuePositionAsync(IDbConnection c, IDbTransaction? tx, Guid tournamentId, Guid teamId)
    {
        var queue = (await c.QueryAsync<QueuedTeam>(
            """
            SELECT id AS team_id, closed_at, created_at
            FROM teams
            WHERE tournament_id = @T AND closed_at IS NOT NULL AND reserved_at IS NULL
            """,
            new { T = tournamentId }, tx)).ToList();
        return ReservationRules.QueuePosition(queue, teamId);
    }
}
