import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/error_messages.dart';
import 'package:gamehall_torneios/features/voting/results_widgets.dart';
import 'package:gamehall_torneios/features/voting/voting_models.dart';
import 'package:gamehall_torneios/features/voting/voting_repository.dart';

Map<String, dynamic> _cand(String id, String name, String team, String teamId, {String? pos}) => {
      'userId': id,
      'displayName': name,
      'teamId': teamId,
      'teamName': team,
      'colorHex': '#E53935',
      'position': pos,
    };

void main() {
  test('TournamentResults lê pódio, prémios e votação', () {
    final r = TournamentResults.fromJson({
      'podium': [
        {'place': 1, 'teamId': 'a', 'name': 'Águias', 'colorHex': '#E53935'},
        {'place': 3, 'teamId': 'c', 'name': 'Lobos', 'colorHex': '#546E7A'},
        {'place': 3, 'teamId': 'd', 'name': 'Falcões', 'colorHex': '#8E24AA'},
      ],
      'bestPlayer': {
        'status': 'final',
        'winners': [
          {'userId': 'u1', 'displayName': 'Rui Silva', 'teamId': 'a', 'teamName': 'Águias', 'colorHex': '#E53935', 'position': 'ST'},
        ],
      },
      'bestGoalkeeper': {'status': 'pending', 'winners': []},
      'voting': null,
    });
    expect(r.podium.length, 3);
    expect(r.podium.where((p) => p.place == 3).length, 2);
    expect(r.bestPlayer!.winners.single.positionLabel, 'Avançado');
    expect(r.bestGoalkeeper!.isPending, isTrue);
    expect(r.voting, isNull);
    expect(r.hasAwards, isTrue);
    expect(const TournamentResults().hasAwards, isFalse);
  });

  test('Voting: ronda 2 é desempate e explica porque não pode votar', () {
    final v = Voting.fromJson({
      'roundNumber': 2,
      'closesAt': '2026-10-28T20:00:00Z',
      'canVote': false,
      'cannotVoteReason': 'email_not_verified_long_enough',
      'categories': [
        {'category': 'best_player', 'myVote': 'u1', 'candidates': [_cand('u1', 'Rui', 'Águias', 'a')]},
      ],
    });
    expect(v.isTiebreak, isTrue);
    expect(v.canVote, isFalse);
    expect(v.categories.single.myVote, 'u1');
    expect(VotingLabels.cannotVote(v.cannotVoteReason), contains('1 dia'));
  });

  test('erros da votação têm mensagem própria', () {
    expect(friendlyError(ApiException(status: 409, code: 'cannot_vote_self', message: 'x')), contains('ti próprio'));
    expect(friendlyError(ApiException(status: 409, code: 'voting_closed', message: 'x')), contains('fechou'));
  });

  testWidgets('Pódio mostra as equipas e o 3.º lugar ex aequo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PodiumCard(podium: [
          PodiumEntry.fromJson({'place': 1, 'teamId': 'a', 'name': 'Águias', 'colorHex': '#E53935'}),
          PodiumEntry.fromJson({'place': 2, 'teamId': 'b', 'name': 'Leões', 'colorHex': '#FB8C00'}),
          PodiumEntry.fromJson({'place': 3, 'teamId': 'c', 'name': 'Lobos', 'colorHex': '#546E7A'}),
          PodiumEntry.fromJson({'place': 3, 'teamId': 'd', 'name': 'Falcões', 'colorHex': '#8E24AA'}),
        ]),
      ),
    ));
    expect(find.text('Águias'), findsOneWidget);
    expect(find.text('3.º'), findsNWidgets(2));
  });

  testWidgets('Prémios: pendente, vencedor e co-vencedores', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AwardsRow(
            bestPlayer: Award.fromJson({
              'status': 'final',
              'winners': [
                {'userId': '1', 'displayName': 'Rui Silva', 'teamId': 'a', 'teamName': 'Águias', 'colorHex': '#E53935', 'position': 'ST'},
                {'userId': '2', 'displayName': 'Hugo Costa', 'teamId': 'b', 'teamName': 'Leões', 'colorHex': '#FB8C00', 'position': null},
              ],
            }),
            bestGoalkeeper: const Award(status: 'pending', winners: []),
          ),
        ),
      ),
    ));
    expect(find.text('Rui Silva'), findsOneWidget);
    expect(find.text('Hugo Costa'), findsOneWidget);
    expect(find.text('Co-vencedor (empate)'), findsNWidgets(2));
    expect(find.textContaining('aguardar desempate'), findsOneWidget);
  });

  testWidgets('Painel de votação lista jogadores por equipa e filtra pela pesquisa', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    final voting = Voting.fromJson({
      'roundNumber': 1,
      'closesAt': '2026-10-28T20:00:00Z',
      'canVote': true,
      'categories': [
        {
          'category': 'best_player',
          'candidates': [
            _cand('u1', 'Rui Silva', 'Águias', 'a'),
            _cand('u2', 'Hugo Costa', 'Leões', 'b'),
          ],
        },
        {
          'category': 'best_goalkeeper',
          'candidates': [_cand('u3', 'Nuno Alves', 'Águias', 'a', pos: 'GK')],
        },
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VotingPanel(
            tournamentId: 't',
            voting: voting,
            repo: VotingRepository(ApiClient(baseUrl: 'http://localhost:1')),
            onVoted: () async {},
          ),
        ),
      ),
    ));
    expect(find.text('Votação aberta'), findsOneWidget);
    expect(find.text('Águias'), findsOneWidget);
    expect(find.text('Leões'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hugo');
    await tester.pump();
    expect(find.text('Águias'), findsNothing);
    expect(find.text('Hugo Costa'), findsOneWidget);
    await tester.tap(find.text('Melhor guarda-redes'));
    await tester.pump();
    expect(find.text('Nenhum jogador encontrado.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
