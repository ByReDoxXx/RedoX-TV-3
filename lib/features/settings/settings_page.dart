import 'package:flutter/material.dart';

import '../../core/content/source_receiver.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/redox_icon.dart';
import '../sources/add_source_tab.dart';

/// Ayarların sekmeleri. Kaynak ekleme burada (kullanıcı isteği: "Kaynak
/// ekleme sekmesi Ayarlar altında olsun"; eklenen listeler Kaynaklar
/// bölümünde); yeni ayarlar yeni sekme olur.
enum SettingsTab {
  addSource('Kaynak ekle', RedoxIcons.add);

  const SettingsTab(this.label, this.icon);

  final String label;
  final RedoxIcons icon;
}

/// Ayarlar: başlık, "Ayarlar" başlığı ve sekme çipleri; altta seçili sekme
/// (kendi içinde kayar).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.sources,
    required this.clock,
    required this.profileName,
    this.receiver,
    this.initialTab = SettingsTab.addSource,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final UserSources sources;

  /// Telefondan ekleme alıcısı (testlerde sunucusuz sahtesi).
  final SourceReceiver? receiver;
  final SettingsTab initialTab;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final phone = metrics.formFactor == FormFactor.phone;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: padding.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: AppHeader(
              clock: widget.clock,
              profileName: widget.profileName,
              onHome: widget.onHome,
              onMore: widget.onMore,
              onProfile: widget.onProfile,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, 14, padding.right, 16),
            child: Row(
              children: [
                const RedoxIcon(RedoxIcons.settings, color: RedoxRoles.onSurfaceVariant),
                const SizedBox(width: 10),
                Text('Ayarlar', style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
                const SizedBox(width: 24),
                for (final tab in SettingsTab.values) ...[
                  CategoryChip(label: tab.label, selected: tab == _tab, onPressed: () => setState(() => _tab = tab)),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              SettingsTab.addSource => AddSourceTab(
                sources: widget.sources,
                receiver: widget.receiver,
                padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, phone ? 16 : padding.bottom),
              ),
            },
          ),
        ],
      ),
    );
  }
}
