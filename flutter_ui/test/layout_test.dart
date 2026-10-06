import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/controller.dart';
import 'package:flutter_ui/design.dart';
import 'package:flutter_ui/download.dart';
import 'package:flutter_ui/home.dart';
import 'package:flutter_ui/settings.dart';
import 'package:flutter_ui/strings.dart';

EuiccController fixture() {
  final controller = EuiccController();
  controller.loading = false;
  controller.configuration = {
    'version': '2.0',
    'fingerprint': '2C01AD79D81F67F34D0001979A4B41C9D1D35B78',
    'systemLocale': 'it-IT',
    'language': '',
  };
  controller.preferences = {
    'notificationDownload': true,
    'notificationDelete': true,
    'notificationSwitch': false,
    'developer': true,
    'disableSafeguard': false,
    'verboseLogging': false,
    'forceTpdu': false,
    'refreshAfterSwitch': true,
    'unfiltered': false,
    'ignoreTls': false,
    'mss': 63,
  };
  controller.selected = {
    'slot': 0,
    'port': 0,
    'se': 0,
    'title': 'SIM 1',
    'eid': '89049032000000000000000000000000',
    'freeSpace': '320 KiB',
  };
  controller.cards = [controller.selected!];
  controller.profiles = [
    {
      'name': 'mineo',
      'provider': 'KDDI',
      'iccid': '8981000000000000000',
      'enabled': true,
      'canDisable': false,
    },
    {
      'name': 'A long profile name that must fit without clipping',
      'provider': 'lifecell',
      'iccid': '8981000000000000001',
      'enabled': false,
      'canEnable': true,
    },
  ];
  return controller;
}

Widget harness(Widget child, Locale locale, {double scale = 2}) => MaterialApp(
  theme: flowTheme(Brightness.light),
  locale: locale,
  supportedLocales: [locale],
  localizationsDelegates: const [
    StringsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final tag in [
      'en',
      'zh-CN',
      'zh-TW',
      'ja',
      'ko',
      'ar',
      'fr',
      'de',
      'es',
    ]) {
      jsonDecode(await rootBundle.loadString('assets/i18n/$tag.json'));
    }
  });
  const locales = [
    Locale('en'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
    Locale('ja'),
    Locale('ko'),
    Locale('ar'),
    Locale('fr'),
    Locale('de'),
    Locale('es'),
  ];
  for (final locale in locales) {
    testWidgets('320dp and large text remain usable in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = fixture();
      for (final page in [
        HomePage(controller: controller),
        SettingsPage(controller: controller),
        DownloadPage(controller: controller),
      ]) {
        await tester.pumpWidget(harness(page, locale));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
        expect(find.byType(page.runtimeType), findsOneWidget);
        expect(find.byType(GlassPanel), findsWidgets);
        expect(tester.takeException(), isNull);
        final scroll = find.byType(Scrollable).first;
        await tester.drag(scroll, const Offset(0, -5000));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets(
    'active profile cannot be deleted or disabled with safeguards on',
    (tester) async {
      final controller = fixture();
      await tester.pumpWidget(
        harness(
          ProfileCard(
            profile: controller.profiles.first,
            locked: false,
            onAction: (_) {},
          ),
          const Locale('en'),
          scale: 1,
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Disable'), findsNothing);
      controller.dispose();
    },
  );

  testWidgets(
    'only supported languages are shown and unsupported system locale is labeled',
    (tester) async {
      final controller = fixture();
      await tester.pumpWidget(
        harness(
          LanguagePage(controller: controller),
          const Locale('en'),
          scale: 1,
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Follow system language (English)'), findsOneWidget);
      expect(find.text('Italiano'), findsNothing);
      expect(find.text('简体中文'), findsOneWidget);
      controller.dispose();
    },
  );
}
