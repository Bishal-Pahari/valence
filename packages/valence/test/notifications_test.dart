import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:valence/valence.dart';

class FakeNotifications extends ValenceNotificationPlatform {
  bool allowed = true, exact = false, revoke = false, ios = false;
  int prompts = 0, initialized = 0, sends = 0;
  final rows = <PendingNotificationRequest>[];
  AndroidScheduleMode? mode;
  NotificationResponse? launch;
  late void Function(NotificationResponse) respond;
  @override
  bool get isIOS => ios;
  @override
  Future<NotificationResponse?> initialize(
      String icon, void Function(NotificationResponse) callback) async {
    initialized++;
    respond = callback;
    return launch;
  }

  @override
  Future<bool> permission({required bool request}) async {
    if (request) prompts++;
    return allowed;
  }

  @override
  Future<bool> canExact() async => exact;
  @override
  Future<List<PendingNotificationRequest>> pending() async => rows.toList();
  @override
  Future<void> cancel(int id) async => rows.removeWhere((r) => r.id == id);
  @override
  Future<void> channel(
      {required String id,
      required String name,
      String importance = 'default',
      String? sound,
      String? group,
      String? groupName,
      bool ifAbsent = false}) async {}
  @override
  Future<NotificationDetails> details(
          {required Directory directory,
          required int id,
          required String channel,
          Uint8List? image,
          required List<String> actionIds,
          String? group}) async =>
      const NotificationDetails();
  @override
  Future<void> schedule(
      {required int id,
      required String title,
      String? body,
      required int at,
      required NotificationDetails details,
      required AndroidScheduleMode mode,
      required String payload}) async {
    sends++;
    if (revoke && mode == AndroidScheduleMode.exactAllowWhileIdle) {
      throw PlatformException(code: 'exact_alarms_not_permitted');
    }
    this.mode = mode;
    rows.removeWhere((r) => r.id == id);
    rows.add(PendingNotificationRequest(id, title, body, payload));
  }

  @override
  Future<bool> badge(int n) async => n > 0;
}

NotificationResponse response(
        {int id = 42, String? action, String payload = '"quoted"\u2028'}) =>
    NotificationResponse(
      id: id,
      actionId: action,
      notificationResponseType: action == null
          ? NotificationResponseType.selectedNotification
          : NotificationResponseType.selectedNotificationAction,
      payload: jsonEncode({'valence': 'local-v1', 'payload': payload}),
    );

