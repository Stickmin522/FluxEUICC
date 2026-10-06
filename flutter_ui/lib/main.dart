import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controller.dart';
import 'design.dart';
import 'download.dart';
import 'home.dart';
import 'settings.dart';
import 'strings.dart';
import 'tools_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FluxApp());
}

class FluxApp extends StatefulWidget {
  const FluxApp({super.key, this.controller});
  final EuiccController? controller;
  @override
  State<FluxApp> createState() => _FluxAppState();
}

class _FluxAppState extends State<FluxApp> {
  late final controller = widget.controller ?? EuiccController();
  final navigator = GlobalKey<NavigatorState>();
  final messages = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    controller.showMessage = (key) {
      final context = navigator.currentContext;
      if (context != null) {
        messages.currentState?.showSnackBar(
          SnackBar(content: Text(context.s(key))),
        );
      }
    };
    controller.onIntent = _intent;
    controller.initialize().then((_) async {
      final context = navigator.currentContext;
      if (!mounted || context == null) return;
      if (controller.configuration['skipCompatibility'] != true &&
          controller.intent['route'] == 'home') {
        await openPage(
          navigator.currentContext!,
          CompatibilityPage(controller: controller, initial: true),
        );
      }
      if (!mounted || !context.mounted) return;
      await controller.invoke('permissions');
      if (controller.task?['kind'] == 'download') {
        openPage(
          navigator.currentContext!,
          DownloadProgressPage(controller: controller),
        );
      } else if (controller.intent['route'] != 'home') {
        _intent(controller.intent);
      }
    });
  }

  Future<void> _intent(Json intent) async {
    final context = navigator.currentContext;
    if (context == null) return;
    if (intent['route'] == 'logs') {
      openPage(
        context,
        LogsPage(controller: controller, supplied: intent['log'] as String?),
      );
    } else if (intent['route'] == 'download') {
      final lpa = intent['lpa'] as String?;
      if (lpa != null &&
          !await confirmAction(
            context,
            context.s('deep_link_confirmation_dialog_title'),
            context.s('deep_link_confirmation_dialog_description'),
          )) {
        return;
      }
      if (!context.mounted) return;
      final synthetic = intent['slot'] as int? ?? -1;
      if (synthetic >= 0) {
        final match = controller.cards
            .where(
              (card) =>
                  card['logicalSlot'] == (synthetic >> 16) &&
                  card['se'] == (synthetic & 0xff),
            )
            .firstOrNull;
        if (match != null) await controller.select(match);
      }
      if (context.mounted) {
        openPage(context, DownloadPage(controller: controller, lpa: lpa));
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final tag = controller.configuration['language'] as String? ?? '';
      final parts = tag.split('-');
      return MaterialApp(
        title: 'FluxEUICC',
        debugShowCheckedModeBanner: false,
        restorationScopeId: 'flux',
        navigatorKey: navigator,
        scaffoldMessengerKey: messages,
        theme: flowTheme(Brightness.light),
        darkTheme: flowTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        locale: tag.isEmpty
            ? null
            : Locale(parts.first, parts.length > 1 ? parts[1] : null),
        supportedLocales: const [
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
          Locale('ja'),
          Locale('ko'),
          Locale('ar'),
          Locale('fr'),
          Locale('de'),
          Locale('es'),
        ],
        localeResolutionCallback: (locale, supported) =>
            supportedLocale(locale ?? const Locale('en')),
        localizationsDelegates: const [
          StringsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: controller.loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : RootPage(controller: controller),
      );
    },
  );
}

class RootPage extends StatefulWidget {
  const RootPage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => FlowBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: [
            HomePage(controller: widget.controller),
            SettingsPage(controller: widget.controller),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface
            .withValues(alpha: .85),
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.sim_card_outlined),
            selectedIcon: Icon(Icons.sim_card),
            label: 'eSIM',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: context.s('pref_settings'),
          ),
        ],
      ),
    ),
  );
}
