import 'dart:async';

import 'package:flutter/foundation.dart';

import '../content/live_channel.dart';
import 'radio_audio.dart';

/// Radyonun durumu (arayüzdeki rozet ve düğmeler buna göre).
enum RadioStatus {
  /// Hiçbir istasyon açılmadı (ya da radyo kapatıldı).
  idle,

  /// Yayın bağlanıyor.
  connecting,
  playing,
  paused,

  /// İstasyonun hiçbir yayını açılmadı.
  failed,
}

/// Radyo: istasyon seçer, çalar, yayın açılmazsa yedeğe geçer; uyku
/// zamanlayıcısı. Uygulama boyunca tektir (bölüm değişince ses sürer); bir TV
/// kanalı açılınca durur.
class RadioController extends ChangeNotifier {
  RadioController({
    required this._stations,
    RadioAudio Function()? audio,
    this.connectTimeout = const Duration(seconds: 12),
  }) : _audioFactory = audio ?? MediaKitRadioAudio.new;

  final ValueListenable<List<LiveChannel>> _stations;
  final RadioAudio Function() _audioFactory;

  /// Bu sürede ses gelmezse sıradaki yayın denenir.
  final Duration connectTimeout;

  RadioAudio? _audio;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _connectTimer;
  Timer? _sleepTimer;
  DateTime? _sleepAt;
  bool _disposed = false;

  LiveChannel? _current;
  int _stream = 0;
  RadioStatus _status = RadioStatus.idle;
  String? _title;

  List<LiveChannel> get stations => _stations.value;
  ValueListenable<List<LiveChannel>> get stationsListenable => _stations;

  /// Çalan (ya da son çalan) istasyon.
  LiveChannel? get current => _current;
  RadioStatus get status => _status;

  /// Çalan şarkı (yayının üst verisinden); yoksa null.
  String? get title => _title;

  /// Kullanılan yayın: (sıra, toplam), örn. (1, 3).
  (int, int) get streamPosition => (_stream + 1, _current?.streams.length ?? 0);

  bool get active => _status == RadioStatus.playing || _status == RadioStatus.connecting;

  /// Uyku zamanlayıcısının kalan süresi; kapalıysa null.
  Duration? get sleepLeft => switch (_sleepAt) {
    final at? => at.difference(DateTime.now()),
    null => null,
  };

  /// Radyo cızırtısı (eski uygulamadaki seçenek; kullanıcı isteği: geçişlerde
  /// cızırtı): kadran çevrilirken ve yayın bağlanırken çalar, ses gelince
  /// susar.
  bool get noise => _noiseEnabled;
  bool _noiseEnabled = true;

  set noise(bool on) {
    _noiseEnabled = on;
    if (!on) unawaited(_audio?.setNoise(false));
    _notify();
  }

  /// Kadranda gezinirken kısa cızırtı (yeni istasyon çalınca bağlanma
  /// cızırtısına döner, değilse [tuneNoise] sonra susar).
  static const tuneNoise = Duration(milliseconds: 1200);
  Timer? _tuneTimer;

  void tuning() {
    if (!_noiseEnabled) return;
    unawaited(_ensureAudio().setNoise(true));
    _tuneTimer?.cancel();
    _tuneTimer = Timer(tuneNoise, () {
      if (_status != RadioStatus.connecting) unawaited(_audio?.setNoise(false));
    });
  }

  /// Uyku zamanlayıcısı seçenekleri (dakika).
  static const sleepChoices = [30, 60, 90];

  RadioAudio _ensureAudio() {
    final existing = _audio;
    if (existing != null) return existing;
    final a = _audioFactory();
    _subscriptions.addAll([a.errors.listen((_) => _nextStream())]);
    a.playing.addListener(() {
      if (a.playing.value && _status == RadioStatus.connecting) {
        _connectTimer?.cancel();
        _set(RadioStatus.playing);
      }
    });
    a.title.addListener(() {
      _title = a.title.value;
      _notify();
    });
    return _audio = a;
  }

  /// İstasyonu ilk yayınından çalar.
  Future<void> play(LiveChannel station) async {
    _current = station;
    _stream = 0;
    _title = null;
    await _open();
  }

  Future<void> _open() async {
    final station = _current;
    if (station == null) return;
    if (_stream >= station.streams.length) {
      _connectTimer?.cancel();
      await _audio?.stop();
      _set(RadioStatus.failed);
      return;
    }
    // Oynatıcı durumdan önce: "bağlanıyor" cızırtısı ilk çalışta da duyulsun.
    final audio = _ensureAudio();
    _set(RadioStatus.connecting);
    _connectTimer?.cancel();
    _connectTimer = Timer(connectTimeout, _nextStream);
    await audio.open(station.streams[_stream]);
    await audio.play();
  }

  void _nextStream() {
    if (_disposed || _current == null || _status == RadioStatus.paused) return;
    _stream++;
    unawaited(_open());
  }

  /// Kullanıcı yayın kaynağını değiştirir (seçenekler: n/m).
  Future<void> switchStream() async {
    final station = _current;
    if (station == null || station.streams.length < 2) return;
    _stream = (_stream + 1) % station.streams.length;
    await _open();
  }

  /// Duraklat/sürdür. Başarısız istasyonda baştan dener.
  Future<void> toggle() async {
    switch (_status) {
      case RadioStatus.playing || RadioStatus.connecting:
        _connectTimer?.cancel();
        await _audio?.pause();
        _set(RadioStatus.paused);
      case RadioStatus.paused:
        await _audio?.play();
        _set(RadioStatus.playing);
      case RadioStatus.failed:
        if (_current case final s?) await play(s);
      case RadioStatus.idle:
        if (_current ?? stations.firstOrNull case final s?) await play(s);
    }
  }

  /// [list] içinde komşu istasyon (kadran, önceki/sonraki): sarar.
  LiveChannel? neighbour(List<LiveChannel> list, int step) {
    if (list.isEmpty) return null;
    final i = _current == null ? -1 : list.indexOf(_current!);
    return list[(i + step) % list.length];
  }

  /// Radyoyu kapatır (TV kanalı açılınca, "Radyoyu kapat").
  Future<void> stop() async {
    _connectTimer?.cancel();
    _cancelSleep();
    await _audio?.stop();
    _title = null;
    _set(RadioStatus.idle);
  }

  /// Uyku zamanlayıcısı: [minutes] sonra radyo kapanır; null kapatır.
  void setSleep(int? minutes) {
    _cancelSleep();
    if (minutes != null) {
      _sleepAt = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), () => unawaited(stop()));
    }
    _notify();
  }

  void _cancelSleep() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
  }

  void _set(RadioStatus s) {
    _status = s;
    // Bağlanırken cızırtı; ses gelince, duraklayınca ya da kapanınca susar.
    final noisy = _noiseEnabled && s == RadioStatus.connecting;
    if (noisy || !(_tuneTimer?.isActive ?? false)) unawaited(_audio?.setNoise(noisy));
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectTimer?.cancel();
    _tuneTimer?.cancel();
    _cancelSleep();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_audio?.dispose());
    super.dispose();
  }
}
