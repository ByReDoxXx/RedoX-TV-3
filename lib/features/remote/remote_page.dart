import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/remote/remote_client.dart';
import '../../core/remote/remote_key.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';

enum _Stage { searching, list, code, connecting, remote }

/// Telefon kumandası (telefonda "Diğer" › Kumanda; kullanıcı isteği: telefon
/// kumanda olarak bağlanınca ekranı doldursun). Tam ekran: yerel ağdaki
/// TV'ler bulunur, seçilen TV ekranında 4 haneli kod çıkar, kod girilince
/// eşleşir; sonraki açılışlarda son TV'ye doğrudan bağlanır. Tuşlar TV'de
/// gerçek kumanda tuşu gibi işler (RemoteHost). Her basış kısa titreşir.
class RemotePage extends StatefulWidget {
  const RemotePage({super.key, this.client = const RemoteClient()});

  final RemoteClient client;

  static Route<void> route({RemoteClient client = const RemoteClient()}) =>
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => RemotePage(client: client));

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  _Stage _stage = _Stage.searching;
  List<RemoteTv> _found = const [];
  RemoteTv? _tv;
  RemoteConnection? _connection;
  String _code = '';
  String? _error;

  /// Yön tuşları yerine rakamlar.
  bool _digits = false;

  RemoteClient get _client => widget.client;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_connection?.close());
    super.dispose();
  }

  Future<void> _start() async {
    final saved = await _client.saved();
    if (saved?.token != null) {
      await _connect(saved!);
    } else {
      await _search();
    }
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _search() async {
    _set(() => _stage = _Stage.searching);
    List<RemoteTv> found;
    try {
      found = await _client.discover();
    } on Object {
      found = const [];
    }
    _set(() {
      _found = found;
      _stage = _Stage.list;
    });
  }

  Future<void> _choose(RemoteTv tv) async {
    try {
      await _client.requestCode(tv);
    } on Object {
      _set(() => _error = '${tv.name} yanıt vermedi.');
      return;
    }
    _set(() {
      _tv = tv;
      _code = '';
      _error = null;
      _stage = _Stage.code;
    });
  }

  Future<void> _codeDigit(int d) async {
    if (_code.length >= 4) return;
    unawaited(HapticFeedback.selectionClick());
    _set(() => _code += '$d');
    if (_code.length < 4) return;
    try {
      final paired = await _client.pair(_tv!, _code);
      await _client.save(paired);
      await _connect(paired);
    } on RemoteCodeException {
      _set(() {
        _code = '';
        _error = 'Kod yanlış. TV ekranındaki kodu girin.';
      });
    } on Object {
      _set(() {
        _error = 'TV yanıt vermedi.';
        _stage = _Stage.list;
      });
    }
  }

  Future<void> _connect(RemoteTv tv) async {
    _set(() {
      _tv = tv;
      _stage = _Stage.connecting;
    });
    try {
      final c = await _client.connect(tv);
      if (!mounted) return unawaited(c.close());
      _connection = c;
      _set(() {
        _error = null;
        _stage = _Stage.remote;
      });
      unawaited(
        c.done.then((_) {
          if (_connection != c) return;
          _connection = null;
          _set(() => _error = '${tv.name} bağlantısı koptu.');
          unawaited(_search());
        }),
      );
    } on WebSocketException {
      // TV eşleşmeyi unutmuş: yeniden eşleşilir.
      await _client.save(null);
      _set(() => _error = '${tv.name} eşleşmesi geçersiz; yeniden eşleştirin.');
      await _search();
    } on Object {
      _set(() => _error = '${tv.name} bulunamadı.');
      await _search();
    }
  }

  Future<void> _change() async {
    final c = _connection;
    _connection = null;
    await c?.close();
    await _client.save(null);
    _set(() => _error = null);
    await _search();
  }

  /// Telefon klavyesi: yazılan metin TV'de açık yazı kutusuna gider (arama,
  /// kaynak adresi, kullanıcı adı…). Gönderince TV'de Tamam ile onaylanır.
  Future<void> _keyboard(BuildContext context) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RedoxRoles.surfaceContainer,
      builder: (context) => const _KeyboardSheet(),
    );
    if (text == null || text.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    _connection?.type(text);
  }

  void _send(RemoteKey key) {
    unawaited(HapticFeedback.lightImpact());
    _connection?.send(key);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final connected = _stage == _Stage.remote;
    return Scaffold(
      backgroundColor: RedoxRoles.surfaceContainerLowest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RoundKey(
                    icon: RedoxIcons.close,
                    label: 'Kumandayı kapat',
                    size: 48,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kumanda', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: connected ? const Color(0xFF4CD787) : RedoxRoles.outline,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                connected ? _tv!.name : 'Bağlı değil',
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (connected)
                    _RoundKey(icon: RedoxIcons.tvDevice, label: 'TV değiştir', size: 48, onPressed: _change),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (_stage) {
                  _Stage.searching || _Stage.connecting => _busy(
                    t,
                    _stage == _Stage.searching ? "TV'ler aranıyor…" : '${_tv!.name} bağlanıyor…',
                  ),
                  _Stage.list => _list(t),
                  _Stage.code => _codeEntry(t),
                  _Stage.remote => _remote(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _busy(TextTheme t, String text) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: RedoxRoles.primaryContainer),
      const SizedBox(height: 20),
      Text(text, style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant)),
    ],
  );

  Widget _message(TextTheme t) => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: t.bodyMedium!.copyWith(color: RedoxRoles.error)),
        );

  Widget _list(TextTheme t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _message(t),
      Text("Yerel ağdaki TV'ler", style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
      const SizedBox(height: 12),
      Expanded(
        child: _found.isEmpty
            ? Text(
                "TV bulunamadı. Telefon ile TV aynı Wi-Fi ağında olmalı ve TV'de RedoX TV açık olmalı.",
                style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
              )
            : ListView.separated(
                itemCount: _found.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final tv = _found[i];
                  return Material(
                    color: RedoxRoles.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _choose(tv),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            const RedoxIcon(RedoxIcons.tvDevice, size: 28, color: RedoxRoles.primary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tv.name, style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
                                  Text(tv.host, style: t.bodySmall!.copyWith(color: RedoxRoles.outline)),
                                ],
                              ),
                            ),
                            const RedoxIcon(RedoxIcons.chevronRight, color: RedoxRoles.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      GlassButton(label: 'Yeniden ara', icon: RedoxIcons.sync, onPressed: _search),
    ],
  );

  Widget _codeEntry(TextTheme t) => Column(
    children: [
      Text(
        '${_tv!.name} ekranındaki 4 haneli kodu girin',
        textAlign: TextAlign.center,
        style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 56,
              height: 68,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RedoxRoles.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: i == _code.length ? RedoxRoles.primaryContainer : RedoxRoles.outlineVariant,
                  width: 2,
                ),
              ),
              child: Text(
                i < _code.length ? _code[i] : '',
                style: t.headlineMedium!.copyWith(color: RedoxRoles.onSurface),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _message(t),
      const Spacer(),
      _Numpad(
        onDigit: _codeDigit,
        onBackspace: () => _set(() => _code = _code.isEmpty ? '' : _code.substring(0, _code.length - 1)),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: _search, child: const Text('Vazgeç')),
    ],
  );

  /// Kumanda: üstte Geri/Ana sayfa/Menü, ortada yön halkası (ya da rakamlar),
  /// altta ses, oynat/duraklat ve kanal. Ekranı doldurur.
  Widget _remote() => LayoutBuilder(
    builder: (context, box) {
      final pad = (box.maxWidth - 16).clamp(0, box.maxHeight * 0.5).toDouble();
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundKey(icon: RedoxIcons.back, label: 'Geri', onPressed: () => _send(RemoteKey.back)),
              _RoundKey(icon: RedoxIcons.home, label: 'Ana sayfa', onPressed: () => _send(RemoteKey.home)),
              _RoundKey(icon: RedoxIcons.keyboard, label: 'Klavye', onPressed: () => _keyboard(context)),
              _RoundKey(icon: RedoxIcons.menu, label: 'Menü', onPressed: () => _send(RemoteKey.menu)),
            ],
          ),
          SizedBox(
            width: pad,
            height: pad,
            child: _digits ? _Numpad(onDigit: (d) => _send(RemoteKey.digit(d))) : _DirectionPad(onKey: _send),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Rocker(
                label: 'Ses',
                upIcon: RedoxIcons.volume,
                downIcon: RedoxIcons.volumeDown,
                upLabel: 'Sesi artır',
                downLabel: 'Sesi azalt',
                onUp: () => _send(RemoteKey.volumeUp),
                onDown: () => _send(RemoteKey.volumeDown),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundKey(
                    icon: RedoxIcons.play,
                    label: 'Oynat/Duraklat',
                    size: 72,
                    onPressed: () => _send(RemoteKey.playPause),
                  ),
                  const SizedBox(height: 16),
                  _RoundKey(
                    icon: _digits ? RedoxIcons.remote : RedoxIcons.dialpad,
                    label: _digits ? 'Yön tuşları' : 'Rakamlar',
                    selected: _digits,
                    onPressed: () => setState(() => _digits = !_digits),
                  ),
                ],
              ),
              _Rocker(
                label: 'CH',
                upIcon: RedoxIcons.expandLess,
                downIcon: RedoxIcons.expandMore,
                upLabel: 'Sonraki kanal',
                downLabel: 'Önceki kanal',
                onUp: () => _send(RemoteKey.channelUp),
                onDown: () => _send(RemoteKey.channelDown),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Yuvarlak kumanda tuşu.
class _RoundKey extends StatelessWidget {
  const _RoundKey({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 60,
    this.selected = false,
  });

  final RedoxIcons icon;
  final String label;
  final VoidCallback onPressed;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? RedoxRoles.primaryContainer : RedoxRoles.surfaceContainerHigh,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: RedoxIcon(icon, size: size * 0.42, color: RedoxRoles.onSurface),
          ),
        ),
      ),
    ),
  );
}

