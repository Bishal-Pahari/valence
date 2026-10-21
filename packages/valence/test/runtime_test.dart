// The built-in bridge methods' policy: the trust boundary that lives in the package rather than in the
// generated marshalling. Contracts Ã‚Â§4.2, Ã‚Â§5.4, Ã‚Â§5.5.
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
    ValenceConfig? config,
    ValenceSecure? secure,
  }) =>
      Valence.open(
        config ??
            testConfig(key,
                writableBuckets: writableBuckets, dataSchemas: dataSchemas),
        hostBuild: 42,
        log: (log ?? LogSpy()).call,
        client: client ??
            MockClient((_) async => http.Response(
                jsonEncode({'rows': [], 'max': 0, 'more': false}), 200)),
        supportDir: support,
        secure: secure ?? testSecure({}),
      );

  Matcher throwsDenied(String fragment) => throwsA(
        isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.denied)
            .having((e) => e.message, 'message', contains(fragment)),
      );

  group('app.info', () {
    test(
        'it reports the platform, the host build, the bridge version and the locale',
        () async {
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

  group('native plugins (Ã‚Â§4.5)', () {
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

  group('data.put is only for writable buckets (Ã‚Â§5.5)', () {
    test('a read-only bucket is refused with E_DENIED', () async {
      final v = await open(dataSchemas: {'plants': 1});
      expect(() => v.dataPut('plants', 'fern', {'x': 1}),
          throwsDenied('not a writable bucket'));
      expect(await v.dataGet('plants', 'fern'), isNull);
    });

    test('an unknown bucket is refused too', () async {
      final v = await open();
      expect(() => v.dataPut('nope', 'k', {'x': 1}),
          throwsDenied('not a writable bucket'));
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

  group('schemaFor (Ã‚Â§5.4)', () {
    test('a writable bucket is always schema 1', () async {
      final v = await open(writableBuckets: {'shelf'});
      expect(v.schemaFor('shelf'), 1);
    });

    test(
        'a read-only bucket falls back to the configured schema with no manifest',
        () async {
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

    test(
        'an undeclared bucket is E_PARAMS with advice, not a silent empty read',
        () async {
      final v = await open();
      expect(
        () => v.schemaFor('mystery'),
        throwsA(
          isA<BridgeError>()
              .having((e) => e.code, 'code', BridgeErrorCode.params)
              .having(
                  (e) => e.message, 'message', contains('valence.config.json')),
        ),
      );
    });
  });

  group('data.list clamps host-side (Ã‚Â§4.2)', () {
    test(
        'the default and the maximum are applied by the host, not trusted from the page',
        () async {
      final v = await open(writableBuckets: {'shelf'});
      for (var i = 0; i < 600; i++) {
        await v.store
            .put('shelf', 'k${i.toString().padLeft(4, '0')}', i, opId: 'op-$i');
      }
      expect((await v.dataList('shelf')).length, defaultListLimit);
      expect((await v.dataList('shelf', limit: 1000000)).length, maxListLimit);
    });
  });

  group('prefs reserve the valence. prefix (Ã‚Â§4.2)', () {
    test('the page cannot read or write the hostÃ¢â‚¬â„¢s own keys', () async {
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

    test(
        'the store refuses the prefix too, so an appÃ¢â‚¬â„¢s own settings method cannot be a way round it',
        () async {
      final v = await open();
      await expectLater(v.store.prefSet('valence.sync.lease', '1'),
          throwsA(isA<BridgeError>()));
      // The runtime writes its own keys through the unchecked entry point.
      await v.store.hostPrefSet('valence.sync.lease', '1');
      expect(await v.store.hostPrefGet('valence.sync.lease'), '1');
    });
  });

  group('open.external allows three schemes (Ã‚Â§4.2)', () {
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
        expect(() => v.openExternal(url), throwsDenied('https, mailto and tel'),
            reason: url);
      }
    });

    test('the three allowed schemes get past the check', () async {
      // They then reach url_launcher, which has no platform implementation under flutter_test, so the
      // assertion is that the *scheme check* passed rather than that the OS opened anything.
      final v = await open();
      for (final url in [
        'https://example.com',
        'mailto:a@b.c',
        'tel:+15551234'
      ]) {
        await expectLater(
          v.openExternal(url),
          throwsA(isNot(isA<BridgeError>()
              .having((e) => e.code, 'code', BridgeErrorCode.denied))),
          reason: url,
        );
      }
    });

    test('the scheme check is case-insensitive', () async {
      final v = await open();
      expect(() => v.openExternal('JAVASCRIPT:alert(1)'),
          throwsDenied('https, mailto and tel'));
    });
  });

  group('publishHostFile (Ã‚Â§3, Ã‚Â§4.2)', () {
    test('it fails clearly before the server is bound', () async {
      final v = await open();
      expect(
        () => v.publishHostFile([1, 2, 3], contentType: 'image/png'),
        throwsA(isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.internal)),
      );
    });
  });

  group('sync.now', () {
    test('it follows the configured schemas when nothing is being served',
        () async {
      final seen = <String>[];
      final v = await open(
        dataSchemas: {'plants': 2},
        client: MockClient((req) async {
          seen.add(req.url.toString());
          return http.Response(
              jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      final result = await v.syncNow();
      expect(result.buckets, ['plants']);
      expect(seen.single, contains('schema=2'));
    });
  });

  group('open (Ã‚Â§5.1, Ã‚Â§5.2)', () {
    test('it creates the valence directory and leaves the database outside it',
        () async {
      final v = await open();
      expect(v.dir.path, endsWith('valence'));
      expect(v.dir.existsSync(), isTrue);
      // The database holds user data and should be backed up, so it lives outside the excluded directory.
      expect(
          File('${support.path}${Platform.pathSeparator}valence.db')
              .existsSync(),
          isTrue);
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

  group('secure.* and auth.* reach the keystore (Ã‚Â§4.4)', () {
    test(
        'the page can set, read and delete its own keys but not the hostÃ¢â‚¬â„¢s',
        () async {
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
          return http.Response(
              jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      // This is the wiring R1 is about: the page sets a token through the bridge and the *host's own*
      // requests carry it, which is the one thing a token the page holds cannot do.
      await v.authSetToken('jwt-1');
      await v.syncNow();
      expect(seen, isNotEmpty);
      expect(seen.every((h) => h['authorization'] == 'Bearer jwt-1'), isTrue);
    });

    test(
        'an appÃ¢â‚¬â„¢s own authToken callback still wins over the stored one',
        () async {
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
          return http.Response(
              jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      await v.syncNow();
      expect(seen.single['authorization'], 'Bearer from-dart');
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
        view.scripts.single,
        'window.__valence&&window.__valence.e("auth.expired",{})',
        reason:
            'built through jsonEncode by the same helper as every other event',
      );
    });
  });
}

/// A host view that records the event scripts the runtime emits.
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

final class _ScriptSpy implements ValenceHostView {
  final List<String> scripts = [];

  @override
  void runScript(String script) => scripts.add(script);

  @override
  Future<void> reloadPage() async {}

  @override
  Future<void> handleReady() async {}
}
