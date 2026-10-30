import 'package:flutter/material.dart';

import '../../../core/theme/m3e_tokens.dart';
import '../../../core/theme/redox_palette.dart';
import '../../../core/theme/redox_tonal.dart';
import '../widgets/section_frame.dart';

/// 1. Marka renkleri, koyu tema rolleri ve tonal şeritler.
class PaletteSection extends StatelessWidget {
  const PaletteSection({super.key});

  static const _brand = <String, Color>{
    'Kızıl': RedoxPalette.red,
    'Koyu kızıl': RedoxDarkRoles.primaryContainer,
    'Şarap': RedoxPalette.redWine,
    'Mercan': RedoxPalette.coral,
    'Altın': RedoxPalette.gold,
    'Parlak altın': RedoxPalette.goldBright,
    'Bronz': RedoxPalette.bronze,
  };

  static const _surfaces = <String, Color>{
    'En alt': RedoxDarkRoles.surfaceContainerLowest,
    'Zemin': RedoxDarkRoles.surface,
    'Kart altı': RedoxDarkRoles.surfaceContainerLow,
    'Kart': RedoxDarkRoles.surfaceContainer,
    'Yükseltilmiş': RedoxDarkRoles.surfaceContainerHigh,
    'En yüksek': RedoxDarkRoles.surfaceContainerHighest,
    'Metin': RedoxDarkRoles.onSurface,
    'İkincil metin': RedoxDarkRoles.onSurfaceVariant,
    'Çerçeve': RedoxDarkRoles.outline,
  };

  static const _tonal = <String, Map<int, Color>>{
    'Primary': RedoxTonal.primary,
    'Secondary': RedoxTonal.secondary,
    'Tertiary': RedoxTonal.tertiary,
    'Neutral': RedoxTonal.neutral,
    'Neutral variant': RedoxTonal.neutralVariant,
    'Error': RedoxTonal.error,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionFrame(
      index: 1,
      title: 'Renk paleti',
      subtitle: 'Logodan ölçüldü; tonal paletler HCT ile üretildi (design/tonal-palette.json).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Marka', style: t.titleMedium),
          const SizedBox(height: 12),
          _SwatchRow(colors: _brand),
          const SizedBox(height: 24),
          Text('Zemin ve metin rolleri', style: t.titleMedium),
          const SizedBox(height: 12),
          _SwatchRow(colors: _surfaces),
          const SizedBox(height: 24),
          Text('Tonal şeritler (ton 0–100)', style: t.titleMedium),
          const SizedBox(height: 12),
          for (final e in _tonal.entries) _TonalStrip(name: e.key, tones: e.value),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.colors});

  final Map<String, Color> colors;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final e in colors.entries)
          Container(
            width: 176,
            height: 104,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: e.value,
              borderRadius: BorderRadius.circular(M3EShape.large),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: DefaultTextStyle(
              style: t.labelLarge!.copyWith(color: _ink(e.value)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(hexOf(e.value), style: const TextStyle(fontFeatures: M3EType.tabularFigures)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TonalStrip extends StatelessWidget {
  const _TonalStrip({required this.name, required this.tones});

  final String name;
  final Map<int, Color> tones;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(name, style: t.labelLarge)),
          for (final e in tones.entries)
            Expanded(
              child: Container(
                height: 44,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: e.value,
                  borderRadius: BorderRadius.circular(M3EShape.small),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${e.key}',
                  style: t.labelSmall!.copyWith(
                    color: _ink(e.value),
                    fontFeatures: M3EType.tabularFigures,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Zemin rengine göre okunur yazı rengi (açık zeminde koyu).
Color _ink(Color c) =>
    c.computeLuminance() > 0.25 ? RedoxDarkRoles.surface : Colors.white;
