import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/content/stored_api_key.dart';
import '../../../core/layout/mouse_mode.dart';
import '../../../core/platform/system_text_input.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import 'setting_tiles.dart';

/// Ayarlar › Veriler: kullanıcının kendi servis anahtarı (TMDB, OMDb). Girilen
/// anahtar önce servise sorulur; reddedilirse saklanmaz. Ekranda gösterilmez.
class ApiKeySetting extends StatelessWidget {
  const ApiKeySetting({
    super.key,
    required this.name,
    required this.description,
    required this.store,
    required this.check,
    this.rejectedHint = '',
  });

  /// Servisin adı: "TMDB".
  final String name;
  final String description;
  final StoredApiKey<Object> store;
  final Future<ApiKeyCheck> Function(String key) check;

  /// Reddedilince uyarıya eklenir.
  final String rejectedHint;

  Future<String?> _ask(BuildContext context) => usesSystemTextInput(context)
      ? SystemTextInput.ask(title: '$name anahtarı', kind: TextKind.secret)
      : showDialog<String>(
          context: context,
          builder: (_) => _KeyDialog(title: '$name anahtarı'),
        );

  Future<void> _enter(BuildContext context) async {
    final key = (await _ask(context))?.trim() ?? '';
    if (key.isEmpty) return;
    final result = await check(key);
    if (result != ApiKeyCheck.rejected) await store.set(key);
    if (!context.mounted) return;
    settingToast(context, switch (result) {
      ApiKeyCheck.valid => '$name anahtarı kaydedildi.',
      ApiKeyCheck.rejected => '$name bu anahtarı kabul etmedi; kaydedilmedi.$rejectedHint',
      ApiKeyCheck.unreachable => '$name servisine ulaşılamadı; anahtar denenmeden kaydedildi.',
    });
  }

  Future<void> _remove(BuildContext context) async {
    if (!await confirmSetting(
      context,
      title: '$name anahtarı kaldırılsın mı?',
      text: 'Bu servisten yeni bilgi gelmez.',
      yes: 'Kaldır',
    )) {
      return;
    }
    await store.set(null);
    if (context.mounted) settingToast(context, '$name anahtarı kaldırıldı.');
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: store.current,
    builder: (context, client, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionSetting(
          title: client == null ? '$name anahtarı: girilmedi' : '$name anahtarı: girildi',
          description: '$description Yalnız bu cihazda saklanır, yedeğe yazılmaz.',
          label: client == null ? 'Anahtarı gir' : 'Anahtarı değiştir',
          icon: RedoxIcons.edit,
          onPressed: () => unawaited(_enter(context)),
        ),
        if (client != null)
          ActionSetting(
            title: '$name anahtarını kaldır',
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
  const _KeyDialog({required this.title});

  final String title;

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
    title: Text(widget.title),
    content: TextField(
      controller: _text,
      autofocus: true,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(hintText: 'Anahtarı yazın ya da yapıştırın'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context)),
      PrimaryButton(label: 'Kaydet', onPressed: _save),
    ],
  );
}
