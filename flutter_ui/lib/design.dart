import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

import 'controller.dart';
import 'marquee.dart';
import 'strings.dart';

const flowPurple = Color(0xFF7655EF);
const flowBlue = Color(0xFF79AAFF);

ThemeData flowTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: flowPurple,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF14121E)
        : const Color(0xFFF7F7FF),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.onSurface,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).black
        .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface.withValues(alpha: .65),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: colors.primary.withValues(alpha: .18),
      elevation: 8,
      menuPadding: const EdgeInsets.all(8),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.primary.withValues(alpha: .12)),
      ),
    ),
  );
}

class FlowBackground extends StatelessWidget {
  const FlowBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF21192F), Color(0xFF151A29), Color(0xFF14121E)]
              : const [Color(0xFFF5EFFF), Color(0xFFF4F7FF), Color(0xFFFCFAFF)],
        ),
      ),
      child: child,
    );
  }
}

class FlowPage extends StatelessWidget {
  const FlowPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => FlowBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: bottom,
    ),
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(22),
    this.active = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: active ? .07 : .025),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: colors.surface.withValues(alpha: active ? .88 : .7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: active
                ? colors.primary.withValues(alpha: .28)
                : colors.onSurface.withValues(alpha: .04),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class FlowButton extends StatelessWidget {
  const FlowButton({super.key, required this.label, this.icon, this.onPressed});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: LinearGradient(
        colors: onPressed == null
            ? [Colors.grey.shade400, Colors.grey.shade400]
            : const [Color(0xFF9668FF), Color(0xFF6C6BF5), flowBlue],
      ),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 25),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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

class MenuLabel extends StatelessWidget {
  const MenuLabel({
    super.key,
    required this.icon,
    required this.label,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = danger ? colors.error : colors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: danger ? colors.error : null),
            ),
          ),
        ],
      ),
    );
  }
}

class SlotGlyph extends StatelessWidget {
  const SlotGlyph({super.key, this.usb = false});
  final bool usb;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: usb
          ? Icon(Icons.usb_rounded, color: colors.primary, size: 22)
          : CustomPaint(painter: _SlotPainter(colors.primary, colors.surface)),
    );
  }
}

class CardSelector extends StatelessWidget {
  const CardSelector({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final EuiccController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final card = controller.selected!;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (MediaQuery.sizeOf(context).width / 2).clamp(
            0.0,
            constraints.maxWidth,
          );
          return SizedBox(
            key: const Key('card-selector-width'),
            width: width,
            child: PopupMenuButton<int>(
              constraints: BoxConstraints.tightFor(width: width),
              enabled: enabled,
              tooltip: context.s('download_wizard_slot_select'),
              onSelected: (index) => controller.select(controller.cards[index]),
              itemBuilder: (_) => [
                for (var i = 0; i < controller.cards.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SlotGlyph(usb: controller.cards[i]['usb'] == true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OneShotMarquee(
                                  '${controller.cards[i]['title']}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                OneShotMarquee(
                                  '${controller.cards[i]['active'] ?? context.s('no_profile')}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (EuiccController.sameCard(
                            controller.cards[i],
                            card,
                          ))
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
              child: Material(
                color: colors.surface.withValues(alpha: .45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: .22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlotGlyph(usb: card['usb'] == true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OneShotMarquee(
                          '${card['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                          animate: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.expand_more_rounded, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotPainter extends CustomPainter {
  const _SlotPainter(this.color, this.contacts);
  final Color color, contacts;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final sim = Path()
      ..moveTo(12, 6)
      ..lineTo(22, 6)
      ..quadraticBezierTo(24, 6, 24, 8)
      ..lineTo(24, 25)
      ..quadraticBezierTo(24, 27, 22, 27)
      ..lineTo(10, 27)
      ..quadraticBezierTo(8, 27, 8, 25)
      ..lineTo(8, 10)
      ..close();
    canvas.drawPath(sim, Paint()..color = color);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 2; column++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(11 + column * 6, 12 + row * 4, 4, 2.8),
            const Radius.circular(.6),
          ),
          Paint()..color = contacts,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlotPainter old) =>
      color != old.color || contacts != old.contacts;
}

Uint8List? profileIconBytes(String? encoded) {
  if (encoded == null || encoded.isEmpty || encoded.length > 32768) return null;
  try {
    final bytes = base64Decode(encoded);
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    return png || jpeg ? bytes : null;
  } on FormatException {
    return null;
  }
}

class ProfileGlyph extends StatefulWidget {
  const ProfileGlyph({super.key, required this.profile});
  final Json profile;
  @override
  State<ProfileGlyph> createState() => _ProfileGlyphState();
}

class _ProfileGlyphState extends State<ProfileGlyph> {
  Uint8List? bytes;
  @override
  void initState() {
    super.initState();
    bytes = profileIconBytes(
      (widget.profile['customIcon'] ?? widget.profile['icon']) as String?,
    );
  }

  @override
  void didUpdateWidget(ProfileGlyph old) {
    super.didUpdateWidget(old);
    if (old.profile['icon'] != widget.profile['icon'] ||
        old.profile['customIcon'] != widget.profile['customIcon']) {
      bytes = profileIconBytes(
        (widget.profile['customIcon'] ?? widget.profile['icon']) as String?,
      );
    }
  }

  Widget fallback(BuildContext context) {
    final profile = widget.profile;
    final name = '${profile['name'] ?? profile['provider'] ?? ''}'.trim();
    var hash = 2166136261;
    for (final unit in utf8.encode('${profile['iccid'] ?? name}')) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    final color = Color.lerp(
      flowPurple,
      const Color(0xFF456ABA),
      (hash % 17) / 16,
    )!;
    return Container(
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name.isEmpty ? 'e' : name.characters.first.toUpperCase(),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: (hash & (1 << i)) == 0 ? .3 : .95,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 54,
      height: 54,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: bytes == null
            ? fallback(context)
            : ColoredBox(
                color: Colors.white,
                child: Image.memory(
                  bytes!,
                  fit: BoxFit.contain,
                  cacheWidth: 128,
                  cacheHeight: 128,
                  errorBuilder: (context, error, stack) => fallback(context),
                ),
              ),
      ),
    ),
  );
}

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.sim_card_outlined,
    this.action,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      children: [
        Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class BusyBanner extends StatelessWidget {
  const BusyBanner({super.key, required this.controller, this.onTap});
  final EuiccController controller;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    if (!controller.busy) return const SizedBox.shrink();
    final kind = controller.task?['kind'] ?? 'switch';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.s(
                  kind == 'reset'
                      ? 'task_euicc_memory_reset'
                      : 'task_profile_$kind',
                ),
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

Future<void> copyValue(
  BuildContext context,
  String value, [
  String message = 'ui_copy',
]) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.s(message))));
  }
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.s('ui_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(context.s('ui_continue')),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> editValue(
  BuildContext context,
  String title, {
  String value = '',
  String? hint,
  String? message,
  String? mustMatch,
  bool multiline = false,
}) async {
  final editor = TextEditingController(text: mustMatch == null ? value : '');
  final result = await showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: editor,
                autofocus: true,
                minLines: multiline ? 5 : 1,
                maxLines: multiline ? 10 : 1,
                decoration: InputDecoration(hintText: hint),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.s('ui_cancel')),
          ),
          FilledButton(
            onPressed: mustMatch != null && editor.text != mustMatch
                ? null
                : () => Navigator.pop(dialog, editor.text),
            child: Text(context.s('ui_continue')),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  editor.dispose();
  return result;
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
