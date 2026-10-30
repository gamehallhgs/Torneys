namespace GameHall.Api.Infrastructure.Push;

/// <summary>Uma notificação push. Data = pares texto/texto que a app usa para abrir o ecrã certo.</summary>
public sealed record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

public interface IPushSender
{
    /// <summary>
    /// Envia a mensagem a cada token. Devolve os tokens que já não servem (app desinstalada, token antigo):
    /// quem chama apaga-os da base de dados.
    /// </summary>
    Task<IReadOnlyList<string>> SendAsync(PushMessage message, IReadOnlyCollection<string> tokens, CancellationToken ct);
}

public sealed class PushOptions
{
    public const string Section = "Push";

    /// <summary>"log" (desenvolvimento: só escreve no log) ou "fcm" (Firebase Cloud Messaging).</summary>
    public string Provider { get; set; } = "log";

    public FcmOptions Fcm { get; set; } = new();
}

public sealed class FcmOptions
{
    /// <summary>ID do projeto no Firebase (Definições do projeto).</summary>
    public string ProjectId { get; set; } = "";

    /// <summary>Caminho para o ficheiro JSON da conta de serviço (Firebase > Contas de serviço > Gerar chave).</summary>
    public string ServiceAccountFile { get; set; } = "";
}

/// <summary>Desenvolvimento / sem Firebase: escreve no log o que seria enviado. Nada sai da máquina.</summary>
public sealed class LoggingPushSender(ILogger<LoggingPushSender> log) : IPushSender
{
    public Task<IReadOnlyList<string>> SendAsync(PushMessage message, IReadOnlyCollection<string> tokens, CancellationToken ct)
    {
        log.LogInformation("[push simulado] {Title} — {Body} (para {Count} dispositivo(s))", message.Title, message.Body, tokens.Count);
        return Task.FromResult<IReadOnlyList<string>>([]);
    }
}
