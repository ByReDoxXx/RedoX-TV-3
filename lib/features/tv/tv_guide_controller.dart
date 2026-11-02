import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/xmltv.dart';
import 'tv_content.dart';

/// Televizyon içeriğini canlı tutar: güncel kanal listesini açılışta, yayın
/// akışını açılışta ve [refresh] aralıkla indirir; kanalların "şimdi"
/// bilgisini her dakika başında yeniler. İndirme başarısız olursa eldeki liste
/// ve akış kalır.
class TvGuideController extends ValueNotifier<TvContent> {
  TvGuideController(
    super.value, {
    required this.load,
    this.loadChannels,
    this.clock = DateTime.now,
    this.refresh = const Duration(hours: 6),
  });

  /// Yayın akışı (EpgSource.load).
  final Future<EpgGuide> Function() load;

  /// Güncel kanal listesi (ChannelSource.download); null dönerse eldeki kalır.
  final Future<List<LiveChannel>?> Function()? loadChannels;

  final DateTime Function() clock;
  final Duration refresh;

  EpgGuide _guide = EpgGuide.empty;

  /// Kanal listesi ve yayın akışının son indirildiği an (Ayarlar ›
  /// Hakkında); bu açılışta inmediyse null.
  final channelsUpdated = ValueNotifier<DateTime?>(null);
  final guideUpdated = ValueNotifier<DateTime?>(null);

  /// Kanal listesini ve yayın akışını hemen yeniden indirir.
  Future<void> refreshNow() => Future.wait([_fetchChannels(), _fetch()]);
  Timer? _minute;
  Timer? _reload;
  bool _disposed = false;

  /// Saati, kanal listesini ve akışı başlatır. İlk indirmeler bitince döner
  /// (testler bekleyebilir).
  Future<void> start() async {
    _apply();
    _scheduleMinute();
    _reload = Timer.periodic(refresh, (_) => unawaited(_fetch()));
    await Future.wait([_fetchChannels(), _fetch()]);
  }

  Future<void> _fetchChannels() async {
    final channels = await loadChannels?.call();
    if (_disposed || channels == null || channels.isEmpty) return;
    value = TvContent(channels: channels).withGuide(_guide, clock());
    channelsUpdated.value = clock();
  }

  /// Sonraki dakika başında yenile, sonra her dakika (başlık saati kaymasın).
  void _scheduleMinute() {
    final now = clock();
    final wait = Duration(seconds: 60 - now.second, milliseconds: -now.millisecond);
    _minute = Timer(wait, () {
      _apply();
      _minute = Timer.periodic(const Duration(minutes: 1), (_) => _apply());
    });
  }

  Future<void> _fetch() async {
    final guide = await load();
    if (_disposed || guide.channelCount == 0) return;
    _guide = guide;
    guideUpdated.value = clock();
    _apply();
  }

  void _apply() {
    if (!_disposed) value = value.withGuide(_guide, clock());
  }

  @override
  void dispose() {
    _disposed = true;
    _minute?.cancel();
    _reload?.cancel();
    super.dispose();
  }
}
