import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';
import 'redox_icon.dart';

/// TV ekran klavyesi: Türkçe Q düzeni, rakamlar, büyük harf, boşluk ve sil.
///
/// Neden sistem klavyesi değil: Flutter metin alanı açıkken Android TV'nin
/// ekran klavyesi kumandanın yön tuşlarını alamıyor; harf seçilemiyor
/// (flutter/flutter#154924, Chromecast'te doğrulandı; Flutter "beklenen
/// davranış" diye kapattı). Bu klavye uygulamanın kendi odak düzeniyle gezilir.
/// Fiziksel klavyenin ve kumandanın rakam tuşları da [controller]'a yazar.
class TvKeyboard extends StatefulWidget {
  const TvKeyboard({
    super.key,
    required this.controller,
    this.maxLength,
    this.autofocus = false,
    this.symbols = false,
    this.autoCapitalize = true,
  });

  final TextEditingController controller;
  final int? maxLength;
  final bool autofocus;

  /// Adres yazımı: sembol satırı (: / . - _ ? = & @ %) ve "https://", ".m3u"
  /// kısayolları.
  final bool symbols;

  /// Kelime başında kendiliğinden büyük harf (adlar); adreste kapalı.
  final bool autoCapitalize;

  static const symbolRow = [':', '/', '.', '-', '_', '?', '=', '&', '@', '%'];

  /// Tek tuşun kapladığı genişlik (tuş + iki yandaki boşluk).
  static const keyExtent = _Key.size + _Key.gap * 2;

  static const rows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'ı', 'o', 'p', 'ğ', 'ü'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ş', 'i'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm', 'ö', 'ç'],
  ];

  /// Türkçe büyük harf ("i" → "İ", "ı" → "I").
  static String upper(String c) => switch (c) {
    'i' => 'İ',
    'ı' => 'I',
    _ => c.toUpperCase(),
  };

  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  /// Büyük harf: kelime başında kendiliğinden açıktır; ⇧ tersine çevirir.
  bool _shiftOverride = false;

  /// Fiziksel klavyeden yazılabilen tek karakter (denetim karakterleri hariç).
  static final _typable = RegExp(r'^[^\x00-\x1F\x7F]$');

  String get _text => widget.controller.text;

  bool get _atWordStart => _text.isEmpty || _text.endsWith(' ');

  bool get _upper => (widget.autoCapitalize && _atWordStart) != _shiftOverride;

  void _insert(String s) {
    if (widget.maxLength case final max? when _text.characters.length + s.characters.length > max) return;
    widget.controller.text = _text + s;
    setState(() => _shiftOverride = false);
  }

  void _letter(String c) => _insert(_upper ? TvKeyboard.upper(c) : c);

  void _erase() {
    if (_text.isEmpty) return;
    widget.controller.text = _text.characters.skipLast(1).toString();
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _erase();
      return KeyEventResult.handled;
    }
    final c = e.character;
    if (c != null && _typable.hasMatch(c)) {
      _insert(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// [n] tuş genişliğinde geniş tuş (aradaki boşluklar dahil).
  static double _units(int n) => _Key.size * n + _Key.gap * 2 * (n - 1);

  @override
  Widget build(BuildContext context) {
    final upper = _upper;
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.symbols)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final c in TvKeyboard.symbolRow) _Key(label: c, onPressed: () => _insert(c))],
            ),
          for (final (r, row) in TvKeyboard.rows.indexed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, c) in row.indexed)
                  _Key(
                    label: r == 0 ? c : (upper ? TvKeyboard.upper(c) : c),
                    autofocus: widget.autofocus && r == 2 && i == 0,
                    onPressed: () => r == 0 ? _insert(c) : _letter(c),
                  ),
              ],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Key(
                icon: RedoxIcons.expandLess,
                semantics: 'Büyük harf',
                selected: upper,
                width: _Key.size * 2 + _Key.gap * 2,
                onPressed: () => setState(() => _shiftOverride = !_shiftOverride),
              ),
              if (widget.symbols) ...[
                _Key(label: 'https://', width: _units(2), onPressed: () => _insert('https://')),
                _Key(label: 'Boşluk', width: _units(4), onPressed: () => _insert(' ')),
                _Key(label: '.m3u', width: _units(2), onPressed: () => _insert('.m3u')),
              ] else
                _Key(label: 'Boşluk', width: _units(8), onPressed: () => _insert(' ')),
              _Key(
                icon: RedoxIcons.backspace,
                semantics: 'Sil',
                width: _Key.size * 2 + _Key.gap * 2,
                onPressed: _erase,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semantics,
    required this.onPressed,
    this.width = size,
    this.selected = false,
    this.autofocus = false,
  });

  static const size = 38.0;
  static const gap = 2.0;

  final String? label;
  final RedoxIcons? icon;
  final String? semantics;
  final VoidCallback onPressed;
  final double width;
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.sm);
    return Padding(
      padding: const EdgeInsets.all(gap),
      child: FocusGlow(
        borderRadius: radius,
        scale: 1.1,
        builder: (context, active) {
          final fg = active ? RedoxSeeds.obsidian : (selected ? RedoxSeeds.amber : RedoxRoles.onSurface);
          return Material(
            color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
            borderRadius: radius,
            child: InkWell(
              onTap: onPressed,
              autofocus: autofocus,
              borderRadius: radius,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Semantics(
                button: true,
                label: semantics ?? label,
                excludeSemantics: true,
                child: SizedBox(
                  width: width,
                  height: size,
                  child: Center(
                    child: switch ((label, icon)) {
                      (final l?, _) => Text(l, style: t.titleMedium!.copyWith(color: fg)),
                      (_, final i?) => RedoxIcon(i, color: fg, size: 22),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
