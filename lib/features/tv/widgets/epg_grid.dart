import 'package:flutter/material.dart';

import '../../../core/content/epg_program.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/focus_glow.dart';

/// EPG çizelgesi: solda sabit kanal sütunu, sağda zaman ekseninde program
/// blokları ve kızıl "şimdi" çizgisi. Yatay kaydırma yoktur: pencere ekran
/// genişliğine sığacak kadar (yarım saatin katı) uzunluktadır ve şimdiden
/// yarım saat önce başlar. Satırlar tembel kurulur (ListView.builder).
///
/// Bir programa OK/dokunma o kanalı açar (canlı yayında yalnız şimdiki
/// program izlenebilir; hatırlatıcı ve geri sarma sonraya).
class EpgGrid extends StatelessWidget {
  const EpgGrid({
    super.key,
    required this.channels,
    required this.scheduleOf,
    required this.now,
    required this.compact,
    this.onChannel,
    this.padding = EdgeInsets.zero,
  });

  final List<LiveChannel> channels;
  final List<EpgProgram> Function(LiveChannel) scheduleOf;

  /// Şimdiki saat, gün başından dakika.
  final int now;

  /// Telefon: dar kanal sütunu (logo ve numara).
  final bool compact;
  final ValueChanged<LiveChannel>? onChannel;

  /// Kayma alanının iç payı (odak halkası ve sayfa kenarı).
  final EdgeInsets padding;

  /// Hedef ölçek (dp/dakika); pencere bu ölçeğe göre seçilir, sonra genişliğe
  /// tam oturacak şekilde gerilir.
  static const _targetScale = 3.2;
  static const _targetScaleCompact = 2.2;

  /// Pencerenin şimdiden önce gösterdiği süre (dakika).
  static const _lead = 30;
  static const _rulerHeight = 28.0;
  static const _rowGap = 8.0;

  /// Kart görünümüyle aynı sık yazılar (TV'nin 16 dp tabanının bilinçli
  /// istisnası, kullanıcı isteği).
  static const _title = RedoxType.labelLg;
  static const _meta = RedoxType.bodySm;

  double get _channelColumn => compact ? 56 : 176;

