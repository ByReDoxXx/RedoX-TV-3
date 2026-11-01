import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/source_receiver.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import 'source_channels_page.dart';
import 'widgets/add_url_dialog.dart';

/// Kaynaklar (eski "M3U ve Dosya" ve "Özel M3U" ekranlarının uyarlaması):
/// eklenen her M3U listesi bir klasördür. Solda klasör kartları; sağda ekleme
/// paneli: adresle, dosyadan ve telefondan (QR). Telefonda klasörler altta,
/// QR yok (zaten telefondasınız).
///
/// QR: sayfa açıkken yerel ağda [SourceReceiver] çalışır; telefon QR'daki
/// adresi açıp listeyi gönderir, klasör burada belirir.
class SourcesPage extends StatefulWidget {
  const SourcesPage({
    super.key,
    required this.sources,
    required this.clock,
    required this.profileName,
    this.onWatch,
    this.receiver,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final UserSources sources;

  /// Klasördeki kanalı tam ekran açar.
  final Future<void> Function(List<LiveChannel> channels, int index)? onWatch;

  /// QR alıcısı; null ise [SourceReceiver] kurulur (testlerde verilmez,
  /// sunucu açılmaz).
  final SourceReceiver? receiver;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  /// Sağ panel genişliği (TV/tablet).
  static const panelWidth = 330.0;

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  SourceReceiver? _receiver;
  String? _qr;
  bool _busy = false;

  UserSources get _sources => widget.sources;

  bool get _phone => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_receiver == null && !_phone) unawaited(_startReceiver());
  }

  Future<void> _startReceiver() async {
    final r = _receiver = widget.receiver ?? SourceReceiver(_sources);
    try {
      final url = await r.start();
      if (mounted) setState(() => _qr = url);
    } on Object {
      // Ağ yoksa QR gösterilmez; adres ve dosya kalır.
    }
  }

  @override
  void dispose() {
    unawaited(_receiver?.stop());
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<UserSource> Function() add) async {
    setState(() => _busy = true);
    try {
      final s = await add();
      _toast('"${s.name}" eklendi: ${s.count} kanal.');
    } on SourceException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addUrl() async {
    final r = await showAddUrlDialog(context);
    if (r == null) return;
    await _run(() => _sources.addUrl(r.name, r.url));
  }

  Future<void> _addFile() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles();
    } on Object {
      _toast('Bu cihazda dosya seçici açılamadı. Telefondan QR ile ekleyin.');
      return;
    }
    if (files.isEmpty) return;
    final f = files.first;
    await _run(() async {
      final text = await f.xFile.readAsString();
      return _sources.addText(
        f.name.replaceAll(RegExp(r'\.m3u8?$', caseSensitive: false), ''),
        text,
        origin: SourceOrigin.file,
      );
    });
  }

  Future<void> _open(UserSource s) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SourceChannelsPage(sources: _sources, source: s, onWatch: widget.onWatch),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final phone = _phone;
    return ListenableBuilder(
      listenable: _sources,
      builder: (context, _) {
        final folders = _Folders(sources: _sources.items, onOpen: _open, phone: phone);
        final add = _AddPanel(busy: _busy, qr: phone ? null : _qr, onUrl: _addUrl, onFile: _addFile);
        return Padding(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, phone ? 16 : padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                clock: widget.clock,
                profileName: widget.profileName,
                onHome: widget.onHome,
                onMore: widget.onMore,
                onProfile: widget.onProfile,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: phone
                    ? ListView(children: [add, const SizedBox(height: 20), folders])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: SingleChildScrollView(child: folders)),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: SourcesPage.panelWidth,
                            child: SingleChildScrollView(child: add),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Folders extends StatelessWidget {
  const _Folders({required this.sources, required this.onOpen, required this.phone});

  final List<UserSource> sources;
  final ValueChanged<UserSource> onOpen;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Listelerim', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
        const SizedBox(height: 4),
        Text(
          'Her liste, eklerken verdiğiniz adla bir klasördür.',
          style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        if (sources.isEmpty)
          Text(
            'Henüz liste yok. Sağdaki panelden adres, dosya ya da telefonla ekleyin.',
            style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final cols = phone ? 1 : (box.maxWidth / 200).floor().clamp(1, 4);
              final w = (box.maxWidth - 14 * (cols - 1)) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final (i, s) in sources.indexed)
                    SizedBox(
                      width: w,
                      child: _FolderCard(source: s, autofocus: i == 0, onPressed: () => onOpen(s)),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.source, required this.onPressed, this.autofocus = false});

  final UserSource source;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = source;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return FocusGlow(
      borderRadius: radius,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RedoxSeeds.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RedoxRadius.sm),
                  ),
                  child: const RedoxIcon(RedoxIcons.folder, color: RedoxSeeds.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${s.count} kanal · ${s.origin.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPanel extends StatelessWidget {
  const _AddPanel({required this.busy, required this.onUrl, required this.onFile, this.qr});

  final bool busy;
  final String? qr;
  final VoidCallback onUrl;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        border: Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Liste ekle', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
              if (busy) ...[
                const SizedBox(width: 12),
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: RedoxSeeds.amber),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PrimaryButton(label: 'Adresle', icon: RedoxIcons.sources, onPressed: busy ? null : onUrl),
              GlassButton(label: 'Dosyadan', icon: RedoxIcons.folder, onPressed: busy ? null : onFile),
            ],
          ),
          if (qr case final url?) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(RedoxRadius.md)),
                  child: QrImageView(data: url, size: 120, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Telefonla ekle',
                        style: t.titleMedium!.copyWith(color: RedoxSeeds.amber, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'QR\'ı telefonun kamerasıyla okutun; açılan sayfadan adres yapıştırın ya da dosya seçin.',
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Text('Aynı Wi-Fi ağında olun.', style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
