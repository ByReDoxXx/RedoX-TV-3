import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/layout/form_factor.dart';
import 'features/tv/tv_content.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Oynatıcı (libmpv) yerel kütüphanesi.
  MediaKit.ensureInitialized();
  // TV'de dokunma yok, odak her an görünür olmalı. Android varsayılanı "touch"
  // kipidir ve halka ilk tuşa kadar gizli kalır (emülatörde doğrulandı).
  if (FormFactor.current == FormFactor.tv) {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  }
  // Yerleşik Türkçe kanal listesi (şifresiz; numara/sıra eski sürümden).
  final tv = TvContent.fromM3u(await rootBundle.loadString('assets/channels/tr.m3u'));
  runApp(RedoxApp(tv: tv));
}
