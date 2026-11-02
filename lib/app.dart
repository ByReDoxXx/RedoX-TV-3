import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'core/content/content_locks.dart';
import 'core/content/profiles.dart';
import 'core/content/favorites.dart';
import 'core/content/user_sources.dart';
import 'core/content/watch_history.dart';
import 'core/playback/frame_grabber.dart';
import 'core/playback/radio_controller.dart';
import 'core/playback/stream_probe.dart';
import 'features/home/home_content.dart';
import 'features/profiles/profile_picker_page.dart';
import 'features/shell/root_shell.dart';
import 'features/tv/tv_content.dart';

/// Açılış: "Kim izliyor?" (her açılışta). Profil seçilince kök kabuk o
/// profille kurulur; başlıktaki profil hapı seçim ekranına döner.
class RedoxApp extends StatefulWidget {
  const RedoxApp({
    super.key,
    required this.tv,
    this.profiles,
    this.history,
    this.favorites,
    this.locks,
    this.sources,
    this.radio,
    this.frames,
    this.rank,
  });

  /// Televizyon kanalları (gömülü M3U listesinden) ve yayın akışı; her
  /// dakika yenilenir (TvGuideController, main.dart).
  final ValueListenable<TvContent> tv;

  /// Profiller; null ise seçim ekranı yok, varsayılan profil (testler).
  final ProfileStore? profiles;

  /// Profilin izleme geçmişi (Anasayfa "Son izlenen kanallar").
  final WatchHistory Function(String profileId)? history;

  /// Profilin favorileri (kanal ve radyo).
  final Favorites Function(String profileId)? favorites;

  /// Kilitli kanallar ve klasörler (cihaz başına, bütün profillerde).
  final ContentLocks? locks;

  /// Kullanıcının M3U listeleri (Kaynaklar; cihaz başına, profillerden bağımsız).
  final UserSources? sources;

  /// Radyo (uygulama boyunca tek).
  final RadioController? radio;

  /// Kanalların yayından alınan kareleri (Anasayfa kartları).
  final FrameStore? frames;

  /// Akış sıralayıcı (StreamProbe.rank).
  final StreamRanker? rank;

  @override
  State<RedoxApp> createState() => _RedoxAppState();
}

class _RedoxAppState extends State<RedoxApp> {
  /// İzleyen profil; null iken seçim ekranı.
  Profile? _profile;

  /// Seçim ekranına profil hapından gelindiyse önceki profil (Geri ona döner).
  Profile? _previous;

  @override
  void initState() {
    super.initState();
    widget.tv.addListener(_prefetch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetch());
  }

  @override
  void dispose() {
    widget.tv.removeListener(_prefetch);
    super.dispose();
  }

  /// Seçim ekranı dururken Anasayfa kanallarının kareleri alınır (kullanıcı
  /// isteği: profil seçilene kadar yüklenmiş olsun). Önce son profilin rafı,
  /// sonra diğer profillerinki.
  void _prefetch() {
    final store = widget.profiles, frames = widget.frames;
    if (store == null || frames == null || _profile != null) return;
    final tv = widget.tv.value;
    final last = store.byId(store.lastId);
    final order = [?last, ...store.profiles.where((p) => p != last)];
    final channels = {
      for (final p in order)
        ...HomeContent.from(
          channels: (p.kids ? tv.only(Profile.kidsCategory) : tv).channels,
          recent: widget.history?.call(p.id).value ?? const [],
          clock: RootShell.previewClock,
          kids: p.kids,
        ).channels,
    };
    frames.request(channels.toList());
  }

  void _select(Profile p) => setState(() {
    _profile = p;
    _previous = null;
  });

  void _switchProfile() {
    widget.frames?.pause();
    setState(() {
      _previous = _profile;
      _profile = null;
    });
    _prefetch();
  }

  Widget _home(BuildContext context) {
    final store = widget.profiles;
    final profile = _profile;
    if (store != null && profile == null) {
      return PopScope(
        canPop: _previous == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _previous != null) _select(_previous!);
        },
        child: ProfilePickerPage(store: store, onSelected: _select),
      );
    }
    return ValueListenableBuilder(
      valueListenable: widget.tv,
      builder: (context, tv, _) => RootShell(
        // Profil değişince kabuk baştan kurulur (bölüm, geçmiş dinleyicisi).
        key: ValueKey(profile?.id),
        tv: tv,
        profile: profile,
        history: widget.history?.call(profile?.id ?? ProfileStore.defaults.first.id),
        favorites: widget.favorites?.call(profile?.id ?? ProfileStore.defaults.first.id),
        radio: widget.radio,
        locks: widget.locks,
        sources: widget.sources,
        frames: widget.frames,
        rank: widget.rank,
        profiles: store,
        onSwitchProfile: store == null ? null : _switchProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      // Katlanabilir telefon açılıp kapanınca düzen değişir (FormFactor.forWindow).
      // Geçiş animasyonsuz: ara karede tablet düzeni telefon genişliğinde
      // çizilip taşıyordu (renkler değişmez, yalnız ölçüler).
      themeAnimationDuration: Duration.zero,
      theme: RedoxTheme.dark(formFactor: FormFactor.forWindow(FormFactor.current, MediaQuery.sizeOf(context))),
      themeMode: ThemeMode.dark,
      home: Builder(builder: _home),
    );
  }
}
