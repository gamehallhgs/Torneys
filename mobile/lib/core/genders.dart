/// Géneros dos utilizadores e categorias dos torneios (os mesmos + misto).
class Genders {
  Genders._();

  static const mixed = 'mixed';

  /// Escolha ao criar a conta.
  static const user = <(String, String)>[
    ('male', 'Masculino'),
    ('female', 'Feminino'),
    ('non_binary', 'Não binário'),
    ('other', 'Outro'),
  ];

  /// "Masculino", "Feminino", "Não binário", "Outro" ou "Misto".
  static String label(String code) {
    if (code == mixed) {
      return 'Misto';
    }
    for (final g in user) {
      if (g.$1 == code) {
        return g.$2;
      }
    }
    return '';
  }

  /// Torneios: "Masculino"... e "Misto" (todos os géneros).
  static String tournamentLabel(String code) => label(code);

  /// Misto aceita todos; caso contrário o género tem de coincidir.
  static bool allowed(String tournamentGender, String userGender) =>
      tournamentGender == mixed || tournamentGender == userGender;
}
