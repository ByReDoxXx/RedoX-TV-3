import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/category_chip.dart';
import '../../../core/ui/header_search.dart';
import '../../../core/ui/icon_action_button.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/remote_hints.dart';
import '../../../core/ui/segmented_toggle.dart';
import '../../../core/ui/status_badge.dart';
import '../widgets/section_frame.dart';

/// 5. Kontroller: düğmeler, çipler, rozetler, ilerleme, giriş ve seçim.
class ComponentSection extends StatelessWidget {
  const ComponentSection({super.key});

  static const _gap = SizedBox(width: 20);

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant);
    return SectionFrame(
      index: 5,
      title: 'Kontroller',
      subtitle: 'Odak = D-pad, klavye veya fare üstü. Odakta büyüme yay fiziğiyle; ışıma hemen açılır.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GroupLabel('Düğmeler · boşta'),
          Row(
            children: [
              PrimaryButton(label: 'Canlı yayına gir', icon: RedoxIcons.play, keyHint: 'OK', onPressed: () {}),
              _gap,
              GlassButton(label: 'Çoklu ekrana ekle', icon: RedoxIcons.splitScreen, onPressed: () {}),
              _gap,
              IconActionButton(icon: RedoxIcons.favorites, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const GroupLabel('Düğmeler · odakta'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                PrimaryButton(label: 'Canlı yayına gir', icon: RedoxIcons.play, keyHint: 'OK', onPressed: () {}, focused: true),
                const SizedBox(width: 32),
                GlassButton(label: 'Çoklu ekrana ekle', icon: RedoxIcons.splitScreen, onPressed: () {}, focused: true),
                const SizedBox(width: 32),
                IconActionButton(icon: RedoxIcons.favorites, onPressed: () {}, focused: true),
              ],
            ),
          ),
          const GroupLabel('Kategori çipleri'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              CategoryChip(label: 'Tüm kanallar', selected: true, onPressed: () {}),
              CategoryChip(label: 'Ulusal', onPressed: () {}),
              CategoryChip(label: 'Haber', onPressed: () {}),
              CategoryChip(label: 'Spor', onPressed: () {}, focused: true),
              CategoryChip(label: 'Müzik', onPressed: () {}),
            ],
          ),
          const SizedBox(height: 6),
          Text('Seçili: kızıl – kor #A86500, beyaz yazı her noktada >= 4,5:1.', style: label),
          const GroupLabel('Kumanda ipuçları (TV, ekranın altında)'),
          const RemoteHintBar(hints: RemoteHintBar.browse),
          const GroupLabel('Rozetler ve ilerleme'),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatusBadge(label: 'CANLI', pulse: true),
              StatusBadge(label: '4K HDR', tone: BadgeTone.gold),
              StatusBadge(label: 'YENİ', tone: BadgeTone.amber),
              StatusBadge(label: 'KAYITTA', tone: BadgeTone.neutral),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: RedoxProgressBar(value: 0.35)),
              SizedBox(width: 16),
              Expanded(child: RedoxProgressBar(value: 0.74, thermal: true, height: 8)),
              SizedBox(width: 16),
              Expanded(child: RedoxProgressBar(value: 0.6, color: RedoxSeeds.crimson)),
            ],
          ),
          const SizedBox(height: 6),
          Text('İzlenme (amber) · canlı maç süresi (ısıl) · oynatma konumu (kızıl). İz: surface-container-lowest.', style: label),
          const GroupLabel('Giriş ve seçim'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(labelText: 'Kaynak adı'),
                  child: Text('RedoX Liste'),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: InputDecorator(
                  isFocused: true,
                  decoration: InputDecoration(labelText: 'M3U adresi'),
                  child: Text('https://…/liste.m3u8'),
                ),
              ),
              const SizedBox(width: 16),
              Checkbox(value: true, onChanged: (_) {}),
              Checkbox(value: false, onChanged: (_) {}),
              RadioGroup<int>(
                groupValue: 0,
                onChanged: (_) {},
                child: const Row(children: [Radio<int>(value: 0), Radio<int>(value: 1)]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const SegmentedToggle(
                segments: [
                  ToggleSegment('Kart görünümü', RedoxIcons.splitScreen),
                  ToggleSegment('EPG çizelgesi', RedoxIcons.clock),
                ],
                selectedIndex: 0,
                focusedIndex: 1,
              ),
              const SizedBox(width: 24),
              const Expanded(child: HeaderSearch()),
            ],
          ),
        ],
      ),
    );
  }
}
