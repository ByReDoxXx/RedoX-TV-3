import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/content/epg_source.dart';
import '../../core/content/xmltv.dart';
import 'tv_content.dart';

/// Televizyon içeriğini canlı tutar: yayın akışını açılışta ve [refresh]
/// aralıkla indirir, kanalların "şimdi" bilgisini her dakika başında yeniler.
/// İndirme başarısız olursa eldeki akış (ya da akışsız liste) kalır.
class TvGuideController extends ValueNotifier<TvContent> {
  TvGuideController(
    super.value, {
    this.load = EpgSource.load,
    this.clock = DateTime.now,
    this.refresh = const Duration(hours: 6),
  });

  final Future<EpgGuide> Function() load;
  final DateTime Function() clock;
  final Duration refresh;

  EpgGuide _guide = EpgGuide.empty;
  Timer? _minute;
  Timer? _reload;
  bool _disposed = false;

  /// Saati ve akışı başlatır. İlk indirme bitince döner (testler bekleyebilir).
  Future<void> start() {
    _apply();
    _scheduleMinute();
    _reload = Timer.periodic(refresh, (_) => unawaited(_fetch()));
    return _fetch();
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
