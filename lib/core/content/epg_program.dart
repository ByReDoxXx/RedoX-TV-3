/// EPG çizelgesindeki tek program. Saatler gün başından dakikadır (20:30 →
/// 1230); veri katmanı (XMLTV) yazıldığında tarih/saat dilimiyle eşlenecek.
class EpgProgram {
  const EpgProgram({required this.title, required this.start, required this.end});

  final String title;
  final int start;
  final int end;

  bool isLiveAt(int minute) => start <= minute && minute < end;

  /// "20:30" → 1230; biçim tutmazsa null.
  static int? parseClock(String text) {
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (m == null) return null;
    return int.parse(m[1]!) * 60 + int.parse(m[2]!);
  }

  /// 1230 → "20:30".
  static String formatClock(int minute) {
    final m = minute % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}
