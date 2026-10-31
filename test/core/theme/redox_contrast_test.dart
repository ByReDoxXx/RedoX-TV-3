import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_colors.dart';
import 'package:redox_tv/core/theme/redox_elevation.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/theme/redox_tonal.dart';
import 'package:redox_tv/core/ui/channel_card.dart';
import 'package:redox_tv/core/ui/status_badge.dart';

import '../../support/contrast.dart';

const _white = Color(0xFFFFFFFF);

void main() {
  group('Bileşen yazıları >= 4.5:1', () {
    test('birincil düğme: beyaz (on-primary-container) / kızıl', () {
      expect(contrast(RedoxRoles.onPrimaryContainer, RedoxSeeds.crimson), greaterThanOrEqualTo(4.5));
    });

    test('cam düğme: boşta yazı cam üstünde, odakta obsidyen / amber', () {
      final glassOnCanvas = Color.alphaBlend(RedoxAccent.glassFill, RedoxRoles.surfaceContainerLowest);
      final glassOnCard = Color.alphaBlend(RedoxAccent.glassFill, RedoxRoles.surfaceContainerHigh);
      expect(contrast(RedoxRoles.onSurface, glassOnCanvas), greaterThanOrEqualTo(4.5));
      expect(contrast(RedoxRoles.onSurface, glassOnCard), greaterThanOrEqualTo(4.5));
      expect(contrast(RedoxSeeds.obsidian, RedoxSeeds.amber), greaterThanOrEqualTo(4.5));
    });

    test('tema cam düğmeyi odakta amber/obsidyen çözer', () {
      final style = RedoxTheme.dark().outlinedButtonTheme.style!;
      const focused = {WidgetState.focused};
      expect(style.backgroundColor!.resolve(focused), RedoxSeeds.amber);
      expect(style.foregroundColor!.resolve(focused), RedoxSeeds.obsidian);
      expect(style.backgroundColor!.resolve({}), RedoxAccent.glassFill);
    });

    test('seçili çip: beyaz yazı degradenin iki ucunda', () {
      expect(contrast(_white, RedoxSeeds.crimson), greaterThanOrEqualTo(4.5));
      expect(contrast(_white, RedoxAccent.ember), greaterThanOrEqualTo(4.5));
    });

    test('kor = amber paletinin beyazla 4.5:1 veren en açık tonu (T49)', () {
      expect(RedoxAccent.ember, Color(RedoxTonal.secondary.get(49)));
      expect(contrast(_white, Color(RedoxTonal.secondary.get(50))), lessThan(4.5));
    });

    test('rozetler', () {
      for (final tone in BadgeTone.values) {
        expect(contrast(tone.foreground, tone.background), greaterThanOrEqualTo(4.5), reason: tone.name);
      }
    });

    test('kart vurgu metinleri kartta (boşta ve odakta)', () {
      for (final a in CardAccent.values) {
        expect(contrast(a.text, RedoxRoles.surfaceContainer), greaterThanOrEqualTo(4.5), reason: a.name);
        expect(contrast(a.text, RedoxRoles.surfaceContainerHigh), greaterThanOrEqualTo(4.5), reason: a.name);
      }
    });

    test('odaktaki giriş alanı: yazı amber yıkamalı zeminde', () {
      final washed = Color.alphaBlend(RedoxAccent.inputFocusWash, RedoxRoles.surfaceContainerHighest);
      expect(contrast(RedoxRoles.onSurface, washed), greaterThanOrEqualTo(4.5));
    });
  });

  group('Metin dışı öğeler >= 3:1', () {
    test('odak halkası tuvalde ve kartta', () {
      for (final bg in [RedoxSeeds.obsidian, RedoxRoles.surfaceContainerLowest, RedoxRoles.surfaceContainer]) {
        expect(contrast(RedoxElevation.focusRing.color, bg), greaterThanOrEqualTo(3.0), reason: '$bg');
      }
    });

    test('ilerleme dolguları izde (iz: surface-container-lowest)', () {
      for (final fill in [...CardAccent.values.map((a) => a.fill), ...RedoxAccent.thermal]) {
        expect(contrast(fill, RedoxRoles.surfaceContainerLowest), greaterThanOrEqualTo(3.0), reason: '$fill');
      }
    });

    test('odaktaki giriş kenarı (amber) en yüksek kapta', () {
      expect(contrast(RedoxSeeds.amber, RedoxRoles.surfaceContainerHighest), greaterThanOrEqualTo(3.0));
    });

    test('marka adındaki kızıl yalnızca büyük yazı: tuvalde >= 3:1', () {
      expect(contrast(RedoxSeeds.crimson, RedoxSeeds.obsidian), greaterThanOrEqualTo(3.0));
    });
  });

  group('Bilinen sınırlar (regresyon)', () {
    test('amber tohum çip ucu olamaz: beyaz / amber yetmez', () {
      expect(contrast(_white, RedoxSeeds.amber), lessThan(3.0));
    });

    test('sadakat şemasının amber kabı siyah izde yetmez; ısıl degradede tohum kullanılır', () {
      expect(contrast(RedoxRoles.secondaryContainer, RedoxRoles.surfaceContainerLowest), lessThan(3.0));
    });

    test('kızıl dolgu en yüksek kap izinde yetmez; iz bu yüzden obsidyen', () {
      expect(contrast(RedoxSeeds.crimson, RedoxRoles.surfaceContainerHighest), lessThan(3.0));
    });

    test('kızıl küçük yazıda kullanılmaz: kartta 4.5:1 altı', () {
      expect(contrast(RedoxSeeds.crimson, RedoxRoles.surfaceContainer), lessThan(4.5));
    });
  });
}
