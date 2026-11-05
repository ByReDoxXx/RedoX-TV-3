/// Kapalıyken sarmaları bekletir, yalnız sonuncusunu saklar; açılınca onu yapar.
///
/// Açılışta görüntü yüzeyi bağlanırken media_kit çözücüyü yeniden kurar ve kendi
/// sarmasını yapar: o sırada istenen sarma ezilir (kaldığı yer kaybolur) ve çözücü
/// kurulurken boşaltılır (Philips'te takılmadan hemen önce günlükte görüldü).
class SeekGate {
  SeekGate(this._seek);

  final Future<void> Function(Duration to) _seek;
  bool _closed = false;
  Duration? _pending;

  bool get closed => _closed;

  /// Bekleyen sarma: konum göstergesi şimdilik bunu gösterir.
  bool get holding => _pending != null;

  /// Yeni açılış: önceki yayının bekleyen sarması atılır.
  void close() {
    _closed = true;
    _pending = null;
  }

  Future<void> seek(Duration to) async {
    if (_closed) {
      _pending = to;
      return;
    }
    await _seek(to);
  }

  Future<void> open() async {
    _closed = false;
    final to = _pending;
    _pending = null;
    if (to != null) await _seek(to);
  }
}
