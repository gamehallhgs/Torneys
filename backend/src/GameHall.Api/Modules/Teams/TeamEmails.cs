namespace GameHall.Api.Modules.Teams;

/// <summary>Emails de aviso (texto simples). Dizem sempre para abrir a app: não levam ligações.</summary>
public static class TeamEmails
{
    public static (string Subject, string Body) JoinRequest(string hostName, string playerName, string teamName, string tournamentName) => (
        $"Novo pedido para entrar na equipa {teamName}",
        $"""
        Olá {hostName},

        {playerName} pediu para entrar na tua equipa "{teamName}" no torneio "{tournamentName}".

        Abre a app GameHall Torneios, vai à equipa e aceita ou rejeita o pedido.
        """);

    public static (string Subject, string Body) Invite(string playerName, string hostName, string teamName, string tournamentName) => (
        $"Convite para a equipa {teamName}",
        $"""
        Olá {playerName},

        {hostName} convidou-te para a equipa "{teamName}" no torneio "{tournamentName}".

        Abre a app GameHall Torneios, vai a "As minhas equipas" e aceita ou recusa o convite.
        """);

    /// <summary>
    /// Email de aviso a partir de uma notificação de equipa (vaga reservada, falta 5 minutos, equipa confirmada):
    /// o mesmo texto que a pessoa vê na app.
    /// </summary>
    public static (string Subject, string Body) FromNotification(string playerName, string title, string teamName, string message) => (
        $"{title}: equipa {teamName}",
        $"""
        Olá {playerName},

        {message}

        Abre a app GameHall Torneios para ver os detalhes.
        """);
}
