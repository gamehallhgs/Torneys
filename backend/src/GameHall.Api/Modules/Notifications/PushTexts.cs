namespace GameHall.Api.Modules.Notifications;

/// <summary>Textos curtos dos push (o ecrã de bloqueio mostra pouco). Funções puras, testáveis.</summary>
public static class PushTexts
{
    public const string InviteTitle = "Convite para uma equipa";
    public const string RequestTitle = "Pedido para entrar na equipa";

    public static string Invite(string inviterName, string teamName) =>
        $"{inviterName} convidou-te para a equipa {teamName}.";

    public static string Request(string playerName, string teamName) =>
        $"{playerName} quer entrar na equipa {teamName}.";
}
