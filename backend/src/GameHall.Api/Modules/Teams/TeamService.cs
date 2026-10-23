using GameHall.Api.Common;
using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Tournaments;
using Npgsql;

namespace GameHall.Api.Modules.Teams;

internal static class TeamErrors
{
    public static readonly ApiError TeamNotFound = new(404, "team_not_found", "Equipa não encontrada.");
    public static readonly ApiError TournamentNotFound = new(404, "tournament_not_found", "Torneio não encontrado.");
    public static readonly ApiError RequestNotFound = new(404, "request_not_found", "Pedido não encontrado.");
    public static readonly ApiError InviteNotFound = new(404, "invite_not_found", "Convite não encontrado.");
    public static readonly ApiError NotHost = new(403, "not_team_host", "Só o líder da equipa pode fazer isto.");
    public static readonly ApiError NotMember = new(403, "not_team_member", "Não pertences a esta equipa.");
    public static readonly ApiError AlreadyInTeam = new(409, "already_in_team", "Já pertences a uma equipa neste torneio.");
    public static readonly ApiError TeamFull = new(409, "team_full", "A equipa já está completa.");
    public static readonly ApiError TeamNotJoinable = new(409, "team_not_joinable", "Não é possível pedir para entrar nesta equipa.");
    public static readonly ApiError RegistrationClosed = new(409, "registration_closed", "As inscrições deste torneio não estão abertas.");
    public static readonly ApiError NotPending = new(409, "not_pending", "Este pedido já foi tratado.");
    public static readonly ApiError NameTaken = new(409, "team_name_taken", "Já existe uma equipa com esse nome neste torneio.");
    public static readonly ApiError ColorTaken = new(409, "team_color_taken", "Já existe uma equipa com essa cor neste torneio.");
    public static readonly ApiError HostMustTransfer = new(409, "host_must_transfer", "Transfere o cargo de líder antes de saíres da equipa.");
    public static readonly ApiError TooManyInvites = new(409, "too_many_invites", "Há demasiados convites pendentes. Cancela alguns primeiro.");
    public static readonly ApiError AgeTooYoung = new(403, "age_too_young", "Não cumpres a idade mínima deste torneio.");
    public static readonly ApiError AgeTooOld = new(403, "age_too_old", "Excedes a idade máxima deste torneio.");
    public static readonly ApiError TournamentFull = new(409, "tournament_full", "O torneio já tem todas as equipas confirmadas.");
    public static readonly ApiError LobbyClosed = new(409, "lobby_closed", "O líder fechou este lobby: só se entra por convite.");
    public static readonly ApiError InviteNotAllowed = new(403, "invite_not_allowed", "Nesta equipa só o líder pode convidar.");
    public static readonly ApiError TeamConfirmed = new(409, "team_confirmed", "A equipa já está confirmada e fechada.");

    public static ApiError InvalidPosition { get; } = ApiError.Validation(
        new Dictionary<string, string[]> { ["position"] = ["Posição inválida."] });

    public static ApiError FromReason(string reason) => reason switch
    {
        "registration_closed" => RegistrationClosed,
        "age_too_young" => AgeTooYoung,
        "age_too_old" => AgeTooOld,
        "tournament_full" => TournamentFull,
        "team_confirmed" => TeamConfirmed,
        _ => RegistrationClosed
    };
}

