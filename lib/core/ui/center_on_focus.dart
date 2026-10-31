import 'package:flutter/widgets.dart';

/// Alt ağaçtaki öğe D-pad/klavye ile odak alınca onu kayma alanının ortasına
/// getirir. Varsayılan odak kaydırması öğeyi kenara yaslıyordu: büyüyen kart
/// ve odak halkası kayma alanının kenarında kesiliyordu (gerçek TV'de
/// görüldü). Dokunmatikte (odak vurgusu gizliyken) kaydırmaz.
class CenterOnFocus extends StatelessWidget {
  const CenterOnFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onFocusChange: (focused) {
      if (!focused || FocusManager.instance.highlightMode != FocusHighlightMode.traditional) return;
      // Varsayılan kaydırmadan sonra (aynı karede o da çalışır).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      });
    },
    child: child,
  );
}
