import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/error_messages.dart';
import 'package:gamehall_torneios/features/notifications/notification_models.dart';
import 'package:gamehall_torneios/features/teams/team_models.dart';

void main() {
  test('TeamCode lê o código do líder e os valores por defeito', () {
    final c = TeamCode.fromJson({
      'code': 'GH-7K3Q',
      'enabled': true,
      'directEntry': false,
      'membersSeeCode': false,
      'regensLeft': 2,
    });
    expect(c.code, 'GH-7K3Q');
    expect(c.enabled, isTrue);
    expect(c.directEntry, isFalse);
    expect(c.membersSeeCode, isFalse);
    expect(c.regensLeft, 2);
    expect(const TeamCode().directEntry, isTrue);
  });

  test('CodePreview traz o motivo de bloqueio', () {
    final p = CodePreview.fromJson({
      'teamId': 't1',
      'teamName': 'Águias',
      'colorHex': '#FF0000',
      'tournamentName': 'Taça',
      'membersCount': 3,
      'maxPlayers': 8,
      'directEntry': true,
      'blockedMessage': 'A equipa já está completa.',
    });
    expect(p.teamName, 'Águias');
    expect(p.blockedMessage, isNotNull);
    expect(p.membersCount, 3);
  });

  test('member_joined é um evento de equipa', () {
    expect(AppNotification.eventTypes.contains(AppNotification.memberJoined), isTrue);
  });

  test('código inválido tem mensagem própria', () {
    final msg = friendlyError(ApiException(status: 404, code: 'invite_code_invalid', message: 'x'));
    expect(msg, contains('Código inválido'));
  });
}