class AttachmentPlatform extends ValenceNotificationPlatform {
  @override
  bool get isIOS => true;
  @override
  Future<List<PendingNotificationRequest>> pending() async =>
      [const PendingNotificationRequest(7, 'Keep', null, null)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeNotifications platform;
  late ValenceNotifications service;
  late Directory directory;
  final now = DateTime.utc(2026, 10, 22);
  final events = <String>[];
  setUp(() async {
    events.clear();
    platform = FakeNotifications();
    directory = await Directory.systemTemp.createTemp('valence-notifications');
    service = ValenceNotifications(
        directory: directory,
        emit: events.add,
        platform: platform,
        now: () => now);
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
      'iOS attachments prune historical IDs and alternate extensions; cancel removes owned files',
      () async {
    final native = AttachmentPlatform();
    await File('${directory.path}/7.png').writeAsString('pending');
    await File('${directory.path}/8.jpg').writeAsString('old');
    await File('${directory.path}/9.jpg').writeAsString('previous extension');
    await File('${directory.path}/unrelated').writeAsString('keep');
    await native.details(
        directory: directory,
        id: 9,
        channel: 'care',
        image: Uint8List.fromList([0x89, 1]),
        actionIds: ['done']);
    expect(await File('${directory.path}/7.png').exists(), true);
    expect(await File('${directory.path}/8.jpg').exists(), false);
    expect(await File('${directory.path}/9.jpg').exists(), false);
    expect(await File('${directory.path}/9.png').exists(), true);
    expect(await File('${directory.path}/unrelated').readAsString(), 'keep');
    await service.cancel(9);
    expect(await File('${directory.path}/9.png').exists(), false);
  });
  Future<Map<String, Object?>> schedule(
          {int id = 42,
          bool exact = false,
          String? image,
          String? title,
          List<String> actions = const [],
          int? at,
          String? channel,
          String? payload}) =>
      service.schedule(
          id: id,
          title: title ?? 'Reminder',
          at: at ?? now.millisecondsSinceEpoch + 60000,
          exact: exact,
          image: image,
          actionIds: actions,
          channel: channel,
          payload: payload);

  test('initialization is single-flight and passive, authorization is explicit',
      () async {
    await Future.wait([service.initialize(), service.initialize()]);
    expect(platform.initialized, 1);
    expect(platform.prompts, 0);
    expect(await service.permission(), true);
    expect(platform.prompts, 0);
    await service.permission(request: true);
    expect(platform.prompts, 1);
  });
  test('denial enqueues nothing and exact access is reported honestly',
      () async {
    platform.allowed = false;
    expect((await schedule(exact: true))['timing'], 'blocked');
    expect(platform.sends, 0);
    platform.allowed = true;
    expect((await schedule(exact: true))['timing'], 'inexact');
    platform.exact = true;
    expect((await schedule(exact: true))['timing'], 'exact');
    platform.revoke = true;
    expect((await schedule(exact: true))['timing'], 'inexact');
    expect(platform.mode, AndroidScheduleMode.inexactAllowWhileIdle);
    platform.ios = true;
    expect((await schedule())['timing'], 'system');
  });
  test(
      'concurrent scheduling cannot exceed cap, replacement works, cancel is scoped',
      () async {
    for (var id = 0; id < 63; id++) {
      await schedule(id: id);
    }
    final results = await Future.wait([
      schedule(id: 63).then<Object>((v) => v),
      schedule(id: 64).then<Object>((v) => v).catchError((Object e) => e)
    ]);
    expect(results[1], isA<BridgeError>());
    await schedule(id: 0, title: 'Replacement');
    expect((await service.pending()).firstWhere((r) => r['id'] == 0)['title'],
        'Replacement');
    await service.cancel(0);
    expect((await service.pending()).length, 63);
    await schedule(id: 64); // rejection did not poison the mutation queue
    expect((await service.pending()).length, 64);
  });
  test('invalid input is refused before any native initialization or decoding',
      () async {
    for (final run in <Future<Object?> Function()>[
      () => schedule(id: -1),
      () => schedule(id: 2147483648),
      () => schedule(at: now.millisecondsSinceEpoch),
      () => schedule(
          at: now.add(const Duration(days: 367)).millisecondsSinceEpoch),
      () => schedule(title: '€' * 86),
      () => schedule(payload: '😀' * 1025),
      () => schedule(channel: '../file'),
      () => schedule(actions: ['delete']),
      () => schedule(actions: ['done', 'done']),
      () => schedule(image: 'file:///secret'),
      () => schedule(image: 'https://example.com/image.png'),
      () => schedule(image: 'A' * 131073),
      () => schedule(image: base64Encode(utf8.encode('<svg>script</svg>'))),
    ]) {
      await expectLater(run(), throwsA(isA<BridgeError>()));
    }
    expect(platform.initialized, 0);
    expect(platform.sends, 0);
  });
  test('PNG pixels and dimensions are validated; malformed JPEG is refused',
      () async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAEgAAABICAMAAABiM0N1AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAK5QTFRFAAAAAU6KAVebKbb2VMX4Kbb2VMX4AVaaAVebKbb2RsD3VMX4VMX4AVaZAVebGHalKbb2VMX4Pa7jADJZADhkAStLATBTAT5uAT5vAUd/AUmCAUyHAU6KAU6LAU6MAVGRAVKSAVKTAVOUAVWXAVWYAVaYAVaaAVeaAVebAjtnAkBwAkN2AkmAA02GA0+KA1CLFmiQF2+ZGXimGn6wG4O2G4a6HIe8Kbb2RL/3VMX47aEaPQAAABN0Uk5TABAQEBBQUGBgYGBggM/Pz8/P3xkQ5PoAAADpSURBVFjD7czXDoJAEEBRVOy9YO+KjB0r+v8/ZoQIC0sizq4PxrmvNzmKQklMrd758uSQQw455JBDDjnvnFSBL4Vw8iGzqn7TCYUwTpiEc3gJ6wQlvOOXXCf3ucNKrpO1bp87nsQ4FidFcF6SzwlKkRxHCjh+KaLzlDiHlSI7TJ7jSaLOSxJ3HEmG85QwTtLiqyEcJVHhnOs+rciQLjsdMhKk83ZmgATptBnrCxCXjuvB1IYEpcOyM5zMbEhIMpvtTn+sAwhKplZv9aYGgKBkao3uHNhwUnk1gmAoKVYEkCPFSyT9qvSvPQCNJCMEO265wAAAAABJRU5ErkJggg==';
    await schedule(image: png, actions: ['done', 'snooze']);
    final huge = base64Decode(png);
    ByteData.sublistView(huge).setUint32(16, 100000);
    await expectLater(
        schedule(image: base64Encode(huge)), throwsA(isA<BridgeError>()));
    await expectLater(
        schedule(
            image:
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII='),
        throwsA(isA<BridgeError>()));
    // SOF segment bounds are checked before reading dimensions.
    await expectLater(
        schedule(image: base64Encode([255, 216, 255, 192, 0, 255, 0])),
        throwsA(isA<BridgeError>()));
  });
  test(
      'cold response consumes once; warm action and tap are escaped; foreign callbacks are ignored',
      () async {
    platform.launch = response();
    expect((await service.initial() as Map)['id'], 42);
    expect(await service.initial(), null);
    expect(events, isEmpty);
    platform.respond(response());
    platform.respond(response(action: 'done'));
    expect(events[0], contains('notify.tapped'));
    expect(events[1], contains('notify.action'));
    expect(events[1], contains(r'\"quoted\"'));
    platform.respond(response(action: 'unknown'));
    platform.respond(response(payload: 'x' * 4097));
    platform.respond(const NotificationResponse(
        id: 2,
        payload: '{',
        notificationResponseType:
            NotificationResponseType.selectedNotification));
    platform.respond(const NotificationResponse(
        id: 2,
        payload: '{"message":"foreign"}',
        notificationResponseType:
            NotificationResponseType.selectedNotification));
    expect(events.length, 2);
  });
  test(
      'channel paths, unknown policies, bad resource names and badge range fail',
      () async {
    await expectLater(
        service.channel(id: 'x', name: 'name', sound: '../secret'),
        throwsA(isA<BridgeError>()));
    await expectLater(
        service.channel(id: 'x', name: 'name', importance: 'urgent'),
        throwsA(isA<BridgeError>()));
    await expectLater(service.channel(id: 'x', name: '', group: 'a'),
        throwsA(isA<BridgeError>()));
    await expectLater(service.badge(10000), throwsA(isA<BridgeError>()));
    expect(platform.initialized, 0);
    expect(await service.badge(2), true);
    expect(await service.badge(0), false);
    platform.allowed = false;
    expect(await service.badge(2), false);
  });
}
