import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/controller.dart';
import 'package:flutter_ui/home.dart';

import 'layout_test.dart' show fixture, harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late EuiccController controller;
  late List<MethodCall> calls;
  Json response = {};
  setUpAll(() async {
    await rootBundle.loadString('assets/i18n/en.json');
  });
  setUp(() {
    controller = fixture();
    calls = [];
    response = {'changed': true, 'customIcon': 'new-icon'};
    messenger.setMockMethodCallHandler(EuiccController.control, (call) async {
      calls.add(call);
      return response;
    });
  });
  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(EuiccController.control, null);
  });

  test(
    'custom icons update only the chosen profile without changing card state',
    () async {
      await controller.setProfileIcon(controller.profiles.first, 'gallery');
      expect(calls.single.method, 'profileIcon');
      expect(calls.single.arguments, {
        ...controller.cardArgs,
        'iccid': controller.profiles.first['iccid'],
        'source': 'gallery',
      });
      expect(controller.profiles.first['customIcon'], 'new-icon');
      expect(controller.profiles.first['enabled'], true);
      expect(controller.profiles.last.containsKey('customIcon'), false);
      expect(controller.reading, false);
      response = {'changed': true, 'customIcon': null};
      await controller.setProfileIcon(controller.profiles.first, 'reset');
      expect(controller.profiles.first['customIcon'], isNull);
    },
  );

  test(
    'cancel and failure preserve the previous icon and unlock the interface',
    () async {
      controller.profiles.first['customIcon'] = 'previous';
      response = {'changed': false};
      await controller.setProfileIcon(controller.profiles.first, 'camera');
      expect(controller.profiles.first['customIcon'], 'previous');
      messenger.setMockMethodCallHandler(EuiccController.control, (_) async {
        throw PlatformException(code: 'operation_failed');
      });
      await expectLater(
        controller.setProfileIcon(controller.profiles.first, 'gallery'),
        throwsA(isA<PlatformException>()),
      );
      expect(controller.profiles.first['customIcon'], 'previous');
      expect(controller.reading, false);
    },
  );

  test(
    'a photo selected for a removed card does not update the replacement card',
    () async {
      final pending = Completer<Json>();
      messenger.setMockMethodCallHandler(
        EuiccController.control,
        (_) => pending.future,
      );
      final operation = controller.setProfileIcon(
        controller.profiles.first,
        'gallery',
      );
      await Future<void>.delayed(Duration.zero);
      controller.selected = {
        ...controller.selected!,
        'eid': 'replacement-card',
      };
      pending.complete(response);
      await operation;
      expect(controller.profiles.first.containsKey('customIcon'), false);
    },
  );

  testWidgets('active profiles offer gallery, camera and restore actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(HomePage(controller: controller), const Locale('en'), scale: 1),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ProfileCard).first,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change icon'));
    await tester.pumpAndSettle();
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Restore default icon'), findsOneWidget);
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(calls.single.arguments['source'], 'camera');
    expect(tester.takeException(), isNull);
  });
}
