/// Formatação de datas e valores em português (sem depender de inicialização de locales).
class Fmt {
  Fmt._();

  static const List<String> _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  /// 5 nov 2026
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "5 nov 2026" ou "5 nov – 7 nov 2026" (ou com anos diferentes, ambos completos).
  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return date(start);
    }
    if (start.year == end.year) {
      return '${start.day} ${_months[start.month - 1]} – ${date(end)}';
    }
    return '${date(start)} – ${date(end)}';
  }

  /// 6000 -> "60 €", 3550 -> "35,50 €", 0 -> "Grátis"
  static String money(int cents) {
    if (cents <= 0) {
      return 'Grátis';
    }
    final euros = cents ~/ 100;
    final rest = cents % 100;
    return rest == 0 ? '$euros €' : '$euros,${rest.toString().padLeft(2, '0')} €';
  }

  /// Interpreta "2026-11-05" (ou "2026-11-05T10:00:00Z") como data civil, sem fuso.
  static DateTime parseDate(String iso) {
    final parts = iso.substring(0, 10).split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static const List<String> _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  /// 14:05
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// "sáb, 5 nov · 14:05" (hora local do dispositivo).
  static String dateTime(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} · ${time(d)}';
}
