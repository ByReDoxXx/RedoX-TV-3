import 'package:flutter/widgets.dart';

/// Görselin belleğe açılacağı boyut (piksel): ekranda kapladığı kadar. Listeden
/// gelen afişler 2000×3000 olabilir (24 MB); küçültülmezse zayıf TV'nin grafik
/// belleği dolar (Philips: 1,1 GB'ta sistem uygulamayı kapattı; günlükte görüldü).
int decodedSize(BuildContext context, double logical) =>
    (logical * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, maxDecodedSize);

/// Tek görselin en büyük kenarı: 4K ekranın yarısı, kartlar için fazlasıyla yeter.
const maxDecodedSize = 1920;
