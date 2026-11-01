import 'dart:async';

import 'package:flutter/foundation.dart';

import '../content/live_channel.dart';
import 'engine/playback_engine.dart';
import 'stream_probe.dart';

/// Oynatmanın evresi.
enum PlaybackStatus {
  /// Akış açılıyor, görüntü bekleniyor.
  loading,

  /// Görüntü geldi.
  playing,

  /// Kanalın bütün akışları denendi, hiçbiri açılmadı.
  failed,
}

/// Bir oynatma oturumu: kanal dizisi, şimdiki kanal ve akışı, otomatik yedek
/// geçişi (eski sürümdeki "Auto-Failover"). Akış hata verirse ya da
/// [startupTimeout] içinde görüntü gelmezse sıradaki akışa geçilir; hepsi
/// denenince kanal [PlaybackStatus.failed] olur. [rank] verilirse akışlar
/// açılmadan önce sıralanır (StreamProbe: hızlı açılanlar içinde bit hızı en
/// yüksek olan önde).
class PlaybackSession extends ChangeNotifier {
  PlaybackSession({
    required this.engine,
    required this.channels,
    required int initialIndex,
    this.startupTimeout = defaultStartupTimeout,
    this.staleErrorWindow = const Duration(seconds: 1),
    this.rank,
    this.resolve,
  }) : assert(channels.isNotEmpty) {
    engine.state.addListener(_onEngine);
    _errorSubscription = engine.errors.listen(_onError);
    _open(initialIndex);
  }

  final PlaybackEngine engine;

  /// Yukarı/aşağı ile gezilen kanal dizisi.
  final List<LiveChannel> channels;

  /// Görüntünün gelmesi için beklenen en uzun süre. Eski sürüm (ExoPlayer)
  /// TV'de 2,5 sn bekliyordu; mpv gerçek kanalları Chromecast with Google TV'de
  /// 6–12 sn'de açtı (ölçüldü), 10 sn sınırında kanallar bir açılıp bir
  /// açılmıyordu.
  final Duration startupTimeout;

  static const defaultStartupTimeout = Duration(seconds: 15);

  /// Hatayla yedek akışa geçtikten sonra bu süre gelen hatalar eski akışındır
  /// (emülatörde açılmayan adres iki hata bildirdi; ikincisi yedek akışı da
  /// "açılamadı" saydırıyordu). Yeni akış bu sürede hata verirse
  /// [startupTimeout] yakalar.
  final Duration staleErrorWindow;

  /// Akış sıralayıcı; null ise listedeki sıra.
  final StreamRanker? rank;

  /// Açmadan önce adresi çözer (STB portalının kısa ömürlü bağlantıları:
  /// UserSources.resolve); null ise adres olduğu gibi açılır. Çözülemeyen
  /// akış hata sayılır, sıradakine geçilir.
  final Future<String> Function(String url)? resolve;

  late final StreamSubscription<String> _errorSubscription;
  Timer? _startupTimer;
  Timer? _staleTimer;

  int _index = 0;
  int _stream = 0;

  /// Şimdiki kanalın akışları, denenecek sırayla.
  List<String> _streams = const [];

  /// Kanal her açılışta artar: geç gelen sıralama sonucu eski kanala uygulanmaz.
  int _generation = 0;
  bool _disposed = false;
  int? _previous;
  PlaybackStatus _status = PlaybackStatus.loading;
  String? _lastError;

  int get index => _index;
  LiveChannel get channel => channels[_index];

  /// Şimdiki akışın sırası (0'dan) ve sayısı: "Akış 1/2".
  int get streamIndex => _stream;
  int get streamCount => _streams.length;

  PlaybackStatus get status => _status;

  /// Son hata iletisi (yalnız bilgi için; kullanıcıya Türkçe ileti gösterilir).
  String? get lastError => _lastError;

  /// Önceki kanal ("0" tuşu, Seçenekler → Önceki kanal).
  LiveChannel? get previousChannel => _previous == null ? null : channels[_previous!];