  /// Satır yüksekliği: blokta başlık + saat satırı sığsın (yazı ölçeği dahil).
  static double rowHeightFor(BuildContext context) {
    double line(TextStyle s) => MediaQuery.textScalerOf(context).scale(s.fontSize!) * (s.height ?? 1.2);
    return (line(_title) + line(_meta) + 2 + 16 + _rowGap).ceilToDouble().clamp(56, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = rowHeightFor(context);
    return LayoutBuilder(
      builder: (context, box) {
        final timeline = box.maxWidth - padding.horizontal - _channelColumn;
        final target = compact ? _targetScaleCompact : _targetScale;
        final minutes = ((timeline / target) / 30).floor().clamp(2, 48) * 30;
        final start = (now ~/ 30) * 30 - _lead;
        final scale = timeline / minutes;
        final window = (start: start, end: start + minutes, scale: scale);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(left: padding.left + _channelColumn, right: padding.right),
              child: SizedBox(
                height: _rulerHeight,
                child: _Ruler(window: window, now: now),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(padding.left, 4, padding.right, padding.bottom),
                itemExtent: rowHeight,
                itemCount: channels.length,
                itemBuilder: (context, i) {
                  final c = channels[i];
                  return Row(
                    children: [
                      SizedBox(
                        width: _channelColumn,
                        child: _ChannelCell(channel: c, compact: compact),
                      ),
                      Expanded(
                        child: _Row(
                          programs: scheduleOf(c),
                          window: window,
                          now: now,
                          onPressed: onChannel == null ? null : () => onChannel!(c),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef _Window = ({int start, int end, double scale});

class _Ruler extends StatelessWidget {
  const _Ruler({required this.window, required this.now});

  final _Window window;
  final int now;

  @override
  Widget build(BuildContext context) {
    final style = EpgGrid._meta.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular);
    final nowX = (now - window.start) * window.scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var t = window.start; t < window.end; t += 30)
          // "Şimdi" hapının altında kalacak etiket yazılmaz.
          if (((t - window.start) * window.scale + 24 - nowX).abs() > 52)
            Positioned(
              left: (t - window.start) * window.scale + 4,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(EpgProgram.formatClock(t), style: style),
              ),
            ),
        // Şimdi: kızıl hap, çizginin üstünde.
        Positioned(
          left: nowX - 24,
          width: 48,
          top: 2,
          bottom: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RedoxRoles.primaryContainer,
              borderRadius: BorderRadius.circular(RedoxRadius.full),
            ),
            child: Center(
              child: FittedBox(
                child: Text(
                  EpgProgram.formatClock(now),
                  style: style.copyWith(color: RedoxRoles.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelCell extends StatelessWidget {
  const _ChannelCell({required this.channel, required this.compact});

  final LiveChannel channel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final number = Text(
      c.number.toString().padLeft(3, '0'),
      style: RedoxType.labelSm.copyWith(
        color: RedoxRoles.tertiary,
        fontWeight: FontWeight.w800,
        fontFeatures: RedoxType.tabular,
      ),
    );
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(RedoxRadius.sm),
      child: SizedBox.square(
        dimension: compact ? 32 : 40,
        child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: EpgGrid._rowGap, right: 8),
      child: compact
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [logo, const SizedBox(height: 2), number])
          : Row(
              children: [
                logo,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      number,
                      Text(
                        c.name,
                        style: RedoxType.labelMd.copyWith(color: c.accent.text, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Bir kanalın zaman ekseni: pencereye kırpılmış program blokları.
class _Row extends StatelessWidget {
  const _Row({required this.programs, required this.window, required this.now, this.onPressed});

  final List<EpgProgram> programs;
  final _Window window;
  final int now;
  final VoidCallback? onPressed;

  /// Bloğun pencereye kırpılmış konumu ve genişliği (aralarında 4 dp boşluk).
  (double, double) _span(EpgProgram p) {
    final from = p.start.clamp(window.start, window.end);
    final to = p.end.clamp(window.start, window.end);
    return ((from - window.start) * window.scale + 2, (to - from) * window.scale - 4);
  }

  @override
  Widget build(BuildContext context) {
    final nowX = (now - window.start) * window.scale;
    return Padding(
      padding: const EdgeInsets.only(bottom: EpgGrid._rowGap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final p in programs)
            if (_span(p) case (final left, final width) when width >= 8)
              Positioned(
                left: left,
                width: width,
                top: 0,
                bottom: 0,
                child: _Block(program: p, now: now, onPressed: onPressed),
              ),
          Positioned(
            left: nowX - 1,
            width: 2,
            top: -EpgGrid._rowGap / 2,
            bottom: -EpgGrid._rowGap / 2,
            child: const IgnorePointer(child: ColoredBox(color: RedoxSeeds.crimson)),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.program, required this.now, this.onPressed});

  final EpgProgram program;
  final int now;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = program;
    final live = p.isLiveAt(now);
    final past = p.known && p.end <= now;
    final radius = BorderRadius.circular(RedoxRadius.sm);
    final fg = past || !p.known ? RedoxRoles.onSurfaceVariant.withValues(alpha: 0.7) : RedoxRoles.onSurface;
    return Semantics(
      label: p.known ? '${p.title}, ${EpgProgram.formatClock(p.start)} – ${EpgProgram.formatClock(p.end)}' : p.title,
      excludeSemantics: true,
      button: true,
      // Ölçek 1: komşu bloklar yan yanadır, büyüyen blok onların altında kalırdı.
      child: FocusGlow(
        borderRadius: radius,
        scale: 1,
        builder: (context, active) => Material(
          color: active
              ? RedoxRoles.surfaceContainerHighest
              : live
              ? RedoxRoles.surfaceContainerHigh
              : past
              ? RedoxRoles.surfaceContainerLowest
              : RedoxRoles.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: live && !active ? const BorderSide(color: RedoxRoles.outlineVariant) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Dar blokta yazı kesik görünmesin: saat 100 dp'nin, başlık
                // 44 dp'nin altında yazılmaz (ad erişilebilirlikte kalır).
                LayoutBuilder(
                  builder: (context, box) => box.maxWidth < 44
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.title,
                                style: EpgGrid._title.copyWith(color: fg),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (p.known && box.maxWidth >= 100) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${EpgProgram.formatClock(p.start)} – ${EpgProgram.formatClock(p.end)}',
                                  style: EpgGrid._meta.copyWith(
                                    color: RedoxRoles.onSurfaceVariant,
                                    fontFeatures: RedoxType.tabular,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                // Canlı programın ilerlemesi: alt kenarda ince kızıl çizgi.
                if (live)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: FractionallySizedBox(
                      widthFactor: ((now - p.start) / (p.end - p.start)).clamp(0, 1),
                      child: const SizedBox(height: 3, child: ColoredBox(color: RedoxSeeds.crimson)),
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
