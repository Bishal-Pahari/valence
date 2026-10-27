// Contracts §2.3 (the host update algorithm) and §2.4 (the activation state machine).
//
// The invariant under test throughout: *no path promotes, re-downloads or serves a seq in `bad`.*
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  late TestKey key;
  late Directory root;
  late Directory casDir;
  late Directory manifestsDir;
  late File stateFile;
  late ValenceStore store;

  /// Garbage collection is scheduled for the first post-frame callback (§2.4), so a test drives the frame
  /// itself. Nothing here runs until [pumpFrame] is called, which is also what proves the scheduling.
  final frames = <Future<void> Function()>[];
  Future<void> pumpFrame() async {
    while (frames.isNotEmpty) {
      await frames.removeAt(0)();
    }
  }

  setUpAll(() async => key = await TestKey.create());

  setUp(() async {
    frames.clear();
    root = await Directory.systemTemp.createTemp('valence-updater');
    casDir = Directory('${root.path}/cas');
    manifestsDir = Directory('${root.path}/manifests');
    stateFile = File('${root.path}/state.json');
    store = await openTestStore();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Map<String, Object?> dataRow(String k, Object? v, int u) => {'k': k, 'v': v, 'u': u, 'd': 0};

  /// Serves an OTA host out of a set of signed bundles plus a pointer.
  MockClient otaHost({
    required Map<int, SignedBundle> bundles,
    int? pointerSeq,
    int rollout = 100,
    Map<String, String> syncBodies = const {},
    Set<String> failPaths = const {},
    List<String>? seen,
  }) =>
      MockClient((req) async {
        final path = req.url.path;
        seen?.add(req.url.toString());
        if (failPaths.any(path.endsWith)) return http.Response('gone', 404);
        if (path.endsWith('.json') && path.contains('/channels/')) {
          if (pointerSeq == null) return http.Response('no pointer', 404);
          return http.Response(jsonEncode({'seq': pointerSeq, 'rollout': rollout}), 200);
        }
        final manifestMatch = RegExp(r'/manifests/(\d+)\.json(\.sig)?$').firstMatch(path);
        if (manifestMatch != null) {
          final b = bundles[int.parse(manifestMatch.group(1)!)];
          if (b == null) return http.Response('no manifest', 404);
          return manifestMatch.group(2) == null
              ? http.Response.bytes(b.bytes, 200)
              : http.Response(b.signature, 200);
        }
        final fileMatch = RegExp(r'/files/([0-9a-f]{64})$').firstMatch(path);
        if (fileMatch != null) {
          for (final b in bundles.values) {
            final body = b.blobs[fileMatch.group(1)];
            if (body != null) return http.Response.bytes(body, 200);
          }
          return http.Response('no file', 404);
        }
        // Sync endpoints, for §2.3 step 7.
        for (final e in syncBodies.entries) {
          if (path.endsWith('/${e.key}')) return http.Response(e.value, 200);
        }
        return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
      });

  ValenceUpdater makeUpdater({
    required ValenceState state,
    http.Client? client,
    ValenceConfig? config,
    LogSpy? log,
    Map<String, Uint8List> assets = const {},
    void Function(int seq)? onUpdateReady,
  }) {
    final cfg = config ?? testConfig(key);
    return ValenceUpdater(
      config: cfg,
      state: state,
      stateFile: stateFile,
      casDir: casDir,
      manifestsDir: manifestsDir,
      store: store,
      sync: ValenceSync(store: store, config: cfg, client: client, log: (log ?? LogSpy()).call),
      readAsset: (k) async => assets[k] ?? (throw StateError('no asset $k')),
      client: client,
      log: (log ?? LogSpy()).call,
      afterFrame: frames.add,
      onUpdateReady: onUpdateReady,
    );
  }

  test('development schema context leaves pending, trial and crash evidence unchanged', () async {
    final builtin = await signBundle(key, seq: 10);
    final state = ValenceState(installId: 'i', pending: 30, trial: 20, serving: 20, trialFails: 1);
    final u = makeUpdater(state: state, assets: builtin.asAssets('assets/valence/builtin'));
    final before = jsonEncode(state.toJson());
    expect((await u.developmentManifest()).seq, 10);
    expect(jsonEncode(state.toJson()), before);
    expect(stateFile.existsSync(), isFalse);
  });

  test(
      'R17 urgency reads only the verified pending manifest without activation',
      () async {
    final state = ValenceState(installId: 'i', pending: 20);
    final u = makeUpdater(state: state);
    for (final urgent in [false, true]) {
      final bundle = await signBundle(key, seq: 20, urgent: urgent);
      bundle.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      expect(await u.pendingUrgent(20), urgent);
      expect(state.pending, 20);
      expect(state.trial, isNull);
      File('${manifestsDir.path}/20.json.sig').writeAsStringSync('invalid');
      expect(await u.pendingUrgent(20), isNull);
    }
    final valid = await signBundle(key, seq: 20, urgent: true);
    valid.writeTo(manifestsDir: manifestsDir, casDir: casDir);
    state.floor = 21;
    expect(await u.pendingUrgent(20), isNull);
    state.floor = 0;
    state.bad.add(20);
    expect(await u.pendingUrgent(20), isNull);
    state.bad.clear();
    final wrongSeq = await signBundle(key, seq: 21, urgent: true);
    File('${manifestsDir.path}/20.json').writeAsBytesSync(wrongSeq.bytes);
    File('${manifestsDir.path}/20.json.sig')
        .writeAsStringSync(wrongSeq.signature);
    expect(await u.pendingUrgent(20), isNull);
    expect(await u.pendingUrgent(21), isNull);
    state.pending = null;
    expect(await u.pendingUrgent(20), isNull);
  });

  for (final reason in ['floor', 'bad']) {
    test('development refuses $reason current and builtin without changing activation state', () async {
      final old = await signBundle(key, seq: 10);
      final newer = await signBundle(key, seq: 30);
      manifestsDir.createSync(recursive: true);
      File('${manifestsDir.path}/10.json').writeAsBytesSync(old.bytes);
      File('${manifestsDir.path}/10.json.sig').writeAsStringSync(old.signature);
      final state = ValenceState(installId: 'i', current: 10,
          floor: reason == 'floor' ? 20 : 0, bad: reason == 'bad' ? [10] : []);
      final before = jsonEncode(state.toJson());
      final refused = makeUpdater(state: state, assets: old.asAssets('assets/valence/builtin'));
      await expectLater(refused.developmentManifest(), throwsStateError);
      final fallback = makeUpdater(state: state, assets: newer.asAssets('assets/valence/builtin'));
      expect((await fallback.developmentManifest()).seq, 30);
      expect(jsonEncode(state.toJson()), before);
      expect(stateFile.existsSync(), isFalse);
    });
  }

  // ===========================================================================
  group('§2.3 step 1, the pointer', () {
    test('the compiled channel selects the beta pointer URL', () async {
      final seen = <String>[];
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        config: testConfig(key).copyWith(channel: 'beta'),
        client: otaHost(bundles: {}, seen: seen),
      );
      await u.checkForUpdate();
      expect(seen.single, 'https://ota.test/com.example.app/channels/beta.json');
    });

    test('a healthy pointer makes the bundle pending', () async {
      final b = await signBundle(key, seq: 20);
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(state: state, client: otaHost(bundles: {20: b}, pointerSeq: 20));
      expect(await u.checkForUpdate(), 20);
      expect(state.pending, 20);
      expect(File('${manifestsDir.path}/20.json').existsSync(), isTrue);
      expect(File('${manifestsDir.path}/20.json.sig').existsSync(), isTrue);
    });

    test('a pointer below pending drops pending: the team pulled that release', () async {
      final b = await signBundle(key, seq: 15);
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, client: otaHost(bundles: {15: b}, pointerSeq: 15), log: log);
      await u.checkForUpdate();
      expect(state.pending, 15, reason: 'the old pending is dropped and 15 takes its place');
      expect(log.has('is below pending 20'), isTrue);
    });

    test('a pointer at or below current stops and logs', () async {
      final state = ValenceState(installId: 'i', current: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, client: otaHost(bundles: {}, pointerSeq: 20), log: log);
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('step 1 stopped'), isTrue);
      expect(log.has('not above current'), isTrue);
    });

    test('a pointer at a seq in bad stops and logs', () async {
      final state = ValenceState(installId: 'i', current: 10, bad: [20]);
      final log = LogSpy();
      final u = makeUpdater(state: state, client: otaHost(bundles: {}, pointerSeq: 20), log: log);
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('is in bad'), isTrue);
    });

    test('a pointer at or below pending stops', () async {
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, client: otaHost(bundles: {}, pointerSeq: 20), log: log);
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('not above pending'), isTrue);
    });

    test('an update check while a seq is on trial does not re-pend it', () async {
      // Without this, the periodic check re-downloads the bundle on screen right now and sets pending to
      // it. That stale pending then resurrects a bundle the two-strike rule has already rejected.
      final state = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, client: otaHost(bundles: {}, pointerSeq: 20), log: log);
      expect(await u.checkForUpdate(), isNull);
      expect(state.pending, isNull);
      expect(log.has('not above the trial 20'), isTrue);
    });

    test('a malformed pointer means no update, and says so', () async {
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: MockClient((_) async => http.Response('{"seq":"nope"}', 200)),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('did not decode'), isTrue);
    });

    test('an unreachable pointer stops and logs rather than throwing', () async {
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: MockClient((_) => throw const SocketException('offline')),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('pointer fetch failed'), isTrue);
    });

    test('no otaBase means nothing to check', () async {
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        config: testConfig(key, otaBase: ''),
        client: MockClient((_) async => fail('must not reach the network')),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('no otaBase'), isTrue);
    });
  });

  group('§2.3 step 2, the rollout gate', () {
    test('an install outside the cohort stops and logs the cohort', () async {
      final b = await signBundle(key, seq: 20);
      // Find an install whose cohort is above 0, so a 0% rollout excludes it.
      final state = ValenceState(installId: 'i', current: 10);
      final log = LogSpy();
      final u = makeUpdater(
        state: state,
        client: otaHost(bundles: {20: b}, pointerSeq: 20, rollout: 0),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(state.pending, isNull);
      expect(log.has('step 2 stopped'), isTrue);
      expect(log.has('cohort'), isTrue);
    });

    test('a 100% rollout always lets the install through', () async {
      final b = await signBundle(key, seq: 20);
      final state = ValenceState(installId: 'whatever', current: 10);
      final u = makeUpdater(state: state, client: otaHost(bundles: {20: b}, pointerSeq: 20));
      expect(await u.checkForUpdate(), 20);
    });
  });

  group('§2.3 steps 3 and 4, the manifest and its checks', () {
    test('a missing manifest stops and logs', () async {
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: otaHost(bundles: {}, pointerSeq: 20),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('step 3 stopped'), isTrue);
    });

    test('a manifest for a different seq stops at check 3', () async {
      final b = await signBundle(key, seq: 21);
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: MockClient((req) async {
          if (req.url.path.contains('/channels/')) {
            return http.Response(jsonEncode({'seq': 20, 'rollout': 100}), 200);
          }
          if (req.url.path.endsWith('.sig')) return http.Response(b.signature, 200);
          return http.Response.bytes(b.bytes, 200);
        }),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('check 3'), isTrue);
    });

    test('a bundle below the floor stops at check 4', () async {
      final b = await signBundle(key, seq: 20);
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i', floor: 30),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('check 4'), isTrue);
    });

    test('a missing signature file stops and logs', () async {
      final b = await signBundle(key, seq: 20);
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: otaHost(bundles: {20: b}, pointerSeq: 20, failPaths: {'.json.sig'}),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('signature returned HTTP 404'), isTrue);
    });
  });

  group('§2.3 step 5, the size cap', () {
    test('a bundle over the cap stops and names the size', () async {
      final b = await signBundle(key, seq: 20, files: {'index.html': 'x' * 5000});
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        config: testConfig(key, bundleSizeCap: 1000),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('step 5 stopped'), isTrue);
      expect(log.has('over the 1000 byte cap'), isTrue);
    });

    test('files already in CAS do not count towards the cap', () async {
      final b = await signBundle(key, seq: 20, files: {'index.html': 'x' * 5000});
      casDir.createSync(recursive: true);
      for (final e in b.blobs.entries) {
        File('${casDir.path}/${e.key}').writeAsBytesSync(e.value);
      }
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        config: testConfig(key, bundleSizeCap: 1000),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), 20);
    });
  });

  group('§2.3 step 6 and check 7, downloads', () {
    test('each file is hashed and sized before it gets its content-addressed name', () async {
      final b = await signBundle(key, seq: 20, files: {
        'index.html': '<html><head></head></html>',
        'app.js': 'console.log(1)',
      });
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), 20);
      for (final e in b.blobs.entries) {
        final f = File('${casDir.path}/${e.key}');
        expect(f.existsSync(), isTrue);
        expect(sha256.convert(f.readAsBytesSync()).toString(), e.key);
      }
      expect(
        casDir.listSync().where((f) => f.uri.pathSegments.last.startsWith('tmp-')),
        isEmpty,
        reason: 'nothing is left behind under a temporary name',
      );
    });

    test('a file whose bytes do not match its hash stops the update (check 7)', () async {
      final b = await signBundle(key, seq: 20);
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: MockClient((req) async {
          if (req.url.path.contains('/channels/')) {
            return http.Response(jsonEncode({'seq': 20, 'rollout': 100}), 200);
          }
          if (req.url.path.endsWith('.sig')) return http.Response(b.signature, 200);
          if (req.url.path.contains('/manifests/')) return http.Response.bytes(b.bytes, 200);
          // The CDN serves the right length but the wrong bytes.
          final want = b.blobs.values.first.length;
          return http.Response('y' * want, 200);
        }),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('hashes to'), isTrue);
      expect(File('${manifestsDir.path}/20.json').existsSync(), isFalse);
    });

    test('a file of the wrong size stops the update', () async {
      final b = await signBundle(key, seq: 20);
      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        client: MockClient((req) async {
          if (req.url.path.contains('/channels/')) {
            return http.Response(jsonEncode({'seq': 20, 'rollout': 100}), 200);
          }
          if (req.url.path.endsWith('.sig')) return http.Response(b.signature, 200);
          if (req.url.path.contains('/manifests/')) return http.Response.bytes(b.bytes, 200);
          return http.Response('short', 200);
        }),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('manifest says'), isTrue);
    });
  });

  group('§2.3 step 7, the data requirements are PULLED', () {
    SignedBundle? bundle;

    setUp(() async => bundle = await signBundle(key, seq: 20, requiresData: {'plants': 2}));

    test('a bundle requiring a pair the device lacks becomes pending only after step 7 pulls it', () async {
      // Ordinary sync follows the *active* bundle, which during a bump is the old schema, so this pull is
      // the only route the new pair has onto the device.
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        config: testConfig(key, dataSchemas: {'plants': 1}),
        client: otaHost(
          bundles: {20: bundle!},
          pointerSeq: 20,
          syncBodies: {
            'plants': jsonEncode({'rows': [dataRow('fern', {'v': 2}, 1)], 'max': 1, 'more': false}),
          },
        ),
        log: log,
      );
      expect(await u.checkForUpdate(), 20);
      expect(state.pending, 20);
      expect(await store.syncedPairs(), {'plants': {2}});
      expect(log.has('step 7 pulled 1 rows for plants v2'), isTrue);
    });

    test('an offline device never takes the bump, and logs which pair it waits for', () async {
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        client: MockClient((req) async {
          if (req.url.path.contains('/channels/')) {
            return http.Response(jsonEncode({'seq': 20, 'rollout': 100}), 200);
          }
          if (req.url.path.endsWith('.sig')) return http.Response(bundle!.signature, 200);
          if (req.url.path.contains('/manifests/')) return http.Response.bytes(bundle!.bytes, 200);
          if (req.url.path.contains('/files/')) {
            return http.Response.bytes(bundle!.blobs.values.first, 200);
          }
          throw const SocketException('airplane mode');
        }),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(state.pending, isNull, reason: 'the bundle is not pending until its data is there');
      expect(log.has('step 7 stopped'), isTrue);
      expect(log.has('plants v2'), isTrue);
    });

    test('a server with nothing at the new schema leaves the bundle parked, and says so', () async {
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        client: otaHost(bundles: {20: bundle!}, pointerSeq: 20, failPaths: {'/plants'}),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(state.pending, isNull);
      expect(log.has('still waiting for plants v2'), isTrue);
    });

    test('step 7 takes the sync lease, and stopping for it is not a failure', () async {
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final cfg = testConfig(key);
      // Somebody else is already syncing, very likely fired by the same trigger.
      await ValenceSync(store: store, config: cfg, log: log.call).acquireLease();
      final u = makeUpdater(
        state: state,
        client: otaHost(bundles: {20: bundle!}, pointerSeq: 20),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(state.pending, isNull);
      expect(log.has('another sync holds the lease'), isTrue);
      expect(log.has('the next check retries'), isTrue);
      expect(state.bad, isEmpty, reason: 'it must not count as a failure');
    });

    test('step 7 releases the lease when it finishes', () async {
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        client: otaHost(
          bundles: {20: bundle!},
          pointerSeq: 20,
          syncBodies: {
            'plants': jsonEncode({'rows': [dataRow('fern', 1, 1)], 'max': 1, 'more': false}),
          },
        ),
      );
      expect(await u.checkForUpdate(), 20);
      expect(await store.hostPrefGet('valence.sync.lease'), isNull);
    });

    test('a pair the device already holds needs no pull at all', () async {
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [dataRow('a', 1, 1)], maxUsnAfter: 1);
      final seen = <String>[];
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        client: otaHost(bundles: {20: bundle!}, pointerSeq: 20, seen: seen),
      );
      expect(await u.checkForUpdate(), 20);
      expect(seen.where((s) => s.contains('sync.test')), isEmpty);
    });

    test('a device holding v1 AND v2 satisfies a requirement for either', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [dataRow('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [dataRow('a', 2, 1)], maxUsnAfter: 1);
      for (final schema in [1, 2]) {
        final b = await signBundle(key, seq: 20 + schema, requiresData: {'plants': schema});
        final state = ValenceState(installId: 'i', current: 10);
        final u = makeUpdater(
          state: state,
          client: otaHost(bundles: {20 + schema: b}, pointerSeq: 20 + schema),
        );
        expect(await u.checkForUpdate(), 20 + schema, reason: 'requiring plants v$schema');
      }
    });

    test('a seeded pair alone does not satisfy step 7', () async {
      // §5.2: synced_at stays null after a seed import, because the gate is about the *server* having
      // rows at that schema.
      await store.db.insert('bucket', {'name': 'plants', 'schema': 2, 'max_usn': 9, 'synced_at': null});
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        client: otaHost(bundles: {20: bundle!}, pointerSeq: 20, failPaths: {'/plants'}),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(log.has('still waiting for plants v2'), isTrue);
    });

    test('the step 7 pull resumes from the pair’s own max_usn, not from 0', () async {
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [dataRow('a', 1, 40)], maxUsnAfter: 40);
      // Applied but, say, interrupted before the host considered it done: synced_at is set here, so make
      // a fresh pair that has rows but has not completed.
      await store.db.update('bucket', {'synced_at': null}, where: 'name = ?', whereArgs: ['plants']);
      final seen = <String>[];
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        client: otaHost(
          bundles: {20: bundle!},
          pointerSeq: 20,
          seen: seen,
          syncBodies: {
            'plants': jsonEncode({'rows': [], 'max': 40, 'more': false}),
          },
        ),
      );
      await u.checkForUpdate();
      final pull = seen.firstWhere((s) => s.contains('sync.test'));
      expect(pull, contains('since=40'));
      expect(pull, isNot(contains('since=0')));
    });

    test('step 7 is budgeted, and the stop names the cap', () async {
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        config: testConfig(key, dataSizeCap: 50),
        client: otaHost(
          bundles: {20: bundle!},
          pointerSeq: 20,
          syncBodies: {
            'plants': jsonEncode({
              'rows': [dataRow('a', 'x' * 400, 1)],
              'max': 1,
              'more': true,
            }),
          },
        ),
        log: log,
      );
      await u.checkForUpdate();
      expect(log.has('byte budget'), isTrue);
      // The cap stopped it *inside* the pull, which is the same reason as a cap that stops it before one:
      // the app's own limit, not unavailable data. §4.6 calls that `toobig`, and reporting
      // `waitingForData` sends the developer to inspect a server that answered correctly.
      expect(u.lastReason, ValenceBundleReason.toobig);
      expect(log.has('data cap'), isTrue);
    });

    test('a cap spent by the first pair stops the second one as toobig too', () async {
      // The other half of the §4.6 claim. Here the budget is gone *before* `pullPair` is called for the
      // second pair, rather than during the first one's pull, and the reason must be the same: it is the
      // app's own cap either way. This is also the path a real multi-pair bump takes.
      final log = LogSpy();
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 2, 'seeds': 1});
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        config: testConfig(key, dataSizeCap: 300),
        client: otaHost(
          bundles: {20: b},
          pointerSeq: 20,
          syncBodies: {
            // Completes — `more: false` returns before the budget check — and spends the whole cap.
            'plants': jsonEncode({'rows': [dataRow('a', 'x' * 400, 1)], 'max': 1, 'more': false}),
            'seeds': jsonEncode({'rows': [dataRow('b', 'y', 1)], 'max': 1, 'more': false}),
          },
        ),
        log: log,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.toobig);
      expect(log.has('before'), isTrue, reason: 'the stop names the pair it never started');
    });

    test('a bundle with no requires.data skips step 7 entirely', () async {
      final b = await signBundle(key, seq: 20);
      final seen = <String>[];
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20, seen: seen),
      );
      expect(await u.checkForUpdate(), 20);
      expect(seen.where((s) => s.contains('sync.test')), isEmpty);
    });
  });

  group('§2.3 step 8, pending', () {
    test('updateReady observes the completed status for its pending bundle', () async {
      final b = await signBundle(key, seq: 20);
      var notifications = 0;
      late final ValenceUpdater u;
      u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        onUpdateReady: (seq) {
          notifications++;
          expect(seq, 20);
          expect(u.state.pending, 20);
          expect(u.lastReason, ValenceBundleReason.ready);
          expect(u.lastOffered, 20);
          expect(u.lastCheckedAt, isNotNull);
        },
      );
      expect(await u.checkForUpdate(), 20);
      expect(notifications, 1);
    });

    test('an urgent bundle calls back so the host can emit bundle.updateReady', () async {
      final b = await signBundle(key, seq: 20, urgent: true);
      final notified = <int>[];
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        onUpdateReady: notified.add,
      );
      expect(await u.checkForUpdate(), 20);
      expect(notified, [20]);
    });

    test('a non-urgent bundle calls back too, because applyUpdate never needed urgent', () async {
      // `bundle.updateReady` is the only push signal that pairs with `bundle.status`, and `applyUpdate`
      // promotes any pending bundle. Gating the event on `urgent` left a page polling on resume, which
      // races this transition: the update is found 400 ms after the read and reported a resume late.
      final b = await signBundle(key, seq: 20);
      final notified = <int>[];
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        onUpdateReady: notified.add,
      );
      expect(await u.checkForUpdate(), 20);
      expect(notified, [20]);
    });

    test('a check that never reaches pending stays silent', () async {
      // The event means "there is a verified bundle waiting", so a stop before step 8 must not fire it.
      final b = await signBundle(key, seq: 20);
      final notified = <int>[];
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10, bad: [20]),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        onUpdateReady: notified.add,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(notified, isEmpty);
    });

    test('the manifest bytes written to disk are the exact signed bytes', () async {
      final b = await signBundle(key, seq: 20);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
      );
      await u.checkForUpdate();
      expect(File('${manifestsDir.path}/20.json').readAsBytesSync(), b.bytes);
      expect(File('${manifestsDir.path}/20.json.sig').readAsStringSync(), b.signature);
    });
  });

  // ===========================================================================
  group('§2.4 the activation state machine', () {
    /// Puts a verified bundle on disk so the state machine can serve it.
    Future<void> onDisk(SignedBundle b) async => b.writeTo(manifestsDir: manifestsDir, casDir: casDir);

    test('a pending bundle is promoted to a trial and served', () async {
      final b = await signBundle(key, seq: 20);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final u = makeUpdater(state: state);
      final served = await u.activateForUiStart();
      expect(served.seq, 20);
      expect(state.trial, 20);
      expect(state.pending, isNull);
      expect(state.trialFails, 0);
      expect(state.serving, 20);
    });

    test('a trial then app.ready commits it and raises the floor', () async {
      final b = await signBundle(key, seq: 20, floor: 18);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, pending: 20, floor: 5);
      final u = makeUpdater(state: state);
      final served = await u.activateForUiStart();
      await u.commitTrial(served);
      expect(state.current, 20);
      expect(state.previous, 10);
      expect(state.trial, isNull);
      expect(state.trialFails, 0);
      expect(state.serving, isNull);
      expect(state.floor, 18);
    });

    test('the floor never goes down', () async {
      final b = await signBundle(key, seq: 20, floor: 2);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, pending: 20, floor: 15);
      final u = makeUpdater(state: state);
      await u.commitTrial(await u.activateForUiStart());
      expect(state.floor, 15);
    });

    test('a commit clears a pending holding the committed seq', () async {
      final b = await signBundle(key, seq: 20);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20, pending: 20);
      final u = makeUpdater(state: state);
      final m = await u.activateForUiStart();
      // The crash check spends a strike here, so re-establish the trial as if ready had arrived in time.
      state
        ..trial = 20
        ..serving = 20
        ..pending = 20
        ..trialFails = 0;
      await u.commitTrial(m);
      expect(state.pending, isNull, reason: 'otherwise the next UI start re-trials the live bundle');
    });

    test('a commit also clears a pending below the committed seq', () async {
      final b = await signBundle(key, seq: 20);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20, pending: 15);
      final u = makeUpdater(state: state);
      await u.commitTrial(
        await checkManifest(
          bytes: b.bytes,
          signature: b.signature,
          config: testConfig(key),
          state: state,
          pointerSeq: null,
        ),
      );
      expect(state.pending, isNull);
    });

    test('a crash while serving == trial counts exactly one failure', () async {
      final b = await signBundle(key, seq: 20);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20);
      final u = makeUpdater(state: state);
      await u.activateForUiStart();
      expect(state.trialFails, 1);
      expect(state.trial, 20, reason: 'one failure can be a user who opened and closed the app at once');
      expect(state.bad, isEmpty);
    });

    test('a UI start with no trial counts no failure and adds nothing to bad', () async {
      // Both serving and trial are null, so a bare `serving == trial` would be satisfied on every launch,
      // count a failure each time, and mark whatever is being served bad.
      final b = await signBundle(key, seq: 10);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(state: state);
      for (var i = 0; i < 5; i++) {
        await u.activateForUiStart();
      }
      expect(state.trialFails, 0);
      expect(state.bad, isEmpty);
      expect(state.current, 10);
    });

    test('a ready timeout with no trial counts no failure', () async {
      final state = ValenceState(installId: 'i', current: 10);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      u.countFailure();
      expect(state.trialFails, 0);
      expect(state.bad, isEmpty);
      expect(log.has('nothing to count'), isTrue);
    });

    test('fails once, is retried at the next UI start, fails again, is marked bad', () async {
      final current = await signBundle(key, seq: 10);
      final trial = await signBundle(key, seq: 20);
      await onDisk(current);
      await onDisk(trial);
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final u = makeUpdater(state: state);

      // Launch 1: promote and serve the trial.
      expect((await u.activateForUiStart()).seq, 20);
      expect(state.serving, 20);
      // It never calls ready; the process dies.

      // Launch 2: one failure counted, and the trial gets one more go.
      expect((await u.activateForUiStart()).seq, 20);
      expect(state.trialFails, 1);
      expect(state.trial, 20);

      // Launch 3: the second strike marks it bad and current is served.
      final served = await u.activateForUiStart();
      expect(state.bad, contains(20));
      expect(state.trial, isNull);
      expect(state.trialFails, 0);
      expect(served.seq, 10, reason: 'the UI start after two strikes serves current, not the bad bundle');

      // Launch 4: still current. The bad bundle does not come back.
      expect((await u.activateForUiStart()).seq, 10);
      expect(state.bad, contains(20));
    });

    test('marking a trial bad drops a pending holding the same seq', () async {
      // This is the loop: bad -> pending survives -> promoted -> trialFails reset -> bad again, for ever.
      final state = ValenceState(installId: 'i', current: 10, trial: 20, trialFails: 1, pending: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      u.countFailure();
      expect(state.bad, contains(20));
      expect(state.pending, isNull);
      expect(log.has('marking it bad'), isTrue);
    });

    test('step 3 never promotes a pending that is in bad', () async {
      final current = await signBundle(key, seq: 10);
      final bad = await signBundle(key, seq: 20);
      await onDisk(current);
      await onDisk(bad);
      final state = ValenceState(installId: 'i', current: 10, pending: 20, bad: [20]);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      expect((await u.activateForUiStart()).seq, 10);
      expect(state.trial, isNull);
      expect(state.pending, isNull);
      expect(log.has('which is in bad'), isTrue);
    });

    test('a pending at or below current is dropped rather than promoted', () async {
      final current = await signBundle(key, seq: 20);
      await onDisk(current);
      final state = ValenceState(installId: 'i', current: 20, pending: 15);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      expect((await u.activateForUiStart()).seq, 20);
      expect(state.pending, isNull);
      expect(state.trial, isNull);
      expect(log.has('not above current'), isTrue);
    });

    test('a pending below the floor is dropped rather than promoted', () async {
      final current = await signBundle(key, seq: 10);
      final low = await signBundle(key, seq: 20);
      await onDisk(current);
      await onDisk(low);
      final state = ValenceState(installId: 'i', current: 10, pending: 20, floor: 25);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      expect((await u.activateForUiStart()).seq, 10);
      expect(state.pending, isNull);
      expect(log.has('below the floor'), isTrue);
    });

    test('entries below the floor are pruned from bad at commit', () async {
      final b = await signBundle(key, seq: 30, floor: 25);
      await onDisk(b);
      final state = ValenceState(installId: 'i', current: 10, trial: 30, serving: 30, bad: [5, 12, 28]);
      final u = makeUpdater(state: state);
      await u.commitTrial(
        await checkManifest(
          bytes: b.bytes,
          signature: b.signature,
          config: testConfig(key),
          state: ValenceState(installId: 'i'),
          pointerSeq: null,
        ),
      );
      expect(state.floor, 25);
      expect(state.bad, [28], reason: 'check 4 already refuses anything below the floor');
    });

    test('a trial whose manifest vanished is counted as a failure, not a crash', () async {
      final current = await signBundle(key, seq: 10);
      await onDisk(current);
      final state = ValenceState(installId: 'i', current: 10, trial: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      expect((await u.activateForUiStart()).seq, 10);
      expect(log.has('has no manifest on disk'), isTrue);
    });

    test('a manifest on disk is re-verified, not trusted', () async {
      final b = await signBundle(key, seq: 20);
      await onDisk(b);
      // Someone edits the file in app storage after it was downloaded.
      final f = File('${manifestsDir.path}/20.json');
      f.writeAsStringSync(utf8.decode(b.bytes).replaceFirst('"seq": 20', '"seq": 21'));
      final current = await signBundle(key, seq: 10);
      await onDisk(current);
      final state = ValenceState(installId: 'i', current: 10, trial: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      expect((await u.activateForUiStart()).seq, 10);
      expect(log.has('failed re-verification'), isTrue);
    });
  });

  group('§2.4 step 1, a newer built-in bundle wins', () {
    test('it installs into CAS, becomes current, and drops older pending and trial', () async {
      final builtin = await signBundle(key, seq: 50, files: {'index.html': '<html><head></head>new</html>'});
      final old = await signBundle(key, seq: 30);
      old.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 20, pending: 30, trial: 25, serving: 25);
      final log = LogSpy();
      final u = makeUpdater(
        state: state,
        assets: builtin.asAssets('assets/valence/builtin'),
        log: log,
      );
      final served = await u.activateForUiStart();
      expect(served.seq, 50);
      expect(state.current, 50);
      expect(state.previous, 20);
      expect(state.pending, isNull);
      expect(state.trial, isNull);
      expect(state.serving, isNull);
      for (final hash in builtin.blobs.keys) {
        expect(File('${casDir.path}/$hash').existsSync(), isTrue);
      }
    });

    test('a built-in seq in bad is cleared, because a store install is the replacement', () async {
      final builtin = await signBundle(key, seq: 50);
      final state = ValenceState(installId: 'i', current: 20, bad: [50]);
      final log = LogSpy();
      final u = makeUpdater(state: state, assets: builtin.asAssets('assets/valence/builtin'), log: log);
      expect((await u.activateForUiStart()).seq, 50);
      expect(state.bad, isNot(contains(50)));
      expect(log.has('a store install clears that'), isTrue);
    });

    test('a built-in bundle at or below current is a no-op on every later launch', () async {
      final builtin = await signBundle(key, seq: 50);
      final state = ValenceState(installId: 'i');
      final u = makeUpdater(state: state, assets: builtin.asAssets('assets/valence/builtin'));
      expect((await u.activateForUiStart()).seq, 50);
      expect(state.current, 50);
      final previousAfterFirst = state.previous;
      await u.activateForUiStart();
      expect(state.current, 50);
      expect(state.previous, previousAfterFirst, reason: 'step 1 did not run again');
    });

    test('a built-in asset whose bytes do not match its hash is refused', () async {
      final builtin = await signBundle(key, seq: 50);
      final assets = {...builtin.asAssets('assets/valence/builtin')};
      final hash = builtin.blobs.keys.first;
      assets['assets/valence/builtin/files/$hash'] = Uint8List.fromList(utf8.encode('repacked'));
      final log = LogSpy();
      final u = makeUpdater(state: ValenceState(installId: 'i'), assets: assets, log: log);
      await expectLater(u.activateForUiStart(), throwsA(isA<StateError>()));
      expect(log.has('failed its hash or size'), isTrue);
    });

    test('with no built-in bundle and no current, starting is a clear error', () async {
      final log = LogSpy();
      final u = makeUpdater(state: ValenceState(installId: 'i'), log: log);
      await expectLater(
        u.activateForUiStart(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('valence bundle --builtin'))),
      );
    });

    test('the built-in manifest is written into manifests/, so later launches load it uniformly', () async {
      final builtin = await signBundle(key, seq: 50);
      final u = makeUpdater(
        state: ValenceState(installId: 'i'),
        assets: builtin.asAssets('assets/valence/builtin'),
      );
      await u.activateForUiStart();
      expect(File('${manifestsDir.path}/50.json').existsSync(), isTrue);
      expect(File('${manifestsDir.path}/50.json.sig').existsSync(), isTrue);
    });
  });

  group('bundle.applyUpdate (§2.4)', () {
    test('it is a full trial promotion', () async {
      final b = await signBundle(key, seq: 20);
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final u = makeUpdater(state: state);
      expect(await u.applyUpdate(), 20);
      expect(state.trial, 20);
      expect(state.serving, 20);
      expect(state.pending, isNull);
      expect(state.trialFails, 0);
    });

    test('with no pending it is a no-op', () async {
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(state: state);
      expect(await u.applyUpdate(), isNull);
      expect(state.trial, isNull);
    });

    test('a pending in bad is dropped, not promoted', () async {
      final state = ValenceState(installId: 'i', current: 10, pending: 20, bad: [20]);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);
      expect(await u.applyUpdate(), isNull);
      expect(state.pending, isNull);
      expect(state.trial, isNull);
      expect(log.has('which is in bad'), isTrue);
    });

    test('it inherits step 3’s current and floor tests, so it cannot skip a check', () async {
      for (final state in [
        ValenceState(installId: 'i', current: 25, pending: 20),
        ValenceState(installId: 'i', current: 10, pending: 20, floor: 30),
      ]) {
        final u = makeUpdater(state: state);
        expect(await u.applyUpdate(), isNull);
        expect(state.trial, isNull);
        expect(state.pending, isNull);
      }
    });

    test('a white-screening urgent bundle costs two strikes and reverts like any other', () async {
      final current = await signBundle(key, seq: 10);
      final urgent = await signBundle(key, seq: 20, urgent: true);
      current.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      urgent.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final u = makeUpdater(state: state);
      expect(await u.applyUpdate(), 20);
      u.countFailure();
      expect(state.trialFails, 1);
      u.countFailure();
      expect(state.bad, contains(20));
      expect((await u.activateForUiStart()).seq, 10);
    });

    test('a built-in bundle that fails its checks is refused, recorded, and not retried', () async {
      // The expensive mistake: a store build whose requires.bridge is above the version the host reports.
      final broken = await signBundle(key, seq: 50, requiresBridge: 9);
      final log = LogSpy();
      final state = ValenceState(installId: 'i', current: 10);
      final previous = await signBundle(key, seq: 10);
      previous.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final u = makeUpdater(state: state, log: log, assets: broken.asAssets('assets/valence/builtin'));

      expect((await u.activateForUiStart()).seq, 10, reason: 'nothing is promoted, and current is served');
      expect(state.current, 10);
      // A fingerprint of the manifest bytes and the host's bridge version, not the seq: the usual cause of
      // a refusal is fixed by a Dart change that ships the same assets, and so the same seq.
      expect(state.builtinRefused, startsWith('50.1.'));
      expect(state.bad, isEmpty, reason: 'a built-in bundle is never a release this install can decline');
      expect(log.has('failed verification'), isTrue);

      // The refusal is recorded, so the next launch does not pay for the verify again — and says so once.
      final second = LogSpy();
      final again = makeUpdater(state: state, log: second, assets: broken.asAssets('assets/valence/builtin'));
      expect((await again.activateForUiStart()).seq, 10);
      expect(second.has('skipping step 1'), isTrue);
      expect(second.has('failed verification'), isFalse, reason: 'the signature is not re-verified');

      // A store update with a different seq clears the record and gets a fresh chance.
      final fixed = await signBundle(key, seq: 51);
      final third = makeUpdater(state: state, assets: fixed.asAssets('assets/valence/builtin'));
      expect((await third.activateForUiStart()).seq, 51);
      expect(state.builtinRefused, isNull);
      expect(state.current, 51);
    });

    test('a refused built-in bundle with no current says so natively, naming the check', () async {
      // A fresh install of a broken store build. There is no bundle left to render an error in, so a blank
      // WebView is both undebuggable and the worst possible shape for a guideline 4.2.3(ii) review.
      final broken = await signBundle(key, seq: 50, requiresBridge: 9);
      final state = ValenceState(installId: 'i');
      final u = makeUpdater(state: state, assets: broken.asAssets('assets/valence/builtin'));
      await expectLater(
        u.activateForUiStart(),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('check 5'))
              .having((e) => e.message, 'message', contains('no bundle to serve')),
        ),
      );
      expect(state.builtinRefused, startsWith('50.1.'));
      expect(state.current, isNull);
    });
  });

  group('garbage collection (§2.4)', () {
    test('it keeps current, previous, pending, trial and the built-in bundle', () async {
      final builtin = await signBundle(key, seq: 1, files: {'index.html': '<html><head></head>b</html>'});
      final kept = <SignedBundle>[];
      for (final seq in [10, 20, 30, 40]) {
        final b = await signBundle(key, seq: seq, files: {'index.html': '<html><head></head>$seq</html>'});
        b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
        kept.add(b);
      }
      final dropped = await signBundle(key, seq: 5, files: {'index.html': '<html><head></head>5</html>'});
      dropped.writeTo(manifestsDir: manifestsDir, casDir: casDir);

      final state = ValenceState(installId: 'i', current: 20, previous: 10, pending: 40, trial: 30);
      final u = makeUpdater(state: state, assets: builtin.asAssets('assets/valence/builtin'));
      await u.garbageCollect();

      for (final seq in [10, 20, 30, 40]) {
        expect(File('${manifestsDir.path}/$seq.json').existsSync(), isTrue, reason: 'kept $seq');
      }
      expect(File('${manifestsDir.path}/5.json').existsSync(), isFalse);
      expect(File('${manifestsDir.path}/5.json.sig').existsSync(), isFalse);
      for (final b in kept) {
        for (final hash in b.blobs.keys) {
          expect(File('${casDir.path}/$hash').existsSync(), isTrue);
        }
      }
      for (final hash in dropped.blobs.keys) {
        expect(File('${casDir.path}/$hash').existsSync(), isFalse);
      }
    });

    test('a CAS file still referenced by a kept manifest is not deleted', () async {
      // Two bundles sharing an unchanged asset: dropping one must not take the shared file with it.
      final shared = {'index.html': '<html><head></head>x</html>', 'logo.png': 'PNGBYTES'};
      final keptBundle = await signBundle(key, seq: 20, files: shared);
      final droppedBundle = await signBundle(key, seq: 5, files: shared);
      keptBundle.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      droppedBundle.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final u = makeUpdater(state: ValenceState(installId: 'i', current: 20));
      await u.garbageCollect();
      for (final hash in keptBundle.blobs.keys) {
        expect(File('${casDir.path}/$hash').existsSync(), isTrue);
      }
    });

    test('it drops read-only pairs no kept manifest requires', () async {
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [dataRow('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [dataRow('a', 2, 1)], maxUsnAfter: 1);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 20),
        config: testConfig(key, dataSchemas: {'plants': 2}),
      );
      await u.garbageCollect();
      expect(await store.allPairs(), {'plants': {2}});
    });

    test('GC after a commit leaves writable buckets untouched', () async {
      // No manifest ever lists a writable bucket in requires.data, so a rule phrased as "delete every
      // pair no manifest requires" destroys all of the user's own data on the first commit after an OTA.
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 1}, floor: 0);
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [dataRow('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'shelf', schema: 1, rows: [], maxUsnAfter: 0);
      await store.put('shelf', 'mine', {'precious': true}, opId: 'op-1');
      await store.applyPushAck(bucket: 'shelf', acked: ['op-1'], rows: [dataRow('mine', {'precious': true}, 7)]);

      final state = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20);
      final u = makeUpdater(
        state: state,
        config: testConfig(key, dataSchemas: {'plants': 1}, writableBuckets: {'shelf'}),
      );
      await u.commitTrial(
        await checkManifest(
          bytes: b.bytes,
          signature: b.signature,
          config: testConfig(key, dataSchemas: {'plants': 1}, writableBuckets: {'shelf'}),
          state: ValenceState(installId: 'i'),
          pointerSeq: null,
        ),
      );
      // The collection is scheduled now, so the frame has to be driven before it has done anything.
      await pumpFrame();
      expect(await store.get('shelf', 1, 'mine'), {'precious': true});
      expect((await store.allPairs())['shelf'], {1});
    });

    test('it is scheduled, not run inside the transition that changed the kept set', () async {
      // Step 1 already pays for a manifest decode, a signature verify and a hash of every file it installs
      // in front of the first frame. A directory walk and a SQLite transaction on top of that is exactly
      // the launch that must not get slower, so the collection waits for the first post-frame callback.
      final builtin = await signBundle(key, seq: 50, files: {'index.html': '<html><head></head>b</html>'});
      // Two behind current, because a supersede sets previous = current and so only collects one back.
      final stale = await signBundle(key, seq: 3, files: {'index.html': '<html><head></head>3</html>'});
      stale.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      (await signBundle(key, seq: 5)).writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 5, previous: 3);
      final u = makeUpdater(state: state, assets: builtin.asAssets('assets/valence/builtin'));

      await u.activateForUiStart();
      expect(state.current, 50, reason: 'the supersede happened');
      expect(frames, hasLength(1), reason: 'and scheduled a collection');
      final staleManifest = File('${manifestsDir.path}/3.json');
      expect(staleManifest.existsSync(), isTrue, reason: 'nothing has been collected yet');
      await pumpFrame();
      expect(staleManifest.existsSync(), isFalse);
    });

    test('a two-strike marking and a commit both schedule a collection', () async {
      final b = await signBundle(key, seq: 20);
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final marking = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20, trialFails: 1);
      // The WebView is still showing the trial page, whose chunks and fonts are CAS files this marking has
      // just made collectable. Deleting them under a live page produces a filesystem error where §2.4's
      // delete-and-500 path should be, and that path cannot recover a seq which is now in bad.
      makeUpdater(state: marking).countFailure();
      expect(marking.bad, [20]);
      expect(frames, hasLength(1));

      frames.clear();
      final committing = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20);
      await makeUpdater(state: committing).commitTrial(
        await checkManifest(
          bytes: b.bytes,
          signature: b.signature,
          config: testConfig(key),
          state: ValenceState(installId: 'i'),
          pointerSeq: null,
        ),
      );
      expect(committing.current, 20);
      expect(frames, hasLength(1));
    });

    test('the pair step is skipped while another sync holds the lease', () async {
      // §2.3 step 7 pulls a required pair while holding the lease, and that bundle's manifest is not on
      // disk until step 8 — so a collection that runs mid-pull would delete a pair the pending bundle
      // needs, and nothing re-pulls it. Manifests and CAS files have no such hazard.
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final stale = await signBundle(key, seq: 5);
      stale.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [dataRow('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [dataRow('a', 2, 1)], maxUsnAfter: 1);
      final cfg = testConfig(key, dataSchemas: {'plants': 2});
      final held = ValenceSync(store: store, config: cfg);
      expect(await held.acquireLease(), isTrue);

      final log = LogSpy();
      final u = makeUpdater(state: ValenceState(installId: 'i', current: 20), config: cfg, log: log);
      await u.garbageCollect();
      expect(log.has('another sync holds the lease'), isTrue);
      expect(await store.allPairs(), {'plants': {1, 2}}, reason: 'no pair was dropped');
      expect(File('${manifestsDir.path}/5.json').existsSync(), isFalse, reason: 'manifests still collected');

      await held.releaseLease();
      await u.garbageCollect();
      expect(await store.allPairs(), {'plants': {2}});
    });
  });


  group('a mid-session reload does not re-run the UI-start transitions (§2.4)', () {
    test('serveAfterApplyUpdate shows the promoted bundle without spending a strike', () async {
      // applyUpdate sets trial and serving, so going back through activateForUiStart would make step 2's
      // crash check true by construction and count a failure against the bundle it is about to show. Two
      // of those and a healthy release is in `bad`, which is final.
      final b = await signBundle(key, seq: 20);
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 10, pending: 20);
      final log = LogSpy();
      final u = makeUpdater(state: state, log: log);

      expect(await u.applyUpdate(), 20);
      expect(state.trial, 20);
      expect(state.serving, 20);

      final served = await u.serveAfterApplyUpdate();
      expect(served.seq, 20, reason: 'the promoted bundle is what gets served');
      expect(state.trialFails, 0, reason: 'no strike for the bundle we just promoted');
      expect(state.bad, isEmpty);
      expect(log.has('did not confirm it'), isFalse, reason: 'the crash check must not run here');
    });

    test('serveCurrent after a timeout goes back to current and keeps the trial for the next launch', () async {
      // §2.4: "on timeout, count a failure, then reload `current` right away". Re-entering
      // activateForUiStart takes step 4's trial branch instead, shows the failing bundle again 15 s later,
      // and spends in this session the retry the spec grants to the next UI start.
      final current = await signBundle(key, seq: 10);
      final trial = await signBundle(key, seq: 20);
      current.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      trial.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 10, trial: 20, serving: 20);
      final u = makeUpdater(state: state);

      u.countFailure();
      expect(state.trialFails, 1);
      final served = await u.serveCurrent();
      expect(served.seq, 10, reason: 'the user goes back to the last good bundle immediately');
      expect(state.trial, 20, reason: 'the trial survives, for one more try at the next UI start');
      expect(state.serving, isNull, reason: 'nothing is on probation while current is on screen');

      // And that next UI start is the one that tries it again.
      expect((await u.activateForUiStart()).seq, 20);
      expect(state.serving, 20);
      expect(state.trialFails, 1, reason: 'still one, so there is a second chance left');
    });
  });

  group('a collection never takes the files of a download in flight (§2.4)', () {
    test('a GC that runs during step 7 leaves the pending bundle complete', () async {
      // Step 6 renames files into CAS before step 8 writes the manifest, and step 7 sits between them and
      // can take minutes. A collection in that window computes its kept set from live state, cannot see
      // the seq being downloaded, and deletes what step 6 just fetched. §2.3 step 1 then stops for ever on
      // `pointer.seq <= pending`, the trial 404s, and two strikes put a healthy release in `bad`.
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 1});
      final old = await signBundle(key, seq: 5, files: {'index.html': '<html><head></head>5</html>'});
      old.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 10);
      final u = makeUpdater(
        state: state,
        config: testConfig(key, dataSchemas: {'plants': 1}),
        // The sync body for step 7 is where the collection gets its chance.
        client: otaHost(
          bundles: {20: b},
          pointerSeq: 20,
          syncBodies: {'pull': jsonEncode({'rows': [dataRow('a', 1, 1)], 'max': 1, 'more': false})},
        ),
      );
      // Scheduled before the check, so the frame lands while the check is in flight.
      u.scheduleGarbageCollect();
      final check = u.checkForUpdate();
      await pumpFrame();
      expect(await check, 20);

      for (final hash in b.blobs.keys) {
        expect(File('${casDir.path}/$hash').existsSync(), isTrue, reason: 'kept $hash');
      }
      // The collection still did its job on what was genuinely unreferenced.
      expect(File('${manifestsDir.path}/5.json').existsSync(), isFalse);
    });

    test('a tmp- file mid-rename is not collected', () async {
      casDir.createSync(recursive: true);
      final tmp = File('${casDir.path}/tmp-${'a' * 64}')..writeAsStringSync('half a download');
      await makeUpdater(state: ValenceState(installId: 'i')).garbageCollect();
      expect(tmp.existsSync(), isTrue);
    });
  });

  group('a refusal is keyed on more than the built-in seq (§2.4)', () {
    test('a host upgrade that fixes the bridge version is not skipped', () async {
      // The spec's named usual cause is `requires.bridge` above what the host reports at check 5. That fix
      // is a Dart change, shipped with the same assets and therefore the same seq — so a seq-only key
      // would skip step 1 on the very host built to fix it, for ever.
      final builtin = await signBundle(key, seq: 50, requiresBridge: 2);
      final assets = builtin.asAssets('assets/valence/builtin');
      final previous = await signBundle(key, seq: 10);
      previous.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final state = ValenceState(installId: 'i', current: 10);

      final broken = makeUpdater(state: state, assets: assets, config: testConfig(key, bridgeVersion: 1));
      expect((await broken.activateForUiStart()).seq, 10);
      expect(state.builtinRefused, isNotNull);
      final refusedByOldHost = state.builtinRefused;

      // Same seq, same bytes, a host that now reports bridge 2.
      final fixed = makeUpdater(state: state, assets: assets, config: testConfig(key, bridgeVersion: 2));
      expect((await fixed.activateForUiStart()).seq, 50, reason: 'the upgraded host installs it');
      expect(state.current, 50);
      expect(state.builtinRefused, isNull);
      expect(refusedByOldHost, isNot(equals('50')), reason: 'the record is not just the seq');
    });

    test('step 1 does not verify the built-in bundle on an ordinary launch', () async {
      // The seq gate comes before the load, so an ordinary launch does not pay for an asset read, a
      // manifest decode and a pure-Dart Ed25519 verify in front of the first frame.
      final builtin = await signBundle(key, seq: 50);
      final assets = {...builtin.asAssets('assets/valence/builtin')};
      final current = await signBundle(key, seq: 50);
      current.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final read = <String>[];
      final u = ValenceUpdater(
        config: testConfig(key),
        state: ValenceState(installId: 'i', current: 50),
        stateFile: stateFile,
        casDir: casDir,
        manifestsDir: manifestsDir,
        store: store,
        sync: ValenceSync(store: store, config: testConfig(key), log: (_) {}),
        readAsset: (k) async {
          read.add(k);
          return assets[k] ?? (throw StateError('no asset $k'));
        },
        log: (_) {},
        afterFrame: frames.add,
      );
      await u.activateForUiStart();
      expect(read, ['assets/valence/builtin/manifest.json'],
          reason: 'the manifest is read for its seq, and the signature is not even fetched');
    });
  });

  group('the active bundle repairs a corrupt file (§2.4)', () {
    test('a file the server deleted is re-fetched, because step 1 can never reach step 6', () async {
      // The server can delete a rotted CAS file and answer 500, but §2.3 step 1 stops on
      // `pointer.seq <= current`, so for the bundle being served there is no step 6. If the rotted file is
      // the entry page, the app is a blank screen until some newer release happens to ship.
      final b = await signBundle(key, seq: 20, files: {'index.html': '<html><head></head>hi</html>'});
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final hash = b.blobs.keys.single;
      final file = File('${casDir.path}/$hash');
      file.deleteSync(); // what the server does on a hash mismatch

      final log = LogSpy();
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 20),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        log: log,
      );
      final manifest = await checkManifest(
        bytes: b.bytes,
        signature: b.signature,
        config: testConfig(key),
        state: ValenceState(installId: 'i'),
        pointerSeq: null,
      );
      u.repairFrom = () => (manifest: manifest, corrupt: {hash});

      // The check itself stops at step 1 — that is the whole point — but the repair runs before it.
      expect(await u.checkForUpdate(), isNull);
      expect(file.existsSync(), isTrue, reason: 're-fetched and re-verified through check 7');
      expect(log.has('repairing'), isTrue);
    });

    test('nothing is fetched when the active bundle is intact', () async {
      final b = await signBundle(key, seq: 20);
      b.writeTo(manifestsDir: manifestsDir, casDir: casDir);
      final seen = <String>[];
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 20),
        client: otaHost(bundles: {20: b}, pointerSeq: 20, seen: seen),
      );
      final manifest = await checkManifest(
        bytes: b.bytes,
        signature: b.signature,
        config: testConfig(key),
        state: ValenceState(installId: 'i'),
        pointerSeq: null,
      );
      u.repairFrom = () => (manifest: manifest, corrupt: const <String>{});
      await u.checkForUpdate();
      expect(seen.where((u) => u.contains('/files/')), isEmpty);
    });
  });

  group('background isolates (§2.4, §5.6)', () {
    test('a sync run leaves the activation state untouched', () async {
      // iOS background launches and workmanager runs must not consume a trial. A sync is the only thing a
      // background isolate does, so running one must not move current, pending, trial or trialFails.
      final state = ValenceState(installId: 'i', current: 10, pending: 20, trialFails: 1);
      state.save(stateFile);
      final before = stateFile.readAsStringSync();
      final cfg = testConfig(key, dataSchemas: {'plants': 1});
      final sync = ValenceSync(
        store: store,
        config: cfg,
        client: MockClient(
          (_) async => http.Response(jsonEncode({'rows': [dataRow('a', 1, 1)], 'max': 1, 'more': false}), 200),
        ),
      );
      final result = await sync.run(readSchemas: {'plants': 1});
      expect(result.changed, 1, reason: 'the sync really did work');
      expect(stateFile.readAsStringSync(), before);
      expect(state.pending, 20);
      expect(state.trialFails, 1);
    });

    test('the §2.4 transitions live only on the updater, not on sync or the store', () {
      // The structural half of "no transition runs from a background isolate": the background entry point
      // is Valence.backgroundSync, which is handed a store and a config and has no updater at all.
      expect(ValenceSync(store: store, config: testConfig(key)), isNot(isA<ValenceUpdater>()));
      expect(store, isNot(isA<ValenceUpdater>()));
    });
  });

  group('state persistence (§2.4)', () {
    test('a write is atomic and leaves no temp file behind', () async {
      final state = ValenceState(installId: 'i', current: 10, bad: [5]);
      state.save(stateFile);
      expect(File('${stateFile.path}.tmp').existsSync(), isFalse);
      final read = ValenceState.load(stateFile);
      expect(read.installId, 'i');
      expect(read.current, 10);
      expect(read.bad, [5]);
    });

    test('a corrupt state file starts clean rather than refusing to launch', () async {
      stateFile.writeAsStringSync('{ this is not json');
      final read = ValenceState.load(stateFile);
      expect(read.installId, isNotEmpty);
      expect(read.current, isNull);
    });

    test('a missing state file makes a fresh installId', () async {
      final a = ValenceState.load(stateFile).installId;
      final b = ValenceState.load(File('${root.path}/other.json')).installId;
      expect(a, isNotEmpty);
      expect(a, isNot(b), reason: 'installId is random, never a device id');
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(a), isTrue);
    });

    test('unknown fields are ignored, so an older host reads a newer file', () {
      stateFile.writeAsStringSync(jsonEncode({'installId': 'i', 'current': 10, 'somethingNew': true}));
      expect(ValenceState.load(stateFile).current, 10);
    });

    test('a negative or zero seq in the file is treated as absent', () {
      stateFile.writeAsStringSync(jsonEncode({'installId': 'i', 'current': 0, 'pending': -1}));
      final read = ValenceState.load(stateFile);
      expect(read.current, isNull);
      expect(read.pending, isNull);
    });
  });
  test('concurrent checks share one pointer fetch and pending publication', () async {
    final b = await signBundle(key, seq: 20);
    final entered = Completer<void>(), resume = Completer<void>();
    var pointers = 0, publications = 0;
    final ota = otaHost(bundles: {20: b}, pointerSeq: 20);
    final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: MockClient((req) async {
          if (req.url.path.contains('/channels/')) {
            pointers++;
            if (!entered.isCompleted) entered.complete();
            await resume.future;
          }
          return ota.get(req.url);
        }),
        onUpdateReady: (_) => publications++);
    final first = u.checkForUpdate();
    await entered.future;
    final second = u.checkForUpdate();
    resume.complete();
    expect(await Future.wait([first, second]), [20, 20]);
    expect(pointers, 1);
    expect(publications, 1, reason: 'both checks coalesce onto one publication, so one updateReady');
    expect(u.state.pending, 20);
  });

  test('CR-4 GC refreshes a kept snapshot after publication during asset verification', () async {
    final b = await signBundle(key, seq: 20);
    final entered = Completer<void>(), resume = Completer<void>();
    final cfg = testConfig(key);
    final client = otaHost(bundles: {20: b}, pointerSeq: 20);
    var blocked = false;
    final u = ValenceUpdater(
        config: cfg,
        state: ValenceState(installId: 'i', current: 10),
        stateFile: stateFile,
        casDir: casDir,
        manifestsDir: manifestsDir,
        store: store,
        sync: ValenceSync(store: store, config: cfg, client: client),
        client: client,
        afterFrame: frames.add,
        readAsset: (_) async {
          if (!blocked) {
            blocked = true;
            entered.complete();
            await resume.future;
          }
          throw StateError('no builtin');
        });
    final gc = u.garbageCollect();
    await entered.future;
    expect(await u.checkForUpdate(), 20);
    resume.complete();
    await gc;
    expect(File('${manifestsDir.path}/20.json').existsSync(), isTrue);
    for (final hash in b.blobs.keys) {
      expect(File('${casDir.path}/$hash').existsSync(), isTrue);
    }
  });

  test('CR-4 data lease protects step 7 through durable pending publication', () async {
    final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
    final cfg = testConfig(key);
    final client = otaHost(
        bundles: {20: b},
        pointerSeq: 20,
        syncBodies: {
          'plants': jsonEncode({
            'rows': [dataRow('a', 1, 1)],
            'max': 1,
            'more': false
          })
        });
    late ValenceUpdater u;
    final directory = _BeforeCreateDirectory(manifestsDir, () => u.garbageCollect());
    u = ValenceUpdater(
        config: cfg,
        state: ValenceState(installId: 'i', current: 10),
        stateFile: stateFile,
        casDir: casDir,
        manifestsDir: directory,
        store: store,
        sync: ValenceSync(store: store, config: cfg, client: client),
        client: client,
        afterFrame: frames.add,
        readAsset: (_) async => throw StateError('no builtin'));
    expect(await u.checkForUpdate(), 20);
    expect(await store.get('plants', 2, 'a'), 1);
    expect((await store.syncedPairs())['plants'], {2});
  });

  test('F-30 same check waits for ordinary sync release and stages required data', () async {
    final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
    final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(
            bundles: {20: b},
            pointerSeq: 20,
            syncBodies: {
              'plants': jsonEncode({
                'rows': [dataRow('a', 1, 1)],
                'max': 1,
                'more': false
              })
            }));
    final holder = ValenceSync(store: store, config: testConfig(key));
    expect(await holder.acquireLease(), isTrue);
    final check = u.checkForUpdate();
    final release = Future<void>.delayed(const Duration(milliseconds: 100), holder.releaseLease);
    expect(await check, 20);
    await release;
  });

  for (final budget in [false, true]) {
    test('CR-3 activation waits for all pull pages after a partial failure budget=$budget', () async {
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
      var recovered = false;
      final ota = otaHost(bundles: {20: b}, pointerSeq: 20);
      final client = MockClient((req) async {
        if (req.url.host != 'sync.test') return ota.get(req.url);
        final since = int.parse(req.url.queryParameters['since']!);
        if (since == 0) {
          return http.Response(
              jsonEncode({
                'rows': [dataRow('a', 1, 1)],
                'max': 2,
                'more': true
              }),
              200);
        }
        if (!recovered) return http.Response('down', 500);
        return http.Response(
            jsonEncode({
              'rows': [dataRow('b', 2, 2)],
              'max': 2,
              'more': false
            }),
            200);
      });
      final u = makeUpdater(
          state: ValenceState(installId: 'i', current: 10),
          client: client,
          config: testConfig(key, dataSizeCap: budget ? 1 : 50000));
      expect(await u.checkForUpdate(), isNull);
      expect(u.state.pending, isNull);
      recovered = true;
      expect(await u.checkForUpdate(), 20);
      expect(await store.get('plants', 2, 'b'), 2);
    });
  }

  // ===========================================================================
  /// Answers the pointer, the manifest, the signature and the files of [b], and null for anything else —
  /// so a test can decide for itself what happens to the sync endpoints step 7 reaches.
  http.Response? bundleOnly(http.BaseRequest req, SignedBundle b) {
    final path = req.url.path;
    if (path.contains('/channels/')) return http.Response(jsonEncode({'seq': b.seq, 'rollout': 100}), 200);
    final base = '/manifests/${b.seq}.json';
    if (path.endsWith(base)) return http.Response.bytes(b.bytes, 200);
    if (path.endsWith('$base.sig')) return http.Response(b.signature, 200);
    final file = RegExp(r'/files/([0-9a-f]{64})$').firstMatch(path);
    if (file != null) return http.Response.bytes(b.blobs[file.group(1)]!, 200);
    return null;
  }

  group('§4.6 why a check stopped, for bundle.status', () {
    // Each row is a stop site in §2.3. The point is not that the check declined — every case above
    // already covers that — it is that the page is told *which* reason it was, because "waiting for
    // data" and "rolled out to 10%" are a healthy system while "rejected" is a broken release, and
    // before this they were one answer: pending stayed null and nothing else moved.

    test('nothing has been checked yet, and an app with no otaBase never will', () async {
      final idle = makeUpdater(state: ValenceState(installId: 'i'));
      expect(idle.lastReason, ValenceBundleReason.idle);
      expect(idle.lastCheckedAt, isNull);
      expect(idle.lastOffered, isNull);

      final u = makeUpdater(state: ValenceState(installId: 'i'), config: testConfig(key, otaBase: ''));
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.unconfigured);
      expect(u.lastOffered, isNull, reason: 'no pointer was ever fetched');
      expect(u.lastCheckedAt, isNotNull, reason: 'the check completed; it just had nothing to do');
    });

    test('a healthy pending reports ready, with the seq the pointer offered', () async {
      final b = await signBundle(key, seq: 20);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), 20);
      expect(u.lastReason, ValenceBundleReason.ready);
      expect(u.lastOffered, 20);
    });

    test('the three "nothing newer" stops are one reason, not three', () async {
      for (final state in [
        ValenceState(installId: 'i', current: 20),
        ValenceState(installId: 'i', current: 10, pending: 20),
        ValenceState(installId: 'i', current: 10, trial: 20, serving: 20),
      ]) {
        final u = makeUpdater(state: state, client: otaHost(bundles: {}, pointerSeq: 20));
        expect(await u.checkForUpdate(), isNull);
        expect(u.lastReason, ValenceBundleReason.uptodate);
        expect(u.lastOffered, 20);
      }
    });

    test('outside the rollout is its own reason: a newer release does exist', () async {
      final b = await signBundle(key, seq: 20);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20, rollout: 0),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.rollout);
      expect(u.lastOffered, 20);
    });

    test('a seq this install has rejected reports bad', () async {
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10, bad: [20]),
        client: otaHost(bundles: {}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.bad);
    });

    test('a fetch that cannot reach the server reports offline, at every step that fetches', () async {
      final b = await signBundle(key, seq: 20);
      final cases = <String, http.Client>{
        'the pointer': MockClient((_) => throw const SocketException('down')),
        'the manifest': otaHost(bundles: {20: b}, pointerSeq: 20, failPaths: {'20.json'}),
        'the signature': otaHost(bundles: {20: b}, pointerSeq: 20, failPaths: {'20.json.sig'}),
      };
      for (final e in cases.entries) {
        final u = makeUpdater(state: ValenceState(installId: 'i', current: 10), client: e.value);
        expect(await u.checkForUpdate(), isNull, reason: e.key);
        expect(u.lastReason, ValenceBundleReason.offline, reason: e.key);
      }
      // A bundle file that 404s is the same answer; the published bytes may simply not be there yet.
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: SignedBundle(b.bytes, b.signature, b.manifest, const {})}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.offline);
    });

    test('a manifest that fails its checks reports rejected, not offline', () async {
      // The one reason that deserves an alert: no device will ever take this release.
      final other = await TestKey.create('k2');
      final b = await signBundle(other, seq: 20);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.rejected);
      expect(u.lastOffered, 20);
    });

    test('a file whose bytes are not the published bytes reports rejected', () async {
      final b = await signBundle(key, seq: 20);
      final hash = b.blobs.keys.first;
      final tampered = SignedBundle(b.bytes, b.signature, b.manifest, {hash: utf8.encode('not it')});
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: tampered}, pointerSeq: 20),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.rejected);
    });

    test('over the size cap reports toobig', () async {
      final b = await signBundle(key, seq: 20);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        config: testConfig(key, bundleSizeCap: 1),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.toobig);
    });

    test('a bundle waiting for its data pair reports waitingForData, not "no update"', () async {
      // The state four hosts read as "nothing new". The bundle is downloaded and verified and simply
      // cannot be served yet, and on an offline device it stays here indefinitely.
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        // Everything the bundle needs is published except the data pair, which is step 7's whole point.
        client: MockClient((req) async => bundleOnly(req, b) ?? http.Response('not published yet', 503)),
        config: testConfig(key, dataSchemas: {'plants': 1}),
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.waitingForData);
      expect(u.lastOffered, 20);

      // Same answer with no syncBase at all: the pair has no route onto the device either way.
      final dry = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: MockClient((req) async => bundleOnly(req, b) ?? http.Response('no', 404)),
        config: testConfig(key, dataSchemas: {'plants': 1}, syncBase: ''),
      );
      expect(await dry.checkForUpdate(), isNull);
      expect(dry.lastReason, ValenceBundleReason.waitingForData);
    });

    test('a step 7 that cannot take the lease reports busy, and the next check retries', () async {
      final b = await signBundle(key, seq: 20, requiresData: {'plants': 2});
      final cfg = testConfig(key, dataSchemas: {'plants': 1});
      final held = ValenceSync(store: store, config: cfg);
      expect(await held.acquireLease(), isTrue);
      final u = makeUpdater(
        state: ValenceState(installId: 'i', current: 10),
        client: otaHost(bundles: {20: b}, pointerSeq: 20),
        config: cfg,
      );
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastReason, ValenceBundleReason.busy);
      await held.releaseLease();
    });

    test('a check that completed stamps checkedAt, and the stamp moves with each one', () async {
      final u =
          makeUpdater(state: ValenceState(installId: 'i', current: 20), client: otaHost(bundles: {}, pointerSeq: 20));
      await u.checkForUpdate();
      final first = u.lastCheckedAt!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await u.checkForUpdate();
      expect(u.lastCheckedAt!, greaterThanOrEqualTo(first));
    });

    test('the offered seq describes this check, not the last one', () async {
      // Otherwise a page shows "update 20 available" for ever after one offer, including on a run that
      // never reached the pointer at all.
      final b = await signBundle(key, seq: 20);
      final state = ValenceState(installId: 'i', current: 10);
      var reachable = true;
      final u = makeUpdater(
        state: state,
        client: MockClient((req) async {
          if (!reachable) throw const SocketException('down');
          return bundleOnly(req, b) ?? http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      expect(await u.checkForUpdate(), 20);
      expect(u.lastOffered, 20);
      reachable = false;
      state.pending = null;
      expect(await u.checkForUpdate(), isNull);
      expect(u.lastOffered, isNull);
      expect(u.lastReason, ValenceBundleReason.offline);
    });
  });
}

// Pauses at the real filesystem boundary between the data gate and manifest publication.
final class _BeforeCreateDirectory implements Directory {
  _BeforeCreateDirectory(this.inner, this.before);
  final Directory inner;
  final Future<void> Function() before;
  @override
  String get path => inner.path;
  @override
  Future<Directory> create({bool recursive = false}) async {
    await before();
    return inner.create(recursive: recursive);
  }

  @override
  bool existsSync() => inner.existsSync();
  @override
  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) =>
      inner.listSync(recursive: recursive, followLinks: followLinks);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
