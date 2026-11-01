import 'dart:io';
import 'dart:typed_data';

/// Adresteki dosyanın baytları (HTTP 200 değilse hata). [headers]: istek
/// başlıkları (örn. STB portalının çerezi ve yetkisi).
Future<List<int>> fetchBytes(
  Uri uri, {
  Duration timeout = const Duration(seconds: 30),
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}', uri: uri);
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add).timeout(timeout);
    return builder.takeBytes();
  } finally {
    client.close();
  }
}
