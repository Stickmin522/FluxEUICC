import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef Json = Map<String, dynamic>;
Json json(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? const {});
List<Json> jsonList(Object? value) => (value as List? ?? []).map(json).toList();

class EuiccController extends ChangeNotifier {
  static const control = MethodChannel('im.fluxeuicc/control');
  static const events = EventChannel('im.fluxeuicc/events');
  StreamSubscription<dynamic>? _subscription;
  Json configuration = {}, preferences = {}, intent = {};
  List<Json> cards = [], profiles = [];
  Json? selected, usb, task;
  bool loading = true, scanning = false, reading = false;
  String? error;
  void Function(String)? showMessage;
  void Function(Json)? onIntent;

  bool get busy => task?['running'] == true;
  Json get cardArgs => selected == null
      ? {}
      : {
          for (final key in ['slot', 'port', 'se']) key: selected![key],
        };
  Future<T?> invoke<T>(String name, [Json? arguments]) =>
      control.invokeMethod<T>(name, arguments);

  Future<void> initialize() async {
    try {
      _subscription = events.receiveBroadcastStream().listen(
        _event,
        onError: (_) {
          showMessage?.call('operation_failed');
        },
      );
      configuration = json(await invoke('bootstrap'));
      preferences = json(configuration['preferences']);
      intent = json(configuration['intent']);
      final pending = configuration['pendingTask'] as int? ?? -1;
      if (pending >= 0) {
        task = {
          'id': pending,
          'kind': configuration['pendingKind'],
          'running': true,
          'phase': 'Preparing',
          'progress': 0,
        };
        if (await invoke<bool>('recover', {'id': pending}) != true) {
          task = {
            'id': pending,
            'kind': configuration['pendingKind'],
            'running': false,
            'error': 'interrupted',
          };
        }
      }
    } catch (_) {
      error = 'operation_failed';
    }
    loading = false;
    notifyListeners();
    await reload();
  }

  Future<void> _event(dynamic value) async {
    final event = json(value);
    switch (event['type']) {
      case 'refresh':
        if (!busy) await reload();
      case 'intent':
        onIntent?.call(json(event['intent']));
      case 'task':
        task = event;
        notifyListeners();
        if (!busy) {
          if (event['kind'] != 'download' && event['error'] != null) {
            showMessage?.call(event['error'] as String);
          }
          await reload();
        }
    }
  }

  Future<void> reload() async {
    if (scanning || busy) return;
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final data = json(await invoke('scan'));
      final previous = selected;
      cards = jsonList(data['cards']);
      usb = data['usb'] == null ? null : json(data['usb']);
      selected =
          cards.where((card) => sameCard(card, previous)).firstOrNull ??
          cards.firstOrNull;
      if (selected == null) {
        profiles = [];
      } else {
        profiles = jsonList(selected!['profiles']);
      }
    } catch (_) {
      error = 'profile_read_failed';
    }
    scanning = false;
    notifyListeners();
  }

  static bool sameCard(Json? a, Json? b) =>
      a != null &&
      b != null &&
      ['slot', 'port', 'se'].every((key) => a[key] == b[key]);

  Future<void> select(Json card) async {
    if (busy || reading || scanning) return;
    selected = card;
    profiles = [];
    notifyListeners();
    await readProfiles();
  }

  Future<void> readProfiles() async {
    if (selected == null || busy || reading) return;
    reading = true;
    notifyListeners();
    try {
      final data = json(await invoke('profiles', cardArgs));
      selected = data;
      profiles = jsonList(data['profiles']);
      error = null;
    } catch (_) {
      error = 'profile_read_failed';
    }
    reading = false;
    notifyListeners();
  }

  Future<void> setProfileIcon(Json profile, String source) async {
    if (selected == null || busy || reading || scanning) return;
    final card = Map<String, dynamic>.from(selected!);
    reading = true;
    notifyListeners();
    try {
      final result = json(
        await invoke('profileIcon', {
          ...cardArgs,
          'iccid': profile['iccid'],
          'source': source,
        }),
      );
      if (result['changed'] == true &&
          sameCard(selected, card) &&
          selected?['eid'] == card['eid']) {
        profiles = [
          for (final item in profiles)
            if (item['iccid'] == profile['iccid'])
              {...item, 'customIcon': result['customIcon']}
            else
              item,
        ];
        selected = {...selected!, 'profiles': profiles};
      }
    } finally {
      reading = false;
      notifyListeners();
    }
  }

  Future<void> startTask(String kind, Json arguments) async {
    if (busy) return;
    task = {'kind': kind, 'running': true, 'phase': 'Preparing', 'progress': 0};
    notifyListeners();
    try {
      final id = await invoke<int>('task', {
        ...cardArgs,
        ...arguments,
        'kind': kind,
      });
      task ??= {};
      task!['id'] = id;
      notifyListeners();
    } on PlatformException catch (e) {
      task = {'kind': kind, 'running': false, 'error': e.code};
      notifyListeners();
      if (kind != 'download') showMessage?.call(e.code);
      rethrow;
    }
  }

  void setLanguage(String tag) {
    configuration['language'] = tag;
    notifyListeners();
  }

  Future<void> setPreference(String key, Object? value) async {
    preferences = json(
      await invoke('preference', {'key': key, 'value': value}),
    );
    notifyListeners();
  }

  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      showMessage?.call(e.code);
    } catch (_) {
      showMessage?.call('operation_failed');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
