import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/validators.dart';

void main() {
  group('Validators.birthDate (mínimo 13 anos)', () {
    final today = DateTime(2026, 10, 18);

    test('rejeita quem faz 13 anos amanhã', () {
      expect(Validators.birthDate(DateTime(2013, 10, 19), today: today), isNotNull);
    });

    test('aceita quem faz 13 anos hoje', () {
      expect(Validators.birthDate(DateTime(2013, 10, 18), today: today), isNull);
    });

    test('rejeita datas futuras e muito antigas', () {
      expect(Validators.birthDate(DateTime(2027, 1, 1), today: today), isNotNull);
      expect(Validators.birthDate(DateTime(1900, 1, 1), today: today), isNotNull);
    });

    test('exige data', () {
      expect(Validators.birthDate(null, today: today), isNotNull);
    });
  });

  group('Validators.newPassword', () {
    test('mínimo 12 caracteres', () {
      expect(Validators.newPassword('curta'), isNotNull);
      expect(Validators.newPassword('doze-caracter'), isNull);
    });

    test('máximo 128 caracteres', () {
      expect(Validators.newPassword('a' * 129), isNotNull);
      expect(Validators.newPassword('a' * 128), isNull);
    });
  });

  group('Outros validadores', () {
    test('email', () {
      expect(Validators.email('x@y.pt'), isNull);
      expect(Validators.email('x@y'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('código de 6 dígitos', () {
      expect(Validators.code('123456'), isNull);
      expect(Validators.code('12345'), isNotNull);
      expect(Validators.code('12a456'), isNotNull);
    });

    test('formatação de datas', () {
      expect(Validators.formatDateApi(DateTime(2008, 3, 5)), '2008-03-05');
      expect(Validators.formatDatePt(DateTime(2008, 3, 5)), '05/03/2008');
    });
  });
}
