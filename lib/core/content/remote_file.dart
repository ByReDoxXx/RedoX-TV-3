import 'dart:io';
import 'dart:typed_data';

/// Adresteki dosyanın baytları (HTTP 200 değilse hata).
Future<List<int>> fetchBytes(Uri uri, {Duration timeout = const Duration(seconds: 30)}) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}', uri: uri);
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add).timeout(timeout);
    return builder.takeBytes();
  } finally {
    client.close();
  }
}
