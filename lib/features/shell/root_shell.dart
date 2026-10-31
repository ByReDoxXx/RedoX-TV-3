import 'package:flutter/material.dart';

import '../../core/content/epg_program.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/watch_history.dart';
import '../../core/layout/form_factor.dart';
import '../../core/navigation/destinations.dart';
import '../../core/navigation/double_back_to_exit.dart';
import '../../core/navigation/more_sheet.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/bottom_nav_bar.dart';
import '../../core/ui/nav_rail.dart';
import '../home/home_content.dart';
import '../home/home_page.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../player/player_page.dart';
import '../../core/playback/stream_probe.dart';
import '../tv/tv_content.dart';
import '../tv/tv_page.dart';
import 'section_placeholder.dart';

/// Uygulamanın kökü: bölümler arası geçiş. TV/tablet/masaüstünde sol ray,
/// telefonda alt menü (Anasayfa logodadır). Geri: başka bölümdeyken
/// Anasayfa'ya döner; Anasayfada ilk basışta uyarı, ikincide çıkış.
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.tv,
    this.home,
    this.history,
    this.initial = AppSection.home,
    this.previewFocus = false,
    this.engineFactory,
    this.rank,
  });

  /// Anasayfa içeriği; null ise kanal listesinden ve izleme geçmişinden
  /// türetilir (HomeContent.from).
  final HomeContent? home;
  final TvContent tv;

  /// İzleme geçmişi (Anasayfa "Son izlenen kanallar"); null ise geçmiş yok.
  final WatchHistory? history;

  /// Yayın akışı olmadığında (tasarım önizlemesi) başlıkta gösterilen saat.
  static const previewClock = '20:45';
  final AppSection initial;

  /// Önizleme görüntüleri: Anasayfa vitrin düğmesini odakta çiz.
  final bool previewFocus;

  /// Oynatma motoru; null ise media_kit (testlerde sahte motor).
  final PlaybackEngine Function()? engineFactory;

  /// Akış sıralayıcı (StreamProbe.rank); null ise listedeki sıra (testler).
  final StreamRanker? rank;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late AppSection _section = widget.initial;

  /// Televizyon sayfası açılınca gösterilecek görünüm (Anasayfa'dan "Yayın
  /// akışı" ile gelinince EPG).
  TvView _tvView = TvView.cards;

  void _go(AppSection section, {TvView tvView = TvView.cards}) {
    if (section != _section || tvView != _tvView) {
      setState(() {
        _section = section;
        _tvView = tvView;
      });
    }
  }

  bool _onBack() {
    if (_section == AppSection.home) return false;
    _go(AppSection.home);
    return true;
  }

  void _showMore(BuildContext context) => showMoreSheet(
    context,
    items: AppDestinations.phoneMore,
    onSelected: (i) => _go(AppDestinations.phoneMoreSections[i]),
  );

  /// Başlık saati: yayın akışının "şimdi"si (gerçek saat); önizlemede örnek saat.
  String get _clock => switch (widget.tv.nowMinute) {
    final m? => EpgProgram.formatClock(m),
    null => RootShell.previewClock,
  };

  HomeContent get _home =>
      widget.home ??
      HomeContent.from(
        channels: widget.tv.channels,
        recent: widget.history?.value ?? const [],
        clock: _clock,
        nowMinute: widget.tv.nowMinute,
      );

  /// Kanalı tam ekran açar; görüntü gelince geçmişe yazılır. Oynatıcıda ▲▼
  /// bütün kanallarda gezer (kategori süzgecinden bağımsız).
  Future<void> _watch(BuildContext context, LiveChannel c) => Navigator.of(context).push(
    PlayerPage.route(
      channels: widget.tv.channels,
      initialIndex: widget.tv.channels.indexOf(c),
      clock: _clock,
      engineFactory: widget.engineFactory,
      rank: widget.rank,
      onWatched: (watched) => widget.history?.record(watched.number),
    ),
  );

  Widget _page(BuildContext context) => switch (_section) {
    AppSection.home => ListenableBuilder(
      // Geçmiş değişince "Son izlenen kanallar" yenilenir.
      listenable: widget.history ?? const _NoHistory(),
      builder: (context, _) => HomePage(
        content: _home,
        previewFocus: widget.previewFocus,
        onNavigate: _go,
        onWatch: (c) => _watch(context, c),
        onGuide: () => _go(AppSection.tv, tvView: TvView.epg),
      ),
    ),
    AppSection.tv => TvPage(
      content: widget.tv,
      clock: _clock,
      profileName: _home.profileName,
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      engineFactory: widget.engineFactory,
      rank: widget.rank,
      initialView: _tvView,
      onChannel: (c) => _watch(context, c),
    ),
    _ => SectionPlaceholder(section: _section),
  };

  @override
  Widget build(BuildContext context) {
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    return DoubleBackToExit(
      onBack: _onBack,
      child: Scaffold(
        bottomNavigationBar: phone
            ? RedoxBottomBar(
                items: AppDestinations.phoneBar,
                // Anasayfa ve "Diğer" bölümleri çubukta yoktur: seçili öğe yok.
                selectedIndex: AppDestinations.phoneBarSections.indexOf(_section),
                onSelected: (i) => _go(AppDestinations.phoneBarSections[i]),
              )
            : null,
        // expand: Scaffold gövdeye gevşek kısıt verir; sayfa içeriğe
        // büzülürse ray ekranın altına kadar uzanmaz.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Bölüm değişince sayfa baştan kurulur (kaydırma ve seçimler sıfırlanır).
            KeyedSubtree(
              key: ValueKey((_section, _tvView)),
              child: Builder(builder: _page),
            ),
            if (!phone)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: RedoxNavRail(
                  items: AppDestinations.main,
                  footer: AppDestinations.footer,
                  selectedIndex: AppDestinations.railIndexOf(_section),
                  onSelected: (i) => _go(AppDestinations.railSectionAt(i)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Geçmiş verilmediğinde dinlenecek boş Listenable.
class _NoHistory implements Listenable {
  const _NoHistory();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
