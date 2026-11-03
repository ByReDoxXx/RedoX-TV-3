import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/content/local_videos.dart';
import '../../core/layout/form_factor.dart';
import '../../core/platform/storage_access.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import 'widgets/source_widgets.dart';

/// Uygulama içi dosya gezgini (kullanıcı isteği; Kaynak ekle › Dosyadan ve
/// Klasörden). Chromecast gibi dosya seçicisi olmayan TV'lerde de çalışır.
///
/// TV/tablet (kullanıcı isteği: "dosya gezginini yeniden tasarla"): solda
/// konumlar (dahili depolama, takılı USB/SSD/SD kart, uygulama klasörü),
/// sağda konum yolu (her parçası OK ile açılır) ve klasörün içeriği iki
/// sütunda: klasörler önce, dosyalar boyutlarıyla. Açılışta ilk konum açık.
/// Telefonda tek sütun: önce konumlar, sonra klasör.
///
/// Yalnız eklenebilen dosyalar görünür (M3U, M3U8, JSON, TXT, HTML). OK
/// klasöre girer ya da dosyayı seçer; Geri üst klasöre, konumun kökünde
/// sayfadan çıkar. Döner: dosyanın yolu.
///
/// [folder] kipinde (Klasörden) videolar görünür: "Bu klasörü ekle" açık
/// klasörü, videoya basmak yalnız o videoyu döner (kullanıcı isteği:
/// "Oppenheimer'ı seçemiyorum").
class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key, this.roots, this.folder = false});

  /// Kökler (ad, yol); null ise cihazınkiler (StorageAccess.roots).
  final List<(String, String)>? roots;

  /// Klasör seçme kipi.
  final bool folder;

  static const extensions = {'m3u', 'm3u8', 'json', 'txt', 'html', 'htm'};

  static Route<String> route({List<(String, String)>? roots, bool folder = false}) => MaterialPageRoute(
    builder: (_) => FileBrowserPage(roots: roots, folder: folder),
  );

  /// Dosya boyutu: "820 KB", "1,4 GB".
  static String size(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes.toDouble();
    var u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    final text = u == 0 || v >= 10 ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
    return '$text ${units[u]}';
  }

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  bool? _allowed;

  /// Açık klasör; null iken konum listesi (telefon).
  String? _dir;
  List<FileSystemEntity> _entries = const [];
  final _sizes = <String, int>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_ask());
  }

  /// Uygulamanın kendi klasörü (izin istemez).
  String? _appDir;

  /// Cihazın kökleri (ya da [FileBrowserPage.roots]); izin sorulurken okunur.
  List<(String, String)> _deviceRoots = const [];

  bool get _wide => Theme.of(context).extension<RedoxMetrics>()!.formFactor != FormFactor.phone;

  Future<void> _ask() async {
    final ok = await StorageAccess.ensure();
    final app = widget.roots == null ? await StorageAccess.appFolder() : null;
    final device = widget.roots ?? await StorageAccess.roots();
    if (!mounted) return;
    setState(() {
      _allowed = ok;
      _appDir = app;
      _deviceRoots = device;
    });
    // Geniş ekranda sağ bölme boş kalmasın: ilk konum açılır.
    if (_wide && _dir == null && _roots.isNotEmpty) await _open(_roots.first.$2);
  }

  Future<void> _open(String? dir) async {
    if (dir == null) {
      setState(() {
        _dir = null;
        _error = null;
      });
      return;
    }
    List<FileSystemEntity> entries;
    String? error;
    final sizes = <String, int>{};
    try {
      entries =
          [
            for (final e in await Directory(dir).list().toList())
              if (!_name(e.path).startsWith('.') && (e is Directory || (e is File && _addable(e.path)))) e,
          ]..sort((a, b) {
            final folders = (a is Directory ? 0 : 1) - (b is Directory ? 0 : 1);
            return folders != 0 ? folders : LocalVideos.naturalCompare(_name(a.path), _name(b.path));
          });
      for (final e in entries.whereType<File>()) {
        try {
          sizes[e.path] = await e.length();
        } on FileSystemException {
          // Boyut bilinmez.
        }
      }
    } on FileSystemException {
      entries = const [];
      error = 'Bu klasör açılamadı.';
    }
    if (!mounted) return;
    setState(() {
      _dir = dir;
      _entries = entries;
      _sizes
        ..clear()
        ..addAll(sizes);
      _error = error;
    });
  }

  static String _name(String path) => path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).lastOrNull ?? path;

  bool _addable(String path) {
    if (widget.folder) return LocalVideos.isVideo(path);
    final dot = path.lastIndexOf('.');
    return dot > 0 && FileBrowserPage.extensions.contains(path.substring(dot + 1).toLowerCase());
  }

  List<(String, String)> get _roots => [
    if (_allowed ?? false) ..._deviceRoots,
    if (_appDir case final app?) ('Uygulama klasörü', app),
  ];

  /// Açık klasörün konumu (kökü).
  (String, String)? get _root {
    final dir = _dir;
    if (dir == null) return null;
    (String, String)? best;
    for (final r in _roots) {
      if (_within(dir, r.$2) && (best == null || r.$2.length > best.$2.length)) best = r;
    }
    return best;
  }

  /// Üst klasör; konumun kökündeyse null.
  String? get _parent {
    final dir = _dir;
    if (dir == null || _roots.any((r) => _same(r.$2, dir))) return null;
    return Directory(dir).parent.path;
  }

  static String _trim(String p) => p.replaceAll(RegExp(r'[/\\]+$'), '');

  static bool _same(String a, String b) => _trim(a) == _trim(b);

  static bool _within(String dir, String root) {
    final d = _trim(dir);
    final r = _trim(root);
    return d == r || d.startsWith('$r/') || d.startsWith('$r\\');
  }

  /// Konum yolu: kökün adı, sonra klasörler (ad, yol).
  List<(String, String)> get _crumbs {
    final dir = _dir;
    final root = _root;
    if (dir == null) return const [];
    if (root == null) return [(_name(dir), dir)];
    final out = [(root.$1, root.$2)];
    var path = _trim(root.$2);
    final sep = path.contains('\\') && !path.contains('/') ? '\\' : '/';
    for (final part in _trim(dir).substring(path.length).split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty)) {
      path = '$path$sep$part';
      out.add((part, path));
    }
    return out;
  }

  Future<void> _system() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles();
    } on Object {
      return;
    }
    final path = files.firstOrNull?.path;
    if (path != null && mounted) Navigator.of(context).pop(path);
  }

  static RedoxIcons _rootIcon(String name) => switch (name) {
    'Dahili depolama' => RedoxIcons.tvDevice,
    'Uygulama klasörü' => RedoxIcons.folder,
    _ => RedoxIcons.database,
  };

  @override
  Widget build(BuildContext context) {
    final wide = _wide;
    final tv = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;
    final t = Theme.of(context).textTheme;
    final dir = _dir;
    // Geniş ekranda konum kökünde Geri sayfadan çıkar; telefonda konum
    // listesine döner.
    final atTop = dir == null || (wide && _parent == null);
    return PopScope(
      canPop: atTop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && dir != null) unawaited(_open(_parent));
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tv ? 48 : 16, vertical: tv ? 28 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconTile(
                      icon: widget.folder ? RedoxIcons.folder : RedoxIcons.uploadFile,
                      tint: RedoxSeeds.gold,
                      size: 44,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.folder ? 'Klasör seç' : 'Dosya seç',
                            style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface),
                          ),
                          Text(
                            widget.folder
                                ? 'Film ya da dizi klasörü ya da tek bir video'
                                : 'M3U, M3U8, JSON, TXT ya da HTML listesi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (widget.folder && wide && dir != null)
                      PrimaryButton(
                        label: 'Bu klasörü ekle',
                        icon: RedoxIcons.add,
                        onPressed: () => Navigator.of(context).pop(dir),
                      ),
                    if (!tv && !widget.folder)
                      GlassButton(label: 'Sistem seçicisi', icon: RedoxIcons.uploadFile, onPressed: _system),
                  ],
                ),
                SizedBox(height: tv ? 20 : 14),
                Expanded(
                  child: _allowed == false && _roots.isEmpty ? _permission(t) : (wide ? _twoPane(t) : _phone(t)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// İzin yokken (ve uygulama klasörü de yokken) yönerge.
  Widget _permission(TextTheme t) => ListView(
    children: [
      Text(
        "Bütün dosyaları görmek için izin gerekiyor. Açılan ekranda RedoX TV için \"Tüm dosyalara erişim\"i "
        'açın. Bu cihazda izin ekranı yoksa listeyi telefondan QR ile ekleyin.',
        style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: PrimaryButton(label: 'İzin ver', icon: RedoxIcons.lock, onPressed: _ask),
      ),
    ],
  );

  /// TV/tablet: solda konumlar, sağda konum yolu ve içerik.
  Widget _twoPane(TextTheme t) {
    final root = _root;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'KONUMLAR',
                  style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant, letterSpacing: 1.5),
                ),
              ),
              for (final (name, path) in _roots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _Place(
                    icon: _rootIcon(name),
                    name: name,
                    detail: path,
                    selected: root?.$2 == path,
                    onPressed: () => _open(path),
                  ),
                ),
              if (_allowed == false) ...[
                const SizedBox(height: 10),
                Text(
                  'Takılı sürücüler için "Tüm dosyalara erişim" izni gerekiyor.',
                  style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                GlassButton(label: 'İzin ver', icon: RedoxIcons.lock, onPressed: _ask),
              ],
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RedoxRoles.surfaceContainerLow,
              borderRadius: BorderRadius.circular(RedoxRadius.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_dir != null) _Crumbs(crumbs: _crumbs, onOpen: _open),
                  const SizedBox(height: 12),
                  Expanded(child: _contents(t, columns: 2)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Telefon: konumlar ya da açık klasör.
  Widget _phone(TextTheme t) {
    if (_dir == null) {
      return ListView(
        children: [
          for (final (i, (name, path)) in _roots.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _Place(
                icon: _rootIcon(name),
                name: name,
                detail: path,
                autofocus: i == 0,
                onPressed: () => _open(path),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Crumbs(crumbs: _crumbs, onOpen: _open),
        const SizedBox(height: 10),
        if (widget.folder) ...[
          PrimaryButton(
            label: 'Bu klasörü ekle',
            icon: RedoxIcons.add,
            onPressed: () => Navigator.of(context).pop(_dir),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(child: _contents(t, columns: 1)),
      ],
    );
  }

  /// Açık klasörün içeriği: "Yukarı", klasörler, dosyalar.
  Widget _contents(TextTheme t, {required int columns}) {
    final dir = _dir;
    if (dir == null) return const SizedBox.shrink();
    final parent = _parent;
    final tiles = [
      if (parent != null)
        _Entry(
          icon: RedoxIcons.expandLess,
          tint: RedoxRoles.onSurfaceVariant,
          name: 'Yukarı',
          // Üst klasörün görünen adı (kökte konumun adı, yolun son parçası değil).
          detail: switch (_crumbs) {
            final c when c.length >= 2 => c[c.length - 2].$1,
            _ => _name(parent),
          },
          autofocus: true,
          onPressed: () => _open(parent),
        ),
      for (final (i, e) in _entries.indexed)
        if (e is Directory)
          _Entry(
            icon: RedoxIcons.folder,
            tint: RedoxSeeds.gold,
            name: _name(e.path),
            detail: 'Klasör',
            autofocus: parent == null && i == 0,
            onPressed: () => _open(e.path),
          )
        else
          _Entry(
            icon: widget.folder ? RedoxIcons.film : RedoxIcons.uploadFile,
            tint: widget.folder ? RedoxSeeds.amber : RedoxRoles.primary,
            name: _name(e.path),
            detail: [
              if (widget.folder) 'Video' else 'Liste dosyası',
              if (_sizes[e.path] case final s?) FileBrowserPage.size(s),
            ].join(' · '),
            autofocus: parent == null && i == 0,
            onPressed: () => Navigator.of(context).pop(e.path),
          ),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        TileGrid(columns: columns, children: tiles),
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 4),
            child: Text(
              _error ??
                  (widget.folder ? 'Bu klasörde alt klasör ya da video yok.' : 'Bu klasörde eklenebilecek dosya yok.'),
              style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Konum yolu: "SSD › Filmler › Aksiyon"; her parça OK ile açılır, son
/// parça (açık klasör) vurgulu.
class _Crumbs extends StatelessWidget {
  const _Crumbs({required this.crumbs, required this.onOpen});

  final List<(String, String)> crumbs;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.full);
    // Kısa yol solda durur; uzun yolda son parçalar görünür (sağa kayar).
    return Row(
      children: [
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (i, (name, path)) in crumbs.indexed) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: RedoxIcon(RedoxIcons.chevronRight, color: RedoxRoles.outline, size: 18),
                    ),
                  FocusGlow(
                    borderRadius: radius,
                    scale: 1,
                    builder: (context, active) => Material(
                      color: active ? RedoxRoles.surfaceContainerHighest : Colors.transparent,
                      borderRadius: radius,
                      child: InkWell(
                        onTap: () => onOpen(path),
                        borderRadius: radius,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            name,
                            style: t.titleSmall!.copyWith(
                              color: i == crumbs.length - 1 ? RedoxRoles.onSurface : RedoxRoles.onSurfaceVariant,
                              fontWeight: i == crumbs.length - 1 ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Konum satırı (sol bölme ve telefondaki konum listesi): ikon, ad, yol;
/// açık konum kızıl çizgili.
class _Place extends StatelessWidget {
  const _Place({
    required this.icon,
    required this.name,
    required this.detail,
    required this.onPressed,
    this.selected = false,
    this.autofocus = false,
  });

  final RedoxIcons icon;
  final String name;
  final String detail;
  final VoidCallback onPressed;
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active
            ? RedoxRoles.surfaceContainerHighest
            : (selected ? RedoxRoles.surfaceContainerHigh : RedoxRoles.surfaceContainer),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: selected ? RedoxSeeds.crimson : Colors.transparent, width: 4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                RedoxIcon(icon, color: selected ? RedoxSeeds.amber : RedoxSeeds.gold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        detail,
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

/// Klasör içeriği kutusu: renkli ikon, ad ve ayrıntı (Klasör / boyut).
class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.tint,
    required this.name,
    required this.detail,
    required this.onPressed,
    this.autofocus = false,
  });

  final RedoxIcons icon;
  final Color tint;
  final String name;
  final String detail;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return CardShell(
      onPressed: onPressed,
      autofocus: autofocus,
      height: 64,
      builder: (active) => Row(
        children: [
          IconTile(icon: icon, tint: tint, active: active, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
                Text(
                  detail,
                  maxLines: 1,
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
