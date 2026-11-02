import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/favorites.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../locks/lock_scope.dart';
import 'source_channels_page.dart';
import 'widgets/source_widgets.dart';

/// Kaynaklar: kullanıcının eklediği listeler (eski "Özel M3U"). Her liste bir
/// klasördür; içine girince kanalları, OK tam ekran. Ekleme Ayarlar > Kaynak
/// ekle sekmesindedir (kullanıcı isteği); "Kaynak ekle" düğmesi oraya götürür.
class SourcesPage extends StatelessWidget {
  const SourcesPage({
    super.key,
    required this.sources,
    this.favorites,
    required this.clock,
    required this.profileName,
    this.onWatch,
    this.onAdd,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final UserSources sources;

  /// Kaynaktaki kayıtlarda yıldız (Favoriler › Kaynaklar).
  final Favorites? favorites;

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
        // Bütün listeler (Canlı TV, Film, Dizi): Film ve Dizi listeleri kendi
        // bölümlerinde de görünür; burada silinince oradan da kalkar.
        final items = [for (final k in SourceKind.values) ...sources.of(k)];
        final header = AppHeader(
          clock: clock,
          profileName: profileName,
          onHome: onHome,
          onMore: onMore,
          onProfile: onProfile,
        );
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: 'Listelerim',
              trailing: Text(
                '${items.length} liste · ${sources.channelCount} kayıt',
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
        );
        // Telefonda başlık üstte sabit (kullanıcı isteği); TV/tablette içerikle kayar.
        if (phone) {
          return Padding(
            padding: EdgeInsets.only(top: padding.top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: padding.left, right: padding.right),
                  child: header,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(padding.left, 18, padding.right, 16),
                    child: body,
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, const SizedBox(height: 18), body],
          ),
        );
      },
    );
  }

  /// Kilitli kaynak PIN ister.
  Future<void> _open(BuildContext context, UserSource s) async {
    final gate = LockScope.maybeOf(context);
    if (gate?.locks.folderLock(s.id, const []) case final key?) {
      if (!await gate!.pass(context, key)) return;
    }
    if (!context.mounted) return;
    final page = SourceChannelsPage(sources: sources, source: s, onWatch: onWatch, favorites: favorites);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Yeni rota kabuğun altında değil: kilit kapsamı taşınır.
        builder: (_) => gate == null ? page : LockScope(locks: gate.locks, profiles: gate.profiles, child: page),
      ),
    );
  }
}
