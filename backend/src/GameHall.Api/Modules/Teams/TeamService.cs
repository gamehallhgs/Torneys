using GameHall.Api.Common;
using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Notifications;
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
    public static readonly ApiError GenderNotAllowed = new(
        403, "gender_not_allowed", "Este torneio não está aberto ao teu género.");
    public static readonly ApiError AgeTooOld = new(403, "age_too_old", "Excedes a idade máxima deste torneio.");
    public static readonly ApiError TournamentFull = new(409, "tournament_full", "O torneio está lotado: todas as vagas estão confirmadas.");
    public static readonly ApiError UserNotFound = new(404, "user_not_found", "Este utilizador não se encontra na app.");
    public static readonly ApiError TooManyFailedLookups = new(
        429, "too_many_failed_lookups", "Demasiadas tentativas falhadas a procurar jogadores. Tenta novamente daqui a uma hora.");
    public static readonly ApiError InviteCodeInvalid = new(404, "invite_code_invalid", "Código inválido ou já não está ativo.");
    public static readonly ApiError InviteCodeDisabled = new(404, "invite_code_invalid", "Código inválido ou já não está ativo.");
    public static ApiError CodeRegenLimit(int minutes) => new(
        429, "invite_code_regen_limit",
        $"Só podes gerar 3 códigos por hora. Podes gerar outro daqui a {minutes} minuto(s).");
    public static readonly ApiError CannotInviteSelf = new(409, "cannot_invite_self", "Não te podes convidar a ti próprio.");
    public static ApiError InviteeAlreadyInTeam(string displayName) => new(
        409, "invitee_already_in_team", $"O jogador {displayName} já se encontra numa equipa do mesmo torneio.");
    public static readonly ApiError LobbyPrivate = new(409, "lobby_private", "Esta equipa é privada: só se entra por convite.");
    public static readonly ApiError InviteNotAllowed = new(403, "invite_not_allowed", "Nesta equipa só o líder pode convidar.");
    public static readonly ApiError TeamConfirmed = new(409, "team_confirmed", "A equipa já está confirmada e fechada.");
    public static readonly ApiError TeamClosed = new(
        409, "team_closed", "A equipa está fechada: ninguém entra nem sai. O líder pode reabri-la enquanto a vaga não estiver confirmada.");
    public static readonly ApiError TeamLocked = new(
        409, "team_confirmed_locked", "A vaga já está confirmada: a equipa não pode desistir do torneio.");
    public static readonly ApiError ReopenAfterDeadline = new(
        409, "reopen_after_deadline",
        "As inscrições já terminaram: não podes reabrir a equipa. Podes desistir (eliminar a equipa).");
    public static readonly ApiError SettingsLocked = new(
        409, "team_confirmed_locked", "A vaga já está confirmada: as definições do lobby já não se alteram.");
    public static ApiError PlayerPenalized(int minutesLeft) => new(
        409, "player_penalized",
        $"Estás penalizado por não teres pago a tempo: podes voltar a entrar numa equipa deste torneio daqui a {minutesLeft} minuto(s).");
    public static ApiError InviteePenalized(string? displayName) => new(
        409, "player_penalized",
        displayName is null
            ? "Este jogador está penalizado por não ter pago a tempo e ainda não pode entrar numa equipa."
            : $"O jogador {displayName} está penalizado por não ter pago a tempo e ainda não pode entrar numa equipa.");
    public static readonly ApiError TeamNotClosed = new(409, "team_not_closed", "A equipa ainda não foi fechada pelo líder.");
    public static readonly ApiError InvalidPaymentMode = ApiError.Validation(
        new Dictionary<string, string[]> { ["paymentMode"] = ["Escolhe pagamento dividido ou total."] });
    public static readonly ApiError InvalidReady = ApiError.Validation(
        new Dictionary<string, string[]> { ["ready"] = ["Indica se estás preparado (true ou false)."] });

    /// <summary>Erro certo para quem tenta mexer numa equipa fechada.</summary>
    public static ApiError ClosedFor(TeamInfoRow team) => team.ConfirmedAt is not null ? TeamConfirmed : TeamClosed;

    /// <summary>Mensagem (em português) do motivo pelo qual o líder ainda não pode fechar a equipa.</summary>
    public static string CloseMessage(string reason, int minPlayers, int notReady, IReadOnlyList<string> penalized) => reason switch
    {
        "registration_closed" => "As inscrições deste torneio não estão abertas.",
        "team_closed" => "A equipa já está fechada.",
        "below_min_players" => $"A equipa precisa de pelo menos {minPlayers} jogadores para fechar.",
        "members_not_ready" => notReady == 1
            ? "Falta 1 jogador marcar-se como preparado."
            : $"Faltam {notReady} jogadores marcarem-se como preparados.",
        "members_penalized" => penalized.Count == 1
            ? $"{penalized[0]} está penalizado e ainda não pode reservar vaga."
            : $"{string.Join(", ", penalized)} estão penalizados e ainda não podem reservar vaga.",
        _ => "Não é possível fechar a equipa."
    };

    public static ApiError CloseBlocked(string reason, int minPlayers, int notReady, IReadOnlyList<string> penalized) =>
        reason switch
        {
            "registration_closed" => RegistrationClosed,
            "team_closed" => TeamClosed,
            _ => new ApiError(409, reason, CloseMessage(reason, minPlayers, notReady, penalized))
        };

    public static ApiError PayBlocked(string reason) => reason switch
    {
        "team_not_closed" => TeamNotClosed,
        "team_in_queue" => new ApiError(409, "team_in_queue", "A tua equipa está na fila: ainda não há vaga reservada para pagar."),
        "team_confirmed" => new ApiError(409, "team_confirmed", "A vaga já está confirmada: não há mais nada a pagar."),
        "reservation_expired" => new ApiError(409, "reservation_expired", "O tempo para pagar terminou: a equipa voltou à formação."),
        "only_host_pays" => new ApiError(403, "only_host_pays", "Neste modo só o líder paga, por toda a equipa."),
        "already_paid" => new ApiError(409, "already_paid", "Já pagaste a tua parte."),
        _ => new ApiError(409, reason, "Não é possível pagar agora.")
    };

    public static ApiError InvalidPosition { get; } = ApiError.Validation(
        new Dictionary<string, string[]> { ["position"] = ["Posição inválida."] });

    public static ApiError FromReason(string reason) => reason switch
    {
        "registration_closed" => RegistrationClosed,
        "age_too_young" => AgeTooYoung,
        "age_too_old" => AgeTooOld,
        "gender_not_allowed" => GenderNotAllowed,
        "tournament_full" => TournamentFull,
        "team_confirmed" => TeamConfirmed,
        _ => RegistrationClosed
    };
}

