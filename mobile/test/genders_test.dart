import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/genders.dart';
import 'package:gamehall_torneios/core/models.dart';
import 'package:gamehall_torneios/features/tournaments/tournament_models.dart';

void main() {
  test('rótulos e regra de entrada', () {
    expect(Genders.label('non_binary'), 'Não binário');
    expect(Genders.tournamentLabel('mixed'), 'Misto');
    expect(Genders.allowed('mixed', 'male'), isTrue);
    expect(Genders.allowed('male', 'male'), isTrue);
    expect(Genders.allowed('female', 'male'), isFalse);
  });

  test('o utilizador traz o género (por omissão "other")', () {
    final u = AppUser.fromJson({'id': '1', 'email': 'a@b.pt', 'displayName': 'A', 'gender': 'female'});
    expect(u.gender, 'female');
    expect(AppUser.fromJson({'id': '1'}).gender, 'other');
    expect(u.copyWith(displayName: 'B').gender, 'female');
  });

  test('mensagem de torneio não aberto ao género', () {
    expect(TournamentLabels.ineligible('gender_not_allowed', minAge: 13), contains('género'));
  });
}
