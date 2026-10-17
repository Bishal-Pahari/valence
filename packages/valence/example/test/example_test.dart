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
  Future<_Handlers> handlers() async => _Handlers(
        await Valence.open(
          // The OTA and sync hosts in the example config are .invalid, so nothing can leave the machine.
          valenceConfig,
          hostBuild: 1,
          log: (_) {},
          client: MockClient(
            (_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200),
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
    final raw = jsonEncode({'id': 1, 'n': withNonce, 'm': method, 'p': params ?? const <String, Object?>{}});
    return jsonDecode(await bridgeDispatch(h, raw, nonce: nonce)) as Map<String, Object?>;
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

  test('the built-ins are inherited from ValenceBuiltins, not written here', () async {
    final h = await handlers();
    // AppHandlers declares exactly one method; everything else comes from the generated base class, which
    // delegates to the package. That is the whole point of the packaging change.
    expect(h, isA<ValenceBuiltins>());
    expect(h, isA<BridgeHandlers>());
  });

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
    final wrongType = await dispatch(h, 'data.get', params: {'bucket': 1, 'key': 'k'});
    expect((wrongType['e']! as Map)['code'], BridgeErrorCode.params);
    final unknownField = await dispatch(h, 'data.get', params: {'bucket': 'b', 'key': 'k', 'extra': 1});
    expect((unknownField['e']! as Map)['message'], contains('extra'));
    final notAnObject = await dispatch(h, 'data.get', params: 'nope');
    expect((notAnObject['e']! as Map)['code'], BridgeErrorCode.params);
  });

  test('a method taking no params rejects params anyway', () async {
    final reply = await dispatch(await handlers(), 'haptics.tap', params: {'x': 1});
    expect((reply['e']! as Map)['code'], BridgeErrorCode.params);
  });

  test('non-JSON input is rejected rather than thrown', () async {
    final h = await handlers();
    final reply = jsonDecode(await bridgeDispatch(h, 'not json', nonce: nonce)) as Map<String, Object?>;
    expect(reply['ok'], isFalse);
    expect((reply['e']! as Map)['code'], BridgeErrorCode.params);
  });

  test('the built-in handlers really reach the package', () async {
    final h = await handlers();
    // data.put on a writable bucket goes all the way to SQLite, through the generated delegation.
    final put = await dispatch(h, 'data.put', params: {'bucket': 'shelf', 'key': 'n-1', 'value': {'a': 1}});
    expect(put['ok'], isTrue, reason: '${put['e']}');
    final list = await dispatch(h, 'data.list', params: {'bucket': 'shelf'});
    final rows = list['v']! as List;
    expect(rows, hasLength(1));
    expect((rows.single as Map)['usn'], -1, reason: 'written locally, not yet synced');
    // And the policy the package owns is enforced through the same path.
    final readOnly = await dispatch(h, 'data.put', params: {'bucket': 'plants', 'key': 'k', 'value': {}});
    expect((readOnly['e']! as Map)['code'], BridgeErrorCode.denied);
    final reserved = await dispatch(h, 'prefs.set', params: {'key': 'valence.sync.lease', 'value': '1'});
    expect((reserved['e']! as Map)['code'], BridgeErrorCode.denied);
    final scheme = await dispatch(h, 'open.external', params: {'url': 'javascript:alert(1)'});
    expect((scheme['e']! as Map)['code'], BridgeErrorCode.denied);
  });

  test('the seed is imported on first launch, so the app works offline', () async {
    final h = await handlers();
    final reply = await dispatch(h, 'data.get', params: {'bucket': 'plants', 'key': 'fern'});
    expect(reply['ok'], isTrue, reason: '${reply['e']}');
    expect((reply['v']! as Map)['name'], 'Boston fern');
  });

  test('the generated event builders go through jsonEncode', () {
    expect(
      BridgeEvents.syncChanged(buckets: ['shelf']),
      'window.__valence&&window.__valence.e("sync.changed",{"buckets":["shelf"]})',
    );
    expect(BridgeEvents.bundleUpdateReady(seq: 42), contains('{"seq":42}'));
  });
}