/// <summary>Regras de negócio das equipas, pedidos, convites, líder e posições.</summary>
public sealed class TeamService(
    TeamStore store,
    AuthStore users,
    UsernameStore usernames,
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
        var gender = await GenderOfAsync(userId, ct);
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
                gate.Status, gate.TeamsConfirmed, gate.MaxTeams, gate.MinAge, gate.MaxAge, age.Value,
                gate.Gender, gender);
            if (reason is not null)
            {
                return Outcome<Guid>.Fail(TeamErrors.FromReason(reason));
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, tournamentId, userId) is not null)
            {
                return Outcome<Guid>.Fail(TeamErrors.AlreadyInTeam);
            }

            if (await PenaltyMinutesLeftAsync(c, tx, tournamentId, userId) is { } left)
            {
                return Outcome<Guid>.Fail(TeamErrors.PlayerPenalized(left));
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
        var gender = await GenderOfAsync(userId, ct);
        if (age is null)
        {
            return Outcome<TeamLobbyDto>.Fail(Errors.UserNotFound);
        }

        var now = Now;
        await using var c = await store.OpenAsync(ct);
        var team = await TeamStore.TeamAsync(c, null, teamId, false);
        if (team is null)
        {
            return Outcome<TeamLobbyDto>.Fail(TeamErrors.TeamNotFound);
        }

        var members = await TeamStore.MembersAsync(c, null, teamId);
        var me = members.FirstOrDefault(m => m.UserId == userId);
        var isMember = me is not null;
        var isHost = team.HostUserId == userId;
        var myTeamId = await TeamStore.MyTeamIdAsync(c, null, team.TournamentId, userId);
        var pendingRequestId = await TeamStore.PendingRequestIdAsync(c, teamId, userId);
        var pendingInviteId = await TeamStore.PendingInviteIdAsync(c, teamId, userId);
        var state = team.State;
        var penaltyUntil = await TeamStore.PenaltyUntilAsync(c, null, team.TournamentId, userId, now);

        var blocked = TeamRules.JoinBlockedReason(
            team.HostUserId is not null, isMember, team.TournamentStatus,
            myTeamId is not null && myTeamId != teamId,
            team.MinAge, team.MaxAge, age.Value, members.Count, team.MaxPlayersPerTeam,
            pendingRequestId is not null,
            team.ConfirmedAt is not null,
            team.IsPrivate,
            team.ClosedAt is not null,
            penaltyUntil is not null,
            team.Gender, gender);

        IReadOnlyList<PendingDto> requests = [];
        IReadOnlyList<PendingDto> invites = [];
        if (isHost)
        {
            requests = (await TeamStore.PendingRequestsAsync(c, teamId))
                .Select(r => new PendingDto(r.Id, r.UserId, r.DisplayName, r.Username, r.CreatedAt)).ToList();
            invites = (await TeamStore.PendingInvitesAsync(c, teamId))
                .Select(r => new PendingDto(r.Id, r.UserId, r.DisplayName, r.Username, r.CreatedAt)).ToList();
        }

        // Quem participa no torneio pode ver os membros e as posições de qualquer equipa;
        // os pagamentos e os "preparados" só os membros (o líder conta sempre como preparado).
        // Penalizados (não pagaram a tempo): só os membros veem, para trocar o sinal de "preparado" por uma bolinha vermelha.
        var penalizedIds = isMember
            ? await TeamStore.PenalizedMemberIdsAsync(c, null, teamId, now)
            : new HashSet<Guid>();
        IReadOnlyList<MemberDto> memberDtos = members.Select(m => new MemberDto(
            m.UserId, m.DisplayName, m.Username, m.Position, m.UserId == team.HostUserId, m.UserId == userId,
            isMember ? m.Paid : null,
            isMember ? (m.Ready || m.UserId == team.HostUserId) : null,
            m.Slot,
            isMember ? penalizedIds.Contains(m.UserId) : null)).ToList();

        // Fecho da equipa (só o líder vê porque ainda não pode fechar).
        var notReady = members.Count(m => m.UserId != team.HostUserId && !m.Ready);
        IReadOnlyList<string> penalizedNames = [];
        string? closeReason = null;
        string? closeMessage = null;
        if (isHost && state == ReservationRules.Forming)
        {
            penalizedNames = await TeamStore.PenalizedMembersAsync(c, null, teamId, now);
            closeReason = ReservationRules.WhyCannotClose(
                team.TournamentStatus, false, members.Count, team.MinPlayersPerTeam, notReady, penalizedNames.Count);
            closeMessage = closeReason is null
                ? null
                : TeamErrors.CloseMessage(closeReason, team.MinPlayersPerTeam, notReady, penalizedNames);
        }

        int? queuePosition = state == ReservationRules.Queued
            ? await TeamStore.QueuePositionAsync(c, null, team.TournamentId, teamId)
            : null;

        var reservation = new TeamReservationDto(
            state, team.ClosedAt,
            state == ReservationRules.Reserved ? team.ReservationExpiresAt : null,
            queuePosition, team.TeamsReserved, team.MaxTeams,
            ReservationRules.ReservationMinutes, ReservationRules.PenaltyMinutes);

        // Valores: antes de fechar, pré-visualização do pagamento dividido (arredondado para cima).
        var mode = team.PaymentMode ?? ReservationRules.Split;
        var share = team.ShareCents ?? ReservationRules.ShareCents(ReservationRules.Split, team.EntryFeeCents, members.Count);
        var collected = ReservationRules.CollectedCents(mode, team.EntryFeeCents, members.Count);
        var extra = ReservationRules.ExtraCents(mode, team.EntryFeeCents, members.Count);
        var iPaid = me?.Paid ?? false;
        var payReason = isMember
            ? ReservationRules.WhyCannotPay(
                state, ReservationRules.IsExpired(team.ReservationExpiresAt, now), team.PaymentMode, isHost, iPaid)
            : "not_team_member";
        var payment = new TeamPaymentDto(
            team.EntryFeeCents, team.PaymentMode, share, members.Count, collected, extra, extra > 0,
            isMember ? members.Count(m => m.Paid) : 0, iPaid, payReason is null, payReason);

        return Outcome<TeamLobbyDto>.Ok(new TeamLobbyDto(
            new TeamHeaderDto(
                team.Id, team.Name, team.ColorHex, team.IsDemo, team.ConfirmedAt is not null,
                team.IsPrivate, team.MembersCanInvite),
            new TeamTournamentDto(
                team.TournamentId, team.TournamentName, team.TournamentStatus,
                team.MinPlayersPerTeam, team.MaxPlayersPerTeam, team.RegistrationClosesAt,
                team.TeamsConfirmed, team.MaxTeams,
                string.IsNullOrWhiteSpace(team.RulesText) ? TournamentRules.PlaceholderRules : team.RulesText),
            members.Count,
            memberDtos,
            isMember ? members.Count(m => m.Position is null) : 0,
            requests,
            invites,
            new TeamMeDto(
                isMember, isHost, pendingRequestId, pendingInviteId, myTeamId, blocked is null, blocked,
                TeamRules.CanInvite(isHost, isMember, team.MembersCanInvite) &&
                team.ClosedAt is null && team.TournamentStatus == "registration_open",
                isMember && (me!.Ready || isHost), penaltyUntil,
                isHost && closeReason is null && state == ReservationRules.Forming,
                closeReason, closeMessage,
                isHost && team.ClosedAt is not null && team.ConfirmedAt is null && team.TournamentStatus == "registration_open",
                isHost && team.ConfirmedAt is null && !team.IsDemo),
            reservation,
            payment,
            new LineupDto(
                team.Formation ?? Formations.Default(team.Sport), Formations.For(team.Sport),
                Formations.SlotCount(team.Formation ?? Formations.Default(team.Sport))),
            await BuildCodeAsync(c, team, isHost, isMember, now)));
    }

    /// <summary>
    /// O líder vê tudo (inclui quantas gerações lhe restam); os membros só veem o código se estiver ativo e o líder o
    /// permitir; outros jogadores não veem nada. Só enquanto a equipa está em formação.
    /// </summary>
    private static async Task<TeamCodeDto?> BuildCodeAsync(
        NpgsqlConnection c, TeamInfoRow team, bool isHost, bool isMember, DateTime now)
    {
        if (!isMember || team.ClosedAt is not null || team.ConfirmedAt is not null)
        {
            return null;
        }

        if (isHost)
        {
            var (count, _) = await TeamStore.CodeRegensAsync(c, null, team.Id, now.AddHours(-1));
            return new TeamCodeDto(
                team.InviteCode, team.InviteCodeEnabled, team.CodeDirectEntry, team.MembersSeeCode,
                InviteCodes.RegensLeft(count));
        }

        return team.InviteCodeEnabled && team.MembersSeeCode
            ? new TeamCodeDto(team.InviteCode, true, team.CodeDirectEntry, true, 0)
            : null;
    }

    // ======================= Pedidos para entrar =======================

    public async Task<ApiError?> RequestJoinAsync(Guid userId, Guid teamId, CancellationToken ct)
    {
        var age = await AgeOfAsync(userId, ct);
        var gender = await GenderOfAsync(userId, ct);
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

            var reason = TournamentRules.WhyCannotParticipate(
                team.TournamentStatus, team.MinAge, team.MaxAge, age.Value, team.Gender, gender);
            if (reason is not null)
            {
                return TeamErrors.FromReason(reason);
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, userId) is not null)
            {
                return TeamErrors.AlreadyInTeam;
            }

            if (await PenaltyMinutesLeftAsync(c, tx, team.TournamentId, userId) is { } penaltyLeft)
            {
                return TeamErrors.PlayerPenalized(penaltyLeft);
            }

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
            }

            if (await TeamStore.CountMembersAsync(c, tx, teamId) >= team.MaxPlayersPerTeam)
            {
                return TeamErrors.TeamFull;
            }

            if (team.IsPrivate)
            {
                return TeamErrors.LobbyPrivate;
            }

            var requestId = Guid.NewGuid();
            inserted = await TeamStore.InsertRequestAsync(c, tx, requestId, teamId, team.TournamentId, userId) == 1;
            if (inserted)
            {
                // O líder vê o pedido na central de notificações (com aceitar/recusar).
                await TeamNotifier.NotifyJoinRequestAsync(c, tx, team.HostUserId.Value, requestId);
            }

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
                await TeamNotifier.NotifyUserAsync(
                    c, tx, req.UserId, team.Id, NotificationTypes.RequestDecided, NotificationTexts.RequestRejectedTitle,
                    NotificationTexts.RequestRejected);
                return null;
            }

            if (team.TournamentStatus != "registration_open")
            {
                return TeamErrors.RegistrationClosed;
            }

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
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

            if (await PenaltyMinutesLeftAsync(c, tx, team.TournamentId, req.UserId) is not null)
            {
                return TeamErrors.InviteePenalized(null);
            }

            await TeamStore.InsertMemberAsync(c, tx, team.Id, team.TournamentId, req.UserId);
            await TeamStore.SetRequestStatusAsync(c, tx, requestId, "accepted");
            await TeamStore.CancelOtherPendingAsync(c, tx, team.TournamentId, req.UserId);
            await TeamNotifier.NotifyUserAsync(
                c, tx, req.UserId, team.Id, NotificationTypes.RequestDecided, NotificationTexts.RequestAcceptedTitle,
                NotificationTexts.RequestAccepted);
            return null;
        }, ct);
    }

    // ======================= Convites =======================

    /// <summary>Verificação rápida (fora da transação) de que este utilizador pode convidar nesta equipa.</summary>
    private async Task<ApiError?> WhyCannotInviteAsync(Guid inviterId, Guid teamId, CancellationToken ct)
    {
        await using var c = await store.OpenAsync(ct);
        var team = await TeamStore.TeamAsync(c, null, teamId, false);
        if (team is null)
        {
            return TeamErrors.TeamNotFound;
        }

        var isMember = team.HostUserId == inviterId ||
            await TeamStore.MyTeamIdAsync(c, null, team.TournamentId, inviterId) == teamId;
        if (!isMember)
        {
            return TeamErrors.NotMember;
        }

        return TeamRules.CanInvite(team.HostUserId == inviterId, true, team.MembersCanInvite)
            ? null
            : TeamErrors.InviteNotAllowed;
    }

    /// <summary>
    /// Convida um utilizador pelo email ou por username#tag.
    /// Email: a resposta é igual exista a conta ou não (o email é privado, não revela quem está registado).
    /// Username#tag: se não existir devolve <c>user_not_found</c> (o par exato é difícil de adivinhar: 1000 tags por
    /// username e no máximo 10 tentativas falhadas por hora).
    /// </summary>
    public async Task<ApiError?> InviteAsync(
        Guid inviterId, Guid teamId, string? emailInput, string? usernameInput, CancellationToken ct)
    {
        User? invitee;
        if (!string.IsNullOrWhiteSpace(usernameInput))
        {
            var handle = UsernameRules.ParseHandle(usernameInput);
            if (handle is null)
            {
                return ApiError.Validation(new Dictionary<string, string[]>
                {
                    ["username"] = ["Escreve o username com a tag, por exemplo hugo#482."]
                });
            }

            // Só quem pode mesmo convidar nesta equipa pesquisa utilizadores (evita usar isto para sondar a base).
            var denied = await WhyCannotInviteAsync(inviterId, teamId, ct);
            if (denied is not null)
            {
                return denied;
            }

            if (await usernames.CountFailuresAsync(inviterId, Now, ct) >= UsernameRules.MaxFailedLookupsPerHour)
            {
                return TeamErrors.TooManyFailedLookups;
            }

            invitee = await usernames.FindByHandleAsync(handle.Value.Username, handle.Value.Tag, ct);
            if (invitee is null)
            {
                await usernames.RecordFailureAsync(inviterId, Now, ct);
                return TeamErrors.UserNotFound;
            }
        }
        else
        {
            var normalized = AuthValidation.NormalizeEmail(emailInput);
            if (normalized is null || !normalized.Contains('@'))
            {
                return ApiError.Validation(new Dictionary<string, string[]> { ["email"] = ["Email inválido."] });
            }

            invitee = await users.FindUserByEmailAsync(normalized, ct);
        }

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

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
            }

            // Convidar-se a si próprio nunca é possível.
            if (invitee is not null && invitee.Id == inviterId)
            {
                return TeamErrors.CannotInviteSelf;
            }

            if (await TeamStore.CountMembersAsync(c, tx, teamId) >= team.MaxPlayersPerTeam)
            {
                return TeamErrors.TeamFull;
            }

            if (await TeamStore.CountPendingInvitesAsync(c, tx, teamId) >= TeamRules.MaxPendingInvitesPerTeam)
            {
                return TeamErrors.TooManyInvites;
            }

            // Conta inexistente ou por verificar: resposta igual à de sucesso, sem convite (não revela quem tem conta).
            if (invitee is null || invitee.EmailVerifiedAt is null)
            {
                return null;
            }

            // Já está numa equipa deste torneio: avisamos quem convida. Só revela o que já é visível nos lobbys
            // (os membros de qualquer equipa do torneio são públicos para quem participa).
            if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, invitee.Id) is not null)
            {
                return TeamErrors.InviteeAlreadyInTeam(invitee.DisplayName);
            }

            if (await PenaltyMinutesLeftAsync(c, tx, team.TournamentId, invitee.Id) is not null)
            {
                return TeamErrors.InviteePenalized(invitee.DisplayName);
            }

            var inviteId = Guid.NewGuid();
            inserted = await TeamStore.InsertInviteAsync(
                c, tx, inviteId, teamId, team.TournamentId, invitee.Id, inviterId) == 1;
            if (inserted)
            {
                // Notificação na app (central de notificações), na mesma transação do convite.
                await NotificationStore.InsertTeamInviteAsync(c, tx, invitee.Id, inviteId);
            }

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
        var gender = await GenderOfAsync(userId, ct);
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

            var reason = TournamentRules.WhyCannotParticipate(
                team.TournamentStatus, team.MinAge, team.MaxAge, age.Value, team.Gender, gender);
            if (reason is not null)
            {
                return TeamErrors.FromReason(reason);
            }

            if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, userId) is not null)
            {
                return TeamErrors.AlreadyInTeam;
            }

            if (await PenaltyMinutesLeftAsync(c, tx, team.TournamentId, userId) is { } penaltyLeft)
            {
                return TeamErrors.PlayerPenalized(penaltyLeft);
            }

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
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

    /// <summary>Só o líder, até a vaga ser confirmada. Só muda os campos enviados.</summary>
    public async Task<ApiError?> UpdateSettingsAsync(
        Guid hostId, Guid teamId, UpdateTeamSettingsRequest req, CancellationToken ct)
    {
        if (req.IsPrivate is null && req.MembersCanInvite is null && req.InviteCodeEnabled is null &&
            req.CodeDirectEntry is null && req.MembersSeeCode is null)
        {
            return ApiError.Validation(new Dictionary<string, string[]>
            {
                ["settings"] = ["Indica pelo menos uma definição."]
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

            // Com a vaga confirmada ninguém entra nem é convidado: as definições deixam de fazer sentido.
            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.SettingsLocked;
            }

            // Fechada (em fila ou a pagar): as definições do lobby já não se mexem; reabrir devolve-as.
            if (team.ClosedAt is not null)
            {
                return TeamErrors.TeamClosed;
            }

            await TeamStore.UpdateSettingsAsync(
                c, tx, teamId,
                req.IsPrivate ?? team.IsPrivate,
                req.MembersCanInvite ?? team.MembersCanInvite,
                req.InviteCodeEnabled ?? team.InviteCodeEnabled,
                req.CodeDirectEntry ?? team.CodeDirectEntry,
                req.MembersSeeCode ?? team.MembersSeeCode);
            return null;
        }, ct);
    }

    // ======================= Código de convite (GH-XXXX) =======================

    /// <summary>Gera um código novo (o antigo deixa de funcionar). Só o líder; máx. 3 por hora.</summary>
    public async Task<Outcome<RegenerateCodeResultDto>> RegenerateCodeAsync(Guid hostId, Guid teamId, CancellationToken ct)
    {
        var now = Now;
        return await store.InTransactionAsync<Outcome<RegenerateCodeResultDto>>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return Outcome<RegenerateCodeResultDto>.Fail(TeamErrors.TeamNotFound);
            }

            if (team.HostUserId != hostId)
            {
                return Outcome<RegenerateCodeResultDto>.Fail(TeamErrors.NotHost);
            }

            if (team.ConfirmedAt is not null)
            {
                return Outcome<RegenerateCodeResultDto>.Fail(TeamErrors.SettingsLocked);
            }

            if (team.ClosedAt is not null)
            {
                return Outcome<RegenerateCodeResultDto>.Fail(TeamErrors.TeamClosed);
            }

            var (count, oldest) = await TeamStore.CodeRegensAsync(c, tx, teamId, now.AddHours(-1));
            if (InviteCodes.RegensLeft(count) == 0)
            {
                return Outcome<RegenerateCodeResultDto>.Fail(
                    TeamErrors.CodeRegenLimit(InviteCodes.MinutesUntilRegen(oldest ?? now, now)));
            }

            var code = await TeamStore.RegenerateCodeAsync(c, tx, teamId, now);
            return Outcome<RegenerateCodeResultDto>.Ok(
                new RegenerateCodeResultDto(code, InviteCodes.RegensLeft(count + 1)));
        }, ct);
    }

    /// <summary>Procura a equipa do código, partilhando o limite de tentativas falhadas das pesquisas.</summary>
    private async Task<(Guid? TeamId, ApiError? Error)> ResolveCodeAsync(Guid userId, string rawCode, CancellationToken ct)
    {
        if (await usernames.CountFailuresAsync(userId, Now, ct) >= UsernameRules.MaxFailedLookupsPerHour)
        {
            return (null, TeamErrors.TooManyFailedLookups);
        }

        var code = InviteCodes.Normalize(rawCode);
        Guid? teamId = null;
        if (code is not null)
        {
            await using var c = await store.OpenAsync(ct);
            var id = await TeamStore.TeamIdByCodeAsync(c, null, code);
            if (id is not null && await TeamStore.TeamAsync(c, null, id.Value, false) is { InviteCodeEnabled: true, HostUserId: not null })
            {
                teamId = id;
            }
        }

        if (teamId is null)
        {
            await usernames.RecordFailureAsync(userId, Now, ct);
            return (null, TeamErrors.InviteCodeInvalid);
        }

        return (teamId, null);
    }

    /// <summary>Verificações comuns a quem quer entrar (pré-visualização e entrada). Null = pode.</summary>
    private async Task<ApiError?> WhyCannotJoinByCodeAsync(
        NpgsqlConnection c, NpgsqlTransaction? tx, TeamInfoRow team, Guid userId, int age, string? gender)
    {
        if (team.HostUserId is null)
        {
            return TeamErrors.TeamNotJoinable;
        }

        var reason = TournamentRules.WhyCannotParticipate(
            team.TournamentStatus, team.MinAge, team.MaxAge, age, team.Gender, gender);
        if (reason is not null)
        {
            return TeamErrors.FromReason(reason);
        }

        if (await TeamStore.MyTeamIdAsync(c, tx, team.TournamentId, userId) is not null)
        {
            return TeamErrors.AlreadyInTeam;
        }

        if (await PenaltyMinutesLeftAsync(c, tx, team.TournamentId, userId) is { } left)
        {
            return TeamErrors.PlayerPenalized(left);
        }

        if (team.ClosedAt is not null)
        {
            return TeamErrors.ClosedFor(team);
        }

        if (await TeamStore.CountMembersAsync(c, tx, team.Id) >= team.MaxPlayersPerTeam)
        {
            return TeamErrors.TeamFull;
        }

        return null;
    }

    /// <summary>O que o jogador vê ao escrever um código, antes de confirmar.</summary>
    public async Task<Outcome<InviteCodePreviewDto>> PreviewCodeAsync(Guid userId, string rawCode, CancellationToken ct)
    {
        var age = await AgeOfAsync(userId, ct);
        var gender = await GenderOfAsync(userId, ct);
        if (age is null)
        {
            return Outcome<InviteCodePreviewDto>.Fail(Errors.UserNotFound);
        }

        var (teamId, error) = await ResolveCodeAsync(userId, rawCode, ct);
        if (error is not null)
        {
            return Outcome<InviteCodePreviewDto>.Fail(error);
        }

        await using var c = await store.OpenAsync(ct);
        var team = await TeamStore.TeamAsync(c, null, teamId!.Value, false);
        if (team is null)
        {
            return Outcome<InviteCodePreviewDto>.Fail(TeamErrors.InviteCodeInvalid);
        }

        var blocked = await WhyCannotJoinByCodeAsync(c, null, team, userId, age.Value, gender);
        var count = await TeamStore.CountMembersAsync(c, null, team.Id);
        return Outcome<InviteCodePreviewDto>.Ok(new InviteCodePreviewDto(
            team.Id, team.Name, team.ColorHex, team.TournamentName, count, team.MaxPlayersPerTeam,
            team.CodeDirectEntry, blocked?.Code, blocked?.Message));
    }

    /// <summary>
    /// Entra com o código. Entrada direta: fica logo na equipa (o líder é avisado). Senão: cria um pedido
    /// normal que o líder aceita ou recusa. Funciona mesmo com a equipa privada: o código é o convite.
    /// </summary>
    public async Task<Outcome<JoinByCodeResultDto>> JoinByCodeAsync(Guid userId, string rawCode, CancellationToken ct)
    {
        var age = await AgeOfAsync(userId, ct);
        var gender = await GenderOfAsync(userId, ct);
        if (age is null)
        {
            return Outcome<JoinByCodeResultDto>.Fail(Errors.UserNotFound);
        }

        var (teamId, lookupError) = await ResolveCodeAsync(userId, rawCode, ct);
        if (lookupError is not null)
        {
            return Outcome<JoinByCodeResultDto>.Fail(lookupError);
        }

        var player = await users.FindUserByIdAsync(userId, ct);
        TeamInfoRow? teamInfo = null;
        var joined = false;
        var result = await store.InTransactionAsync<Outcome<JoinByCodeResultDto>>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId!.Value, true);
            // Entretanto o líder pode ter desligado ou mudado o código.
            if (team is null || !team.InviteCodeEnabled || InviteCodes.Normalize(rawCode) != team.InviteCode)
            {
                return Outcome<JoinByCodeResultDto>.Fail(TeamErrors.InviteCodeInvalid);
            }

            var blocked = await WhyCannotJoinByCodeAsync(c, tx, team, userId, age.Value, gender);
            if (blocked is not null)
            {
                return Outcome<JoinByCodeResultDto>.Fail(blocked);
            }

            teamInfo = team;
            if (team.CodeDirectEntry)
            {
                await TeamStore.InsertMemberAsync(c, tx, team.Id, team.TournamentId, userId);
                await TeamStore.CancelOtherPendingAsync(c, tx, team.TournamentId, userId);
                var name = player?.DisplayName ?? "Um jogador";
                await TeamNotifier.NotifyUserAsync(
                    c, tx, team.HostUserId!.Value, team.Id, NotificationTypes.MemberJoined,
                    NotificationTexts.MemberJoinedTitle, (teamName, _) => NotificationTexts.MemberJoinedText(name, teamName));
                joined = true;
                return Outcome<JoinByCodeResultDto>.Ok(new JoinByCodeResultDto(team.Id, true));
            }

            var requestId = Guid.NewGuid();
            if (await TeamStore.InsertRequestAsync(c, tx, requestId, team.Id, team.TournamentId, userId) == 1)
            {
                await TeamNotifier.NotifyJoinRequestAsync(c, tx, team.HostUserId!.Value, requestId);
            }

            return Outcome<JoinByCodeResultDto>.Ok(new JoinByCodeResultDto(team.Id, false));
        }, ct);

        if (result.IsOk && teamInfo is { HostUserId: not null } t && !joined)
        {
            await NotifyAsync(t.HostUserId.Value, hostName =>
                TeamEmails.JoinRequest(hostName, player?.DisplayName ?? "Um jogador", t.Name, t.TournamentName), ct);
        }

        return result;
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
            await TeamNotifier.NotifyUserAsync(
                c, tx, newHostId.Value, teamId, NotificationTypes.NowLeader, NotificationTexts.NowLeaderTitle,
                NotificationTexts.NowLeaderText);
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

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
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

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
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
            if (removed == 0)
            {
                return TeamErrors.NotMember;
            }

            await TeamNotifier.NotifyUserAsync(
                c, tx, memberId, teamId, NotificationTypes.RemovedFromTeam, NotificationTexts.RemovedTitle,
                NotificationTexts.Removed);
            return null;
        }, ct);

    // ======================= Preparado, fechar, reservar e pagar =======================

    /// <summary>O jogador marca-se como preparado (ou deixa de estar). Só enquanto a equipa não está fechada.</summary>
    public async Task<ApiError?> SetReadyAsync(Guid userId, Guid teamId, bool? ready, CancellationToken ct)
    {
        if (ready is null)
        {
            return TeamErrors.InvalidReady;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.TournamentStatus != "registration_open")
            {
                return TeamErrors.RegistrationClosed;
            }

            if (team.ClosedAt is not null)
            {
                return TeamErrors.ClosedFor(team);
            }

            var updated = await TeamStore.SetReadyAsync(c, tx, teamId, userId, ready.Value);
            return updated == 0 ? TeamErrors.NotMember : null;
        }, ct);
    }

    /// <summary>
    /// O líder fecha a equipa: ninguém entra nem sai, entra na fila e, havendo vaga livre, fica logo com a vaga
    /// reservada durante 30 minutos para pagar. Várias equipas a fechar quase ao mesmo tempo: ordem de chegada.
    /// </summary>
    public async Task<ApiError?> CloseAsync(Guid hostId, Guid teamId, string? paymentMode, CancellationToken ct)
    {
        if (!ReservationRules.IsValidMode(paymentMode))
        {
            return TeamErrors.InvalidPaymentMode;
        }

        var tournamentId = await TournamentOfTeamAsync(teamId, ct);
        if (tournamentId is null)
        {
            return TeamErrors.TeamNotFound;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            // Primeiro o torneio, depois a equipa (mesma ordem em todo o lado: evita deadlocks).
            if (await TeamStore.GateAsync(c, tx, tournamentId.Value) is null)
            {
                return TeamErrors.TournamentNotFound;
            }

            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            var members = await TeamStore.MembersAsync(c, tx, teamId);
            var notReady = members.Count(m => m.UserId != team.HostUserId && !m.Ready);
            var penalized = await TeamStore.PenalizedMembersAsync(c, tx, teamId, Now);
            var reason = ReservationRules.WhyCannotClose(
                team.TournamentStatus, team.ClosedAt is not null, members.Count, team.MinPlayersPerTeam,
                notReady, penalized.Count);
            if (reason is not null)
            {
                return TeamErrors.CloseBlocked(reason, team.MinPlayersPerTeam, notReady, penalized);
            }

            var share = ReservationRules.ShareCents(paymentMode!, team.EntryFeeCents, members.Count);
            await TeamStore.CloseTeamAsync(c, tx, teamId, paymentMode!, share, Now);
            var picked = await ReservationAllocator.AllocateAsync(c, tx, tournamentId.Value, Now, skipNotify: teamId);
            await TeamNotifier.NotifyClosedAsync(c, tx, teamId, reserved: picked.Contains(teamId));
            return null;
        }, ct);
    }

    /// <summary>
    /// O líder reabre a equipa (desiste da fila ou da vaga reservada) enquanto a vaga não está confirmada.
    /// Os pagamentos reservados são libertados sem custos e a vaga passa à próxima equipa da fila.
    /// </summary>
    public async Task<ApiError?> ReopenAsync(Guid hostId, Guid teamId, CancellationToken ct) =>
        await WithdrawAsync(hostId, teamId, deleteTeam: false, ct);

    /// <summary>O líder elimina a equipa (como numa equipa normal), enquanto a vaga não está confirmada.</summary>
    public async Task<ApiError?> DisbandAsync(Guid hostId, Guid teamId, CancellationToken ct) =>
        await WithdrawAsync(hostId, teamId, deleteTeam: true, ct);

    private async Task<ApiError?> WithdrawAsync(Guid hostId, Guid teamId, bool deleteTeam, CancellationToken ct)
    {
        var tournamentId = await TournamentOfTeamAsync(teamId, ct);
        if (tournamentId is null)
        {
            return TeamErrors.TeamNotFound;
        }

        return await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            if (await TeamStore.GateAsync(c, tx, tournamentId.Value) is null)
            {
                return TeamErrors.TournamentNotFound;
            }

            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            if (team.HostUserId != hostId)
            {
                return TeamErrors.NotHost;
            }

            // Vaga confirmada (todos pagaram): a equipa já não pode desistir.
            if (team.ConfirmedAt is not null)
            {
                return TeamErrors.TeamLocked;
            }

            if (deleteTeam)
            {
                await TeamStore.DeleteTeamAsync(c, tx, teamId);
            }
            else
            {
                if (team.ClosedAt is null)
                {
                    return TeamErrors.TeamNotClosed;
                }

                // Depois do prazo das inscrições já não se volta à formação (a equipa seria eliminada).
                if (team.TournamentStatus != "registration_open")
                {
                    return TeamErrors.ReopenAfterDeadline;
                }

                await ReservationAllocator.ResetToFormingAsync(c, tx, teamId);
            }

            await ReservationAllocator.AllocateAsync(c, tx, tournamentId.Value, Now);
            return null;
        }, ct);
    }

    /// <summary>
    /// Pagamento SIMULADO (o futuro módulo de pagamentos reserva o saldo e só debita quando todos pagarem).
    /// Dividido: cada membro paga a sua parte. Total: só o líder, que paga por todos. Quando todos pagaram,
    /// a vaga fica confirmada e a equipa já não pode desistir.
    /// </summary>
    public async Task<ApiError?> PayAsync(Guid userId, Guid teamId, CancellationToken ct) =>
        await store.InTransactionAsync<ApiError?>(async (c, tx) =>
        {
            var team = await TeamStore.TeamAsync(c, tx, teamId, true);
            if (team is null)
            {
                return TeamErrors.TeamNotFound;
            }

            var members = await TeamStore.MembersAsync(c, tx, teamId);
            var me = members.FirstOrDefault(m => m.UserId == userId);
            if (me is null)
            {
                return TeamErrors.NotMember;
            }

            var now = Now;
            var reason = ReservationRules.WhyCannotPay(
                team.State, ReservationRules.IsExpired(team.ReservationExpiresAt, now),
                team.PaymentMode, team.HostUserId == userId, me.Paid);
            if (reason is not null)
            {
                return TeamErrors.PayBlocked(reason);
            }

            await TeamStore.MarkPaidAsync(
                c, tx, teamId, team.PaymentMode == ReservationRules.Total ? null : userId, now);
            if (ReservationRules.AllPaid(members.Count, await TeamStore.CountPaidAsync(c, tx, teamId)))
            {
                await TeamStore.ConfirmTeamAsync(c, tx, teamId, now);
                await TeamNotifier.NotifyConfirmedAsync(c, tx, teamId);
            }

            return null;
        }, ct);

    // ======================= Formação (só o líder) =======================

    /// <summary>O líder escolhe a formação e quem joga em cada lugar; os restantes ficam suplentes.</summary>
    public async Task<ApiError?> SetLineupAsync(Guid hostId, Guid teamId, SetLineupRequest req, CancellationToken ct) =>
        await store.InTransactionAsync<ApiError?>(async (c, tx) =>
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

            var slots = (req.Slots ?? []).Select(s => (s.UserId, s.Slot)).ToList();
            var members = (await TeamStore.MembersAsync(c, tx, teamId)).Select(m => m.UserId).ToHashSet();
            var problem = Formations.Validate(team.Sport, req.Formation, slots, members);
            if (problem is not null)
            {
                return ApiError.Validation(new Dictionary<string, string[]> { ["lineup"] = [problem] });
            }

            await TeamStore.SetLineupAsync(c, tx, teamId, req.Formation!, slots);
            return null;
        }, ct);

    // ======================= Listas =======================

    public async Task<IReadOnlyList<MyTeamDto>> MyTeamsAsync(Guid userId, CancellationToken ct) =>
        (await store.MyTeamsAsync(userId, ct)).Select(r => new MyTeamDto(
            r.TeamId, r.Name, r.ColorHex, r.TournamentId, r.TournamentName, r.TournamentStatus,
            r.IsHost, r.MembersCount, r.MinPlayersPerTeam, r.MaxPlayersPerTeam, r.PendingRequests,
            r.State, r.State == ReservationRules.Reserved ? r.ReservationExpiresAt : null)).ToList();

    public async Task<IReadOnlyList<MyInviteDto>> MyInvitesAsync(Guid userId, CancellationToken ct) =>
        (await store.MyInvitesAsync(userId, ct)).Select(r => new MyInviteDto(
            r.Id, r.TeamId, r.TeamName, r.ColorHex, r.TournamentId, r.TournamentName,
            r.InvitedByName, r.CreatedAt)).ToList();

    public async Task<IReadOnlyList<MyRequestDto>> MyRequestsAsync(Guid userId, CancellationToken ct) =>
        (await store.MyRequestsAsync(userId, ct)).Select(r => new MyRequestDto(
            r.Id, r.TeamId, r.TeamName, r.ColorHex, r.TournamentId, r.TournamentName, r.CreatedAt)).ToList();

    // ======================= Auxiliares =======================

    /// <summary>Minutos (arredondados para cima) que faltam para acabar a penalização, ou null se não está penalizado.</summary>
    private async Task<int?> PenaltyMinutesLeftAsync(NpgsqlConnection c, NpgsqlTransaction? tx, Guid tournamentId, Guid userId)
    {
        var now = Now;
        var until = await TeamStore.PenaltyUntilAsync(c, tx, tournamentId, userId, now);
        return until is null ? null : Math.Max(1, (int)Math.Ceiling((until.Value - now).TotalMinutes));
    }

    private async Task<Guid?> TournamentOfTeamAsync(Guid teamId, CancellationToken ct)
    {
        await using var c = await store.OpenAsync(ct);
        return (await TeamStore.TeamAsync(c, null, teamId, false))?.TournamentId;
    }

    private async Task<string?> GenderOfAsync(Guid userId, CancellationToken ct) =>
        (await users.FindUserByIdAsync(userId, ct))?.Gender;

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
