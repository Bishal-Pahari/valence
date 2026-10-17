// The built-in bridge methods' policy: the trust boundary that lives in the package rather than in the
// generated marshalling. Contracts §4.2, §5.4, §5.5.
import 'dart:convert';
import 'dart:io';

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
  }) =>
      Valence.open(
        testConfig(key, writableBuckets: writableBuckets, dataSchemas: dataSchemas),
        hostBuild: 42,
        log: (log ?? LogSpy()).call,
        client: client ?? MockClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200)),
        supportDir: support,
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
      final v = await open(writableBuckets: {'shelf'});
      for (var i = 0; i < 600; i++) {
        await v.store.put('shelf', 'k${i.toString().padLeft(4, '0')}', i, opId: 'op-$i');
      }
      expect((await v.dataList('shelf')).length, defaultListLimit);
      expect((await v.dataList('shelf', limit: 1000000)).length, maxListLimit);
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
}