  void _open(int index) {
    if (index != _index) _previous = _index;
    _index = index;
    _stream = 0;
    final generation = ++_generation;
    final rank = this.rank;
    if (rank == null || channel.streams.length < 2) {
      _streams = channel.streams;
      _play();
      return;
    }
    // Sıralama sürerken "yükleniyor"; açılış süresi sıralamadan sonra başlar.
    _startupTimer?.cancel();
    _streams = channel.streams;
    _setStatus(PlaybackStatus.loading);
    unawaited(
      rank(channel.streams).then(
        (ordered) {
          if (_disposed || generation != _generation) return;
          _streams = ordered;
          _play();
        },
        onError: (Object _) {
          if (!_disposed && generation == _generation) _play();
        },
      ),
    );
  }

  void _play() {
    _startupTimer?.cancel();
    _lastError = null;
    if (_streams.isEmpty) {
      _setStatus(PlaybackStatus.failed);
      return;
    }
    _setStatus(PlaybackStatus.loading);
    // Zamanlayıcı açılıştan önce: motor hatayı hemen bildirirse yedek akışa
    // geçiş bu zamanlayıcıyı iptal eder (sonradan kurulsaydı ortada kalırdı).
    _startupTimer = Timer(startupTimeout, _failover);
    final url = _streams[_stream];
    final resolve = this.resolve;
    if (resolve == null) {
      unawaited(engine.open(url));
      return;
    }
    final generation = _generation;
    final stream = _stream;
    unawaited(
      resolve(url).then(
        (real) {
          if (!_disposed && generation == _generation && stream == _stream) unawaited(engine.open(real));
        },
        onError: (Object _) {
          if (!_disposed && generation == _generation && stream == _stream) _failover();
        },
      ),
    );
  }

  void _setStatus(PlaybackStatus status) {
    _status = status;
    notifyListeners();
  }

  void _onEngine() {
    if (_status == PlaybackStatus.loading && engine.state.value.hasVideo) {
      _startupTimer?.cancel();
      _setStatus(PlaybackStatus.playing);
    }
  }

  void _onError(String message) {
    _lastError = message;
    // Açıldıktan sonraki hatalar (geçici ağ uyarıları) yayını kesmez; mpv
    // gerekirse kendisi yeniden bağlanır.
    if (_status != PlaybackStatus.loading || (_staleTimer?.isActive ?? false)) return;
    _staleTimer = Timer(staleErrorWindow, () {});
    _failover();
  }

  /// Sıradaki akışa geç; akış kalmadıysa kanal açılamadı.
  void _failover() {
    _startupTimer?.cancel();
    if (_stream + 1 < streamCount) {
      _stream++;
      _play();
    } else {
      _setStatus(PlaybackStatus.failed);
    }
  }

  /// Kanal değiştir: +1 sonraki, -1 önceki (dizinin ucunda başa döner).
  void zap(int delta) => _open((_index + delta) % channels.length);

  /// Dizideki kanalı aç.
  void openAt(int index) => _open(index);

  /// Önceki kanala dön; yoksa false.
  bool openPrevious() {
    final p = _previous;
    if (p == null) return false;
    _open(p);
    return true;
  }

  /// Numarası verilen kanalı aç; yoksa false.
  bool openNumber(int number) {
    final i = channels.indexWhere((c) => c.number == number);
    if (i < 0) return false;
    _open(i);
    return true;
  }

  /// Elle sıradaki akış (sonuncudan sonra ilkine döner).
  void nextStream() {
    if (streamCount < 2) return;
    _stream = (_stream + 1) % streamCount;
    _play();
  }

  /// Bütün akışları baştan dene.
  void retry() {
    _stream = 0;
    _play();
  }

  @override
  void dispose() {
    _disposed = true;
    _startupTimer?.cancel();
    _staleTimer?.cancel();
    unawaited(_errorSubscription.cancel());
    engine.state.removeListener(_onEngine);
    super.dispose();
  }
}
