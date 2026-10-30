namespace GameHall.Api.Modules.Teams;

/// <summary>
/// Formações por modalidade. "4-4-2" = 4 defesas, 4 médios, 2 avançados (+ guarda-redes, lugar 0).
/// Os lugares numeram-se: 0 = guarda-redes, depois cada linha da defesa para o ataque, da esquerda para a direita.
/// </summary>
public static class Formations
{
    private static readonly Dictionary<string, string[]> BySport = new()
    {
        ["football7"] = ["2-3-1", "3-2-1", "2-2-2", "3-3"],
        ["football9"] = ["3-3-2", "3-4-1", "2-4-2", "4-3-1"],
        ["football11"] = ["4-4-2", "4-3-3", "3-5-2", "4-2-3-1", "5-3-2"],
        ["futsal"] = ["1-2-1", "2-2", "1-1-2", "3-1"],
    };

    public static IReadOnlyList<string> For(string sport) =>
        BySport.TryGetValue(sport, out var list) ? list : [];

    public static string Default(string sport) => For(sport).FirstOrDefault() ?? "";

    public static bool IsValid(string sport, string? formation) =>
        formation is not null && For(sport).Contains(formation);

    /// <summary>Número de lugares em campo (guarda-redes incluído).</summary>
    public static int SlotCount(string formation) =>
        1 + formation.Split('-').Sum(int.Parse);

    /// <summary>
    /// O plantel por defeito está definido? Formação escolhida e todos os lugares preenchidos
    /// (ou todos os jogadores em campo, se a equipa tem menos jogadores do que lugares).
    /// </summary>
    public static bool IsLineupComplete(string sport, string? formation, int starters, int members) =>
        IsValid(sport, formation) && starters >= Math.Min(SlotCount(formation!), members);

    /// <summary>
    /// Valida a escolha do líder: formação da modalidade, lugares dentro do campo e sem repetições, só membros
    /// da equipa e cada membro no máximo uma vez. Devolve a mensagem de erro (null = válida).
    /// </summary>
    public static string? Validate(
        string sport, string? formation, IReadOnlyList<(Guid UserId, int Slot)> slots, ISet<Guid> memberIds)
    {
        if (!IsValid(sport, formation))
        {
            return "Formação inválida para esta modalidade.";
        }

        var count = SlotCount(formation!);
        if (slots.Any(s => s.Slot < 0 || s.Slot >= count))
        {
            return "Lugar fora do campo.";
        }

        if (slots.Select(s => s.Slot).Distinct().Count() != slots.Count)
        {
            return "Dois jogadores no mesmo lugar.";
        }

        if (slots.Select(s => s.UserId).Distinct().Count() != slots.Count)
        {
            return "O mesmo jogador em dois lugares.";
        }

        return slots.Any(s => !memberIds.Contains(s.UserId)) ? "Só podes escolher jogadores da equipa." : null;
    }
}
