import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/content/source_receiver.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/redox_buttons.dart';

/// Telefondan ekleme penceresi: QR ve kısa yönerge. Yerel sunucu yalnız bu
/// pencere açıkken çalışır; kapanınca durur. Telefondan eklenen liste
/// arkadaki "Listelerim"de hemen belirir.
Future<void> showPhoneQrDialog(BuildContext context, {required SourceReceiver receiver}) => showDialog<void>(
  context: context,
  builder: (_) => PhoneQrDialog(receiver: receiver),
);

class PhoneQrDialog extends StatefulWidget {
  const PhoneQrDialog({super.key, required this.receiver});

  final SourceReceiver receiver;

  @override
  State<PhoneQrDialog> createState() => _PhoneQrDialogState();
}

class _PhoneQrDialogState extends State<PhoneQrDialog> {
  /// null: açılıyor; boş: ağ yok.
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    String? url;
    try {
      url = await widget.receiver.start();
    } on Object {
      url = null;
    }
    if (!mounted) return;
    setState(() {
      _url = url;
      _failed = url == null;
    });
  }

  @override
  void dispose() {
    unawaited(widget.receiver.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final url = _url;
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(RedoxRadius.lg)),
              child: switch ((url, _failed)) {
                (final u?, _) => QrImageView(data: u, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                (_, true) => Center(
                  child: Text(
                    'Ağ bağlantısı yok',
                    textAlign: TextAlign.center,
                    style: t.titleMedium!.copyWith(color: RedoxSeeds.obsidian),
                  ),
                ),
                _ => const Center(child: CircularProgressIndicator(color: RedoxSeeds.crimson)),
              },
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Telefondan ekle', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 12),
                  for (final (i, step) in const [
                    'Telefonu TV ile aynı Wi-Fi ağına bağlayın.',
                    'Kamerayla QR kodunu okutun.',
                    'Açılan sayfada liste adresini yapıştırın ya da telefondaki dosyayı seçin.',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: RedoxSeeds.crimson, shape: BoxShape.circle),
                            child: Text(
                              '${i + 1}',
                              style: t.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(step, style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurface)),
                          ),
                        ],
                      ),
                    ),
                  if (url != null)
                    Text(url.split('?').first, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  PrimaryButton(label: 'Kapat', autofocus: true, onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
