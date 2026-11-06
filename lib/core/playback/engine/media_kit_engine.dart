import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../content/app_settings.dart';
import '../../content/diagnostics.dart';
import '../../layout/form_factor.dart';
import '../subtitle_look.dart';
import 'audio_fallback.dart';
import 'late_closer.dart';
import 'mpv_log_ring.dart';
import 'mpv_probe.dart';
import 'native_video_surface.dart';
import 'playback_engine.dart';
import 'seek_gate.dart';
import 'seek_queue.dart';

/// media_kit (libmpv) ile oynatma. Uygulama başında
/// `MediaKit.ensureInitialized()` çağrılmış olmalı (main.dart).
class MediaKitEngine implements PlaybackEngine {
  /// [nativeSurface]: görüntü Flutter'ın arkasındaki ayrı yüzeye çizilir (TV'de tam
  /// ekran oynatıcı); yalnız Android'de.
  MediaKitEngine({bool nativeSurface = false}) : _surface = nativeSurface && _android ? NativeVideoSurface() : null {
    // Görüntü denetleyicisi yayın açılmadan kurulur: donanım çözücü ve
    // kopyasız çıkış ayarı mpv'ye ilk yayından önce verilsin. Önceden ilk
    // çizimde kuruluyordu, yayın ondan önce açıldığı için telefonda 4K HEVC
    // bile yazılımla çözülüyordu (hwdec-current=no; Pixel'de görüldü).
    if (_surface == null) {
      _video = VideoController(_player, configuration: _android ? _zeroCopy : const VideoControllerConfiguration());
    }
    _tuned = _tune();
    if (_android) {
      if (_surface == null) unawaited(_watchSurface());
      _watchdog = EngineWatchdog(ping: _ping, onStuck: _markStuck)..start();
    }
    final s = _player.stream;
    _subscriptions.addAll([
      if (_diagnoseCore) s.log.listen((l) => _mpvLog.add('${l.prefix}: ${l.text}'.trim())),
      s.playing.listen((v) {
        if (!_startLogged) {
          Diagnostics.instance.log('oynatıcı', 'açılışta oynuyor=$v, ${_opening.elapsedMilliseconds} ms');
        }
        _update(_state.value.copyWith(playing: v));
      }),
      s.buffering.listen((v) => _update(_state.value.copyWith(buffering: v))),
      s.width.listen((v) => unawaited(_onWidth(v))),
      s.height.listen((v) => _update(_state.value.copyWith(height: () => v))),
      s.duration.listen((v) => _update(_state.value.copyWith(duration: v))),
      s.position.listen((v) {
        // Bekleyen sarma varken gösterge (ve yazılan izleme yeri) onda kalır: 0'a
        // dönerse çıkınca kaldığı yer silinirdi.
        if (!_gate.holding) _position.value = v;
        if (!_startLogged && v > Duration.zero) {
          _startLogged = true;
          Diagnostics.instance.log('oynatıcı', 'oynatma başladı, ${_opening.elapsedMilliseconds} ms');
        }
      }),
      s.tracks.listen(_onTracks),
      s.track.listen(
        (t) => _update(
          _state.value.copyWith(videoTrack: t.video.id, audioTrack: t.audio.id, subtitleTrack: t.subtitle.id),
        ),
      ),
      s.error.listen((e) {
        if (_transient(e)) {
          Diagnostics.instance.log('oynatıcı', 'geçici ileti: $e');
        } else if (!_onDecoderFailure(e)) {
          _errors.add(e);
        }
      }),
    ]);
  }

  final _player = Player(
    configuration: PlayerConfiguration(logLevel: _diagnoseCore ? MPVLogLevel.v : MPVLogLevel.error),
  );
  late final VideoController _video;
  final NativeVideoSurface? _surface;

  @override
  bool get paintsBehindUi => _surface != null;

  /// TV'de çekirdek takılması (Philips) çözülene dek: mpv'nin ayrıntılı günlüğü
  /// bellekte tutulur, takılınca tanılamaya yazılır.
  static bool get _diagnoseCore => _android && _tv;
  final _mpvLog = MpvLogRing();

