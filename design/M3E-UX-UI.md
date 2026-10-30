# RedoX TV 3.0 — Material 3 Expressive: Yazı Tipi, Şekil, Hareket, Bileşenler

Her değer **kaynaktan okundu**; tahmin yoktur. Kaynak sütunu "doğrulama" durumunu gösterir.

## 1. Yazı tipi

| Karar | Değer | Doğrulama |
|---|---|---|
| Ana yazı tipi | **Google Sans Flex** (değişken) | `google/fonts` deposu `ofl/googlesansflex`: lisans **OFL**, eksenler `ROND` 0–100, `opsz` 1–144, `slnt` −10–0, `wdth` 25–151, `wght` 1–1000 |
| Yedek | **Roboto Flex** (OFL) | Android Wear belgeleri: Material 3 Expressive, Roboto'yu Roboto Flex ile değiştirir |
| Türkçe | ç Ç ğ Ğ ı İ ö Ö ş Ş ü Ü â Â î Î û Û | Yazı tipi dosyasının karakter tablosu okundu: **eksik yok** |
| Sabit genişlikli rakam | `tnum` özelliği var | Yazı tipi GSUB tablosu okundu |
| Kanal numarası, saat, EPG saatleri | Aynı yazı tipi + `tabularFigures` (monospace **yok**) | Kod: `M3EType.tabularFigures` |
| `ROND` ekseni | 0 (keskin) | **RedoX kararı**: boğa logosu açısal; resmi bir kural değildir |

Not: androidx'in `TypefaceTokens` dosyasında marka yazı tipi `FontFamily.SansSerif`'tir; yani M3E yazı tipini **sistem belirler**, Google Sans Flex bir RedoX tercihidir. Yazı tipi henüz pakete **eklenmedi** (3,9 MB, OFL metni ile eklenecek).

### Yazı ölçeği (androidx `TypeScaleTokens`)
| Stil | Boyut/Satır | Baz ağırlık | Vurgulu ağırlık |
|---|---|---|---|
| displayLarge / Medium / Small | 57/64, 45/52, 36/44 | 400 | 500 |
| headlineLarge / Medium / Small | 32/40, 28/36, 24/32 | 400 | 500 |
| titleLarge | 22/28 | 400 | 500 |
| titleMedium / Small | 16/24, 14/20 | 500 | **700** |
| labelLarge / Medium / Small | 14/20, 12/16, 11/16 | 500 | **700** |
| bodyLarge / Medium / Small | 16/24, 14/20, 12/16 | 400 | 500 |

İzleme (letter spacing) değerleri kodda: `lib/core/theme/m3e_tokens.dart` → `M3EType`.

**TV (RedoX kararı, M3 resmi TV ölçeği vermez):** en küçük yazı bodyMedium 14; kart başlığı titleMedium **vurgulu**; bölüm başlığı headlineSmall vurgulu; kanal numarası labelLarge vurgulu + tabular.

## 2. Şekil (androidx `ShapeTokens`)
none 0 · extraSmall 4 · small 8 · medium 12 · large 16 · **largeIncreased 20** · extraLarge 28 · **extraLargeIncreased 32** · **extraExtraLarge 48** · full (tam yuvarlak). Kalın yazılanlar Expressive'e özgü yeni basamaklardır.

RedoX eşlemesi: kart = extraLarge 28 · öğe = large 16 · çip/düğme = full · büyük hero kart = extraExtraLarge 48 · odak halkası 3 dp parlak altın.
Expressive'in şekil **dönüşümü**: `ButtonDefaults` içinde `pressedShape`/`checkedShape` (androidx `Button.kt`) vardır; basılı/seçili düğmenin köşesi değişir. Flutter'da bu davranış **kendimiz** yazılır (bkz. §4).

## 3. Hareket (androidx `ExpressiveMotionTokens`, `MotionTokens`)
| Yay | Sönümleme oranı | Sertlik |
|---|---|---|
| Uzamsal hızlı | 0,6 | 800 |
| Uzamsal varsayılan | 0,8 | 380 |
| Uzamsal yavaş | 0,8 | 200 |
| Etki hızlı / varsayılan / yavaş | 1,0 | 3800 / 1600 / 800 |