/// <summary>Regras de negócio das equipas, pedidos, convites, líder e posições.</summary>
public sealed class TeamService(
    TeamStore store,
    AuthStore users,
    IEmailSender email,
    TimeProvider clock,
    ILogger<TeamService> log)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    // ======================= Criar equipa =======================

    public async Task<Outcome<Guid>> CreateTeamAsync(
        Guid userId, Guid tournamentId, CreateTeamRequest req, CancellationToken ct)
    {
        var name = TeamRules.NormalizeName(req.Name);
        var color = TeamRules.NormalizeColor(req.ColorHex);
        var fields = new Dictionary<string, string[]>();
        var nameProblem = TeamRules.ValidateName(name);
        if (nameProblem is not null)
        {
            fields["name"] = [nameProblem];
        }

        if (color is null)
        {
            fields["colorHex"] = ["Escolhe uma cor válida."];
        }

        if (fields.Count > 0)
        {
            return Outcome<Guid>.Fail(ApiError.Validation(fields));
        }

        var age = await AgeOfAsync(userId, ct);
        if (age is null)
        {
            return Outcome<Guid>.Fail(Errors.UserNotFound);
        }

        return await store.InTransactionAsync(async (c, tx) =>
        {
            var gate = await TeamStore.GateAsync(c, tx, tournamentId);
            if (gate is null)
            {
                return Outcome<Guid>.Fail(TeamErrors.TournamentNotFound);
            }

            var reason = TournamentRules.WhyCannotCreateTeam(
                gate.Status, gate.TeamsConfirmed, gate.MaxTeams, gate.MinAge, gate.MaxAge, age.Value);
            if (reason is not null)
            {
                return Outcome<Guid>.Fail(TeamErrors.FromReason(reason));
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, tournamentId, userId) is not null)
            {
                return Outcome<Guid>.Fail(TeamErrors.AlreadyInTeam);
            }

            var teamId = Guid.NewGuid();
            try
            {
                await TeamStore.InsertTeamAsync(c, tx, teamId, tournamentId, name, color!, userId);
            }
            catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                return Outcome<Guid>.Fail(ex.ConstraintName == "ux_teams_tournament_color"
                    ? TeamErrors.ColorTaken
                    : TeamErrors.NameTaken);
            }

            await TeamStore.InsertMemberAsync(c, tx, teamId, tournamentId, userId);
            await TeamStore.CancelOtherPendingAsync(c, tx, tournamentId, userId);
            return Outcome<Guid>.Ok(teamId);
        }, ct);
    }

    // ======================= Lobby =======================

    public async Task<Outcome<TeamLobbyDto>> GetLobbyAsync(Guid userId, Guid teamId, CancellationToken ct)
    {
        var age = await AgeOfAsync(userId, ct);
        if (age is null)
        {
            return Outcome<TeamLobbyDto>.Fail(Errors.UserNotFound);
        }

        await using var c = await store.OpenAsync(ct);
        var team = await TeamStore.TeamAsync(c, null, teamId, false);
        if (team is null)
        {
            return Outcome<TeamLobbyDto>.Fail(TeamErrors.TeamNotFound);
        }

        var members = await TeamStore.MembersAsync(c, null, teamId);
        var isMember = members.Any(m => m.UserId == userId);
        var isHost = team.HostUserId == userId;
        var myTeamId = await TeamStore.MyTeamIdAsync(c, null, team.TournamentId, userId);
        var pendingRequestId = await TeamStore.PendingRequestIdAsync(c, teamId, userId);
        var pendingInviteId = await TeamStore.PendingInviteIdAsync(c, teamId, userId);

        var blocked = TeamRules.JoinBlockedReason(
            team.HostUserId is not null, isMember, team.TournamentStatus,
            myTeamId is not null && myTeamId != teamId,
            team.MinAge, team.MaxAge, age.Value, members.Count, team.MaxPlayersPerTeam,
            pendingRequestId is not null,
            team.ConfirmedAt is not null,
            team.ClosedToRequests);

        IReadOnlyList<PendingDto> requests = [];
        IReadOnlyList<PendingDto> invites = [];
        if (isHost)
        {
            requests = (await TeamStore.PendingRequestsAsync(c, teamId))
                .Select(r => new PendingDto(r.Id, r.UserId, r.DisplayName, r.CreatedAt)).ToList();
            invites = (await TeamStore.PendingInvitesAsync(c, teamId))
                .Select(r => new PendingDto(r.Id, r.UserId, r.DisplayName, r.CreatedAt)).ToList();
        }

        // Quem participa no torneio pode ver os membros e as posições de qualquer equipa; os pagamentos só os membros.
        IReadOnlyList<MemberDto> memberDtos = members.Select(m => new MemberDto(
            m.UserId, m.DisplayName, m.Position, m.UserId == team.HostUserId, m.UserId == userId,
            isMember ? m.Paid : null)).ToList();

        return Outcome<TeamLobbyDto>.Ok(new TeamLobbyDto(
            new TeamHeaderDto(
                team.Id, team.Name, team.ColorHex, team.IsDemo, team.ConfirmedAt is not null,
                team.ClosedToRequests, team.MembersCanInvite),
            new TeamTournamentDto(
                team.TournamentId, team.TournamentName, team.TournamentStatus,
                team.MinPlayersPerTeam, team.MaxPlayersPerTeam, team.RegistrationClosesAt,
                team.TeamsConfirmed, team.MaxTeams),
            members.Count,
            memberDtos,
            isMember ? members.Count(m => m.Position is null) : 0,
            requests,
            invites,
            new TeamMeDto(
                isMember, isHost, pendingRequestId, pendingInviteId, myTeamId, blocked is null, blocked,
                TeamRules.CanInvite(isHost, isMember, team.MembersCanInvite) &&
                team.ConfirmedAt is null && team.TournamentStatus == "registration_open")));
    }

    // ======================= Pedidos para entrar =======================

    public async Task<ApiError?> RequestJoinAsync(Guid userId, Guid teamId, CancellationToken ct)
    {
        var age = await AgeOfAsync(userId, ct);
        if (age is null)
        {
            return Errors.UserNotFound;
        }

        var inserted = false;
        TeamInfoRow? teamInfo = null;
        var error = await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId is null)
            {
                return TeamErrors.TeamNotJoinable;
            }

            var reason = TournamentRules.WhyCannotParticipate(team.TournamentStatus, team.MinAge, team.MaxAge, age.Value);
            if (reason is not null)
            {
                return TeamErrors.FromReason(reason);
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, userId) is not null)
            {
                return TeamErrors.AlreadyInTeam;
            }

            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamConfirmed;
            }

            if (await TeamStore.CountMembersAsync(c, tx, teamId) >= team.MaxPlayersPerTeam)
            {
                return TeamErrors.TeamFull;
            }

            if (team.ClosedToRequests)
            {
                return TeamErrors.LobbyClosed;
            }

            inserted = await TeamStore.InsertRequestAsync(c, tx, Guid.NewGuid(), teamId, team.TournamentId, userId) == 1;
            teamInfo = team;
            return null;
        }, ct);

        if (error is null && inserted && teamInfo is { HostUserId: not null } t)
        {
            var player = await users.FindUserByIdAsync(userId, ct);
            await NotifyAsync(t.HostUserId.Value, (hostName) =>
                TeamEmails.JoinRequest(hostName, player?.DisplayName ?? "Um jogador", t.Name, t.TournamentName), ct);
        }

        return error;
    }

    public async Task<ApiError?> CancelRequestAsync(Guid userId, Guid requestId, CancellationToken ct) =>
        await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var req = await TeamStore.RequestAsync(c, tx, requestId);
            if (req is null || req.UserId != userId)
            {
                return TeamErrors.RequestNotFound;
            }

            if (req.Status != "pending")
            {
                return TeamErrors.NotPending;
            }

            await TeamStore.SetRequestStatusAsync(c, tx, requestId, "cancelled");
            return null;
        }, ct);

    public async Task<ApiError?> DecideRequestAsync(Guid hostId, Guid requestId, bool accept, CancellationToken ct)
    {
        Guid? teamId;
        await using (var c0 = await store.OpenAsync(ct))
        {
            teamId = (await TeamStore.RequestAsync(c0, null, requestId))?.TeamId;
        }

        if (teamId is null)
        {
            return TeamErrors.RequestNotFound;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            // Bloqueia a equipa primeiro (mesma ordem em todas as operações: evita deadlocks).
            var team = await TeamStore.TeamAsync(c, tx, teamId.Value, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            var req = await TeamStore.RequestAsync(c, tx, requestId);
            if (req is null || req.TeamId != team.Id)
            {
                return TeamErrors.RequestNotFound;
            }

            if (req.Status != "pending")
            {
                return TeamErrors.NotPending;
            }

            if (!accept)
            {
                await TeamStore.SetRequestStatusAsync(c, tx, requestId, "rejected");
                return null;
            }

            if (team.TournamentStatus != "registration_open")
            {
                return TeamErrors.RegistrationClosed;
            }

            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamConfirmed;
            }

            if (await TeamStore.CountMembersAsync(c, tx, team.Id) >= team.MaxPlayersPerTeam)
            {
                return TeamErrors.TeamFull;
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, req.UserId) is not null)
            {
                // O jogador entretanto entrou noutra equipa: o pedido já não faz sentido.
                await TeamStore.SetRequestStatusAsync(c, tx, requestId, "cancelled");
                return TeamErrors.AlreadyInTeam;
            }

            await TeamStore.InsertMemberAsync(c, tx, team.Id, team.TournamentId, req.UserId);
            await TeamStore.SetRequestStatusAsync(c, tx, requestId, "accepted");
            await TeamStore.CancelOtherPendingAsync(c, tx, team.TournamentId, req.UserId);
            return null;
        }, ct);
    }

    // ======================= Convites =======================

    /// <summary>
    /// Convida um utilizador pelo email. A resposta é igual exista a conta ou não (não revela quem está registado).
    /// </summary>
    public async Task<ApiError?> InviteAsync(Guid inviterId, Guid teamId, string? emailInput, CancellationToken ct)
    {
        var normalized = AuthValidation.NormalizeEmail(emailInput);
        if (normalized is null || !normalized.Contains('@'))
        {
            return ApiError.Validation(new Dictionary<string, string[]> { ["email"] = ["Email inválido."] });
        }

        var invitee = await users.FindUserByEmailAsync(normalized, ct);
        var inviter = await users.FindUserByIdAsync(inviterId, ct);
        var inserted = false;
        TeamInfoRow? teamInfo = null;

        var error = await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            var inviterIsMember = team.HostUserId == inviterId ||
                await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, inviterId) == teamId;
            if (!inviterIsMember)
            {
                return TeamErrors.NotMember;
            }

            if (!TeamRules.CanInvite(team.HostUserId == inviterId, true, team.MembersCanInvite))
            {
                return TeamErrors.InviteNotAllowed;
            }

            if (team.TournamentStatus != "registration_open")
            {
                return TeamErrors.RegistrationClosed;
            }

            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamConfirmed;
            }

            if (await TeamStore.CountMembersAsync(c, tx, teamId) >= team.MaxPlayersPerTeam)
            {
                return TeamErrors.TeamFull;
            }

            if (await TeamStore.CountPendingInvitesAsync(c, tx, teamId) >= TeamRules.MaxPendingInvitesPerTeam)
            {
                return TeamErrors.TooManyInvites;
            }

            // Conta inexistente, não verificada, o próprio líder ou já numa equipa: resposta igual, sem convite.
            if (invitee is null || invitee.EmailVerifiedAt is null || invitee.Id == inviterId ||
                await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, invitee.Id) is not null)
            {
                return null;
            }

            inserted = await TeamStore.InsertInviteAsync(
                c, tx, Guid.NewGuid(), teamId, team.TournamentId, invitee.Id, inviterId) == 1;
            teamInfo = team;
            return null;
        }, ct);

        if (error is null && inserted && invitee is not null && teamInfo is { } t)
        {
            await NotifyAsync(invitee.Id, (name) =>
                TeamEmails.Invite(name, inviter?.DisplayName ?? "Um colega", t.Name, t.TournamentName), ct);
        }

        return error;
    }

    public async Task<ApiError?> RespondInviteAsync(Guid userId, Guid inviteId, bool accept, CancellationToken ct)
    {
        Guid? teamId;
        await using (var c0 = await store.OpenAsync(ct))
        {
            var invite = await TeamStore.InviteAsync(c0, null, inviteId);
            teamId = invite is not null && invite.InvitedUserId == userId ? invite.TeamId : null;
        }

        if (teamId is null)
        {
            return TeamErrors.InviteNotFound;
        }

        var age = await AgeOfAsync(userId, ct);
        if (age is null)
        {
            return Errors.UserNotFound;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId.Value, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            var invite = await TeamStore.InviteAsync(c, tx, inviteId);
            if (invite is null || invite.InvitedUserId != userId)
            {
                return TeamErrors.InviteNotFound;
            }

            if (invite.Status != "pending")
            {
                return TeamErrors.NotPending;
            }

            if (!accept)
            {
                await TeamStore.SetInviteStatusAsync(c, tx, inviteId, "declined");
                return null;
            }

            var reason = TournamentRules.WhyCannotParticipate(team.TournamentStatus, team.MinAge, team.MaxAge, age.Value);
            if (reason is not null)
            {
                return TeamErrors.FromReason(reason);
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, userId) is not null)
            {
                return TeamErrors.AlreadyInTeam;
            }

            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamConfirmed;
            }

            if (await TeamStore.CountMembersAsync(c, tx, team.Id) >= team.MaxPlayersPerTeam)
            {
                return TeamErrors.TeamFull;
            }

            await TeamStore.InsertMemberAsync(c, tx, team.Id, team.TournamentId, userId);
            await TeamStore.SetInviteStatusAsync(c, tx, inviteId, "accepted");
            await TeamStore.CancelOtherPendingAsync(c, tx, team.TournamentId, userId);
            return null;
        }, ct);
    }

    public async Task<ApiError?> CancelInviteAsync(Guid hostId, Guid inviteId, CancellationToken ct)
    {
        Guid? teamId;
        await using (var c0 = await store.OpenAsync(ct))
        {
            teamId = (await TeamStore.InviteAsync(c0, null, inviteId))?.TeamId;
        }

        if (teamId is null)
        {
            return TeamErrors.InviteNotFound;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId.Value, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            var invite = await TeamStore.InviteAsync(c, tx, inviteId);
            if (invite is null || invite.TeamId != team.Id)
            {
                return TeamErrors.InviteNotFound;
            }

            if (invite.Status != "pending")
            {
                return TeamErrors.NotPending;
            }

            await TeamStore.SetInviteStatusAsync(c, tx, inviteId, "cancelled");
            return null;
        }, ct);
    }

    // ======================= Definições do lobby =======================

    /// <summary>Só o líder, a qualquer momento (mesmo com a equipa confirmada). Só muda os campos enviados.</summary>
    public async Task<ApiError?> UpdateSettingsAsync(
        Guid hostId, Guid teamId, UpdateTeamSettingsRequest req, CancellationToken ct)
    {
        if (req.ClosedToRequests is null && req.MembersCanInvite is null)
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["settings"] = ["Indica pelo menos uma definição (closedToRequests ou membersCanInvite)."]
            });
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            await TeamStore.UpdateSettingsAsync(
                c, tx, teamId,
                req.ClosedToRequests ?? team.ClosedToRequests,
                req.MembersCanInvite ?? team.MembersCanInvite);
            return null;
        }, ct);
    }

    // ======================= Membros: posição, líder, sair, remover =======================

    public async Task<ApiError?> SetPositionAsync(Guid userId, Guid teamId, string? position, CancellationToken ct)
    {
        if (!TeamRules.IsValidPosition(position))
        {
            return TeamErrors.InvalidPosition;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.TournamentStatus is not ("registration_open" or "registration_closed"))
            {
                return TeamErrors.RegistrationClosed;
            }

            var updated = await TeamStore.SetPositionAsync(c, tx, teamId, userId, position!);
            return updated == 0 ? TeamErrors.NotMember : null;
        }, ct);
    }

    public async Task<ApiError?> TransferHostAsync(Guid hostId, Guid teamId, Guid? newHostId, CancellationToken ct)
    {
        if (newHostId is null)
        {
            return ApiError.Validation(new Dictionary<string, string[]> { ["userId"] = ["Escolhe o novo líder."] });
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            if (team.TournamentStatus is not ("registration_open" or "registration_closed"))
            {
                return TeamErrors.RegistrationClosed;
            }

            var members = await TeamStore.MembersAsync(c, tx, teamId);
            if (newHostId == hostId || members.All(m => m.UserId != newHostId))
            {
                return TeamErrors.NotMember;
            }

            await TeamStore.SetHostAsync(c, tx, teamId, newHostId.Value);
            return null;
        }, ct);
    }

    public async Task<ApiError?> LeaveAsync(Guid userId, Guid teamId, CancellationToken ct) =>
        await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamConfirmed;
            }

            var members = await TeamStore.MembersAsync(c, tx, teamId);
            if (members.All(m => m.UserId != userId))
            {
                return TeamErrors.NotMember;
            }

            if (team.TournamentStatus != "registration_open")
            {
                return TeamErrors.RegistrationClosed;
            }

            if (team.HostUserId == userId)
            {
                if (members.Count > 1)
                {
                    return TeamErrors.HostMustTransfer;
                }

                // Último membro: a equipa deixa de existir.
                await TeamStore.DeleteTeamAsync(c, tx, teamId);
                return null;
            }

            await TeamStore.DeleteMemberAsync(c, tx, teamId, userId);
            return null;
        }, ct);

    public async Task<ApiError?> RemoveMemberAsync(Guid hostId, Guid teamId, Guid memberId, CancellationToken ct) =>
        await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamConfirmed;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            if (team.TournamentStatus != "registration_open")
            {
                return TeamErrors.RegistrationClosed;
            }

            if (memberId == hostId)
            {
                return TeamErrors.HostMustTransfer;
            }

            var removed = await TeamStore.DeleteMemberAsync(c, tx, teamId, memberId);
            return removed == 0 ? TeamErrors.NotMember : null;
        }, ct);

    // ======================= Listas =======================

    public async Task<IReadOnlyList<MyTeamDto>> MyTeamsAsync(Guid userId, CancellationToken ct) =>
        (await store.MyTeamsAsync(userId, ct)).Select(r => new MyTeamDto(
            r.TeamId, r.Name, r.ColorHex, r.TournamentId, r.TournamentName, r.TournamentStatus,
            r.IsHost, r.MembersCount, r.MinPlayersPerTeam, r.MaxPlayersPerTeam, r.PendingRequests)).ToList();

    public async Task<IReadOnlyList<MyInviteDto>> MyInvitesAsync(Guid userId, CancellationToken ct) =>
        (await store.MyInvitesAsync(userId, ct)).Select(r => new MyInviteDto(
            r.Id, r.TeamId, r.TeamName, r.ColorHex, r.TournamentId, r.TournamentName,
            r.InvitedByName, r.CreatedAt)).ToList();

    public async Task<IReadOnlyList<MyRequestDto>> MyRequestsAsync(Guid userId, CancellationToken ct) =>
        (await store.MyRequestsAsync(userId, ct)).Select(r => new MyRequestDto(
            r.Id, r.TeamId, r.TeamName, r.ColorHex, r.TournamentId, r.TournamentName, r.CreatedAt)).ToList();

    // ======================= Auxiliares =======================

    private async Task<int?> AgeOfAsync(Guid userId, CancellationToken ct)
    {
        var user = await users.FindUserByIdAsync(userId, ct);
        return user is null ? null : AgeCalculator.AgeOn(user.BirthDate, DateOnly.FromDateTime(Now));
    }

    /// <summary>Envia um email de aviso. Nunca falha o pedido: se o email não sair, só fica no registo.</summary>
    private async Task NotifyAsync(
        Guid userId, Func<string, (string Subject, string Body)> template, CancellationToken ct)
    {
        try
        {
            var user = await users.FindUserByIdAsync(userId, ct);
            if (user is null)
            {
                return;
            }

            var (subject, body) = template(user.DisplayName);
            await email.SendAsync(user.Email, subject, body, ct);
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Não foi possível enviar o email de aviso a {UserId}", userId);
        }
    }
}
