import 'package:flutter/material.dart';

import '../layout/form_factor.dart';
import '../theme/redox_metrics.dart';
import 'redox_buttons.dart';
import 'redox_icon.dart';

/// Masaüstünde açılan sayfanın geri düğmesi: Windows ve Linux'ta sistem Geri
/// tuşu yok, fareyle gelen kullanıcı sayfadan başka türlü çıkamıyordu. Diğer
/// cihazlarda yer kaplamaz (Geri kumandada ya da sistem çubuğunda).
class DesktopBackButton extends StatelessWidget {
  const DesktopBackButton({super.key, this.gap = 0});

  /// Satır içinde düğmeden sonraki boşluk.
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).extension<RedoxMetrics>()?.formFactor != FormFactor.desktop) return const SizedBox.shrink();
    final button = GlassButton(
      label: 'Geri',
      icon: RedoxIcons.back,
      iconOnly: true,
      onPressed: () => Navigator.of(context).maybePop(),
    );
    return gap == 0
        ? button
        : Padding(
            padding: EdgeInsets.only(right: gap),
            child: button,
          );
  }
}
