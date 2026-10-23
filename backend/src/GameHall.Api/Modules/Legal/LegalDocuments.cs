using GameHall.Api.Common;
using GameHall.Api.Infrastructure.Security;
using Microsoft.Extensions.Options;

namespace GameHall.Api.Modules.Legal;

public sealed record LegalDoc(string Type, string Version, string Text, string Hash);

/// <summary>
/// Carrega os textos legais (ficheiros Markdown na pasta Legal/) e a respetiva versão.
/// O hash do texto fica guardado em cada consentimento como prova do que o utilizador aceitou.
/// </summary>
public sealed class LegalDocuments
{
    private const string Placeholder = "[PREENCHER";

    public LegalDoc Terms { get; }
    public LegalDoc Privacy { get; }

    public LegalDocuments(IOptions<LegalOptions> options, IHostEnvironment env)
    {
        var dir = Path.Combine(AppContext.BaseDirectory, "Legal");
        Terms = Load(dir, "terms", "termos-e-condicoes.pt.md", options.Value.TermsVersion);
        Privacy = Load(dir, "privacy", "politica-de-privacidade.pt.md", options.Value.PrivacyVersion);

        // Rede de segurança: em produção, a API não arranca com textos legais por preencher.
        if (env.IsProduction() &&
            (Terms.Text.Contains(Placeholder, StringComparison.Ordinal) ||
             Privacy.Text.Contains(Placeholder, StringComparison.Ordinal)))
        {
            throw new InvalidOperationException(
                "Os textos legais em Legal/*.md ainda contêm campos [PREENCHER ...]. " +
                "Preenche-os (e pede revisão jurídica) antes de usar em produção.");
        }
    }

    public LegalDoc? Get(string type) => type switch
    {
        "terms" => Terms,
        "privacy" => Privacy,
        _ => null
    };

    private static LegalDoc Load(string dir, string type, string fileName, string version)
    {
        var path = Path.Combine(dir, fileName);
        if (!File.Exists(path))
        {
            throw new InvalidOperationException($"Texto legal não encontrado: {path}");
        }

        var text = File.ReadAllText(path).Replace("\r\n", "\n");
        return new LegalDoc(type, version, text, Hashing.Sha256Hex(text));
    }
}
