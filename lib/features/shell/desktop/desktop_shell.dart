import 'package:flutter/material.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/layout/desktop_chrome.dart';
import '../../../core/navigation/destinations.dart';
import '../../../core/theme/m3e_motion.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/app_header.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/header_search.dart';
import '../../../core/ui/redox_icon.dart';

/// Windows/Linux kabuğu (Spotify masaüstü düzeni, RedoX M3 Expressive dili):
/// obsidyen zemin üstünde üç yüzey. Üstte gezinme ve arama çubuğu, solda
/// daraltılabilir kitaplık paneli, sağda yuvarlak köşeli içerik paneli.
/// Bölüm sayfaları [DesktopChrome] içinde kendi başlıklarını çizmez.
class DesktopFrame extends StatelessWidget {
  const DesktopFrame({
    super.key,
    required this.topBar,
    required this.library,
    required this.content,
    this.nowPlaying,
    this.bottomBar,
  });

  /// Paneller arası ve kenar boşluğu.
  static const double gap = 8;

  final Widget topBar;
  final Widget library;
  final Widget content;

  /// Sağdaki "Şimdi oynatılan" paneli; null ise yok.
  final Widget? nowPlaying;

  /// Alttaki oynatma çubuğu; çalan bir şey yoksa null.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RedoxRoles.surfaceContainerLowest,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gap, 0, gap, bottomBar == null ? gap : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            topBar,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  library,
                  const SizedBox(width: gap),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RedoxRadius.lg),
                      child: ColoredBox(
                        color: RedoxRoles.surface,
                        child: DesktopChrome(child: content),
                      ),
                    ),
                  ),
                  if (nowPlaying case final panel?) ...[const SizedBox(width: gap), panel],
                ],
              ),
            ),
            ?bottomBar,
          ],
        ),
      ),
    );
  }
}

/// Üst çubuk: logo (Anasayfa), geri/ileri, Anasayfa düğmesi, ortada arama,
/// sağda profil ve saat.
class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({
    super.key,
    required this.clock,
    required this.profileName,
    required this.home,
    this.kids = false,
    this.onBack,
    this.onForward,
    this.onHome,
    this.onProfile,
  });

  static const double height = 64;

  final String clock;
  final String profileName;
  final bool kids;

  /// Anasayfa açık mı (düğme dolu çizilir)?
  final bool home;

  /// null ise düğme pasif (geçmiş yok).
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onHome;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Tooltip(
            message: 'Anasayfa',
            child: InkWell(
              onTap: onHome,
              customBorder: const CircleBorder(),
              child: Image.asset(
                BrandAssets.markPng,
                width: 40,
                height: 40,
                semanticLabel: 'RedoX TV',
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _NavButton(icon: RedoxIcons.chevronLeft, tooltip: 'Geri', onPressed: onBack),
          const SizedBox(width: 4),
          _NavButton(icon: RedoxIcons.chevronRight, tooltip: 'İleri', onPressed: onForward),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HomeButton(selected: home, onPressed: onHome),
                const SizedBox(width: 8),
                Flexible(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: const HeaderSearch()),
                ),
              ],
            ),
          ),
          HeaderProfilePill(name: profileName, kids: kids, onPressed: onProfile),
          const SizedBox(width: 12),
          HeaderClock(clock: clock),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Geri/ileri: küçük dairesel düğme, geçmiş yoksa soluk.
class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.tooltip, this.onPressed});

  final RedoxIcons icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        disabledBackgroundColor: RedoxRoles.surfaceContainerLow,
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
      ),
      icon: RedoxIcon(icon, color: enabled ? RedoxRoles.onSurface : RedoxRoles.onSurfaceVariant.withValues(alpha: 0.4)),
    );
  }
}

/// Aramanın yanındaki Anasayfa düğmesi (Spotify'daki gibi): 48 dp daire,
/// Anasayfadayken dolu ikon.
class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.selected, this.onPressed});

  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Anasayfa',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? RedoxRoles.secondaryContainer : RedoxRoles.surfaceContainerHigh,
        fixedSize: const Size.square(48),
      ),
      icon: RedoxIcon(
        RedoxIcons.home,
        filled: selected,
        color: selected ? RedoxRoles.onSecondaryContainer : RedoxRoles.onSurfaceVariant,
      ),
    );
  }
}