Uzamsal yaylar (konum, boyut, şekil) hafif **aşım** yapar; etki yayları (opaklık, renk) yapmaz. Süreler: short 50–200 ms, medium 250–400, long 450–600, extraLong 700+. Eğriler: emphasized `(0.2, 0, 0, 1)`, emphasizedAccelerate `(0.3, 0, 0.8, 0.15)`, emphasizedDecelerate `(0.05, 0.7, 0.1, 1)`.
Flutter eşlemesi: `SpringDescription.withDampingRatio(mass: 1, stiffness: …, ratio: …)` (SDK'da doğrulandı). Compose yayı kütleyi 1 varsayar (**varsayım**, birebir eşleme bu varsayıma dayanır).

**RedoX kuralı:** TV odak geçişi uzamsal hızlı; kart büyümesi uzamsal varsayılan; renk/opaklık etki varsayılan. **Sonsuz animasyon yok.**

## 4. Bileşenler: M3 Expressive ve Flutter durumu
androidx'te Expressive bileşenler: `ButtonGroup`, `SplitButton`, `ToggleButton`, `FloatingActionButtonMenu`, `FloatingToolbar`, `LoadingIndicator`, `WideNavigationRail`, `ShortNavigationBar`, `MaterialShapes`, `Carousel`, genişletilmiş `ListItem`.

Flutter 3.47.9 `material` kütüphanesinde **var**: `NavigationRail`, `SegmentedButton`, `Chip`/`FilterChip`, `Card`, `SearchAnchor`/`SearchBar`, `CarouselView`, `NavigationDrawer`. **Yok** (dosya listesi okundu): ButtonGroup, SplitButton, FAB menüsü, LoadingIndicator, WideNavigationRail, FloatingToolbar. Bunlar `lib/core/ui/` altında **kendi** bileşenlerimiz olarak yazılacak; üçüncü taraf "m3e" paketleri resmi olmadığı ve sürümleri doğrulanmadığı için kullanılmayacak.

| RedoX ekranı | Bileşen |
|---|---|
| Menü (açılıp kapanan ray) | WideNavigationRail benzeri (özel): odak/hover ile genişler |
| Kategori çipleri | FilterChip (tam yuvarlak) |
| Kanal / film / dizi kartları | Card (28) + odakta halka + uzamsal yay |
| Anasayfa story sırası | Özel yatay liste (halkalı yuvarlak) |
| Dizi sezon seçimi | SegmentedButton veya ButtonGroup (özel) |
| Radyo oynat/duraklat | ToggleButton (şekil dönüşümlü, özel) |
| Yükleniyor | LoadingIndicator benzeri (özel, sonsuz değil: ilerleme ya da tek seferlik) |
| Filmler vitrin | CarouselView |

## 5. Kaynaklar
- androidx Material3 token kaynakları: `androidx/androidx` → `compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/` (`ShapeTokens.kt`, `ExpressiveMotionTokens.kt`, `MotionTokens.kt`, `TypeScaleTokens.kt`, `TypefaceTokens.kt`).
- Yazı tipi: `google/fonts` → `ofl/googlesansflex/METADATA.pb`, `OFL.txt`.
- Android Wear Material 3 Expressive dil belgesi (Roboto Flex).
- m3.material.io sayfaları JavaScript ile çizildiği için okunamadı; **resmi sitedeki yazılı şartnameye karşı** ayrıca doğrulanmadı.

## 6. Ekran: TV 4K
Hedef TV paneli **4K UHD, 3840×2160 piksel**. Android TV 4K cihazlarda arayüz genellikle 2× yoğunlukla **1920×1080 dp** mantıksal boyutta çizilir (bu yoğunluk varsayımdır, gerçek cihazda doğrulanmadı). Sonuçlar:
- Tüm ölçüler dp/sp cinsindendir; piksel karşılığı iki kattır (14 sp yazı = 28 px, 28 dp köşe = 56 px, 3 dp odak halkası = 6 px).
- Flutter'da yerleşim mantıksal piksel üzerinden kurulur; sabit piksel kullanılmaz.
- Rasterleşmiş görseller (kapaklar, kanal logoları) en az 2× keskinlikte olmalı; logo ve simgeler SVG olduğu için ölçekten etkilenmez.
- Stitch taslakları 3840×2160 tuvalde, "2× yoğunluk" notuyla üretilir.