/// Yön halkası: dört yön ve ortada kızıl Tamam.
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.onKey});

  final void Function(RemoteKey key) onKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final d = box.biggest.shortestSide;
      final arrow = d * 0.26;
      Widget dir(RedoxIcons icon, String label, RemoteKey key, Alignment at) => Align(
        alignment: at,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onKey(key),
            radius: arrow * 0.6,
            child: SizedBox.square(
              dimension: arrow,
              child: Center(
                child: RedoxIcon(icon, size: arrow * 0.5, color: RedoxRoles.onSurface),
              ),
            ),
          ),
        ),
      );
      return Center(
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RedoxRoles.surfaceContainerHigh,
            border: Border.all(color: RedoxRoles.outlineVariant),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                dir(RedoxIcons.expandLess, 'Yukarı', RemoteKey.up, const Alignment(0, -0.92)),
                dir(RedoxIcons.expandMore, 'Aşağı', RemoteKey.down, const Alignment(0, 0.92)),
                dir(RedoxIcons.chevronLeft, 'Sol', RemoteKey.left, const Alignment(-0.92, 0)),
                dir(RedoxIcons.chevronRight, 'Sağ', RemoteKey.right, const Alignment(0.92, 0)),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Tamam',
                    excludeSemantics: true,
                    child: Material(
                      color: RedoxRoles.primaryContainer,
                      shape: const CircleBorder(side: BorderSide(color: RedoxRoles.onPrimaryFixedVariant, width: 4)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onKey(RemoteKey.ok),
                        child: SizedBox.square(
                          dimension: d * 0.36,
                          child: Center(
                            child: Text(
                              'OK',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Dikey çift tuş (ses, kanal).
class _Rocker extends StatelessWidget {
  const _Rocker({
    required this.label,
    required this.upIcon,
    required this.downIcon,
    required this.upLabel,
    required this.downLabel,
    required this.onUp,
    required this.onDown,
  });

  final String label;
  final RedoxIcons upIcon;
  final RedoxIcons downIcon;
  final String upLabel;
  final String downLabel;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    Widget half(RedoxIcons icon, String text, VoidCallback onTap) => Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(child: RedoxIcon(icon, size: 28, color: RedoxRoles.onSurface)),
        ),
      ),
    );
    return Material(
      color: RedoxRoles.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(upIcon, upLabel, onUp),
          Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: RedoxRoles.onSurfaceVariant)),
          half(downIcon, downLabel, onDown),
        ],
      ),
    );
  }
}

