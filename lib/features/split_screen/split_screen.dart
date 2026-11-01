import 'package:flutter/foundation.dart';

import '../../core/content/live_channel.dart';

/// Bölünmüş Ekran'ın karoları: en çok dört kanal, 2'li ya da 4'lü düzen.
/// Oturum boyunca durur (bölüm değişince karolar kalır; uygulama kapanınca
/// boşalır).
///
/// [maxLayout]: cihazın aynı anda oynatabildiği yayın. Chromecast with Google
/// TV'de ölçüldü (2026-11-01): iki yayın sorunsuz, üçüncü siyah kalır
/// (donanım çözücü yok), dördüncüde arayüz 5 sn donar ve sistem uygulamayı
/// kapatır (ANR). TV'de 2'dir.
class SplitScreen extends ChangeNotifier {
  SplitScreen({this.maxLayout = maxSlots}) : assert(maxLayout == 2 || maxLayout == maxSlots), _layout = maxLayout;

  static const maxSlots = 4;

  /// TV'de aynı anda en çok yayın (yukarıdaki ölçüm).
  static const tvMaxLayout = 2;

  final int maxLayout;
  final List<LiveChannel?> _slots = List.filled(maxSlots, null);
  int _layout;

  /// Görünen karo sayısı: 2 ya da 4.
  int get layout => _layout;

  set layout(int value) {
    assert(value == 2 || value == maxSlots);
    if (value == _layout || value > maxLayout) return;
    _layout = value;
    notifyListeners();
  }

  /// Görünen karolar (düzen kadar).
  List<LiveChannel?> get slots => List.unmodifiable(_slots.take(_layout));

  /// Kanalı ilk boş karoya koyar (zaten varsa yerinde kalır). 2'li düzen
  /// doluysa (cihaz izin veriyorsa) 4'lüye geçer. Hepsi doluysa -1.
  int add(LiveChannel c) {
    final existing = _slots.indexOf(c);
    if (existing >= 0 && existing < _layout) return existing;
    var i = _slots.take(_layout).toList().indexOf(null);
    if (i < 0 && _layout < maxLayout) {
      _layout = maxLayout;
      i = _slots.indexOf(null);
    }
    if (i < 0) return -1;
    _slots[i] = c;
    notifyListeners();
    return i;
  }

  void put(int index, LiveChannel c) {
    _slots[index] = c;
    notifyListeners();
  }

  void clear(int index) {
    _slots[index] = null;
    notifyListeners();
  }
}
