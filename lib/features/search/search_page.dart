import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/platform/system_text_input.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/channel_logo.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/icon_action_button.dart';
import '../../core/ui/redox_icon.dart';
import '../radio/widgets/station_avatar.dart';

/// Arama: kanal adı, şu an yayındaki program ve radyo adı içinde arar
/// (Türkçe harfler sadeleşir: "trt cocuk" = "TRT Çocuk"). Başlıktaki aramadan
/// açılır (SearchScope); sonuca OK/dokunma kanalı ya da radyoyu açar.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.channels,
    this.radios = const [],
    this.initialQuery = '',
    this.onChannel,
    this.onRadio,
  });

  final List<LiveChannel> channels;
  final List<LiveChannel> radios;
  final String initialQuery;
  final void Function(LiveChannel channel)? onChannel;
  final void Function(LiveChannel station)? onRadio;

  /// En çok bu kadar sonuç (her grupta).
  static const limit = 50;

  static Route<void> route({
    required List<LiveChannel> channels,
    List<LiveChannel> radios = const [],
    String query = '',
    void Function(LiveChannel channel)? onChannel,
    void Function(LiveChannel station)? onRadio,
  }) => MaterialPageRoute(
    builder: (_) =>
        SearchPage(channels: channels, radios: radios, initialQuery: query, onChannel: onChannel, onRadio: onRadio),
  );

  /// Karşılaştırma için sadeleştirme: küçük harf, Türkçe harfler Latin.
  static String fold(String s) {
    const map = {'ı': 'i', 'ğ': 'g', 'ü': 'u', 'ş': 's', 'ö': 'o', 'ç': 'c', 'â': 'a', 'î': 'i', 'û': 'u'};
    final lower = s.toLowerCase().replaceAll('̇', '');
    return lower.split('').map((ch) => map[ch] ?? ch).join();
  }

  /// [query]'yi adında ya da şimdiki programında taşıyan kanallar; adı
  /// eşleşenler önde.
  static List<LiveChannel> match(List<LiveChannel> list, String query) {
    final q = fold(query.trim());
    if (q.isEmpty) return const [];
    final byName = [
      for (final c in list)
        if (fold(c.name).contains(q)) c,
    ];
    final byProgram = [
      for (final c in list)
        if (!byName.contains(c) && fold(c.programTitle ?? '').contains(q)) c,
    ];
    return [...byName, ...byProgram].take(limit).toList();
  }

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  bool get _tv => Theme.of(context).extension<RedoxMetrics>()?.formFactor == FormFactor.tv;

  @override
  void initState() {
    super.initState();
    // TV'de boş açılınca klavye hemen gelsin (telefondaki autofocus gibi).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tv && _controller.text.isEmpty) unawaited(_ask());
    });
  }

  /// TV: cihazın klavyesiyle yerel metin kutusu (Flutter metin alanında
  /// Gboard kumandanın yön tuşlarını alamıyor; HeaderSearch).
  Future<void> _ask() async {
    final q = await SystemTextInput.ask(title: 'Ara', value: _controller.text);
    if (q != null && mounted) setState(() => _controller.text = q);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    final pad = phone ? 16.0 : 40.0;
    final q = _controller.text;
    final channels = SearchPage.match(widget.channels, q);
    final radios = SearchPage.match(widget.radios, q);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
              child: Row(
                children: [
                  IconActionButton(icon: RedoxIcons.close, onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tv
                        ? _QueryButton(text: q, onPressed: _ask)
                        : TextField(
                            controller: _controller,
                            // Telefonda boş açılır: klavye hemen gelsin.
                            autofocus: phone || q.isEmpty,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Kanal, program veya radyo ara…',
                              hintStyle: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: RedoxIcon(RedoxIcons.search, color: RedoxRoles.tertiary),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RedoxRadius.full),
                                borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RedoxRadius.full),
                                borderSide: BorderSide(color: RedoxRoles.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RedoxRadius.full),
                                borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: q.trim().isEmpty
                  ? const SizedBox.shrink()
                  : channels.isEmpty && radios.isEmpty
                  ? Center(
                      child: Text('Sonuç yok', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                      children: [
                        if (channels.isNotEmpty) _Group('Kanallar (${channels.length})'),
                        for (final c in channels)
                          _Result(
                            title: c.name,
                            subtitle: c.programTitle ?? '${c.number} · ${c.category}',
                            leading: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 0.8),
                            onPressed: widget.onChannel == null ? null : () => widget.onChannel!(c),
                          ),
                        if (radios.isNotEmpty) _Group('Radyolar (${radios.length})'),
                        for (final r in radios)
                          _Result(
                            title: r.name,
                            subtitle: r.category,
                            leading: StationAvatar(station: r, size: 48),
                            onPressed: widget.onRadio == null ? null : () => widget.onRadio!(r),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: RedoxRoles.secondary)),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.title, required this.subtitle, required this.leading, this.onPressed});

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FocusGlow(
        borderRadius: radius,
        scale: 1,
        builder: (context, active) => Material(
          color: active ? RedoxRoles.surfaceContainerHigh : RedoxRoles.surfaceContainer,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  SizedBox.square(dimension: 48, child: leading),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// TV'deki arama kutusu: odaklanır, OK yerel klavyeyi açar.
class _QueryButton extends StatelessWidget {
  const _QueryButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pill = BorderRadius.circular(RedoxRadius.full);
    return FocusGlow(
      borderRadius: pill,
      scale: 1,
      builder: (context, active) => Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? RedoxSeeds.amber : RedoxRoles.outlineVariant.withValues(alpha: 0.5),
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          autofocus: true,
          borderRadius: pill,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: RedoxIcon(RedoxIcons.search, color: RedoxRoles.tertiary),
                ),
                Expanded(
                  child: Text(
                    text.isEmpty ? 'Kanal, program veya radyo ara… (OK)' : text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge!.copyWith(
                      color: text.isEmpty ? RedoxRoles.onSurfaceVariant : RedoxRoles.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
