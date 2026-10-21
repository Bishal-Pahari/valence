import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as native;
import 'package:valence/valence.dart';

class _Backend implements ValencePermissionBackend {
  final values = <String, String>{'camera': 'denied', 'photos': 'limited'};
  final calls = <String>[];
  Future<String> Function(String)? prompt;
  bool failCheck = false;

  @override
  Future<String> check(String kind) async {
    calls.add('check:$kind');
    if (failCheck && kind == 'camera') throw StateError('native failed');
    return values[kind] ?? 'granted';
  }

  @override
  Future<String> request(String kind, {required bool Function() isForeground}) async {
    calls.add('request:$kind');
    return prompt == null ? values[kind]! : prompt!(kind);
  }

  @override
  Future<bool> openSettings() async {
    calls.add('settings');
    return false;
  }
}

Matcher errorCode(String code) => throwsA(isA<BridgeError>().having((e) => e.code, 'code', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Backend backend;
  late ValencePermissions permissions;
  var foreground = true;
  final logs = <String>[];

  setUp(() {
    foreground = true;
    logs.clear();
    backend = _Backend();
    permissions = ValencePermissions(
      kinds: {'camera', 'photos'},
      isForeground: () => foreground,
      backend: backend,
      log: logs.add,
    );
  });

  test('unknown and unconfigured kinds never reach native code', () async {
    await expectLater(permissions.check('sql'), errorCode(BridgeErrorCode.params));
    await expectLater(permissions.request('location'), errorCode(BridgeErrorCode.denied));
    await expectLater(permissions.check('contacts'), errorCode(BridgeErrorCode.denied));
    expect(backend.calls, isEmpty);
  });

  test('default empty allowlist and copied kinds prevent escalation', () async {
    final kinds = <String>{};
    final service = ValencePermissions(kinds: kinds, isForeground: () => true, backend: backend);
    kinds.add('camera');
    await expectLater(service.request('camera'), errorCode(BridgeErrorCode.denied));
    expect(() => service.kinds.add('camera'), throwsUnsupportedError);
    expect(backend.calls, isEmpty);
  });

  test('background prompts and settings are denied, checks remain available', () async {
    foreground = false;
    await expectLater(permissions.request('camera'), errorCode(BridgeErrorCode.denied));
    await expectLater(permissions.openSettings(), errorCode(BridgeErrorCode.denied));
    expect(await permissions.check('camera'), 'denied');
    expect(backend.calls, ['check:camera']);
  });

  test('serialized requests recheck foreground before showing another dialog', () async {
    final first = Completer<String>();
    backend.prompt = (_) => first.future;
    final a = permissions.request('camera');
    final b = permissions.request('photos');
    final denied = expectLater(b, errorCode(BridgeErrorCode.denied));
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, ['request:camera']);
    foreground = false;
    first.complete('granted');
    expect(await a, 'granted');
    await denied;
    expect(backend.calls, ['request:camera']);
  });

  test('a native failure does not poison the request queue', () async {
    backend.prompt = (_) async => throw StateError('failed');
    await expectLater(permissions.request('camera'), throwsStateError);
    backend.prompt = null;
    expect(await permissions.request('photos'), 'limited');
    expect(await permissions.openSettings(), isFalse);
  });

  test('resume establishes baseline, reports only deltas, and never requests', () async {
    expect(await permissions.refresh(baseline: true), isEmpty);
    expect(await permissions.refresh(), isEmpty);
    backend.values['camera'] = 'granted';
    expect(await permissions.refresh(), [
      {'kind': 'camera', 'status': 'granted'}
    ]);
    expect(await permissions.refresh(), isEmpty);
    backend.values['photos'] = 'denied';
    expect(await permissions.check('photos'), 'denied');
    expect(await permissions.refresh(), isEmpty);
    expect(backend.calls.every((c) => c.startsWith('check:')), isTrue);
  });

  test('a failed kind cannot hide another kind changing on resume', () async {
    await permissions.refresh(baseline: true);
    backend.failCheck = true;
    backend.values['photos'] = 'granted';
    expect(await permissions.refresh(), [
      {'kind': 'photos', 'status': 'granted'}
    ]);
    expect(logs.single, contains('camera failed'));
    backend.failCheck = false;
    backend.values['camera'] = 'granted';
    expect(await permissions.refresh(), [
      {'kind': 'camera', 'status': 'granted'}
    ]);
  });

  group('permission_handler adapter', () {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    final calls = <MethodCall>[];
    final statuses = <int, int>{};
    setUp(() {
      calls.clear();
      statuses.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        calls.add(call);
        if (call.method == 'requestPermissions') {
          return {for (final p in call.arguments as List) p: statuses[p] ?? 1};
        }
        if (call.method == 'openAppSettings') return true;
        return statuses[call.arguments] ?? 1;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    for (final entry in {
      0: 'denied',
      1: 'granted',
      2: 'restricted',
      3: 'limited',
      4: 'permanentlyDenied',
      5: 'limited'
    }.entries) {
      test('normalizes native status ${entry.key} to ${entry.value}', () async {
        final adapter = ValencePermissionBackend.native(platform: 'ios');
        statuses[native.Permission.camera.value] = entry.key;
        expect(await adapter.check('camera'), entry.value);
        expect(await adapter.request('camera', isForeground: () => true), entry.value);
      });
    }

    test('all kinds map to explicit native groups on Android and iOS', () async {
      final android = ValencePermissionBackend.native(platform: 'android', androidSdk: () async => 36);
      final ios = ValencePermissionBackend.native(platform: 'ios');
      for (final kind in valencePermissionKinds) {
        expect(await android.check(kind), 'granted');
        expect(await ios.request(kind, isForeground: () => true), 'granted');
      }
      expect(await ios.openSettings(), isTrue);
      expect(calls.where((c) => c.method == 'requestPermissions').length, 7);
    });

    test('photos use storage before 33 and images on 33+', () async {
      for (final sdk in [23, 32, 33, 34, 36]) {
        calls.clear();
        final adapter = ValencePermissionBackend.native(platform: 'android', androidSdk: () async => sdk);
        await adapter.request('photos', isForeground: () => true);
        expect(calls.single.arguments,
            [sdk < 33 ? native.Permission.storage.value : native.Permission.photos.value]);
      }
    });

    test('Bluetooth combines scan/connect and legacy foreground location', () async {
      final modern = ValencePermissionBackend.native(platform: 'android', androidSdk: () async => 31);
      statuses[native.Permission.bluetoothConnect.value] = 4;
      expect(await modern.request('bluetooth', isForeground: () => true), 'permanentlyDenied');
      expect(calls.single.arguments,
          [native.Permission.bluetoothScan.value, native.Permission.bluetoothConnect.value]);
      calls.clear();
      final legacy = ValencePermissionBackend.native(platform: 'android', androidSdk: () async => 30);
      await legacy.check('bluetooth');
      expect(calls.single.arguments, native.Permission.locationWhenInUse.value);
    });

    test('backgrounding during SDK preparation cannot dispatch a permission dialog', () async {
      final sdk = Completer<int>();
      var foreground = true;
      final adapter = ValencePermissionBackend.native(platform: 'android', androidSdk: () => sdk.future);
      final result = adapter.request('camera', isForeground: () => foreground);
      final denied = expectLater(result, errorCode(BridgeErrorCode.denied));
      foreground = false;
      sdk.complete(36);
      await denied;
      expect(calls, isEmpty);
    });

    test('unsupported platform makes no native call', () async {
      final adapter = ValencePermissionBackend.native(platform: 'windows');
      await expectLater(
          adapter.request('camera', isForeground: () => true), errorCode(BridgeErrorCode.unsupported));
      await expectLater(adapter.openSettings(), errorCode(BridgeErrorCode.unsupported));
      expect(calls, isEmpty);
    });
  });
}