  /// Oynatıcı ayarları bitti: ilk yayın bunlarla açılsın.
  late final Future<void> _tuned;

  /// Her açılışta artar: eski açılışın gecikmiş işleri yeniye karışmaz.
  int _openId = 0;
  final _opening = Stopwatch();
  bool _startLogged = true;

  /// Şimdiki ayarlar cihazdaki dosya için mi.
  bool _localTuned = false;
  EngineWatchdog? _watchdog;

  /// Oynatıcı çekirdeği yanıt vermiyor: ona dokunan her çağrı arayüzü
  /// dondurur, çağrılmaz (motor kapanırken de).
  bool _stuck = false;
  bool _disposed = false;

  /// Süren ayrı isolate okumaları: oynatıcı kapatılmadan biter (kapanmış
  /// oynatıcıyı okumak uygulamayı düşürür).
  final _reads = <Future<Object?>>{};

  /// Bilgi okumalarının süresi; takılı çekirdekte boşuna beklenmez.
  static const _readTimeout = Duration(seconds: 8);

  /// mpv özellikleri, arayüzü dondurmadan ([MpvProbe]). Okunamayan değer null;
  /// takılı ya da kapanmış oynatıcıda ve süre aşılınca boş.
  Future<Map<String, String?>> _read(List<String> names) async {
    if (_stuck || _disposed) return const {};
    if (!_android) {
      final native = _player.platform;
      if (native is! NativePlayer) return const {};
      return {
        for (final name in names)
          name: await native.getProperty(name).then<String?>((v) => v, onError: (Object _) => null),
      };
    }
    final handle = await _player.handle;
    if (_stuck || _disposed) return const {};
    final read = MpvProbe.read(library: 'libmpv.so', handle: handle, names: names);
    _reads.add(read);
    unawaited(read.then<void>((_) {}, onError: (Object _) {}).whenComplete(() => _reads.remove(read)));
    try {
      return await read.timeout(_readTimeout);
    } on TimeoutException {
      return const {};
    }
  }

  /// Bekçinin yoklaması: görüntü yokken (yayın açılırken) yoklanmaz.
  Future<void> _ping() async {
    if (_stuck || _disposed || !_state.value.hasVideo) return;
    final handle = await _player.handle;
    final read = MpvProbe.read(library: 'libmpv.so', handle: handle, names: const ['time-pos']);
    _reads.add(read);
    unawaited(read.then<void>((_) {}, onError: (Object _) {}).whenComplete(() => _reads.remove(read)));
    await read;
  }

  void _markStuck() {
    if (_stuck || _disposed) return;
    _stuck = true;
    Diagnostics.instance.log('görüntü', 'oynatıcı yanıt vermiyor (donanım çözücü takılmış olabilir)');
    for (final line in _mpvLog.lines) {
      Diagnostics.instance.log('mpv', line);
    }
    _update(_state.value.copyWith(stuck: true));
  }

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// TV sürümü (zayıf kutu: kopyalı yol yalnız gerektiğinde).
  static bool get _tv => FormFactor.current == FormFactor.tv;

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
    if (_surface != null) await _attachSurface(native, _surface);
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

  /// media_kit'in denetleyicisi yerine (o Flutter dokusuna bağlar): aynı ayarlar, ayrı
  /// yüzey. Yayın açılmadan bağlanır; çözücü baştan donanımla kurulur, yeniden
  /// kurulup sarılmaz. Yüzey gelmezse açılış bekletilmez (görüntü gelmez, süre dolar).
  Future<void> _attachSurface(NativePlayer native, NativeVideoSurface surface) async {
    for (final e in const {
      'vo': 'null',
      'hwdec': 'mediacodec',
      'vid': 'auto',
      'force-window': 'no',
      'sub-use-margins': 'no',
      'sub-font-provider': 'none',
      'sub-scale-with-window': 'yes',
      'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
    }.entries) {
      await native.setProperty(e.key, e.value);
    }
    await _lockToDisplay(native);
    final first = Completer<void>();
    var attached = false;
    surface.wid.addListener(() {
      final wid = surface.wid.value;
      if (wid != null && !first.isCompleted) first.complete();
      if (_stuck || _disposed) return;
      unawaited(_applySurface(native, wid, reattach: attached));
      attached = true;
    });
    await surface.open();
    try {
      await first.future.timeout(const Duration(seconds: 3));
      await _surfaceApplied;
    } on TimeoutException {
      Diagnostics.instance.log('görüntü', 'video yüzeyi gelmedi');
    }
  }

