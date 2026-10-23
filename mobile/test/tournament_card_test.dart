import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/tournaments/tournament_card.dart';
import 'package:gamehall_torneios/features/tournaments/tournament_models.dart';

TournamentSummary summary({
  String status = 'registration_open',
  int registered = 5,
  int confirmed = 0,
  int max = 8,
}) =>
    TournamentSummary.fromJson({
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
      'teamsRegistered': registered,
      'teamsConfirmed': confirmed,
      'isFull': confirmed >= max,
      'maxTeams': max,
      'minAge': 18,
      'maxAge': null,
      'ageLabel': '18+',
      'registrationClosesAt': '2026-10-30T23:00:00Z',
    });

Future<void> pump(WidgetTester tester, TournamentSummary t) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: TournamentCard(tournament: t, onTap: () {})),
      ),
    ),
  );
}

void main() {
  testWidgets('aberto e cheio mostra a flag Cheio', (tester) async {
    await pump(tester, summary(registered: 12, confirmed: 8));
    expect(find.text('Cheio'), findsOneWidget);
    expect(find.text('8/8 equipas confirmadas · 4 em formação'), findsOneWidget);
  });

  testWidgets('aberto com vagas não mostra Cheio', (tester) async {
    await pump(tester, summary(registered: 6, confirmed: 3));
    expect(find.text('Cheio'), findsNothing);
    expect(find.text('3/8 equipas confirmadas · 3 em formação'), findsOneWidget);
  });

  testWidgets('sem equipas em formação não mostra o sufixo', (tester) async {
    await pump(tester, summary(registered: 8, confirmed: 8));
    expect(find.text('8/8 equipas confirmadas'), findsOneWidget);
    expect(find.text('Cheio'), findsOneWidget);
  });

  testWidgets('torneio cheio mas a decorrer não mostra Cheio', (tester) async {
    await pump(tester, summary(status: 'ongoing', registered: 8, confirmed: 8));
    expect(find.text('Cheio'), findsNothing);
  });

  testWidgets('toque no cartão chama onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TournamentCard(tournament: summary(), onTap: () => taps++),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Taça Teste'));
    expect(taps, 1);
  });
}
