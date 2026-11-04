import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/layout/mouse_mode.dart';
import '../../../core/platform/system_text_input.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import 'setting_tiles.dart';

/// Ayarlar › Veriler: kullanıcının kendi TMDB anahtarı. Girilen anahtar önce
/// TMDB'ye sorulur; reddedilirse saklanmaz. Ekranda gösterilmez.
class TmdbKeySetting extends StatelessWidget {
  const TmdbKeySetting({super.key, required this.check});

  final Future<TmdbKeyCheck> Function(String key) check;

  Future<String?> _ask(BuildContext context) => usesSystemTextInput(context)
      ? SystemTextInput.ask(title: 'TMDB anahtarı', kind: TextKind.secret)
      : showDialog<String>(context: context, builder: (_) => const _KeyDialog());

  Future<void> _enter(BuildContext context) async {
    final key = (await _ask(context))?.trim() ?? '';
    if (key.isEmpty) return;
    final result = await check(key);
    if (result != TmdbKeyCheck.rejected) await Tmdb.setKey(key);
    if (!context.mounted) return;
    settingToast(context, switch (result) {
      TmdbKeyCheck.valid => 'TMDB anahtarı kaydedildi.',
      TmdbKeyCheck.rejected => 'TMDB bu anahtarı kabul etmedi; kaydedilmedi.',
      TmdbKeyCheck.unreachable => 'TMDB\'ye ulaşılamadı; anahtar denenmeden kaydedildi.',
    });
  }

  Future<void> _remove(BuildContext context) async {
    if (!await confirmSetting(
      context,
      title: 'TMDB anahtarı kaldırılsın mı?',
      text: 'Film ve dizilerin yeni afiş, özet ve puanları gelmez.',
      yes: 'Kaldır',
    )) {
      return;
    }
    await Tmdb.setKey(null);
    if (context.mounted) settingToast(context, 'TMDB anahtarı kaldırıldı.');
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: Tmdb.current,
    builder: (context, tmdb, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionSetting(
          title: tmdb == null ? 'TMDB anahtarı: girilmedi' : 'TMDB anahtarı: girildi',
          description:
              'Film ve dizi afişleri, özetleri ve puanları için. Anahtarı themoviedb.org hesabınızda Ayarlar › API '
              'bölümünden alın. Yalnız bu cihazda saklanır, yedeğe yazılmaz.',
          label: tmdb == null ? 'Anahtarı gir' : 'Anahtarı değiştir',
          icon: RedoxIcons.edit,
          onPressed: () => unawaited(_enter(context)),
        ),
        if (tmdb != null)
          ActionSetting(
            title: 'TMDB anahtarını kaldır',
            label: 'Kaldır',
            icon: RedoxIcons.delete,
            onPressed: () => unawaited(_remove(context)),
          ),
      ],
    ),
  );
}

/// Dokunmatik ve masaüstünde anahtar kutusu; yapıştırılabilir, gizli yazılır.
class _KeyDialog extends StatefulWidget {
  const _KeyDialog();

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _text.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: RedoxRoles.surfaceContainerHigh,
    title: const Text('TMDB anahtarı'),
    content: TextField(
      controller: _text,
      autofocus: true,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(hintText: 'API anahtarı ya da okuma belirteci'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context)),
      PrimaryButton(label: 'Kaydet', onPressed: _save),
    ],
  );
}
