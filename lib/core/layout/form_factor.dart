/// Cihaz biçimi. Ölçüler (yazı alt sınırı, odak büyümesi, kenar boşluğu)
/// buna göre seçilir; bkz. RedoxMetrics.
///
/// Algılama henüz yok: Android TV ayrımı platform tarafında yapılmalı
/// (UiModeManager / leanback özelliği). O yazılana kadar biçim uygulama
/// açılışında açıkça verilir.
enum FormFactor { phone, tablet, desktop, tv }
