// RedoX TV 3.0 tonal palet üreticisi.
//
// Kullanım (proje kökünden): dart run tool/generate_tonal_palette.dart
//
// Girdi : design/tokens.json'daki ölçülmüş marka renkleri (tohum).
// Çıktı : design/tonal-palette.json  ve  lib/core/theme/redox_tonal.dart
// Kural : Kontrast eşikleri sağlanmazsa araç hata ile çıkar (çıktı yazılmaz).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_color_utilities/material_color_utilities.dart';

/// Tohum renkler (tokens.json -> brand/surface, "measured").
const _seedPrimary = 0xFFE11D3C; // kızıl
const _seedSecondary = 0xFF820E26; // şarap
const _seedTertiary = 0xFFE5AF53; // altın
const _seedBackground = 0xFF0F1126; // logo zemini (nötr tohum)

const _tones = [
  0, 4, 6, 10, 12, 17, 20, 22, 24, 30, 40, 50, //
  60, 70, 80, 87, 90, 92, 94, 95, 96, 98, 99, 100,
];

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

double _lin(int c) {
  final v = c / 255;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(int argb) =>
    0.2126 * _lin((argb >> 16) & 0xFF) +
    0.7152 * _lin((argb >> 8) & 0xFF) +
    0.0722 * _lin(argb & 0xFF);

double _contrast(int a, int b) {
  final x = _lum(a), y = _lum(b);
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final bg = Hct.fromInt(_seedBackground);
  final palettes = <String, TonalPalette>{
    'primary': TonalPalette.fromHct(Hct.fromInt(_seedPrimary)),
    'secondary': TonalPalette.fromHct(Hct.fromInt(_seedSecondary)),
    'tertiary': TonalPalette.fromHct(Hct.fromInt(_seedTertiary)),
    'neutral': TonalPalette.fromHct(bg),
    'neutralVariant': TonalPalette.of(bg.hue, bg.chroma * 1.4),
    'error': TonalPalette.of(25, 84),
  };

  int t(String p, int tone) => palettes[p]!.get(tone);

  // Koyu rol eşlemesi: marka kızılı/altını sabit çıpa; kalanı tonlardan.
  final dark = <String, int>{
    'primary': _seedPrimary,
    'onPrimary': 0xFFFFFFFF,
    'primaryContainer': t('primary', 40),
    'onPrimaryContainer': t('primary', 90),
    'secondary': t('secondary', 80),
    'onSecondary': t('secondary', 20),
    'secondaryContainer': t('secondary', 30),
    'onSecondaryContainer': t('secondary', 90),
    'tertiary': _seedTertiary,
    'onTertiary': t('neutral', 6),
    'tertiaryContainer': t('tertiary', 30),
    'onTertiaryContainer': t('tertiary', 90),
    'error': t('error', 80),
    'onError': t('error', 20),
    'errorContainer': t('error', 30),
    'onErrorContainer': t('error', 90),
    'surface': _seedBackground,
    'onSurface': t('neutral', 90),
    'onSurfaceVariant': t('neutralVariant', 80),
    'outline': t('neutralVariant', 60),
    'outlineVariant': t('neutralVariant', 30),
    'surfaceDim': _seedBackground,
    'surfaceBright': t('neutral', 24),
    'surfaceContainerLowest': t('neutral', 4),
    'surfaceContainerLow': t('neutral', 10),
    'surfaceContainer': t('neutral', 12),
    'surfaceContainerHigh': t('neutral', 17),
    'surfaceContainerHighest': t('neutral', 22),
    'inverseSurface': t('neutral', 90),
    'onInverseSurface': t('neutral', 20),
    'inversePrimary': t('primary', 40),
    'scrim': 0xFF000000,
    'shadow': 0xFF000000,
  };

  final light = <String, int>{
    'primary': _seedPrimary,
    'onPrimary': 0xFFFFFFFF,
    'primaryContainer': t('primary', 90),
    'onPrimaryContainer': t('primary', 10),
    'secondary': t('secondary', 40),
    'onSecondary': 0xFFFFFFFF,
    'secondaryContainer': t('secondary', 90),
    'onSecondaryContainer': t('secondary', 10),
    'tertiary': t('tertiary', 40),
    'onTertiary': 0xFFFFFFFF,
    'tertiaryContainer': t('tertiary', 90),
    'onTertiaryContainer': t('tertiary', 10),
    'error': t('error', 40),
    'onError': 0xFFFFFFFF,
    'errorContainer': t('error', 90),
    'onErrorContainer': t('error', 10),
    'surface': t('neutral', 98),
    'onSurface': t('neutral', 10),
    'onSurfaceVariant': t('neutralVariant', 30),
    'outline': t('neutralVariant', 50),
    'outlineVariant': t('neutralVariant', 80),
    'surfaceDim': t('neutral', 87),
    'surfaceBright': t('neutral', 98),
    'surfaceContainerLowest': t('neutral', 100),
    'surfaceContainerLow': t('neutral', 96),
    'surfaceContainer': t('neutral', 94),
    'surfaceContainerHigh': t('neutral', 92),
    'surfaceContainerHighest': t('neutral', 90),
    'inverseSurface': t('neutral', 20),
    'onInverseSurface': t('neutral', 95),
    'inversePrimary': t('primary', 80),
    'scrim': 0xFF000000,
    'shadow': 0xFF000000,
  };

  // Kontrast kapıları: (ön, arka, en düşük oran)
  const textPairs = [
    ['onPrimary', 'primary', 4.5],
    ['onPrimaryContainer', 'primaryContainer', 4.5],
    ['onSecondary', 'secondary', 4.5],
    ['onSecondaryContainer', 'secondaryContainer', 4.5],
    ['onTertiary', 'tertiary', 4.5],
    ['onTertiaryContainer', 'tertiaryContainer', 4.5],
    ['onError', 'error', 4.5],
    ['onErrorContainer', 'errorContainer', 4.5],
    ['onSurface', 'surface', 4.5],
    ['onSurface', 'surfaceContainerHighest', 4.5],
    ['onSurfaceVariant', 'surface', 4.5],
    ['onSurfaceVariant', 'surfaceContainerHighest', 4.5],
    ['onInverseSurface', 'inverseSurface', 4.5],
    ['outline', 'surface', 3.0], // metin dışı bileşen eşiği
  ];

  final failures = <String>[];
  final report = <String, Map<String, double>>{'dark': {}, 'light': {}};
  for (final entry in {'dark': dark, 'light': light}.entries) {
    for (final p in textPairs) {
      final r = _contrast(entry.value[p[0]]!, entry.value[p[1]]!);
      report[entry.key]!['${p[0]}/${p[1]}'] = double.parse(r.toStringAsFixed(2));
      if (r < (p[2] as double)) {
        failures.add('${entry.key}: ${p[0]} / ${p[1]} = ${r.toStringAsFixed(2)} '
            '(< ${p[2]})');
      }
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln('KONTRAST HATASI, çıktı yazılmadı:\n  ${failures.join('\n  ')}');
    exitCode = 1;
    return;
  }

  final tonal = <String, Map<String, String>>{
    for (final e in palettes.entries)
      e.key: {for (final tn in _tones) '$tn': _hex(e.value.get(tn))},
  };
  final seedInfo = {
    'primary': _hct(_seedPrimary),
    'secondary': _hct(_seedSecondary),
    'tertiary': _hct(_seedTertiary),
    'background': _hct(_seedBackground),
  };

  File('design/tonal-palette.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      r'$comment': 'tool/generate_tonal_palette.dart tarafından üretildi; elle düzenlemeyin.',
      'library': 'material_color_utilities 0.13.0 (HCT)',
      'seeds': seedInfo,
      'tones': tonal,
      'roles': {
        'dark': {for (final e in dark.entries) e.key: _hex(e.value)},
        'light': {for (final e in light.entries) e.key: _hex(e.value)},
      },
      'contrast': report,
    })}\n',
  );

  final b = StringBuffer()
    ..writeln('// GENERATED by tool/generate_tonal_palette.dart. Elle düzenlemeyin.')
    ..writeln('// Kaynak: design/tonal-palette.json (material_color_utilities 0.13.0, HCT).')
    ..writeln("import 'dart:ui' show Color;")
    ..writeln()
    ..writeln('/// Marka tohumlarından üretilen tonal paletler (ton -> renk).')
    ..writeln('abstract final class RedoxTonal {');
  for (final e in palettes.entries) {
    b.writeln('  static const ${e.key} = <int, Color>{');
    for (final tn in _tones) {
      b.writeln('    $tn: Color(0xFF${_hex(e.value.get(tn)).substring(1)}),');
    }
    b.writeln('  };');
  }
  b.writeln('}');
  for (final entry in {'Dark': dark, 'Light': light}.entries) {
    b
      ..writeln()
      ..writeln('/// ${entry.key == 'Dark' ? 'Koyu' : 'Açık'} tema rol eşlemesi.')
      ..writeln('abstract final class Redox${entry.key}Roles {');
    for (final r in entry.value.entries) {
      b.writeln('  static const ${r.key} = Color(0xFF${_hex(r.value).substring(1)});');
    }
    b.writeln('}');
  }
  File('lib/core/theme/redox_tonal.dart').writeAsStringSync(b.toString());

  stdout.writeln('Tohumlar (HCT): $seedInfo');
  stdout.writeln('Koyu rol kontrastları: ${report['dark']}');
  stdout.writeln('Açık rol kontrastları: ${report['light']}');
  stdout.writeln('Yazıldı: design/tonal-palette.json, lib/core/theme/redox_tonal.dart');
}

Map<String, double> _hct(int argb) {
  final h = Hct.fromInt(argb);
  return {
    'hue': double.parse(h.hue.toStringAsFixed(1)),
    'chroma': double.parse(h.chroma.toStringAsFixed(1)),
    'tone': double.parse(h.tone.toStringAsFixed(1)),
  };
}
