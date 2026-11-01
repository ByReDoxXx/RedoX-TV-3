import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'user_sources.dart';

/// Telefondan liste ekleme: Kaynaklar sayfası açıkken yerel ağda küçük bir
/// HTTP sunucusu. Telefon QR'daki adresi açar; gelen sayfada liste adresini
/// yapıştırır ya da telefondaki M3U dosyasını seçer.
///
/// Güvenlik: yalnız yerel ağ adresinden erişilir; her istek QR'daki rastgele
/// anahtarı (`t`) taşımalıdır; sunucu sayfadan çıkınca kapanır.
class SourceReceiver {
  SourceReceiver(this.sources);

  final UserSources sources;
  HttpServer? _server;
  String? _url;
  final _token = _randomToken();

  /// Telefonun açacağı adres (QR); sunucu açılmadıysa ya da ağ yoksa null.
  String? get url => _url;

  static String _randomToken() {
    const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return String.fromCharCodes([for (var i = 0; i < 10; i++) chars.codeUnitAt(r.nextInt(chars.length))]);
  }

  /// Sunucuyu açar; yerel ağ adresi yoksa null döner. [host] verilirse QR
  /// adresinde o kullanılır (testler).
  Future<String?> start({String? host}) async {
    final ip = host ?? await localAddress();
    if (ip == null) return null;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    unawaited(server.forEach(_handle));
    return _url = 'http://$ip:${server.port}/?t=$_token';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _url = null;
  }

  /// Cihazın yerel ağ (özel) IPv4 adresi.
  static Future<String?> localAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        final b = a.rawAddress;
        final private = b[0] == 10 || (b[0] == 192 && b[1] == 168) || (b[0] == 172 && b[1] >= 16 && b[1] <= 31);
        if (private && !a.isLoopback) return a.address;
      }
    }
    return null;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      if (req.uri.queryParameters['t'] != _token) {
        res.statusCode = HttpStatus.forbidden;
        res.write('Geçersiz bağlantı: TV\'deki QR kodunu yeniden okutun.');
      } else if (req.method == 'GET' && req.uri.path == '/') {
        res.headers.contentType = ContentType.html;
        res.write(_page);
      } else if (req.method == 'POST' && req.uri.path == '/ekle') {
        await _add(req);
      } else {
        res.statusCode = HttpStatus.notFound;
      }
    } on Object {
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
  }

  Future<void> _add(HttpRequest req) async {
    final res = req.response;
    res.headers.contentType = ContentType.json;
    if ((req.contentLength) > UserSources.maxBytes) {
      res.statusCode = HttpStatus.requestEntityTooLarge;
      res.write(jsonEncode({'ok': false, 'message': 'Liste çok büyük (en çok 50 MB).'}));
      return;
    }
    final body = jsonDecode(await utf8.decodeStream(req)) as Map<String, Object?>;
    final name = (body['name'] as String?) ?? '';
    try {
      final s = switch (body) {
        {'url': final String url} when url.trim().isNotEmpty => await sources.addUrl(
          name,
          url,
          origin: SourceOrigin.phone,
        ),
        {'text': final String text} => await sources.addText(name, text, origin: SourceOrigin.phone),
        _ => throw const SourceException('Adres ya da dosya gönderin.'),
      };
      res.write(jsonEncode({'ok': true, 'message': '"${s.name}" eklendi: ${s.count} kanal.'}));
    } on SourceException catch (e) {
      res.statusCode = HttpStatus.badRequest;
      res.write(jsonEncode({'ok': false, 'message': e.message}));
    }
  }

  /// Telefonda açılan sayfa (Türkçe, koyu tema, tek dosya).
  static const _page = r'''<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>RedoX TV · Liste ekle</title>
<style>
:root{color-scheme:dark}
body{margin:0;font-family:system-ui,sans-serif;background:#0B0B20;color:#E2DFFD}
main{max-width:520px;margin:0 auto;padding:24px 16px}
h1{font-size:22px;margin:0 0 4px}p{color:#E5BDBA;margin:0 0 20px}
label{display:block;font-weight:600;margin:16px 0 6px}
input{box-sizing:border-box;width:100%;padding:12px;border-radius:12px;border:1px solid #5C403D;background:#1D1D33;color:#E2DFFD;font-size:16px}
button{margin-top:20px;width:100%;padding:14px;border:0;border-radius:999px;background:#D7232C;color:#fff;font-size:16px;font-weight:700}
.or{text-align:center;color:#AC8885;margin:18px 0 0}
#msg{margin-top:18px;padding:12px;border-radius:12px;display:none}
.ok{background:#1E3A2A}.err{background:#4A1418}
</style></head><body><main>
<h1>RedoX TV'ye liste ekle</h1>
<p>Liste TV'de Kaynaklar'a klasör olarak eklenir.</p>
<form id="f">
<label for="name">Ad (isteğe bağlı)</label>
<input id="name" placeholder="Örn. Spor listem">
<label for="url">Liste adresi</label>
<input id="url" type="url" inputmode="url" placeholder="https://.../liste.m3u">
<div class="or">ya da</div>
<label for="file">Telefondaki M3U dosyası</label>
<input id="file" type="file" accept=".m3u,.m3u8,audio/x-mpegurl,application/x-mpegurl,text/plain">
<button type="submit">TV'ye gönder</button>
</form>
<div id="msg"></div>
</main><script>
const q=location.search;
document.getElementById('f').onsubmit=async e=>{
 e.preventDefault();
 const msg=document.getElementById('msg');
 const body={name:document.getElementById('name').value};
 const f=document.getElementById('file').files[0];
 if(f){body.text=await f.text();}else{body.url=document.getElementById('url').value;}
 msg.style.display='block';msg.className='';msg.textContent='Gönderiliyor…';
 try{const r=await fetch('/ekle'+q,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  const j=await r.json();msg.className=j.ok?'ok':'err';msg.textContent=j.message;}
 catch(_){msg.className='err';msg.textContent='TV\'ye ulaşılamadı. Aynı Wi-Fi ağında olun.';}
};
</script></body></html>''';
}
