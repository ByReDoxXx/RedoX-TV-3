import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/content/source_receiver.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_icon.dart';
import 'widgets/phone_qr_dialog.dart';
import 'widgets/source_form_dialog.dart';
import 'widgets/source_widgets.dart';

/// Ekleme yöntemi (kutu).
enum AddMethod {
  m3u('M3U / M3U8', 'Liste adresi', RedoxIcons.link),
  json('JSON', 'Kanal listesi adresi', RedoxIcons.json),
  html('HTML', 'Sayfadaki yayınlar', RedoxIcons.html),
  xtream('Xtream', 'Sunucu ve hesap', RedoxIcons.profile),
  portal('MAC / STB Portal', 'Portal ve MAC', RedoxIcons.portal),
  mediaHub('MediaHub (mHub)', 'Açık eklenti', RedoxIcons.plugin),
  bulk('Toplu (GitHub)', 'Klasördeki listeler', RedoxIcons.bulkAdd),
  file('Dosyadan', 'Cihazdaki M3U/JSON', RedoxIcons.uploadFile),
  phone('Telefondan', 'QR ile gönder', RedoxIcons.qrCode);

  const AddMethod(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final RedoxIcons icon;
}

/// Ayarlar > Kaynak ekle sekmesi (kullanıcı isteği: kaynak ekleme Ayarlar
/// altında; eklenen listeler Kaynaklar bölümünde). Eski "M3U ve Dosya"
/// ekranının uyarlaması: ekleme yöntemleri kutu olarak. Telefondan ekleme ayrı
/// pencerede (QR ve yerel sunucu yalnız o açıkken); telefonda "Telefondan"
/// kutusu yoktur.
class AddSourceTab extends StatefulWidget {
  const AddSourceTab({super.key, required this.sources, this.receiver, this.padding = EdgeInsets.zero});

  final UserSources sources;

  /// Telefondan ekleme alıcısı; null ise pencere [SourceReceiver] kurar
  /// (testlerde sunucusuz sahtesi verilir).
  final SourceReceiver? receiver;

  /// Kayma alanının iç payı (sayfa kenarları).
  final EdgeInsets padding;

  @override
  State<AddSourceTab> createState() => _AddSourceTabState();
}

class _AddSourceTabState extends State<AddSourceTab> {
  bool _busy = false;

