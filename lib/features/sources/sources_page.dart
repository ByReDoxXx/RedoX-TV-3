import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import 'source_channels_page.dart';
import 'widgets/source_widgets.dart';

/// Kaynaklar: kullanıcının eklediği listeler (eski "Özel M3U"). Her liste bir
/// klasördür; içine girince kanalları, OK tam ekran. Ekleme Ayarlar > Kaynak
/// ekle sekmesindedir (kullanıcı isteği); "Kaynak ekle" düğmesi oraya götürür.
class SourcesPage extends StatelessWidget {
  const SourcesPage({
    super.key,
    required this.sources,
    required this.clock,
    required this.profileName,
    this.onWatch,
    this.onAdd,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final UserSources sources;

  /// Klasördeki kanalı tam ekran açar.
  final Future<void> Function(List<LiveChannel> channels, int index)? onWatch;

  /// Ayarlar > Kaynak ekle sekmesini açar.
  final VoidCallback? onAdd;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final phone = metrics.formFactor == FormFactor.phone;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: sources,
      builder: (context, _) {
        final items = sources.items;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, phone ? 16 : padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(clock: clock, profileName: profileName, onHome: onHome, onMore: onMore, onProfile: onProfile),
              const SizedBox(height: 18),
              SectionTitle(
                title: 'Listelerim',
                trailing: Text(
                  '${items.length} liste · ${sources.channelCount} kanal',
                  style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text(
                  'Henüz liste yok. Ayarlar > Kaynak ekle\'den M3U, JSON, HTML, Xtream, portal ya da telefonla ekleyin; '
                  'her liste burada bir klasör olur.',
                  style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
                )
              else
                TileGrid(
                  columns: phone ? 1 : 3,
                  children: [
                    for (final (i, s) in items.indexed)
                      FolderCard(source: s, autofocus: i == 0, onPressed: () => _open(context, s)),
                  ],
                ),
              const SizedBox(height: 18),
              if (onAdd != null) GlassButton(label: 'Kaynak ekle', icon: RedoxIcons.add, onPressed: onAdd),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, UserSource s) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SourceChannelsPage(sources: sources, source: s, onWatch: onWatch),
    ),
  );
}
