# DESIGN.md uygulama kararları

Tek kaynak: [`DESIGN.md`](DESIGN.md) ("RedoX TV Expressive"; kullanıcının verdiği dosya, değiştirilmeden kopyalandı). Bu belge spec'in Flutter'a nasıl çevrildiğini, spec içindeki çelişkileri ve her seçimin gerekçesini kaydeder. Her sayısal iddianın testi parantez içinde.

Görsel ilham: kullanıcının verdiği Stitch Anasayfa ekranı (`stitch_redox_tv_brand_identity.zip` içindeki `screen.png` ve `code.html`). Zip'teki `DESIGN.md`, bu dosyayla birebir aynıdır (SHA-256 `cc8ac372…`). Ekrandan alınanlar:
- 96 → 288 dp açılan ray, bölüm renkli ikonlar
- Hap arama kutusu
- Durum hapları
- Dikey çizgili bölüm başlığı
- Kart / EPG anahtarı
- Isıl ilerleme çubuğu
- Kanal kartı düzeni
- Vitrin hâlesi
- "OK" tuş ipucu

## 1. Birim ve tuval

- **1 spec px = 1 dp.** CSS pikseli ve Android dp ikisi de yoğunluktan bağımsız referans birimdir. rem = 16 px.
- **TV tuvali 960×540 dp** (`RedoxMetrics`, `PageLayout`). Kaynak: Android TV tasarım rehberi (developer.android.com/design/ui/tv/guides/styles/layouts): "Always design at MDPI resolution at 960px × 540px", "At MDPI 1px = 1dp". Önceki "1920×1080 dp" varsayımı yanlıştı ve kaldırıldı.
  - 1080p arayüzde 1 dp = 2 px, 4K arayüzde 1 dp = 4 px olur. Bu oranlar sayfadan çıkarımdır, cihazda ölçülmedi.
  - Bazı kutular 1080p'de 240 dpi kullanır; bu durumda tuval 1280×720 dp olur. Yerleşim genişliğe göre hesaplanır, sabit değildir.
- **TV kenarları** (`RedoxSpace`):
  - Yatay: spec'in `margin-tv` değeri, 64 dp.
  - Dikey: 27 dp. Spec'in 64'ü 540 dp yükseklikte %24 eder. Android TV'nin %5 taşma kuralı 540 × 0,05 ≈ 27 dp verir.

## 2. Renk

### Palet: Logo-2'den türetme (2026-10-31)

Kullanıcı paletin Logo-2'ye göre revize edilmesini istedi. Logo-2, ilk logoyla aynı çizimdir (piksel hizalı, en iyi kayma 0,0); fark zemindedir: lacivert yerine saf siyah.

