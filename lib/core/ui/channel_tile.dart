import 'package:flutter/material.dart';

import '../content/live_channel.dart';
import '../layout/form_factor.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_elevation.dart';
import '../theme/redox_metrics.dart';
import '../theme/redox_shapes.dart';
import '../theme/redox_type.dart';
import 'channel_logo.dart';
import 'focus_glow.dart';
import 'long_press_select.dart';
import 'redox_icon.dart';
import 'redox_progress_bar.dart';
import 'status_badge.dart';

/// Sık kanal kartı (Televizyon ızgarası; kullanıcının referansından
/// esinlenildi): üstte logo karosu, sağında numara ve CANLI; altında kanal
/// adı, şimdiki program ve ince ilerleme çizgisi. 16:9 görsel yoktur: ekranda daha çok kanal sığar.
/// Yazılar sıktır (12/14 dp): TV'nin 16 dp yazı tabanının bilinçli istisnası
/// (kullanıcı isteği); 960 dp tuvalde 12 dp, 1080p ekranda 24 px eder.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    this.selected = false,
    this.onPressed,
    this.focused,
    this.favorite = false,
    this.onFavorite,
  });

  final LiveChannel channel;

  /// Önizlemedeki kanal: odakta değilken altın kenarlık.
  final bool selected;
  final VoidCallback? onPressed;
  final bool? focused;

  /// Favoride: yıldız dolu.
  final bool favorite;

  /// Favori ekle/çıkar (kullanıcı isteği): TV'de uzun OK, dokunmatikte
  /// yıldıza dokunma ya da uzun dokunma. null ise yıldız yok.
  final VoidCallback? onFavorite;

  static const _padding = 12.0;
  static const _logo = 40.0;
  static const _gap = 8.0;
  static const _progressGap = 10.0;
  static const _progressHeight = 4.0;
  static const _badgeHeight = 16.0;

  static const _name = RedoxType.labelLg;
  static const _program = RedoxType.bodySm;
  static const _number = RedoxType.labelSm;

  /// Kartın yüksekliği (ızgara hücresi): satır yükseklikleri yazı ölçeğiyle.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle s) => scaler.scale(s.fontSize!) * (s.height ?? 1.2);
    final badges = line(_number) + 4 + 4 + _badgeHeight;
    final top = badges > _logo ? badges : _logo;
    return (2 * _padding + top + _gap + line(_name) + 2 + line(_program) + _progressGap + _progressHeight)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    final touch = Theme.of(context).extension<RedoxMetrics>()?.formFactor != FormFactor.tv;
    final tile = FocusGlow(
      borderRadius: radius,
      focused: focused,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHigh : RedoxRoles.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: active
              ? BorderSide.none
              : selected
              ? const BorderSide(color: RedoxRoles.tertiary, width: 2)
              : RedoxElevation.restingBorder,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onFavorite,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst: logo karosu solda; numara ve CANLI sağda alt alta. Ad
                // ve program altta tam genişlikte: 3 sütunlu dar kartta da
                // kanal adı sığsın.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RedoxRadius.md),
                      child: SizedBox.square(
                        dimension: _logo,
                        child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: RedoxRoles.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(RedoxRadius.full),
                          ),
                          child: Text(
                            c.number.toString().padLeft(3, '0'),
                            style: _number.copyWith(
                              color: RedoxRoles.tertiary,
                              fontWeight: FontWeight.w800,
                              fontFeatures: RedoxType.tabular,
                            ),
                          ),
                        ),
                        if (c.live) ...[
                          const SizedBox(height: 4),
                          const SizedBox(
                            height: _badgeHeight,
                            child: FittedBox(child: StatusBadge(label: 'CANLI', pulse: true)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: _gap),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: _name.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Yıldız adın satırında: dar kartta (4 sütun) üst satıra sığmıyordu.
                    if (onFavorite != null && (touch || favorite))
                      _Star(filled: favorite, onPressed: touch ? onFavorite : null),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  // Yayın akışı yoksa: akış sayısı ve kategori.
                  c.programTitle ?? '${c.streams.length} akış · ${c.category}',
                  style: _program.copyWith(color: RedoxRoles.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: _progressGap),
                RedoxProgressBar(value: c.progress ?? 0, color: c.accent.fill, height: _progressHeight),
              ],
            ),
          ),
        ),
      ),
    );
    return onFavorite == null ? tile : LongPressSelect(onPressed: onPressed, onLongPress: onFavorite, child: tile);
  }
}

/// Favori yıldızı: dokunmatikte düğme, TV'de yalnız favorideyse işaret.
class _Star extends StatelessWidget {
  const _Star({required this.filled, this.onPressed});

  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = RedoxIcon(
      RedoxIcons.star,
      filled: filled,
      size: 20,
      color: filled ? RedoxSeeds.gold : RedoxRoles.onSurfaceVariant,
    );
    if (onPressed == null) return icon;
    return Semantics(
      button: true,
      label: filled ? 'Favorilerden çıkar' : 'Favorilere ekle',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        canRequestFocus: false,
        child: SizedBox(width: 28, height: 20, child: Center(child: icon)),
      ),
    );
  }
}
