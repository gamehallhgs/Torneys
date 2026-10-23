namespace GameHall.Api.Infrastructure.Email;

/// <summary>Emails em texto simples (sem HTML: mais seguros e sem rastreio).</summary>
public static class EmailTemplates
{
    public static (string Subject, string Body) VerifyEmail(string name, string code, int minutes) => (
        "O teu código de verificação GameHall",
        $"""
        Olá {name},

        O teu código de verificação é: {code}

        O código expira em {minutes} minutos. Se não criaste uma conta no GameHall Torneios, ignora este email.
        """);

    public static (string Subject, string Body) AlreadyRegistered(string name) => (
        "Tentativa de registo com o teu email",
        $"""
        Olá {name},

        Alguém tentou criar uma conta no GameHall Torneios com este email, mas já existe uma conta associada.

        Se foste tu, inicia sessão normalmente ou usa "Esqueci-me da palavra-passe". Se não foste tu, podes ignorar esta mensagem.
        """);

    public static (string Subject, string Body) ResetPassword(string name, string code, int minutes) => (
        "Código para repor a palavra-passe",
        $"""
        Olá {name},

        Recebemos um pedido para repor a palavra-passe da tua conta. O teu código é: {code}

        O código expira em {minutes} minutos. Se não fizeste este pedido, ignora este email: a tua palavra-passe não foi alterada.
        """);

    public static (string Subject, string Body) PasswordChanged(string name) => (
        "A tua palavra-passe foi alterada",
        $"""
        Olá {name},

        A palavra-passe da tua conta GameHall foi alterada e todas as sessões foram terminadas.

        Se não foste tu, repõe a palavra-passe de imediato e contacta o suporte.
        """);

    public static (string Subject, string Body) AccountLocked(string name, int minutes) => (
        "A tua conta foi bloqueada temporariamente",
        $"""
        Olá {name},

        Houve várias tentativas falhadas de início de sessão na tua conta. Por segurança, bloqueámo-la durante {minutes} minutos.

        Se não foste tu, considera repor a palavra-passe.
        """);

    public static (string Subject, string Body) AccountDeleted(string name) => (
        "A tua conta foi eliminada",
        $"""
        Olá {name},

        Confirmamos que a tua conta no GameHall Torneios foi eliminada e os teus dados pessoais foram anonimizados.
        """);
}
