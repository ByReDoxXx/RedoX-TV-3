import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../content/diagnostics.dart';
import '../content/live_channel.dart';
import 'engine/late_closer.dart';

/// Yayından tek kare: JPEG baytları; alınamazsa null.
typedef FrameGrabber = Future<Uint8List?> Function(String url);

/// Kanal kartları için yayından gerçek kare (kullanıcı isteği: "yayının
/// oynamasına gerek yok, bir kare alsa yeter").
///
/// Ayrı ve sessiz bir mpv, görüntüyü ekrana değil dosyaya yazar (`vo=image`,
/// JPEG) ve ilk kareden sonra durur (`frames=1`). Çözücü donanımsaldır, kare
/// belleğe kopyalanır (`mediacodec-copy`; masaüstünde `auto-copy`); açılmazsa
/// mpv yazılıma düşer. Yazılım çözücü 1080p akışta zayıf TV işlemcisini
/// açılışta boğuyordu. Dosya geçici klasörden okunup silinir.
/// (`vo=null` + `screenshot-raw` denendi: kare saklanmadığı için boş döndü.)
///
/// [cancelled] doğru olunca (film açıldı) kare beklenmez. Kapanmayan oynatıcı
/// varken yenisi açılmaz: her biri bir donanım çözücü tutar.
Future<Uint8List?> grabFrame(
  String url, {
  Duration timeout = const Duration(seconds: 15),
  bool Function()? cancelled,
}) async {
  if (_grabberOpen) return null;
  final dir = await Directory.systemTemp.createTemp('redox-kare-');
  final player = Player(configuration: const PlayerConfiguration(vo: 'image', muted: true));
  try {
    final native = player.platform;
    if (native is! NativePlayer) return null;
    // media_kit görüntüsü bağlanmamış oynatıcıda görüntüyü hiç çözmez (vid=no).
    await native.setProperty('vid', 'auto');
    await native.setProperty('aid', 'no');
    await native.setProperty('hwdec', Platform.isAndroid ? 'mediacodec-copy' : 'auto-copy');
    await native.setProperty('frames', '1');
    await native.setProperty('vo-image-format', 'jpg');
    await native.setProperty('vo-image-jpeg-quality', '80');
    await native.setProperty('vo-image-outdir', dir.path);
    await native.setProperty('demuxer-lavf-analyzeduration', '1');
    await native.setProperty('network-timeout', '10');
    await player.open(Media(url)).timeout(timeout);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) && !(cancelled?.call() ?? false)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList();
      if (files.isEmpty) continue;
      // Yazma bitsin: boyut iki yoklamada aynı kalmalı.
      final size = files.first.lengthSync();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (size > 0 && files.first.lengthSync() == size) {
        return await files.first.readAsBytes();
      }
    }
    return null;
  } on Object {
    return null;
  } finally {
    await _closeGrabber(player);
    unawaited(dir.delete(recursive: true).then<void>((_) {}, onError: (Object _) {}));
  }
}

/// Kare oynatıcısı kapanamadı: kapanana dek yeni kare alınmaz.
bool _grabberOpen = false;

/// `dispose` çekirdek meşgulken bitmez; sonsuza dek beklenirse kuyruk da durur.
Future<void> _closeGrabber(Player player) async {
  final closing = player.dispose();
  try {
    await closing.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    _grabberOpen = true;
    LateCloser.open++;
    Diagnostics.instance.log('oynatıcı', 'kare oynatıcısı vaktinde kapanmadı (${LateCloser.open} açık)');
    unawaited(
      closing.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
        _grabberOpen = false;
        LateCloser.open--;
        Diagnostics.instance.log('oynatıcı', 'kare oynatıcısı sonradan kapandı (${LateCloser.open} açık)');
      }),
    );
  } on Object {
    // Zaten kapanmış olabilir.
  }
}

/// Kanal başına son alınan kare. Kareler sırayla, tek tek alınır (zayıf
/// TV işlemcisinde iki çözücü aynı anda çalışmasın); [pause] ile durur
/// ve süren alımı keser (örn. bir kanal izlenirken). Kare [freshFor] boyunca tazedir.
class FrameStore extends ChangeNotifier {
  FrameStore({
    this._grabber,
    this.freshFor = const Duration(minutes: 10),
    this.startDelay = Duration.zero,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// İlk kare bu kadar sonra alınır: açılışta arayüz, kanal listesi ve akış
  /// işlemciyi paylaşmasın.
  final Duration startDelay;
  bool _started = false;

  /// Testin yerine koyduğu; null ise gerçek kare alınır, [pause] alımı keser.
  final FrameGrabber? _grabber;

  Future<Uint8List?> _grab(String url) => _grabber?.call(url) ?? grabFrame(url, cancelled: () => _paused || _disposed);
  final Duration freshFor;
  final DateTime Function() _clock;

  final _frames = <int, (DateTime, Uint8List)>{};
  final _queue = <LiveChannel>[];
  bool _running = false;
  bool _paused = false;
  bool _disposed = false;

  /// Kanalın karesi (eski olsa da); hiç alınmadıysa null.
  Uint8List? frameOf(LiveChannel c) => _frames[c.number]?.$2;

  /// Bu kanalların karelerini sırayla alır (taze olanlar atlanır). Önceki
  /// istek kuyruktaysa yerini bu alır.
  void request(List<LiveChannel> channels) {
    _queue
      ..clear()
      ..addAll(channels.where((c) => !_isFresh(c) && c.streams.isNotEmpty));
    _paused = false;
    unawaited(_run());
  }

  /// Sıradaki kareyi almaz; süren alım kareyi beklemeyi bırakır.
  void pause() => _paused = true;

  bool _isFresh(LiveChannel c) {
    final f = _frames[c.number];
    return f != null && _clock().difference(f.$1) < freshFor;
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      if (!_started) {
        _started = true;
        if (startDelay > Duration.zero) await Future<void>.delayed(startDelay);
      }
      while (_queue.isNotEmpty && !_paused && !_disposed) {
        final c = _queue.removeAt(0);
        // İlk açılan akış yeter; açılmazsa ikincisi.
        for (final url in c.streams.take(2)) {
          final jpeg = await _grab(url);
          if (_disposed) return;
          if (jpeg != null && jpeg.isNotEmpty) {
            _frames[c.number] = (_clock(), jpeg);
            notifyListeners();
            break;
          }
          // Kesilen alımda ikinci akış denenmez.
          if (_paused) break;
        }
      }
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    super.dispose();
  }
}
