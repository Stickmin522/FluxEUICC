import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/controller.dart';
import 'package:flutter_ui/design.dart';
import 'package:flutter_ui/home.dart';
import 'package:flutter_ui/strings.dart';

import 'layout_test.dart' show fixture, harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late EuiccController controller;
  late List<MethodCall> calls;
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
      await rootBundle.loadString('assets/i18n/$tag.json');
    }
  });
  setUp(() {
    controller = fixture();
    controller.profiles.first['canDisable'] = true;
    controller.profiles.last['name'] = 'Travel';
    calls = [];
    messenger.setMockMethodCallHandler(EuiccController.control, (call) async {
      calls.add(call);
      return 1;
    });
  });
  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(EuiccController.control, null);
  });

  Future<void> showHome(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      harness(HomePage(controller: controller), const Locale('en'), scale: 1),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, int index, String action) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ProfileCard).at(index),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  FlowButton button(WidgetTester tester, String label) =>
      tester.widget<FlowButton>(
        find.byWidgetPredicate(
          (widget) => widget is FlowButton && widget.label == label,
        ),
      );

  test('active profile pins above addition order and returns to its position when disabled', () {
    controller.profiles = [
      {'iccid': 'c', 'enabled': false, 'order': 2},
      {'iccid': 'b', 'enabled': true, 'order': 1},
      {'iccid': 'a', 'enabled': false, 'order': 0},
    ];
    expect(controller.displayProfiles.map((p) => p['iccid']), ['b', 'a', 'c']);
    controller.profiles[1]['enabled'] = false;
    expect(controller.displayProfiles.map((p) => p['iccid']), ['a', 'b', 'c']);
    expect(controller.profiles.first['iccid'], 'c');
  });

  testWidgets(
    'inactive cards are compact and grayscale while details remain accessible',
    (tester) async {
      await showHome(tester);
      expect(
        tester.getSize(find.byType(ProfileCard).last).height,
        lessThan(tester.getSize(find.byType(ProfileCard).first).height),
      );
      expect(
        find.descendant(
          of: find.byType(ProfileCard).first,
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileCard).last,
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
      expect(find.byType(ProfileDetails), findsOneWidget);
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetails), findsNWidgets(2));
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('8981000000000000001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switch confirmation names both profiles and cancel sends no command',
    (tester) async {
      await showHome(tester);
      await menu(tester, 1, 'Switch');
      expect(find.text('Switch from “mineo” to “Travel”?'), findsOneWidget);
      expect(button(tester, 'Confirm').neutral, false);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await menu(tester, 1, 'Switch');
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(
        calls.single.arguments['iccid'],
        controller.profiles.last['iccid'],
      );
      expect(
        calls.single.arguments['expectedActive'],
        controller.profiles.first['iccid'],
      );
      expect(calls.single.arguments['enable'], true);
    },
  );

  testWidgets(
    'all inactive profiles offer Enable and do not require a switch dialog',
    (tester) async {
      controller.profiles.first['enabled'] = false;
      controller.profiles.first['canEnable'] = true;
      await showHome(tester);
      await menu(tester, 0, 'Enable');
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls.single.arguments['expectedActive'], '');
    },
  );

  for (final action in ['Disable', 'Delete']) {
    testWidgets(
      '$action on the active profile emphasizes Cancel and keeps gray Confirm clickable',
      (tester) async {
        await showHome(tester);
        await menu(tester, 0, action);
        expect(
          find.textContaining('may make the card inaccessible'),
          findsOneWidget,
        );
        expect(button(tester, 'Cancel').neutral, false);
        expect(button(tester, 'Confirm').neutral, true);
        expect(button(tester, 'Confirm').onPressed, isNotNull);
        await tester.tap(find.text('Confirm'));
        await tester.pump();
        expect(
          calls.single.arguments['kind'],
          action == 'Delete' ? 'delete' : 'switch',
        );
        if (action == 'Delete') {
          expect(calls.single.arguments['activeConfirmed'], true);
        } else {
          expect(calls.single.arguments['enable'], false);
        }
      },
    );
  }

  testWidgets(
    'inactive deletion asks once without typed-name input and emphasizes Confirm',
    (tester) async {
      await showHome(tester);
      await menu(tester, 1, 'Delete');
      expect(
        find.text('Delete “Travel”? This cannot be undone.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(button(tester, 'Confirm').neutral, false);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(calls.single.arguments['confirmation'], 'Travel');
      expect(calls.single.arguments['activeConfirmed'], false);
    },
  );

  testWidgets(
    'replacing the selected card during confirmation sends no command',
    (tester) async {
      await showHome(tester);
      await menu(tester, 1, 'Switch');
      controller.selected = {...controller.selected!, 'eid': 'another-card'};
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    },
  );
  testWidgets(
    'confirmation buttons fit narrow screens with large text in every supported language',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in [
        const Locale('en'),
        const Locale('zh', 'CN'),
        const Locale('zh', 'TW'),
        const Locale('ja'),
        const Locale('ko'),
        const Locale('ar'),
        const Locale('fr'),
        const Locale('de'),
        const Locale('es'),
      ]) {
        for (final emphasizeCancel in [false, true]) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            harness(
              Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => confirmProfileAction(
                      context,
                      context.s('profile_disable'),
                      context.s('profile_active_warning'),
                      emphasizeCancel: emphasizeCancel,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
              locale,
            ),
          );
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale / $emphasizeCancel',
          );
        }
      }
    },
  );
}
