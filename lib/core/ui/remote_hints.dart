import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'redox_icon.dart';

/// Kumandada bir tuş ve yaptığı iş. Tuş ya ikon (yön tuşları, geri) ya da
/// yazılı tuş adıdır ("OK"). Renkli tuş (kırmızı/yeşil/sarı/mavi) kullanılmaz:
/// Chromecast 4K gibi kumandalarda yoktur.
class RemoteHint {
  const RemoteHint.icon(RedoxIcons this.icon, this.action) : key = null;
  const RemoteHint.key(String this.key, this.action) : icon = null;

  final RedoxIcons? icon;
  final String? key;
  final String action;
}

/// TV'de ekranın altında, kumandayla neler yapılabileceğini gösteren şerit
/// (kullanıcı isteği). Yalnızca TV biçiminde gösterilir; karar çağırandadır.
class RemoteHintBar extends StatelessWidget {
  const RemoteHintBar({super.key, required this.hints});

  /// Anasayfa ve genel gezinme için varsayılan ipuçları.
  static const browse = [
    RemoteHint.icon(RedoxIcons.dpad, 'Gezin'),
    RemoteHint.key('OK', 'Seç'),
    RemoteHint.icon(RedoxIcons.back, 'Geri'),
  ];

  final List<RemoteHint> hints;

  @override
  Widget build(BuildContext context) {
    // İnce şerit: TV'de yazı 16'nın altına inemez; incelik boşluk, ikon ve
    // yazı kalınlığından gelir.
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: RedoxRoles.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.2);
    return Semantics(
      container: true,
      label: 'Kumanda: ${hints.map((h) => '${h.key ?? h.icon!.label} ${h.action}').join(', ')}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: RedoxRoles.surfaceContainer.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(RedoxRadius.full),
          border: Border.all(color: RedoxAccent.ghostBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < hints.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                if (hints[i].icon != null)
                  RedoxIcon(hints[i].icon!, color: RedoxRoles.tertiary, size: 18)
                else
                  // Şeritte ince tuş etiketi: çerçeve, dolgu yok.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: RedoxRoles.tertiary.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(RedoxRadius.xs),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(hints[i].key!, style: style.copyWith(color: RedoxRoles.tertiary)),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(hints[i].action, style: style),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
