import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/form_factor.dart';
import '../layout/mouse_mode.dart';
import '../navigation/search_scope.dart';
import '../platform/system_text_input.dart';
import '../navigation/double_back_to_exit.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_metrics.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';
import 'icon_action_button.dart';
import 'redox_icon.dart';

/// Başlıktaki arama: telefonda ikon düğmesi, TV/tablet/masaüstünde giriş kutusu.
/// Ayrı bir arama sekmesi yoktur. Kutu hap biçimlidir (zip'teki tasarım);
/// odakta 2px amber kenar (DESIGN.md "Input Fields").
///
/// Kutu iki kiplidir (TV emülatöründe görülen sorunlar üzerine):
/// - **Dinlenme:** odaklanabilir düğme. D-pad üstünden geçerken klavye açılmaz,
///   yön tuşları kutuda takılmaz.
/// - **Yazma:** OK (veya dokunma/tıklama) ile açılır; klavye gelir. Klavyenin
///   onay tuşu, Geri ya da klavyenin kapanması yazmayı bitirir ve odak kutuya
///   döner. Geri bu sırada uygulamadan çıkmaz.
///
/// TV'de yazma kipi yoktur: OK cihazın kendi klavyesiyle yerel metin kutusunu
/// açar ([SystemTextInput]). Flutter metin alanı açıkken Gboard kumandanın yön
/// tuşlarını alamıyordu (Chromecast'te: "klavye kumandadan hareket etmiyor").
class HeaderSearch extends StatefulWidget {
  const HeaderSearch({super.key, this.hint = 'Kanal, program veya film ara…', this.onOpen, this.onSubmitted});

  final String hint;

  /// Telefonda ikon düğmesine basılınca (arama sayfası açılır).
  final VoidCallback? onOpen;
  final ValueChanged<String>? onSubmitted;

  @override
  State<HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<HeaderSearch> {
  final _controller = TextEditingController();
  final _boxNode = FocusNode(debugLabel: 'HeaderSearch kutu');
  final _fieldNode = FocusNode(debugLabel: 'HeaderSearch alan');
  bool _editing = false;

  /// Son görülen klavye yüksekliği: klavye kapanınca yazma biter.
  double _keyboard = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (_editing && _keyboard > 0 && keyboard == 0) {
      // Klavye Geri ile kapandı (Geri klavyeye gider, uygulamaya gelmez).
      // Telefon/tablette geçerli; TV klavyesi (Gboard) ekran payı bildirmez,
      // orada yazma ikinci Geri ile biter (emülatörde görüldü).
      WidgetsBinding.instance.addPostFrameCallback((_) => _stop());
    }
    _keyboard = keyboard;
  }

  /// Yazarken Geri'yi alan kök sayfa koruyucusu (varsa).
  DoubleBackToExitState? _backGuard;

  @override
  void dispose() {
    _backGuard?.removeHandler(_onBack);
    _controller.dispose();
    _boxNode.dispose();
    _fieldNode.dispose();
    super.dispose();
  }

  /// Yazarken Geri: yazma biter, Geri tüketilir (çıkış uyarısı çıkmaz).
  /// Android Geri'yi önce tuş, sonra "pop" olarak iletir; tuşta yakalamak
  /// pop'u durdurmaz (emülatörde ikisi birden işledi). Bu yüzden Geri,
  /// pop'u alan koruyucuya kayıtlı işleyiciyle karşılanır.
  bool _onBack() {
    _stop();
    return true;
  }

  void _start() {
    if (usesSystemTextInput(context)) {
      unawaited(_askSystem());
      return;
    }
    _backGuard = DoubleBackToExit.maybeOf(context)?..addHandler(_onBack);
    setState(() => _editing = true);
    // Alan bir sonraki karede ağaca girer; odak orada istenir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _fieldNode.requestFocus();
    });
  }

  /// TV: yerel kutuda yazılır; onaylanırsa arama yapılır.
  Future<void> _askSystem() async {
    final q = await SystemTextInput.ask(title: 'Ara', value: _controller.text);
    if (q == null || !mounted) return;
    setState(() => _controller.text = q);
    _submit(q);
  }

  void _submit(String q) {
    if (widget.onSubmitted case final submit?) {
      submit(q);
    } else if (q.trim().isNotEmpty) {
      SearchScope.maybeOf(context)?.open(context, q);
    }
  }

  void _stop() {
    if (!mounted || !_editing) return;
    _backGuard?.removeHandler(_onBack);
    _backGuard = null;
    setState(() => _editing = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _boxNode.requestFocus();
    });
  }

  /// Yazarken Esc (klavye/masaüstü): yazma biter. Kumanda Geri'si
  /// [_onBack] ile işlenir.
  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    if (event is KeyUpEvent) _stop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    if (metrics.formFactor == FormFactor.phone) {
      // Telefonda kutu yok: düğme arama sayfasını açar (önceden işlevsizdi).
      final open = widget.onOpen ?? () => SearchScope.maybeOf(context)?.open(context, '');
      return IconActionButton(icon: RedoxIcons.search, onPressed: open);
    }
    final t = Theme.of(context).textTheme;
    final pill = BorderRadius.circular(RedoxRadius.full);
    const icon = Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: RedoxIcon(RedoxIcons.search, color: RedoxRoles.tertiary),
    );
    if (_editing) {
      return Focus(
        onKeyEvent: _onFieldKey,
        skipTraversal: true,
        canRequestFocus: false,
        child: TextField(
          controller: _controller,
          focusNode: _fieldNode,
          textInputAction: TextInputAction.search,
          onSubmitted: (q) {
            _stop();
            _submit(q);
          },
          onTapOutside: (_) => _stop(),
          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: icon,
            enabledBorder: OutlineInputBorder(
              borderRadius: pill,
              borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: pill,
              borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
            ),
          ),
        ),
      );
    }
    final query = _controller.text;
    return FocusGlow(
      borderRadius: pill,
      scale: 1,
      builder: (context, active) => Semantics(
        button: true,
        label: query.isEmpty ? widget.hint : query,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: RedoxRoles.outlineVariant.withValues(alpha: 0.3))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: _boxNode,
            onTap: _start,
            focusColor: RedoxAccent.inputFocusWash,
            hoverColor: RedoxAccent.inputFocusWash,
            // TextField ile aynı yükseklik: 12 + satır + 12.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  icon,
                  Expanded(
                    child: Text(
                      query.isEmpty ? widget.hint : query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge!.copyWith(
                        color: query.isEmpty ? RedoxRoles.onSurfaceVariant : RedoxRoles.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
