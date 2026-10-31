import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:redox_tv/core/playback/engine/playback_engine.dart';

/// Testlerin oynatma motoru: yerel video kütüphanesi test ortamında yoktur.
/// Açılan adresleri ve seçimleri kaydeder; görüntü ve hata elle verilir.
class FakeEngine implements PlaybackEngine {
  final _state = ValueNotifier(const EngineState());
  final _errors = StreamController<String>.broadcast();

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

  /// Görüntü gelsin (yayın açıldı).
  void showVideo({int width = 1280, int height = 720}) =>
      _state.value = _state.value.copyWith(playing: true, width: () => width, height: () => height);

  @override
  Future<void> playOrPause() async => _state.value = _state.value.copyWith(playing: !_state.value.playing);

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
  Future<void> dispose() async {
    disposed = true;
    await _errors.close();
  }
}
