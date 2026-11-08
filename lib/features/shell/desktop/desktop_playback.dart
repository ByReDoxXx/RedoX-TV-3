import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/content/app_settings.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/playback/engine/media_kit_engine.dart';
import '../../../core/playback/engine/playback_engine.dart';
import '../../../core/playback/playback_session.dart';
import '../../../core/playback/stream_probe.dart';

/// Masaüstü kabuğunun oynatması (Spotify'daki gibi): kanal, uygulamada
/// gezinirken alttaki oynatma çubuğunda ve sağdaki "Şimdi oynatılan"
/// panelinde sürer. Tam ekran oynatıcı aynı oturumu ödünç alır; yayın
/// yeniden açılmaz.
///
/// Motor ilk kanalda kurulur ve kanallar arasında yeniden kullanılır;
/// [stop] motoru kapatır.
class DesktopPlayback extends ChangeNotifier {
  DesktopPlayback({this.engineFactory, this.rank});

  /// null ise media_kit (testlerde sahte motor).
  final PlaybackEngine Function()? engineFactory;
  final StreamRanker? rank;

  PlaybackEngine? _engine;
  PlaybackSession? _session;
  int? _watched;

  /// Görüntü gelince (geçmişe yazmak için); kanal başına bir kez.
  ValueChanged<LiveChannel>? _onWatched;
  bool _disposed = false;

  /// Şimdiki oturum; çalan bir şey yoksa null.
  PlaybackSession? get session => _session;
  PlaybackEngine? get engine => _engine;
  bool get active => _session != null;
  bool get muted => _engine?.audio.value.muted ?? false;

  /// [channels] içinden [index]'teki kanalı oynatır. Aynı liste çalıyorsa
  /// yalnız kanal değişir.
  void play(
    List<LiveChannel> channels,
    int index, {
    Future<String> Function(String url)? resolve,
    ValueChanged<LiveChannel>? onWatched,
  }) {
    _onWatched = onWatched;
    final current = _session;
    if (current != null && listEquals(current.channels, channels)) {
      current.openAt(index);
      return;
    }
    _closeSession();
    final engine = _engine ??= (engineFactory ?? MediaKitEngine.new)();
    _session = PlaybackSession(
      engine: engine,
      channels: channels,
      initialIndex: index,
      rank: rank,
      resolve: resolve,
      failover: AppSettings.instance.failover,
    )..addListener(_onSession);
    // Oturum kurulurken görüntü gelmiş olabilir (dinleyici sonradan eklendi).
    _onSession();
  }

  void _onSession() {
    final s = _session;
    if (s == null) return;
    if (s.status == PlaybackStatus.playing && s.channel.number != _watched) {
      _watched = s.channel.number;
      _onWatched?.call(s.channel);
    }
    notifyListeners();
  }

  void zap(int delta) => _session?.zap(delta);

  void openAt(int index) => _session?.openAt(index);

  Future<void> playOrPause() async => _engine?.playOrPause();

  Future<void> toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setMuted(!engine.audio.value.muted);
    notifyListeners();
  }

  /// Oynatmayı bitirir: oturum ve motor kapanır, çubuk ve panel gizlenir.
  Future<void> stop() async {
    if (_session == null && _engine == null) return;
    _closeSession();
    final engine = _engine;
    _engine = null;
    if (!_disposed) notifyListeners();
    await engine?.dispose();
  }

  void _closeSession() {
    _session
      ?..removeListener(_onSession)
      ..dispose();
    _session = null;
    _watched = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
