import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_tonal.dart';
import '../../../core/theme/redox_type.dart';
import '../widgets/section_frame.dart';

/// 1. Tohumlar, roller, vurgu renkleri ve tonal şeritler.
class PaletteSection extends StatelessWidget {
  const PaletteSection({super.key});

  static const _seeds = <String, Color>{
    'Crimson Flame': RedoxSeeds.crimson,
    'Molten Amber': RedoxSeeds.amber,
    'Incandescent Gold': RedoxSeeds.gold,
    'Obsidian Void': RedoxSeeds.obsidian,
  };

  static const _surfaces = <String, Color>{
    'lowest': RedoxRoles.surfaceContainerLowest,
    'surface · ray': RedoxRoles.surface,
    'low': RedoxRoles.surfaceContainerLow,
    'container · kart': RedoxRoles.surfaceContainer,
    'high · üst katman': RedoxRoles.surfaceContainerHigh,
    'highest · diyalog': RedoxRoles.surfaceContainerHighest,
    'bright': RedoxRoles.surfaceBright,
  };

  static const _accents = <String, Color>{
    'primary': RedoxRoles.primary,
    'primary-container': RedoxRoles.primaryContainer,
    'secondary': RedoxRoles.secondary,
    'secondary-container': RedoxRoles.secondaryContainer,
    'tertiary': RedoxRoles.tertiary,
    'tertiary-container': RedoxRoles.tertiaryContainer,
    'on-surface': RedoxRoles.onSurface,
    'on-surface-variant': RedoxRoles.onSurfaceVariant,
    'outline': RedoxRoles.outline,
    'outline-variant': RedoxRoles.outlineVariant,
    'error': RedoxRoles.error,
    'kor (çip ucu)': RedoxAccent.ember,
  };

  static final _tonal = <String, TonalPalette>{
    'Primary · kızıl': RedoxTonal.primary,
    'Secondary · amber': RedoxTonal.secondary,
    'Tertiary · altın': RedoxTonal.tertiary,
    'Neutral · obsidyen': RedoxTonal.neutral,
    'Neutral variant': RedoxTonal.neutralVariant,
    'Error': RedoxTonal.error,
  };

  @override
  Widget build(BuildContext context) {
    return SectionFrame(
      index: 1,
      title: 'Renk',
      subtitle: 'Tohumlar logodan (Logo-2) ölçüldü · roller M3 sadakat şemasıyla türer (testle kanıtlı).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GroupLabel('Tohumlar'),
          _SwatchRow(colors: _seeds, wide: true),
          const GroupLabel('Yüzey kademeleri (koyudan açığa)'),
          _SwatchRow(colors: _surfaces),
          const GroupLabel('Roller ve vurgular'),
          _SwatchRow(colors: _accents),
          const GroupLabel('Isıl degrade · seçili çip degradesi'),
          Row(
            children: [
              // Sora'da "→" glifi yok; görünen metinde "–" kullanılır.
              Expanded(child: _GradientBar(colors: RedoxAccent.thermal, label: 'kızıl – amber – altın')),
              const SizedBox(width: 12),
              const Expanded(child: _GradientBar(colors: [RedoxSeeds.crimson, RedoxAccent.ember], label: 'kızıl – kor')),
            ],
          ),
          const GroupLabel('Tonal şeritler (ton 0–100)'),
          for (final e in _tonal.entries) _TonalStrip(name: e.key, palette: e.value),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.colors, this.wide = false});

  final Map<String, Color> colors;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in colors.entries)
          Container(
            width: wide ? 206 : 166,
            height: wide ? 88 : 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: e.value,
              borderRadius: BorderRadius.circular(RedoxRadius.md),
              border: Border.all(color: RedoxAccent.ghostBorder),
            ),
            child: DefaultTextStyle(
              style: t.bodySmall!.copyWith(color: _ink(e.value)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(hexOf(e.value), style: const TextStyle(fontFeatures: RedoxType.tabular)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GradientBar extends StatelessWidget {
  const _GradientBar({required this.colors, required this.label});

  final List<Color> colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TonalStrip extends StatelessWidget {
  const _TonalStrip({required this.name, required this.palette});

  final String name;
  final TonalPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(name, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant))),
          for (final tone in RedoxTonal.tones)
            Expanded(
              child: Container(
                height: 28,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: Color(palette.get(tone)),
                  borderRadius: BorderRadius.circular(RedoxRadius.xs),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$tone',
                  style: TextStyle(
                    fontFamily: RedoxType.family,
                    fontSize: 9,
                    fontFeatures: RedoxType.tabular,
                    color: _ink(Color(palette.get(tone))),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Zemin rengine göre okunur yazı rengi.
Color _ink(Color c) =>
    c.computeLuminance() > 0.25 ? RedoxSeeds.obsidian : Colors.white;
