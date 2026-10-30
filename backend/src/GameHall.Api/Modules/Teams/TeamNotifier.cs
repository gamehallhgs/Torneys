using System.Data;
using Dapper;
using GameHall.Api.Modules.Notifications;

namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Cria as notificações (na central da app) dos eventos de equipa, dentro da mesma transação que os
/// gerou: ou acontece tudo, ou nada. O texto fica guardado já composto.
/// </summary>
public static class TeamNotifier
{
    private sealed class Info
    {
        public Guid TeamId { get; set; }
        public string Name { get; set; } = "";
        public string ColorHex { get; set; } = "";
        public string TournamentName { get; set; } = "";
        public Guid? HostUserId { get; set; }
        public string? PaymentMode { get; set; }
        public int? ShareCents { get; set; }
    }

    private static async Task<List<Info>> InfosAsync(IDbConnection c, IDbTransaction tx, IEnumerable<Guid> teamIds) =>
        (await c.QueryAsync<Info>(
            """
            SELECT t.id AS team_id, t.name, t.color_hex, tr.name AS tournament_name,
                   t.host_user_id, t.payment_mode, t.share_cents
            FROM teams t JOIN tournaments tr ON tr.id = t.tournament_id
            WHERE t.id = ANY(@Ids)
            """,
            new { Ids = teamIds.ToArray() }, tx)).ToList();

    private static async Task<List<Guid>> MembersAsync(IDbConnection c, IDbTransaction tx, Guid teamId) =>
        (await c.QueryAsync<Guid>(
            "SELECT user_id FROM team_members WHERE team_id = @T", new { T = teamId }, tx)).ToList();

    /// <summary>O líder recebe o pedido para entrar (com aceitar/recusar).</summary>
    public static Task NotifyJoinRequestAsync(IDbConnection c, IDbTransaction tx, Guid hostId, Guid requestId) =>
        NotificationStore.InsertJoinRequestAsync(c, tx, hostId, requestId);

    /// <summary>Todos os membros: a equipa foi fechada, quem paga o quê e se há vaga já ou fila.</summary>
    public static async Task NotifyClosedAsync(IDbConnection c, IDbTransaction tx, Guid teamId, bool reserved)
    {
        foreach (var t in await InfosAsync(c, tx, [teamId]))
        {
            foreach (var userId in await MembersAsync(c, tx, t.TeamId))
            {
                var msg = NotificationTexts.Closed(
                    t.Name, t.TournamentName, t.PaymentMode, t.ShareCents ?? 0, userId == t.HostUserId,
                    reserved, ReservationRules.ReservationMinutes);
                await NotificationStore.InsertTeamEventAsync(
                    c, tx, userId, NotificationTypes.TeamClosed,
                    new TeamEventData(t.TeamId, t.Name, t.ColorHex, t.TournamentName, NotificationTexts.ClosedTitle, msg));
            }
        }
    }

    /// <summary>Equipas que estavam em fila e acabaram de receber vaga: todos os membros são avisados.</summary>
    public static async Task NotifySlotReservedAsync(IDbConnection c, IDbTransaction tx, IReadOnlyCollection<Guid> teamIds)
    {
        if (teamIds.Count == 0)
        {
            return;
        }

        foreach (var t in await InfosAsync(c, tx, teamIds))
        {
            foreach (var userId in await MembersAsync(c, tx, t.TeamId))
            {
                var msg = NotificationTexts.SlotReserved(
                    t.Name, t.TournamentName, t.PaymentMode, t.ShareCents ?? 0, userId == t.HostUserId,
                    ReservationRules.ReservationMinutes);
                await NotificationStore.InsertTeamEventAsync(
                    c, tx, userId, NotificationTypes.SlotReserved,
                    new TeamEventData(t.TeamId, t.Name, t.ColorHex, t.TournamentName, NotificationTexts.SlotReservedTitle, msg));
            }
        }
    }

    /// <summary>Aviso a um só utilizador sobre uma equipa (a equipa tem de existir ainda).</summary>
    public static async Task NotifyUserAsync(
        IDbConnection c, IDbTransaction tx, Guid userId, Guid teamId, string type, string title,
        Func<string, string, string> message, bool deliver = true)
    {
        foreach (var t in await InfosAsync(c, tx, [teamId]))
        {
            await NotificationStore.InsertTeamEventAsync(
                c, tx, userId, type,
                new TeamEventData(t.TeamId, t.Name, t.ColorHex, t.TournamentName, title, message(t.Name, t.TournamentName)),
                deliver);
        }
    }

    /// <summary>Equipas prestes a ser eliminadas: avisa os membros (chamar ANTES de apagar).</summary>
    public static async Task NotifyEliminatedAsync(
        IDbConnection c, IDbTransaction tx, IReadOnlyCollection<Guid> teamIds, bool deadline)
    {
        if (teamIds.Count == 0)
        {
            return;
        }

        foreach (var t in await InfosAsync(c, tx, teamIds))
        {
            foreach (var userId in await MembersAsync(c, tx, t.TeamId))
            {
                await NotificationStore.InsertTeamEventAsync(
                    c, tx, userId, NotificationTypes.TeamEliminated,
                    new TeamEventData(
                        t.TeamId, t.Name, t.ColorHex, t.TournamentName, NotificationTexts.EliminatedTitle,
                        NotificationTexts.Eliminated(t.Name, t.TournamentName, deadline)));
            }
        }
    }

    /// <summary>Todos pagaram: a equipa está confirmada.</summary>
    public static async Task NotifyConfirmedAsync(IDbConnection c, IDbTransaction tx, Guid teamId)
    {
        foreach (var t in await InfosAsync(c, tx, [teamId]))
        {
            foreach (var userId in await MembersAsync(c, tx, t.TeamId))
            {
                await NotificationStore.InsertTeamEventAsync(
                    c, tx, userId, NotificationTypes.TeamConfirmed,
                    new TeamEventData(
                        t.TeamId, t.Name, t.ColorHex, t.TournamentName, NotificationTexts.ConfirmedTitle,
                        NotificationTexts.Confirmed(t.Name, t.TournamentName)));
            }
        }
    }
}
