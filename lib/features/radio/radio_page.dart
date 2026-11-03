import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/playback/radio_controller.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/theme/redox_type.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/scroll_hint_row.dart';
import '../../core/ui/status_badge.dart';
import 'radio_player_page.dart';
import 'widgets/recent_songs.dart';
import 'widgets/sound_wave.dart';
import 'widgets/station_avatar.dart';

/// Radyo listesi (eski uygulamadaki "liste + büyük panel" tasarımının
/// uyarlaması): üstte sayılı tür çipleri ("Tümü", "Favoriler", türler), altta
/// numaralı istasyon listesi. TV/tablette sağda "Şimdi çalıyor" ve odaktaki
/// "Seçili istasyon" kartları; telefonda altta mini çubuk.
///
/// OK/dokunma istasyonu çalar ve tam ekran kadranı açar ([RadioPlayerPage]);
/// Geri listeye döner, ses sürer.
class RadioPage extends StatefulWidget {
  const RadioPage({
    super.key,
    required this.radio,
    required this.clock,
    required this.profileName,
    this.favorites,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final RadioController radio;
  final Favorites? favorites;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  /// Çip sırası; listede olmayan türler sonda.
  static const genreOrder = [
    'Pop',
    'Türkü & Halk',
    'Arabesk & Fantezi',
    'Nostalji',
    'Rock & Alternatif',
    'Dans & Elektronik',
    'Klasik & Sanat',
    'Haber & Spor',
    'Dini',
    'Karışık',
    'Yerel',
  ];

  /// "Favoriler" çipinin süzgeç adı.
  static const favoritesFilter = 'Favoriler';

  /// "Son şarkılar" çipi: istasyon yerine son dinlenen şarkılar (kullanıcı
  /// isteği: son 15).
  static const songsFilter = 'Son şarkılar';

  /// Odak halkası payı (TvPage ile aynı).
  static const ringRoom = 12.0;

  /// Sağ panel genişliği (TV/tablet).
  static const panelWidth = 320.0;

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  String? _filter;
  LiveChannel? _selected;

  RadioController get _radio => widget.radio;

  List<String> _genres(List<LiveChannel> all) {
    final seen = {for (final s in all) s.category};
    return [
      for (final g in RadioPage.genreOrder)
        if (seen.contains(g)) g,
      for (final g in seen)
        if (!RadioPage.genreOrder.contains(g)) g,
    ];
  }

  List<LiveChannel> _filtered(List<LiveChannel> all) => switch (_filter) {
    null => all,
    RadioPage.songsFilter => const [],
    RadioPage.favoritesFilter => [
      for (final n in widget.favorites?.radios ?? const <int>[]) ?all.where((s) => s.number == n).firstOrNull,
    ],
    final g => [
      for (final s in all)
        if (s.category == g) s,
    ],
  };

  Future<void> _open(LiveChannel s, List<LiveChannel> list) async {
    if (s != _radio.current || _radio.status == RadioStatus.failed) unawaited(_radio.play(s));
    await Navigator.of(context).push(
      RadioPlayerPage.route(
        radio: _radio,
        stations: list.isEmpty ? _radio.stations : list,
        favorites: widget.favorites,
        clock: widget.clock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final padding = PageLayout.scrollPadding(context, metrics);
    return ListenableBuilder(
      listenable: Listenable.merge([_radio, _radio.stationsListenable, ?widget.favorites, ?_radio.songs]),
      builder: (context, _) {
        final all = _radio.stations;
        final list = _filtered(all);
        final header = AppHeader(
          clock: widget.clock,
          profileName: widget.profileName,
          onHome: widget.onHome,
          onMore: widget.onMore,
          onProfile: widget.onProfile,
        );
        final listColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chips(all),
            const SizedBox(height: 4),
            Expanded(child: _filter == RadioPage.songsFilter ? _songs(all) : _list(list, phone)),
          ],
        );
        return Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: phone ? 0 : padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: header,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: padding.left - RadioPage.ringRoom, right: padding.right),
                  child: phone
                      ? listColumn
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: listColumn),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: RadioPage.panelWidth,
                              child: Padding(padding: const EdgeInsets.only(top: 16), child: _panel(context, list)),
                            ),
                          ],
                        ),
                ),
              ),
              if (phone && _radio.current != null) _MiniBar(radio: _radio, onOpen: () => _open(_radio.current!, list)),
            ],
          ),
        );
      },
    );
  }

  Widget _chips(List<LiveChannel> all) {
    final favCount = widget.favorites?.radios.length ?? 0;
    final chips = <(String?, String, int)>[
      (null, 'Tümü', all.length),
      if (widget.favorites != null) (RadioPage.favoritesFilter, RadioPage.favoritesFilter, favCount),
      if (_radio.songs case final songs?) (RadioPage.songsFilter, RadioPage.songsFilter, songs.value.length),
      for (final g in _genres(all)) (g, g, all.where((s) => s.category == g).length),
    ];
    return ScrollHintRow(
      padding: const EdgeInsets.fromLTRB(RadioPage.ringRoom, 16, 12, 6),
      child: Row(
        children: [
          for (final (i, (filter, label, count)) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            CategoryChip(
              label: label,
              count: count,
              selected: filter == _filter,
              onPressed: () => setState(() => _filter = filter),
            ),
          ],
        ],
      ),
    );
  }

  /// Son dinlenen şarkılar; OK/dokunma o istasyonu açar.
  Widget _songs(List<LiveChannel> all) => RecentSongList(
    songs: _radio.songs?.value ?? const [],
    stations: all,
    onOpen: (s) => _open(s, all),
    padding: const EdgeInsets.fromLTRB(RadioPage.ringRoom, 6, RadioPage.ringRoom, 16),
  );

  Widget _list(List<LiveChannel> list, bool phone) {
    final t = Theme.of(context).textTheme;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(RadioPage.ringRoom),
        child: Text(
          _filter == RadioPage.favoritesFilter
              ? 'Favori istasyon yok. Bir istasyonda yıldıza basarak ekleyin.'
              : 'Bu türde istasyon yok.',
          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(RadioPage.ringRoom, 6, RadioPage.ringRoom, 16),
      itemExtent: _StationRow.height + 6,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _StationRow(
            station: s,
            position: i + 1,
            current: s == _radio.current,
            playing: s == _radio.current && _radio.status == RadioStatus.playing,
            favorite: widget.favorites?.hasRadio(s.number) ?? false,
            autofocus: i == 0,
            onFocus: () => setState(() => _selected = s),
            onPressed: () => _open(s, list),
          ),
        );
      },
    );
  }

  Widget _panel(BuildContext context, List<LiveChannel> list) {
    final selected = _selected ?? list.firstOrNull;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NowPlayingCard(radio: _radio, onOpen: _radio.current == null ? null : () => _open(_radio.current!, list)),
          if (selected != null) ...[
            const SizedBox(height: 16),
            _SelectedCard(
              station: selected,
              favorite: widget.favorites?.hasRadio(selected.number) ?? false,
              onPlay: () => _open(selected, list),
              onFavorite: widget.favorites == null ? null : () => widget.favorites!.toggleRadio(selected.number),
            ),
          ],
        ],
      ),
    );
  }
}

