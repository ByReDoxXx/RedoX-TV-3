import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';
import '../home_content.dart';
import 'resume_board.dart';

/// İzleme kaydı yokken pano (anasayfa B tasarımı, [ResumeBoard] düzeni):
/// büyük kartta şu an yayında olan kanal ("Canlı yayına gir", "Yayın akışı"),
/// yanında sonraki iki kanal küçük kart. Görsel yayından alınan karedir
/// ([artwork]); yoksa kanal logosu.
class LiveBoard extends StatelessWidget {
  const LiveBoard({
    super.key,
    required this.hero,
    required this.artwork,
    this.others = const [],
    this.primaryFocused,
    this.onWatch,
    this.onGuide,
  });

  final HomeHero hero;

  /// Küçük kartlardaki kanallar (en çok iki).
  final List<LiveChannel> others;

  /// Kanalın görseli (kart genişliğiyle).
  final Widget Function(LiveChannel channel, double width) artwork;

  /// Önizleme: birincil düğmeyi odakta göster.
  final bool? primaryFocused;
  final ValueChanged<LiveChannel>? onWatch;
  final VoidCallback? onGuide;

  @override
  Widget build(BuildContext context) {
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    final gap = phone ? 12.0 : 16.0;
    final rest = others.take(ResumeBoard.size - 1).toList();
    final large = LayoutBuilder(
      builder: (context, box) => _LargeTile(
        hero: hero,
        artwork: artwork(hero.channel, box.maxWidth),
        phone: phone,
        primaryFocused: primaryFocused,
        onWatch: () => onWatch?.call(hero.channel),
        onGuide: onGuide,
      ),
    );
    Widget small(LiveChannel c) => LayoutBuilder(
      builder: (context, box) =>
          LiveBoardTile(channel: c, artwork: artwork(c, box.maxWidth), onPressed: () => onWatch?.call(c)),
    );
    if (phone) {
      return Column(
        children: [
          large,
          if (rest.isNotEmpty) ...[
            SizedBox(height: gap),
            SizedBox(
              height: 112,
              child: Row(
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: small(rest[i])),
                  ],
                  if (rest.length == 1) ...[SizedBox(width: gap), const Spacer()],
                ],
              ),
            ),
          ],
        ],
      );
    }
    return SizedBox(
      height: ResumeBoard.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: large),
          if (rest.isNotEmpty) ...[
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) SizedBox(height: gap),
                    Expanded(child: small(rest[i])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Alttan obsidyen perde (yazı okunurluğu).
const _scrim = DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      stops: [0, 0.55, 1],
      colors: [RedoxSeeds.obsidian, Color(0x99000000), Color(0x00000000)],
    ),
  ),
);

/// Büyük kart: kart değil düğmeleri odaklanır (açılışta "Canlı yayına gir").
class _LargeTile extends StatelessWidget {
  const _LargeTile({
    required this.hero,
    required this.artwork,
    required this.phone,
    this.primaryFocused,
    this.onWatch,
    this.onGuide,
  });

  final HomeHero hero;
  final Widget artwork;
  final bool phone;
  final bool? primaryFocused;
  final VoidCallback? onWatch;
  final VoidCallback? onGuide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tv = Theme.of(context).extension<RedoxMetrics>()?.formFactor == FormFactor.tv;
    final primary = PrimaryButton(
      label: 'Canlı yayına gir',
      icon: RedoxIcons.play,
      // Tuş ipucu yalnız kumandalı TV'de.
      keyHint: tv ? 'OK' : null,
      onPressed: onWatch,
      focused: primaryFocused,
      autofocus: primaryFocused == null,
    );
    final guide = GlassButton(label: 'Yayın akışı', icon: RedoxIcons.clock, iconOnly: true, onPressed: onGuide);
    final info = [hero.phase, if (hero.clock.isNotEmpty) hero.clock].join(' · ');
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const StatusBadge(label: 'CANLI', pulse: true),
              Text(
                '${hero.channelName} · Kanal ${hero.number}',
                style: t.labelMedium!.copyWith(color: RedoxRoles.tertiary, fontFeatures: RedoxType.tabular),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hero.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.headlineMedium!.copyWith(color: RedoxRoles.onSurface),
          ),
          Text(
            info,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
          ),
          const SizedBox(height: 8),
          RedoxProgressBar(value: hero.progress, thermal: true, height: 6),
          const SizedBox(height: 12),
          Row(
            children: [
              // Dar ekranda birincil düğme sığmazsa orantılı küçülür.
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: primary),
              ),
              const SizedBox(width: 12),
              guide,
            ],
          ),
        ],
      ),
    );
    return Material(
      color: RedoxRoles.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        side: RedoxElevation.restingBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        // Telefonda kart yüksekliğini içerik belirler (en az 16:9).
        fit: phone ? StackFit.loose : StackFit.expand,
        children: [
          Positioned.fill(child: artwork),
          const Positioned.fill(child: _scrim),
          if (phone)
            LayoutBuilder(
              builder: (context, box) => ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth, minHeight: box.maxWidth * 9 / 16),
                child: Align(alignment: Alignment.bottomLeft, widthFactor: 1, heightFactor: 1, child: content),
              ),
            )
          else
            Align(alignment: Alignment.bottomLeft, child: content),
        ],
      ),
    );
  }
}

/// Panonun küçük canlı kartı: kanal, şimdiki program ve yayın ilerlemesi;
/// OK ya da dokunma kanalı açar.
class LiveBoardTile extends StatelessWidget {
  const LiveBoardTile({super.key, required this.channel, required this.artwork, this.onPressed});

  final LiveChannel channel;
  final Widget artwork;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return FocusGlow(
      borderRadius: radius,
      builder: (context, active) => Material(
        color: RedoxRoles.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: active ? BorderSide.none : RedoxElevation.restingBorder,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              artwork,
              _scrim,
              const Positioned(top: 10, left: 12, child: StatusBadge(label: 'CANLI')),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.programTitle ?? 'Yayın akışı bilgisi yok',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    RedoxProgressBar(value: channel.progress ?? 0, height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karesi olmayan kanalın pano görseli: renk geçişi, logo sağda ortada
/// (yazılar solda kalır).
class LiveBoardLogo extends StatelessWidget {
  const LiveBoardLogo({super.key, required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = (box.maxHeight * 0.45).clamp(40.0, 120.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            ArtworkFallback(name: channel.name, showInitials: false),
            Positioned(
              right: 16,
              top: 12,
              width: side,
              height: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RedoxRadius.lg),
                child: ChannelLogo(name: channel.name, logoUrl: channel.logoUrl, size: 0.7),
              ),
            ),
          ],
        );
      },
    );
  }
}
