import 'package:flutter/material.dart';

import '../../../core/theme/m3e_tokens.dart';
import '../../../core/theme/redox_palette.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/brand_components.dart';
import '../../../core/ui/redox_icon.dart';
import '../widgets/section_frame.dart';

/// 5. Bileşenler: düğmeler, çipler, rozet, kart, odak halkası, story, ilerleme, arama.
class ComponentSection extends StatelessWidget {
  const ComponentSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SectionFrame(
      index: 5,
      title: 'Bileşenler',
      subtitle: 'Logodan tasarım dili: halka, üçlü kontur, statik ışık, eğim, gradyan (design/TASARIM-DILI.md).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Düğmeler', style: t.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const RedoxIcon(RedoxIcons.play, filled: true, color: Colors.white),
                label: const Text('İzle'),
              ),
              FilledButton.tonal(onPressed: () {}, child: const Text('Favorilere ekle')),
              OutlinedButton(onPressed: () {}, child: const Text('Kaynak ekle')),
            ],
          ),
          const SizedBox(height: 28),
          Text('Kategori çipleri', style: t.titleMedium),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              CategoryChip(label: 'Tüm Kanallar', selected: true),
              CategoryChip(label: 'Ulusal'),
              CategoryChip(label: 'Haber'),
              CategoryChip(label: 'Spor'),
              CategoryChip(label: 'Müzik'),
            ],
          ),
          const SizedBox(height: 28),
          Text('Kanal kartı: boşta ve odakta (3 dp halka + statik parıltı)', style: t.titleMedium),
          const SizedBox(height: 16),
          const Row(
            children: [
              _ChannelCardSample(number: '002', name: 'Örnek Kanal', program: 'Akşam Haberleri', progress: 0.35),
              SizedBox(width: 24),
              _ChannelCardSample(number: '001', name: 'Örnek Kanal', program: 'Canlı Yayın', progress: 0.6, focused: true),
            ],
          ),
          const SizedBox(height: 28),
          Text('Story ve arama', style: t.titleMedium),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryAvatar(
                label: 'Yeni kanal',
                child: Center(child: RedoxIcon(RedoxIcons.television, color: scheme.onSurfaceVariant, size: 36)),
              ),
              const SizedBox(width: 24),
              StoryAvatar(
                label: 'Radyo',
                child: Center(child: RedoxIcon(RedoxIcons.radio, color: scheme.onSurfaceVariant, size: 36)),
              ),
              const SizedBox(width: 48),
              SizedBox(
                width: 520,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Kanal, film veya dizi ara…',
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: RedoxIcon(RedoxIcons.search, color: scheme.onSurfaceVariant),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(M3EShape.full),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelCardSample extends StatelessWidget {
  const _ChannelCardSample({
    required this.number,
    required this.name,
    required this.program,
    required this.progress,
    this.focused = false,
  });

  final String number;
  final String name;
  final String program;
  final double progress;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final decoration = focused
        ? RedoxFocus.ring(radius: M3EShape.extraLarge, fill: scheme.surfaceContainerHigh)
        : BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(M3EShape.extraLarge),
          );
    return Container(
      width: 400,
      padding: const EdgeInsets.all(20),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: t.titleLarge!.copyWith(
                  color: RedoxPalette.gold,
                  fontWeight: FontWeight.w700,
                  fontVariations: RedoxType.brandSlant,
                  fontFeatures: M3EType.tabularFigures,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: M3EType.emphasized.titleMedium!.copyWith(
                    fontFamily: RedoxType.family,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const LiveBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Text(program, style: t.bodyLarge!.copyWith(color: scheme.onSurface)),
          const SizedBox(height: 16),
          GoldProgressBar(value: progress),
          const SizedBox(height: 8),
          Text(
            '20:00 – 21:30',
            style: t.labelLarge!.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: M3EType.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
