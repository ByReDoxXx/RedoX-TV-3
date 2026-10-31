// Köşe yarıçapları (dp). Kaynak: DESIGN.md "rounded" ve "Shapes".

abstract final class RedoxRadius {
  /// rounded-xs: onay kutusu.
  static const double xs = 4;

  /// rounded DEFAULT: giriş alanı, küçük görsel, mini rozet, metadata çipi.
  static const double sm = 8;

  /// rounded-md.
  static const double md = 12;

  /// rounded-lg: medya kartı, diyalog, alt sayfa, açılır panel.
  static const double lg = 16;

  /// rounded-xl: vitrin (hero) kartı, öne çıkan bant, canlı etkinlik çerçevesi.
  static const double xl = 24;

  /// Tam yuvarlak: birincil düğmeler, kategori çipi, durum rozeti, kaydırma tutamacı.
  static const double full = 9999;
}
