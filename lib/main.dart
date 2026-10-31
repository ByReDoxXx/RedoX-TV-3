import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/layout/form_factor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Oynatıcı (libmpv) yerel kütüphanesi.
  MediaKit.ensureInitialized();
  // TV'de dokunma yok, odak her an görünür olmalı. Android varsayılanı "touch"
  // kipidir ve halka ilk tuşa kadar gizli kalır (emülatörde doğrulandı).
  if (FormFactor.current == FormFactor.tv) {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  }
  runApp(const RedoxApp());
}
