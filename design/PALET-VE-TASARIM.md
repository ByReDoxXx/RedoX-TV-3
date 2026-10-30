# RedoX TV 3.0 — Palet ve Tasarım Dili ("Kızıl Halka", Material 3 Expressive)

Kaynak: `assets/brand/redox-logo-source.jpg` (yeni logo). Vektör: `assets/brand/redox-logo.svg`. Makine okunur karşılığı: `design/tokens.json`.

## 1. Yöntem

Renkler tahminle değil, logo görselinden **piksel ölçümüyle** alındı (bölge bazlı baskın renk kümeleri). Ölçülemeyen yüzey kademeleri ölçülen zeminden **türetildi**; `tokens.json` içinde her renk `measured` / `derived` diye işaretlidir.

## 2. Ölçülen marka renkleri

| Ad | Hex | Logodaki yeri |
|---|---|---|
| Kızıl | `#E11D3C` | "RedoX" yazısı, boynuzlar |
| Koyu kızıl | `#B11229` | boğa yüzü gölgesi |
| Şarap | `#820E26` | yazı gölgesi |
| En koyu kızıl | `#6B0F26` | yüzün en koyu tonu |
| Mercan | `#F96D54` | boğa yüzünün aydınlık tarafı |
| Altın | `#E5AF53` | "TV" yazısı |
| Parlak altın | `#F8E286` | halka parlaması |
| Orta altın | `#E2B156` | boynuz kenarı |
| Bronz | `#C98234` | "TV" gölgesi |
| Zemin | `#0F1126` | yan zemin (üstte `#1E3755` parıltı, altta `#060B1F`) |

Yeni logo eskisinden farklı: kızıl `#F22144`→`#E11D3C`, altın `#F0BE5E`→`#E5AF53`, zemin daha mavi.

## 3. Roller (M3 Expressive eşlemesi)

| Rol | Renk | Kural |
|---|---|---|
| primary | Kızıl | Eylem, CANLI rozeti, düğme dolgusu (beyaz yazı) |
| primaryContainer | Koyu kızıl | Basılı/seçili dolgu |
| tertiary | Altın | Favori, ilerleme, vurgu |
| odak halkası | Parlak altın | TV/masaüstü odağı: 3 dp halka |
| küçük kırmızı yazı | Mercan | Kart üzerinde küçük kırmızı metin |
| zemin / kart | `#0F1126` / `#1A1F36` | AMOLED seçeneği: `#060B1F` |

M3 Expressive tercihleri: renk varyantı **Expressive**; büyük yuvarlak şekiller (kart 28 dp, öğe 16 dp, çip/düğme tam yuvarlak); seçili durumda şekil dönüşümü; kısa yay geçişleri. **Sonsuz animasyon yok** (zayıf TV işlemcileri).

## 4. Kontrast (hesaplanmış, WCAG; testle korunuyor)

| Çift | Oran | Karar |
|---|---|---|
| Ana metin / zemin | 16,93:1 | Geçer |
| Ana metin / kart | 14,77:1 | Geçer |
| İkincil metin / kart | 8,70:1 | Geçer |
| Üçüncül metin / kart | 5,42:1 | Geçer |
| Altın / zemin | 9,38:1 | Geçer |
| Altın / kart | 8,19:1 | Geçer |
| Parlak altın halka / kart | 12,54:1 | Odak halkası net |
| Beyaz / kızıl `#E11D3C` | 4,73:1 | Geçer: düğme dolgusu |
| Beyaz / koyu kızıl `#B11229` | 7,03:1 | Geçer |
| Mercan / kart | 5,68:1 | Geçer: küçük kırmızı yazı |
| Kızıl / zemin | 3,94:1 | Yalnızca simge, büyük metin (≥ 3:1) |
| Kızıl / kart | 3,44:1 | **Küçük metinde yetmez**, mercan kullan |
| Kızıl / parlak altın (yan yana) | 3,65:1 | Sınırda; odak ayrımı renge değil **halka şekline** dayanır |

## 5. Cihaza göre tasarım kuralları

