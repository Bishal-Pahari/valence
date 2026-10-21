import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
  final calls = <String>[];
  var status = 1;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() {
    calls.clear(); status = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'Messaging#getInitialMessage': return {'messageId': 'cold', 'data': {'screen': 'inbox'}};
        case 'Messaging#getNotificationSettings':
        case 'Messaging#requestPermission':
          return {
            'authorizationStatus': status, 'alert': 1, 'announcement': 1,
            'badge': 1, 'carPlay': 1, 'lockScreen': 1, 'notificationCenter': 1,
            'showPreviews': 1, 'sound': 1, 'timeSensitive': 1,
            'criticalAlert': 1, 'providesAppNotificationSettings': 1,
          };
        case 'Messaging#getToken': return {'token': 'registration'};
        default: throw StateError('unexpected Firebase call ${call.method}');
      }
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('real Firebase adapter maps passive settings, explicit request, token and native streams', () async {
    final push = ValencePush(log: (_) {});
    addTearDown(push.dispose);
    final events = <String>[];
    await push.start(emit: events.add, sync: () async {});
    expect(calls, ['Messaging#getInitialMessage']);
    expect((await push.initial())!.id, 'cold');
    expect(await push.permission(), 'authorized');
    expect(await push.permission(request: true), 'authorized');
    expect(await push.token(), 'registration');
    status = 0;
    expect(await push.token(), isNull);
    expect(calls.where((m) => m == 'Messaging#getToken'), hasLength(1));
    FirebaseMessagingPlatform.onMessage.add(const RemoteMessage(messageId: 'foreground'));
    FirebaseMessagingPlatform.onMessageOpenedApp.add(const RemoteMessage(messageId: 'warm'));
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(2));
    expect(events[0], contains('push.received')); expect(events[1], contains('push.tapped'));
  });

  test('foreground and background hints sync with the native token without touching bundle state', () async {
    final key = await TestKey.create();
    final support = await Directory.systemTemp.createTemp('valence-push-runtime');
    ValenceStore.resetCacheForTests();
    final authorizations = <String?>[];
    final client = MockClient((request) async {
      authorizations.add(request.headers['Authorization']);
      final since = int.parse(request.url.queryParameters['since']!);
      return http.Response(jsonEncode({'rows': since == 0 ? [{'k': 'remote', 'v': 'new', 'u': 1, 'd': 0}] : [], 'max': 1, 'more': false}), 200);
    });
    final config = testConfig(key, writableBuckets: {'shelf'});
    final secure = testSecure({});
    await secure.setAuthToken('login-token');
    final log = LogSpy();
    final push = ValencePush(log: log.call);
    addTearDown(push.dispose);
    final v = await Valence.open(config, supportDir: support, secure: secure, push: push, client: client, log: log.call);
    final stateBefore = jsonEncode(v.state.toJson());
    final file = File('${v.dir.path}/state.json');
    final existsBefore = file.existsSync();
    FirebaseMessagingPlatform.onMessage.add(const RemoteMessage(data: {'valence': 'sync'}));
    // Poll a concrete database condition rather than assume an arbitrary sync delay.
    for (var i = 0; i < 100 && await v.store.maxUsn('shelf', 1) == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await v.store.maxUsn('shelf', 1), 1, reason: log.toString());
    expect(authorizations, contains('Bearer login-token'));
    for (var i = 0; i < 100 && await v.store.hostPrefGet('valence.sync.lease') != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(jsonEncode(v.state.toJson()), stateBefore);
    expect(file.existsSync(), existsBefore);
    final requestsBefore = authorizations.length;
    await ValencePush.handleBackground({'valence': 'sync'}, hasNotification: false, sync: () async {
      final result = await Valence.backgroundSync(config, supportDir: support, secure: secure, client: client, log: (_) {});
      expect(result.reason, ValenceSyncReason.ok);
    });
    expect(authorizations.length, greaterThan(requestsBefore));
    expect(file.existsSync(), existsBefore);
    expect(jsonEncode(v.state.toJson()), stateBefore);
    expect(await v.store.maxUsn('shelf', 1), 1, reason: 'background worker leaves the UI database open');
  });
}
