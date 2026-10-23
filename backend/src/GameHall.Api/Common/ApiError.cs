namespace GameHall.Api.Common;

/// <summary>
/// Erro devolvido ao cliente em formato ProblemDetails. O campo "code" é estável (inglês, snake_case)
/// para a app mapear para mensagens traduzidas; "title" é uma mensagem em português.
/// </summary>
public sealed record ApiError(int Status, string Code, string Message, IDictionary<string, string[]>? Fields = null)
{
    public IResult ToResult()
    {
        var extensions = new Dictionary<string, object?> { ["code"] = Code };
        if (Fields is { Count: > 0 })
        {
            extensions["errors"] = Fields;
        }

        return Results.Problem(statusCode: Status, title: Message, extensions: extensions);
    }

    public static ApiError Validation(IDictionary<string, string[]> fields) =>
        new(StatusCodes.Status400BadRequest, "validation_error", "Alguns campos são inválidos.", fields);
}

public readonly record struct Outcome<T>(T? Value, ApiError? Error)
{
    public bool IsOk => Error is null;

    public static Outcome<T> Ok(T value) => new(value, null);

    public static Outcome<T> Fail(ApiError error) => new(default, error);
}

public static class Errors
{
    public static readonly ApiError InvalidCredentials =
        new(StatusCodes.Status401Unauthorized, "invalid_credentials", "Email ou palavra-passe incorretos.");

    public static readonly ApiError EmailNotVerified =
        new(StatusCodes.Status403Forbidden, "email_not_verified", "Confirma o teu email antes de iniciares sessão.");

    public static readonly ApiError InvalidCode =
        new(StatusCodes.Status400BadRequest, "invalid_code", "Código inválido ou expirado.");

    public static readonly ApiError InvalidRefreshToken =
        new(StatusCodes.Status401Unauthorized, "invalid_refresh_token", "Sessão inválida ou expirada. Inicia sessão novamente.");

    public static readonly ApiError LegalNotAccepted =
        new(StatusCodes.Status400BadRequest, "legal_not_accepted",
            "É necessário aceitar os Termos e Condições e a Política de Privacidade.");

    public static readonly ApiError LegalVersionOutdated =
        new(StatusCodes.Status409Conflict, "legal_version_outdated",
            "Os documentos legais foram atualizados. Lê e aceita as versões atuais.");

    public static readonly ApiError UserNotFound =
        new(StatusCodes.Status404NotFound, "user_not_found", "Utilizador não encontrado.");

    public static ApiError AgeTooYoung(int minimumAge) =>
        new(StatusCodes.Status403Forbidden, "age_too_young",
            $"Tens de ter pelo menos {minimumAge} anos para criar conta.");
}
