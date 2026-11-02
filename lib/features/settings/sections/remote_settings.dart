import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/platform/system_text_input.dart';
import '../../../core/remote/remote_host.dart';
import '../../../core/ui/redox_icon.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Telefon kumandası (yalnız TV): telefonda görünen ad, eşleşmiş
/// ve bağlı telefonlar, eşleşmeleri unutma.
class RemoteSettings extends StatefulWidget {
  const RemoteSettings({super.key, required this.host, this.padding = EdgeInsets.zero});

  final RemoteHost host;
  final EdgeInsets padding;

  @override
  State<RemoteSettings> createState() => _RemoteSettingsState();
}

class _RemoteSettingsState extends State<RemoteSettings> {
  RemoteHost get _host => widget.host;

  Future<void> _rename() async {
    final text = await SystemTextInput.ask(title: 'TV adı', value: _host.name, maxLength: 32);
    final name = text?.trim() ?? '';
    if (name.isEmpty || name == _host.name) return;
    await _host.rename(name);
    if (mounted) setState(() {});
  }

  Future<void> _forget() async {
    if (!await confirmSetting(
      context,
      title: 'Eşleşmeler unutulsun mu?',
      text: 'Bağlı telefonlar düşer; kumanda olarak yeniden kullanmak için TV ekranındaki kodla eşleşmeleri gerekir.',
      yes: 'Unut',
    )) {
      return;
    }
    await _host.forget();
    if (mounted) {
      setState(() {});
      settingToast(context, 'Eşleşmeler unutuldu.');
    }
  }

  @override
  Widget build(BuildContext context) => SettingsBody(
    title: 'Telefon kumandası',
    padding: widget.padding,
    children: [
      ActionSetting(
        title: 'Telefonda görünen ad: ${_host.name}',
        description: 'Telefon, aynı Wi-Fi ağındaki TV\'leri bu adla listeler (Diğer › Kumanda).',
        label: 'Adı değiştir',
        icon: RedoxIcons.edit,
        onPressed: () => unawaited(_rename()),
      ),
      ValueListenableBuilder(
        valueListenable: _host.connected,
        builder: (context, connected, _) => ActionSetting(
          title: 'Eşleşmiş telefon: ${_host.pairedCount} · şu an bağlı: $connected',
          description: 'Kod 2 dakika geçerlidir; yanlış kod 5 denemede iptal olur.',
          label: 'Eşleşmeleri unut',
          icon: RedoxIcons.delete,
          onPressed: _host.pairedCount == 0 ? null : () => unawaited(_forget()),
        ),
      ),
    ],
  );
}
