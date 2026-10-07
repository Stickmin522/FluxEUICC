import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/controller.dart';
import 'package:flutter_ui/design.dart';
import 'package:flutter_ui/download.dart';
import 'package:flutter_ui/home.dart';

import 'layout_test.dart' show fixture, harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late EuiccController controller;
  late List<MethodCall> calls;
  const activation = 'LPA:1\$rsp.example\$activation';

  setUpAll(() async {
    await rootBundle.loadString('assets/i18n/en.json');
    await rootBundle.loadString('assets/i18n/ar.json');
  });

  setUp(() {
    controller = fixture();
    calls = [];
    messenger.setMockMethodCallHandler(EuiccController.control, (call) async {
      calls.add(call);
      if (call.method == 'image') return activation;
      if (call.method == 'parse') {
        return {'address': 'rsp.example', 'matchingId': 'activation'};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': activation};
      return null;
    });
  });
  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(EuiccController.control, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> show(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(harness(page, const Locale('en'), scale: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'download entry contains four methods without input or continue',
    (tester) async {
      await show(tester, DownloadPage(controller: controller));
      expect(find.byType(DownloadMethodCard), findsNWidgets(4));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FlowButton), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('activation-code-option')),
      );
      await tester.tap(find.byKey(const Key('activation-code-option')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivationCodePage), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(FlowButton), findsOneWidget);
    },
  );

  testWidgets('manual option opens the full download form', (tester) async {
    await show(tester, DownloadPage(controller: controller));
    await tester.ensureVisible(find.byKey(const Key('manual-input-option')));
    await tester.tap(find.byKey(const Key('manual-input-option')));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadDetailsPage), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets('typed activation code is parsed before opening the details', (
    tester,
  ) async {
    await show(tester, ActivationCodePage(controller: controller));
    await tester.enterText(find.byType(TextFormField), activation);
    await tester.ensureVisible(find.byType(FlowButton));
    await tester.tap(find.byType(FlowButton));
    await tester.pumpAndSettle();
    expect(calls.single.arguments, {'input': activation});
    expect(find.byType(DownloadDetailsPage), findsOneWidget);
    expect(find.text('rsp.example'), findsOneWidget);
  });

  testWidgets('clipboard option still parses and opens the details', (
    tester,
  ) async {
    await show(tester, ActivationCodePage(controller: controller));
    await tester.tap(find.widgetWithText(TextButton, 'Load from Clipboard'));
    await tester.pumpAndSettle();
    expect(calls.single.arguments, {'input': activation});
    expect(find.byType(DownloadDetailsPage), findsOneWidget);
  });

  testWidgets(
    'gallery and incoming activation links retain the download flow',
    (tester) async {
      await show(tester, DownloadPage(controller: controller));
      await tester.tap(find.text('Import from image'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['image', 'parse']);
      expect(find.byType(DownloadDetailsPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      calls.clear();
      await show(tester, DownloadPage(controller: controller, lpa: activation));
      expect(calls.single.method, 'parse');
      expect(find.byType(DownloadDetailsPage), findsOneWidget);
    },
  );

  testWidgets('menus use rounded themed surfaces and action icons in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      harness(HomePage(controller: controller), const Locale('ar')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.byType(MenuLabel), findsNWidgets(3));
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or corrupt profile icons fall back to distinct marks', (
    tester,
  ) async {
    expect(profileIconBytes('invalid image'), isNull);
    expect(profileIconBytes(''), isNull);
    await show(
      tester,
      Row(
        children: [
          ProfileGlyph(profile: controller.profiles[0]),
          ProfileGlyph(profile: controller.profiles[1]),
        ],
      ),
    );
    expect(find.text('M'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    final tiles = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(ProfileGlyph),
            matching: find.byType(Container),
          ),
        )
        .where((tile) => tile.color != null)
        .map((tile) => tile.color)
        .toSet();
    expect(tiles.length, 2);
    expect(tester.takeException(), isNull);
  });
}
