import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

final class _Transport implements ValencePushTransport {
  final messages = StreamController<ValencePushMessage>.broadcast(sync: true);
  final taps = StreamController<ValencePushMessage>.broadcast(sync: true);
  final rotations = StreamController<String>.broadcast(sync: true);
  final initialReply = Completer<ValencePushMessage?>();
  String status = 'authorized';
  final requests = <bool>[];
  int tokenCalls = 0;
  @override
  Stream<ValencePushMessage> get received => messages.stream;
  @override
  Stream<ValencePushMessage> get tapped => taps.stream;
  @override
  Stream<String> get tokens => rotations.stream;
  @override
  Future<ValencePushMessage?> initial() => initialReply.future;
  @override
  Future<String> permission({required bool request}) async {
    requests.add(request);
    return status;
  }

  @override
  Future<String?> token() async {
    tokenCalls++;
    return 'installation-token';
  }

  Future<void> close() async {
    await messages.close();
    await taps.close();
    await rotations.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Transport transport;
  late ValencePush push;
  late List<String> events;
  late List<String> logs;
  late int syncs;

  setUp(() {
    transport = _Transport();
    events = [];
    logs = [];
    syncs = 0;
    push = ValencePush(transport: transport, log: logs.add);
  });
  tearDown(() async {
    await push.dispose();
    await transport.close();
  });
  Future<void> start([ValencePushMessage? initial]) {
    transport.initialReply.complete(initial);
    return push.start(
        emit: events.add,
        sync: () async {
          syncs++;
        });
  }

  test('startup does not request permission or a network token; starts once',
      () async {
    await start();
    await push.start(emit: (_) => fail('duplicate attach'), sync: () async {});
    expect(transport.requests, isEmpty);
    expect(transport.tokenCalls, 0);
    transport.rotations.add('rotated');
    expect(events, hasLength(1));
    expect(events.single, contains('push.tokenChanged'));
  });

  test('permission checks are passive and token retrieval requires consent',
      () async {
    for (final status in ['notDetermined', 'denied']) {
      transport.status = status;
      expect(await push.token(), isNull);
    }
    expect(transport.tokenCalls, 0);
    for (final status in ['authorized', 'provisional']) {
      transport.status = status;
      expect(await push.token(), 'installation-token');
    }
    expect(transport.requests, everyElement(false));
    await push.permission(request: true);
    expect(transport.requests.last, true);
  });

  test('cold tap is consumed once then warm taps become live', () async {
    await start(
        const ValencePushMessage(id: 'cold', data: {'screen': '/shelf'}));
    expect(events, isEmpty);
    expect((await push.initial())?.id, 'cold');
    expect(await push.initial(), isNull);
    transport.taps.add(const ValencePushMessage(id: 'warm'));
    expect(events.single, contains('push.tapped'));
    expect(events.single, contains('warm'));
  });

  test('newer tap during initial lookup wins over stale cold tap', () async {
    final starting = push.start(emit: events.add, sync: () async {});
    transport.taps.add(const ValencePushMessage(id: 'new'));
    transport.initialReply.complete(const ValencePushMessage(id: 'old'));
    await starting;
    expect((await push.initial())?.id, 'new');
    expect(events, isEmpty);
  });

  test('background command is exact and ignores payload-supplied configuration',
      () async {
    for (final data in <Map<String, dynamic>>[
      {},
      {'valence': 'reload'},
      {'valence': 'sync', 'url': 'https://evil.test'},
      {'valence': 'sync', 'token': 'stolen'},
      {
        'valence': ['sync']
      },
    ]) {
      await ValencePush.handleBackground(data, hasNotification: false,
          sync: () async {
        syncs++;
      });
    }
    await ValencePush.handleBackground({'valence': 'sync'},
        hasNotification: true, sync: () async {
      syncs++;
    });
    expect(syncs, 0);
    await ValencePush.handleBackground({'valence': 'sync'},
        hasNotification: false, sync: () async {
      syncs++;
    });
    expect(syncs, 1);
  });

  test('foreground hint syncs; notification or extra fields never do',
      () async {
    await start();
    transport.messages.add(const ValencePushMessage(data: {'valence': 'sync'}));
    transport.messages.add(
        const ValencePushMessage(data: {'valence': 'sync', 'bucket': 'x'}));
    transport.messages.add(const ValencePushMessage(
        data: {'valence': 'sync'}, hasNotification: true));
    await Future<void>.delayed(Duration.zero);
    expect(syncs, 1);
    expect(events, hasLength(3));
  });

  test('script content stays JSON and image URLs are HTTPS metadata only',
      () async {
    await start();
    transport.messages.add(const ValencePushMessage(
      data: {'text': '\u2028\u2029";evil()'},
      title: '";evil()',
      image: 'file:///secret',
      hasNotification: true,
    ));
    expect(events.single, contains(r'\u2028\u2029'));
    expect(events.single, contains('"image":null'));
    expect(events.single, contains(r'\";evil()'));
    expect(
        const ValencePushMessage(image: 'https://images.test/a.png')
            .toJson()['image'],
        'https://images.test/a.png');
    for (final image in [
      'http://images.test/a',
      'https://user@images.test/a',
      'javascript:evil()'
    ]) {
      expect(ValencePushMessage(image: image).toJson()['image'], isNull);
    }
  });

  test(
      'oversized or invalid JSON events and taps are dropped without contents in logs',
      () async {
    await start();
    final secret = 's' * maxMessageBytes;
    transport.messages.add(ValencePushMessage(data: {'secret': secret}));
    transport.taps.add(ValencePushMessage(data: {'secret': secret}));
    transport.messages.add(ValencePushMessage(data: {'bad': Object()}));
    expect(events, isEmpty);
    expect(await push.initial(), isNull);
    expect(logs, hasLength(3));
    expect(logs.join(), isNot(contains(secret)));
  });

  test('initial payload fits both reply and event message caps', () async {
    await start(const ValencePushMessage(id: 'x', data: {'count': 1}));
    final json = (await push.initial())!.toJson();
    expect(utf8.encode(jsonEncode({'id': 1, 'ok': true, 'v': json})).length,
        lessThan(maxMessageBytes));
  });

  test('platform stream errors and sync errors log no private content',
      () async {
    transport.initialReply.completeError(StateError('private-initial'));
    await push.start(
        emit: events.add,
        sync: () async {
          throw StateError('private-token');
        });
    transport.messages.addError(StateError('private-payload'));
    transport.messages.add(const ValencePushMessage(data: {'valence': 'sync'}));
    await Future<void>.delayed(Duration.zero);
    expect(logs, hasLength(3));
    expect(logs.join(), isNot(contains('private')));
  });

  test(
      'dispose cancels events and pending tap while initial lookup is in flight',
      () async {
    final starting = push.start(
        emit: events.add,
        sync: () async {
          syncs++;
        });
    await push.dispose();
    transport.initialReply.complete(const ValencePushMessage(id: 'late'));
    await starting;
    expect(await push.initial(), isNull);
    transport.messages.add(const ValencePushMessage(data: {'valence': 'sync'}));
    transport.rotations.add('secret');
    expect(events, isEmpty);
    expect(syncs, 0);
  });
}
