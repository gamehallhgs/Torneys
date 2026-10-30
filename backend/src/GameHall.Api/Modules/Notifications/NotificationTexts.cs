namespace GameHall.Api.Modules.Notifications;

/// <summary>Textos (em português) das notificações de equipa. Funções puras, testáveis.</summary>
public static class NotificationTexts
{
    /// <summary>715 -> "7,15 €"; 5000 -> "50 €"; 0 -> "0 €".</summary>
    public static string Money(int cents)
    {
        if (cents <= 0)
        {
            return "0 €";
        }

        var rest = cents % 100;
        return rest == 0 ? $"{cents / 100} €" : $"{cents / 100},{rest:00} €";
    }

    /// <summary>A frase sobre quem paga o quê (para cada membro).</summary>
    public static string Payment(string? mode, int shareCents, bool isHost, bool reserved, int reservationMinutes)
    {
        var who = mode == "total"
            ? (isHost
                ? $"Pagas {Money(shareCents)} por toda a equipa."
                : "O líder paga por toda a equipa: tu não tens de pagar.")
            : $"Cada jogador paga a sua parte: {Money(shareCents)}.";

        var mustPay = mode != "total" || isHost;
        if (!reserved)
        {
            return $"{who} Neste momento não há vaga livre: a equipa ficou em fila e avisamos quando houver vaga para pagarem.";
        }

        return mustPay ? $"{who} Tens {reservationMinutes} minutos para pagar." : $"{who} A vaga está reservada por {reservationMinutes} minutos.";
    }

    public static string ClosedTitle => "Equipa fechada";

    public static string Closed(
        string teamName, string tournamentName, string? mode, int shareCents, bool isHost, bool reserved, int minutes) =>
        $"O líder fechou a equipa {teamName} ({tournamentName}). " + Payment(mode, shareCents, isHost, reserved, minutes);

    public static string SlotReservedTitle => "Vaga reservada";

    public static string SlotReserved(
        string teamName, string tournamentName, string? mode, int shareCents, bool isHost, int minutes) =>
        $"Há vaga para a equipa {teamName} ({tournamentName})! " + Payment(mode, shareCents, isHost, true, minutes);

    public static string RequestAcceptedTitle => "Pedido aceite";
    public static string RequestRejectedTitle => "Pedido recusado";

    public static string RequestAccepted(string teamName, string tournamentName) =>
        $"O líder aceitou o teu pedido: já fazes parte da equipa {teamName} ({tournamentName}).";

    public static string RequestRejected(string teamName, string tournamentName) =>
        $"O líder da equipa {teamName} ({tournamentName}) recusou o teu pedido.";

    public static string ExpiringTitle => "Tempo a acabar";

    public static string Expiring(string teamName, int minutesLeft, bool mustPay) =>
        mustPay
            ? $"Faltam cerca de {minutesLeft} minutos para pagar a vaga da equipa {teamName}. Quem não pagar a tempo fica penalizado."
            : $"Faltam cerca de {minutesLeft} minutos para a equipa {teamName} pagar a vaga.";

    public static string ExpiredTitle => "Reserva expirada";

    public static string Expired(string teamName, bool penalized, int penaltyMinutes) =>
        penalized
            ? $"O tempo para pagar a vaga da equipa {teamName} acabou. Ficas {penaltyMinutes} minutos sem poder entrar em equipas deste torneio. A equipa voltou à formação."
            : $"O tempo para pagar a vaga da equipa {teamName} acabou. A equipa voltou à formação e não pagas nada.";

    public static string EliminatedTitle => "Equipa eliminada";

    public static string Eliminated(string teamName, string tournamentName, bool deadline) =>
        deadline
            ? $"A equipa {teamName} foi eliminada de {tournamentName}: as inscrições terminaram sem a equipa estar fechada."
            : $"A equipa {teamName} foi eliminada de {tournamentName}: todas as vagas ficaram confirmadas.";

    public static string MemberJoinedTitle => "Novo jogador na equipa";

    public static string MemberJoinedText(string playerName, string teamName) =>
        $"{playerName} entrou na equipa {teamName} com o código de convite.";

    public static string RemovedTitle => "Foste removido da equipa";

    public static string Removed(string teamName, string tournamentName) =>
        $"O líder da equipa {teamName} ({tournamentName}) removeu-te da equipa. Podes entrar noutra equipa do torneio.";

    public static string NowLeaderTitle => "Agora és o líder";

    public static string NowLeaderText(string teamName, string tournamentName) =>
        $"A liderança da equipa {teamName} ({tournamentName}) passou para ti. Agora geres o lobby: convites, pedidos, formação e fecho da equipa.";

    public static string ConfirmedTitle => "Equipa confirmada";

    public static string Confirmed(string teamName, string tournamentName) =>
        $"A equipa {teamName} está confirmada no torneio {tournamentName}: todos pagaram e a vaga é vossa.";
}
