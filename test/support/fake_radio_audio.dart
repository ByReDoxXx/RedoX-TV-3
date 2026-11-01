import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:redox_tv/core/playback/radio_audio.dart';

/// Testlerde radyo sesi: açılan adresleri kaydeder; [failing] adresler hata
/// verir, diğerleri hemen çalar (ya da [autoPlay] false ise sessiz kalır).
class FakeRadioAudio implements RadioAudio {
  FakeRadioAudio({this.failing = const {}, this.autoPlay = true});

  final Set<String> failing;
  bool autoPlay;
  final opened = <String>[];
  bool disposed = false;

  final _playing = ValueNotifier(false);
  final _buffering = ValueNotifier(false);
  final _title = ValueNotifier<String?>(null);
  final _errors = StreamController<String>.broadcast(sync: true);

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<bool> get buffering => _buffering;

  @override
  ValueListenable<String?> get title => _title;

  @override
  Stream<String> get errors => _errors.stream;

  /// Yayının ICY başlığını değiştirir.
  set icy(String? v) => _title.value = v;

  @override
  Future<void> open(String url) async {
    opened.add(url);
    _playing.value = false;
    _title.value = null;
  }

  @override
  Future<void> play() async {
    final url = opened.lastOrNull;
    if (url == null) return;
    if (failing.contains(url)) {
      _errors.add('açılamadı: $url');
    } else if (autoPlay) {
      _playing.value = true;
    }
  }

  @override
  Future<void> pause() async => _playing.value = false;

  @override
  Future<void> stop() async => _playing.value = false;

  @override
  Future<void> dispose() async => disposed = true;
}
