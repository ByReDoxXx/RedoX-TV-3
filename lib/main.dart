import 'package:flutter/material.dart';

import 'app.dart';
import 'core/layout/form_factor.dart';

void main() {
  // TV'de dokunma yok, odak her an görünür olmalı. Android varsayılanı "touch"
  // kipidir ve halka ilk tuşa kadar gizli kalır (emülatörde doğrulandı).
  if (FormFactor.current == FormFactor.tv) {
    WidgetsFlutterBinding.ensureInitialized();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  }
  runApp(const RedoxApp());
}
