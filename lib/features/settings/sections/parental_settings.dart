import 'package:flutter/material.dart';

import '../../../core/content/profiles.dart';
import '../../../core/content/user_sources.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../locks/lock_scope.dart';
import '../parent_pin_tab.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Ebeveyn denetimi: PIN ve kilitli içeriklerin listesi (kilit
/// buradan da kalkar; PIN sorulur).
class ParentalSettings extends StatelessWidget {
  const ParentalSettings({
    super.key,
    required this.store,
    required this.sources,
    this.channelName,
    this.padding = EdgeInsets.zero,
  });

  final ProfileStore store;
  final UserSources sources;

  /// TV kanalının adı (numarasından); yoksa "Kanal N".
  final String? Function(int number)? channelName;
  final EdgeInsets padding;

  /// Kilit anahtarının okunur adı.
  String _label(String key) {
    if (key.startsWith('kanal:')) {
      final n = int.tryParse(key.substring(6)) ?? 0;
      final name = channelName?.call(n);
      return name == null ? 'Kanal $n' : 'Kanal $n · $name';
    }
    if (key.startsWith('klasor:')) {
      final parts = key.substring(7).split('/').where((p) => p.isNotEmpty).toList();
      final source = sources.items.where((s) => s.id == parts.firstOrNull).firstOrNull?.name ?? 'Silinmiş liste';
      return [source, ...parts.skip(1)].join(' › ');
    }
    if (key.startsWith('kayit:')) {
      final url = key.substring(6);
      final last = Uri.tryParse(url)?.pathSegments.where((p) => p.isNotEmpty).lastOrNull;
      return 'Kayıt · ${last ?? url}';
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scope = LockScope.maybeOf(context);
    final locked = (scope?.locks.locked ?? const <String>{}).toList()..sort();
    return SettingsBody(
      title: 'Ebeveyn denetimi',
      padding: padding,
      children: [
        SettingTile(
          title: "Ebeveyn PIN'i",
          child: ParentPinTab(store: store),
        ),
        SettingTile(
          title: 'Kilitli içerik',
          description: locked.isEmpty
              ? 'Kilitli kanal ya da klasör yok. Kanal önizlemesindeki ve klasör satırlarındaki kilit düğmesiyle kilitlenir.'
              : 'Açmak PIN ister; kilit kalkınca bütün profillerde açılır.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final key in locked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const RedoxIcon(RedoxIcons.lock, size: 20, color: RedoxSeeds.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _label(key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface),
                        ),
                      ),
                      GlassButton(
                        label: 'Kilidi kaldır',
                        icon: RedoxIcons.close,
                        onPressed: scope == null ? null : () => scope.toggle(context, key),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
