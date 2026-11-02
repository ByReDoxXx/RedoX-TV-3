import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../content/app_settings.dart';
import '../../content/diagnostics.dart';
import '../subtitle_look.dart';
import 'playback_engine.dart';

/// media_kit (libmpv) ile oynatma. Uygulama başında
/// `MediaKit.ensureInitialized()` çağrılmış olmalı (main.dart).
class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine() {
    // Görüntü denetleyicisi yayın açılmadan kurulur: donanım çözücü ve
    // kopyasız çıkış ayarı mpv'ye ilk yayından önce verilsin. Önceden ilk
    // çizimde kuruluyordu, yayın ondan önce açıldığı için telefonda 4K HEVC
    // bile yazılımla çözülüyordu (hwdec-current=no; Pixel'de görüldü).
    _video = VideoController(_player, configuration: _android ? _zeroCopy : const VideoControllerConfiguration());
    unawaited(_tune());
    if (_android) unawaited(_watchSurface());
    final s = _player.stream;
    _subscriptions.addAll([
      s.playing.listen((v) => _update(_state.value.copyWith(playing: v))),
      s.buffering.listen((v) => _update(_state.value.copyWith(buffering: v))),
      s.width.listen((v) => unawaited(_onWidth(v))),
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
  late final VideoController _video;

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
  /// Ayarlar › Oynatıcı: ön bellek (ileriye okunan süre) ve tercih edilen ses
  /// ve altyazı dili (mpv alang/slang; altyazı "Kapalı" ise hiç seçilmez).
  Future<void> _tune() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    await native.setProperty('demuxer-lavf-analyzeduration', '1');
    await native.setProperty('network-timeout', '10');
    final settings = AppSettings.instance;
    if (settings.buffer.seconds case final s?) {
      await native.setProperty('cache', 'yes');
      await native.setProperty('cache-secs', '$s');
      await native.setProperty('demuxer-readahead-secs', '$s');
    }
    if (settings.audio.codes.isNotEmpty) await native.setProperty('alang', settings.audio.codes);
    // Gece modu: ffmpeg acompressor (eşiğin üstünü 4'te bire sıkıştırır,
    // kazançla kısık sesleri yükseltir).
    if (settings.nightMode) {
      await native.setProperty('af', 'lavfi=[acompressor=threshold=0.125:ratio=4:attack=20:release=250:makeup=2]');
    }
    switch (settings.subtitles) {
      case TrackLanguage.off:
        await native.setProperty('sid', 'no');
      case final TrackLanguage l when l.codes.isNotEmpty:
        await native.setProperty('slang', l.codes);
      default:
        break;
    }
  }

  /// Yayının görüntü biçimi tanılama günlüğüne (yayın başına bir kez, ilk
  /// boyut gelince): kodek, çözücü, renk aktarımı (HDR: pq/hlg), renk uzayı
  /// ve Dolby Vision profili. Kopyasız yolda kareler mpv'den geçmediği için
  /// bilgiler parça listesinden ve çözücü parametrelerinden okunur. Renk
  /// sorunlarını (pembe/yeşil görüntü) ayırt etmek için.
  bool _videoLogged = false;

  Future<void> _logVideo(int? width) async {
    if (_videoLogged || (width ?? 0) == 0) return;
    _videoLogged = true;
    // Görüntü yüzeyi bağlanınca media_kit çıkışı ve çözücüyü yeniden kurar:
    // ölçüm ondan sonra.
    await Future<void>.delayed(const Duration(seconds: 6));
    final native = _player.platform;
    if (native is! NativePlayer) return;
    Future<String> get(String name) async {
      try {
        final v = await native.getProperty(name);
        return v.isEmpty ? '-' : v;
      } on Object {
        return '?';
      }
    }

    final parts = [
      for (final name in const [
        'video-codec',
        'current-vo',
        'hwdec',
        'hwdec-current',
        'current-tracks/video/codec',
        'current-tracks/video/dolby-vision-profile',
        'video-dec-params/gamma',
        'video-dec-params/primaries',
        'video-dec-params/colormatrix',
        'video-dec-params/pixelformat',
        'video-params/gamma',
      ])
        '$name=${await get(name)}',
    ];
    Diagnostics.instance.log('görüntü', '${width}p-genişlik ${parts.join(' ')}');
  }

  /// İlk görüntü boyutu geldi. Android'de önce yayının HDR olup olmadığına
  /// bakılır; HDR ise yol SDR'ye çevrilir. "Görüntü geldi" (boyut) bundan
  /// sonra bildirilir: oynatıcı o ana kadar yükleniyor gösterir, pembe ilk
  /// kareler görünmez (önce 6 sn pembe kalıyordu).
  bool _hdrChecked = false;

  Future<void> _onWidth(int? width) async {
    if (_android && !_hdrChecked && (width ?? 0) > 0) {
      _hdrChecked = true;
      final native = _player.platform;
      if (native is NativePlayer) await _hdrToSdr(native);
    }
    _update(_state.value.copyWith(width: () => width));
    unawaited(_logVideo(width));
  }

  /// HDR yayında kopyasız yol pembe görüntü veriyordu (Pixel'de görüldü):
  /// donanım çözücü HDR10/HLG kareleri (10-bit, BT.2020, PQ) doğrudan
  /// Flutter'ın görüntü yüzeyine yazıyor, yüzey onları SDR sanıyor. HDR
  /// yayında yol kopyalıya geçer: kareler mpv'ye gelir, mpv HDR'yi SDR'ye
  /// ton eşler (bt.2390) ve yüzeye çizer. Daha çok işlemci ister; yalnız
  /// HDR yayında.
  bool _sdrPath = false;

  /// media_kit'in Android denetleyicisi (yüzey ve kilit); dışa açık türü
  /// yok, alanlarına dinamik erişilir. Bulunamazsa null.
  dynamic _android0;

  /// media_kit görüntü yüzeyi yeniden kurulunca (arka plandan dönüş, yüzey
  /// değişimi) çıkışı yapılandırmadaki kopyasız yola döndürür; HDR
  /// yayındaysak SDR yolu kendi kilidinde, onun ardından yeniden kurulur.
  Future<void> _watchSurface() async {
    try {
      final dynamic android = await _video.platform.future;
      _android0 = android;
      (android.wid as ValueNotifier<int?>).addListener(() {
        if (_sdrPath) unawaited(_locked(_applySdrPath));
      });
    } on Object {
      // media_kit iç yapısı değişti: HDR yolu yalnız açılışta kurulur.
    }
  }

  /// Yüzey hazır mı: mpv'nin kendi "wid" değerinden okunur. Değilken
  /// çıkış kurulursa libmpv uygulamayı kapatır ("WinID != 0" doğrulaması;
  /// Pixel'de görüldü: media_kit'in Dart tarafındaki yüzey değeri mpv'ye
  /// geçmeden doluyordu). Hazır değilse yüzey gelince dinleyici kurar.
  Future<bool> _surfaceReady(NativePlayer native) async {
    try {
      final wid = (await native.getProperty('wid')).trim();
      return wid.isNotEmpty && wid != '0' && wid != '-1';
    } on Object {
      return false;
    }
  }

  /// media_kit'in kendi kilidinde çalıştırır (çıkış ayarları onun yüzey
  /// dinleyicisiyle çakışmasın); denetleyici bulunamazsa çalıştırmaz.
  Future<void> _locked(Future<void> Function() body) async {
    final android = _android0;
    if (android == null) return;
    try {
      await (android.lock.synchronized(body) as Future<void>);
    } on NoSuchMethodError {
      // media_kit iç yapısı değişti.
    }
  }

  Future<void> _hdrToSdr(NativePlayer native) async {
    if (!_android || _sdrPath) return;
    final gamma = await native.getProperty('video-dec-params/gamma');
    if (gamma != 'pq' && gamma != 'hlg') return;
    _sdrPath = true;
    Diagnostics.instance.log('görüntü', 'HDR ($gamma): SDR\'ye ton eşlemeli kopyalı yola geçildi');
    // Yüzey henüz yoksa media_kit yüzeyi bağlayınca dinleyici uygular.
    await _locked(_applySdrPath);
    unawaited(_logDrops(native));
  }

  /// Kopyalı yolun yükü: 10 sn sonra atlanan kareler günlüğe.
  Future<void> _logDrops(NativePlayer native) async {
    await Future<void>.delayed(const Duration(seconds: 10));
    if (!_sdrPath) return;
    final drops = await native.getProperty('frame-drop-count');
    final decoderDrops = await native.getProperty('decoder-frame-drop-count');
    final fps = await native.getProperty('estimated-vf-fps');
    Diagnostics.instance.log('görüntü', 'HDR→SDR 10 sn: atlanan kare $drops, çözücü $decoderDrops, fps $fps');
  }

  /// HDR yayın için kopyalı, ton eşlemeli yol.
  Future<void> _applySdrPath() async {
    final native = _player.platform;
    if (native is! NativePlayer || !await _surfaceReady(native)) return;
    await native.setProperty('vo', 'null');
    await native.setProperty('hwdec', 'mediacodec-copy');
    await native.setProperty('tone-mapping', 'bt.2390');
    await native.setProperty('target-trc', 'srgb');
    await native.setProperty('target-prim', 'bt.709');
    await native.setProperty('vo', 'gpu');
    await native.setProperty('vid', 'auto');
    await _player.seek(_player.state.position);
  }

  /// Yeni yayın açılmadan HDR yolundan kopyasız yola dönüş.
  Future<void> _leaveSdrPath() async {
    final native = _player.platform;
    if (native is! NativePlayer || !await _surfaceReady(native)) return;
    await native.setProperty('vo', 'null');
    await native.setProperty('hwdec', _zeroCopy.hwdec!);
    await native.setProperty('vo', _zeroCopy.vo!);
  }

  /// Ayarlar › Kalite sınırı: yayın birden çok kalite verdiyse (HLS ana
  /// listesi) sınırın altındaki en yüksek kalite seçilir; kullanıcı
  /// Seçenekler'den kalite seçerse ona dokunulmaz. Yayın başına bir kez.
  bool _capped = false;

  void _applyCap(Tracks t) {
    final max = AppSettings.instance.quality.maxHeight;
    if (_capped || max == null) return;
    final fitting = [
      for (final v in t.video)
        if (_real(v.id) && v.h != null && v.h! <= max) v,
    ]..sort((a, b) => b.h! - a.h!);
    final tallest = t.video.where((v) => _real(v.id) && v.h != null).fold<int>(0, (m, v) => v.h! > m ? v.h! : m);
    if (fitting.isEmpty || tallest <= max) return;
    _capped = true;
    unawaited(_player.setVideoTrack(fitting.first));
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
    _applyCap(t);
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
  Future<void> open(String url) async {
    // Yeni yayında boyut ve izler sıfırlanır: "görüntü geldi" yeniden ölçülür.
    _update(const EngineState());
    _capped = false;
    _videoLogged = false;
    _hdrChecked = false;
    if (_sdrPath) {
      _sdrPath = false;
      await _locked(_leaveSdrPath);
    }
    await _player.open(Media(url));
  }

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 100);

  @override
  Future<void> selectVideoTrack(String id) {
    _capped = true;
    return _selectVideoTrack(id);
  }

  Future<void> _selectVideoTrack(String id) => _player.setVideoTrack(switch (id) {
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
      Video(
        controller: _video,
        controls: NoVideoControls,
        fit: fit,
        // Ayarlar › Altyazı: boyut, renk, arka plan, konum, kalınlık.
        subtitleViewConfiguration: SubtitleViewConfiguration(
          style: SubtitleLook.style(AppSettings.instance),
          padding: SubtitleLook.padding(AppSettings.instance),
        ),
      );

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
