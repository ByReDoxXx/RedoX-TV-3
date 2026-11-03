import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/favorites.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/hiding_header.dart';
import '../../core/ui/app_header.dart';
import '../locks/lock_scope.dart';
import 'source_channels_page.dart';
import 'widgets/source_widgets.dart';

/// Kaynaklar: kullanıcının eklediği listeler (eski "Özel M3U"). Her liste bir
/// klasördür; içine girince kanalları, OK tam ekran. Ekleme Ayarlar > Kaynak
/// ekle sekmesindedir (kullanıcı isteği); ilk kart "Kaynak ekle" oraya
/// götürür. Üstte türe göre süzme (Tümü, Canlı TV, Film, Dizi); kartlarda
/// ekleme yolu, kayıt sayısı ve son güncelleme.
class SourcesPage extends StatefulWidget {
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
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  /// Süzgeç; null: Tümü.
  SourceKind? _kind;

  UserSources get _sources => widget.sources;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final phone = metrics.formFactor == FormFactor.phone;
    final t = Theme.of(context).textTheme;
    final onAdd = widget.onAdd;
    return ListenableBuilder(
      listenable: _sources,
      builder: (context, _) {
        // Bütün listeler (Canlı TV, Film, Dizi): Film ve Dizi listeleri kendi
        // bölümlerinde de görünür; burada silinince oradan da kalkar.
        final all = [for (final k in SourceKind.values) ..._sources.of(k)];
        final kinds = [
          for (final k in SourceKind.values)
            if (_sources.of(k).isNotEmpty) k,
        ];
        // Süzülen tür kalmadıysa (silindi) Tümü.
        final kind = kinds.contains(_kind) ? _kind : null;
        final items = kind == null ? all : _sources.of(kind);
        final header = AppHeader(
          clock: widget.clock,
          profileName: widget.profileName,
          onHome: widget.onHome,
          onMore: widget.onMore,
          onProfile: widget.onProfile,
        );
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: 'Listelerim',
              trailing: Text(
                '${all.length} liste · ${_sources.channelCount} kayıt',
                style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
              ),
            ),
            if (kinds.length > 1) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  CategoryChip(
                    label: 'Tümü',
                    count: all.length,
                    selected: kind == null,
                    onPressed: () => setState(() => _kind = null),
                  ),
                  for (final k in kinds)
                    CategoryChip(
                      label: k.label,
                      count: _sources.of(k).length,
                      selected: kind == k,
                      onPressed: () => setState(() => _kind = k),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (all.isEmpty) ...[
              Text(
                "Henüz liste yok. Ayarlar > Kaynak ekle'den M3U, JSON, HTML, Xtream, portal, dosya, USB/SSD klasörü "
                'ya da telefonla ekleyin; her liste burada bir klasör olur.',
                style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ],
            TileGrid(
              columns: phone ? 1 : 3,
              minWidth: phone ? 0 : 230,
              children: [
                if (onAdd != null) AddSourceCard(onPressed: onAdd, autofocus: all.isEmpty),
                for (final (i, s) in items.indexed)
                  FolderCard(source: s, autofocus: i == 0, onPressed: () => _open(context, s)),
              ],
            ),
          ],
        );
        // Telefonda başlık üstte; aşağı kaydırınca gizlenir, yukarı kaydırınca
        // geri gelir (kullanıcı isteği). TV/tablette içerikle kayar.
        if (phone) {
          return Padding(
            // Telefonda başlık durum çubuğuna (saatin altına) yaslı (kullanıcı isteği).
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: HidingHeader(
              header: Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: header,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(padding.left, 6, padding.right, 16),
                child: body,
              ),
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
    final page = SourceChannelsPage(sources: _sources, source: s, onWatch: widget.onWatch, favorites: widget.favorites);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Yeni rota kabuğun altında değil: kilit kapsamı taşınır.
        builder: (_) => gate == null ? page : LockScope(locks: gate.locks, profiles: gate.profiles, child: page),
      ),
    );
  }
}
