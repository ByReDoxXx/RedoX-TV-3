import 'package:flutter/material.dart';

import '../theme/m3e_tokens.dart';
import '../theme/redox_palette.dart';
import '../theme/redox_type.dart';

// Logodan çıkarılan tasarım dilinin bileşenleri. Kaynak: design/TASARIM-DILI.md.

/// Motif 1 (halka) + 4 (statik ışık): TV odak halkası.
abstract final class RedoxFocus {
  static const double ringWidth = 3;

  static BoxDecoration ring({required double radius, Color? fill}) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: RedoxPalette.goldBright, width: ringWidth),
      boxShadow: [
        BoxShadow(
          color: RedoxPalette.gold.withValues(alpha: 0.45),
          blurRadius: 24,
        ),
      ],
    );
  }
}

/// Motif 5 (eğim): "RedoX" kızıl + "TV" altın, hafif italik.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: RedoxType.family,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      fontVariations: RedoxType.brandSlant,
      height: 1,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'RedoX', style: base.copyWith(color: RedoxPalette.red)),
          TextSpan(text: ' TV', style: base.copyWith(color: RedoxPalette.gold)),
        ],
      ),
      semanticsLabel: 'RedoX TV',
    );
  }
}

/// Motif 3 (üçlü kontur): sabit CANLI rozeti, koyu konturlu.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelMedium!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: RedoxPalette.red,
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: Border.all(color: RedoxPalette.backgroundDeep, width: 2),
      ),
      child: Text(
        'CANLI',
        style: label.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Motif 6 (gradyan): altın → bronz ilerleme çubuğu.
class GoldProgressBar extends StatelessWidget {
  const GoldProgressBar({super.key, required this.value, this.height = 6});

  /// 0…1 arası.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(M3EShape.full),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [RedoxPalette.goldBright, RedoxPalette.bronze],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Motif 1 (halka): altın halkalı story avatarı (3 dp halka + 3 dp boşluk).
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.label,
    required this.child,
    this.diameter = 88,
  });

  final String label;
  final Widget child;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: diameter,
          height: diameter,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: RedoxPalette.gold, width: 3),
          ),
          child: ClipOval(
            child: ColoredBox(color: scheme.surfaceContainerHigh, child: child),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

/// Kategori çipi. Seçili: kızıl dolgu + altın kılcal + koyu kontur (motif 3).
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge!;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? RedoxPalette.red : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: selected
            ? Border.all(color: RedoxPalette.gold, width: 1)
            : Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Text(
        label,
        style: style.copyWith(
          color: selected ? Colors.white : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
    if (!selected) return chip;
    // Dış koyu kontur.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: Border.all(color: RedoxPalette.backgroundDeep, width: 2),
      ),
      child: chip,
    );
  }
}

/// Motif 4 (statik ışık): kızıl → saydam bölüm ayracı.
class FlareDivider extends StatelessWidget {
  const FlareDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [RedoxPalette.red, Color(0x00E11D3C)],
        ),
      ),
    );
  }
}
