import 'package:flutter/material.dart';

import '../../../core/content/favorites.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/playback/radio_controller.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';

/// Radyo seçenekleri (eski uygulamadaki panelin uyarlaması): favori, yayın
/// kaynağı (n/m), uyku zamanlayıcısı (Kapalı → 30 → 60 → 90 dk) ve radyoyu
/// kapat. TV/tablette sağda yan panel, telefonda alt sayfa. "Radyoyu kapat"
/// seçilirse true döner (oynatıcı da kapanır).
Future<bool?> showRadioOptions(BuildContext context, {required RadioController radio, Favorites? favorites}) {
  final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
  final panel = RadioOptions(radio: radio, favorites: favorites);
  if (phone) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (_) => SafeArea(child: panel),
    );
  }
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: const Color(0x99000000),
    pageBuilder: (_, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: RedoxRoles.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(RedoxRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: 380, child: panel),
        ),
      ),
    ),
  );
}

class RadioOptions extends StatelessWidget {
  const RadioOptions({super.key, required this.radio, this.favorites});

  final RadioController radio;
  final Favorites? favorites;

  static String sleepLabel(Duration? left) => switch (left) {
    null => 'Kapalı',
    final d => '${(d.inSeconds / 60).ceil()} dk',
  };

  /// Sıradaki uyku süresi: Kapalı → 30 → 60 → 90 → Kapalı.
  static int? nextSleep(Duration? left) {
    if (left == null) return RadioController.sleepChoices.first;
    final m = (left.inSeconds / 60).ceil();
    return RadioController.sleepChoices.where((c) => c > m).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([radio, ?favorites]),
      builder: (context, _) {
        final station = radio.current;
        final fav = station != null && (favorites?.hasRadio(station.number) ?? false);
        final (n, m) = radio.streamPosition;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Seçenekler', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
              ),
              if (station != null && favorites != null)
                _Item(
                  icon: RedoxIcons.favorites,
                  filled: fav,
                  label: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  autofocus: true,
                  onPressed: () => favorites!.toggleRadio(station.number),
                ),
              if (station != null)
                _Item(
                  icon: RedoxIcons.sync,
                  label: 'Yayın kaynağı',
                  value: m == 0 ? '—' : '$n / $m',
                  onPressed: m < 2 ? null : radio.switchStream,
                ),
              _Item(
                icon: RedoxIcons.clock,
                label: 'Uyku zamanlayıcı',
                value: sleepLabel(radio.sleepLeft),
                autofocus: station == null || favorites == null,
                onPressed: () => radio.setSleep(nextSleep(radio.sleepLeft)),
              ),
              _Item(
                icon: RedoxIcons.volume,
                label: 'Radyo cızırtısı',
                value: radio.noise ? 'Açık' : 'Kapalı',
                onPressed: () => radio.noise = !radio.noise,
              ),
              const Divider(height: 16, indent: 20, endIndent: 20, color: RedoxRoles.outlineVariant),
              _Item(
                icon: RedoxIcons.close,
                label: 'Radyoyu kapat',
                danger: true,
                onPressed: () async {
                  await radio.stop();
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    this.value,
    this.onPressed,
    this.filled = false,
    this.danger = false,
    this.autofocus = false,
  });

  final RedoxIcons icon;
  final String label;
  final String? value;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final fg = danger ? RedoxSeeds.amber : RedoxRoles.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: FocusGlow(
        borderRadius: radius,
        scale: 1,
        builder: (context, active) => Material(
          color: active ? RedoxRoles.surfaceContainerHighest : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onPressed,
            autofocus: autofocus,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Opacity(
              opacity: onPressed == null ? 0.5 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    RedoxIcon(icon, filled: filled, color: danger ? RedoxSeeds.amber : RedoxSeeds.gold, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label, style: t.titleMedium!.copyWith(color: fg)),
                    ),
                    if (value != null)
                      Text(
                        value!,
                        style: t.labelLarge!.copyWith(color: RedoxSeeds.amber, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
