using System.Globalization;
using System.Text;

namespace GameHall.Api.Common;

/// <summary>
/// Lista (curta, de propósito) de palavras que não podem aparecer em usernames, nomes de equipas e nomes de
/// jogador. Para mudar a lista basta editar este ficheiro: nada mais depende dele.
///
/// Quanto mais palavras, mais nomes verdadeiros ficam de fora ("Scunthorpe problem"): por isso só entram as
/// mais graves, e as que se confundem com palavras normais só valem como palavra inteira.
/// O resto fica para os admins: podem bloquear a conta (ver docs/PAPEIS_E_PERMISSOES.md).
/// </summary>
public static class ProfanityWords
{
    /// <summary>
    /// Proibidas mesmo dentro de outra palavra ("xcaralhox", "c.a.r.a.l.h.o"). Só palavras longas e sem
    /// uso inocente em nomes portugueses.
    /// </summary>
    public static readonly string[] Anywhere =
    [
        "caralho",     // pedido por ti
        "fodasse",     // pedido por ti (cobre também "fodase")
        "paneleiro",   // sugestão: insulto homofóbico muito comum
    ];

    /// <summary>
    /// Proibidas só como palavra inteira (separada por espaço, ".", "_", "-" ou números). Assim "computador",
    /// "reputação", "disputa", "puto" ou "Fodão" (apelido raro) não são apanhados por engano.
    /// </summary>
    public static readonly string[] WholeWord =
    [
        "puta", "putas",                       // pedido por ti
        "cabrao", "cabroes",                   // pedido por ti ("cabrão" sem acento)
        "foda", "fodas", "foder", "fodeu",     // família de "fodasse"
        "fdp",                                 // sugestão: sigla muito usada
        "nazi", "hitler",                      // sugestão: nomes de ódio
    ];
}

/// <summary>
/// Verifica se um texto tem uma palavra da <see cref="ProfanityWords"/>. Ignora maiúsculas, acentos, letras repetidas
/// ("caaaralho") e trocas comuns de letras por números/símbolos ("c4r4lh0", "pu7a", "f0da-se").
/// </summary>
public static class ProfanityFilter
{
    public const string Message = "Este nome não é permitido. Escolhe outro.";

    private static readonly string[] Anywhere = ProfanityWords.Anywhere.Select(Collapse).ToArray();
    private static readonly HashSet<string> Whole = ProfanityWords.WholeWord.Select(Collapse).ToHashSet();

    public static bool Contains(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        // Duas leituras: com números como letras (c4ralho) e com números como separadores (puta2).
        return Check(text, leet: true) || Check(text, leet: false);
    }

    private static bool Check(string text, bool leet)
    {
        var tokens = Tokens(text, leet);
        if (tokens.Any(t => Whole.Contains(t) || Anywhere.Any(a => t.Contains(a, StringComparison.Ordinal))))
        {
            return true;
        }

        // "c.a.r.a.l.h.o" / "car alho": junta tudo e procura só as palavras longas.
        var joined = string.Concat(tokens);
        return Anywhere.Any(a => joined.Contains(a, StringComparison.Ordinal));
    }

    /// <summary>Texto em minúsculas, sem acentos, com letras repetidas juntas, dividido em palavras (só a-z).</summary>
    private static List<string> Tokens(string text, bool leet)
    {
        var decomposed = text.ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var tokens = new List<string>();
        var cur = new StringBuilder();

        void Flush()
        {
            if (cur.Length > 0)
            {
                tokens.Add(Collapse(cur.ToString()));
                cur.Clear();
            }
        }

        foreach (var ch0 in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch0) == UnicodeCategory.NonSpacingMark)
            {
                continue;   // tira o acento
            }

            var ch = leet ? Leet(ch0) : ch0;
            if (ch is >= 'a' and <= 'z')
            {
                cur.Append(ch);
            }
            else
            {
                Flush();
            }
        }

        Flush();
        return tokens;
    }

    private static char Leet(char c) => c switch
    {
        '0' => 'o',
        '1' => 'i',
        '3' => 'e',
        '4' => 'a',
        '5' => 's',
        '7' => 't',
        '@' => 'a',
        '$' => 's',
        '!' => 'i',
        _ => c,
    };

    /// <summary>"caaaralho" -> "caralho" (letras iguais seguidas contam como uma).</summary>
    private static string Collapse(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (var c in s)
        {
            if (sb.Length == 0 || sb[^1] != c)
            {
                sb.Append(c);
            }
        }

        return sb.ToString();
    }
}
