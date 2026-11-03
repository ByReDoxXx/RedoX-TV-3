import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/content/source_receiver.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/redox_icon.dart';
import 'file_browser_page.dart';
import 'widgets/phone_qr_dialog.dart';
import 'widgets/source_form_dialog.dart';
import 'widgets/source_widgets.dart';

/// Eklenen kaynağın içeriği (kullanıcı isteği: "dizi eklenirse dizide,
/// film eklenirse filmde listelensin"). Aynı yöntemlerle (M3U, Xtream,
/// portal…) eklenir; liste Kaynaklar, Film ya da Dizi bölümünde görünür.
enum SourceContent {
  live('Canlı TV', RedoxIcons.television, SourceKind.live, 'Kaynaklar'),
  film('Film', RedoxIcons.film, SourceKind.film, 'Film'),
  series('Dizi', RedoxIcons.series, SourceKind.series, 'Dizi');

  const SourceContent(this.label, this.icon, this.kind, this.section);

  final String label;
  final RedoxIcons icon;
  final SourceKind kind;

  /// Listenin göründüğü bölüm.
  final String section;
}

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
  folder('Klasörden', 'SSD, USB, SD karttaki videolar', RedoxIcons.folder),
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
  const AddSourceTab({super.key, required this.sources, this.receiver, this.fileRoots, this.padding = EdgeInsets.zero});

  final UserSources sources;

  /// Telefondan ekleme alıcısı; null ise pencere [SourceReceiver] kurar
  /// (testlerde sunucusuz sahtesi verilir).
  final SourceReceiver? receiver;

  /// Dosya gezgininin kökleri; null ise cihazınkiler (testlerde geçici klasör).
  final List<(String, String)>? fileRoots;

  /// Kayma alanının iç payı (sayfa kenarları).
  final EdgeInsets padding;

  @override
  State<AddSourceTab> createState() => _AddSourceTabState();
}

