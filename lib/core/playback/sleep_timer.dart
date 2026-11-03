import 'dart:async';

/// Uyku zamanlayıcısı (radyo ve oynatıcı): seçilen süre dolunca [onDone]
/// çağrılır. Seçim tek satırdan döngüyle yapılır: Kapalı → 30 → 60 → 90 →
/// Kapalı.
class SleepTimer {
  SleepTimer(this.onDone);

  final void Function() onDone;

  /// Seçenekler (dakika).
  static const choices = [30, 60, 90];

  Timer? _timer;
  DateTime? _at;

  /// Kalan süre; kapalıysa null.
  Duration? get left {
    final at = _at;
    if (at == null) return null;
    final d = at.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// [minutes] sonra [onDone]; null kapatır.
  void set(int? minutes) {
    cancel();
    if (minutes == null) return;
    final d = Duration(minutes: minutes);
    _at = DateTime.now().add(d);
    _timer = Timer(d, () {
      _timer = null;
      _at = null;
      onDone();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _at = null;
  }

  /// Örn. "Kapalı", "28 dk".
  static String label(Duration? left) => switch (left) {
    null => 'Kapalı',
    final d => '${(d.inSeconds / 60).ceil()} dk',
  };

  /// Sıradaki seçim: kalan süreden büyük ilk seçenek; sonuncudan sonra kapalı.
  static int? next(Duration? left) {
    if (left == null) return choices.first;
    final m = (left.inSeconds / 60).ceil();
    return choices.where((c) => c > m).firstOrNull;
  }
}
