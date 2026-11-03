import 'package:flutter/material.dart';

import '../layout/form_factor.dart';

// Yazı tipi: Sora (OFL), değişken wght 100–800. Kaynak: DESIGN.md "typography".
// Doğrulandı (fontTools): Türkçe harfler tam, `tnum` var (rakamlar 676 birim);
// "₺" ve "→" glifleri yok (görünen metinde kullanılmaz).
// letterSpacing em cinsinden verilmiştir; Flutter mantıksal piksel ister:
// izleme = em × fontSize.

abstract final class RedoxType {
  static const family = 'Sora';

  /// Saat, kanal numarası, süre, EPG saatleri: sabit genişlikli rakam (Sora tnum).
  static const tabular = [FontFeature.tabularFigures()];

  /// TV'de izin verilen en küçük yazı: title-md (16).
  static const double tvMinSize = 16;

  static const displayLg = TextStyle(
    fontFamily: family,
    fontSize: 56,
    height: 64 / 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.02 * 56,
  );
  static const displayLgMobile = TextStyle(
    fontFamily: family,
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.02 * 36,
  );
  static const headlineLg = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.01 * 32,
  );
  static const headlineLgMobile = TextStyle(
    fontFamily: family,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.01 * 26,
  );
  static const headlineMd = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const headlineSm = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const titleLg = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.01 * 18,
  );
  static const titleMd = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.01 * 16,
  );
  static const bodyLg = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.01 * 16,
  );
  static const bodyMd = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.015 * 14,
  );
  static const bodySm = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.02 * 12,
  );
  static const labelLg = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05 * 14,
  );
  static const labelMd = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.04 * 12,
  );
  static const labelSm = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.06 * 10,
  );

  /// Spec belirteçleri adlarıyla (rehber ve testler için).
  static const tokens = <String, TextStyle>{
    'display-lg': displayLg,
    'display-lg-mobile': displayLgMobile,
    'headline-lg': headlineLg,
    'headline-lg-mobile': headlineLgMobile,
    'headline-md': headlineMd,
    'headline-sm': headlineSm,
    'title-lg': titleLg,
    'title-md': titleMd,
    'body-lg': bodyLg,
    'body-md': bodyMd,
    'body-sm': bodySm,
    'label-lg': labelLg,
    'label-md': labelMd,
    'label-sm': labelSm,
  };

  /// M3 yuvalarına eşleme. Spec'te karşılığı olmayan displayMedium,
  /// displaySmall ve titleSmall boş bırakılır; Flutter bunları M3 tabanından
  /// doldurur (aile yine Sora). Telefonda -mobile belirteçleri kullanılır;
  /// TV'de 16'dan küçük yazılar 16'ya yükseltilir.
  static TextTheme textTheme(FormFactor formFactor) {
    final phone = formFactor == FormFactor.phone;
    final theme = TextTheme(
      displayLarge: phone ? displayLgMobile : displayLg,
      headlineLarge: phone ? headlineLgMobile : headlineLg,
      headlineMedium: headlineMd,
      headlineSmall: headlineSm,
      titleLarge: titleLg,
      titleMedium: titleMd,
      bodyLarge: bodyLg,
      bodyMedium: bodyMd,
      bodySmall: bodySm,
      labelLarge: labelLg,
      labelMedium: labelMd,
      labelSmall: labelSm,
    );
    if (formFactor != FormFactor.tv) return theme;
    return theme.copyWith(
      bodyMedium: forTv(bodyMd),
      bodySmall: forTv(bodySm),
      labelLarge: forTv(labelLg),
      labelMedium: forTv(labelMd),
      labelSmall: forTv(labelSm),
    );
  }

  /// TV alt sınırı: boyut 16'ya, satır title-md'nin satırına çıkar; ağırlık ve
  /// em cinsinden izleme korunur.
  static TextStyle forTv(TextStyle s) {
    if (s.fontSize! >= tvMinSize) return s;
    return s.copyWith(
      fontSize: tvMinSize,
      height: titleMd.height,
      letterSpacing: s.letterSpacing! / s.fontSize! * tvMinSize,
    );
  }
}