class _AddSourceTabState extends State<AddSourceTab> {
  bool _busy = false;
  SourceContent _content = SourceContent.live;

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
        await _run(
          () async => _added(await _sources.addUrl(r['name']!, r['url']!, origin: origin, kind: _content.kind)),
        );
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
              kind: _content.kind,
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
        await _run(
          () async =>
              _added(await _sources.addPortal(r['name']!, portal: r['portal']!, mac: r['mac']!, kind: _content.kind)),
        );
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
          final res = await _sources.addBulk(r['url']!, kind: _content.kind);
          final failed = res.failed == 0 ? '' : ', ${res.failed} liste okunamadı';
          return '${res.added.length} liste eklendi$failed.';
        });
      case AddMethod.file:
        await _addFile();
      case AddMethod.folder:
        await _addFolder();
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

  /// Dosyadan: uygulama içi dosya gezgini (izin, kökler, klasörler).
  Future<void> _addFile() async {
    final path = await Navigator.of(context).push(FileBrowserPage.route(roots: widget.fileRoots));
    if (path == null) return;
    await _run(() async {
      final text = await File(path).readAsString();
      final file = path.split(RegExp(r'[/\\]')).last;
      final name = file.replaceAll(RegExp(r'\.(m3u8?|json|html?|txt)$', caseSensitive: false), '');
      return _added(await _sources.addText(name, text, origin: SourceOrigin.file, kind: _content.kind));
    });
  }

  /// Klasörden: gezginde klasör seçilir, videoları Film ya da Dizi olur
  /// (Canlı TV seçiliyken Film).
  Future<void> _addFolder() async {
    final path = await Navigator.of(context).push(FileBrowserPage.route(roots: widget.fileRoots, folder: true));
    if (path == null) return;
    final kind = _content == SourceContent.series ? SourceKind.series : SourceKind.film;
    await _run(() async {
      final s = await _sources.addFolder('', path, kind: kind);
      return '"${s.name}" eklendi: ${s.count} video (${kind.label} bölümünde).';
    });
  }

  /// Yöntem grupları (başlık, açıklama, yöntemler).
  static const _groups = [
    ('İnternetten', 'Liste ya da sayfa adresiyle', [AddMethod.m3u, AddMethod.json, AddMethod.html, AddMethod.bulk]),
    ('Hesapla', 'Sağlayıcının verdiği bilgilerle', [AddMethod.xtream, AddMethod.portal, AddMethod.mediaHub]),
    ('Bu cihazdan', 'Dosya, USB/SSD klasörü ya da telefon', [AddMethod.file, AddMethod.folder, AddMethod.phone]),
  ];

  /// Bu içerikte ve cihazda görünen yöntem mi: telefonda "Telefondan", Canlı
  /// TV'de "Klasörden" (videolar Film/Dizi olur) yok.
  bool _shown(AddMethod m, {required bool phone}) =>
      !(phone && m == AddMethod.phone) && !(_content == SourceContent.live && m == AddMethod.folder);

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final t = Theme.of(context).textTheme;
    var first = true;
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
          const SizedBox(height: 14),
          // 1. İçerik: Canlı TV, Film, Dizi.
          _StepTitle(number: 1, title: 'Ne ekliyorsunuz?'),
          const SizedBox(height: 10),
          TileGrid(
            columns: 3,
            // Dikey tablette de üçü bir satırda.
            minWidth: phone ? 0 : 96,
            children: [
              for (final c in SourceContent.values)
                _ContentCard(
                  content: c,
                  selected: c == _content,
                  compact: phone,
                  onPressed: () => setState(() => _content = c),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Eklenen her liste ${_content.section} bölümünde bir klasör olur.',
            style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          // 2. Yöntem, gruplar hâlinde.
          _StepTitle(number: 2, title: 'Nereden?'),
          for (final (title, detail, methods) in _groups)
            if (methods.where((m) => _shown(m, phone: phone)).toList() case final shown when shown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: '  ·  $detail'),
                  ],
                ),
                style: t.labelLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TileGrid(
                columns: phone ? 2 : 3,
                minWidth: phone ? 0 : 200,
                children: [
                  for (final m in shown)
                    _MethodTile(
                      method: m,
                      tint: kindTint(_content.kind),
                      compact: phone,
                      autofocus: () {
                        final f = first;
                        first = false;
                        return f;
                      }(),
                      onPressed: _busy ? null : () => _choose(m),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

/// Adım başlığı: kızıl daire içinde numara ve soru.
class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: RedoxSeeds.crimson, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: t.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// İçerik kartı (Canlı TV, Film, Dizi): seçili olan kızıl çerçeveli,
/// ikonu türün renginde.
class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content, required this.selected, required this.onPressed, this.compact = false});

  final SourceContent content;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tint = kindTint(content.kind);
    final label = Text(
      content.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: t.titleSmall!.copyWith(
        color: selected ? RedoxRoles.onSurface : RedoxRoles.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    return CardShell(
      onPressed: onPressed,
      selected: selected,
      height: compact ? 56 : 88,
      // Dar bölmede (Ayarlar'ın sağı) ikon üstte, ad altta: yan yana "Canlı
      // TV" kesiliyordu.
      builder: (active) => compact
          ? Center(child: label)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTile(icon: content.icon, tint: tint, active: active || selected, size: 36),
                const SizedBox(height: 6),
                label,
              ],
            ),
    );
  }
}

/// Ekleme yöntemi kutusu: renkli ikon, tek satır başlık ve açıklama; bütün
/// kutular eşit yükseklikte (önce açıklama sarılınca boylar farklıydı).
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.tint,
    this.onPressed,
    this.autofocus = false,
    this.compact = false,
  });

  final AddMethod method;
  final Color tint;

  /// Telefon: dar kutu; açıklama yok.
  final bool compact;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = method;
    return CardShell(
      onPressed: onPressed,
      autofocus: autofocus,
      height: compact ? 64 : 86,
      builder: (active) => Row(
        children: [
          IconTile(icon: m.icon, tint: active ? RedoxSeeds.amber : tint, active: active, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
