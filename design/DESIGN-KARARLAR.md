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

### Palet: Logo-3'ten türetme (2026-11-01)

Kullanıcı yeni logoyu (Logo-3, alevli boğa, gece laciverti zemin) verdi ve paletin ona göre güncellenmesini istedi ("güncelle ama beğenmezsen eskiye çevirirsin"). Yöntem Logo-2'dekiyle aynı. Önceki palet (Logo-2: `#D82131 #ED9650 #F6BD58 #000000`) git geçmişinde; geri dönmek tek işlemle olur.

**Tohumlar logodan ölçüldü** (`RedoxSeeds`; 2000 px görsel, 1000 px'e ölçeklenip karo içinde):

| Tohum | Değer | Ölçüm |
|---|---|---|
| Crimson Flame (primary) | `#D7232C` | Kızıl aile (ton 340°–12°, doygunluk ≥ 0,55) içinde, iki kısıtı sağlayan piksellerin medyanı (157 bin pikselden 19 bini) |
| Molten Amber (secondary) | `#FC7422` | Turuncu aile (12°–32°), parlak (V ≥ 0,85) piksellerin medyanı: alevler |
| Incandescent Gold (tertiary) | `#FBBE4D` | Altın aile (32°–58°), parlak piksellerin medyanı: halka ve "TV" |
| Obsidian Void (nötr) | `#0B0B20` | Logonun zemini: koyu (V < 0,22), mavisi kırmızısından baskın piksellerin medyanı |

**Kızıl için iki kısıt** (Logo-2'deki gibi): beyaz düğme yazısı ≥ 4,5:1 ve odak halkası kartta ≥ 3:1. Kart artık lacivert nötrün T12'si (`#1D1D33`); kısıt bu kartla ölçüldü. Logonun genel kızılı daha koyu (`#932027`), kısıtlı medyan Logo-2'ninkine çok yakın çıktı (`#D82131` → `#D7232C`).

**Roller M3 sadakat (fidelity) şemasıyla hesaplanır** (`RedoxTonal`, `RedoxRoles`). Bu Stitch'in yöntemidir. Kanıt:
- İlk tohumlar (`#E61638 #FF9E1B #FFD54F #0D0E11`) bu şemayla ilk DESIGN.md'nin 44 rolünü **birebir** üretti (0/44 fark).
- Yeni roller aynı hesapla üretildi ve DESIGN.md YAML'ına yazıldı.
- `redox_roles_test.dart`, 44 rolün `RedoxTonal.scheme` ile eşleştiğini denetler.

**Tuval gece laciverti.** Scaffold zemini nötr tohumdur (`#0B0B20`); yüzeyler bu tonda (kart `#1D1D33`, en yüksek kap `#333349`). Logo artık zeminiyle bütünleşir. `on-surface` hafif lacivert tonlu beyazdır (`#E2DFFD`).

**Belirgin değişiklikler:**
- İkincil kap (`secondary-container`) parlak turuncu oldu (`#ED6915`, yazısı koyu `#351100`). Logo-2'de koyu kahveydi (`#884500`). Gezinme rayının seçili göstergesi bu renktir: turuncu hap, koyu ikon.
- Isıl degrade ve ilerleme dolguları daha canlı (alev turuncusu).

**Sonuçlar** (`redox_contrast_test.dart`; hepsi geçiyor):

| Çift | Oran |
|---|---|
| Beyaz / kızıl `#D7232C` | 5,04:1 |
| on-primary-container `#FFF0EE` / kızıl | 4,55:1 |
| Kızıl odak halkası tuvalde / lowest'ta / kartta | 3,85 / 3,82 / 3,27:1 |
| Tuval / amber (cam düğme odağı) | 7,07:1 |
| Beyaz / amber | 2,74:1; çip ucu olamaz |
| Amber giriş kenarı en yüksek kapta | 4,48:1 |

**Seçili çip ucu (kor).** Kullanıcının "Kor kalsın" kararı korunur: uç, amber paletinin beyazla 4,5:1'i sağlayan en açık tonudur.
- Yeni palette T50: `#C75300` (4,50:1); T51 4,5:1'in altında.

**Isıl degrade.** Tohumlarla çizilir: kızıl → amber `#FC7422` → altın `#FBBE4D` (logodaki alevin renkleri). İzde sırasıyla 3,82 / 7,03 / 11,53:1.

**Kızıl yazı kuralı.** Kızıl kartta 3,27:1 verir, bu yüzden küçük yazıda kullanılmaz.
- Vurgulu metinlerde `primary`, `secondary`, `tertiary` rolleri kullanılır; kartta hepsi ≥ 4,5:1.

**İlerleme izi.** Kızıl dolgu en yüksek kapta 3:1'in altında kalır.
- **Karar:** İz `surface-container-lowest`'tır (`#0C0C21`).

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
- **Anasayfa gerçek veriyle (kullanıcı isteği, 2026-11-01: "anasayfayı kullanılabilir hale getir").** Uydurma vitrin ve raflar kaldırıldı.
  - **Vitrin:** son izlenen kanal; geçmiş boşsa ilk ulusal kanal. Yayın akışından şimdiki program, saat aralığı, kalan süre ("123 dk kaldı"), kanal logosu (sağda, TV/tablet). "Canlı yayına gir" oynatıcıyı açar; "Yayın akışı" Televizyon sayfasını EPG görünümünde açar (`TvPage.initialView`). "Çoklu ekrana ekle" 2x2 ekran yazılana kadar gösterilmez.
  - **Kısayol halkaları:** uygulamanın bölümleri (TV, Radyo, Film, Dizi, Favori, 2x2 Ekran, Kaynaklar), ortada büyük ikon; kısa adlar ("Televizyon" halkanın altına sığmıyordu).
  - **"Son izlenen kanallar":** izleme geçmişi (`WatchHistory`, en çok 12 kanal, cihazda `shared_preferences` 2.5.6 ile saklanır). Kanal oynatıcıda görüntü verince yazılır (`PlayerPage.onWatched`), açılmayan kanal yazılmaz. Geçmiş boşsa raf "Ulusal kanallar". Odaktaki kart ortalanır (`CenterOnFocus`).
  - Dizi, film ve radyo rafları o bölümler yazılınca gelecek; veri kaynağı olmadan uydurma içerik gösterilmez.
  - **Yayından gerçek kare (kullanıcı isteği: "yayının oynamasına gerek yok, bir kare alsa yeter").** Raftaki kartların ve vitrinin görseli kanalın yayınından alınan karedir (`FrameStore`, `grabFrame`); alınamazsa logo.
    - Ayrı ve sessiz bir mpv kareyi dosyaya yazar (`vo=image`, JPEG %80) ve ilk kareden sonra durur (`frames=1`); çözücü yazılımsaldır (`hwdec=no`). Dosya geçici klasörden okunup silinir.
    - Denenip bırakılanlar: `vo=null` + `screenshot-raw` (kare saklanmadığı için boş döndü, Chromecast'te görüldü); oynatıcının kendi ekran görüntüsü (kopyasız çizimde kare belleğe inmez); TV+ program görselleri (gerçek kare değil, kullanıcı istemedi).
    - Kareler sırayla, tek tek alınır; yalnız Anasayfa görünürken (vitrin önce), bir kanal izlenirken ve başka bölümde durur (zayıf TV'de oynatmayla yarışmasın). Kare 10 dk tazedir; bellekte tutulur, cihaza yazılmaz (uygulama açılınca yeniden alınır).
    - Kart, kareyi kart boyunda çözer (`cacheWidth`): 1080p JPEG zayıf TV belleğinde tam boy açılmaz.
    - Chromecast'te: TRT 1'in karesi açılıştan ~10 sn sonra geldi (~115 KB); vitrin arka planında ve kartta göründü.
    - Kanıt: `test/core/playback/frame_store_test.dart` (sıra, ikinci akış, tazelik, durdurma), `home_content_test.dart` (vitrinde kare, izlerken kare alınmaz).
  - Anasayfa verisi kök kabukta kanal listesinden türer (`HomeContent.from`): Anasayfa, Televizyon modülüne bağımlı değil.
  - Kanıt: `test/features/home/home_content_test.dart` (türetme, kalan süre, geçmişin saklanması, düğmeler), `home_page_test.dart`. Gerçek TV'de doğrulandı (Chromecast with Google TV, 2026-11-01): açılışta gerçek saat ve TRT 1'in şimdiki programı, "Canlı yayına gir" ile o program açıldı, dönüşte "Son izlenen kanallar" rafında TRT 1, "Yayın akışı" gerçek verili çizelgeyi açtı.
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
    - Kanıt: `test/core/playback/stream_probe_test.dart`. Cihazda denenmedi.
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

- **Profil seçimi "Kim izliyor?" ve çocuk profili (`ProfilePickerPage`, `ProfileStore`; kullanıcı isteği, 2026-11-01).** Kullanıcı YouTube TV'nin profil ekranını referans verdi ("fotoğraftaki tasarımı kullanabiliriz, çocuk profili yapmayı unutma").
  - **Ne zaman:** her açılışta (kullanıcı seçimi). Başlıktaki profil hapı (TV/tablet) ve telefonda "Diğer" → "Profil değiştir" bu ekrana döner. Profil hapından gelindiyse Geri önceki profile döner.
  - **Görünüm (referanstan):** gece laciverti zeminde sağ alttan kızıl/amber ışıma; üstte logo işareti, "Kim izliyor?" (headlineLarge). Solda küçük "+" dairesi (profil ekle), sağında büyük renkli daireler (TV 112 dp, telefon 84 dp) ve adın Türkçe büyük baş harfi ("i" → "İ"). Odaktaki profilde beyaz halka, büyüme ve beyaz ad. Düzenleme düğmesi yalnız seçili profilin altında; odak düğmeye inse de yerinde kalır. Telefonda profiller satırlara sarılır, "+" sonda.
  - **Avatar renkleri:** marka tonları (kızıl `#D7232C`, kor `#C75300`, altın kabı `#936700`) ve ayırt edilsin diye üç soğuk ton (mor `#6B3FA0`, deniz yeşili `#00796B`, mavi `#1E5BB8`); beyaz harf hepsinde okunur. Çocuk profilinde sağ altta altın rozet (çocuk ikonu).
  - **İlk açılış:** "Profil 1" ve "Çocuk". En çok 6 profil; son yetişkin profili silinemez.
  - **Çocuk kipi (kullanıcı seçimi: yalnız Çocuk kategorisi):** kanallar `TvContent.only('Çocuk')` ile süzülür; oynatıcıda ▲▼ de bunlarda gezer. Rayda yalnız Anasayfa ve Televizyon, Ayarlar yok. Telefonda alt menü yok; "Diğer"de Televizyon ve "Profil değiştir". Anasayfa kısayolu yalnız Televizyon; raf ulusal kanal yerine listenin başı.
  - **Ebeveyn PIN'i (kullanıcı seçimi: 4 hane):** çocuk profili PIN yokken ilk açılışta iki kez girilerek belirlenir. Son profil çocuk profiliyse yetişkin profiline geçmek PIN ister; böylece çocuk ne profil hapından ne de uygulamayı kapatıp açarak çıkabilir. Ekleme, düzenleme ve silme de PIN ister. PIN cihazda düz değil, rastgele 16 baytlık tuzla SHA-256 özeti olarak saklanır. Pencerede ekran tuş takımı var; kumandanın ve klavyenin rakam tuşları da çalışır.
  - **Geçmiş profil başına:** her profilin "Son izlenen kanallar" listesi ayrıdır (`izlenen_kanallar_<id>`). Profillerden önceki tek liste ilk profile ('p1') geçer.
  - **Kareler önceden (kullanıcı isteği):** "uygulama açılınca anasayfadaki dinamik kanallardan alınacak fotoğraflar alınır, kullanıcı giriş yapana kadar yüklenmiş olur." Seçim ekranı dururken `FrameStore` önce son profilin, sonra diğer profillerin Anasayfa rafındaki kanalların karesini alır. Profil seçilince kabuk aynı kanalları ister; taze olanlar yeniden alınmaz.
  - Kanıt: `profiles_test.dart`, `profile_picker_test.dart`; görüntüler `build/profiller/` (`REDOX_SNAPSHOT=1`).

## 6. Logo

**Kaynak:** kullanıcının Logo-3'ü (alevli boğa, koyu lacivert zemin; kullanıcı isteği, 2026-11-01: "yeni logomuz"), `assets/brand/redox-logo-source.jpg` (2000 px). Önceki logolar (Logo-1, Logo-2: geometrik kızıl boğa, siyah zemin) git geçmişinde.
- `redox-logo.svg`: kaynağın 1000 px'e küçültülmüş hâli VTracer 0.6.12 ile yeniden izlendi (renkli, katmanlı, spline; 2339 yol, ~1,07 MB; Logo-2'de ~0,83 MB). Her yolun rengi kaynakta görünen alanının medyanıyla yeniden boyanır.
- **Beyaz köşeler saydam:** tam logo, kaynaktaki karo sınırıyla kesilir (920 noktalı yol; köşelerde beyazın bittiği yerden 2 birim içeride). Kenardaki beyaz kalıntılar böylece görünmez. İşaret, simgeler ve afiş karo içinden kırpıldığı için beyaz içermez.
- Varyasyonlar `design/logo/logo_varyasyonlari.py` ile üretilir.
- Ölçüleri `test/platform/brand_assets_test.dart` denetler.

| Varyasyon | Dosya | Kullanım |
|---|---|---|
| Tam logo | `assets/brand/redox-logo.svg` | 96 dp ve üstü; yazı daha küçükte okunmaz |
| İşaret (yazısız karo) | `assets/brand/redox-mark.svg` | 64 dp ve altı; Anasayfa başlığında 44 dp |
| Metin markası | `BrandWordmark` (Sora 800) | Metin olarak marka adı |
| Android eski simge | `mipmap-*/ic_launcher.png`, 48 dp | API 24–25 |
| Android uyarlanabilir simge | `mipmap-anydpi-v26/ic_launcher.xml`; ön ve tek renk katman 108 dp; zemin `#222032` (işaret kırpıntısının lacivert zemin ortalaması) | API 26+; temalı simge API 33+ |
| Android TV afişi | `drawable-xhdpi/banner.png`, 320×180 px | `android:banner` |
| Windows | `windows/runner/resources/app_icon.ico`, 16–256 px, 10 boyut | Exe ve pencere |

**Geometri (kaynak px):**
- Alev ucu y=125, çene y=1482; yazı y=1490'da başlar (X harfinin alevi yukarı uzanır).
- İşaret kutusu x 306–1688, y 104–1486 (1382 px kare). Yazı kutunun dışında kalır; kenardaki alev ve duman uçları (x 288–306, 1688–1715) kesilir.
- Köşe yarıçapı kenarın %22'si.

**Android kaynakları** (developer.android.com, 2026-10-31'de okundu):
- **Uyarlanabilir simge:** "Size all layers to 108x108 dp". Güvenli alan 66 dp; logo 48–66 dp olmalı.
  - İşaret, en uzak opak pikseli 33 dp yarıçapta kalacak biçimde ölçeklendi. Sonuç: 56,8 × 55,8 dp kutu. Konu maskesi alev, kıvılcım ve duman yüzünden kenarda tırtıklı; koyu zeminde ve daire maskede görünmüyor (önizleyerek bakıldı), boynun ucu hafif kesik.
  - İşaret, kaynak görselden ayrıldı: sıcaklık (kırmızı − mavi) maskesi + kenardan taşkın dolgu. Koyu dış çizgiler korunur.
- **TV afişi:** "use an xhdpi resource with a size of 320 x 180 px. Text must be included in the image." Afişte işaret ve logonun kendi "REDOX TV" yazısı var.
- **Android 12+ açılış ekranı:** varsayılan olarak başlatıcı simgesini gösterir. Zemin olarak tema `windowBackground`'ını kullanır, ama yalnızca tek renkse.
  - Bu yüzden açılış ve pencere zemini obsidyen (`@color/redox_obsidian`, gece laciverti `#0B0B20`) yapıldı.
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
- Tek renk katmanda alevler ve kıvılcımlar da görünür.
- Palet Logo-3'ten türetildi (2. bölüm, "Palet: Logo-3'ten türetme").

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
