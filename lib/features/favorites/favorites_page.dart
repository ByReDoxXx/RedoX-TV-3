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
import '../../core/ui/icon_action_button.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/scroll_hint_row.dart';
import '../radio/radio_player_page.dart';
import '../radio/widgets/station_avatar.dart';

/// Favori sırası (eski uygulamadaki "Sırala" çipleri; "Sıram" elle dizilen).
enum FavoriteSort {
  custom('Sıram'),
  name('A-Z'),
  number('Kanal no'),
  category('Kategori');

  const FavoriteSort(this.label);

  final String label;
}

/// Favoriler (eski uygulamadaki sıralanabilir listenin uyarlaması): TV
/// kanalları ve radyo istasyonları ayrı sekmede; satırda sıra, karo, ad, şu
/// anki program (TV) ya da tür (radyo); sağda yukarı/aşağı (yalnız "Sıram"da)
/// ve kaldır. OK/dokunma kanalı tam ekran açar ya da istasyonu çalar.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.channels,
    required this.clock,
    required this.profileName,
    this.radio,
    this.onWatch,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final Favorites favorites;

  /// TV kanalları (yayın akışıyla; şu anki program buradan).
  final List<LiveChannel> channels;
  final RadioController? radio;
  final ValueChanged<LiveChannel>? onWatch;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  static const ringRoom = 12.0;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _radio = false;
  FavoriteSort _sort = FavoriteSort.custom;

  Favorites get _fav => widget.favorites;

  List<LiveChannel> _items() {
    final source = _radio ? widget.radio?.stations ?? const <LiveChannel>[] : widget.channels;
    final byNumber = {for (final c in source) c.number: c};
    final list = [for (final n in _radio ? _fav.radios : _fav.channels) ?byNumber[n]];
    switch (_sort) {
      case FavoriteSort.custom:
        break;
      case FavoriteSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case FavoriteSort.number:
        list.sort((a, b) => a.number.compareTo(b.number));
      case FavoriteSort.category:
        list.sort((a, b) => a.category.compareTo(b.category));
    }
    return list;
  }

  void _move(LiveChannel c, int to) => _radio ? _fav.moveRadio(c.number, to) : _fav.moveChannel(c.number, to);

  void _remove(LiveChannel c) => _radio ? _fav.toggleRadio(c.number) : _fav.toggleChannel(c.number);

  Future<void> _open(LiveChannel c, List<LiveChannel> list) async {
    if (!_radio) {
      widget.onWatch?.call(c);
      return;
    }
    final radio = widget.radio;
    if (radio == null) return;
    if (c != radio.current) unawaited(radio.play(c));
    await Navigator.of(context)
        .push(RadioPlayerPage.route(radio: radio, stations: list, favorites: _fav, clock: widget.clock));
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final padding = PageLayout.scrollPadding(context, metrics);
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _fav,
      builder: (context, _) {
        final items = _items();
        return Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: phone ? 0 : padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: AppHeader(
                  clock: widget.clock,
                  profileName: widget.profileName,
                  onHome: widget.onHome,
                  onMore: widget.onMore,
                  onProfile: widget.onProfile,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: padding.left - FavoritesPage.ringRoom),
                child: ScrollHintRow(
                  padding: const EdgeInsets.fromLTRB(FavoritesPage.ringRoom, 16, 12, 6),
                  child: Row(
                    children: [
                      CategoryChip(
                        label: 'TV kanalları',
                        count: _fav.channels.length,
                        selected: !_radio,
                        onPressed: () => setState(() => _radio = false),
                      ),
                      if (widget.radio != null) ...[
                        const SizedBox(width: 12),
                        CategoryChip(
                          label: 'Radyo',
                          count: _fav.radios.length,
                          selected: _radio,
                          onPressed: () => setState(() => _radio = true),
                        ),
                      ],
                      const SizedBox(width: 24),
                      Text('Sırala:', style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                      for (final s in FavoriteSort.values) ...[
                        const SizedBox(width: 12),
                        CategoryChip(label: s.label, selected: s == _sort, onPressed: () => setState(() => _sort = s)),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(padding.left, 24, padding.right, 0),
                        child: Text(
                          _radio
                              ? 'Favori istasyon yok. Radyo listesinde ya da kadranda kalbe basarak ekleyin.'
                              : 'Favori kanal yok. Televizyon\'da önizleme panelindeki kalbe basarak ekleyin.',
                          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          padding.left - FavoritesPage.ringRoom,
                          6,
                          padding.right,
                          phone ? padding.bottom : 16,
                        ),
                        itemExtent: _FavoriteRow.height + 8,
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final c = items[i];
                          final custom = _sort == FavoriteSort.custom;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(FavoritesPage.ringRoom, 0, 0, 8),
                            child: _FavoriteRow(
                              channel: c,
                              position: i + 1,
                              radio: _radio,
                              compact: phone,
                              autofocus: i == 0,
                              onPressed: () => _open(c, items),
                              onUp: custom && i > 0 ? () => _move(c, i - 1) : null,
                              onDown: custom && i < items.length - 1 ? () => _move(c, i + 1) : null,
                              onRemove: () => _remove(c),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.channel,
    required this.position,
    required this.radio,
    required this.compact,
    required this.onPressed,
    required this.onRemove,
    this.onUp,
    this.onDown,
    this.autofocus = false,
  });

  static const height = 64.0;

  final LiveChannel channel;
  final int position;
  final bool radio;
  final bool compact;
  final bool autofocus;
  final VoidCallback onPressed;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final subtitle = radio ? c.category : (c.programTitle ?? c.category);
    return Container(
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: radius,
        border: Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FocusGlow(
              borderRadius: radius,
              scale: 1,
              builder: (context, active) => Material(
                color: active ? RedoxRoles.surfaceContainerHighest : Colors.transparent,
                borderRadius: radius,
                child: InkWell(
                  onTap: onPressed,
                  autofocus: autofocus,
                  borderRadius: radius,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        StationAvatar(station: c, size: 44, radius: RedoxRadius.sm),
                        const SizedBox(width: 14),
                        if (!compact) ...[
                          Text(
                            '$position',
                            style: t.labelLarge!.copyWith(
                              color: RedoxRoles.onSurfaceVariant,
                              fontFeatures: RedoxType.tabular,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium!.copyWith(
                                  color: RedoxRoles.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Telefonda yer yok: yalnız "kaldır"; sıra çiplerle seçilir.
          if (!compact) ...[
            _Action(icon: RedoxIcons.expandLess, label: 'Yukarı taşı', onPressed: onUp),
            const SizedBox(width: 6),
            _Action(icon: RedoxIcons.expandMore, label: 'Aşağı taşı', onPressed: onDown),
            const SizedBox(width: 6),
          ],
          _Action(icon: RedoxIcons.close, label: 'Favorilerden çıkar', onPressed: onRemove),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Satır sonundaki düğme; devre dışıysa soluk ve odak almaz.
class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onPressed});

  final RedoxIcons icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.3 : 1,
        child: ExcludeFocus(
          excluding: onPressed == null,
          child: IconActionButton(icon: icon, onPressed: onPressed),
        ),
      ),
    );
  }
}
