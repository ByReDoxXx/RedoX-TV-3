import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'artwork_fallback.dart';

/// Kanal logosu alanı: sade zeminde ortalanmış logo karosu. Logo adresi yoksa
/// veya yüklenemezse baş harfli yer tutucu (ArtworkFallback) çizilir. Program
/// görseli değildir: kartlarda kanal kimliği öne çıksın diye.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.name, this.logoUrl, this.size = 0.5, this.alignment = Alignment.center});

  final String name;
  final String? logoUrl;

  /// Karonun kenarı, alanın kısa kenarına oranla.
  final double size;

  /// Karonun alandaki yeri.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RedoxRadius.md);
    Widget fallback() => ClipRRect(
      borderRadius: radius,
      child: ArtworkFallback(name: name, initialsScale: 0.4),
    );
    return ColoredBox(
      color: RedoxRoles.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.biggest.shortestSide * size;
          final url = logoUrl;
          return Align(
            alignment: alignment,
            child: SizedBox.square(
              dimension: side,
              child: url == null
                  ? fallback()
                  : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback()),
            ),
          );
        },
      ),
    );
  }
}
