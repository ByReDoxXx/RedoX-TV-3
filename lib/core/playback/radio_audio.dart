import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Radyo sesi: görüntüsüz oynatıcı. Arayüz kütüphaneden bağımsızdır; testler
/// sahte sesle koşar.
abstract class RadioAudio {
  /// Ses geliyor mu.
  ValueListenable<bool> get playing;

  /// Yayın bağlanıyor ya da arabelleğe alıyor.
  ValueListenable<bool> get buffering;

  /// Çalan şarkı: yayının ICY üst verisi ("Sanatçı - Şarkı"); yoksa null.
  ValueListenable<String?> get title;

  /// Açılamayan yayın.
  Stream<String> get errors;

  Future<void> open(String url);

  /// Radyo cızırtısı (istasyon geçişi, bağlanırken): döngüde çalar ya da
  /// susar. Yayının sesinden ayrı oynatıcıdır.
  Future<void> setNoise(bool on);

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// media_kit (libmpv) ile radyo. Video izi kapalıdır; kullanıcı aracısı
/// tarayıcı değildir: Shoutcast sunucuları "Mozilla" içeren istemciye ses
/// yerine HTML durum sayfası döndürür (eski uygulamada sınandı).
class MediaKitRadioAudio implements RadioAudio {
  MediaKitRadioAudio() {
    unawaited(_tune());
    final s = _player.stream;
    _subscriptions.addAll([
      s.playing.listen((v) => _playing.value = v),
      s.buffering.listen((v) => _buffering.value = v),
      s.error.listen(_errors.add),
    ]);
  }

  static const userAgent = 'RedoXTV/3.0';

  final _player = Player(configuration: const PlayerConfiguration(title: 'RedoX TV Radyo'));

  /// Cızırtı sesi (assets/sounds/radyo_cizirti.wav, tools/ses/radyo_cizirti.py);
  /// ilk kullanımda kurulur.
  Player? _noise;
  bool _noiseOn = false;

  static const noiseAsset = 'asset:///assets/sounds/radyo_cizirti.wav';

  /// Cızırtı yayının altında kalsın: kısık.
  static const noiseVolume = 45.0;
  final _playing = ValueNotifier(false);
  final _buffering = ValueNotifier(false);
  final _title = ValueNotifier<String?>(null);
  final _errors = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  Future<void> _tune() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    await native.setProperty('vid', 'no');
    await native.setProperty('user-agent', userAgent);
    await native.setProperty('network-timeout', '10');
    // Canlı yayında 1 sn çözümleme yeter (TV akışlarındaki gibi).
    await native.setProperty('demuxer-lavf-analyzeduration', '1');
    await native.observeProperty('metadata/by-key/icy-title', (v) async {
      final t = v.trim();
      _title.value = t.isEmpty ? null : t;
    });
  }

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<bool> get buffering => _buffering;

  @override
  ValueListenable<String?> get title => _title;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<void> open(String url) {
    _title.value = null;
    return _player.open(Media(url));
  }

  @override
  Future<void> setNoise(bool on) async {
    if (on == _noiseOn) return;
    _noiseOn = on;
    if (!on) {
      await _noise?.pause();
      return;
    }
    var noise = _noise;
    if (noise == null) {
      noise = _noise = Player(configuration: const PlayerConfiguration(title: 'RedoX TV Cızırtı'));
      final native = noise.platform;
      if (native is NativePlayer) await native.setProperty('vid', 'no');
      await noise.setPlaylistMode(PlaylistMode.loop);
      await noise.setVolume(noiseVolume);
      await noise.open(Media(noiseAsset));
    } else {
      await noise.play();
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() {
    _title.value = null;
    return _player.stop();
  }

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _errors.close();
    await _noise?.dispose();
    await _player.dispose();
  }
}
