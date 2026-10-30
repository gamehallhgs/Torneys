namespace GameHall.Api.Modules.Games;

/// <summary>
/// Monta o plantel de uma equipa para um jogo. Com formação e titulares definidos pelo líder é um plantel
/// formal (campo + suplentes); senão é só a lista dos membros, do guarda-redes ao avançado.
/// </summary>
public static class SquadRules
{
    /// <summary>Ordem das posições na lista (guarda-redes primeiro, avançado por fim; sem posição no fim).</summary>
    public static readonly string[] PositionOrder =
        ["GK", "RB", "CB", "LB", "RWB", "LWB", "CDM", "CM", "CAM", "RM", "LM", "RW", "LW", "CF", "ST"];

    public static int PositionRank(string? position)
    {
        var i = position is null ? -1 : Array.IndexOf(PositionOrder, position);
        return i < 0 ? PositionOrder.Length : i;
    }

    public static SquadDto Build(IReadOnlyList<SquadRow> rows)
    {
        var first = rows[0];
        var starters = rows.Count(r => r.Slot is not null);
        var formal = Teams.Formations.IsLineupComplete(first.Sport, first.Formation, starters, rows.Count);

        // Formal: titulares por lugar e depois suplentes. Informal: toda a gente por posição.
        var players = formal
            ? rows.OrderBy(r => r.Slot is null).ThenBy(r => r.Slot).ThenBy(r => PositionRank(r.Position))
            : rows.OrderBy(r => PositionRank(r.Position)).ThenBy(r => r.DisplayName);

        return new SquadDto(
            formal ? first.Formation : null,
            players.Select(r => new SquadPlayerDto(r.DisplayName, r.Position, formal ? r.Slot : null, formal && r.Slot is not null)).ToList(),
            formal);
    }
}
