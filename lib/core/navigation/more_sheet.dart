import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../ui/nav_rail.dart';
import '../ui/redox_icon.dart';

/// Telefonda alt menüye sığmayan bölümler: M3 modal alt sayfa (tutamaklı),
/// her bölüm bir liste satırı. Seçilen satırın dizini [onSelected]'a gider.
Future<void> showMoreSheet(BuildContext context, {required List<NavRailItem> items, ValueChanged<int>? onSelected}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final t = Theme.of(context).textTheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              ListTile(
                leading: RedoxIcon(items[i].icon, color: RedoxRoles.onSurfaceVariant),
                title: Text(items[i].label, style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  onSelected?.call(i);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