/// 1–9, 0 ve (verilirse) silme.
class _Numpad extends StatelessWidget {
  const _Numpad({required this.onDigit, this.onBackspace});

  final void Function(int digit) onDigit;
  final VoidCallback? onBackspace;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget key(Widget child, String label, VoidCallback? onTap) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: onTap == null
            ? const SizedBox.shrink()
            : Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: Material(
                  color: RedoxRoles.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: SizedBox(height: 60, child: Center(child: child)),
                  ),
                ),
              ),
      ),
    );
    Widget digit(int d) =>
        key(Text('$d', style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)), '$d', () => onDigit(d));
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Row(children: [for (final d in row) digit(d)]),
        Row(
          children: [
            key(const SizedBox.shrink(), '', null),
            digit(0),
            key(const RedoxIcon(RedoxIcons.backspace, color: RedoxRoles.onSurface), 'Sil', onBackspace),
          ],
        ),
      ],
    );
  }
}

/// Klavye sayfası: tek satır yazı ve Gönder.
class _KeyboardSheet extends StatefulWidget {
  const _KeyboardSheet();

  @override
  State<_KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<_KeyboardSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_text.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("TV'ye yaz", style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
          const SizedBox(height: 4),
          Text(
            "Yazı TV'de açık yazı kutusuna gider; sonra TV'de Tamam'a basın.",
            style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Yazın',
                    filled: true,
                    fillColor: RedoxRoles.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _RoundKey(icon: RedoxIcons.send, label: 'Gönder', size: 56, selected: true, onPressed: _submit),
            ],
          ),
        ],
      ),
    );
  }
}
