import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/geo/geo_models.dart';
import 'package:gamehall_torneios/features/geo/location_picker.dart';
import 'package:gamehall_torneios/features/tournaments/tournament_models.dart';

Map<String, dynamic> summary({String? district, String? municipality}) => {
      'id': 'a1',
      'name': 'Taça Teste',
      'organizerName': 'Clube Demo',
      'sport': 'football7',
      'format': 'single_elimination',
      'status': 'registration_open',
      'startsOn': '2026-11-05',
      'endsOn': '2026-11-06',
      'locationName': 'Pavilhão X',
      'district': district,
      'municipality': municipality,
      'entryFeeCents': 6000,
      'teamsRegistered': 3,
      'teamsConfirmed': 1,
      'isFull': false,
      'maxTeams': 8,
      'minAge': 18,
      'maxAge': null,
      'ageLabel': '18+',
      'registrationClosesAt': '2026-10-30T23:00:00Z',
    };

void main() {
  group('District', () {
    test('fromJson lê nome e concelhos', () {
      final d = District.fromJson({
        'name': 'Lisboa',
        'municipalities': ['Cascais', 'Lisboa'],
      });
      expect(d.name, 'Lisboa');
      expect(d.municipalities, ['Cascais', 'Lisboa']);
    });
  });

  group('LocationFilter', () {
    test('sem distrito não está ativo', () {
      expect(LocationFilter.none.isActive, isFalse);
      expect(LocationFilter.none.label, 'Localidade');
    });

    test('etiqueta com distrito e com concelho', () {
      expect(const LocationFilter(district: 'Porto').label, 'Porto');
      expect(const LocationFilter(district: 'Porto', municipality: 'Matosinhos').label, 'Porto · Matosinhos');
    });

    test('igualdade por valor', () {
      expect(const LocationFilter(district: 'Faro'), const LocationFilter(district: 'Faro'));
      expect(const LocationFilter(district: 'Faro') == const LocationFilter(district: 'Faro', municipality: 'Loulé'),
          isFalse);
    });
  });

  group('torneio com localidade', () {
    test('lê distrito e concelho', () {
      final t = TournamentSummary.fromJson(summary(district: 'Lisboa', municipality: 'Cascais'));
      expect(t.district, 'Lisboa');
      expect(t.municipality, 'Cascais');
      expect(t.placeLine, 'Pavilhão X · Cascais, Lisboa');
    });

    test('sem localidade mostra só o local', () {
      final t = TournamentSummary.fromJson(summary());
      expect(t.placeLine, 'Pavilhão X');
    });

    test('só distrito', () {
      final t = TournamentSummary.fromJson(summary(district: 'Faro'));
      expect(t.placeLine, 'Pavilhão X · Faro');
    });
  });

  group('pesquisa sem acentos', () {
    test('foldText', () {
      expect(foldText('Évora'), 'evora');
      expect(foldText('Guimarães'), 'guimaraes');
      expect(foldText('Vila Nova de Foz Côa'), 'vila nova de foz coa');
    });
  });

  group('filtro de modalidades', () {
    test('"Todas" volta a sem filtro e não é null (o bug do menu)', () {
      expect(TournamentLabels.allSports, isNotNull);
      expect(TournamentLabels.sportFilter(TournamentLabels.allSports), isNull);
      expect(TournamentLabels.sportFilter('futsal'), 'futsal');
    });
  });
}
