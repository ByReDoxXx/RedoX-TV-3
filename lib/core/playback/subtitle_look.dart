import 'package:flutter/painting.dart';

import '../content/app_settings.dart';

/// Altyazının görünümü (Ayarlar › Altyazı): oynatıcı (media_kit altyazı
/// görünümü) ve ayardaki örnek aynı hesabı kullanır. Değerler 1280x720
/// referansındadır; oynatıcı küçük ekranda oranla küçültür.
abstract final class SubtitleLook {
  static TextStyle style(AppSettings s) {
    final background = s.subtitleBackground;
    return TextStyle(
      height: 1.4,
      fontSize: s.subtitleSize.fontSize,
      color: Color(s.subtitleColor.argb),
      fontWeight: s.subtitleBold ? FontWeight.w700 : FontWeight.w500,
      backgroundColor: Color(background.argb),
      // Arka plansızken gölge: açık sahnede de okunur.
      shadows: background == SubtitleBackground.none
          ? const [
              Shadow(color: Color(0xFF000000), blurRadius: 4),
              Shadow(color: Color(0xFF000000), offset: Offset(1.5, 1.5), blurRadius: 2),
            ]
          : null,
    );
  }

  static EdgeInsets padding(AppSettings s) => EdgeInsets.fromLTRB(16, 0, 16, s.subtitlePosition.margin);
}
