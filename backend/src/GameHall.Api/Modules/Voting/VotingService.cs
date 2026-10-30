using GameHall.Api.Common;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Games;
using GameHall.Api.Modules.Tournaments;

namespace GameHall.Api.Modules.Voting;

internal static class VotingErrors
{
    public static readonly ApiError TournamentNotFound =
        new(404, "tournament_not_found", "Torneio não encontrado.");
    public static readonly ApiError InvalidCategory = ApiError.Validation(
        new Dictionary<string, string[]> { ["category"] = ["Categoria inválida."] });
    public static readonly ApiError VotingClosed =
        new(409, "voting_closed", "Não há nenhuma votação aberta neste torneio.");
    public static readonly ApiError CannotVoteSelf =
        new(409, "cannot_vote_self", "Não podes votar em ti próprio.");
    public static readonly ApiError CandidateNotFound =
        new(404, "candidate_not_found", "Esse jogador não está na votação.");
    public static readonly ApiError NotEligible = new(
        403, "email_not_verified_long_enough",
        "Para votar sem teres participado no torneio, o teu email tem de estar verificado há mais de 1 dia.");

    public static ApiError FromOpenReason(string reason) => reason switch
    {
        "tournament_not_finished" => new(409, reason, "O torneio ainda não terminou."),
        "voting_window_closed" => new(409, reason, "Já passou o prazo para abrir votações neste torneio."),
        "round_already_exists" => new(409, reason, "Esta ronda de votação já foi aberta."),
        "no_first_round" => new(409, reason, "Ainda não houve uma primeira votação."),
        "previous_round_open" => new(409, reason, "A votação anterior ainda está a decorrer."),
        "no_tie" => new(409, reason, "Não há empates para desempatar."),
        "round_exceeds_window" => new(
            409, reason, "A ronda tem de acabar dentro do prazo para a votação deste torneio: escolhe uma duração mais curta."),
        _ => new(400, "invalid_duration", "Duração da votação inválida."),
    };
}

