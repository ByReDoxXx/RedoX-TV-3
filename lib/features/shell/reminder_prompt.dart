import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/epg_program.dart';
import '../../core/content/reminders.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';

/// Vakti gelen hatırlatıcı: üstte kart, "İzle" (odakta) ve "Kapat". Ayrı
/// bir rota olarak açılır: oynatıcının üstünde de çıkar, Geri yalnız kartı
/// kapatır, odak kapanınca önceki yere döner. [timeout] sonra kendiliğinden
/// kapanır. Sonuç: izlenecekse true.
Future<bool> showReminderPrompt(
  BuildContext context,
  Reminder r, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final navigator = Navigator.of(context);
  Route<bool>? route;
  final timer = Timer(timeout, () {
    final shown = route;
    if (shown != null && shown.isActive) navigator.removeRoute(shown);
  });
  route = RawDialogRoute<bool>(
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: const Color(0x66000000),
    pageBuilder: (context, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ReminderCard(reminder: r),
        ),
      ),
    ),
  );
  try {
    return await navigator.push(route) ?? false;
  } finally {
    timer.cancel();
  }
}

class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = reminder;
    final at = EpgProgram.formatClock(r.start.hour * 60 + r.start.minute);
    return Material(
      color: RedoxRoles.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(RedoxRadius.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const RedoxIcon(RedoxIcons.notifications, color: RedoxRoles.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Text('$at · ${r.channelName}', style: t.labelLarge!.copyWith(color: RedoxRoles.tertiary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${r.title} başlıyor',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  PrimaryButton(
                    label: 'İzle',
                    icon: RedoxIcons.play,
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  GlassButton(
                    label: 'Kapat',
                    icon: RedoxIcons.close,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