| Konu | TV | Tablet | Telefon | Masaüstü |
|---|---|---|---|---|
| Gezinti | Daralmış ray; odaklanınca açılır, odak ayrılınca kapanır | Ray | Alt çubuk | Ray; hover ile açılır |
| Arama | Başlıkta giriş kutusu | Giriş kutusu | Simge | Giriş kutusu |
| Etkileşim | D-pad: yön, OK, Geri, Menü. **Renkli tuş yok** | Dokunma | Dokunma | Fare + klavye |
| Yazı alt sınırı | 14 sp | 12 sp | 12 sp | 12 sp |
| Dokunma hedefi | – | ≥ 48 dp | ≥ 48 dp | ≥ 32 dp |

Simgeler ve logolar **SVG**; emoji yok.

## 6. Logo SVG (`assets/brand/redox-logo.svg`)

Yüklenen JPEG, beyaz köşeler **saydam** yapıldıktan sonra `vtracer` 0.6.15 ile otomatik izlenerek vektöre çevrildi (1000×1000 `viewBox`, ~800 KB, ~2100 yol). Bu **izleme**dir, elle çizilmiş vektör değildir:

- Işıma, kıvılcım ve zemin gradyanı düz renk katmanlarıyla yaklaşıklanır; orijinalden daha mat görünür.
- Yeniden izleme, bu ayarlar için `design/` içinde belgelenmemiştir; gerekirse yeniden üretmek için kaynak JPEG'den aynı araçla yapılır.
- Dosya ağır: TV'de ana ekranda her karede çizmek yerine **açılış/giriş ekranında** kullan; uygulama içi küçük işaret için ayrı, sade bir vektör işaret (boğa + halka + yazı) elle çizilmelidir.

## 7. Açık noktalar

- **A1.** Uygulama simgesi (launcher), Android 13 temalı tek renkli simge ve TV afişi henüz üretilmedi; sade işaret gerektirir.
- **A2.** Yazı tipi: Stitch'te Google Sans Flex seçildi; Flutter'a gömmek için lisansı doğrulanmadı, yedek Roboto Flex.
- **A3.** Türetilmiş yüzey kademelerinden yalnızca `surface` (kart) kontrast hesabına girdi.
- **A4.** Stitch Anasayfa taslağında "KIRMIZI TUŞ" ipucu var: Chromecast kumandasında renkli tuş yok, kaldırılmalı. Taslaktaki kanal adları, puanlar, süreler ve kapaklar örnek içeriktir, gerçek veri değildir.

## 8. Tonal palet (M3 / HCT)

`dart run tool/generate_tonal_palette.dart` ölçülmüş tohumlardan (kızıl `#E11D3C`, şarap `#820E26`, altın `#E5AF53`, zemin `#0F1126`) altı tonal palet (primary, secondary, tertiary, neutral, neutralVariant, error; 24 ton) ve koyu/açık rol eşlemesi üretir. Çıktılar: `design/tonal-palette.json`, `lib/core/theme/redox_tonal.dart` (elle düzenlenmez). Pano: `design/tonal-panosu.png`.

- Marka çıpası: `primary` (kızıl), `tertiary` (altın, koyu temada) ve koyu `surface` ölçülen renkle **birebir**; M3'ün varsayılan koyu `primary`si (ton 80, pastel) yerine canlı marka kızılı kullanılır.
- Araç, rol çiftlerinde kontrast eşiğini (metin ≥ 4,5:1, çerçeve ≥ 3:1) sağlayamazsa **çıktı yazmadan hata verir**; aynı kapılar `test/core/theme/redox_roles_test.dart` içinde Dart tarafında da doğrulanır.
- Tema yalnızca **koyu** rolleri kullanır; açık rol eşlemesi üretilir ama uygulamaya bağlı değildir.

Bilinen riskler:
- **Error ile marka kızılı birbirine yakın** (koyu: `errorContainer #93000A` ↔ `primaryContainer #BF002C`). Hata durumu yalnızca renkle değil, simge ve metinle de gösterilmeli.
- **Secondary, primary ile aynı ailede** (ton farkı dışında ayırt edilmiyor); gerçek bir ikinci renk ailesi gerekiyorsa tohum değişmeli.
- Nötr tohum (`#0F1126`) mor-lacivert eğilimli (H282); metin tonları hafif lavanta görünür.
