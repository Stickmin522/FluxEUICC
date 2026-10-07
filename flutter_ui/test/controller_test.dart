import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const eventMethods = MethodChannel('im.fluxeuicc/events');
  const card = {'slot': 0, 'port': 0, 'se': 0};
  late EuiccController controller;
  late List<String> calls;
  late Json bootstrap;
  bool recover = true;
  bool taskFails = false;

  Future<void> event(Json value) async {
    await messenger.handlePlatformMessage(
      'im.fluxeuicc/events',
      const StandardMethodCodec().encodeSuccessEnvelope(value),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    calls = [];
    bootstrap = {
      'preferences': {},
      'intent': {'route': 'home'},
      'pendingTask': -1,
    };
    recover = true;
    taskFails = false;
    controller = EuiccController();
    messenger.setMockMethodCallHandler(eventMethods, (_) async => null);
    messenger.setMockMethodCallHandler(EuiccController.control, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'bootstrap':
          return bootstrap;
        case 'recover':
          return recover;
        case 'scan':
          return {
            'cards': [
              {
                ...card,
                'profiles': [
                  {'iccid': 'test', 'enabled': true},
                ],
              },
            ],
          };
        case 'profiles':
          return {
            ...card,
            'profiles': [
              {'iccid': 'test', 'enabled': true},
            ],
          };
        case 'task':
          if (taskFails) throw PlatformException(code: 'safeguard_enabled');
          return 42;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(EuiccController.control, null);
    messenger.setMockMethodCallHandler(eventMethods, null);
  });

  test(
    'missing service task unlocks the interface and reports interruption',
    () async {
      bootstrap.addAll({'pendingTask': 42, 'pendingKind': 'download'});
      recover = false;
      await controller.initialize();
      expect(controller.busy, false);
      expect(controller.task?['error'], 'interrupted');
      expect(controller.profiles, isNotEmpty);
    },
  );

  test('recovered download preserves confirmation metadata and reloads on completion', () async {
    bootstrap.addAll({'pendingTask': 42, 'pendingKind': 'download'});
    await controller.initialize();
    expect(controller.busy, true);
    expect(calls, isNot(contains('scan')));
    await event({
      'type': 'task',
      'id': 42,
      'kind': 'download',
      'running': true,
      'phase': 'ConfirmingDownload',
      'metadata': {'name': 'Profile'},
    });
    expect(controller.task?['metadata']['name'], 'Profile');
    await event({
      'type': 'task',
      'id': 42,
      'kind': 'download',
      'running': false,
    });
    expect(controller.busy, false);
    expect(calls.where((call) => call == 'scan').length, 1);
    expect(controller.profiles.single['enabled'], true);
  });

  test(
    'a second operation is blocked until the current service task ends',
    () async {
      await controller.initialize();
      await controller.startTask('switch', {'iccid': 'test', 'enable': true});
      await controller.startTask('delete', {'iccid': 'test'});
      await controller.reload();
      expect(calls.where((call) => call == 'task').length, 1);
      expect(controller.task?['id'], 42);
    },
  );

  test('task launch errors clear the busy state', () async {
    await controller.initialize();
    taskFails = true;
    await expectLater(
      controller.startTask('switch', {'iccid': 'test'}),
      throwsA(isA<PlatformException>()),
    );
    expect(controller.busy, false);
    expect(controller.task?['error'], 'safeguard_enabled');
    await controller.reload();
    expect(controller.profiles, isNotEmpty);
  });
}
