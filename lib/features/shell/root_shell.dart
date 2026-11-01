import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/epg_program.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/profiles.dart';
import '../../core/content/watch_history.dart';
import '../../core/playback/frame_grabber.dart';
import '../../core/layout/form_factor.dart';
import '../../core/navigation/destinations.dart';
import '../../core/navigation/double_back_to_exit.dart';
import '../../core/navigation/more_sheet.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/bottom_nav_bar.dart';
import '../../core/ui/nav_rail.dart';
import '../../core/ui/redox_icon.dart';
import '../home/home_content.dart';
import '../home/home_page.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../player/player_page.dart';
import '../../core/playback/radio_controller.dart';
import '../../core/playback/stream_probe.dart';
import '../tv/tv_content.dart';
import '../favorites/favorites_page.dart';
import '../radio/radio_page.dart';
import '../split_screen/split_screen.dart';
import '../split_screen/split_screen_page.dart';
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
    this.frames,
    this.initial = AppSection.home,
    this.previewFocus = false,
    this.engineFactory,
    this.rank,
    this.radio,
    this.favorites,
    this.profile,
    this.onSwitchProfile,
  });

  /// İzleyen profil; null ise varsayılan ad ("Profil 1"), çocuk kipi kapalı.
  /// Çocuk profilinde yalnız Çocuk kategorisi görünür, rayda Anasayfa ve
  /// Televizyon kalır, Ayarlar yoktur.
  final Profile? profile;

  /// Başlıktaki profil hapı: "Kim izliyor?" ekranına döner.
  final VoidCallback? onSwitchProfile;

  /// Anasayfa içeriği; null ise kanal listesinden ve izleme geçmişinden
  /// türetilir (HomeContent.from).
  final HomeContent? home;
  final TvContent tv;

  /// İzleme geçmişi (Anasayfa "Son izlenen kanallar"); null ise geçmiş yok.
  final WatchHistory? history;

  /// Kanalların yayından alınan kareleri (Anasayfa kartları); null ise logo.
  final FrameStore? frames;

  /// Yayın akışı olmadığında (tasarım önizlemesi) başlıkta gösterilen saat.
  static const previewClock = '20:45';
  final AppSection initial;

  /// Önizleme görüntüleri: Anasayfa vitrin düğmesini odakta çiz.
  final bool previewFocus;

  /// Oynatma motoru; null ise media_kit (testlerde sahte motor).
  final PlaybackEngine Function()? engineFactory;

  /// Akış sıralayıcı (StreamProbe.rank); null ise listedeki sıra (testler).
  final StreamRanker? rank;

  /// Radyo; null ise Radyo bölümü "yakında" sayfasıdır (testler).
  final RadioController? radio;

  /// Profilin favorileri (kanal ve radyo).
  final Favorites? favorites;

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
      _syncFrames();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.history?.addListener(_syncFrames);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFrames());
  }

  @override
  void dispose() {
    widget.history?.removeListener(_syncFrames);
    _split.dispose();
    super.dispose();
  }

  /// Kareler yalnız Anasayfa görünürken alınır (vitrin önce); başka bölümde
  /// ve kanal izlenirken durur.
  void _syncFrames() {
    final frames = widget.frames;
    if (frames == null || !mounted) return;
    if (_section == AppSection.home && !_watching) {
      frames.request(_home.channels);
    } else {
      frames.pause();
    }
  }

  bool _watching = false;

  /// Bölünmüş Ekran karoları (oturum boyunca).
  final _split = SplitScreen();

  /// Televizyon önizlemesindeki "2x2 Ekrana ekle".
  void _addToSplit(BuildContext context, LiveChannel c) {
    final i = _split.add(c);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(i < 0 ? 'Bölünmüş Ekran dolu: bir karoyu boşaltın.' : "${c.name} Bölünmüş Ekran'a eklendi."),
      ),
    );
  }

  bool _onBack() {
    if (_section == AppSection.home) return false;
    _go(AppSection.home);
    return true;
  }

  bool get _kids => widget.profile?.kids ?? false;

  /// Görünen kanallar: çocuk profilinde yalnız Çocuk kategorisi (oynatıcıda
  /// ▲▼ de bunlarda gezer).
  late TvContent _tv = _visible();

  TvContent _visible() => _kids ? widget.tv.only(Profile.kidsCategory) : widget.tv;

  @override
  void didUpdateWidget(RootShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tv != widget.tv || oldWidget.profile != widget.profile) _tv = _visible();
  }

  List<AppSection> get _rail => _kids ? AppDestinations.kidsRailSections : AppDestinations.railSections;
  List<AppSection> get _footer => _kids ? const [] : AppDestinations.railFooterSections;
  List<AppSection> get _more => _kids ? AppDestinations.kidsPhoneMoreSections : AppDestinations.phoneMoreSections;

  /// Telefonda "Diğer": bölümler ve en altta "Profil değiştir".
  void _showMore(BuildContext context) {
    final sections = _more;
    showMoreSheet(
      context,
      items: [...AppDestinations.items(sections), if (widget.onSwitchProfile != null) _switchItem],
      onSelected: (i) => i < sections.length ? _go(sections[i]) : widget.onSwitchProfile?.call(),
    );
  }

  static const _switchItem = NavRailItem(RedoxIcons.profile, 'Profil değiştir');

  /// Başlık saati: yayın akışının "şimdi"si (gerçek saat); önizlemede örnek saat.
  String get _clock => switch (_tv.nowMinute) {
    final m? => EpgProgram.formatClock(m),
    null => RootShell.previewClock,
  };

  HomeContent get _home =>
      widget.home ??
      HomeContent.from(
        channels: _tv.channels,
        recent: widget.history?.value ?? const [],
        clock: _clock,
        nowMinute: _tv.nowMinute,
        profileName: widget.profile?.name ?? 'Profil 1',
        kids: _kids,
      );

  /// Kanalı tam ekran açar; görüntü gelince geçmişe yazılır. Oynatıcıda ▲▼
  /// bütün kanallarda gezer (kategori süzgecinden bağımsız).
  Future<void> _watch(BuildContext context, LiveChannel c) async {
    _watching = true;
    // TV kanalı başlayınca radyo susar.
    unawaited(widget.radio?.stop());
    _syncFrames();
    try {
      await Navigator.of(context).push(
        PlayerPage.route(
          channels: _tv.channels,
          initialIndex: _tv.channels.indexOf(c),
          clock: _clock,
          engineFactory: widget.engineFactory,
          rank: widget.rank,
          onWatched: (watched) => widget.history?.record(watched.number),
        ),
      );
    } finally {
      _watching = false;
      _syncFrames();
    }
  }

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
        frames: widget.frames,
        onMore: () => _showMore(context),
        onProfile: widget.onSwitchProfile,
        kids: _kids,
      ),
    ),
    AppSection.tv => TvPage(
      content: _tv,
      clock: _clock,
      profileName: _home.profileName,
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      onProfile: widget.onSwitchProfile,
      kids: _kids,
      engineFactory: widget.engineFactory,
      rank: widget.rank,
      initialView: _tvView,
      favorites: widget.favorites,
      onSplit: (c) => _addToSplit(context, c),
      onChannel: (c) => _watch(context, c),
    ),
    AppSection.radio when widget.radio != null => RadioPage(
      radio: widget.radio!,
      favorites: widget.favorites,
      clock: _clock,
      profileName: _home.profileName,
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      onProfile: widget.onSwitchProfile,
    ),
    AppSection.splitScreen when !_kids => SplitScreenPage(
      split: _split,
      channels: _tv.channels,
      clock: _clock,
      profileName: _home.profileName,
      engineFactory: widget.engineFactory,
      onWatch: (c) => _watch(context, c),
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      onProfile: widget.onSwitchProfile,
    ),
    AppSection.favorites when widget.favorites != null => FavoritesPage(
      favorites: widget.favorites!,
      channels: _tv.channels,
      radio: widget.radio,
      clock: _clock,
      profileName: _home.profileName,
      onWatch: (c) => _watch(context, c),
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      onProfile: widget.onSwitchProfile,
    ),
    _ => SectionPlaceholder(section: _section),
  };

  @override
  Widget build(BuildContext context) {
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    return DoubleBackToExit(
      onBack: _onBack,
      child: Scaffold(
        // Çocuk profilinde alt menü yok (bölümler "Diğer" sayfasında).
        bottomNavigationBar: phone && !_kids
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
                  items: _kids ? AppDestinations.items(_rail) : AppDestinations.main,
                  footer: _kids ? const [] : AppDestinations.footer,
                  selectedIndex: AppDestinations.railIndexOf(_section, main: _rail, footer: _footer),
                  onSelected: (i) => _go(AppDestinations.railSectionAt(i, main: _rail, footer: _footer)),
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
