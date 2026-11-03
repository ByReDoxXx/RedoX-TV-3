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

/// Uygulama içi dosya gezgini (kullanıcı isteği; Kaynak ekle › Dosyadan).
/// Chromecast gibi dosya seçicisi olmayan TV'lerde de çalışır: kökler
/// (dahili depolama, USB/SD, sürücüler), klasörler ve yalnız eklenebilen
/// dosyalar (M3U, M3U8, JSON, TXT, HTML). OK klasöre girer ya da dosyayı
/// seçer; Geri üst klasöre, köklerde sayfadan çıkar. Döner: dosyanın yolu.
///
/// [folder] kipinde (Kaynak ekle › Klasörden) klasör seçilir: klasörler ve
/// içlerindeki videolar listelenir (videolar seçilmez), üstteki "Bu klasörü
/// ekle" açık klasörü döner.
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

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  bool? _allowed;

  /// Açık klasör; null iken kök listesi.
  String? _dir;
  List<FileSystemEntity> _entries = const [];
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

  Future<void> _ask() async {
    final ok = await StorageAccess.ensure();
    final app = widget.roots == null ? await StorageAccess.appFolder() : null;
    final device = widget.roots ?? await StorageAccess.roots();
    if (mounted) {
      setState(() {
        _allowed = ok;
        _appDir = app;
        _deviceRoots = device;
      });
    }
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
    try {
      entries =
          [
            for (final e in await Directory(dir).list().toList())
              if (!_name(e.path).startsWith('.') && (e is Directory || (e is File && _addable(e.path)))) e,
          ]..sort((a, b) {
            final folders = (a is Directory ? 0 : 1) - (b is Directory ? 0 : 1);
            return folders != 0 ? folders : _name(a.path).toLowerCase().compareTo(_name(b.path).toLowerCase());
          });
    } on FileSystemException {
      entries = const [];
      error = 'Bu klasör açılamadı.';
    }
    if (!mounted) return;
    setState(() {
      _dir = dir;
      _entries = entries;
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

  /// Üst klasör; kökteyse null (kök listesi).
  String? get _parent {
    final dir = _dir!;
    if (_roots.any((r) => _same(r.$2, dir))) return null;
    return Directory(dir).parent.path;
  }

  static bool _same(String a, String b) => a.replaceAll(RegExp(r'[/\\]+$'), '') == b.replaceAll(RegExp(r'[/\\]+$'), '');

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

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final tv = metrics.formFactor == FormFactor.tv;
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: _dir == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dir != null) unawaited(_open(_parent));
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tv ? 48 : 16, vertical: tv ? 32 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.folder ? 'Klasör seç' : 'Dosya seç',
                            style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface),
                          ),
                          Text(
                            _dir ??
                                (widget.folder
                                    ? 'Film ya da dizi klasörü (SSD, USB bellek, SD kart)'
                                    : 'M3U, M3U8, JSON, TXT ya da HTML listesi'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!tv && !widget.folder)
                      GlassButton(label: 'Sistem seçicisi', icon: RedoxIcons.uploadFile, onPressed: _system),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: _body(t)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(TextTheme t) {
    switch (_allowed) {
      case null:
        return const SizedBox.shrink();
      case false when _dir == null:
        return ListView(
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
            if (_appDir case final app?) ...[
              const SizedBox(height: 16),
              _Row(
                icon: RedoxIcons.folder,
                name: 'Uygulama klasörü',
                detail: app,
                autofocus: true,
                onPressed: () => _open(app),
              ),
            ],
          ],
        );
      default:
        break;
    }
    final dir = _dir;
    final rows = <Widget>[
      if (dir == null)
        for (final (i, (name, path)) in _roots.indexed)
          _Row(icon: RedoxIcons.folder, name: name, detail: path, autofocus: i == 0, onPressed: () => _open(path))
      else ...[
        _Row(
          icon: RedoxIcons.expandLess,
          name: 'Yukarı',
          detail: dir,
          autofocus: true,
          onPressed: () => _open(_parent),
        ),
        if (widget.folder)
          _Row(
            icon: RedoxIcons.add,
            name: 'Bu klasörü ekle',
            detail: 'Alt klasörlerdeki videolar da eklenir',
            onPressed: () => Navigator.of(context).pop(dir),
          ),
        for (final e in _entries)
          _Row(
            icon: e is Directory ? RedoxIcons.folder : (widget.folder ? RedoxIcons.film : RedoxIcons.uploadFile),
            name: _name(e.path),
            detail: e is Directory ? 'Klasör' : (widget.folder ? 'Video' : 'Liste dosyası'),
            onPressed: e is Directory
                ? () => _open(e.path)
                : (widget.folder ? null : () => Navigator.of(context).pop(e.path)),
          ),
      ],
    ];
    final empty = dir != null && _entries.isEmpty;
    return ListView(
      children: [
        for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 6), child: r),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.name,
    required this.detail,
    required this.onPressed,
    this.autofocus = false,
  });

  final RedoxIcons icon;
  final String name;
  final String detail;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  RedoxIcon(icon, color: RedoxSeeds.gold, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}
