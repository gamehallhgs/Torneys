import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/format.dart';
import 'package:gamehall_torneios/features/tournaments/tournament_models.dart';

Map<String, dynamic> summaryJson({int teams = 5, int maxTeams = 16, int? confirmed, String status = 'registration_open'}) => {
      'id': 'a1',
      'name': 'Taça Teste',
      'organizerName': 'Clube Demo',
      'sport': 'football7',
      'format': 'single_elimination',
      'status': status,
      'startsOn': '2026-11-05',
      'endsOn': '2026-11-06',
      'locationName': 'Pavilhão X',
      'entryFeeCents': 6000,
      'teamsRegistered': teams,
      'teamsConfirmed': confirmed ?? 0,
      'isFull': (confirmed ?? 0) >= maxTeams,
      'maxTeams': maxTeams,
      'minAge': 18,
      'maxAge': null,
      'ageLabel': '18+',
      'registrationClosesAt': '2026-10-30T23:00:00Z',
    };

void main() {
  test('TournamentPage.fromJson lê a lista paginada', () {
    final page = TournamentPage.fromJson({
      'items': [summaryJson()],
      'total': 1,
      'page': 1,
      'pageSize': 20,
    });
    expect(page.items.single.name, 'Taça Teste');
    expect(page.items.single.maxAge, isNull);
    expect(page.items.single.startsOn, DateTime(2026, 11, 5));
    expect(page.total, 1);
  });

  test('vagas restantes nunca ficam negativas', () {
    final s = TournamentSummary.fromJson(summaryJson(teams: 9, maxTeams: 8, confirmed: 9));
    expect(s.spotsLeft, 0);
  });

  test('só as equipas confirmadas ocupam vaga; as outras estão em formação', () {
    final s = TournamentSummary.fromJson(summaryJson(teams: 30, maxTeams: 8, confirmed: 3));
    expect(s.spotsLeft, 5);
    expect(s.teamsInFormation, 27);
    expect(s.isFull, isFalse);
    expect(s.showFullFlag, isFalse);
    expect(TournamentLabels.teamsLine(s.teamsConfirmed, s.maxTeams, s.teamsInFormation),
        '3/8 equipas confirmadas · 27 em formação');
    expect(TournamentLabels.teamsLine(8, 8, 0), '8/8 equipas confirmadas');
  });

  test('etiqueta "Cheio" só nos torneios com inscrições abertas e vagas esgotadas', () {
    final full = TournamentSummary.fromJson(summaryJson(teams: 12, maxTeams: 8, confirmed: 8));
    expect(full.isFull, isTrue);
    expect(full.showFullFlag, isTrue);
    final ongoing =
        TournamentSummary.fromJson(summaryJson(teams: 8, maxTeams: 8, confirmed: 8, status: 'ongoing'));
    expect(ongoing.isFull, isTrue);
    expect(ongoing.showFullFlag, isFalse);
  });

  test('isFull usa o valor do servidor e, sem ele, calcula pelas confirmadas', () {
    final json = summaryJson(teams: 8, maxTeams: 8, confirmed: 8)..remove('isFull');
    expect(TournamentSummary.fromJson(json).isFull, isTrue);
  });

  test('TournamentDetail.fromJson lê equipas e elegibilidade', () {
    final d = TournamentDetail.fromJson({
      'summary': summaryJson(),
      'description': 'x',
      'hasThirdPlace': true,
      'tiebreakers': ['points', 'draw'],
      'locationAddress': 'Rua 1',
      'minPlayersPerTeam': 9,
      'maxPlayersPerTeam': 14,
      'teams': [
        {'id': 't1', 'name': 'Águias', 'colorHex': '#E53935', 'confirmed': true},
        {'id': 't2', 'name': 'Bravos', 'colorHex': '#1E88E5', 'confirmed': false},
      ],
      'eligibility': {'canCreateTeam': false, 'reason': 'age_too_young'},
      'myTeamId': 't1',
      'myTeam': {'id': 't1', 'name': 'Águias', 'colorHex': '#E53935', 'isHost': true, 'membersCount': 5, 'confirmed': true},
    });
    expect(d.myTeam?.name, 'Águias');
    expect(d.myTeam?.membersCount, 5);
    expect(d.myTeam?.isHost, isTrue);
    expect(d.myTeam?.confirmed, isTrue);
    expect(d.myTeam?.color.toARGB32(), 0xFFE53935);
    expect(d.myTeamId, 't1');
    expect(d.hasThirdPlace, isTrue);
    expect(d.tiebreakers, ['points', 'draw']);
    expect(d.teams.first.color.toARGB32(), 0xFFE53935);
    expect(d.teams.map((t) => t.confirmed).toList(), [true, false]);
    expect(d.canCreateTeam, isFalse);
    expect(d.ineligibleReason, 'age_too_young');
  });

  test('TournamentDetail sem equipa não tem myTeam', () {
    final d = TournamentDetail.fromJson({
      'summary': summaryJson(),
      'teams': [],
      'eligibility': {'canCreateTeam': true},
      'myTeamId': null,
      'myTeam': null,
    });
    expect(d.myTeam, isNull);
    expect(d.myTeamId, isNull);
  });

  test('textos em português', () {
    expect(TournamentLabels.sport('futsal'), 'Futsal');
    expect(TournamentLabels.status('registration_open'), 'Inscrições abertas');
    expect(TournamentLabels.tiebreaker('head_to_head'), 'Confronto direto');
    expect(TournamentLabels.ineligible('age_too_young', minAge: 18),
        contains('18 anos'));
  });

  test('formatação de valores e datas', () {
    expect(Fmt.money(0), 'Grátis');
    expect(Fmt.money(6000), '60 €');
    expect(Fmt.money(3550), '35,50 €');
    expect(Fmt.date(DateTime(2026, 11, 5)), '5 nov 2026');
    expect(Fmt.dateRange(DateTime(2026, 11, 5), DateTime(2026, 11, 5)), '5 nov 2026');
    expect(Fmt.dateRange(DateTime(2026, 11, 5), DateTime(2026, 11, 7)), '5 nov – 7 nov 2026');
    expect(Fmt.parseDate('2026-11-05T10:00:00Z'), DateTime(2026, 11, 5));
  });
}