/// Sol kitaplık paneli. Açıkken 280 dp: bölümler, kitaplık ve son izlenen
/// kanallar adlarıyla; daralmışken 88 dp: yalnız ikonlar ve logolar
/// (adlar ipucunda).
class DesktopLibraryPanel extends StatelessWidget {
  const DesktopLibraryPanel({
    super.key,
    required this.browse,
    required this.library,
    required this.footer,
    required this.selected,
    required this.onSelected,
    required this.expanded,
    required this.onToggle,
    this.recent = const [],
    this.onWatch,
  });

  static const double expandedWidth = 280;
  static const double collapsedWidth = 88;

  /// Göz atılan bölümler (Anasayfa, Televizyon, Radyo, Film, Dizi).
  final List<AppSection> browse;

  /// Kişisel bölümler (Favoriler, Bölünmüş ekran, Kaynaklar).
  final List<AppSection> library;

  /// En alttaki bölümler (Ayarlar).
  final List<AppSection> footer;

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;

  final bool expanded;
  final VoidCallback onToggle;

  /// Son izlenen kanallar (en yenisi önce).
  final List<LiveChannel> recent;
  final ValueChanged<LiveChannel>? onWatch;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget heading(String text) => expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Text(text, style: t.titleSmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
          )
        : const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Divider(height: 1, color: RedoxRoles.outlineVariant),
          );
    Widget items(List<AppSection> sections) => Column(
      children: [
        for (final s in sections)
          _PanelItem(
            icon: s.icon,
            label: s.label,
            selected: s == selected,
            expanded: expanded,
            onPressed: () => onSelected(s),
          ),
      ],
    );
    return AnimatedContainer(
      duration: M3EMotion.medium2,
      curve: M3EMotion.standard,
      width: expanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RedoxRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: expanded ? expandedWidth : collapsedWidth,
        maxWidth: expanded ? expandedWidth : collapsedWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeader(expanded: expanded, onToggle: onToggle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  items(browse),
                  if (library.isNotEmpty) ...[heading('Kitaplığın'), items(library)],
                  if (recent.isNotEmpty) ...[
                    heading('Son izlenenler'),
                    for (final c in recent)
                      _RecentChannel(channel: c, expanded: expanded, onPressed: () => onWatch?.call(c)),
                  ],
                ],
              ),
            ),
            if (footer.isNotEmpty) ...[
              const Divider(height: 1, color: RedoxRoles.outlineVariant),
              const SizedBox(height: 8),
              items(footer),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final button = IconButton(
      tooltip: expanded ? 'Paneli daralt' : 'Paneli genişlet',
      onPressed: onToggle,
      icon: RedoxIcon(expanded ? RedoxIcons.menuOpen : RedoxIcons.menu, color: RedoxRoles.onSurfaceVariant),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: expanded
          ? Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gezin',
                    style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
                button,
              ],
            )
          : Center(child: button),
    );
  }
}

/// Paneldeki bölüm: M3 Expressive hap gösterge. Seçili öğe secondary
/// container zeminli ve dolu ikonlu; üstüne gelince %8 durum katmanı.
class _PanelItem extends StatelessWidget {
  const _PanelItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onPressed,
  });

  final RedoxIcons icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = selected ? RedoxRoles.onSecondaryContainer : RedoxRoles.onSurfaceVariant;
    final tile = Material(
      color: selected ? RedoxRoles.secondaryContainer : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: RedoxRoles.onSurface.withValues(alpha: 0.08),
        focusColor: RedoxRoles.onSurface.withValues(alpha: 0.10),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (expanded) const SizedBox(width: 16),
              RedoxIcon(icon, filled: selected, color: fg),
              if (expanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelLarge!.copyWith(
                      color: selected ? RedoxRoles.onSecondaryContainer : RedoxRoles.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 16, vertical: 2),
      child: Semantics(
        selected: selected,
        child: expanded ? tile : Tooltip(message: label, child: tile),
      ),
    );
  }
}

/// Son izlenen kanal: logo karosu, ad ve numara; tıklayınca oynar.
class _RecentChannel extends StatelessWidget {
  const _RecentChannel({required this.channel, required this.expanded, required this.onPressed});

  final LiveChannel channel;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(RedoxRadius.sm),
      child: SizedBox.square(
        dimension: 44,
        child: ChannelLogo(name: channel.name, logoUrl: channel.logoUrl, size: 0.8),
      ),
    );
    final row = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(RedoxRadius.md),
      hoverColor: RedoxRoles.onSurface.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            logo,
            if (expanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelLarge!.copyWith(color: RedoxRoles.onSurface),
                    ),
                    Text('Kanal ${channel.number}', style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Semantics(
        button: true,
        label: '${channel.name} izle',
        child: expanded ? row : Tooltip(message: channel.name, child: row),
      ),
    );
  }
}