**Tohumlar logodan ölçüldü** (`RedoxSeeds`; 2048 px görsel, 1024 px'e ölçeklenip boğa ve halka bölgesinde):

| Tohum | Değer | Ölçüm |
|---|---|---|
| Crimson Flame (primary) | `#D82131` | Kızıl aile (ton 340°–12°, doygunluk ≥ 0,55) içinde, iki kısıtı sağlayan piksellerin medyanı (aşağıda) |
| Molten Amber (secondary) | `#ED9650` | Turuncu aile (12°–32°), parlak (V ≥ 0,85) piksellerin medyanı: kıvılcım ve parlama |
| Incandescent Gold (tertiary) | `#F6BD58` | Altın aile (32°–58°), parlak piksellerin medyanı: halka ve "TV" |
| Obsidian Void (nötr) | `#000000` | Logonun zemini (köşe ve kenar örnekleri `#000000`/`#010101`) |

**Kızıl için iki kısıt.** Logonun en sık kızılı `#D51931` kartta 3:1'in altında kalıyordu; en parlak kızılı `#E6313A` ise beyaz yazıyı 4,5:1'in altına düşürüyordu. Bu yüzden kızıl, şu iki koşulu birlikte sağlayan logo piksellerinin medyanıdır:
- Beyaz düğme yazısı ≥ 4,5:1 olmalı.
- Odak halkası kartta (`#1F1F1F`) ≥ 3:1 olmalı.

**Roller M3 sadakat (fidelity) şemasıyla hesaplanır** (`RedoxTonal`, `RedoxRoles`). Bu Stitch'in yöntemidir. Kanıt:
- Eski tohumlar (`#E61638 #FF9E1B #FFD54F #0D0E11`) bu şemayla ilk DESIGN.md'nin 44 rolünü **birebir** üretti (0/44 fark).
- Yeni roller aynı hesapla üretildi ve DESIGN.md YAML'ına yazıldı.
- `redox_roles_test.dart`, 44 rolün `RedoxTonal.scheme` ile eşleştiğini denetler.

**Tuval saf siyah.** Scaffold zemini nötr tohumdur (`#000000`, paletin T0'ı).
- M3'ün `surface-container-lowest` rolü T4 (`#0E0E0E`) olarak kalır.
- Düzyazının "true-black OLED baselines" ilkesiyle ve logonun zeminiyle uyumludur.

**Sonuçlar** (`redox_contrast_test.dart`):

| Çift | Oran |
|---|---|
| Beyaz / kızıl `#D82131` | 5,02:1 |
| on-primary-container `#FFF0EF` / kızıl | 4,53:1 |
| Kızıl odak halkası tuvalde / lowest'ta / kartta | 4,18 / 3,84 / 3,28:1 |
| Siyah / amber (cam düğme odağı) | 9,08:1 |
| Beyaz / amber | 2,31:1; çip ucu olamaz |

**Seçili çip ucu (kor).** Kullanıcının "Kor kalsın" kararı korunur: uç, amber paletinin beyazla 4,5:1'i sağlayan en açık tonudur.
- Yeni palette yine T49'dur: `#AC6220`.
- T49 4,64:1, T50 4,50:1'in altında (4,498).

**Isıl degrade.** Sadakat şemasında amber kabı koyu çıkar (`#884500`): izde 2,66:1, yani 3:1'in altında.
- **Karar:** Degrade tohumlarla çizilir: kızıl → amber `#ED9650` → altın `#F6BD58`.
- İzde sırasıyla 3,84 / 8,35 / 11,34:1.

**Kızıl yazı kuralı.** Kızıl kartta 3,28:1 verir, bu yüzden küçük yazıda kullanılmaz.
- Vurgulu metinlerde `primary`, `secondary`, `tertiary` rolleri kullanılır; kartta hepsi ≥ 4,5:1.

**İlerleme izi.** Kızıl dolgu en yüksek kapta (`#353535`) 2,44:1 kalır.
- **Karar:** İz `surface-container-lowest`'tır (`#0E0E0E`).

**Düzyazının yüzey merdiveni** (`#08090B #121418 #181A20 #22252C #2C3039`) hiçbir tohumdan türemez ve kullanılmaz (ilk sürümdeki "Çelişki 1" kararı değişmedi).

## 3. Yazı

- **Sora** (`RedoxType`; OFL, google/fonts `ofl/sora`), değişken yazı tipi, wght 100–800. fontTools ile doğrulandı:
  - Türkçe harflerin hepsi var.
  - `tnum` var: tüm rakamlar 676 birim.
  - `₺` ve `→` glifleri **yok**. Görünen metinde `→` yerine `–` kullanılır.
- **14 belirteç** birebir alındı. em cinsinden izleme, Flutter'da `em × boyut` olarak verilir (`redox_type_test.dart`).
- **M3 yuvaları:**
  - displayMedium, displaySmall ve titleSmall'ın spec'te karşılığı yok. Flutter bunları M3 tabanından doldurur; aile yine Sora. Uygulamada kullanılmazlar.
  - Telefonda `-mobile` belirteçleri kullanılır.
- **TV'de en küçük yazı 16** (spec kuralı). Spec'in kendi çip ve rozet tarifleri 10–12 boyutunda yazı içerir; genel kural öncelikli sayıldı.
  - TV'de 16'nın altındaki stiller 16'ya çıkar.
  - Satır yüksekliği title-md'nin satırı olur.
  - Ağırlık ve em izleme korunur.

## 4. Şekil, boşluk, derinlik

- **Köşeler** (`RedoxRadius`): 4 / 8 / 12 / 16 / 24 / tam. **Boşluk** (`RedoxSpace`): 4 / 8 / 16 / 24 / 40, oluk 24 (TV 48), kenar 24 (TV 64).
- **Odak:**
  - Büyüme: TV 1.08, masaüstü ve tablet 1.04, birincil düğme 1.06.
  - Yay: M3E `spatialFast` (`M3EMotion`; sertlik 800, sönüm 0,6).
- **Odak halkası** (`FocusGlow`, `RedoxElevation`): 2 dp kızıl çizgi + aura (0 8 32, kızıl %40) + ışıma (0 16 64, amber %20).
- **Çelişki 4 – ışıma değerleri.** "Focus & Kinetic Glow" bölümü %45 / %25 ve iç vurgu veriyor; "Focus Elevation" bölümü ofset ve bulanıklıkla birlikte %40 / %20.

  **Karar:** Ölçüleri tam olan "Focus Elevation" değerleri kullanılır. Flutter'da iç gölge yoktur.
- **CSS bulanıklığı → Flutter:**
  - CSS'te sigma = blur / 2. Flutter'da sigma = r × 0,57735 + 0,5.
  - `cssBlur(px)` bu iki formülü eşitler (`redox_type_test.dart`).
- **Halka ofseti 2 dp.** Spec ofset vermez. Kızıl düğmenin etrafındaki kızıl halka görüntüde seçilmiyordu; M3 odak göstergesindeki gibi 2 dp boşluk eklendi.
- **Hayalet kenar** `rgba(255,255,255,.08)`. **Cam düğme** %10 dolgu ve %15 kenar; odakta amber zemin ve siyah yazı (9,08:1).
- **Vitrin hâlesi.** Spec'teki "Chromatic Backlight Flares" ve zip'teki hero: arkada kızıl ve amber bulanık ışık.

## 5. Bileşen yorumları

- **Gezinme rayı: M3 Expressive (`RedoxNavRail`; kullanıcı isteği, 2026-10-31).** Kullanıcı eski rayı beğenmedi ve M3 Expressive istedi.
  - Spec'teki "sol kenara yaslı asimetrik hap" M3E ile çelişir. **Karar: M3E.**
  - Ölçü ve renkler, Compose Material 3 belirteç dosyalarından okundu (androidx `NavigationRailCollapsedTokens`, `…ExpandedTokens`, `…VerticalItemTokens`, `…HorizontalItemTokens`, `…ColorTokens`). m3.material.io sayfası metin olarak okunamadı.
  - **Daralmış:** 96 dp, `surface`; gösterge 56 × 32 dp hap; öğe arası 4 dp; üst boşluk 44 dp.
  - **Açık:** modal genişletilmiş ray. Genişlik 256 dp (spec 220–360); `surfaceContainer`; uç köşeler 16 dp (CornerLarge); seviye 2 gölge. Öğe 56 dp; ikon ve etiket yan yana (labelLarge, araları 8 dp); gösterge içeriği sarar (iç boşluk 16 dp).
  - **Renk:** gösterge `secondaryContainer`, etkin ikon `onSecondaryContainer`, etkin etiket `secondary`, edilgen ikon ve etiket `onSurfaceVariant`. Durum katmanı `onSecondaryContainer`: %8 üstüne gelme, %10 odak ve basma.
  - Bölüm başına renkli ikonlar kaldırıldı; M3E rayında ikonlar tek renktir.
  - Gösterge sol kenarı iki durumda da 20 dp'dedir; açılırken ikon yerinden oynamaz.
  - **Etiketler:** M3E daralmış rayda etiket ikonun altındadır (labelMedium).
    - TV'de (540 dp) 9 öğe etiketle sığmaz: 44 + 9 × (66 + 4) dp. Bu yüzden etiketler yalnızca yükseklik yettiğinde gösterilir (`LayoutBuilder` ile ölçülür).
    - TV'de daralmış ray yalnızca ikondur; etiketler ray odakla açılınca görünür.
  - **Menü düğmesi** (M3E'de isteğe bağlı) TV dışında gösterilir. Dokunmatikte rayı açar ve açık tutar; TV'de açma odakla olur.
  - **Odaktaki öğe açılır (kullanıcı isteği):** odak (D-pad) veya fare üstündeki öğe sağa doğru açılıp adını gösterir; ayrılınca kapanır. Ray daralmış kalır, hap içeriğin üstüne taşar. Seçili değilse hap `surfaceContainerHighest` zeminle yüzer. Bütün ray menü düğmesiyle açılır.
  - **Raya girişte seçili öğe (kullanıcı isteği):** D-pad ile raya dışarıdan girilince odak en yakın öğeye değil, seçili bölüme gider. Örneğin vitrin düğmesinden sola basınca Kaynaklar yerine Anasayfa odaklanır. Ray içinde yukarı/aşağı geçişler değişmez. Kanıt: `home_page_test.dart` (sol → Anasayfa, aşağı → Televizyon, sağ → içerik) ve TV emülatörü.
  - Açık hapın 96 dp dışında kalan kısmı fareyle tıklanmaz (Flutter isabet testi rayın sınırında biter); ikon alanı tıklanır, TV'de seçim OK tuşuyladır.
  - Seçili öğe dinlenirken parlamaz; parıltı ve halka yalnızca odaktadır (halka ölçeği 1, büyüme yok).
  - Açık rayda ana öğeler kaydırılır (TV'de 9 × 56 dp sığmaz). Kaydırma alanı keser; odak halkası için 4 dp pay bırakılır.
  - Kanıt: `test/core/ui/nav_rail_test.dart` (konumlar, gösterge ölçüsü ve rengi, menü düğmesi).
- **Telefon alt menüsü (`RedoxBottomBar`; kullanıcı isteği, 2026-10-31).** Telefonda ray yoktur. Ray 411 dp ekranın dörtte birini alıyordu; emülatörde kartlar ve yazılar kesildi. Yerine alt menü gelir.
  - Sıra: TV · Radyo · Film · Dizi · Favori. Beş öğe (M3 sınırı).
    - Anasayfa çubukta yoktur; başlıktaki logoya dokununca gidilir (kullanıcı isteği). Anasayfadayken hiçbir öğe seçili değildir.
    - Kumanda çubuktan alındı; önce başlığa, sonra "Diğer" sayfasına taşındı (kullanıcı isteği: başlıkta göze batıyordu).
    - Önceki denemeler: ortada kızıl yuvarlak Anasayfa düğmesi ve 7 öğe. Kullanıcı isteğiyle kaldırıldı.
    - 360 dp'de yuva 72 dp olur; gösterge 56 dp sığar.
  - Ölçüler M3E kısa gezinme çubuğundan alındı: 64 dp, `surfaceContainer`, gösterge 56 × 32 hap, üst 6 dp, ikon–etiket arası 4 dp.
  - 2x2 Ekran (eski adı "Bölünmüş ekran"; kullanıcı isteğiyle değişti), Kaynaklar, Kumanda ve Ayarlar alt menüye sığmaz. Başlıktaki "Diğer" düğmesiyle açılan M3 modal alt sayfadadırlar.
  - Telefon başlığı: logo (Anasayfa) · Arama · Diğer.
  - **Telefon vitrini (kullanıcı isteği: düğmeler küçük ve yan yana):**
    - İç boşluk 20 dp (M3 kart boşluğu).
    - Tek satırda: "Canlı yayına gir" hap düğmesi, ardından 40 dp yuvarlak, yalnız ikonlu iki cam düğme ("Çoklu ekrana ekle", "Yayın akışı"). Adları ipucu ve ekran okuyucu etiketidir.
    - Üç etiketli düğme 360 dp'de sığmaz (~465 dp gerekir, ~272 dp yer var). 360 dp'de birincil düğme gerekirse orantılı küçülür.
    - Telefonda "OK" tuş ipucu yoktur; telefonda kumanda yoktur.
  - **Telefon aralıkları (kullanıcı isteği):** raf kartları arası 24 → 12 dp (M3 sıkı yerleşim 8–16 dp). Hikâye halkaları arası 12 dp; telefonda etiket 12 sp olduğu için yeter. Saat ve profil yoktur: emülatörde ekran dışına taşıyordu, saat zaten durum çubuğunda.
  - Raflar telefonda kesirli kart sayısıyla gösterilir (2,3 / 1,15 / 3,3). Sağda kartın ucu görünür, bu da rafın kaydığını belli eder.
  - Kanıt: `test/core/ui/bottom_nav_bar_test.dart` (360 ve 411 dp: eşit yuva, taşma) ve `home_page_test.dart` (telefonda taşma yok; logo başlıkta, Kumanda "Diğer" sayfasında).
- **Hikâye aralığı (kullanıcı isteği):** yuva = halka + 28 dp; halkalar arasında 28 dp boşluk kalır (48 → 36 → 28).
  - 20 dp denendi: emülatörde yan yana etiketler (~5 dp) birbirine değdi.
  - Etiketin iki yanında 4 dp pay vardır. Yuvaya sığmayan etiket ("Çoklu ekran", "QR kaynak") kesilmez, iki satıra iner. Satır üste hizalıdır, halkalar aynı hizada kalır.
- **TV raf aralığı (kullanıcı isteği):** kartlar arası 48 → 16 dp. Odaktaki kart 1,08 büyür ve 4 dp halka alır; 16 dp'de komşuya değmez.
- **Düğmeler küçüldü (`PrimaryButton`, `GlassButton`, `RedoxButtonSize`; kullanıcı isteği):**
  - Hap düğmeler 48 → 40 dp yükseklikte, yan boşluk 24 → 16 dp. Compose TV Material düğmesi ve M3 ortak düğmeler 40 dp'dir. Dokunmatikte isabet alanı 48 dp kalır.
  - TV ikon düğmesi 56 → 40 dp (Compose TV IconButton).
- **Başlık sırası (kullanıcı isteği):** logo · arama · profil · saat. Arama kutusu profile kadar uzanır (16 dp boşluk); saat en sağdadır. Kanıt: `home_page_test.dart`.
- **Arama kutusu iki kiplidir (`HeaderSearch`; TV emülatöründe görülen sorunlar üzerine):**
  - Sorunlar:
    - D-pad kutunun üstünden geçerken klavye kendiliğinden açılıyordu.
    - Tek satırlı alan sol/sağ tuşlarını tutuyordu.
    - Geri ilk basışta klavyeyi, ikincide uygulamayı kapatıyordu.
  - **Dinlenme kipi:** kutu odaklanabilir bir düğmedir; klavye açılmaz. **Yazma kipi:** OK (veya dokunma) ile açılır ve klavye gelir.
  - **Yazmayı bitirme:** klavyenin onay tuşu, Geri veya Esc yazmayı bitirir; odak kutuya döner, yazılan kalır.
  - TV'de Geri'nin ilk basışı klavyeyi kapatır (Gboard Geri'yi kendisi alır). İkinci basış yazmayı bitirir. Gboard TV'de ekran payı bildirmediği için klavyenin kapanması algılanamaz.
  - **Teknik not:** Android Geri'yi hem tuş hem "pop" olarak iletir. Tuşta yakalamak pop'u durdurmaz; emülatörde ikisi birden işledi.
    - Flutter 3.47'de `didPopRoute` gözlemcileri kayıt sırasıyla sorulur ve Navigator önce gelir.
    - Bu yüzden yazma kipindeki kutu, kök sayfa koruyucusuna (`DoubleBackToExit`) Geri işleyicisi olarak kaydolur.
- **Anasayfada Geri (`DoubleBackToExit`; kullanıcı isteği: doğrudan çıkmasın):** ilk basışta "Çıkmak için tekrar Geri'ye basın" uyarısı çıkar. 2 sn içindeki ikinci basış uygulamadan çıkar.
  - Kanıt: `test/core/ui/header_search_test.dart` ve TV emülatörü. Sırasıyla doğrulandı:
    - kutuya gelince klavye kapalı;
    - OK ile klavye açılıyor; "qw" yazıldı;
    - Geri: klavye kapanıyor;
    - Geri: yazma bitiyor, uyarı çıkmıyor;
    - Geri: uyarı çıkıyor;
    - iki hızlı Geri: uygulamadan çıkılıyor.
- **TV'de kumanda ipucu şeridi yok (kullanıcı isteği):** Altta "Gezin · OK Seç · Geri" şeridi denendi, sonra kaldırıldı. Kaydırma alanı ekranın altına kadar iner; alttaki bölüm başlığının ucu görünür, bu da sayfanın kaydığını belli eder. Düğmedeki "OK" tuş ipucu durur.
- **TV'de odak hep görünür:** Android'in varsayılan "touch" vurgu kipinde odak halkası ilk tuşa kadar gizliydi (emülatörde görüldü). TV'de `FocusHighlightStrategy.alwaysTraditional` kullanılır (`lib/main.dart`). Kanıt: emülatör, açılışta "Canlı yayına gir" halkalı; D-pad sol, ray öğesini açar.
- **Ray açılış eğrisi:** spec `cubic-bezier(0.2, 0, 0, 1)`; süre spec'te yok, M3 `medium4` = 400 ms seçildi.
- **Radyo düğmesi:** "obsidyen merkez, amber halka". Seçili radyo düğmesinin içi obsidyen, halka ve noktası amberdir.
- **Nabız atan nokta** (`StatusBadge`): spec süre vermez. Zip'teki `animate-pulse` değeri kullanıldı: 2 sn, opaklık 1 → 0,5. Sistem animasyonları kapalıysa nokta sabit kalır.
- **Medya kartı rampası** (`MediaCard`): spec'teki doğrusal rampa (alt üçte bir, %0 → %95). Çok açık afişlerde başlığın üst kısmı rampanın düşük opaklık bölgesine düşer. Bu yüzden rampa kontrastı **garanti etmez**. Gerçek afişlerle bakılıp gerekirse rampa başlangıcı yukarı çekilmeli; bu açık nokta olarak bırakıldı.
- **Televizyon sayfası (kullanıcı isteği, 2026-10-31).** Üstte sayılı kategori çipleri ve görünüm anahtarı, altta seçili görünüm. Kullanıcının Stitch referansından esinlenildi, aynısı değil. Teknik panel, numara tuş takımı ve ipucu şeridi alınmadı.
  - **Anahtar:** "Kart görünümü | EPG çizelgesi". İkonludur; seçili parça yalnız ikon, seçili olmayanın adı yazılı. Ağaç her durumda aynıdır; seçim değişince odak parçada kalır (emülatörde görüldü).
  - **Çip satırı kayar:** kaydırılabilen uçta "<" / ">" oku ve zemine solma çıkar. Kayma alanı sayfa kenarında başlar; ekran kenarından başlasaydı odakla kayan çip rayın altına girerdi. Odaktaki çip okun altında kalırsa satır ok payı kadar daha kayar.
  - **Kart görünümü:** TV/tablette 3 sütun ve sağda 280 dp önizleme paneli; telefonda 2 sütun, panel yok.
    - İlk OK/dokunma önizler (altın kenarlık), aynı kanalda ikincisi tam ekran açar. Önizleme odakla değişmez. Açılışta panelde yönerge durur.
    - **Önizleme canlı oynar (kullanıcı isteği):** ilk OK panelde yayını açar (`ChannelPreview`, kendi `PlaybackSession`'ı ile). Görüntü gelene kadar logo ve bekleme göstergesi, açılmazsa "Yayın açılamadı" durur. Görüntü yüzeyi baştan kurulur, logo üstünü örter: yüzey ancak "oynuyor"da kurulunca Android'de media_kit görüntüyü hiç çözmedi, panel sonsuza dek bekledi (gerçek TV'de görüldü, düzeltildi). Tam ekrana geçerken önizleme durur, dönünce yeniden başlar; kategori değişince ve sayfadan çıkınca durur.
    - **Odaktaki kart ortalanır (`CenterOnFocus`):** varsayılan odak kaydırması kartı kenara yaslıyordu; büyüyen kart ve halkası ızgaranın kenarında kesiliyordu (gerçek TV'de görüldü). D-pad odağında kart kayma alanının ortasına getirilir; dokunmatikte kaydırma yapılmaz.
    - Sık kart (`ChannelTile`, kullanıcının ikinci referansından): logo karosu, numara ve CANLI, kanal adı, program, ince ilerleme çizgisi. 16:9 görsel yoktur.
    - Kart yazıları 12/14 dp'dir. Bu, TV'nin 16 dp yazı tabanının bilinçli istisnasıdır (kullanıcı isteği: yazılar çok büyüktü). 960 dp tuvalde 12 dp, 1080p ekranda 24 px eder.
    - TV'de düğmelerin dokunma alanı büyütülmez (`MaterialTapTargetSize.shrinkWrap`). 40 dp düğmeler 48'e çıkmaz, böylece panel düğmeleri 540 dp'ye sığar.
  - **EPG çizelgesi:** solda kanal sütunu, sağda zaman ekseni ve kızıl "şimdi" çizgisi. Yatay kaydırma yoktur: pencere genişliğe sığan, yarım saatin katı uzunluktadır ve şimdiden 30 dk önce başlar. Dar blokta saat (100 dp altı) ve başlık (44 dp altı) yazılmaz. Programa OK o kanalı açar. Saatler "şimdi"nin günbaşından dakikadır (gece yarısını geçen program 1440'ı aşar). Akışı olmayan kanalda tek soluk blok "Yayın akışı bilgisi yok" yazar (`EpgProgram.unknown`), şimdi çizgisi ve ilerleme çizilmez.
  - **Tam ekran:** `PlayerPage` açılır; ▲▼ kategori süzgecinden bağımsız bütün kanallarda gezer (`RootShell`).
  - Bileşenler: `TvPage`, anahtar `SegmentedToggle`, çip satırı `ScrollHintRow` + `CategoryChip`, kart `ChannelTile`, panel `ChannelPreview`, çizelge `EpgGrid`.
  - Kanıt: `test/features/tv/tv_page_test.dart` (4K görüntüler `build/tv/televizyon-4k.png`, `epg-4k.png`, gerçek listeyle `televizyon-gercek-4k.png`, `epg-gercek-4k.png`). TV emülatöründe sırayla doğrulandı: OK → önizleme → OK → tam ekran → Geri → anahtar → EPG → çizelgede gezinme.
- **Kanal listesi (kullanıcı isteği, 2026-10-31).** Kaynak: kullanıcının verdiği herkese açık M3U (gist `blog-tv.m3u`). Yalnız Türkçe ve şifresiz kanallar alındı. Kaynak liste gizli depodadır (`assets/channels/tr.m3u`); uygulamaya şifreli paket olarak girer (`channels.bin`, aşağıda "Veri paketleri").
  - 204 kanal, 446 akış. Aynı `tvg-id`'li satırlar tek kanalın akışlarıdır (`M3uParser`); ilk akış gist'inki, ardından eski sürümün listesindeki yedekler.
  - **Sıra:** gerçek TKGS kanal sırası herkese açık bir kaynakta yok. Kullanıcının seçimiyle eski sürümün sırası kullanıldı (Türksat frekans tablosu satır sırası). Eşleşen 94 kanal eski numarasını korur; kalan 110 kanal 134'ten başlayarak numaralanır. `tvg-chno` olmayan kanal sona eklenir.
  - **Kategoriler** sabit sıradadır (`TvContent.categoryOrder`): Ulusal, Haber, Spor, Belgesel, Sinema, Müzik, Çocuk, Yaşam, Dini, Kıbrıs, Dünya, Genel, Yerel, Diğer.
  - Logolar gist'teki `tvg-logo` adresleridir (`ChannelLogo`); yoksa monogram (`ArtworkFallback`).
  - Alınmayanlar: şifreli/ücretli paketler (beIN, FX, Disney Junior, Baby TV, FilmScreen, FIX Sinema), Azerice kanallar, radyo akışları. Gist'te olmadığı için Kanal D, Star TV, NTV ve Teve2 başta listede yoktu (aşağıda eklendi).
  - Gist'te yayın akışı (EPG) adresi yok, `tvg-id`'ler rastgele; EPG ayrı bir kaynaktan bağlanır (aşağıda).
  - Kanıt: `test/core/content/m3u_parser_test.dart`.
  - **Vavoo akışları (kullanıcı isteği, 2026-11-01).** Kullanıcının verdiği liste (`atakan1983.lxi.be/vavoo.php?list=Turkey.m3u`, 849 kayıt): Vavoo (vavoo.to) yayınları, hepsi aynı aracı PHP sunucusundan geçiyor.
    - Ücretli kanallar (beIN, S Sport, Spor Smart, sinema paketleri vb.) "yalnız şifresiz" kuralıyla alınmadı.
    - Ortak 86 kanala 210 akış eklendi, mevcut akışların arkasına (adresler https; aracı sunucu http'yi zaten yönlendiriyor).
    - Eksik altı kanal eski sürümün numarası, kategorisi, logosu ve akışlarıyla eklendi, ardından Vavoo akışları: NTV (38), Star TV (40), Teve2 (78), Kanal D (81), Ekol TV (88), Sözcü TV (122). Liste 210 kanal.
    - Bilgisayardan denendi: 5 örnekten 4'ü 0,6–1 sn'de yayın listesini verdi, Halk TV 15 sn sonra hata ("m3u8 alinamadi").
    - Riskler: kimin işlettiği belli olmayan tek bir aracı sunucu (kapanabilir, trafiği görür); Vavoo'nun yayın hakkı yok. Akışlar yedek olarak durur; resmî CDN'ler yoklamada genelde önde çıkıyor.
- **Yayın akışı (EPG, 2026-10-31).** İki kaynak, kullanıcının seçimi: önce epgshare01'in Türkiye dosyası (`epg_ripper_TR1.xml.gz`), ikinci olarak iptv-org/epg ile ürettiğimiz dosya. İkisi `ByReDoxXx/redox-epg` deposunda tek şifreli pakette (`epg.bin`) yayınlanır, uygulama birleştirir; 31 Ekim'de 204 kanalın 51–52'si.
  - Neden bu kaynak: her gün güncelleniyor (Türksat Kablo'nun yayın akışından), 3 gün, ~170 KB gzip, başlıklar Türkçe, saatler +03:00. 31 Ekim'de gömülü 204 kanalın 31'ini kapsadı.
  - Elenenler: kullanıcının `epg.xml`'i (Rus servisi it999, 404 MB, kanallarımızdan yalnız 5'i, iki gün sonra eskiyor); `ViP.m3u` (EPG adresi yok; adresleri ücretli aboneliğin kullanıcı adı/şifreli bağlantıları, uygulamaya konamaz).
  - Risk: epgshare01 gönüllü servis, kullanım koşulu yok. Bu yüzden ikinci kaynak kendi elimizde.
  - **Kendi dosyamız (`ByReDoxXx/redox-epg`):** iptv-org/epg aracı GitHub Actions'ta günde iki kez (TSİ 05:15, 17:15) yalnız listemizdeki kanallar için 3 günlük XMLTV üretir; epgshare01 dosyasını da indirip ikisini `epg.bin` paketine koyar (~220 KB); uygulama `raw.githubusercontent.com`'dan indirir. Paket her çalışmada değişir (rastgele nonce); depo şişmesin diye iş akışının önceki işlemesinin üzerine yazılır. Kod deposu gizli kaldığı için ayrı ve herkese açık depo (kullanıcı onayladı). 500'den az programlı çıktı eldeki dosyanın yerine yazılmaz.
    - Kanallar TV+'tan (48), TV+'ta olmayan bir kanal Digiturk'ten. Denenen öteki yollar:
      - Digiturk öncelikli: gece yarısını geçen programları atlıyor (TRT 1'de 20:00–00:15 boş); üstelik GitHub sunucularından gelen istekleri 403 ile reddediyor (132/132).
      - D-Smart: 403. Türksat Kablo: sertifika zinciri eksik (epgshare01 zaten aynı veriyi veriyor).
      - TV+ her istekte oturum açıyor; istekler sık olunca oturum açma düşüyordu (144 istekte 83 hata). İstekler arası 1,5 sn bekleme ile hata kalmadı.
    - Sonuç (31 Ekim, yerelde): 49 kanal, 48'inde o an yayındaki program var; 21 kanal yalnız burada (TRT 2, NOW, Halk TV, Haber Global, TRT Spor Yıldız, TV8.5…).
  - **Birleştirme (`EpgGuide.mergedWith`):** kanal iki kaynakta da varsa öndekinin programları kalır, sonrakinin yalnız çakışmayan programları boşlukları doldurur (kaynaklarda delik olabiliyor). epgshare01 önde: gece yarısını geçen programları tam.
  - **Eşleme:** kaynak kimlikleri (`TRT.1.HD.tr`) listedekilerle ortak değil; kanallar adla eşlenir (`EpgGuide.key`: küçük harf, Türkçe harfler sadeleşir, HD/TV/TR ekleri ve boşluk atılır; "TRT 1 HD" = "TRT 1", "Bengütürk TV" = "BENGÜ TÜRK"). Adı farklı olanlar `TvContent.epgAliases`'tadır (FB TV → FENERBAHÇE TV).
  - **Yenileme:** `TvGuideController` akışı açılışta ve 6 saatte bir indirir; kanalların şimdiki programı, saat aralığı, türü, ilerlemesi ve sonraki programı her dakika başında yenilenir (`TvContent.withGuide`). İndirme başarısızsa eldeki akış kalır; akış gelene kadar kanallar akışsız görünür. Çözme (2–3 MB XML) ayrı iş parçacığındadır (`Isolate.run`).
  - Kanal nesnesi her dakika yenilendiği için `LiveChannel` eşitliği numara ve addır (önizleme seçimi ve dizideki yer korunur).
  - Televizyon ve oynatıcı başlığındaki saat artık gerçek saattir. Anasayfa başlığı örnek içerikle birlikte örnek saati (20:45) gösterir.
  - Kanıt: `test/core/content/xmltv_test.dart` (ad anahtarı, saat dilimi, gzip/BOM, kimlik birleştirme), `test/features/tv/tv_guide_test.dart` (şimdiki/sonraki program, takma ad, çizelge dakikaları, denetleyici), `tv_page_test.dart` (4K görüntüler `build/tv/televizyon-akis-4k.png`, `epg-akis-4k.png`). Gerçek dosyalarla masaüstünde denendi: epgshare01 tek başına 1,2 sn, 31 eşleşme (TRT Çocuk'un akıştaki programı TV'de o an yayındakiyle aynıydı); iki kaynak birlikte ~0,9 sn, 52 kanal. Cihazda (Chromecast) henüz denenmedi.
- **Veri paketleri: şifreli ve imzalı kanal listesi ve yayın akışı (kullanıcı isteği, 2026-10-31).** Amaç: listenin kopyalanmasını zorlaştırmak ve değiştirilmesini önlemek.
  - **İki dosya:** `channels.bin` (kanallar; liste değişince elle paketlenir) ve `epg.bin` (yayın akışı; günde iki kez). Ayrı dosya: EPG her yenilendiğinde kanal listesi baştan inmez, biri bozulursa öteki çalışır.
  - **Biçim (`DataPack`, `redox-epg/tools/pack.mjs`):** gzip'li JSON → AES-256-GCM → Ed25519 imza. `"RDX1" | tür | nonce | şifreli metin | etiket | imza`. Başlık GCM ek verisidir (bir türün dosyası ötekinin yerine konamaz). Uygulama önce imzayı doğrular, sonra çözer.
  - **Anahtarlar:** imzanın gizli anahtarı ve şifre anahtarı yalnız GitHub Secrets'ta (`REDOX_SIGN_KEY`, `REDOX_DATA_KEY`) ve geliştiricinin bilgisayarında, depoların dışında (`%USERPROFILE%\.redox\`). Eski sürümün anahtarı kullanılmadı. İmzanın açık anahtarı kodda (`DataPack._signPublic`). Şifre anahtarı uygulamaya derlemede verilir (`--dart-define=REDOX_DATA_KEY`, yerelde `--dart-define-from-file=%USERPROFILE%\.redox\app-keys.json`); verilmezse kanal listesi açılmaz.
  - **Sınır:** şifre anahtarı APK'nın içindedir; kararlı biri çıkarabilir. Şifreleme kopyalamayı zorlaştırır, engellemez. Değiştirmeyi imza engeller: imzanın gizli anahtarı uygulamada yoktur.
  - **Akış:** açılışta uygulamadaki `channels.bin` okunur; güncel `channels.bin` ve `epg.bin` arkada iner (`ChannelSource.download`, `EpgSource.load`). İnmez ya da açılmazsa eldeki kalır. İndirilen paket cihazda saklanmıyor (sonraki iş): internetsiz açılışta uygulamadaki liste kullanılır, yayın akışı olmaz.
  - **Kanıt:** `test/core/content/data_pack_test.dart`: açma, tek bayt değişince ve başka anahtarla imzalanınca ret, tür karışmaması, anahtar yok/yanlış, Node ile üretilmiş paketin Dart'ta açılması (yalnız teste ait anahtarlarla, `test/fixtures/`), uygulamadaki paketin gerçek imza anahtarıyla imzalı olması. Gerçek anahtarla masaüstünde: uygulamadaki ve indirilen paket 204 kanal, M3U'dan okunanla birebir aynı; indirme ve açma 1,8 sn. APK'da yalnız `channels.bin` var, `tr.m3u` yok.
- **Oynatıcı, 1. aşama (kullanıcı isteği, 2026-10-31).** Eski sürümün oynatıcısı örnek alındı (`design/referans-oynatici.jpg`, eski deponun wiki'si).
  - **Motor: media_kit 1.2.6 (libmpv).** Android/Android TV, Windows ve Linux'ta HLS ve MPEG-TS oynatır; Flutter'ın `video_player`ı Windows/Linux'u desteklemiyor. Motor bir arayüzün (`PlaybackEngine`, uygulaması `MediaKitEngine`) arkasındadır; testler sahte motorla (`FakeEngine`) koşar. Kullanıcı kararı: bütün platformlarda aynı motor.
    - mpv ayarları: `demuxer-lavf-analyzeduration=1` (HLS'te akış çözümleme süresi kısalır), `network-timeout=10`.
    - **Android'de kopyasız çizim (`vo=mediacodec_embed`, `hwdec=mediacodec`) — kasmanın çözümü (2026-10-31).** Varsayılan yol (`vo=gpu`, `mediacodec-copy`) donanım çözücünün her karesini belleğe kopyalıyordu. Chromecast'te ölçüldü (mpv sayaçları, 40'ar sn):
      - 1440p yayınlar (TRT Genç, 360): saniyede ~8 kare atlama, görüntü sesin 18–24 sn gerisine düştü.
      - 1080p'ye sınırlayınca da saniyede ~5 kare atlama, 10 sn gecikme. Hafif ölçekleme (bilinear, dithering kapalı) etkisiz: darboğaz GPU değil kopyalama.
      - Kopyasız yolda aynı kanallarda atlama 0, ses-görüntü farkı 0; işlemci yükü ~%130'dan ~%60'a indi. Panel önizlemesi, tam ekran ve üstündeki çubuk çiziliyor.
      - İlk denemede "Could not open codec" yedek akışa geçiriyordu: media_kit yüzey bağlanınca çözücüyü yeniden kurar, ilk açılış hata verebilir; ardından canlı yayında konuma atlama "Cannot seek" verir. Bu iletiler artık yayını düşürmez (`MediaKitEngine._transient`); gerçekten açılmayan akışı açılış süresi yakalar.
      - Windows ve Linux varsayılan yolda kalır.
    - APK işlemci başına ~25 MB büyür: CI APK'ları işlemciye göre ayırır (`--split-per-abi`). Linux derlemesi `libmpv-dev` ister.
    - Sürüm derlemesine internet izni eklendi (yalnız hata ayıklama derlemesinde vardı).
  - Bileşenler: sayfa `PlayerPage`, oturum `PlaybackSession`, çubuk `PlayerBar` + `PlayerHints`, menü `PlayerOptions`, hızlı liste `ChannelDrawer`.
  - **Alt çubuk (eski düzen):** solda logo + numara rozeti, ad, CANLI, ölçülen çözünürlük, "Akış 1/2"; ortada önceki kanal · oynat/duraklat · sonraki kanal; sağda kanal listesi, sonraki akış (birden çok akış varsa), Seçenekler. Odaktaki düğmenin adı üstünde yazar.
    - Oynat/duraklat 92 dp'dir; satırda 48 dp yer kaplar, çubuğun üstünden ve altından taşar. Çevresinde koyu kırmızı (`onPrimaryFixedVariant`) 4 dp çizgi vardır (kullanıcı isteği).
  - **Kumanda:** OK çubuğu açar (odak oynat/duraklatta). ▲▼ kanal değiştirir (uçta başa döner), ◄ hızlı kanal listesi, ► sonraki akış. 0-9 kanal numarası (1,5 sn sonra açılır), tek başına 0 önceki kanal. Geri açık menüyü, listeyi, çubuğu sırayla kapatır; sonra oynatıcıdan çıkar.
    - Kanal açılamadığında yalnız rakamlar ve ▲▼ / kanal tuşları işler; öteki tuşlar "Tekrar dene" / "Sonraki kanal" düğmelerine gider (cihazda ▲▼ engelleniyordu).
  - **İpuçları:** kanal ya da akış değişince çubuk ve "OK Kontroller · ▲▼ Kanal · ◄ Kanal listesi · ► Sonraki akış" 3,8 sn görünür. Eski sürümde böyleydi; Anasayfadaki kalıcı şerit kaldırılmıştı, bu kısa süreli.
  - **Seçenekler:** Kalite, Ses, Altyazı, Ölçek (16:9 Orijinal / Ekranı doldur / Uzat), Önceki kanal, Oynatıcıdan çık; altta ölçülen boyut ve akış. Kalite listesi yüksekten düşüğe sıralıdır. İşlevi olmayan satır (gece modu, PiP, 2×2, kanalı gizle) gösterilmez: 2. aşama.
  - **En iyi akış seçimi (`StreamProbe`, kullanıcı isteği, 2026-11-01):** kanal açılırken bütün akışların oynatma listeleri aynı anda indirilir (en çok 2 sn). Hızlı açılanlar (en hızlının iki katı ya da +0,7 sn içinde) bit hızına göre öne dizilir, sonra yavaşlar, en sonda açılmayanlar (yoklamada açılmayan oynatıcıda açılabilir). Bit hızı: ana listede en yüksek `BANDWIDTH`; tek kaliteli listede ilk parçanın boyutu (HEAD, en çok 1 sn) / süresi. Sonuç kanal başına 30 dk saklanır. Oynatıcı ve önizleme bu sırayla açar, yedek geçişi de bu sırayı izler.
    - Bedeli: kanalın ilk açılışına en çok ~3 sn eklenir (bilgisayardan TRT 1'in 12 akışı 2 sn, Show TV'nin 11 akışı 3,5 sn sürdü; sınırlar sonradan 2 + 1 sn'ye indirildi). Kanal hızla değişirse eski kanalın geç gelen sonucu yok sayılır.
    - Kanıt: `test/features/player/stream_probe_test.dart`. Cihazda denenmedi.
  - **Otomatik yedek akış (`PlaybackSession`):** akış hata verirse ya da 15 sn içinde görüntü gelmezse (`PlaybackSession.defaultStartupTimeout`) sıradaki akışa geçilir; hepsi açılmazsa "Tekrar dene" / "Sonraki kanal". Eski sürüm (ExoPlayer) TV'de 2,5 sn bekliyordu.
    - Süre ölçümle belirlendi: mpv gerçek kanalları Chromecast with Google TV'de 6–12 sn'de açtı (A Haber 5,9 · ATV 7,9 · TV8 8,3 · Show 8,5 · Halk TV 11,7 sn). İlk sınır 10 sn idi; kanallar bir açılıp bir açılmıyordu.
    - Hatayla geçişten sonraki 1 sn içinde gelen hatalar eski akışın sayılır: emülatörde açılmayan adres iki hata bildirdi, ikincisi yedek akışı da düşürüyordu.
  - **Test yayınları:** uygulama gerçek kanal listesini oynatır. Mux ve Unified Streaming (çok sesli/altyazılı) test yayınları yalnız önizleme verisinde ve testlerde kullanılır; bir örnek kanalın ilk akışı bilerek açılmaz (`.invalid`). Apple test yayını, Chromecast'te hiç açılmadığı için çıkarıldı.
  - **Doğrulama:** testler (`test/features/player/player_page_test.dart`, 4K görüntüler `build/player/`). TV emülatöründe yayın açıldı, 1920×1080 ölçüldü, kalite izleri listelendi; çubuk, Seçenekler ve kanal listesi çalıştı.
    - **Görüntü emülatörde çizilemiyor:** media_kit emülatörü tanıyıp yazılımsal çizime geçiyor, emülatörün EGL'i bağlam kuramıyor (`EGL_BAD_ATTRIBUTE`). Görüntü gerçek cihazda doğrulanmalı.
    - **Gerçek cihazda doğrulandı (Chromecast with Google TV, Android 14, 32 bit ARM, 2026-10-31):** görüntü ve ses geliyor (1080p); ULUSAL 2'de bozuk ilk akıştan yedeğe geçiliyor; Seçenekler (ses listesi, ölçek "Ekranı doldur", önceki kanal), kanal listesi, numara girişi ve Geri sırası çalışıyor.
    - Gerçek kanallar cihazda açıldı (TRT Spor, NOW, ATV, Show, Kanal 7, Habertürk, TV8).
    - Apple ve Unified Streaming test yayınları bu cihazda mpv ile hiç açılmadı (40 sn'de bile hata yok). Bu yüzden çok sesli/altyazılı yayında seçim cihazda doğrulanamadı.
    - Kasma (yüksek çözünürlüklü yayınlarda kare atlama ve sesin gerisinde kalma) kopyasız çizimle giderildi (yukarıda).
    - Windows derlemesi denenmedi: proje D:, pub önbelleği C: sürücüsünde olduğu için eklenti bağlantısı (symlink) kurulamıyor. Windows'ta Geliştirici Modu gerekir.
  - **2. aşama:** 15 sn geri sarma ve Canlıya dön, favori, kanalı gizle, gece modu, PiP, 2×2, bit hızı/düşen kare, çalışan akışı kanal başına hatırlama, telefon hareketleri ve mini oynatıcı.

## 6. Logo

**Kaynak:** kullanıcının Logo-2'si (siyah zemin), `assets/brand/redox-logo-source.jpg` (2048 px; ölçüm 2000 px ölçekte).
- `redox-logo.svg`'nin geometrisi ilk logodan VTracer ile izlendi. Logo-2 aynı çizimdir (piksel hizalı), bu yüzden her yolun rengi Logo-2'de görünen alanının medyanıyla yeniden boyandı.
- **Beyaz köşeler saydam:** tam logo, kaynaktaki karo sınırıyla kesilir (927 noktalı yol; köşelerde beyazın bittiği yerden 2 birim içeride). Kenardaki 23 beyaz kalıntı böylece görünmez. İşaret, simgeler ve afiş karo içinden kırpıldığı için beyaz içermez.
- Varyasyonlar `design/logo/logo_varyasyonlari.py` ile üretilir.
- Ölçüleri `test/platform/brand_assets_test.dart` denetler.

| Varyasyon | Dosya | Kullanım |
|---|---|---|
| Tam logo | `assets/brand/redox-logo.svg` | 96 dp ve üstü; yazı daha küçükte okunmaz |
| İşaret (yazısız karo) | `assets/brand/redox-mark.svg` | 64 dp ve altı; Anasayfa başlığında 44 dp |
| Metin markası | `BrandWordmark` (Sora 800) | Metin olarak marka adı |
| Android eski simge | `mipmap-*/ic_launcher.png`, 48 dp | API 24–25 |
| Android uyarlanabilir simge | `mipmap-anydpi-v26/ic_launcher.xml`; ön ve tek renk katman 108 dp; zemin `#0B0203` (logonun siyah zemininin ortalaması) | API 26+; temalı simge API 33+ |
| Android TV afişi | `drawable-xhdpi/banner.png`, 320×180 px | `android:banner` |
| Windows | `windows/runner/resources/app_icon.ico`, 16–256 px, 10 boyut | Exe ve pencere |

**Geometri (kaynak px):**
- Boynuz ucu y=156, çene ve halka altı y=1518; yazı y=1534'te başlar.
- İşaret kutusu x 295–1705, y 116–1526 (1410 px kare). Yazı kutunun dışında kalır.
- Köşe yarıçapı kenarın %22'si.

**Android kaynakları** (developer.android.com, 2026-10-31'de okundu):
- **Uyarlanabilir simge:** "Size all layers to 108x108 dp". Güvenli alan 66 dp; logo 48–66 dp olmalı.
  - İşaret, en uzak opak pikseli 33 dp yarıçapta kalacak biçimde ölçeklendi. Sonuç: 55,5 × 54,8 dp kutu.
  - İşaret, kaynak görselden ayrıldı: sıcaklık (kırmızı − mavi) maskesi + kenardan taşkın dolgu. Koyu dış çizgiler korunur.
- **TV afişi:** "use an xhdpi resource with a size of 320 x 180 px. Text must be included in the image." Afişte işaret ve logonun kendi "RedoX TV" yazısı var.
- **Android 12+ açılış ekranı:** varsayılan olarak başlatıcı simgesini gösterir. Zemin olarak tema `windowBackground`'ını kullanır, ama yalnızca tek renkse.
  - Bu yüzden açılış ve pencere zemini obsidyen (`@color/redox_obsidian`, `#000000`) yapıldı.
  - Flutter'ın beyaz `launch_background` çizimleri kaldırıldı.
  - Android 12 öncesinde açılışta logo yok; yalnızca obsidyen zemin görünür.

**Karar:**
- Platform simgeleri PNG/ICO'dur, çünkü platformlar bu biçimleri ister.
- Uygulama içinde logo her zaman SVG'dir.
- Uygulama adı Android etiketinde ve Windows/Linux pencere başlığında "RedoX TV".

**Açık noktalar:**
- Linux masaüstü simgesi yok. Flutter Linux şablonu simge ayarlamaz; simge paketlemede `.desktop` dosyasıyla verilir.
- TV başlatıcısında görünmek için iki bildirim gerekir: `LEANBACK_LAUNCHER` filtresi ve `android.hardware.touchscreen required="false"`. Bunlar ayrı TV APK'sı işine bırakıldı; afiş şimdiden tanımlı.
- Afiş tek dillidir. Başka dil eklenirse her dil için ayrı afiş gerekir (TV belgesi).
- Tek renk katmanda kıvılcım ve ışın çizgileri de görünür.

## 7. Doğrulanmayanlar

- Oynatıcı gerçek cihazda doğrulandı (5. bölüm). Öteki ekranların görüntüleri test ortamında çizildi ve emülatörde denendi.
  - Cihazda doğrulandı (2026-10-31): kart kesilmesinin düzeltmesi (`CenterOnFocus`), panelde canlı önizleme (TRT Genç), tam ekran ve dönünce önizlemenin sürmesi.
  - Cihazda henüz denenmeyenler: açılamayan kanalda ▲▼, 15 sn sınırında yedek akışa geçiş.
  - TRT Belgesel, TRT Diyanet Çocuk ve TRT Spor'un gist'teki logoları cihazda yüklenmedi; baş harfli yer tutucu çiziliyor.
  - Test ortamı gölgeleri bulanıksız çizer (`debugDisableShadows`).
  - Görüntü alınırken gerçek bulanıklık açılır.
- Android TV biçim algılaması yok. Biçim şimdilik açılışta verilir; varsayılan TV'dir.
- Anasayfa'daki içerik örnektir (`HomeContent.preview`). Televizyon sayfası gerçek listeyi ve iki kaynaklı yayın akışını kullanır (204 kanalın 52'si).
- Simgeler ve TV afişi gerçek bir başlatıcıda görülmedi. Ölçüleri testle, görünüşleri önizleme görüntüleriyle denetlendi.
