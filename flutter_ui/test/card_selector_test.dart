import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/home.dart';
import 'package:flutter_ui/marquee.dart';

import 'layout_test.dart' show fixture, harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await rootBundle.loadString('assets/i18n/en.json');
    await rootBundle.loadString('assets/i18n/ar.json');
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('half-screen selector and single-line names in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = fixture();
      controller.selected!['active'] = 'A very long operator profile name';
      await tester.pumpWidget(
        harness(HomePage(controller: controller), locale),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('card-selector-width'))).width,
        160,
      );
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      final name = find.text('A very long operator profile name');
      expect(tester.widget<Text>(name).maxLines, 1);
      expect(tester.widget<Text>(name).softWrap, false);
      expect(find.byType(ShaderMask), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('long names scroll once and return to their original position', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              child: OneShotMarquee('A very long operator profile name'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final transform = find.descendant(
      of: find.byType(OneShotMarquee),
      matching: find.byType(Transform),
    );
    expect(
      tester.widget<Transform>(transform).transform.getTranslation().x,
      lessThan(0),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.widget<Transform>(transform).transform.getTranslation().x, 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion keeps the name stationary with a fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                child: OneShotMarquee('Long profile name'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
