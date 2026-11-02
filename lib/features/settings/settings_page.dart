import 'package:flutter/material.dart';

import '../../core/content/app_settings.dart';
import '../../core/content/profiles.dart';
import '../../core/content/song_history.dart';
import '../../core/content/source_receiver.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/user_sources.dart';
import '../../core/content/watch_history.dart';
import '../../core/layout/form_factor.dart';
import '../../core/navigation/double_back_to_exit.dart';
import '../../core/layout/page_layout.dart';
import '../../core/remote/remote_host.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/hiding_header.dart';
import '../../core/ui/redox_icon.dart';
import '../sources/add_source_tab.dart';
import '../tv/tv_guide_controller.dart';
import 'sections/about_settings.dart';
import 'sections/appearance_settings.dart';
import 'sections/data_settings.dart';
import 'sections/parental_settings.dart';
import 'sections/player_settings.dart';
import 'sections/remote_settings.dart';
import 'sections/startup_settings.dart';

/// Ayarların bölümleri (kullanıcı isteği: "Ayarlar sayfası çok düzensiz ve
/// ekstra ne ekleyebiliriz" › hepsi).
enum SettingsSection {
  addSource('Kaynak ekle', 'M3U, Xtream, portal, dosya, telefon', RedoxIcons.add),
  player('Oynatıcı', 'Kalite, ölçek, ses, hareketler', RedoxIcons.tune),
  appearance('Görünüm', 'Yazı boyutu, OLED modu', RedoxIcons.textSize),
  startup('Açılış', 'Profil sorusu ve ilk sayfa', RedoxIcons.home),
  parental('Ebeveyn denetimi', 'PIN ve kilitli içerik', RedoxIcons.lock),
  remote('Telefon kumandası', 'Ad ve eşleşmiş telefonlar', RedoxIcons.remote),
  data('Veriler', 'Temizle, yedekle, geri yükle', RedoxIcons.database),
  about('Hakkında', 'Sürüm, güncelleme, tanılama', RedoxIcons.info);

  const SettingsSection(this.label, this.summary, this.icon);

  final String label;
  final String summary;
  final RedoxIcons icon;
}

