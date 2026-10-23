namespace GameHall.Api.Modules.Games;

/// <summary>Constantes e regras puras dos jogos.</summary>
public static class GameRules
{
    public static readonly string[] Statuses = ["scheduled", "running", "finished", "cancelled", "postponed"];

    public static bool IsValidStatus(string? status) => status is not null && Statuses.Contains(status);

    /// <summary>Tipos de evento que contam nas estatísticas.</summary>
    public const string Goal = "goal";
    public const string Assist = "assist";
    public const string Yellow = "yellow_card";
    public const string Red = "red_card";

    public static readonly string[] StatTypes = [Goal, Assist, Yellow, Red];

    public const int StatsTopN = 10;
}