  UserSources get _sources => widget.sources;

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  /// Eklemeyi çalıştırır; sonucu ileti olarak gösterir.
  Future<void> _run(Future<String> Function() add) async {
    setState(() => _busy = true);
    try {
      _toast(await add());
    } on SourceException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _added(UserSource s) => '"${s.name}" eklendi: ${s.count} kanal.';

  static const _name = FormFieldSpec('name', 'Ad', required: false, hint: 'Örn. Spor listem');

  Future<void> _choose(AddMethod m) async {
    switch (m) {
      case AddMethod.m3u || AddMethod.json || AddMethod.html:
        final r = await showSourceForm(
          context,
          title: '${m.title} ile ekle',
          description: switch (m) {
            AddMethod.json => 'Kanalları içeren JSON adresi (ad, adres, logo, kategori alanları).',
            AddMethod.html => 'Yayın bağlantıları (.m3u8, .ts, .mpd) içeren sayfanın adresi.',
            _ => 'M3U ya da M3U8 liste adresi.',
          },
          fields: const [
            FormFieldSpec('url', 'Adres', kind: FieldKind.url, hint: 'https://…'),
            _name,
          ],
        );
        if (r == null) return;
        final origin = switch (m) {
          AddMethod.json => SourceOrigin.json,
          AddMethod.html => SourceOrigin.html,
          _ => SourceOrigin.url,
        };
        await _run(() async => _added(await _sources.addUrl(r['name']!, r['url']!, origin: origin)));
      case AddMethod.xtream:
        final r = await showSourceForm(
          context,
          title: 'Xtream hesabı ile ekle',
          description: 'Sağlayıcınızın verdiği sunucu adresi, kullanıcı adı ve şifre. Canlı kanallar eklenir.',
          fields: const [
            FormFieldSpec('server', 'Sunucu', kind: FieldKind.url, hint: 'http://alan:port'),
            FormFieldSpec('username', 'Kullanıcı adı', kind: FieldKind.url),
            FormFieldSpec('password', 'Şifre', kind: FieldKind.secret),
            _name,
          ],
        );
        if (r == null) return;
        await _run(
          () async => _added(
            await _sources.addXtream(
              r['name']!,
              server: r['server']!,
              username: r['username']!,
              password: r['password']!,
            ),
          ),
        );
      case AddMethod.portal:
        final r = await showSourceForm(
          context,
          title: 'MAC / STB Portal ile ekle',
          description: 'Portal adresi ve sağlayıcıya kayıtlı MAC adresi (MAG kutusu portalı).',
          fields: const [
            FormFieldSpec('portal', 'Portal adresi', kind: FieldKind.url, hint: 'http://alan:port/c/'),
            FormFieldSpec('mac', 'MAC adresi', kind: FieldKind.mac, hint: '00:1A:79:12:34:56'),
            _name,
          ],
        );
        if (r == null) return;
        await _run(() async => _added(await _sources.addPortal(r['name']!, portal: r['portal']!, mac: r['mac']!)));
      case AddMethod.bulk:
        final r = await showSourceForm(
          context,
          title: 'Toplu liste ekle',
          description:
              'GitHub klasörü (github.com/kullanıcı/depo/tree/dal/klasör) ya da satır satır liste adresi içeren '
              'metin dosyası. Her liste ayrı klasör olur (en çok ${UserSources.maxBulk}).',
          fields: const [FormFieldSpec('url', 'Adres', kind: FieldKind.url, hint: 'https://github.com/…')],
        );
        if (r == null) return;
        await _run(() async {
          final res = await _sources.addBulk(r['url']!);
          final failed = res.failed == 0 ? '' : ', ${res.failed} liste okunamadı';
          return '${res.added.length} liste eklendi$failed.';
        });
      case AddMethod.file:
        await _addFile();
      case AddMethod.phone:
        await showPhoneQrDialog(context, receiver: widget.receiver ?? SourceReceiver(_sources));
      case AddMethod.mediaHub:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: RedoxRoles.surfaceContainerHigh,
            title: const Text('MediaHub (mHub) eklentisi'),
            content: const Text(
              'Bu eklentinin biçimi henüz eklenmedi. Biçimi tahmin etmek yerine örnek bir eklenti '
              'adresiyle ya da belgesiyle eklenecek.',
            ),
            actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
          ),
        );
    }
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
      final name = f.name.replaceAll(RegExp(r'\.(m3u8?|json|html?)$', caseSensitive: false), '');
      return _added(await _sources.addText(name, text, origin: SourceOrigin.file));
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final t = Theme.of(context).textTheme;
    final methods = [
      for (final m in AddMethod.values)
        if (!(phone && m == AddMethod.phone)) m,
    ];
    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Liste ekle',
            trailing: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: RedoxSeeds.amber),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            'Eklenen her liste Kaynaklar bölümünde bir klasör olur.',
            style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TileGrid(
            columns: phone ? 2 : 3,
            children: [
              for (final (i, m) in methods.indexed)
                _MethodTile(method: m, compact: phone, autofocus: i == 0, onPressed: _busy ? null : () => _choose(m)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, this.onPressed, this.autofocus = false, this.compact = false});

  final AddMethod method;

  /// Telefon: dar kutu; başlık iki satıra iner, açıklama yok.
  final bool compact;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = method;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (active ? RedoxSeeds.amber : RedoxSeeds.crimson).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: RedoxIcon(m.icon, size: 20, color: active ? RedoxSeeds.amber : RedoxRoles.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      if (!compact)
                        Text(
                          m.subtitle,
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