/// Ayarlar. TV ve tablette solda bölümler, sağda seçili bölüm; telefonda
/// bölüm listesi, dokununca bölüm açılır (Geri listeye döner).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.sources,
    required this.clock,
    required this.profileName,
    this.receiver,
    this.profiles,
    this.settings,
    this.history,
    this.songs,
    this.tmdb,
    this.remote,
    this.guide,
    this.channelName,
    this.initialSection,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final UserSources sources;

  /// Telefondan ekleme alıcısı (testlerde sunucusuz sahtesi).
  final SourceReceiver? receiver;

  /// Profiller ve ebeveyn PIN'i; null ise Ebeveyn denetimi yok.
  final ProfileStore? profiles;

  /// Uygulama ayarları; null ise AppSettings.instance.
  final AppSettings? settings;
  final WatchHistory? history;
  final SongHistory? songs;
  final Tmdb? tmdb;

  /// TV'de kumanda sunucusu; null ise Telefon kumandası bölümü yok.
  final RemoteHost? remote;
  final TvGuideController? guide;
  final String? Function(int number)? channelName;

  /// Açılınca gösterilen bölüm; null ise telefonda liste, TV'de ilk bölüm.
  final SettingsSection? initialSection;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsSection? _open = widget.initialSection;

  List<SettingsSection> get _sections => [
    for (final s in SettingsSection.values)
      if ((s != SettingsSection.parental || widget.profiles != null) &&
          (s != SettingsSection.remote || widget.remote != null))
        s,
  ];

  Widget _content(SettingsSection section, EdgeInsets padding) {
    final settings = widget.settings ?? AppSettings.instance;
    return switch (section) {
      SettingsSection.addSource => AddSourceTab(sources: widget.sources, receiver: widget.receiver, padding: padding),
      SettingsSection.player => PlayerSettings(settings: settings, padding: padding),
      SettingsSection.appearance => AppearanceSettings(settings: settings, padding: padding),
      SettingsSection.startup => StartupSettings(settings: settings, padding: padding),
      SettingsSection.parental => ParentalSettings(
        store: widget.profiles!,
        sources: widget.sources,
        channelName: widget.channelName,
        padding: padding,
      ),
      SettingsSection.remote => RemoteSettings(host: widget.remote!, padding: padding),
      SettingsSection.data => DataSettings(
        sources: widget.sources,
        history: widget.history,
        songs: widget.songs,
        tmdb: widget.tmdb,
        padding: padding,
      ),
      SettingsSection.about => AboutSettings(sources: widget.sources, guide: widget.guide, padding: padding),
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final phone = metrics.formFactor == FormFactor.phone;
    final header = Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: AppHeader(
        clock: widget.clock,
        profileName: widget.profileName,
        onHome: widget.onHome,
        onMore: widget.onMore,
        onProfile: widget.onProfile,
      ),
    );
    if (phone) {
      final open = _open;
      final inset = EdgeInsets.fromLTRB(padding.left, 4, padding.right, 16);
      return BackInterceptor(
        active: open != null,
        onBack: () => setState(() => _open = null),
        child: Padding(
          // Başlık saatin altına yaslı; aşağı kaydırınca gizlenir.
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: HidingHeader(
            header: header,
            child: open == null
                ? ListView(
                    padding: inset,
                    children: [
                      const _Title(),
                      for (final (i, s) in _sections.indexed)
                        _SectionRow(section: s, autofocus: i == 0, onPressed: () => setState(() => _open = s)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 8),
                        child: _SectionRow.back(onPressed: () => setState(() => _open = null)),
                      ),
                      Expanded(child: _content(open, inset)),
                    ],
                  ),
          ),
        ),
      );
    }
    final current = _open != null && _sections.contains(_open) ? _open! : _sections.first;
    return Padding(
      padding: EdgeInsets.only(top: padding.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 16, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 280,
                    child: ListView(
                      padding: EdgeInsets.only(bottom: padding.bottom),
                      children: [
                        const _Title(),
                        for (final (i, s) in _sections.indexed)
                          _SectionRow(
                            section: s,
                            selected: s == current,
                            autofocus: i == 0,
                            onPressed: () => setState(() => _open = s),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(current),
                      child: _content(current, EdgeInsets.fromLTRB(0, 4, padding.right, padding.bottom)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const RedoxIcon(RedoxIcons.settings, color: RedoxRoles.onSurfaceVariant),
          const SizedBox(width: 10),
          Text('Ayarlar', style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
        ],
      ),
    );
  }
}

/// Bölüm satırı: ikon, ad ve kısa açıklama; seçiliyken kızıl kenar.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required SettingsSection this.section,
    required this.onPressed,
    this.selected = false,
    this.autofocus = false,
  });

  const _SectionRow.back({required this.onPressed}) : section = null, selected = false, autofocus = true;

  /// null: telefonda bölümden listeye dönüş satırı.
  final SettingsSection? section;
  final VoidCallback onPressed;
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final s = section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusGlow(
        borderRadius: radius,
        scale: 1,
        builder: (context, active) => Material(
          color: active || selected ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: selected ? const BorderSide(color: RedoxRoles.primaryContainer, width: 2) : BorderSide.none,
          ),
          child: InkWell(
            onTap: onPressed,
            autofocus: autofocus,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  RedoxIcon(s?.icon ?? RedoxIcons.back, color: RedoxSeeds.gold, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s?.label ?? 'Ayarlar',
                          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                        ),
                        if (s != null)
                          Text(
                            s.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (s != null) const RedoxIcon(RedoxIcons.chevronRight, color: RedoxRoles.onSurfaceVariant, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