/// <summary>
/// Votação do melhor jogador e do melhor guarda-redes de um torneio terminado, mais o pódio.
/// Abrir rondas (<see cref="OpenRoundAsync"/>) é para o painel do gestor, que ainda não existe: por agora só os
/// seeds de desenvolvimento criam rondas. Ver docs/PAPEIS_E_PERMISSOES.md.
/// </summary>
public sealed class VotingService(
    VotingStore store, TournamentStore tournaments, GameStore games, AuthStore users, TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    // ======================= Ler =======================

    public async Task<Outcome<TournamentResultsDto>> GetResultsAsync(Guid tournamentId, Guid userId, CancellationToken ct)
    {
        var t = await tournaments.FindAsync(tournamentId, ct);
        if (t is null)
        {
            return Outcome<TournamentResultsDto>.Fail(VotingErrors.TournamentNotFound);
        }

        if (t.Status != "finished")
        {
            return Outcome<TournamentResultsDto>.Ok(new TournamentResultsDto([], null, null, null));
        }

        var now = Now;
        var podium = await PodiumAsync(t, ct);
        var (rounds, best, gk) = await ResolveAsync(t, now, ct);
        var winnerRows = await store.WinnersAsync(tournamentId, best.Winners.Concat(gk.Winners).Distinct().ToList(), ct);

        AwardDto? Award(CategoryResult r) => r.Status == "none"
            ? null
            : new AwardDto(r.Status, r.Winners
                .Select(id => winnerRows.FirstOrDefault(w => w.UserId == id))
                .OfType<WinnerRow>()
                .Select(w => new AwardWinnerDto(w.UserId, w.DisplayName, w.Position, w.TeamId, w.TeamName, w.ColorHex))
                .ToList());

        var open = rounds.FirstOrDefault(r => VotingRules.IsOpen(r.OpenedAt, r.ClosesAt, now));
        var voting = open is null ? null : await BuildVotingAsync(t, open, userId, now, ct);
        return Outcome<TournamentResultsDto>.Ok(new TournamentResultsDto(podium, Award(best), Award(gk), voting));
    }

    /// <summary>Estado das rondas e resultado (pendente/final/nenhum) de cada categoria num dado momento.</summary>
    private async Task<(IReadOnlyList<RoundRow> Rounds, CategoryResult Best, CategoryResult Goalkeeper)> ResolveAsync(
        TournamentRow t, DateTime now, CancellationToken ct)
    {
        var rounds = await store.RoundsAsync(t.Id, ct);
        var tallies = await store.TalliesAsync(t.Id, ct);
        var windowOpen = VotingRules.WindowOpen(t.FinishedAt, t.VotingWindowHours, now);

        var r1 = rounds.FirstOrDefault(r => r.RoundNumber == 1);
        var r2 = rounds.FirstOrDefault(r => r.RoundNumber == 2);

        IReadOnlyList<Tally> Of(RoundRow r, string category) => tallies
            .Where(x => x.RoundId == r.Id && x.Category == category)
            .Select(x => new Tally(x.CandidateId, x.Votes)).ToList();

        CategoryResult ResolveCategory(string category)
        {
            var r1Closed = r1 is not null && VotingRules.IsClosed(r1.ClosesAt, now);
            var r2HasCategory = r2 is not null && tallies.Any(x => x.RoundId == r2.Id && x.Category == category);
            var r2Closed = r2 is not null && VotingRules.IsClosed(r2.ClosesAt, now);
            return VotingRules.Resolve(
                r1Closed ? Of(r1!, category) : null,
                r2HasCategory,
                r2Closed ? Of(r2!, category) : null,
                windowOpen);
        }

        return (rounds, ResolveCategory(VotingCategories.BestPlayer), ResolveCategory(VotingCategories.BestGoalkeeper));
    }

    /// <summary>
    /// Para o aviso "resultados publicados": null enquanto ainda falta decidir (ronda a decorrer ou empate que o
    /// gestor ainda pode desempatar); senão os vencedores de cada categoria (listas vazias = sem votos).
    /// </summary>
    public async Task<(IReadOnlyList<string> BestPlayer, IReadOnlyList<string> Goalkeeper)?> FinalWinnersAsync(
        TournamentRow t, CancellationToken ct)
    {
        var now = Now;
        var (rounds, best, gk) = await ResolveAsync(t, now, ct);
        if (rounds.Count == 0 || rounds.Any(r => !VotingRules.IsClosed(r.ClosesAt, now))
            || best.Status == CategoryResult.Pending || gk.Status == CategoryResult.Pending)
        {
            return null;
        }

        var rows = await store.WinnersAsync(t.Id, best.Winners.Concat(gk.Winners).Distinct().ToList(), ct);
        IReadOnlyList<string> Names(CategoryResult r) =>
            r.Winners.Select(id => rows.FirstOrDefault(w => w.UserId == id)?.DisplayName).OfType<string>().ToList();
        return (Names(best), Names(gk));
    }

    private async Task<IReadOnlyList<PodiumEntryDto>> PodiumAsync(TournamentRow t, CancellationToken ct)
    {
        if (t.Format == "league")
        {
            var (teams, rows, cards) = await games.StandingsDataAsync(t.Id, ct);
            var groups = StandingsCalculator.BuildGroups(t.Format, teams, rows, cards, t.Tiebreakers);
            return groups.Count == 0 ? [] : PodiumCalculator.FromStandings(groups[0].Rows);
        }

        var list = await games.ListGamesAsync(t.Id, null, ct);
        var teamMap = new Dictionary<Guid, (string Name, string ColorHex)>();
        foreach (var g in list)
        {
            if (g.HomeTeamId is { } h && g.HomeName is not null)
            {
                teamMap[h] = (g.HomeName, g.HomeColor ?? "#888888");
            }

            if (g.AwayTeamId is { } a && g.AwayName is not null)
            {
                teamMap[a] = (g.AwayName, g.AwayColor ?? "#888888");
            }
        }

        return PodiumCalculator.FromKnockout(
            list.Select(g => new PodiumGame(
                g.Stage, g.RoundNumber, g.Status, g.HomeTeamId, g.AwayTeamId,
                g.HomeGoals, g.AwayGoals, g.HomePenalties, g.AwayPenalties)).ToList(),
            teamMap);
    }

    private async Task<VotingDto> BuildVotingAsync(TournamentRow t, RoundRow round, Guid userId, DateTime now, CancellationToken ct)
    {
        var candidates = await store.CandidatesAsync(round.Id, ct);
        var mine = await store.MyVotesAsync(round.Id, userId, ct);
        var user = await users.FindUserByIdAsync(userId, ct);
        var participant = await store.IsParticipantAsync(t.Id, userId, ct);
        var minHours = await store.SettingAsync("voting_min_voter_email_hours", VotingRules.DefaultMinVoterEmailHours, ct);
        var reason = VotingRules.WhyCannotVote(participant, user?.EmailVerifiedAt, now, minHours, true, false);

        var categories = VotingCategories.All
            .Select(cat => new VotingCategoryDto(
                cat,
                mine.FirstOrDefault(m => m.Category == cat)?.CandidateId,
                candidates.Where(c => c.Category == cat)
                    .Select(c => new CandidateDto(c.UserId, c.DisplayName, c.Position, c.TeamId, c.TeamName, c.ColorHex))
                    .ToList()))
            .Where(c => c.Candidates.Count > 0)
            .ToList();

        return new VotingDto(round.RoundNumber, round.ClosesAt, reason is null, reason, categories);
    }

    // ======================= Votar =======================

    /// <summary>Vota (ou muda o voto) numa categoria da ronda aberta.</summary>
    public async Task<ApiError?> VoteAsync(Guid tournamentId, Guid userId, string? category, Guid? candidateId, CancellationToken ct)
    {
        if (category is null || !VotingCategories.All.Contains(category) || candidateId is null)
        {
            return VotingErrors.InvalidCategory;
        }

        var t = await tournaments.FindAsync(tournamentId, ct);
        if (t is null)
        {
            return VotingErrors.TournamentNotFound;
        }

        var now = Now;
        var open = t.Status == "finished"
            ? (await store.RoundsAsync(tournamentId, ct)).FirstOrDefault(r => VotingRules.IsOpen(r.OpenedAt, r.ClosesAt, now))
            : null;
        var user = await users.FindUserByIdAsync(userId, ct);
        if (user is null)
        {
            return Errors.InvalidCredentials;
        }

        var participant = open is not null && await store.IsParticipantAsync(tournamentId, userId, ct);
        var minHours = await store.SettingAsync("voting_min_voter_email_hours", VotingRules.DefaultMinVoterEmailHours, ct);
        var reason = VotingRules.WhyCannotVote(
            participant, user.EmailVerifiedAt, now, minHours, open is not null, candidateId == userId);
        if (reason is not null)
        {
            return reason switch
            {
                "voting_closed" => VotingErrors.VotingClosed,
                "cannot_vote_self" => VotingErrors.CannotVoteSelf,
                _ => VotingErrors.NotEligible,
            };
        }

        if (!await store.IsCandidateAsync(open!.Id, category, candidateId.Value, ct))
        {
            return VotingErrors.CandidateNotFound;
        }

        await store.UpsertVoteAsync(open.Id, category, userId, candidateId.Value, now, ct);
        return null;
    }

    // ======================= Abrir ronda (painel do gestor, mais tarde) =======================

    /// <summary>
    /// Abre a ronda seguinte: 1 se ainda não houve votação; senão a 2 (desempate) só com as categorias empatadas
    /// e só com os empatados. O gestor só o pode fazer dentro da janela depois de o torneio terminar.
    /// </summary>
    public async Task<Outcome<int>> OpenRoundAsync(Guid tournamentId, int durationMinutes, CancellationToken ct)
    {
        var t = await tournaments.FindAsync(tournamentId, ct);
        if (t is null)
        {
            return Outcome<int>.Fail(VotingErrors.TournamentNotFound);
        }

        var now = Now;
        var rounds = await store.RoundsAsync(tournamentId, ct);
        var roundNumber = rounds.Count == 0 ? 1 : 2;
        var r1 = rounds.FirstOrDefault(r => r.RoundNumber == 1);

        IReadOnlyDictionary<string, IReadOnlyList<Guid>>? tied = null;
        if (roundNumber == 2 && r1 is not null)
        {
            var tallies = await store.TalliesAsync(tournamentId, ct);
            var byCategory = VotingCategories.All.ToDictionary(
                c => c,
                c => (IReadOnlyList<Tally>)tallies.Where(x => x.RoundId == r1.Id && x.Category == c)
                    .Select(x => new Tally(x.CandidateId, x.Votes)).ToList());
            tied = VotingRules.TiedCategories(byCategory);
        }

        var minMinutes = await store.SettingAsync("voting_min_duration_minutes", VotingRules.DefaultMinDurationMinutes, ct);
        var maxMinutes = await store.SettingAsync("voting_max_duration_minutes", VotingRules.DefaultMaxDurationMinutes, ct);
        var why = VotingRules.WhyCannotOpen(
            t.Status, t.FinishedAt, t.VotingWindowHours, now, roundNumber,
            rounds.Any(r => r.RoundNumber == roundNumber), r1?.ClosesAt, tied is { Count: > 0 },
            durationMinutes, minMinutes, maxMinutes);
        if (why is not null)
        {
            return Outcome<int>.Fail(VotingErrors.FromOpenReason(why));
        }

        await store.OpenRoundAsync(tournamentId, roundNumber, now, now.AddMinutes(durationMinutes), tied, ct);
        return Outcome<int>.Ok(roundNumber);
    }
}
