import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/error_messages.dart';

void main() {
  test('convidar alguém que já está numa equipa mostra o nome do jogador', () {
    final e = ApiException(
      status: 409,
      code: 'invitee_already_in_team',
      message: 'O jogador Rui Costa já se encontra numa equipa do mesmo torneio.',
    );
    expect(friendlyError(e), 'O jogador Rui Costa já se encontra numa equipa do mesmo torneio.');
  });

  test('convidar-se a si próprio', () {
    final e = ApiException(status: 409, code: 'cannot_invite_self', message: 'Não te podes convidar a ti próprio.');
    expect(friendlyError(e), 'Não te podes convidar a ti próprio.');
  });

  test('lobby fechado e convites só do líder', () {
    expect(friendlyError(ApiException(status: 409, code: 'lobby_closed', message: 'x')), contains('convite'));
    expect(friendlyError(ApiException(status: 403, code: 'invite_not_allowed', message: 'x')), contains('líder'));
  });
}
