import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/remote/remote_host.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/watch_progress.dart';
import '../../core/content/content_locks.dart';
import '../../core/content/epg_program.dart';
import '../../core/content/favorites.dart';
import '../../core/content/reminders.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../../core/content/series_catalog.dart';
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
import '../locks/lock_scope.dart';
import '../home/home_page.dart';
import '../library/film_detail_page.dart';
import '../library/library_page.dart';
import '../library/series_detail_page.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../player/player_page.dart';
import '../../core/playback/radio_controller.dart';
import '../../core/playback/stream_probe.dart';
import '../tv/tv_content.dart';
import '../tv/tv_guide_controller.dart';
import '../favorites/favorites_page.dart';
import 'reminder_prompt.dart';
import '../radio/radio_page.dart';
import '../remote/remote_page.dart';
import '../radio/radio_player_page.dart';
import '../search/library_search.dart';
import '../search/search_page.dart';
import '../../core/navigation/search_scope.dart';
import '../settings/settings_page.dart';
import '../sources/sources_page.dart';
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
    this.locks,
    this.sources,
    this.profile,
    this.profiles,
    this.onSwitchProfile,
    this.homeRequests,
    this.remote,
    this.guide,
    this.openLastChannel = false,
    this.progress,
  });

  /// TV: telefon kumandası sunucusu (Ayarlar › Telefon kumandası).
  final RemoteHost? remote;

  /// Kanal listesi ve yayın akışı denetleyicisi (Ayarlar › Hakkında).
  final TvGuideController? guide;

  /// Film/dizide kaldığı yer (oynatıcı ve Anasayfa "İzlemeye devam et").
  final WatchProgress? progress;

  /// Açılışta son izlenen kanal oynatılır (Ayarlar › Açılış).
  final bool openLastChannel;

  /// TV: telefon kumandasının Ana sayfa tuşu (açık sayfalar kapanır,
  /// Anasayfa'ya dönülür).
  final Listenable? homeRequests;

  /// İzleyen profil; null ise varsayılan ad ("Profil 1"), çocuk kipi kapalı.
  /// Çocuk profilinde yalnız Çocuk kategorisi görünür, rayda Anasayfa ve
  /// Televizyon kalır, Ayarlar yoktur.
  final Profile? profile;

  /// Profil deposu: Ayarlar › Ebeveyn PIN'i; null ise sekme yok.
  final ProfileStore? profiles;

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

  /// Kilitli kanallar ve klasörler; null ise oturumluk boş küme (testler).
  final ContentLocks? locks;

  /// Kullanıcının M3U listeleri; null ise Kaynaklar "yakında" sayfasıdır.
  final UserSources? sources;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late AppSection _section = widget.initial;

  /// Televizyon sayfası açılınca gösterilecek görünüm (Anasayfa'dan "Yayın
  /// akışı" ile gelinince EPG).
  TvView _tvView = TvView.cards;

  void _go(AppSection section, {TvView tvView = TvView.cards}) {
    // Ayarlar'dan çıkınca "Kaynak ekle" açılışı unutulur (menüden gelince bölüm listesi).
    if (section != AppSection.settings) _settingsSection = null;
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
    widget.homeRequests?.addListener(_remoteHome);
    _reminderTimer = Timer.periodic(const Duration(seconds: 20), (_) => unawaited(_checkReminders()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFrames();
      if (widget.openLastChannel) _openLast();
    });
  }

  @override
  void dispose() {
    widget.history?.removeListener(_syncFrames);
    widget.homeRequests?.removeListener(_remoteHome);
    _reminderTimer?.cancel();
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

  /// Kilitler (LockScope ile sayfalara).
  late final ContentLocks _locks = widget.locks ?? ContentLocks();

  /// Bölünmüş Ekran karoları (oturum boyunca).
  late final _split = SplitScreen();

  /// Televizyon önizlemesindeki "Bölünmüş ekrana ekle".
  void _addToSplit(BuildContext context, LiveChannel c) {
    final i = _split.add(c);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(i < 0 ? 'Bölünmüş Ekran dolu: bir karoyu boşaltın.' : "${c.name} Bölünmüş Ekran'a eklendi."),
      ),
    );
  }

  /// Ayarlar'da açılacak bölüm ("Kaynak ekle" düğmelerinden gelince).
  SettingsSection? _settingsSection;

  void _openAddSource() {
    setState(() => _settingsSection = SettingsSection.addSource);
    _go(AppSection.settings);
  }

  /// Ayarlar › Açılış › Son izlenen kanal.
  void _openLast() {
    final last = widget.history?.value.firstOrNull;
    final channel = _tv.channels.where((c) => c.number == last).firstOrNull;
    // Kilitli kanal açılışta kendiliğinden açılmaz (PIN sorusu kabuğun
    // altındaki kapsamda; burada yok).
    if (channel == null || _locks.blocks(ContentLocks.channel(channel.number)) || !mounted) return;
    unawaited(_watch(context, channel));
  }

  /// Program hatırlatıcıları: vakti geleni sorar (oynatıcının üstünde de);
  /// "İzle" açık oynatıcıyı kapatıp kanalı açar.
  Timer? _reminderTimer;
  bool _prompting = false;

  Future<void> _checkReminders() async {
    if (_prompting || !mounted) return;
    for (final r in Reminders.instance.takeDue(DateTime.now())) {
      final channel = _tv.channels.where((c) => c.number == r.channel).firstOrNull;
      if (channel == null || !mounted) continue;
      _prompting = true;
      final watch = await showReminderPrompt(context, r);
      _prompting = false;
      if (!watch || !mounted) continue;
      final shell = ModalRoute.of(context);
      Navigator.of(context).popUntil((route) => route == shell || route.isFirst);
      unawaited(_watch(context, channel));
      return;
    }
  }

  void _remoteHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    _go(AppSection.home);
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
      onSelected: (i) => switch (i < sections.length ? sections[i] : null) {
        // Telefon kumandası tam ekran açılır (bölüm değil).
        AppSection.remote => unawaited(Navigator.of(context).push(RemotePage.route())),
        final AppSection s => _go(s),
        null => widget.onSwitchProfile?.call(),
      },
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

  /// Anasayfadaki devam kartı: film kaldığı yerden açılır. Dizide bölümün
  /// sezonu açılır (oynatıcıda "Sonraki bölüm" çalışsın); bitmiş bölümde
  /// sıradaki bölümden (sezon bittiyse sonraki sezonun ilkinden) başlar.
  Future<void> _resume(BuildContext context, ProgressEntry e) async {
    final ep = e.episode;
    if (ep == null) return _watch(context, e.channel, from: [e.channel], mode: PlayerMode.film);
    final sources = widget.sources;
    final loaded = <(String, List<LiveChannel>)>[];
    for (final s in sources?.of(SourceKind.series) ?? const <UserSource>[]) {
      try {
        loaded.add((s.id, await sources!.channels(s)));
      } on Object {
        // Okunamayan liste atlanır.
      }
    }
    if (!context.mounted) return;
    final key = ep.series.toLowerCase();
    final series = SeriesCatalog.build(loaded).where((s) => s.name.toLowerCase() == key).firstOrNull;
    List<LiveChannel> season(int n) => [for (final x in series?.episodes(n) ?? const <Episode>[]) x.channel];
    var list = season(ep.season);
    var i = list.indexWhere((c) => c.streams.contains(e.url));
    if (i < 0) {
      // Bölüm artık listede yok (liste değişti): kaydedilen adresle açılır.
      list = [e.channel];
      i = 0;
    } else if (e.finished) {
      if (i + 1 < list.length) {
        i++;
      } else if (series!.seasons.where((n) => n > ep.season).firstOrNull case final n?) {
        list = season(n);
        i = 0;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${series.name}: son bölümü izledin.')));
        return;
      }
    }
    return _watch(context, list[i], from: list, mode: PlayerMode.series);
  }

  /// Kanalı tam ekran açar; görüntü gelince geçmişe yazılır. Oynatıcıda ▲▼
  /// bütün kanallarda gezer (kategori süzgecinden bağımsız).
  /// [from]: kanalın listesi (Kaynaklar'daki klasör); null ise TV kanalları.
  /// Klasör kanalları izleme geçmişine yazılmaz (numaraları ana listeyle
  /// çakışır).
  Future<void> _watch(
    BuildContext context,
    LiveChannel c, {
    List<LiveChannel>? from,
    PlayerMode mode = PlayerMode.live,
  }) async {
    // Kilitli kanal PIN ister; oynatıcıda ▲▼ açılmamış kilitli kanallara
    // girmez (listeden çıkar).
    String lockOf(LiveChannel x) =>
        from == null ? ContentLocks.channel(x.number) : ContentLocks.item(x.streams.firstOrNull ?? x.name);
    final gate = LockScope.maybeOf(context);
    if (gate != null && !await gate.pass(context, lockOf(c))) return;
    if (!context.mounted) return;
    final list = [
      for (final x in from ?? _tv.channels)
        if (x == c || !_locks.blocks(lockOf(x))) x,
    ];
    _watching = true;
    // TV kanalı başlayınca radyo susar.
    unawaited(widget.radio?.stop());
    _syncFrames();
    try {
      await Navigator.of(context).push(
        PlayerPage.route(
          channels: list,
          initialIndex: list.indexOf(c),
          clock: _clock,
          engineFactory: widget.engineFactory,
          rank: widget.rank,
          onWatched: from == null ? (watched) => widget.history?.record(watched.number) : null,
          // Klasör kanalları: STB portalının bağlantıları oynatma anında çözülür.
          resolve: from == null ? null : widget.sources?.resolve,
          mode: mode,
          progress: mode == PlayerMode.live ? null : widget.progress,
          tmdb: mode == PlayerMode.live ? null : Tmdb.shared,
        ),
      );
    } finally {
      _watching = false;
      _syncFrames();
    }
  }

  /// Aramanın Film/Dizi verisi; Film ya da Dizi kaynakları değişmedikçe
  /// yeniden yüklenmez (büyük listede sadeleştirme saniyeler sürer).
  Future<LibrarySearch>? _librarySearch;
  String? _librarySearchKey;

  Future<LibrarySearch>? _library() {
    final sources = widget.sources;
    if (sources == null || _kids) return null;
    final key = [
      for (final s in sources.items)
        if (s.kind != SourceKind.live) '${s.id}:${s.updated.millisecondsSinceEpoch}',
    ].join(',');
    if (key.isEmpty) return null;
    if (key != _librarySearchKey) {
      _librarySearchKey = key;
      final load = _librarySearch = LibrarySearch.load(sources);
      // Okunamazsa sonraki aramada yeniden denenir.
      load.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_librarySearch, load)) _librarySearchKey = null;
        },
      );
    }
    return _librarySearch;
  }

  /// Aramadan film: TMDB varsa ayrıntı sayfası (Film bölümündeki gibi), yoksa
  /// doğrudan oynar.
  void _openFilm(BuildContext context, LiveChannel film, List<LiveChannel> films) {
    void watch(LiveChannel f) => unawaited(_watch(context, f, from: [f], mode: PlayerMode.film));
    final tmdb = Tmdb.shared;
    if (tmdb == null) return watch(film);
    Route<void> detail(LiveChannel f) => FilmDetailPage.route(
      film: f,
      tmdb: tmdb,
      onWatch: () => watch(f),
      library: films,
      onSimilar: (c) => unawaited(Navigator.of(context).pushReplacement(detail(c))),
    );
    unawaited(Navigator.of(context).push(detail(film)));
  }

  /// Başlıktaki aramanın sayfası: kanallar ve (çocuk profili dışında)
  /// radyolar, filmler ve diziler.
  void _search(BuildContext context, String query) {
    final radio = _kids ? null : widget.radio;
    unawaited(
      Navigator.of(context).push(
        SearchPage.route(
          channels: _tv.channels,
          radios: radio?.stations ?? const [],
          query: query,
          onChannel: (c) => _watch(context, c),
          library: _library(),
          onFilm: (f, films) => _openFilm(context, f, films),
          onSeries: (s) => unawaited(
            SeriesDetailPage.open(
              context,
              s,
              tmdb: Tmdb.shared,
              favorites: widget.favorites,
              onWatch: (list, i) => _watch(context, list[i], from: list, mode: PlayerMode.series),
            ),
          ),
          onRadio: radio == null
              ? null
              : (s) {
                  if (s != radio.current) unawaited(radio.play(s));
                  unawaited(
                    Navigator.of(
                      context,
                    ).push(RadioPlayerPage.route(radio: radio, stations: radio.stations, favorites: widget.favorites)),
                  );
                },
        ),
      ),
    );
  }

  Widget _page(BuildContext context) => switch (_section) {
    AppSection.home => ListenableBuilder(
      // Geçmiş ya da izleme ilerlemesi değişince raflar yenilenir.
      listenable: Listenable.merge([widget.history, widget.progress]),
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
        resume: _kids ? const [] : widget.progress?.recent ?? const [],
        onResume: (e) => _resume(context, e),
        tmdb: Tmdb.shared,
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
    AppSection.sources when widget.sources != null && !_kids => SourcesPage(
      sources: widget.sources!,
      favorites: widget.favorites,
      clock: _clock,
      profileName: _home.profileName,
      onWatch: (list, i) => _watch(context, list[i], from: list),
      onAdd: _openAddSource,
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      onProfile: widget.onSwitchProfile,
    ),
    AppSection.film || AppSection.series when widget.sources != null && !_kids => LibraryPage(
      kind: _section == AppSection.film ? SourceKind.film : SourceKind.series,
      sources: widget.sources!,
      favorites: widget.favorites,
      tmdb: Tmdb.shared,
      clock: _clock,
      profileName: _home.profileName,
      onWatch: (list, i) =>
          _watch(context, list[i], from: list, mode: _section == AppSection.film ? PlayerMode.film : PlayerMode.series),
      onAdd: _openAddSource,
      onHome: () => _go(AppSection.home),
      onMore: () => _showMore(context),
      onProfile: widget.onSwitchProfile,
    ),
    AppSection.settings when widget.sources != null && !_kids => SettingsPage(
      // "Kaynak ekle" düğmelerinden gelince o bölüm açık; her açılışta bir kez.
      key: ValueKey(_settingsSection),
      initialSection: _settingsSection,
      sources: widget.sources!,
      profiles: widget.profiles,
      history: widget.history,
      songs: widget.radio?.songs,
      tmdb: Tmdb.shared,
      remote: widget.remote,
      guide: widget.guide,
      channelName: (n) => _tv.channels.where((c) => c.number == n).firstOrNull?.name,
      clock: _clock,
      profileName: _home.profileName,
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
      sources: widget.sources,
      onWatchList: (list, i) => _watch(context, list[i], from: list),
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
      child: LockScope(
        locks: _locks,
        profiles: widget.profiles,
        child: SearchScope(
          open: _search,
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
        ),
      ),
    );
  }
}
