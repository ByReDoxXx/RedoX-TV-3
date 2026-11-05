import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/watch_progress.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../../core/playback/playback_session.dart';

/// Film ve dizide izlenen yer: kaydın süresi ilk gelince kaldığı yere sarar,
/// sonra 10 sn'de bir, kayıt değişince ve çıkarken yeri yazar.
class VodProgress {
  VodProgress({
    required this.engine,
    required this.session,
    required this.store,
    required this.series,
    required this.onResumed,
    this.period = const Duration(seconds: 10),
  });

  final PlaybackEngine engine;

  /// Oturum sayfada geç kurulur: dinleyici oturumdan önce bağlansın diye işlev.
  final PlaybackSession Function() session;

  /// Null ise izlenen yer tutulmaz.
  final WatchProgress? store;
  final bool series;

  /// Kaldığı yere sarıldı.
  final ValueChanged<Duration> onResumed;
  final Duration period;

  int? _resumedIndex;
  Timer? _timer;

  /// Yerin yazılacağı kayıt: kayıt değişince eskisininki kaybolmasın.
  LiveChannel? _of;

  void start() {
    engine.state.addListener(_resume);
    _timer = Timer.periodic(period, (_) => save());
  }

  /// Son yeri yazar ve durur.
  void stop() {
    save();
    _timer?.cancel();
    engine.state.removeListener(_resume);
  }

  void _resume() {
    // Önce süre: oturum kurulurken de bildirim gelir, o sırada oturum okunamaz.
    if (!engine.state.value.seekable) return;
    final s = session();
    if (_resumedIndex == s.index) return;
    save();
    _resumedIndex = s.index;
    _of = s.channel;
    final url = s.channel.streams.firstOrNull;
    final at = url == null ? null : store?.resumeAt(url);
    if (at == null) return;
    unawaited(engine.seek(at));
    onResumed(at);
  }

  void save() {
    final c = _of;
    final e = engine.state.value;
    if (c == null || !e.seekable) return;
    store?.record(c, position: engine.position.value, duration: e.duration, series: series);
  }
}
