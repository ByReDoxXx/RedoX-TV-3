# RedoX TV 3.0 — Palet ve Tasarım Dili ("Kızıl Halka", Material 3 Expressive)

Kaynak: `assets/brand/redox-logo-source.jpg`. Makine okunur karşılığı: `design/tokens.json`.

## 1. Yöntem

Renkler tahminle değil, logo görselinden **piksel ölçümüyle** alındı (görselin nicemlenmiş baskın renk kümeleri). Ölçülemeyen yüzey kademeleri ölçülen zemin renginden **türetildi**; `tokens.json` içinde her renk `measured` / `derived` diye işaretlidir.

## 2. Ölçülen marka renkleri

| Ad | Hex | Logodaki yeri |
|---|---|---|
| Kızıl | `#F22144` | "RedoX" yazısı (en yaygın) |
| Koyu kızıl | `#C41536` | boğa alnı |
| Şarap | `#95122B` | gölgeli yüzeyler |
| En koyu kızıl | `#440A21` | yüzün gölgesi |
| Mercan | `#F25F61` | boğa yüzünün aydınlık tarafı |
| Altın | `#F0BE5E` | "TV" yazısı |
| Parlak altın | `#F7D574` | halka |
| Derin altın | `#DFA747` | boynuz alt tonu |
| Bronz | `#CF9038` | altın gölgesi |
| Zemin | `#0A0D1C` | logo zemini (üstte `#293143` parıltısından altta `#010413`'e gradyan) |

v2 dokümanındaki paletle (`#F02848`, `#F3C05D`, `#0A0A14`) farklar küçüktür; v3 ölçülen değerleri esas alır.

## 3. Roller (M3 Expressive eşlemesi)

| Rol | Renk | Kural |
|---|---|---|
| primary | Kızıl | Eylem, CANLI rozeti. Üzerine büyük/kalın beyaz yazı |
| primaryContainer | Koyu kızıl | Beyaz yazılı düğme dolgusu |
| tertiary | Altın | Favori, ilerleme, vurgu |
| odak halkası | Parlak altın | TV/masaüstü odağı: 3 dp halka |
| küçük kırmızı yazı | Mercan | Kart üzerinde küçük kırmızı metin |
| zemin / kart | `#0A0D1C` / `#141829` | AMOLED seçeneği: `#010413` |

M3 Expressive tercihleri: renk varyantı **Expressive**; büyük yuvarlak şekiller (kart 28 dp, öğe 16 dp, çip/düğme tam yuvarlak); seçili durumda şekil dönüşümü; kısa yay geçişleri. v2'deki kararı koruyorum: **sonsuz animasyon yok** (zayıf TV işlemcileri).

## 4. Kontrast (hesaplanmış, WCAG)

| Çift | Oran | Karar |
|---|---|---|
| Ana metin / zemin | 17,57:1 | Geçer |
| Ana metin / kart | 16,02:1 | Geçer |
| İkincil metin / kart | 9,44:1 | Geçer |
| Üçüncül metin / kart | 5,88:1 | Geçer |
| Altın / zemin | 11,25:1 | Geçer |
| Parlak altın halka / kart | 12,35:1 | Odak halkası net görünür |
| Zemin / altın (altın düğme) | 11,25:1 | Geçer |
| Beyaz / koyu kızıl `#C41536` | 5,99:1 | Geçer: düğme dolgusu bu |
| Mercan / kart | 5,52:1 | Geçer: küçük kırmızı yazı bu |
| Kızıl / zemin | 4,67:1 | Yalnızca büyük metin ve simge |
| Kızıl / kart | 4,26:1 | **Küçük metinde yetmez**, mercan kullan |
| Beyaz / kızıl `#F22144` | 4,14:1 | **Küçük metinde yetmez**, yalnızca büyük/kalın |
| Kızıl / altın (yan yana) | 2,90:1 | **Ayırt etmek için renge güvenme** |

Sonuçlar: (1) Küçük beyaz yazılı düğme `primaryContainer` (`#C41536`) kullanır. (2) Seçili kırmızı öğe ile altın halka yan yana gelince renk farkı yetmez; odak ayrımı 3 dp **halka şekliyle** yapılır.

## 5. Cihaza göre tasarım kuralları

| Konu | TV | Tablet | Telefon | Masaüstü |
|---|---|---|---|---|
| Gezinti | Daralmış ray; odaklanınca açılır, odak ayrılınca kapanır | Ray (hover/dokunma) | Alt çubuk | Ray; fare üstüne gelince açılır, çekilince kapanır |
| Arama | Başlıkta giriş kutusu | Giriş kutusu | Simge | Giriş kutusu |
| Etkileşim | D-pad: yön, OK, Geri, Menü. **Renkli tuş yok** | Dokunma | Dokunma | Fare + klavye |
| Yazı alt sınırı | 14 sp | 12 sp | 12 sp | 12 sp |
| Dokunma hedefi | – | ≥ 48 dp | ≥ 48 dp | ≥ 32 dp |

Simgeler ve logolar **SVG**; emoji yok. Kanal logosu radyo kadranında kadranın üstünde durur.

## 6. Açık noktalar (doğrulanmadı)

- **A1. Logo SVG'leri:** `redox-mark.svg` ve `redox-wordmark.svg` v2'den kopyalandı. v2'deki kaynak görsel yüklediğin logodan **farklı** olduğu için bu SVG'ler yeni logoyla eşleşmeyebilir. Eşleştiği görsel karşılaştırmayla doğrulanana kadar son kabul sayılmaz.
- **A2. Yazı tipi:** Stitch tasarım sisteminde Google Sans Flex seçildi. Flutter'a gömmek için lisansı doğrulanmadı; doğrulanana dek yedek olarak Roboto Flex.
- **A3. Türetilmiş yüzey kademeleri** (`surfaceLow` … `outline`) ölçülmedi; kart rengi dışındakilerin kontrastı hesaplanmadı.
- **A4. Stitch tasarım sistemi** (`assets/9554844437592105634`) eski tohum renkleriyle (`#F02848`…) oluşturuldu; ölçülen değerlerle güncellenmesi gerekiyor.
