/// Sarmaları sıraya koyar: biri sürerken gelenlerden yalnız sonuncusu yapılır.
/// TV'de her sarma çözücüyü yeniden açar; ◄► art arda basılınca her basışta
/// açılıp kapanmasın.
class SeekQueue {
  SeekQueue(this._run);

  final Future<void> Function(Duration to) _run;
  Duration? _next;
  bool _busy = false;

  /// Sürmekte olan sarma varsa hemen döner; [to] ondan sonra yapılır.
  Future<void> seek(Duration to) async {
    _next = to;
    if (_busy) return;
    _busy = true;
    try {
      for (var target = _next; target != null; target = _next) {
        _next = null;
        await _run(target);
      }
    } finally {
      _busy = false;
    }
  }
}
