namespace GameHall.Api.Modules.Teams;

/// <summary>Equipa fechada à espera de vaga (fila por ordem de chegada).</summary>
public sealed record QueuedTeam(Guid TeamId, DateTime ClosedAt, DateTime CreatedAt);

/// <summary>
/// Regras puras do fecho da equipa, da reserva de vaga (30 min), da penalização (15 min) e do valor a pagar.
/// Sem base de dados, para se poderem testar.
/// </summary>
public static class ReservationRules
{
    public const int ReservationMinutes = 30;
    public const int PenaltyMinutes = 15;

    public const string Split = "split";
    public const string Total = "total";

    public const string Forming = "forming";
    public const string Queued = "queued";
    public const string Reserved = "reserved";
    public const string Confirmed = "confirmed";

    public static bool IsValidMode(string? mode) => mode is Split or Total;

    /// <summary>Estado da equipa: formação, em fila, vaga reservada ou confirmada.</summary>
    public static string StateOf(DateTime? closedAt, DateTime? reservedAt, DateTime? confirmedAt) =>
        confirmedAt is not null ? Confirmed
        : reservedAt is not null ? Reserved
        : closedAt is not null ? Queued
        : Forming;

    /// <summary>
    /// Valor que cada pagador paga, em cêntimos. Dividido: a parte de cada membro, arredondada para CIMA
    /// (50 € por 7 jogadores = 7,15 € cada). Total: o líder paga tudo.
    /// </summary>
    public static int ShareCents(string mode, int feeCents, int members)
    {
        if (feeCents <= 0)
        {
            return 0;
        }

        if (mode == Total)
        {
            return feeCents;
        }

        return members <= 0 ? feeCents : (feeCents + members - 1) / members;
    }

    /// <summary>Total que a equipa acaba por pagar (no modo dividido pode passar o preço por causa do arredondamento).</summary>
    public static int CollectedCents(string mode, int feeCents, int members) =>
        mode == Total ? Math.Max(feeCents, 0) : ShareCents(mode, feeCents, members) * Math.Max(members, 0);

    /// <summary>Quanto passa do preço do torneio por causa do arredondamento (0 se divide certo).</summary>
    public static int ExtraCents(string mode, int feeCents, int members) =>
        Math.Max(CollectedCents(mode, feeCents, members) - Math.Max(feeCents, 0), 0);

    /// <summary>
    /// Motivo (código) pelo qual o líder ainda NÃO pode fechar a equipa, ou null se pode.
    /// Só os membros que não são o líder precisam de estar preparados (fechar já é o "preparado" do líder).
    /// </summary>
    public static string? WhyCannotClose(
        string tournamentStatus, bool alreadyClosed, int members, int minPlayers, int notReadyMembers, int penalizedMembers)
    {
        if (tournamentStatus != "registration_open")
        {
            return "registration_closed";
        }

        if (alreadyClosed)
        {
            return "team_closed";
        }

        if (members < minPlayers)
        {
            return "below_min_players";
        }

        if (notReadyMembers > 0)
        {
            return "members_not_ready";
        }

        return penalizedMembers > 0 ? "members_penalized" : null;
    }

    public static int FreeSlots(int maxTeams, int reserved) => Math.Max(maxTeams - reserved, 0);

    /// <summary>O torneio está cheio (sem vaga livre agora) quando as vagas reservadas ou confirmadas atingem o máximo.</summary>
    public static bool IsFull(int maxTeams, int reserved) => maxTeams > 0 && reserved >= maxTeams;

    /// <summary>
    /// Equipas da fila que passam a ter vaga reservada: por ordem de chegada (quem fechou primeiro),
    /// desempate pela criação, até ao número de vagas livres.
    /// </summary>
    public static IReadOnlyList<Guid> NextToReserve(IEnumerable<QueuedTeam> queue, int freeSlots)
    {
        if (freeSlots <= 0)
        {
            return [];
        }

        return queue
            .OrderBy(q => q.ClosedAt)
            .ThenBy(q => q.CreatedAt)
            .ThenBy(q => q.TeamId)
            .Take(freeSlots)
            .Select(q => q.TeamId)
            .ToList();
    }

    /// <summary>Posição na fila (1 = próxima a receber vaga), ou null se a equipa não está na fila.</summary>
    public static int? QueuePosition(IEnumerable<QueuedTeam> queue, Guid teamId)
    {
        var ordered = queue.OrderBy(q => q.ClosedAt).ThenBy(q => q.CreatedAt).ThenBy(q => q.TeamId).ToList();
        var index = ordered.FindIndex(q => q.TeamId == teamId);
        return index < 0 ? null : index + 1;
    }

    public static DateTime ExpiresAt(DateTime reservedAt) => reservedAt.AddMinutes(ReservationMinutes);

    public static DateTime PenaltyUntil(DateTime now) => now.AddMinutes(PenaltyMinutes);

    public static bool IsExpired(DateTime? expiresAt, DateTime now) => expiresAt is not null && expiresAt <= now;

    public static bool IsPenalized(DateTime? penaltyUntil, DateTime now) => penaltyUntil is not null && penaltyUntil > now;

    /// <summary>
    /// Quem é penalizado quando a reserva expira: no modo dividido, quem não pagou; no modo total,
    /// só o líder (era ele quem tinha de pagar) se não pagou.
    /// </summary>
    public static bool IsPenalizedOnExpiry(string mode, bool isHost, bool paid) =>
        !paid && (mode == Split || isHost);

    /// <summary>
    /// Se o utilizador pode pagar agora, ou o motivo (código) de não poder:
    /// team_not_closed, team_in_queue, team_confirmed, reservation_expired, only_host_pays, already_paid.
    /// </summary>
    public static string? WhyCannotPay(
        string state, bool expired, string? mode, bool isHost, bool alreadyPaid)
    {
        switch (state)
        {
            case Forming:
                return "team_not_closed";
            case Queued:
                return "team_in_queue";
            case Confirmed:
                return "team_confirmed";
        }

        if (expired)
        {
            return "reservation_expired";
        }

        if (mode == Total && !isHost)
        {
            return "only_host_pays";
        }

        return alreadyPaid ? "already_paid" : null;
    }

    /// <summary>Todos pagaram (no modo total o pagamento do líder marca toda a gente como paga).</summary>
    public static bool AllPaid(int members, int paid) => members > 0 && paid >= members;
}
