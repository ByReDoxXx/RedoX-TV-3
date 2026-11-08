import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:redox_tv/core/playback/engine/playback_engine.dart';

/// Testlerin oynatma motoru: yerel video kütüphanesi test ortamında yoktur.
/// Açılan adresleri ve seçimleri kaydeder; görüntü ve hata elle verilir.
class FakeEngine implements PlaybackEngine {
  final _state = ValueNotifier(const EngineState());
  final _errors = StreamController<String>.broadcast();
  final _audioFallbacks = StreamController<AudioFallback>.broadcast();

  @override
  bool paintsBehindUi = false;

  /// Açılan adresler, sırasıyla.
  final opened = <String>[];
  final videoSelections = <String>[];
  final audioSelections = <String>[];
  final subtitleSelections = <String>[];
  bool disposed = false;

  /// Testin motor listesine eklenir (sayfaların kurduğu motorları izlemek için).
  void addTo(List<FakeEngine>? list) => list?.add(this);

  /// Bu adresler açılınca hata verir.
  final failing = <String>{};

  /// Açılan adres hata vermiyorsa görüntü hemen "gelir".
  bool autoVideo = true;

  /// Görüntü yüzeyi (4K görüntüde video yerine koyu degrade).
  @override
  Widget view({BoxFit fit = BoxFit.contain}) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B3A55), Color(0xFF6B4E71), Color(0xFFC08B5C)],
      ),
    ),
  );

  @override
  ValueListenable<EngineState> get state => _state;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<AudioFallback> get audioFallbacks => _audioFallbacks.stream;

  /// Motor ses izi değiştirsin.
  void emitAudioFallback(AudioFallback fallback) => _audioFallbacks.add(fallback);

  @override
  Future<void> open(String url) async {
    opened.add(url);
    _state.value = const EngineState(
      videoTracks: [MediaTrack('1', '1080p'), MediaTrack('2', '720p')],
      audioTracks: [MediaTrack('1', 'Türkçe'), MediaTrack('2', 'English')],
      subtitleTracks: [MediaTrack('1', 'Türkçe')],
    );
    if (failing.contains(url)) {
      // mpv açılmayan adres için birden çok hata bildirir (emülatörde görüldü).
      _errors
        ..add('açılamadı: $url')
        ..add('yükleme başarısız: $url');
    } else if (autoVideo) {
      showVideo();
    }
  }

  /// Motor hata iletisi bildirsin.
  void emitError(String message) => _errors.add(message);

  /// Oynatıcı yanıt vermez oldu.
  void freeze() => _state.value = _state.value.copyWith(stuck: true);

  /// Görüntü gelsin (yayın açıldı).
  void showVideo({int width = 1280, int height = 720}) =>
      _state.value = _state.value.copyWith(playing: true, width: () => width, height: () => height);

  final _position = ValueNotifier(Duration.zero);

  @override
  ValueListenable<Duration> get position => _position;

  /// Sarılan konumlar, sırasıyla.
  final seeks = <Duration>[];

  @override
  Future<void> seek(Duration to) async {
    final end = _state.value.duration;
    final clamped = to < Duration.zero ? Duration.zero : (end > Duration.zero && to > end ? end : to);
    seeks.add(clamped);
    _position.value = clamped;
  }

  /// Yayın süresi (film/dizi: sarma çubuğu görünür); konum.
  void setDuration(Duration d, {Duration at = Duration.zero}) {
    _state.value = _state.value.copyWith(duration: d);
    _position.value = at;
  }

  @override
  Future<void> playOrPause() async => _state.value = _state.value.copyWith(playing: !_state.value.playing);

  /// Seçilen oynatma hızları, sırasıyla.
  final rates = <double>[];

  @override
  Future<void> setRate(double rate) async => rates.add(rate);

  /// Ses kapalı mı (Bölünmüş Ekran).
  bool muted = false;

  @override
  Future<void> setMuted(bool muted) async {
    this.muted = muted;
    _audio.value = AudioLevel(level: _audio.value.level, muted: muted);
  }

  final _audio = ValueNotifier(const AudioLevel());

  @override
  ValueListenable<AudioLevel> get audio => _audio;

  @override
  Future<void> setVolume(double level) async => _audio.value = AudioLevel(level: level, muted: _audio.value.muted);

  @override
  Future<void> selectVideoTrack(String id) async {
    videoSelections.add(id);
    _state.value = _state.value.copyWith(videoTrack: id);
  }

  @override
  Future<void> selectAudioTrack(String id) async {
    audioSelections.add(id);
    _state.value = _state.value.copyWith(audioTrack: id);
  }

  @override
  Future<void> selectSubtitleTrack(String id) async {
    subtitleSelections.add(id);
    _state.value = _state.value.copyWith(subtitleTrack: id);
  }

  @override
  Future<StreamStats> stats() async => const StreamStats(
    videoCodec: 'h264',
    audioCodec: 'aac',
    decoder: 'mediacodec',
    fps: 25,
    videoBitrate: 4200000,
    audioBitrate: 128000,
    cache: Duration(seconds: 8),
    droppedFrames: 0,
  );

  /// Yayın takıldı (ön belleğe alınıyor) ya da sürüyor.
  void setBuffering(bool v) => _state.value = _state.value.copyWith(buffering: v);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _errors.close();
  }
}
