import 'package:flutter/foundation.dart';

/// Tanılama günlüğü (Ayarlar › Hakkında): uygulama hataları ve oynatıcının
/// açamadığı akışlar, son [limit] satır, yalnız bellekte. Hata raporu bu
/// satırlardan yazılır.
///
/// Gizlilik: adreslerde kullanıcı adı, şifre ve anahtar olabilir (Xtream,
/// portal); her adres yalnız sunucu adına indirilir ([redact]).
class Diagnostics extends ChangeNotifier {
  static final instance = Diagnostics();

  static const limit = 300;

  final _lines = <String>[];

  List<String> get lines => List.unmodifiable(_lines);

  void log(String source, String message) {
    final now = DateTime.now();
    String two(int n) => '$n'.padLeft(2, '0');
    final line = '${two(now.hour)}:${two(now.minute)}:${two(now.second)} [$source] ${redact(message)}';
    _lines.add(line);
    // Sistem günlüğüne de (adb logcat; adresler yine gizli).
    debugPrint('redox $line');
    if (_lines.length > limit) _lines.removeRange(0, _lines.length - limit);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  static final _url = RegExp(r'''[a-zA-Z][a-zA-Z0-9+.-]*://[^\s"'<>]+''');

  /// Adresler sunucu adına iner: "http://sunucu:8080/live/ali/1234/5.ts" →
  /// "http://sunucu:8080/…".
  static String redact(String text) => text.replaceAllMapped(_url, (m) {
    final uri = Uri.tryParse(m[0]!);
    if (uri == null || uri.host.isEmpty) return '[adres]';
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/…';
  });

  /// Hata raporu metni: başlık (uygulama, cihaz) ve günlük.
  String report({required String header}) => [
    header,
    '',
    ..._lines.isEmpty ? ['(günlük boş)'] : _lines,
  ].join('\n');
}