/// Numaralı istasyon satırı: sıra, karo, ad, "tür · N yayın", çalıyorsa ses
/// çubukları, favoriyse yıldız. Satırın tamamı odak alır.
class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.position,
    required this.current,
    required this.playing,
    required this.favorite,
    required this.onPressed,
    this.onFocus,
    this.autofocus = false,
  });

  static const height = 60.0;

  final LiveChannel station;
  final int position;
  final bool current;
  final bool playing;
  final bool favorite;
  final VoidCallback onPressed;
  final VoidCallback? onFocus;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = station;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final streams = s.streams.length;
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active
            ? RedoxRoles.surfaceContainerHighest
            : current
            ? RedoxRoles.surfaceContainer
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          onFocusChange: (v) {
            if (v) onFocus?.call();
          },
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '$position',
                    textAlign: TextAlign.right,
                    style: t.labelLarge!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
                  ),
                ),
                const SizedBox(width: 14),
                StationAvatar(station: s, size: 40, radius: RedoxRadius.sm),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(
                          color: current ? RedoxSeeds.amber : RedoxRoles.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [s.category, if (streams > 1) '$streams yayın'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (current) SizedBox(width: 28, child: SoundWave(active: playing, bars: 4, height: 20)),
                if (favorite) ...[
                  const SizedBox(width: 12),
                  const RedoxIcon(RedoxIcons.favorites, filled: true, color: RedoxSeeds.crimson, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.highlight = false});

  final String title;
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        color: RedoxRoles.surfaceContainer,
        gradient: highlight
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A1626), RedoxRoles.surfaceContainer],
              )
            : null,
        border: Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.radio, this.onOpen});

  final RadioController radio;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = radio.current;
    if (s == null) {
      return _Card(
        title: 'ŞİMDİ ÇALIYOR',
        highlight: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Henüz bir istasyon çalmıyor', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
            const SizedBox(height: 4),
            Text(
              Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv
                  ? 'Listeden bir istasyon seçip OK\'a basın.'
                  : 'Listeden bir istasyona dokunun.',
              style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    final playing = radio.status == RadioStatus.playing || radio.status == RadioStatus.connecting;
    return _Card(
      title: 'ŞİMDİ ÇALIYOR',
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StationAvatar(station: s, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      radio.title ?? s.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(
                        color: radio.title == null ? RedoxRoles.onSurfaceVariant : RedoxSeeds.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SoundWave(active: radio.status == RadioStatus.playing, bars: 28, height: 18),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassButton(
                label: playing ? 'Duraklat' : 'Çal',
                icon: playing ? RedoxIcons.pause : RedoxIcons.play,
                onPressed: radio.toggle,
              ),
              GlassButton(label: 'Kadran', icon: RedoxIcons.fullscreen, onPressed: onOpen),
            ],
          ),
          if (radio.status == RadioStatus.failed) ...[
            const SizedBox(height: 8),
            const StatusBadge(label: 'YAYIN AÇILMADI', tone: BadgeTone.neutral),
          ],
        ],
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.station, required this.favorite, required this.onPlay, this.onFavorite});

  final LiveChannel station;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = station;
    return _Card(
      title: 'SEÇİLİ İSTASYON',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StationAvatar(station: s, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${s.category} · ${s.streams.length} yayın',
                      style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Kartlar odak almaz: satırdan sağa geçiş yok, OK satırda çalar.
          // Dokunmatik ve fare için düğmeler.
          ExcludeFocus(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PrimaryButton(label: 'Çal', icon: RedoxIcons.play, onPressed: onPlay),
                if (onFavorite != null)
                  GlassButton(
                    label: favorite ? 'Favoride' : 'Favori',
                    icon: RedoxIcons.favorites,
                    onPressed: onFavorite,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Telefonda altta: çalan istasyon, şarkı, oynat/duraklat; dokununca kadran.
class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.radio, required this.onOpen});

  final RadioController radio;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = radio.current!;
    final playing = radio.status == RadioStatus.playing || radio.status == RadioStatus.connecting;
    return Material(
      color: RedoxRoles.surfaceContainerHigh,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              StationAvatar(station: s, size: 40, radius: RedoxRadius.sm),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      radio.title ?? s.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(
                        color: radio.title == null ? RedoxRoles.onSurfaceVariant : RedoxSeeds.gold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: radio.toggle,
                tooltip: playing ? 'Duraklat' : 'Çal',
                icon: RedoxIcon(
                  playing ? RedoxIcons.pause : RedoxIcons.play,
                  filled: true,
                  color: RedoxRoles.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