  /// Deneme (TV): mediacodec_embed kareyi yenilemeye hizalamadan "hemen göster" diye
  /// verir; 24 kare 60 Hz'de 2-3 düzeni kayıyor (Philips ölçümü). Film ekrana kilitlenir
  /// (24 kare %0,1 hızlanır). Bu çıkış yenilemeyi görmez, mpv'ye ekran hızı bildirilir.
  Future<void> _lockToDisplay(NativePlayer native) async {
    final rate = WidgetsBinding.instance.platformDispatcher.displays.firstOrNull?.refreshRate ?? 0;
    if (rate <= 0) return;
    // Paketteki libmpv'de seçeneğin adı bu; yeni sürümlerde display-fps-override.
    await native.setProperty('override-display-fps', '$rate');
    await native.setProperty('video-sync', 'display-resample');
  }

  /// Sıradaki yüzey değişikliği öncekinin üstüne binmesin.
  Future<void> _surfaceApplied = Future.value();

  Future<void> _applySurface(NativePlayer native, int? wid, {required bool reattach}) {
    return _surfaceApplied = _surfaceApplied.then((_) async {
      if (_stuck || _disposed) return;
      // media_kit'in sırası: yüzey değişirken vo=null, yoksa uygulama düşer.
      await native.setProperty('vo', 'null');
      await native.setProperty('wid', '${wid ?? 0}');
      if (wid == null) {
        await native.setProperty('vid', 'no');
        return;
      }
      await native.setProperty('vo', _zeroCopy.vo!);
      await native.setProperty('vid', 'auto');
      // Arka plandan dönüş: çözücü yeni yüzeyde kaldığı yerden sürsün.
      if (reattach) await _player.seek(_player.state.position);
    });
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
    final id = _openId;
    Diagnostics.instance.log('görüntü', 'ilk boyut $width, ${_opening.elapsedMilliseconds} ms');
    // Görüntü yüzeyi bağlanınca media_kit çıkışı ve çözücüyü yeniden kurar:
    // ölçüm ondan sonra.
    await Future<void>.delayed(const Duration(seconds: 6));
    if (id != _openId) return;
    const names = [
      'video-codec',
      'current-vo',
      'current-ao',
      'hwdec',
      'hwdec-current',
      'current-tracks/video/codec',
      'current-tracks/video/dolby-vision-profile',
      'video-dec-params/gamma',
      'video-dec-params/primaries',
      'video-dec-params/colormatrix',
      'video-dec-params/pixelformat',
      'video-params/gamma',
      'video-format',
      'file-format',
    ];
    final values = await _read(names);
    if (_disposed) return;
    final parts = [
      for (final name in names)
        '$name=${switch (values[name]) {
          null => '?',
          '' => '-',
          final v => v,
        }}',
    ];
    Diagnostics.instance.log('görüntü', '${width}p-genişlik ${parts.join(' ')}');
    unawaited(_logDrops(id));
    if (_diagnoseCore) unawaited(_logSync(id));
  }

  /// TV: kasma incelenirken 30 sn'de bir mpv'nin kendi zamanlama sayaçları. Ekran
  /// ölçümü yalnız Flutter yüzeyini görüyor; filmin kareleri ondan önce kayboluyor
  /// olabilir (Philips: ölçüm temizken görüntü "çok kötü kasıyor").
  Future<void> _logSync(int id) async {
    const names = [
      'avsync',
      'total-avsync-change',
      'frame-drop-count',
      'decoder-frame-drop-count',
      'mistimed-frame-count',
      'vo-delayed-frame-count',
      'estimated-vf-fps',
      'current-ao',
      'video-sync',
      'display-sync-active',
      'display-fps',
      'vsync-ratio',
      'vsync-jitter',
      'video-speed-correction',
      'audio-speed-correction',
    ];
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 30));
      if (id != _openId || _disposed || _stuck) return;
      final values = await _read(names);
      if (id != _openId || _disposed || values.isEmpty) return;
      Diagnostics.instance.log('zamanlama', [for (final n in names) '$n=${values[n] ?? '?'}'].join(' '));
    }
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
      if (native is NativePlayer) await _hdrToSdr();
    }
    if (_gate.closed && (width ?? 0) > 0) {
      unawaited(_settleSurface(width));
      return;
    }
    _update(_state.value.copyWith(width: () => width));
    unawaited(_logVideo(width));
  }

  /// Bekletilen sarmanın kapısı: TV'de her açılışta kapanır, görüntü yüzeyi
  /// oturunca açılır.
  late final _gate = SeekGate(_seeks.seek);
  bool _settling = false;
  int? _heldWidth;

  /// Yüzey bu açılışta yeniden bağlandı (aynı boyutta bağlanmaz, süre dolar).
  Completer<void> _surfaceAttached = Completer();

  /// media_kit yüzeyi bağlayıp çözücüyü kurana dek sarma yapılmaz. "Görüntü geldi"
  /// de bekler: kaldığı yerden sürecek film bu arada baştan görünmesin.
  Future<void> _settleSurface(int? width) async {
    _heldWidth = width;
    if (_settling) return;
    _settling = true;
    final id = _openId;
    Future<void> within(Future<void> work, Duration limit) async {
      try {
        await work.timeout(limit);
      } on TimeoutException {
        // Süre dolunca beklemeden sürer: görüntü sonsuza dek gizli kalmasın.
      }
    }

    await within(_surfaceAttached.future, const Duration(seconds: 2));
    if (id != _openId || _disposed) return;
    // Sıra media_kit'in kilidinde: kendi yeniden kurma işi bitmiş olur.
    await within(_locked(() async {}), const Duration(seconds: 3));
    if (id != _openId || _disposed) return;
    // Konum yeniden akınca oynatma sürüyordur: boşaltma kurulumun ortasına düşmez.
    await within(_player.stream.position.first, const Duration(seconds: 3));
    if (id != _openId || _disposed || _stuck) return;
    await within(_gate.open(), const Duration(seconds: 2));
    if (id != _openId || _disposed) return;
    _settling = false;
    _update(_state.value.copyWith(width: () => _heldWidth));
    unawaited(_logVideo(_heldWidth));
  }

  /// HDR yayında kopyasız yol pembe görüntü veriyordu (Pixel'de görüldü):
  /// donanım çözücü HDR10/HLG kareleri (10-bit, BT.2020, PQ) doğrudan
  /// Flutter'ın görüntü yüzeyine yazıyor, yüzey onları SDR sanıyor. HDR
  /// yayında yol kopyalıya geçer: kareler mpv'ye gelir, mpv HDR'yi SDR'ye
  /// ton eşler (bt.2390) ve yüzeye çizer. Daha çok işlemci ister; yalnız
  /// HDR yayında.
  bool _sdrPath = false;

  /// Kopyalı yolun çözücüsü: "mediacodec-copy" (HDR, HEVC) ya da "no"
  /// (yazılım; eski MPEG-4 Part 2 / Xvid / DivX, [_legacy]).
  String _copyHwdec = 'mediacodec-copy';

  /// Donanım çözücüsünde kare atlatan eski kodekler: Pixel'in (Exynos) MPEG-4
  /// çözücüsü Xvid AVI dizilerde 10 sn'de 40 kare atlattı ("Arrow kasıyor";
  /// günlükte görüldü). Bu yayınlar düşük çözünürlüklü, yazılımla rahat çözülür.
  static bool _legacy(String codec) => RegExp(r'mpeg4|mpeg-4 part 2|msmpeg4|h263|divx|xvid').hasMatch(codec);

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
        if (!_surfaceAttached.isCompleted) _surfaceAttached.complete();
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

  Future<void> _hdrToSdr() async {
    // TV'de kopyalı yol yok: Chromecast 4K HDR'de 10 sn'de 15 kare atladı,
    // ses görüntünün önüne geçti (kullanıcı: "kasıyor, ses önden gidiyor").
    // TV kutusu HDR'yi donanımla doğrudan ekrana verir (HDR10/HLG destekli
    // televizyonda renk doğru); pembe görüntü yalnız telefonda görüldü.
    if (!_android || _tv || _sdrPath) return;
    final values = await _read(const ['video-dec-params/gamma', 'video-codec']);
    final gamma = values['video-dec-params/gamma'];
    final hdr = gamma == 'pq' || gamma == 'hlg';
    // Telefon/tablette HEVC de: kopyasız yol bazı HEVC filmlerde (SDR,
    // BT.709 bildiren) yeşil-mor görüntü veriyordu; kopyalı yolda doğru
    // (Pixel'de görüldü, 0 kare atlama). TV'de kopyalı yol 1080p'de bile
    // kare atlattığı için (Chromecast) yalnız HDR'de.
    final codec = (values['video-codec'] ?? '').toLowerCase();
    final hevc = codec.contains('hevc');
    final legacy = _legacy(codec);
    if (!hdr && !hevc && !legacy) return;
    _sdrPath = true;
    _copyHwdec = legacy ? 'no' : 'mediacodec-copy';
    Diagnostics.instance.log('görüntü', switch ((hdr, hevc)) {
      (true, _) => "HDR ($gamma): SDR'ye ton eşlemeli kopyalı yola geçildi",
      (_, true) => 'HEVC: renk için kopyalı yola geçildi',
      _ => 'Eski MPEG-4 (Xvid/DivX): yazılımla çözülüyor',
    });
    // Yüzey henüz yoksa media_kit yüzeyi bağlayınca dinleyici uygular.
    await _locked(_applySdrPath);
  }

  /// Oynatmanın yükü: 10 sn sonra atlanan kareler günlüğe (takılma
  /// şikâyetlerini ayırt etmek için; her yayında bir kez).
  Future<void> _logDrops(int id) async {
    await Future<void>.delayed(const Duration(seconds: 10));
    if (id != _openId) return;
    final values = await _read(const ['frame-drop-count', 'decoder-frame-drop-count', 'estimated-vf-fps']);
    if (_disposed || values.isEmpty) return;
    final drops = values['frame-drop-count'];
    final decoderDrops = values['decoder-frame-drop-count'];
    final fps = values['estimated-vf-fps'];
    final path = !_sdrPath ? 'kopyasız' : (_copyHwdec == 'no' ? 'yazılım' : 'kopyalı');
    Diagnostics.instance.log('görüntü', '$path yol 10 sn: atlanan kare $drops, çözücü $decoderDrops, fps $fps');
    // Grafik belleği dolunca sistem uygulamayı kapatıyor: görsellerin payı görünsün.
    final images = PaintingBinding.instance.imageCache;
    Diagnostics.instance.log('bellek', 'kapanmamış oynatıcı: ${LateCloser.open}');
    final megabytes = images.currentSizeBytes ~/ (1024 * 1024);
    Diagnostics.instance.log(
      'bellek',
      'görsel önbelleği $megabytes MB, ${images.currentSize} görsel, ${images.liveImageCount} canlı',
    );
  }

  /// HDR/HEVC için kopyalı, ton eşlemeli yol; eski MPEG-4'te yazılım çözücüyle.
  Future<void> _applySdrPath() async {
    final native = _player.platform;
    if (native is! NativePlayer || !await _surfaceReady(native)) return;
    await native.setProperty('vo', 'null');
    await native.setProperty('hwdec', _copyHwdec);
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
  final _audioFallbacks = StreamController<AudioFallback>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Tracks _tracks = const Tracks();

  @override
  ValueListenable<EngineState> get state => _state;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<AudioFallback> get audioFallbacks => _audioFallbacks.stream;

  void _update(EngineState next) {
    if (!_disposed) _state.value = next;
  }

  /// mpv'nin "auto"/"no" sözde izleri listeye alınmaz (arayüz "Otomatik" ve
  /// "Kapalı"yı kendisi ekler).
  static bool _real(String id) => id != EngineState.autoTrack && id != EngineState.noTrack;

  /// Çözülemeyen kodekler (bu dosyada; kullanıcı iz seçince sıfırlanır).
  final _failedCodecs = <String>{};

  /// Bildirilen son geçiş: iz değişimi sürerken gelen iz listesi yinelemesin.
  /// Boş metin: çalınabilen ses yok.
  String? _lastFallback;

  /// mpv'ye bu açılışta yedek iz seçtirildi: seçim sonraki dosyaya taşınmasın.
  bool _audioFellBack = false;

  /// Ses izi çözülemediyse yedeğe geçer. İleti ses izine aitse true: yayın
  /// görüntüyle sürer, hata sayılmaz. İzler henüz bilinmiyorsa kodek saklanır,
  /// iz listesi gelince karar verilir.
  bool _onDecoderFailure(String error) {
    final codec = AudioFallbackRule.failedCodec(error);
    if (codec == null) return false;
    _failedCodecs.add(codec);
    if (!_tracks.audio.any((a) => a.codec?.toLowerCase() == codec)) return false;
    Diagnostics.instance.log('oynatıcı', 'ses izi çözülemedi: $codec');
    _fallBackAudio();
    return true;
  }

  void _fallBackAudio() {
    if (_failedCodecs.isEmpty || _stuck || _disposed) return;
    final step = AudioFallbackRule.next(
      tracks: [
        for (final a in _tracks.audio.where((a) => _real(a.id)))
          AudioCandidate(a.id, codec: a.codec, language: a.language),
      ],
      selected: _player.state.track.audio.id,
      failed: _failedCodecs,
    );
    switch (step) {
      case KeepAudio():
        return;
      case SwitchAudio(:final id):
        if (_lastFallback == id) return;
        _lastFallback = id;
        _audioFellBack = true;
        final to = _state.value.audioTracks.firstWhere((t) => t.id == id, orElse: () => MediaTrack(id, 'Ses $id'));
        Diagnostics.instance.log('oynatıcı', 'yedek ses izine geçildi: ${to.label}');
        unawaited(_player.setAudioTrack(_tracks.audio.firstWhere((a) => a.id == id)));
        _audioFallbacks.add(AudioFallback(to));
      case NoPlayableAudio():
        if (_lastFallback == '') return;
        _lastFallback = '';
        Diagnostics.instance.log('oynatıcı', 'çalınabilen ses izi yok');
        _audioFallbacks.add(const AudioFallback(null));
    }
  }

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
    _fallBackAudio();
  }

  @override
  Future<void> open(String url) async {
    if (_stuck) return;
    final id = ++_openId;
    final local = isLocalMedia(url);
    _opening
      ..reset()
      ..start();
    _startLogged = false;
    Diagnostics.instance.log('oynatıcı', local ? 'cihazdaki dosya açılıyor' : 'ağ yayını açılıyor');
    // Yeni yayında boyut ve izler sıfırlanır: "görüntü geldi" yeniden ölçülür.
    _update(const EngineState());
    _tracks = const Tracks();
    _failedCodecs.clear();
    _lastFallback = null;
    _capped = false;
    _videoLogged = false;
    _hdrChecked = false;
    _settling = false;
    _heldWidth = null;
    _surfaceAttached = Completer();
    if (_diagnoseCore && _surface == null) _gate.close();
    if (_sdrPath) {
      _sdrPath = false;
      await _locked(_leaveSdrPath);
    }
    await _tuned;
    if (_audioFellBack) {
      _audioFellBack = false;
      await _player.setAudioTrack(AudioTrack.auto());
    }
    await _tuneFor(local: local);
    // Beklerken yeni açılış geldiyse (Tekrar dene, sonraki bölüm) bu açılmaz.
    if (id != _openId || _stuck || _disposed) return;
    await _player.open(Media(url));
  }

  /// Cihazdaki dosya ağ önbelleği olmadan okunur: media_kit önbelleği açık ve
  /// diske yazar kuruyor (cache, cache-on-disk), mpv'nin yerel dosyadaki
  /// kendi kararı ise kapalıdır. Yoksa 4K film USB'den okunurken bir de geçici
  /// dosyaya yazılırdı. Ağ yayınının hızlı açılış ayarı (1 sn çözümleme) de
  /// dosyada ses izlerini kaçırabilir; ffmpeg'in olağan 5 sn'si kullanılır.
  Future<void> _tuneFor({required bool local}) async {
    final native = _player.platform;
    if (local == _localTuned || native is! NativePlayer) return;
    _localTuned = local;
    final seconds = AppSettings.instance.buffer.seconds;
    await native.setProperty('cache', local ? 'no' : 'yes');
    await native.setProperty('cache-on-disk', local ? 'no' : 'yes');
    await native.setProperty('demuxer-lavf-analyzeduration', local ? '5' : '1');
    await native.setProperty('demuxer-readahead-secs', local ? '5' : '${seconds ?? 1}');
  }

  @override
  Future<void> playOrPause() async {
    if (!_stuck) await _player.playOrPause();
  }

  final _position = ValueNotifier(Duration.zero);

  @override
  ValueListenable<Duration> get position => _position;

  @override
  Future<void> seek(Duration to) async {
    if (_stuck) return;
    final end = _state.value.duration;
    final clamped = to < Duration.zero ? Duration.zero : (end > Duration.zero && to > end ? end : to);
    _position.value = clamped;
    await _gate.seek(clamped);
  }

  /// Art arda basılan ◄► tek sarmada birleşir: her sarma donanım çözücüyü boşaltır
  /// ve Philips'te boşaltma çekirdeği kilitleyebiliyor (► sonrası günlükte görüldü).
  /// Kapatıp yeniden açmak da kilitledi; üstelik `setProperty` arayüzü beklettiği
  /// için uygulama dondu. Burada yalnız zaman uyumsuz komut kullanılır.
  late final _seeks = SeekQueue(_player.seek);

  @override
  Future<void> setMuted(bool muted) async {
    if (!_stuck) await _player.setVolume(muted ? 0 : 100);
  }

  @override
  Future<void> selectVideoTrack(String id) async {
    if (_stuck) return;
    _capped = true;
    await _player.setVideoTrack(switch (id) {
      EngineState.autoTrack => VideoTrack.auto(),
      EngineState.noTrack => VideoTrack.no(),
      _ => _tracks.video.firstWhere((v) => v.id == id, orElse: VideoTrack.auto),
    });
  }

  @override
  Future<void> selectAudioTrack(String id) async {
    if (_stuck) return;
    // Kullanıcının seçimi: seçtiği iz de çözülemezse yeniden yedeğe geçilir.
    _failedCodecs.clear();
    _lastFallback = null;
    await _player.setAudioTrack(switch (id) {
      EngineState.autoTrack => AudioTrack.auto(),
      EngineState.noTrack => AudioTrack.no(),
      _ => _tracks.audio.firstWhere((a) => a.id == id, orElse: AudioTrack.auto),
    });
  }

  @override
  Future<void> selectSubtitleTrack(String id) async {
    if (_stuck) return;
    await _player.setSubtitleTrack(switch (id) {
      EngineState.autoTrack => SubtitleTrack.auto(),
      EngineState.noTrack => SubtitleTrack.no(),
      _ => _tracks.subtitle.firstWhere((s) => s.id == id, orElse: SubtitleTrack.auto),
    });
  }

  @override
  Future<StreamStats> stats() async {
    final values = await _read(const [
      'hwdec-current',
      'demuxer-cache-duration',
      'video-codec',
      'audio-codec-name',
      'estimated-vf-fps',
      'video-bitrate',
      'audio-bitrate',
      'frame-drop-count',
    ]);
    if (values.isEmpty) return const StreamStats();
    String? get(String name) => switch (values[name]?.trim()) {
      null || '' => null,
      final v => v,
    };

    final hwdec = get('hwdec-current');
    final cache = double.tryParse(get('demuxer-cache-duration') ?? '');
    return StreamStats(
      videoCodec: get('video-codec'),
      audioCodec: get('audio-codec-name'),
      decoder: hwdec == null || hwdec == 'no' ? 'yazılım' : hwdec,
      fps: double.tryParse(get('estimated-vf-fps') ?? ''),
      videoBitrate: double.tryParse(get('video-bitrate') ?? '')?.round(),
      audioBitrate: double.tryParse(get('audio-bitrate') ?? '')?.round(),
      cache: cache == null ? null : Duration(milliseconds: (cache * 1000).round()),
      droppedFrames: int.tryParse(get('frame-drop-count') ?? ''),
    );
  }

  @override
  Widget view({BoxFit fit = BoxFit.contain}) {
    final surface = _surface;
    if (surface != null) {
      final s = _state.value;
      return NativeVideoView(
        surface: surface,
        size: s.hasVideo ? Size(s.width!.toDouble(), s.height!.toDouble()) : null,
        fit: fit,
        subtitles: _player.stream.subtitle,
        subtitleStyle: SubtitleLook.style(AppSettings.instance),
        subtitlePadding: SubtitleLook.padding(AppSettings.instance),
      );
    }
    // Denetimler uygulamanındır (alt çubuk); media_kit'inkiler kapalı.
    return Video(
      controller: _video,
      controls: NoVideoControls,
      fit: fit,
      // Ayarlar › Altyazı: boyut, renk, arka plan, konum, kalınlık.
      subtitleViewConfiguration: SubtitleViewConfiguration(
        style: SubtitleLook.style(AppSettings.instance),
        padding: SubtitleLook.padding(AppSettings.instance),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _watchdog?.stop();
    // Kapatmadan önce çekirdek yanıt veriyor mu: takılıysa kapatma çağrısı da
    // arayüzü dondurur (Geri ile çıkarken). O zaman oynatıcı bırakılır; uygulama
    // yeniden açılınca sistem temizler.
    var responsive = !_stuck;
    if (_android && responsive) {
      try {
        await Future.wait([
          ..._reads,
          MpvProbe.read(library: 'libmpv.so', handle: await _player.handle, names: const ['time-pos']),
        ]).timeout(_disposeProbe);
      } on TimeoutException {
        responsive = false;
        Diagnostics.instance.log('görüntü', 'oynatıcı kapanırken yanıt vermedi');
      } on Object {
        // Okuma hatası takılma değildir.
      }
    }
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _errors.close();
    await _audioFallbacks.close();
    _state.dispose();
    _position.dispose();
    if (responsive) {
      await _player.dispose();
    } else if (_android) {
      unawaited(_closeLate());
    }
    await _surface?.close(keep: !responsive);
  }

  /// Meşgul çekirdeğe önce durmasını söyler: arkada oynamayı sürdürmesin.
  /// Komut da okuma da ayrı isolate'ta: takılan yalnız onlar olur.
  Future<void> _closeLate() async {
    final handle = await _player.handle;
    await LateCloser.closeWhenReady(
      ready: () async {
        await MpvProbe.stop(library: 'libmpv.so', handle: handle);
        await MpvProbe.read(library: 'libmpv.so', handle: handle, names: const ['time-pos']);
      },
      close: _player.dispose,
    );
  }

  static const _disposeProbe = Duration(seconds: 2);
}
