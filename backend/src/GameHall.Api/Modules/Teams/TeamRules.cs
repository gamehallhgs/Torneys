using System.Text.RegularExpressions;

namespace GameHall.Api.Modules.Teams;

/// <summary>Regras puras das equipas (sem base de dados).</summary>
public static partial class TeamRules
{
    /// <summary>Posições do FIFA: GK, RB, CB, LB, RWB, LWB, CDM, CM, CAM, RM, LM, RW, LW, CF, ST.</summary>
    public static readonly string[] Positions =
        ["GK", "RB", "CB", "LB", "RWB", "LWB", "CDM", "CM", "CAM", "RM", "LM", "RW", "LW", "CF", "ST"];

    public const int MaxPendingInvitesPerTeam = 20;

    [GeneratedRegex(@"\s+")]
    private static partial Regex Spaces();

    [GeneratedRegex(@"^[\p{L}\p{N}][\p{L}\p{N} .'&\-]{2,29}$")]
    private static partial Regex NameShape();

    [GeneratedRegex(@"^#[0-9A-Fa-f]{6}$")]
    private static partial Regex ColorShape();

    /// <summary>Tira espaços nas pontas e junta espaços repetidos.</summary>
    public static string NormalizeName(string? raw) => Spaces().Replace((raw ?? "").Trim(), " ");

    /// <summary>Mensagem de erro, ou null se o nome (já normalizado) for válido: 3 a 30 caracteres.</summary>
    public static string? ValidateName(string name) =>
        NameShape().IsMatch(name)
            ? null
            : "O nome deve ter entre 3 e 30 caracteres (letras, números, espaços e . ' & -).";

    /// <summary>"#e53935" -> "#E53935"; null se não for uma cor #RRGGBB.</summary>
    public static string? NormalizeColor(string? raw) =>
        raw is not null && ColorShape().IsMatch(raw.Trim()) ? raw.Trim().ToUpperInvariant() : null;

    public static bool IsValidPosition(string? position) =>
        position is not null && Positions.Contains(position);

    /// <summary>O líder convida sempre; os outros membros só se o líder o permitir.</summary>
    public static bool CanInvite(bool isHost, bool isMember, bool membersCanInvite) =>
        isHost || (isMember && membersCanInvite);

    /// <summary>
    /// Motivo (código) pelo qual o utilizador NÃO pode pedir para entrar nesta equipa, ou null se pode.
    /// </summary>
    public static string? JoinBlockedReason(
        bool teamHasHost, bool isMember, string tournamentStatus, bool inOtherTeamOfTournament,
        int minAge, int? maxAge, int userAge, int membersCount, int maxPlayers, bool hasPendingRequest,
        bool teamConfirmed = false, bool lobbyClosed = false)
    {
        if (!teamHasHost)
        {
            return "team_not_joinable";
        }

        if (isMember)
        {
            return "already_member";
        }

        if (tournamentStatus != "registration_open")
        {
            return "registration_closed";
        }

        // Equipa confirmada = fechada (já tem todos os jogadores e todos pagaram).
        if (teamConfirmed)
        {
            return "team_confirmed";
        }

        if (inOtherTeamOfTournament)
        {
            return "already_in_team";
        }

        if (userAge < minAge)
        {
            return "age_too_young";
        }

        if (maxAge is not null && userAge > maxAge)
        {
            return "age_too_old";
        }

        if (membersCount >= maxPlayers)
        {
            return "team_full";
        }

        // O líder fechou o lobby a pedidos: só entra quem for convidado.
        if (lobbyClosed)
        {
            return "lobby_closed";
        }

        return hasPendingRequest ? "request_pending" : null;
    }
}
