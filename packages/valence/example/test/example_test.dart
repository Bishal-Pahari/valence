// What the example is here to prove: the generated code and the package fit together, and an app's own
// method reaches the dispatcher while the built-ins stay the package's job.
//
// The host itself is tested in the package (`flutter test` one directory up). This file is about wiring.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';
import 'package:valence_example/main.dart';
import 'package:valence_example/valence/bridge.g.dart';
import 'package:valence_example/valence/config.g.dart';

class _Handlers extends AppHandlers {
  _Handlers(super.valence);

  int taps = 0;

  @override
  Future<void> hapticsTap() async => taps++;
}

// Widget tests normally replace HttpClient with an unconditional HTTP 400.
// This scoped override allows only this integration test to use its local server.
class _LocalHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nonce = 'test-nonce';
  late Directory support;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    support = await Directory.systemTemp.createTemp('valence-example');
    ValenceStore.resetCacheForTests();
  });

  /// A real runtime on a temp directory, with the network mocked: the built-in handlers under test here
  /// are the generated delegations, so they have to reach the package for real.
  Future<_Handlers> handlers({ValenceConfig? config}) async => _Handlers(
    await Valence.open(
      // The OTA and sync hosts in the example config are .invalid, so nothing can leave the machine.
      config ?? valenceConfig,
      hostBuild: 1,
      log: (_) {},
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'rows': [], 'max': 0, 'more': false}),
          200,
        ),
      ),
      supportDir: support,
    ),
  );

  Future<Map<String, Object?>> dispatch(
    _Handlers h,
    String method, {
    Object? params,
    String withNonce = nonce,
  }) async {
    final raw = jsonEncode({
      'id': 1,
      'n': withNonce,
      'm': method,
      'p': params ?? const <String, Object?>{},
    });
    return jsonDecode(await bridgeDispatch(h, raw, nonce: nonce))
        as Map<String, Object?>;
  }

  test('the generated config carries what the spec compiles into a host', () {
    expect(valenceConfig.appId, 'com.getvalence.example');
    expect(valenceConfig.keyring.keys, ['k1']);
    // Check 5 compares requires.bridge against this, and codegen wires it to the generated constant
    // rather than to a second literal.
    expect(valenceConfig.bridgeVersion, hostBridgeVersion);
    expect(valenceConfig.writableBuckets, {'shelf'});
    expect(valenceConfig.dataSchemas, {'plants': 1});
    expect(valenceConfig.channel, 'production');
  });

  test('the app’s own method reaches the dispatcher', () async {
    final h = await handlers();
    final reply = await dispatch(h, 'haptics.tap');
    expect(reply['ok'], isTrue);
    expect(h.taps, 1);
  });

  test(
    'the built-ins are inherited from ValenceBuiltins, not written here',
    () async {
      final h = await handlers();
      // AppHandlers declares exactly one method; everything else comes from the generated base class, which
      // delegates to the package. That is the whole point of the packaging change.
      expect(h, isA<ValenceBuiltins>());
      expect(h, isA<BridgeHandlers>());
    },
  );

  test('a message without the nonce is denied', () async {
    final h = await handlers();
    final reply = await dispatch(h, 'haptics.tap', withNonce: 'wrong');
    expect(reply['ok'], isFalse);
    expect((reply['e']! as Map)['code'], BridgeErrorCode.denied);
    expect(h.taps, 0, reason: 'the handler must not run');
  });

  test('an unknown method is E_UNKNOWN', () async {
    final reply = await dispatch(await handlers(), 'nope.nope');
    expect((reply['e']! as Map)['code'], BridgeErrorCode.unknown);
  });

  test('bad params are E_PARAMS, and an unknown field is named', () async {
    final h = await handlers();
    final wrongType = await dispatch(
      h,
      'data.get',
      params: {'bucket': 1, 'key': 'k'},
    );
    expect((wrongType['e']! as Map)['code'], BridgeErrorCode.params);
    final unknownField = await dispatch(
      h,
      'data.get',
      params: {'bucket': 'b', 'key': 'k', 'extra': 1},
    );
    expect((unknownField['e']! as Map)['message'], contains('extra'));
    final notAnObject = await dispatch(h, 'data.get', params: 'nope');
    expect((notAnObject['e']! as Map)['code'], BridgeErrorCode.params);
  });

  test('a method taking no params rejects params anyway', () async {
    final reply = await dispatch(
      await handlers(),
      'haptics.tap',
      params: {'x': 1},
    );
    expect((reply['e']! as Map)['code'], BridgeErrorCode.params);
  });

  test('non-JSON input is rejected rather than thrown', () async {
    final h = await handlers();
    final reply =
        jsonDecode(await bridgeDispatch(h, 'not json', nonce: nonce))
            as Map<String, Object?>;
    expect(reply['ok'], isFalse);
    expect((reply['e']! as Map)['code'], BridgeErrorCode.params);
  });

  test('the built-in handlers really reach the package', () async {
    final h = await handlers();
    // data.put on a writable bucket goes all the way to SQLite, through the generated delegation.
    final put = await dispatch(
      h,
      'data.put',
      params: {
        'bucket': 'shelf',
        'key': 'n-1',
        'value': {'a': 1},
      },
    );
    expect(put['ok'], isTrue, reason: '${put['e']}');
    final list = await dispatch(h, 'data.list', params: {'bucket': 'shelf'});
    final rows = list['v']! as List;
    expect(rows, hasLength(1));
    expect(
      (rows.single as Map)['usn'],
      -1,
      reason: 'written locally, not yet synced',
    );
    // And the policy the package owns is enforced through the same path.
    final readOnly = await dispatch(
      h,
      'data.put',
      params: {'bucket': 'plants', 'key': 'k', 'value': {}},
    );
    expect((readOnly['e']! as Map)['code'], BridgeErrorCode.denied);
    final reserved = await dispatch(
      h,
      'prefs.set',
      params: {'key': 'valence.sync.lease', 'value': '1'},
    );
    expect((reserved['e']! as Map)['code'], BridgeErrorCode.denied);
    final scheme = await dispatch(
      h,
      'open.external',
      params: {'url': 'javascript:alert(1)'},
    );
    expect((scheme['e']! as Map)['code'], BridgeErrorCode.denied);
  });

  test(
    'the generated secure.* and auth.* delegations reach the package (§4.4)',
    () async {
      final h = await handlers();
      // The reserved key is refused before any platform call, so this runs without a Keystore.
      final token = await dispatch(
        h,
        'secure.get',
        params: {'key': secureAuthTokenKey},
      );
      expect((token['e']! as Map)['code'], BridgeErrorCode.denied);
      // And a host with no secure-storage platform at all — a plain `flutter test` — reads as "no token"
      // rather than throwing out of the bridge. The Keystore behaviour is tested in the package.
      final has = await dispatch(h, 'auth.hasToken');
      expect(has['ok'], isTrue, reason: '${has['e']}');
      expect(has['v'], isFalse);
    },
  );

  test(
    'the seed is imported on first launch, so the app works offline',
    () async {
      final h = await handlers();
      final reply = await dispatch(
        h,
        'data.get',
        params: {'bucket': 'plants', 'key': 'fern'},
      );
      expect(reply['ok'], isTrue, reason: '${reply['e']}');
      expect((reply['v']! as Map)['name'], 'Boston fern');
    },
  );

  test(
    'native HTTP delegates to the runtime and enforces policy through strict decoding',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      server.listen((r) {
        calls++;
        expect(r.headers.value('authorization'), 'Bearer callback-token');
        r.response.headers.contentType = ContentType.json;
        r.response.write('{"native":true}');
        r.response.close();
      });
      final origin = 'http://127.0.0.1:${server.port}';
      final h = await handlers(
        config: valenceConfig.copyWith(
          httpOrigins: {origin},
          authToken: () async => 'callback-token',
        ),
      );
      final ok = await dispatch(
        h,
        'http.request',
        params: {'url': '$origin/rpc'},
      );
      expect(ok['ok'], isTrue, reason: '${ok['e']}');
      expect((ok['v']! as Map)['status'], 200);
      expect((ok['v']! as Map)['body'], '{"native":true}');
      for (final params in [
        {'url': 'https://unlisted.invalid'},
        {
          'url': origin,
          'headers': {'Authorization': 'page-token'},
        },
      ]) {
        expect(
          ((await dispatch(h, 'http.request', params: params))['e']!
              as Map)['code'],
          BridgeErrorCode.denied,
        );
      }
      for (final params in [
        {'url': 1},
        {'url': origin, 'unexpected': true},
        {'url': origin, 'body': {}},
        {
          'url': origin,
          'headers': ['not-a-map'],
        },
      ]) {
        expect(
          ((await dispatch(h, 'http.request', params: params))['e']!
              as Map)['code'],
          BridgeErrorCode.params,
        );
      }
      final wrongNonce = await dispatch(
        h,
        'http.request',
        params: {'url': origin},
        withNonce: 'wrong',
      );
      expect((wrongNonce['e']! as Map)['code'], BridgeErrorCode.denied);
      expect(calls, 1, reason: 'refused calls never reach the network');
    }, _LocalHttpOverrides()),
  );
  test('schema-3 reads and status delegate to the runtime and enforce strict input', () async {
    final h = await handlers();
    final batch = await dispatch(h, 'data.getMany', params: {'bucket': 'plants', 'keys': ['fern', 'missing', 'fern']});
    expect(batch['ok'], isTrue);
    expect((batch['v']! as List).map((r) => (r as Map)['key']), ['fern']);
    await h.valence.store.put('shelf', 'a', 1, opId: 'one');
    await h.valence.store.put('shelf', 'a', null, opId: 'two');
    final status = await dispatch(h, 'sync.status');
    expect((status['v']! as Map)['pending'], 2);
    expect((status['v']! as Map)['lastSyncedAt'], isNull);
    final invalid = await dispatch(h, 'data.getMany', params: {'bucket': 'plants', 'keys': [3]});
    expect((invalid['e']! as Map)['code'], 'E_PARAMS');
    final oversized = await dispatch(h, 'data.getMany', params: {'bucket': 'plants', 'keys': List.filled(501, 'fern')});
    expect((oversized['e']! as Map)['code'], 'E_PARAMS');
  });


  test('schema-6 lifecycle and update status delegate to the runtime', () async {
    final h = await handlers();
    final state = await dispatch(h, 'app.state');
    // The wire values are the Dart enum names, and a page only ever runs in the foreground.
    expect((state['v']! as Map)['lifecycle'], 'foreground');
    expect((state['v']! as Map)['online'], isTrue);

    h.valence.state.pending = 77;
    final status = await dispatch(h, 'bundle.status');
    final v = status['v']! as Map;
    expect(v['pending'], 77);
    expect(v['serving'], 0, reason: 'no host widget has bound a manifest in a unit test');
    expect(v['trial'], isNull);
    // Nothing has checked, so the honest answer is "idle" rather than a claim about freshness.
    expect(v['reason'], 'idle');
    expect(v['checkedAt'], isNull);
    expect(v['offered'], isNull);

    // Neither takes params, so the strict decoders refuse one rather than ignoring it.
    final extra = await dispatch(h, 'app.state', params: {'verbose': true});
    expect((extra['e']! as Map)['code'], 'E_PARAMS');
  });

  test('sync.done carries the whole SyncResult the reply would carry', () {
    // One type for the reply and the event, so a page renders a freshness line from either.
    const result = ValenceSyncResult(['shelf'], 2, false, ValenceSyncReason.ok, 0);
    expect(
      BridgeEvents.syncDone(result: SyncResult.fromJson(result.toJson())),
      'window.__valence&&window.__valence.e("sync.done",{"result":{"buckets":["shelf"],"changed":2,'
          '"offline":false,"reason":"ok","pending":0}})',
    );
    expect(BridgeEvents.appLifecycle(state: 'background'), contains('{"state":"background"}'));
    expect(BridgeEvents.appOnline(online: false), contains('{"online":false}'));
  });

  test('the generated event builders go through jsonEncode', () {
    expect(
      BridgeEvents.syncChanged(buckets: ['shelf']),
      'window.__valence&&window.__valence.e("sync.changed",{"buckets":["shelf"]})',
    );
    expect(BridgeEvents.bundleUpdateReady(seq: 42), contains('{"seq":42}'));
  });
  test('permissions use strict generated dispatch and the store allowlist', () async {
    final h = await handlers(config: valenceConfig.copyWith(permissionKinds: {}));
    final denied = await dispatch(h, 'permissions.check', params: {'kind': 'camera'});
    expect((denied['e']! as Map)['code'], BridgeErrorCode.denied);
    final unknown = await dispatch(h, 'permissions.check', params: {'kind': 'sql'});
    expect((unknown['e']! as Map)['code'], BridgeErrorCode.params);
    final invalid = await dispatch(h, 'permissions.request', params: {'kind': 'camera', 'force': true});
    expect((invalid['e']! as Map)['code'], BridgeErrorCode.params);
    final nonce = await dispatch(h, 'permissions.request', params: {'kind': 'camera'}, withNonce: 'bad');
    expect((nonce['e']! as Map)['code'], BridgeErrorCode.denied);
    final inactive = await dispatch(h, 'permissions.openSettings');
    expect((inactive['e']! as Map)['code'], BridgeErrorCode.denied);
    expect(BridgeEvents.permissionsChanged(permissions: [const PermissionState(kind: 'camera', status: 'granted')]),
      contains('"permissions":[{"kind":"camera","status":"granted"}]'));
  });

}
