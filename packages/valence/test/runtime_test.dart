// The built-in bridge methods' policy: the trust boundary that lives in the package rather than in the
// generated marshalling. Contracts §4.2, §5.4, §5.5.
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestKey key;
  late Directory support;

  setUpAll(() async {
    key = await TestKey.create();
    sqfliteFfiInit();
    // Valence.open goes through the global factory, as a real app does.
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    support = await Directory.systemTemp.createTemp('valence-runtime');
    ValenceStore.resetCacheForTests();
  });

  Future<Valence> open({
    Set<String> writableBuckets = const {},
    Map<String, int> dataSchemas = const {},
    http.Client? client,
    LogSpy? log,
    ValenceConfig? config,
    ValenceSecure? secure,
  }) =>
      Valence.open(
        config ?? testConfig(key, writableBuckets: writableBuckets, dataSchemas: dataSchemas),
        hostBuild: 42,
        log: (log ?? LogSpy()).call,
        client:
            client ?? MockClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200)),
        supportDir: support,
        secure: secure ?? testSecure({}),
      );

  Matcher throwsDenied(String fragment) => throwsA(
        isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.denied)
            .having((e) => e.message, 'message', contains(fragment)),
      );

  group('app.info', () {
    test('it reports the platform, the host build, the bridge version and the locale', () async {
      final v = await open();
      final info = v.appInfo();
      expect(info.platform, Platform.operatingSystem);
      expect(info.host, 42);
      // The bridge version comes from the config, which codegen wires to the generated hostBridgeVersion.
      expect(info.bridge, v.config.bridgeVersion);
      expect(info.bundle, 0, reason: 'nothing is being served yet');
      expect(info.locale, isNotEmpty);
    });
  });

  test('sync status counts deletes, persists observations and leaves busy/scoped timestamps alone', () async {
    var requests = 0;
    var unreachable = false;
    final client = MockClient((_) async {
      requests++;
      if (unreachable) throw const SocketException('offline');
      return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
    });
    final v = await open(dataSchemas: {'plants': 1}, writableBuckets: {'shelf'}, client: client);
    final fresh = await v.syncStatus();
    expect(fresh.lastSyncedAt, isNull);
    expect(fresh.offline, isFalse);
    expect(requests, 0, reason: 'status never starts sync');
    await v.store.put('shelf', 'a', 1, opId: 'a');
    await v.store.put('shelf', 'a', null, opId: 'b');
    expect((await v.syncStatus()).pending, 2);
    expect(await v.sync.acquireLease(), isTrue);
    final busy = await v.syncNow();
    expect(busy.pending, 2);
    expect(busy.reason, ValenceSyncReason.busy);
    expect((await v.syncStatus()).lastSyncedAt, isNull);
    await v.sync.releaseLease();
    unreachable = true;
    final failed = await v.syncNow();
    expect(failed.pending, 2);
    expect((await v.syncStatus()).offline, isTrue);
    expect((await v.syncStatus()).lastSyncedAt, isNull);
    // Clear only the synthetic queued ops so this mock does not need a push protocol.
    await v.store.db.delete('outbox');
    unreachable = false;
    await v.syncNow(buckets: ['plants']);
    expect((await v.syncStatus()).lastSyncedAt, isNull);
    await v.syncNow();
    final successful = await v.syncStatus();
    expect(successful.lastSyncedAt, isNotNull);
    expect(successful.offline, isFalse);
    final reopened = await open(dataSchemas: {'plants': 1}, writableBuckets: {'shelf'}, client: client);
    expect((await reopened.syncStatus()).lastSyncedAt, successful.lastSyncedAt);
    expect((await reopened.syncStatus()).pending, 0);
  });

  test('HTTP and protocol failures cannot advance last successful sync', () async {
    var response = http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
    final v = await open(dataSchemas: {'plants': 1}, client: MockClient((_) async => response));
    await v.syncNow();
    const previous = '123';
    await v.store.hostPrefSet('valence.sync.lastSyncedAt', previous);
    for (final bad in [http.Response('', 500), http.Response('not JSON', 200),
      http.Response('{"rows":[]}', 200), http.Response('{"rows":[3],"max":1,"more":false}', 200)]) {
      response = bad;
      await v.syncNow();
      expect((await v.syncStatus()).lastSyncedAt, 123);
    }
    final push = await open(writableBuckets: {'shelf'}, client: MockClient((req) async =>
      http.Response(req.method == 'POST' ? '{}' : '{"rows":[],"max":0,"more":false}', 200)));
    await push.store.put('shelf', 'a', 1, opId: 'malformed-push');
    await push.store.hostPrefSet('valence.sync.lastSyncedAt', previous);
    await push.syncNow();
    expect((await push.syncStatus()).lastSyncedAt, 123);
    expect((await push.syncStatus()).pending, 1);
  });

  test('fresh runtime imports current and additional declared seed schemas', () async {
    final seed = await openTestStore();
    await seed.applyPullPage(bucket: 'plants', schema: 1,
      rows: [{'k': 'fern', 'v': 'old', 'u': 1, 'd': 0}], maxUsnAfter: 1);
    await seed.applyPullPage(bucket: 'plants', schema: 2,
      rows: [{'k': 'fern', 'v': 'new', 'u': 1, 'd': 0}], maxUsnAfter: 1);
    await seed.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final bytes = File(seed.path).readAsBytesSync();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (_) async => ByteData.sublistView(Uint8List.fromList(bytes)));
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final base = testConfig(key, dataSchemas: {'plants': 2});
    final v = await open(config: ValenceConfig(appId: base.appId, keyring: base.keyring,
      bridgeVersion: base.bridgeVersion, dataSchemas: {'plants': 2}, seedSchemas: {'plants': [1]}));
    expect(await v.store.get('plants', 1, 'fern'), 'old');
    expect(await v.store.get('plants', 2, 'fern'), 'new');
    expect(await v.dataGet('plants', 'fern'), 'new');
  });

  group('native plugins (section 4.7)', () {
    test(
        'reserved owners, duplicate owners and cross-namespace methods fail at registration',
        () {
      expect(
          () => ValencePluginRegistry([
                _Plugin('auth', {'auth.read'})
              ]),
          throwsArgumentError);
      expect(
          () => ValencePluginRegistry([
                _Plugin('open', {'open.external'})
              ]),
          throwsArgumentError);
      expect(
          () => ValencePluginRegistry([
                _Plugin('probe', {'probe.read'}),
                _Plugin('probe', {'probe.more'})
              ]),
          throwsArgumentError);
      expect(
          () => ValencePluginRegistry([
                _Plugin('probe', {'secure.get'})
              ]),
          throwsArgumentError);
      expect(
          () => ValencePluginRegistry([
                _Plugin('probe', {'probe..read'})
              ]),
          throwsArgumentError);
    });

    test(
        'registration snapshots the method set and missing methods are unsupported',
        () async {
      final v = await open();
      final methods = {'probe.read'};
      final plugin = _Plugin('probe', methods);
      final registry = ValencePluginRegistry([plugin]);
      methods.add('probe.hidden');
      expect(
          await registry.invoke(v, 'probe.read', {'key': 'k'}), {'key': 'k'});
      expect(
          () => registry.invoke(v, 'probe.hidden', {}),
          throwsA(isA<BridgeError>()
              .having((e) => e.code, 'code', 'E_UNSUPPORTED')));
      expect(() => registry.invoke(v, 'probe.absent', {}),
          throwsA(isA<BridgeError>()));
    });

    test('the built-in open plugin preserves scheme and parameter restrictions',
        () async {
      final v = await open();
      final registry = ValencePluginRegistry();
      for (final url in [
        'javascript:alert(1)',
        'file:///tmp/secret',
        'http://evil.test',
        'data:text/html,x'
      ]) {
        await expectLater(registry.invoke(v, 'open.external', {'url': url}),
            throwsDenied('accepts https'));
      }
      await expectLater(
          registry.invoke(v, 'open.external', {'url': 42}),
          throwsA(
              isA<BridgeError>().having((e) => e.code, 'code', 'E_PARAMS')));
    });
  });

  group('data.put is only for writable buckets (§5.5)', () {
    test('a read-only bucket is refused with E_DENIED', () async {
      final v = await open(dataSchemas: {'plants': 1});
      expect(() => v.dataPut('plants', 'fern', {'x': 1}), throwsDenied('not a writable bucket'));
      expect(await v.dataGet('plants', 'fern'), isNull);
    });

    test('an unknown bucket is refused too', () async {
      final v = await open();
      expect(() => v.dataPut('nope', 'k', {'x': 1}), throwsDenied('not a writable bucket'));
    });

    test('a writable bucket is written at schema 1, with usn -1', () async {
      final v = await open(writableBuckets: {'shelf'});
      await v.dataPut('shelf', 'p-1', {'note': 'hi'});
      final rows = await v.dataList('shelf');
      expect(rows.single.value, {'note': 'hi'});
      expect(rows.single.usn, -1);
      expect(await v.pendingWrites(), 1);
    });

    test('a null value deletes', () async {
      final v = await open(writableBuckets: {'shelf'});
      await v.dataPut('shelf', 'p-1', {'note': 'hi'});
      await v.dataPut('shelf', 'p-1', null);
      expect(await v.dataGet('shelf', 'p-1'), isNull);
    });
  });

  group('schemaFor (§5.4)', () {
    test('a writable bucket is always schema 1', () async {
      final v = await open(writableBuckets: {'shelf'});
      expect(v.schemaFor('shelf'), 1);
    });

    test('a read-only bucket falls back to the configured schema with no manifest', () async {
      final v = await open(dataSchemas: {'plants': 3});
      expect(v.schemaFor('plants'), 3);
    });

    test('the active manifest wins over the configured schema', () async {
      // The old UI keeps reading its own schema, which is what makes a failed trial reversible.
      final v = await open(dataSchemas: {'plants': 1});
      final b = await signBundle(key, seq: 10, requiresData: {'plants': 2});
      final manifest = await checkManifest(
        bytes: b.bytes,
        signature: b.signature,
        config: v.config,
        state: ValenceState(installId: 'i'),
        pointerSeq: null,
      );
      final server = await ValenceServer.bind(
        config: v.config,
        state: v.state,
        casDir: Directory('${support.path}/cas'),
        hostDir: Directory('${support.path}/host'),
        log: LogSpy().call,
      );
      addTearDown(server.close);
      v.bound(server, manifest);
      expect(v.schemaFor('plants'), 2);
    });

    test('an undeclared bucket is E_PARAMS with advice, not a silent empty read', () async {
      final v = await open();
      expect(
        () => v.schemaFor('mystery'),
        throwsA(
          isA<BridgeError>()
              .having((e) => e.code, 'code', BridgeErrorCode.params)
              .having((e) => e.message, 'message', contains('valence.config.json')),
        ),
      );
    });
  });

  group('data.list clamps host-side (§4.2)', () {
    test('the default and the maximum are applied by the host, not trusted from the page', () async {
      // Seeded through one pull page, not 600 `put`s: a put fires an unawaited sync each time, and 600 of
      // those against the shared lease timed this test out under full-suite load.
      final v = await open(dataSchemas: {'places': 1});
      await v.store.applyPullPage(
        bucket: 'places',
        schema: 1,
        rows: [
          for (var i = 0; i < 600; i++) {'k': 'k${i.toString().padLeft(4, '0')}', 'v': i, 'u': i + 1, 'd': 0},
        ],
        maxUsnAfter: 600,
      );
      expect((await v.dataList('places')).length, defaultListLimit);
      expect((await v.dataList('places', limit: 1000000)).length, maxListLimit);
    });

    test('after pages past the clamp, and data.count answers the size question for free', () async {
      // Seeded through one pull page rather than 600 `put`s: a put fires a background sync each time, and
      // the catalogue this models is read-only anyway.
      final v = await open(dataSchemas: {'places': 1});
      await v.store.applyPullPage(
        bucket: 'places',
        schema: 1,
        rows: [
          for (var i = 0; i < 600; i++) {'k': 'k${i.toString().padLeft(4, '0')}', 'v': i, 'u': i + 1, 'd': 0},
        ],
        maxUsnAfter: 600,
      );
      expect(await v.dataCount('places'), 600, reason: 'a number the clamped list could never report');
      expect(await v.dataCount('places', prefix: 'k05'), 100);

      final first = await v.dataList('places', limit: maxListLimit);
      final rest = await v.dataList('places', limit: maxListLimit, after: first.last.key);
      expect(first.length + rest.length, 600);
      expect({...first.map((r) => r.key), ...rest.map((r) => r.key)}.length, 600);
      // The presence question the clamp used to answer wrongly: a key in the tail is found, not absent.
      expect(rest.map((r) => r.key), contains('k0599'));
    });

    test('data.count resolves the bucket the same way every other read does', () async {
      final v = await open(dataSchemas: {'plants': 1});
      expect(await v.dataCount('plants'), 0);
      expect(() => v.dataCount('nope'), throwsA(isA<BridgeError>()), reason: 'an undeclared bucket, as data.get');
    });
  });

  group('data.put refuses a key no server can address (§4.2, §5.5)', () {
    test('"." and ".." never reach the outbox, so push cannot be wedged by one bad write', () async {
      // These are the two keys `encodeURIComponent` leaves alone, so a server mapping a key into a URL
      // path sees them resolve away as dot segments. A server that then rejects the batch — as the
      // reference adapter does — rejects the *same* queued write on every later run, because push replays
      // the outbox: one bad key and nothing in that bucket ever syncs again, with no way for the page to
      // clear it. So it is refused where it enters.
      final v = await open(writableBuckets: {'shelf'});
      for (final key in ['.', '..']) {
        await expectLater(
          v.dataPut('shelf', key, {'x': 1}),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.params)),
          reason: key,
        );
      }
      expect(await v.pendingWrites(), 0, reason: 'nothing was queued');
      // Keys that merely contain dots are fine: only the two that address a parent are refused.
      await v.dataPut('shelf', '...', {'x': 1});
      await v.dataPut('shelf', 'a.b', {'x': 1});
      await v.dataPut('shelf', '.hidden', {'x': 1});
      expect(await v.dataGet('shelf', '...'), {'x': 1});
      expect(await v.dataGet('shelf', '.hidden'), {'x': 1});
    });
  });

  group('prefs reserve the valence. prefix (§4.2)', () {
    test('the page cannot read or write the host’s own keys', () async {
      final v = await open();
      for (final k in ['valence', 'valence.sync.lease', 'valence.anything']) {
        expect(() => v.prefsGet(k), throwsDenied('reserved'), reason: k);
        expect(() => v.prefsSet(k, 'x'), throwsDenied('reserved'), reason: k);
      }
    });

    test('an ordinary key round-trips', () async {
      final v = await open();
      await v.prefsSet('theme', 'dark');
      expect(await v.prefsGet('theme'), 'dark');
      await v.prefsSet('theme', null);
      expect(await v.prefsGet('theme'), isNull);
    });

    test('a key that merely starts with the letters is fine', () async {
      final v = await open();
      await v.prefsSet('valenceish', 'ok');
      expect(await v.prefsGet('valenceish'), 'ok');
    });

    test('the store refuses the prefix too, so an app’s own settings method cannot be a way round it', () async {
      final v = await open();
      await expectLater(v.store.prefSet('valence.sync.lease', '1'), throwsA(isA<BridgeError>()));
      // The runtime writes its own keys through the unchecked entry point.
      await v.store.hostPrefSet('valence.sync.lease', '1');
      expect(await v.store.hostPrefGet('valence.sync.lease'), '1');
    });
  });

  group('open.external allows three schemes (§4.2)', () {
    test('anything else is E_DENIED and never reaches the launcher', () async {
      final v = await open();
      for (final url in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'http://example.com',
        'data:text/html,<script>1</script>',
        'intent://x#Intent;scheme=http;end',
        'content://media/1',
        'not a url at all',
        '',
      ]) {
        expect(() => v.openExternal(url), throwsDenied('https, mailto and tel'), reason: url);
      }
    });

    test('the three allowed schemes get past the check', () async {
      // They then reach url_launcher, which has no platform implementation under flutter_test, so the
      // assertion is that the *scheme check* passed rather than that the OS opened anything.
      final v = await open();
      for (final url in ['https://example.com', 'mailto:a@b.c', 'tel:+15551234']) {
        await expectLater(
          v.openExternal(url),
          throwsA(isNot(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.denied))),
          reason: url,
        );
      }
    });

    test('the scheme check is case-insensitive', () async {
      final v = await open();
      expect(() => v.openExternal('JAVASCRIPT:alert(1)'), throwsDenied('https, mailto and tel'));
    });
  });

  group('publishHostFile (§3, §4.2)', () {
    test('it fails clearly before the server is bound', () async {
      final v = await open();
      expect(
        () => v.publishHostFile([1, 2, 3], contentType: 'image/png'),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internal)),
      );
    });
  });

  group('sync.now', () {
    test('it follows the configured schemas when nothing is being served', () async {
      final seen = <String>[];
      final v = await open(
        dataSchemas: {'plants': 2},
        client: MockClient((req) async {
          seen.add(req.url.toString());
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      final result = await v.syncNow();
      expect(result.buckets, ['plants']);
      expect(seen.single, contains('schema=2'));
    });
  });

  group('open (§5.1, §5.2)', () {
    test('it creates the valence directory and leaves the database outside it', () async {
      final v = await open();
      expect(v.dir.path, endsWith('valence'));
      expect(v.dir.existsSync(), isTrue);
      // The database holds user data and should be backed up, so it lives outside the excluded directory.
      expect(File('${support.path}${Platform.pathSeparator}valence.db').existsSync(), isTrue);
    });

    test('a missing seed asset is logged, not fatal', () async {
      final log = LogSpy();
      await open(dataSchemas: {'plants': 1}, log: log);
      expect(log.has('no bundled seed'), isTrue);
    });

    test('the journal mode is reported when it is not wal', () async {
      final v = await open();
      expect(v.store.journalMode, isNotEmpty);
    });
  });

  group('secure.* and auth.* reach the keystore (§4.4)', () {
    test('the page can set, read and delete its own keys but not the host’s', () async {
      final data = <String, String>{};
      final v = await open(secure: testSecure(data));
      await v.secureSet('refresh', 'r-1');
      expect(await v.secureGet('refresh'), 'r-1');
      await v.secureDelete('refresh');
      expect(await v.secureGet('refresh'), isNull);
      expect(() => v.secureGet(secureAuthTokenKey), throwsDenied('reserved'));
      expect(() => v.secureSet('valence.x', 'y'), throwsDenied('reserved'));
      expect(() => v.secureDelete('valence.x'), throwsDenied('reserved'));
    });

    test('auth.setToken stores a token only auth.hasToken can see', () async {
      final data = <String, String>{};
      final v = await open(secure: testSecure(data));
      expect(await v.authHasToken(), isFalse);
      await v.authSetToken('jwt-1');
      expect(await v.authHasToken(), isTrue);
      expect(data[secureAuthTokenKey], 'jwt-1');
      await v.authSetToken(null);
      expect(await v.authHasToken(), isFalse);
    });

    test('the stored token is what sync attaches to a user bucket', () async {
      final seen = <Map<String, String>>[];
      final v = await open(
        writableBuckets: {'shelf'},
        secure: testSecure({}),
        client: MockClient((req) async {
          seen.add(req.headers);
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      // This is the wiring R1 is about: the page sets a token through the bridge and the *host's own*
      // requests carry it, which is the one thing a token the page holds cannot do.
      await v.authSetToken('jwt-1');
      await v.syncNow();
      expect(seen, isNotEmpty);
      expect(seen.every((h) => h['authorization'] == 'Bearer jwt-1'), isTrue);
    });

    test('an app’s own authToken callback still wins over the stored one', () async {
      final seen = <Map<String, String>>[];
      final v = await open(
        config: ValenceConfig(
          appId: 'com.example.app',
          keyring: {key.keyId: key.publicKeyBase64},
          bridgeVersion: 1,
          syncBase: 'https://sync.test',
          writableBuckets: const {'shelf'},
          authToken: () async => 'from-dart',
        ),
        secure: testSecure({secureAuthTokenKey: 'from-the-page'}),
        client: MockClient((req) async {
          seen.add(req.headers);
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      await v.syncNow();
      expect(seen.single['authorization'], 'Bearer from-dart');
    });

    test('an account switch clears the user data, and a refresh does not (§4.4)', () async {
      final data = <String, String>{};
      final v = await open(writableBuckets: {'shelf'}, dataSchemas: {'plants': 1}, secure: testSecure(data));
      // A read-only bucket and a writable one, both with rows and a cursor.
      await v.store.applyPullPage(
          bucket: 'plants', schema: 1, rows: [{'k': 'fern', 'v': 1, 'u': 7, 'd': 0}], maxUsnAfter: 7);
      await v.store.applyPullPage(
          bucket: 'shelf', schema: 1, rows: [{'k': 'a', 'v': 1, 'u': 4, 'd': 0}], maxUsnAfter: 4);

      // Nothing recorded yet, so the first id is an adoption: an app upgrading with its user signed in.
      await v.authSetToken('jwt-a', account: 'user-a');
      expect(await v.authAccount(), 'user-a');
      expect(await v.dataGet('shelf', 'a'), 1, reason: 'adoption clears nothing');

      // A refresh of the same account is a new token and nothing else.
      await v.authSetToken('jwt-a2', account: 'user-a');
      expect(data[secureAuthTokenKey], 'jwt-a2');
      expect(await v.dataGet('shelf', 'a'), 1);
      expect(await v.store.maxUsn('shelf', 1), 4);

      final view = _ScriptSpy();
      v.attach(view);
      await v.authSetToken('jwt-b', account: 'user-b');
      expect(await v.authAccount(), 'user-b');
      expect(data[secureAuthTokenKey], 'jwt-b');
      expect(await v.dataGet('shelf', 'a'), isNull, reason: 'B must not see A rows on a shared phone');
      expect(await v.store.maxUsn('shelf', 1), 0, reason: "A's cursor says nothing about B's history");
      expect(await v.dataGet('plants', 'fern'), 1, reason: 'the public bucket is the same for everyone');
      expect(await v.store.maxUsn('plants', 1), 7);
      expect(view.events, ['sync.changed'], reason: 'the page is showing rows that are gone');
      expect(view.scripts.single, contains('"shelf"'));
    });

    test('a switch over queued writes is refused, and discardPending is the only way past (§4.4)', () async {
      final data = <String, String>{};
      final v = await open(writableBuckets: {'shelf'}, secure: testSecure(data));
      await v.authSetToken('jwt-a', account: 'user-a');
      await v.store.put('shelf', 'note', {'t': 'mine'}, opId: 'op-1');
      expect(await v.store.pendingWrites(), 1);

      // The host attaches whatever token is stored when the request is made, so letting this through
      // pushes A's row under B's credentials. Nothing changes: not the token, not the id, not a row.
      await expectLater(
        v.authSetToken('jwt-b', account: 'user-b'),
        throwsA(isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.pending)
            .having((e) => e.message, 'message', contains('1 local write'))),
      );
      expect(data[secureAuthTokenKey], 'jwt-a');
      expect(await v.authAccount(), 'user-a');
      expect(await v.dataGet('shelf', 'note'), {'t': 'mine'});
      expect(await v.sync.acquireLease(), isTrue, reason: 'the refusal released the lease it took');
      await v.sync.releaseLease();

      await v.authSetToken('jwt-b', account: 'user-b', discardPending: true);
      expect(await v.store.pendingWrites(), 0, reason: 'deleted unsent, which is what the flag means');
      expect(await v.dataGet('shelf', 'note'), isNull);
      expect(await v.authAccount(), 'user-b');
    });

    test('signing out clears the same, but only for an app that records an account (§4.4)', () async {
      final v = await open(writableBuckets: {'shelf'}, secure: testSecure({}));
      await v.store.applyPullPage(
          bucket: 'shelf', schema: 1, rows: [{'k': 'a', 'v': 1, 'u': 4, 'd': 0}], maxUsnAfter: 4);

      // The 0.3 shape: no account anywhere, so logout keeps the rows exactly where they are.
      await v.authSetToken('jwt-x');
      await v.authSetToken(null);
      expect(await v.authHasToken(), isFalse);
      expect(await v.dataGet('shelf', 'a'), 1, reason: 'no app gets a wipe it did not ask for');

      await v.authSetToken('jwt-a', account: 'user-a');
      await v.store.put('shelf', 'note', {'t': 'mine'}, opId: 'op-1');
      await expectLater(
        v.authSetToken(null),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.pending)),
      );
      expect(await v.authHasToken(), isTrue, reason: 'a refused sign-out changed nothing');

      await v.authSetToken(null, discardPending: true);
      expect(await v.authHasToken(), isFalse);
      expect(await v.authAccount(), isNull, reason: 'the next sign-in is an adoption, not a second wipe');
      expect(await v.dataGet('shelf', 'a'), isNull);
      expect(await v.store.pendingWrites(), 0);
    });

    test('the new token is stored under the same lease that cleared the data (§4.4)', () async {
      // The window this closes: the clear finishes, the lease is released, and a sync fired by a resume
      // or by returning connectivity pulls the previous account's rows straight back — with the previous
      // account's token, because the header is built per request — and the new token is then written
      // over them. So the invariant is not "a sync is refused" but "the lease is still held at the
      // moment the token is written", which is what this probes.
      late Valence v;
      final data = <String, String>{};
      var heldAtTokenWrite = false;
      final watcher = _WatchedSecureStorage(data, (key) async {
        if (key != secureAuthTokenKey) return;
        // acquireLease() answers false while *this* process holds a live lease, and takes it otherwise
        // — so put back what the probe took.
        final free = await v.sync.acquireLease();
        if (free) await v.sync.releaseLease();
        heldAtTokenWrite = !free;
      });
      FlutterSecureStoragePlatform.instance = watcher;
      v = await open(writableBuckets: {'shelf'}, secure: ValenceSecure(log: (_) {}));
      await v.authSetToken('jwt-a', account: 'user-a');
      expect(heldAtTokenWrite, isFalse, reason: 'an ordinary sign-in takes no lease');
      await v.authSetToken('jwt-b', account: 'user-b');
      expect(heldAtTokenWrite, isTrue, reason: 'the switch wrote the token before releasing');
      expect(data[secureAuthTokenKey], 'jwt-b');
      expect(await v.sync.acquireLease(), isTrue, reason: 'and the lease is released at the end');
      await v.sync.releaseLease();
    });

    test('an unreadable account id fails the call rather than reading as "none recorded"', () async {
      // Every other secure read fails open, because the alternative is failing a sync over a bucket
      // that was never authenticated. This one cannot: "absent" is the answer that means *no account
      // has ever been recorded*, which turns the next sign-in into an adoption — B's token stored over
      // A's rows and A's outbox, silently, on exactly the devices whose Keystore is in a bad state.
      final data = <String, String>{secureAuthAccountKey: 'user-a', secureAuthTokenKey: 'jwt-a'};
      FlutterSecureStoragePlatform.instance = _UnreadableAccount(data);
      final v = await open(writableBuckets: {'shelf'}, secure: ValenceSecure(log: (_) {}));
      await v.store.applyPullPage(
          bucket: 'shelf', schema: 1, rows: [{'k': 'a', 'v': 1, 'u': 4, 'd': 0}], maxUsnAfter: 4);
      await expectLater(
        v.authSetToken('jwt-b', account: 'user-b'),
        throwsA(isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.internal)
            .having((e) => e.message, 'message', contains('same account'))),
      );
      expect(data[secureAuthTokenKey], 'jwt-a', reason: 'nothing was changed');
      expect(await v.dataGet('shelf', 'a'), 1);
    });

    test('an empty token clears the token and never the data (§4.4)', () async {
      // `''` has always meant "clear the token". A refresh loop that yields it on failure, or an
      // uninitialised state field, must not read as "a different person is holding the phone".
      final v = await open(writableBuckets: {'shelf'}, secure: testSecure({}));
      await v.store.applyPullPage(
          bucket: 'shelf', schema: 1, rows: [{'k': 'a', 'v': 1, 'u': 4, 'd': 0}], maxUsnAfter: 4);
      await v.authSetToken('jwt-a', account: 'user-a');
      await v.authSetToken('');
      expect(await v.authHasToken(), isFalse);
      expect(await v.dataGet('shelf', 'a'), 1, reason: 'only null is the sign-out');
      expect(await v.authAccount(), 'user-a');
    });

    test('a switch will not clear underneath a sync that holds the lease (§5.6)', () async {
      final v = await open(writableBuckets: {'shelf'}, secure: testSecure({}));
      await v.store.applyPullPage(
          bucket: 'shelf', schema: 1, rows: [{'k': 'a', 'v': 1, 'u': 4, 'd': 0}], maxUsnAfter: 4);
      await v.authSetToken('jwt-a', account: 'user-a');
      // A push in flight has already read the old token and its acknowledgements would land after the
      // wipe, re-creating the rows of the account that just left.
      expect(await v.sync.acquireLease(), isTrue);
      await expectLater(
        v.authSetToken('jwt-b', account: 'user-b'),
        throwsA(isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.internal)
            .having((e) => e.message, 'message', contains('a sync is running'))),
      );
      expect(await v.dataGet('shelf', 'a'), 1);
      expect(await v.authAccount(), 'user-a');
      await v.sync.releaseLease();
      await v.authSetToken('jwt-b', account: 'user-b');
      expect(await v.dataGet('shelf', 'a'), isNull);
      expect(await v.sync.acquireLease(), isTrue, reason: 'and the switch released what it took');
    });

    test('a 401 is emitted to the page as auth.expired', () async {
      final v = await open(
        writableBuckets: {'shelf'},
        secure: testSecure({secureAuthTokenKey: 'expired'}),
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      final view = _ScriptSpy();
      v.attach(view);
      final result = await v.syncNow();
      expect(result.reason, ValenceSyncReason.unauthorized);
      expect(
        view.scripts.first,
        'window.__valence&&window.__valence.e("auth.expired",{})',
        reason: 'built through jsonEncode by the same helper as every other event',
      );
      // And the run still reports itself: "the token was rejected" is exactly the outcome a freshness
      // line has to show, and sync.changed alone has no way to say it (§4.6).
      expect(view.events, ['auth.expired', 'sync.changed', 'sync.done']);
      expect(view.scripts.last, contains('"reason":"unauthorized"'));
    });
  });

  group('a database locked by another isolate', () {
    // §5.6. An app update is the launch that collides: WorkManager fires the already-registered periodic
    // job while the UI isolate holds `BEGIN EXCLUSIVE` for the schema upgrade. `busy_timeout` does not
    // cover it, because the lock is refused before the connection that would wait on it exists.

    test('open retries until the lock clears rather than failing the launch', () async {
      final locking = LockingDatabaseFactory(databaseFactoryFfi, locks: 2);
      final log = LogSpy();

      final v = await Valence.open(
        testConfig(key),
        log: log.call,
        client: MockClient((_) async => http.Response('{}', 200)),
        supportDir: support,
        documentsDir: support,
        secure: testSecure({}),
        databaseFactory: locking,
      );

      expect(locking.attempts, 3, reason: 'two refusals, then the open that worked');
      expect(await v.syncStatus(), isNotNull, reason: 'a usable store, not a half-open one');
      expect(log.has('the database is locked by another isolate'), isTrue);
    });

    test('open gives up and rethrows once the budget is spent, because an app with no store cannot start',
        () async {
      await expectLater(
        Valence.open(
          testConfig(key),
          log: LogSpy().call,
          client: MockClient((_) async => http.Response('{}', 200)),
          supportDir: support,
          documentsDir: support,
          secure: testSecure({}),
          databaseFactory: LockingDatabaseFactory(databaseFactoryFfi, locks: 99),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('a failed open is not cached, so the next call sees a database that is now fine', () async {
      // Caching the rejection would leave every later call in the isolate failing against a healthy file.
      final locking = LockingDatabaseFactory(databaseFactoryFfi, locks: 1);
      final path = '${support.path}${Platform.pathSeparator}valence.db';
      await expectLater(ValenceStore.open(path, factory: locking), throwsA(isA<DatabaseException>()));

      final store = await ValenceStore.open(path, factory: locking);
      expect(await store.prefGet('anything'), isNull);
    });

    test('backgroundSync reports busy instead of throwing, so WorkManager does not record a failure',
        () async {
      final log = LogSpy();

      final result = await Valence.backgroundSync(
        testConfig(key),
        log: log.call,
        client: MockClient((_) async => http.Response('{}', 200)),
        supportDir: support,
        documentsDir: support,
        secure: testSecure({}),
        databaseFactory: LockingDatabaseFactory(databaseFactoryFfi, locks: 99),
      );

      expect(result.reason, ValenceSyncReason.busy);
      expect(result.changed, 0);
      expect(result.offline, isFalse, reason: 'nothing was attempted, so nothing observed the network');
      expect(log.has('the UI isolate holds the database'), isTrue);
    });

    test('isDatabaseLocked matches what Android prints, and nothing else', () {
      expect(isDatabaseLocked(LockedDatabaseException()), isTrue);
      expect(isDatabaseLocked(const SocketException('offline')), isFalse);
      expect(isDatabaseLocked(StateError('no such table')), isFalse);
      // The message match is anchored, because `toString()` appends the failing SQL and its arguments —
      // and those can come from the page. A loose `contains` would read an unrelated failure of
      // `data.put(bucket, 'database is locked', v)` as a lock, and retry instead of surfacing it.
      expect(isDatabaseLocked(NotLockedDatabaseException("UNIQUE constraint failed", "database is locked")), isFalse,
          reason: 'the phrase appears only in a page-supplied argument');
    });
  });

  // ===========================================================================
  group('§4.6 lifecycle, connectivity and update status', () {
    test('the five platform states are the four the page sees', () {
      // The mapping is the contract, not an implementation detail: a page switching on the value has to
      // be able to cover it, and "hidden" and "paused" are one backgrounding, not two.
      expect(valenceLifecycleFor(AppLifecycleState.resumed), ValenceLifecycle.foreground);
      expect(valenceLifecycleFor(AppLifecycleState.inactive), ValenceLifecycle.inactive);
      expect(valenceLifecycleFor(AppLifecycleState.hidden), ValenceLifecycle.background);
      expect(valenceLifecycleFor(AppLifecycleState.paused), ValenceLifecycle.background);
      expect(valenceLifecycleFor(AppLifecycleState.detached), ValenceLifecycle.detached);
    });

    test('online means any interface that is not none', () {
      // A device on Wi-Fi and VPN at once reports two, and a check written against the first entry calls
      // it offline whenever the VPN sorts first.
      expect(valenceOnline([ConnectivityResult.wifi]), isTrue);
      expect(valenceOnline([ConnectivityResult.none, ConnectivityResult.vpn]), isTrue);
      expect(valenceOnline([ConnectivityResult.none]), isFalse);
      expect(valenceOnline([]), isFalse, reason: 'no interfaces at all is not online');
    });

    test('app.state answers before any event has been emitted, and optimistically', () async {
      // A page only ever runs while the app is on screen, and a host whose connectivity plugin has not
      // answered yet must not claim the device is offline: the cost of that error is a UI that refuses
      // to try on a working network.
      final v = await open();
      expect(v.appState().lifecycle, ValenceLifecycle.foreground);
      expect(v.appState().online, isTrue);
    });

    test('only a change emits, which is what makes the two events countable', () async {
      final v = await open();
      final spy = _ScriptSpy();
      v.attach(spy);
      // Android delivers hidden then paused for one backgrounding: both map to background, and the
      // second one must not produce an event a page would count.
      v.noteLifecycle(ValenceLifecycle.background);
      v.noteLifecycle(ValenceLifecycle.background);
      expect(v.appState().lifecycle, ValenceLifecycle.background);
      v.noteLifecycle(ValenceLifecycle.foreground);

      v.noteOnline(true); // already the optimistic default
      v.noteOnline(false);
      v.noteOnline(false);
      expect(v.appState().online, isFalse);

      expect(spy.events, ['app.lifecycle', 'app.lifecycle', 'app.online']);
      expect(spy.scripts[0], contains('"state":"background"'));
      expect(spy.scripts[1], contains('"state":"foreground"'));
      expect(spy.scripts[2], contains('"online":false'));
    });

    test('a state event with no page is dropped, not queued, and app.state keeps the truth', () async {
      // The §4.2 buffer is for one-shot events. These two are state: queueing them would be an unbounded
      // list — a host whose entry page never loads, on a device moving between networks — holding
      // transitions that are stale by the time anything reads them.
      final v = await open();
      final spy = _ScriptSpy()..pageLoaded = false;
      v.attach(spy);
      v.noteLifecycle(ValenceLifecycle.background);
      v.noteOnline(false);
      expect(spy.scripts, isEmpty);
      // Recorded all the same, so the page that loads next reads the truth from app.state().
      expect(v.appState().lifecycle, ValenceLifecycle.background);
      expect(v.appState().online, isFalse);

      // And nothing is replayed when a page does arrive.
      spy.pageLoaded = true;
      expect(spy.scripts, isEmpty);
      v.noteLifecycle(ValenceLifecycle.foreground);
      expect(spy.events, ['app.lifecycle']);
    });

    test('every completed run reports itself, sync.changed before sync.done', () async {
      final v = await open(dataSchemas: {'plants': 1});
      final spy = _ScriptSpy();
      v.attach(spy);
      final result = await v.syncNow();
      // The mock server has nothing, so this is the run sync.changed alone could never report.
      expect(result.changed, 0);
      expect(spy.events, ['sync.changed', 'sync.done'], reason: 'refetch first, then the freshness line');
      expect(spy.scripts.last, contains('"changed":0'));
      expect(spy.scripts.last, contains('"reason":"ok"'));

      // A second run moves nothing, so there is no sync.changed — and still a sync.done.
      spy.scripts.clear();
      await v.syncNow();
      expect(spy.events, ['sync.done']);
    });

    test("data.put's own push reports itself, because the page's writes are most of an outbox", () async {
      // The push goes straight through Valence.syncNow and never passes a host-widget trigger, so a host
      // that reported only its own triggers would leave the freshness line untouched by the page's writes.
      final v = await open(writableBuckets: {'notes'});
      final spy = _ScriptSpy();
      v.attach(spy);
      await v.dataPut('notes', 'a', {'t': 1});
      // The push is deliberately not awaited by data.put: a local write is durable at commit.
      for (var i = 0; i < 100 && !spy.events.contains('sync.done'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(spy.events, contains('sync.done'));
    });

    test('bundle.status before any check says idle rather than "up to date"', () async {
      // The distinction the page needs: nothing has been asked yet, so claiming freshness would be a
      // guess. serving is 0 because the host widget has not bound a manifest in a unit test.
      final v = await open();
      final s = v.bundleStatus();
      expect(s.reason, ValenceBundleReason.idle);
      expect(s.checkedAt, isNull);
      expect(s.offered, isNull);
      expect(s.serving, 0);
      expect(s.pending, isNull);
      expect(s.trial, isNull);
    });

    test('bundle.status reports the live activation state and the last check', () async {
      final v = await open(config: testConfig(key, otaBase: ''));
      v.state.pending = 31;
      v.state.trial = 30;
      // No otaBase, so the check is honest about never having run rather than guessing freshness.
      await v.updater.checkForUpdate();
      final s = v.bundleStatus();
      expect(s.pending, 31);
      expect(s.trial, 30);
      expect(s.reason, ValenceBundleReason.unconfigured);
      expect(s.checkedAt, isNotNull);
    });

    test('a SyncResult crosses the bridge the same way in a reply and in sync.done', () async {
      // sync.done carries the whole record, including the two fields a schema may not declare: an app's
      // handler reads what it knows about and an older host simply never sends them (§4.3).
      const result = ValenceSyncResult(['notes'], 3, false, ValenceSyncReason.busy, 7);
      expect(result.toJson(), {
        'buckets': ['notes'],
        'changed': 3,
        'offline': false,
        'reason': 'busy',
        'pending': 7,
      });
    });
  });
}

/// A host view that records the event scripts the runtime emits.
final class _ScriptSpy implements ValenceHostView {
  final List<String> scripts = [];

  /// Whether a page is loaded. Settable, because §4.6's state events are dropped when it is false.
  @override
  bool pageLoaded = true;

  /// The names of the events emitted, in order. The shape is fixed by §4.2's wire table.
  List<String> get events => [for (final s in scripts) s.split('.e("')[1].split('"')[0]];

  @override
  void runScript(String script) => scripts.add(script);

  @override
  Future<void> reloadPage() async {}

  @override
  Future<void> handleReady() async {}
}

final class _Plugin implements ValencePlugin {
  _Plugin(this.namespace, this.methods);
  @override
  final String namespace;
  @override
  final Set<String> methods;
  @override
  Future<Object?> invoke(
          Valence valence, String method, Map<String, Object?> params) async =>
      params;
}

/// The in-memory secure storage the tests use, with a hook that runs *during* a write.
///
/// The §4.4 switch must still hold the sync lease when it stores the new token, and that is only
/// observable from inside the write: afterwards the lease is gone either way.
final class _WatchedSecureStorage extends TestFlutterSecureStoragePlatform {
  _WatchedSecureStorage(super.data, this._onWrite);

  final Future<void> Function(String key) _onWrite;

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    await _onWrite(key);
    return super.write(key: key, value: value, options: options);
  }
}

/// A platform whose account-id read throws, as an invalidated Keystore entry does.
final class _UnreadableAccount extends TestFlutterSecureStoragePlatform {
  _UnreadableAccount(super.data);

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    if (key == secureAuthAccountKey) throw PlatformException(code: 'Invalid');
    return super.read(key: key, options: options);
  }
}
