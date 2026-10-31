import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import 'redox_icon.dart';

/// Logosu veya afişi olmayan içerik için yer tutucu görsel: adın baş harfleri
/// ve sağ üstte soluk ikon, addan türetilen sabit bir tohum renginde degrade
/// üstünde. İkon sağ üsttedir: kartların başlığı ve numarası alt kenardadır.
class ArtworkFallback extends StatelessWidget {
  const ArtworkFallback({
    super.key,
    required this.name,
    this.icon,
    this.showInitials = true,
    this.initialsScale = 0.28,
  });

  /// Baş harflerin boyu, alanın kısa kenarına oranla (logo karosunda büyük).
  final double initialsScale;

  final String name;
  final RedoxIcons? icon;
  final bool showInitials;

  static const _tints = [RedoxSeeds.crimson, RedoxSeeds.amber, RedoxSeeds.gold, RedoxRoles.outline];

  /// Çalıştırmalar arası sabit: karakter kodlarının toplamı (String.hashCode
  /// sürümler arasında değişebilir).
  Color get _tint => _tints[name.codeUnits.fold(0, (a, b) => a + b) % _tints.length];

  /// İlk iki kelimenin baş harfi, Türkçe büyük harf kuralıyla (i → İ, ı → I).
  String get _initials {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w.characters.first).join();
    return letters.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tint;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: 0.45), RedoxRoles.surfaceContainerHigh),
            RedoxRoles.surfaceContainerLowest,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final s = box.biggest.shortestSide;
          return Stack(
            children: [
              if (icon != null)
                Positioned(
                  right: s * 0.08,
                  top: s * 0.08,
                  child: Opacity(
                    opacity: 0.22,
                    child: RedoxIcon(icon!, filled: true, color: Colors.white, size: s * 0.3),
                  ),
                ),
              if (showInitials)
                Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontSize: s * initialsScale,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
