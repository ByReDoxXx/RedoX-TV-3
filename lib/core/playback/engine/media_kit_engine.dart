import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playback_engine.dart';

/// media_kit (libmpv) ile oynatma. Uygulama başında
/// `MediaKit.ensureInitialized()` çağrılmış olmalı (main.dart).
class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine() {
    unawaited(_tune());
    final s = _player.stream;
    _subscriptions.addAll([
      s.playing.listen((v) => _update(_state.value.copyWith(playing: v))),
      s.buffering.listen((v) => _update(_state.value.copyWith(buffering: v))),
      s.width.listen((v) => _update(_state.value.copyWith(width: () => v))),
      s.height.listen((v) => _update(_state.value.copyWith(height: () => v))),
      s.tracks.listen(_onTracks),
      s.track.listen(
        (t) => _update(
          _state.value.copyWith(videoTrack: t.video.id, audioTrack: t.audio.id, subtitleTrack: t.subtitle.id),
        ),
      ),
      s.error.listen((e) {
        if (!_transient(e)) _errors.add(e);
      }),
    ]);
  }

  final _player = Player();
  late final _video = VideoController(
    _player,
    configuration: _android ? _zeroCopy : const VideoControllerConfiguration(),
  );

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Android'de donanım çözücü kareyi doğrudan yüzeye çizer (kopyasız).
  /// Varsayılan yol (vo=gpu, mediacodec-copy) her kareyi belleğe kopyalıyordu:
  /// Chromecast with Google TV'de 1080p/1440p yayınlar saniyede 5–8 kare
  /// atladı, görüntü 40 sn'de sesin 10–24 sn gerisine düştü ("kasma"; ölçüldü).
  /// Kopyasız yolda aynı kanallarda atlama 0, ses-görüntü farkı 0, işlemci yükü
  /// yarıya indi. Hafif ölçekleme (bilinear) ve 1080p sınırı denendi, etkisiz.
  static const _zeroCopy = VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec');

  /// Yayını düşürmeyen mpv iletileri: media_kit yüzey bağlanınca çözücüyü
  /// yeniden kurar ve oynatma konumuna atlar; canlı yayında atlama "Cannot
  /// seek" verir, kopyasız kipte ilk açılış "Could not open codec." verebilir.
  /// Bunlar hata sayılsaydı oturum çalışan akışı bırakıp yedeğe geçerdi.
  /// Gerçekten açılmayan akışı açılış süresi yakalar.
  static bool _transient(String e) =>
      e.contains('Cannot seek') || e.contains('force-seekable') || (_android && e.contains('Could not open codec'));

  /// Canlı yayında açılışı hızlandırır: ffmpeg yayın biçimini varsayılan 5 sn
  /// yerine 1 sn çözümler (IPTV akışlarında yeterli). Ağ beklemesi 10 sn.
  Future<void> _tune() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    await native.setProperty('demuxer-lavf-analyzeduration', '1');
    await native.setProperty('network-timeout', '10');
  }

  final _state = ValueNotifier(const EngineState());
  final _errors = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Tracks _tracks = const Tracks();

  @override
  ValueListenable<EngineState> get state => _state;

  @override
  Stream<String> get errors => _errors.stream;

  void _update(EngineState next) => _state.value = next;

  /// mpv'nin "auto"/"no" sözde izleri listeye alınmaz (arayüz "Otomatik" ve
  /// "Kapalı"yı kendisi ekler).
  static bool _real(String id) => id != EngineState.autoTrack && id != EngineState.noTrack;

  void _onTracks(Tracks t) {
    _tracks = t;
    String lang(String? title, String? language, String fallback) =>
        [title, language].whereType<String>().where((s) => s.isNotEmpty).firstOrNull ?? fallback;
    _update(
      _state.value.copyWith(
        // Yüksekten düşüğe (yayın sırası karışık geliyordu: 720p, 184p, 1080p...).
        videoTracks: [
          for (final v in t.video.where((v) => _real(v.id)).toList()..sort((a, b) => (b.h ?? 0) - (a.h ?? 0)))
            MediaTrack(v.id, v.h != null ? '${v.h}p' : lang(v.title, v.language, 'Görüntü ${v.id}')),
        ],
        audioTracks: [
          for (final a in t.audio.where((a) => _real(a.id))) MediaTrack(a.id, lang(a.title, a.language, 'Ses ${a.id}')),
        ],
        subtitleTracks: [
          for (final s in t.subtitle.where((s) => _real(s.id)))
            MediaTrack(s.id, lang(s.title, s.language, 'Altyazı ${s.id}')),
        ],
      ),
    );
  }

  @override
  Future<void> open(String url) {
    // Yeni yayında boyut ve izler sıfırlanır: "görüntü geldi" yeniden ölçülür.
    _update(const EngineState());
    return _player.open(Media(url));
  }

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 100);

  @override
  Future<void> selectVideoTrack(String id) => _player.setVideoTrack(switch (id) {
    EngineState.autoTrack => VideoTrack.auto(),
    EngineState.noTrack => VideoTrack.no(),
    _ => _tracks.video.firstWhere((v) => v.id == id, orElse: VideoTrack.auto),
  });

  @override
  Future<void> selectAudioTrack(String id) => _player.setAudioTrack(switch (id) {
    EngineState.autoTrack => AudioTrack.auto(),
    EngineState.noTrack => AudioTrack.no(),
    _ => _tracks.audio.firstWhere((a) => a.id == id, orElse: AudioTrack.auto),
  });

  @override
  Future<void> selectSubtitleTrack(String id) => _player.setSubtitleTrack(switch (id) {
    EngineState.autoTrack => SubtitleTrack.auto(),
    EngineState.noTrack => SubtitleTrack.no(),
    _ => _tracks.subtitle.firstWhere((s) => s.id == id, orElse: SubtitleTrack.auto),
  });

  @override
  Widget view({BoxFit fit = BoxFit.contain}) =>
      // Denetimler uygulamanındır (alt çubuk); media_kit'inkiler kapalı.
      Video(controller: _video, controls: NoVideoControls, fit: fit);

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _errors.close();
    _state.dispose();
    await _player.dispose();
  }
}
