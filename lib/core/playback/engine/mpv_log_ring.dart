import 'dart:collection';

/// mpv'nin son günlük satırları, yalnız bellekte. Takılma anında yazdırılır:
/// çekirdeğin neyi beklerken kilitlendiği başka yoldan görülemiyor (Philips'te
/// yığın dökümü root ister). Satırlarda adres olabilir: dışarı yalnız
/// `Diagnostics` üzerinden çıkar, o adresleri gizler.
class MpvLogRing {
  MpvLogRing({this.limit = 150});

  final int limit;
  final _lines = ListQueue<String>();

  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.addLast(line);
    if (_lines.length > limit) _lines.removeFirst();
  }
}
