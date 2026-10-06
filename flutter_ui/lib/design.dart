import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

import 'controller.dart';
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

class SimGlyph extends StatelessWidget {
  const SimGlyph({super.key, this.active = false, this.size = 54});
  final bool active;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (active ? colors.primary : colors.onSurfaceVariant).withValues(
          alpha: .09,
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(
        Icons.sim_card_outlined,
        size: size * .58,
        color: active ? colors.primary : colors.onSurfaceVariant,
      ),
    );
  }
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
