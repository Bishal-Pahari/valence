import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

final class _Transport implements ValencePushTransport {
  final messages = StreamController<ValencePushMessage>.broadcast(sync: true);
  @override
  Stream<ValencePushMessage> get received => messages.stream;
  @override
  Stream<ValencePushMessage> get tapped => const Stream.empty();
  @override
  Stream<String> get tokens => const Stream.empty();
  @override
  Future<ValencePushMessage?> initial() async => null;
  @override
  Future<String> permission({required bool request}) async => 'authorized';
  @override
  Future<String?> token() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
      'foreground and background hints sync with the native token without touching bundle state',
      () async {
    final key = await TestKey.create();
    final support =
        await Directory.systemTemp.createTemp('valence-push-runtime');
    ValenceStore.resetCacheForTests();
    final authorizations = <String?>[];
    final client = MockClient((request) async {
      authorizations.add(request.headers['Authorization']);
      final since = int.parse(request.url.queryParameters['since']!);
      return http.Response(
          jsonEncode({
            'rows': since == 0
                ? [
                    {'k': 'remote', 'v': 'new', 'u': 1, 'd': 0}
                  ]
                : [],
            'max': 1,
            'more': false
          }),
          200);
    });
    final config = testConfig(key, writableBuckets: {'shelf'});
    final secure = testSecure({});
    await secure.setAuthToken('login-token');
    final log = LogSpy();
    final transport = _Transport();
    addTearDown(transport.messages.close);
    final push = ValencePush(transport: transport, log: log.call);
    addTearDown(push.dispose);
    final v = await Valence.open(config,
        supportDir: support,
        secure: secure,
        push: push,
        client: client,
        log: log.call);
    final stateBefore = jsonEncode(v.state.toJson());
    final file = File('${v.dir.path}/state.json');
    final existsBefore = file.existsSync();
    transport.messages.add(const ValencePushMessage(data: {'valence': 'sync'}));
    // Poll a concrete database condition rather than assume an arbitrary sync delay.
    for (var i = 0; i < 100 && await v.store.maxUsn('shelf', 1) == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await v.store.maxUsn('shelf', 1), 1, reason: log.toString());
    expect(authorizations, contains('Bearer login-token'));
    for (var i = 0;
        i < 100 && await v.store.hostPrefGet('valence.sync.lease') != null;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(jsonEncode(v.state.toJson()), stateBefore);
    expect(file.existsSync(), existsBefore);
    final requestsBefore = authorizations.length;
    await ValencePush.handleBackground({'valence': 'sync'},
        hasNotification: false, sync: () async {
      final result = await Valence.backgroundSync(config,
          supportDir: support, secure: secure, client: client, log: (_) {});
      expect(result.reason, ValenceSyncReason.ok);
    });
    expect(authorizations.length, greaterThan(requestsBefore));
    expect(file.existsSync(), existsBefore);
    expect(jsonEncode(v.state.toJson()), stateBefore);
    expect(await v.store.maxUsn('shelf', 1), 1,
        reason: 'background worker leaves the UI database open');
  });
}
