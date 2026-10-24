using System.Text.RegularExpressions;

namespace GameHall.Api.Modules.Auth;

/// <summary>Regras puras do username (@hugo) e da tag (#482). Sem base de dados.</summary>
public static partial class UsernameRules
{
    public const int MinLength = 3;
    public const int MaxLength = 20;
    public const int TagLength = 3;

    /// <summary>Quantos dias o username antigo fica reservado e o tempo mínimo entre mudanças.</summary>
    public const int ChangeCooldownDays = 30;
    public const int ReservedAfterChangeDays = 30;

    /// <summary>Tentativas falhadas de convidar por username#tag permitidas por hora, por utilizador.</summary>
    public const int MaxFailedLookupsPerHour = 10;

    // 3 a 20: minúsculas, números, "." e "_"; começa e acaba em letra/número.
    [GeneratedRegex(@"^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]$")]
    private static partial Regex Shape();

    [GeneratedRegex(@"^[0-9]{3}$")]
    private static partial Regex TagShape();

    /// <summary>
    /// Nomes que ninguém pode escolher (iguais, sem distinguir maiúsculas). Lista para rever e ajustar.
    /// Além destes, qualquer username que CONTENHA <see cref="BlockedFragments"/> também é recusado.
    /// </summary>
    public static readonly IReadOnlySet<string> Reserved = new HashSet<string>(StringComparer.Ordinal)
    {
        // Administração e suporte
        "admin", "administrador", "administrator", "root", "system", "sistema", "suporte", "support",
        "ajuda", "help", "moderador", "moderator", "mod", "staff", "equipa.gamehall", "oficial", "official",
        // Papéis da plataforma
        "arbitro", "referee", "gestor", "manager", "organizador", "organizer", "capitao", "lider",
        // Palavras da app (evitam confusão e rotas)
        "torneio", "torneios", "tournament", "tournaments", "jogo", "jogos", "lobby", "convite", "convites",
        "notificacoes", "perfil", "profile", "conta", "account", "login", "logout", "registar", "register",
        "api", "www", "app", "home", "settings", "definicoes", "equipa", "equipas", "team", "teams",
        // Genéricos que enganam ("falar com o @todos")
        "todos", "all", "everyone", "here", "me", "eu", "tu", "null", "undefined", "anonymous", "anonimo",
        "user", "users", "utilizador", "jogador", "player", "removido", "deleted",
        // Entidades do futebol
        "fpf", "uefa", "fifa", "liga", "ligaportugal", "selecao"
    };

    public static readonly IReadOnlyList<string> BlockedFragments = ["gamehall"];

    /// <summary>"  @Hugo " -> "hugo" (tira espaços e o @ inicial, passa a minúsculas).</summary>
    public static string Normalize(string? raw)
    {
        var s = (raw ?? "").Trim();
        if (s.StartsWith('@'))
        {
            s = s[1..];
        }

        return s.ToLowerInvariant();
    }

    /// <summary>Mensagem de erro (em português) ou null se o username (já normalizado) for válido.</summary>
    public static string? Validate(string username)
    {
        if (username.Length < MinLength || username.Length > MaxLength)
        {
            return "O username deve ter entre 3 e 20 caracteres.";
        }

        if (!IsWellFormed(username) && !username.Contains("..", StringComparison.Ordinal))
        {
            return "Usa só letras minúsculas, números, \".\" e \"_\", e não comeces nem acabes com \".\" ou \"_\".";
        }

        if (username.Contains("..", StringComparison.Ordinal))
        {
            return "Não uses dois pontos seguidos.";
        }

        if (IsReserved(username))
        {
            return "Este username não está disponível.";
        }

        return null;
    }

    public static bool IsReserved(string username) =>
        Reserved.Contains(username) || BlockedFragments.Any(f => username.Contains(f, StringComparison.Ordinal));

    public static bool IsValidTag(string? tag) => tag is not null && TagShape().IsMatch(tag);

    /// <summary>Tag ao acaso "000" a "999".</summary>
    public static string NewTag() =>
        System.Security.Cryptography.RandomNumberGenerator.GetInt32(0, 1000).ToString("D3");

    /// <summary>
    /// "hugo#482", "@Hugo#482" -> ("hugo", "482"). Devolve null se não tiver o formato certo
    /// (a tag é obrigatória). Não verifica se o utilizador existe.
    /// </summary>
    public static (string Username, string Tag)? ParseHandle(string? input)
    {
        var s = (input ?? "").Trim();
        var hash = s.LastIndexOf('#');
        if (hash < 1)
        {
            return null;
        }

        var username = Normalize(s[..hash]);
        var tag = s[(hash + 1)..].Trim();
        return IsWellFormed(username) && IsValidTag(tag) ? (username, tag) : null;
    }

    /// <summary>Formato certo (comprimento, caracteres, sem ".."), sem olhar para nomes reservados.</summary>
    private static bool IsWellFormed(string username) =>
        Shape().IsMatch(username) && !username.Contains("..", StringComparison.Ordinal);

    /// <summary>Quando é que o utilizador volta a poder mudar o username (null = já pode).</summary>
    public static DateTime? NextChangeAt(DateTime? lastChangedAt, DateTime now)
    {
        if (lastChangedAt is null)
        {
            return null;
        }

        var next = lastChangedAt.Value.AddDays(ChangeCooldownDays);
        return next > now ? next : null;
    }
}
