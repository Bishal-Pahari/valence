import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valence_push/valence_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
  final calls = <String>[];
  var status = 1;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() {
    calls.clear();
    status = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'Messaging#getInitialMessage':
          return {
            'messageId': 'cold',
            'data': {'screen': 'inbox'}
          };
        case 'Messaging#getNotificationSettings':
        case 'Messaging#requestPermission':
          return {
            'authorizationStatus': status,
            'alert': 1,
            'announcement': 1,
            'badge': 1,
            'carPlay': 1,
            'lockScreen': 1,
            'notificationCenter': 1,
            'showPreviews': 1,
            'sound': 1,
            'timeSensitive': 1,
            'criticalAlert': 1,
            'providesAppNotificationSettings': 1,
          };
        case 'Messaging#getToken':
          return {'token': 'registration'};
        default:
          throw StateError('unexpected Firebase call ${call.method}');
      }
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'real Firebase adapter maps passive settings, explicit request, token and native streams',
      () async {
    final push = createFirebasePush(log: (_) {});
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
    FirebaseMessagingPlatform.onMessage
        .add(const RemoteMessage(messageId: 'foreground'));
    FirebaseMessagingPlatform.onMessageOpenedApp
        .add(const RemoteMessage(messageId: 'warm'));
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(2));
    expect(events[0], contains('push.received'));
    expect(events[1], contains('push.tapped'));
  });

  test('native envelopes retain image metadata and empty notification presence',
      () async {
    final push = createFirebasePush(log: (_) {});
    addTearDown(push.dispose);
    final events = <String>[];
    var syncs = 0;
    await push.start(
        emit: events.add,
        sync: () async {
          syncs++;
        });
    FirebaseMessagingPlatform.onMessage.add(const RemoteMessage(
      messageId: 'image',
      data: {'valence': 'sync'},
      notification: RemoteNotification(
          title: 'title',
          body: 'body',
          android: AndroidNotification(imageUrl: 'https://images.test/a.png')),
    ));
    FirebaseMessagingPlatform.onMessage.add(const RemoteMessage(
      data: {'valence': 'sync'},
      notification: RemoteNotification(),
    ));
    FirebaseMessagingPlatform.onMessage.add(const RemoteMessage(
      data: {'valence': 'sync'},
    ));
    await Future<void>.delayed(Duration.zero);
    expect(syncs, 1, reason: 'only a truly data-only message can request sync');
    expect(events, hasLength(3));
    expect(events.first, contains('https://images.test/a.png'));
    expect(events.first, contains('"title":"title"'));
    expect(events.first, contains('"body":"body"'));
    expect(events.join(), isNot(contains('hasNotification')));
  });
}
