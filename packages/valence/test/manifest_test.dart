// Contracts §2.1, §2.2 and the canonical check order: "each check 1-7 rejects".
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  late TestKey key;

  setUpAll(() async => key = await TestKey.create());

  ValenceState freshState({int floor = 0}) => ValenceState(installId: 'install-1', floor: floor);

  Future<ValenceManifest> check(
    SignedBundle b, {
    ValenceConfig? config,
    ValenceState? state,
    int? pointerSeq,
    String? signature,
  }) =>
      checkManifest(
        bytes: b.bytes,
        signature: signature ?? b.signature,
        config: config ?? testConfig(key),
        state: state ?? freshState(),
        pointerSeq: pointerSeq ?? b.seq,
      );

  Future<ValenceCheckFailure> expectStop(Future<ValenceManifest> f, int step) async {
    try {
      await f;
      fail('expected a stop at check $step, but the manifest was accepted');
    } on ValenceCheckFailure catch (e) {
      expect(e.step, step, reason: 'stopped at the wrong step: $e');
      return e;
    }
  }

  group('check 1, the signature over the exact bytes', () {
    test('a sign and verify round trip is accepted', () async {
      final b = await signBundle(key, seq: 10);
      final m = await check(b);
      expect(m.seq, 10);
      expect(m.entry, 'index.html');
      expect(m.files, hasLength(1));
    });

    test('a tampered byte is rejected', () async {
      final b = await signBundle(key, seq: 10);
      final tampered = Uint8List.fromList(utf8.encode(utf8.decode(b.bytes).replaceFirst('"seq": 10', '"seq": 11')));
      await expectStop(
        checkManifest(
          bytes: tampered,
          signature: b.signature,
          config: testConfig(key),
          state: freshState(),
          pointerSeq: 11,
        ),
        1,
      );
    });

    test('a bad signature is rejected', () async {
      final b = await signBundle(key, seq: 10);
      final other = await signBundle(key, seq: 11);
      await expectStop(check(b, signature: other.signature), 1);
    });

    test('a signature that is not base64 is rejected', () async {
      final b = await signBundle(key, seq: 10);
      await expectStop(check(b, signature: 'not base64 at all!!'), 1);
    });

    test('an unknown keyId is rejected before anything else is read', () async {
      final stranger = await TestKey.create('k9');
      final b = await signBundle(stranger, seq: 10);
      final e = await expectStop(check(b), 1);
      expect(e.reason, contains('unknown keyId'));
    });

    test('a manifest signed by a different key for a known keyId is rejected', () async {
      // The attacker holds a key and claims our keyId. The keyring is what decides.
      final impostor = await TestKey.create('k1');
      final b = await signBundle(impostor, seq: 10);
      await expectStop(check(b), 1);
    });

    test('an unsupported format is refused before its fields are trusted', () async {
      final b = await signBundle(key, seq: 10, overrides: {'format': 2});
      final e = await expectStop(check(b), 1);
      expect(e.reason, contains('format'));
    });

    test('a trailing newline on the .sig file is tolerated', () async {
      final b = await signBundle(key, seq: 10);
      final m = await check(b, signature: '${b.signature}\n  ');
      expect(m.seq, 10);
    });
  });

  group('check 2, appId', () {
    test('another appId is rejected', () async {
      final b = await signBundle(key, seq: 10, appId: 'com.other.app');
      final e = await expectStop(check(b), 2);
      expect(e.reason, contains('com.other.app'));
    });
  });

  group('check 3, seq == pointer.seq', () {
    test('a manifest served under a different seq is rejected', () async {
      final b = await signBundle(key, seq: 10);
      await expectStop(check(b, pointerSeq: 11), 3);
    });

    test('the built-in bundle skips check 3, because it has no pointer', () async {
      final b = await signBundle(key, seq: 10);
      final m = await check(b, pointerSeq: null);
      expect(m.seq, 10);
    });
  });

  group('check 4, seq >= state.floor', () {
    test('a bundle below the floor is rejected', () async {
      final b = await signBundle(key, seq: 10);
      await expectStop(check(b, state: freshState(floor: 20)), 4);
    });

    test('a bundle exactly at the floor is accepted', () async {
      final b = await signBundle(key, seq: 20, floor: 20);
      expect((await check(b, state: freshState(floor: 20))).seq, 20);
    });
  });

  group('check 5, requires', () {
    test('a newer bridge than the host has is refused', () async {
      final b = await signBundle(key, seq: 10, requiresBridge: 4);
      final e = await expectStop(check(b, config: testConfig(key, bridgeVersion: 3)), 5);
      expect(e.reason, contains('needs bridge 4'));
    });

    test('a bundle requiring exactly the host bridge version is ACCEPTED', () async {
      // The half everyone forgets. Getting this wrong means the host refuses its own built-in bundle on
      // first launch, on every install, with nothing left to serve.
      final b = await signBundle(key, seq: 10, requiresBridge: 3);
      expect((await check(b, config: testConfig(key, bridgeVersion: 3))).seq, 10);
    });

    test('the comparison uses the configured host bridge version, not a literal', () async {
      final b = await signBundle(key, seq: 10, requiresBridge: 7);
      expect((await check(b, config: testConfig(key, bridgeVersion: 7))).seq, 10);
      await expectStop(check(b, config: testConfig(key, bridgeVersion: 6)), 5);
    });

    test('a malformed requires.data key is refused', () async {
      for (final bad in ['../etc', 'a/b', '', 'x' * 65, 'has space']) {
        final b = await signBundle(key, seq: 10, requiresData: {bad: 1});
        final e = await expectStop(check(b), 5);
        expect(e.reason, contains('bucket name'), reason: 'for key "$bad"');
      }
    });

    test('a requires.data key naming a writable bucket is refused', () async {
      // Step 7 interpolates these keys into a sync URL, so a signed manifest must not be able to name the
      // user's own writable bucket.
      final b = await signBundle(key, seq: 10, requiresData: {'shelf': 1});
      final e = await expectStop(check(b, config: testConfig(key, writableBuckets: {'shelf'})), 5);
      expect(e.reason, contains('writable'));
    });

    test('a non-positive requires.data schema is refused', () async {
      final b = await signBundle(key, seq: 10, requiresData: {'plants': 0});
      await expectStop(check(b), 5);
    });

    test('check 5 does not ask whether the device holds the pair; that is step 7', () async {
      final b = await signBundle(key, seq: 10, requiresData: {'plants': 2});
      expect((await check(b)).requiresData, {'plants': 2});
    });
  });

  group('check 6, paths, hashes and sizes', () {
    test('an unsafe path is rejected', () async {
      for (final bad in ['../secret', 'a/../b', '/etc/passwd', 'a//b', 'a/./b', r'win\path']) {
        final b = await signBundle(key, seq: 10, files: {'index.html': '<html></html>', bad: 'x'});
        final e = await expectStop(check(b), 6);
        expect(e.reason, contains('unsafe path'), reason: 'for "$bad"');
      }
    });

    test('a bundle file under the reserved _host/ prefix is refused', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': '<html></html>', '_host/evil.js': 'x'});
      final e = await expectStop(check(b), 6);
      expect(e.reason, contains('_host/'));
    });

    test('a bare _host file is refused too', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': '<html></html>', '_host': 'x'});
      await expectStop(check(b), 6);
    });

    test('a malformed hash is rejected', () async {
      final b = await signBundle(key, seq: 10, overrides: {
        'files': {'index.html': {'h': 'NOTAHASH', 'n': 5}},
      });
      await expectStop(check(b), 6);
    });

    test('an uppercase hash is rejected', () async {
      final b = await signBundle(key, seq: 10, overrides: {
        'files': {'index.html': {'h': 'A' * 64, 'n': 5}},
      });
      await expectStop(check(b), 6);
    });

    test('a negative size is rejected', () async {
      final b = await signBundle(key, seq: 10, overrides: {
        'files': {'index.html': {'h': '0' * 64, 'n': -1}},
      });
      await expectStop(check(b), 6);
    });

    test('an entry that is not in files is rejected', () async {
      final b = await signBundle(key, seq: 10, entry: 'missing.html');
      final e = await expectStop(check(b), 6);
      expect(e.reason, contains('entry'));
    });

    test('a floor above the seq is rejected', () async {
      final b = await signBundle(key, seq: 10, overrides: {'floor': 11});
      await expectStop(check(b), 6);
    });
  });

  group('manifest decoding', () {
    test('an unknown top-level field is ignored, so the format stays additive', () async {
      final b = await signBundle(key, seq: 10, overrides: {'somethingNew': {'a': 1}});
      expect((await check(b)).seq, 10);
    });

    test('urgent and routes are carried through', () async {
      final b = await signBundle(key, seq: 10, urgent: true, routes: ['/', '/shelf']);
      final m = await check(b);
      expect(m.urgent, isTrue);
      expect(m.routes, ['/', '/shelf']);
      expect(m.csp, "default-src 'self'");
    });

    test('a manifest that is not JSON stops at check 1', () async {
      await expectStop(
        checkManifest(
          bytes: Uint8List.fromList(utf8.encode('not json')),
          signature: await key.sign(utf8.encode('not json')),
          config: testConfig(key),
          state: freshState(),
          pointerSeq: 1,
        ),
        1,
      );
    });
  });

  group('the pointer is decoded strictly (§2.1)', () {
    test('a well-formed pointer decodes', () {
      expect(decodePointer('{"seq":43,"rollout":10}'), (seq: 43, rollout: 10));
      expect(decodePointer('{"seq":1,"rollout":0}'), (seq: 1, rollout: 0));
      expect(decodePointer('{"seq":1,"rollout":100}'), (seq: 1, rollout: 100));
    });

    test('anything else means no update', () {
      for (final bad in [
        '',
        'null',
        '[]',
        '"43"',
        '{"seq":0,"rollout":10}',
        '{"seq":-1,"rollout":10}',
        '{"seq":1.5,"rollout":10}',
        '{"seq":"43","rollout":10}',
        '{"seq":43}',
        '{"seq":43,"rollout":101}',
        '{"seq":43,"rollout":-1}',
        '{"seq":43,"rollout":"10"}',
        '{"rollout":10}',
      ]) {
        expect(decodePointer(bad), isNull, reason: 'for $bad');
      }
    });
  });

  group('the rollout gate is deterministic (§2.3 step 2)', () {
    test('fnv1a32 matches the values the CLI and the release console compute', () {
      // Known FNV-1a 32-bit vectors, so the host, the CLI and the release console agree on a cohort.
      expect(fnv1a32(''), 0x811c9dc5);
      expect(fnv1a32('a'), 0xe40c292c);
      expect(fnv1a32('foobar'), 0xbf9cf968);
    });

    test('the same install and seq always land in the same cohort', () {
      final first = fnv1a32('install-1:43') % 100;
      for (var i = 0; i < 5; i++) {
        expect(fnv1a32('install-1:43') % 100, first);
      }
      expect(first, inInclusiveRange(0, 99));
    });

    test('different installs spread across cohorts', () {
      final cohorts = {for (var i = 0; i < 200; i++) fnv1a32('install-$i:43') % 100};
      expect(cohorts.length, greaterThan(50), reason: 'the gate must not bucket everyone together');
    });
  });

  group('path safety helpers', () {
    test('safe paths pass', () {
      for (final p in ['index.html', 'assets/app.js', 'a/b/c.png', 'file name.txt', '_hostly/x.js']) {
        expect(isSafeBundlePath(p), isTrue, reason: p);
      }
    });

    test('unsafe paths fail', () {
      for (final p in ['', '/abs', 'a//b', 'a/./b', 'a/../b', '..', r'a\b']) {
        expect(isSafeBundlePath(p), isFalse, reason: p);
      }
    });

    test('the reserved prefix is the first segment only', () {
      expect(isReservedBundlePath('_host'), isTrue);
      expect(isReservedBundlePath('_host/a.js'), isTrue);
      expect(isReservedBundlePath('_hostly/a.js'), isFalse);
      expect(isReservedBundlePath('assets/_host/a.js'), isFalse);
    });
  });
}
