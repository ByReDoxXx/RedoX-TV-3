import 'package:flutter/material.dart';

import '../../core/remote/remote_host.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/ui/redox_icon.dart';

/// TV: telefon eşleşmek isteyince ekranın sağ üstünde 4 haneli kod. Uygulama
/// düzeyindedir (MaterialApp.builder): oynatıcı açıkken de görünür. Odak
/// almaz; kod girilince ya da süresi dolunca kaybolur.
class PairingOverlay extends StatelessWidget {
  const PairingOverlay({super.key, required this.host, required this.child});

  final RemoteHost host;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Stack(
      children: [
        child,
        ValueListenableBuilder(
          valueListenable: host.pairingCode,
          builder: (context, code, _) => code == null
              ? const SizedBox.shrink()
              : Positioned(
                  top: 32,
                  right: 32,
                  child: ExcludeFocus(
                    child: Material(
                      color: RedoxRoles.surfaceContainerHigh,
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: const BorderSide(color: RedoxRoles.primaryContainer, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 28, 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RedoxIcon(RedoxIcons.remote, size: 40, color: RedoxRoles.primary),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Telefon kumandası',
                                  style: t.titleMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  code.split('').join(' '),
                                  style: t.displaySmall!.copyWith(
                                    color: RedoxRoles.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  'Bu kodu telefona girin',
                                  style: t.bodyMedium!.copyWith(color: RedoxRoles.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
