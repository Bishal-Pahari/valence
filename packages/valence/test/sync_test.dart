// Contracts §5.3 to §5.6: paged pulls, push, the static variant, and the one-sync-at-a-time lease.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  late TestKey key;
  late ValenceStore store;

  setUpAll(() async => key = await TestKey.create());
  setUp(() async => store = await openTestStore());

  Map<String, Object?> row(String k, Object? v, int u, {bool d = false}) =>
      {'k': k, 'v': v, 'u': u, 'd': d ? 1 : 0};

  /// A client that records every request and answers from [handler].
  ({MockClient client, List<http.BaseRequest> seen}) recordingClient(
    Future<http.Response> Function(http.Request req) handler,
  ) {
    final seen = <http.BaseRequest>[];
    return (
      client: MockClient((req) {
        seen.add(req);
        return handler(req);
      }),
      seen: seen,
    );
  }

  ValenceSync syncWith(
    http.Client client, {
    ValenceConfig? config,
    LogSpy? log,
    DateTime Function()? clock,
  }) =>
      ValenceSync(
        store: store,
        config: config ?? testConfig(key, dataSchemas: {'plants': 1}),
        client: client,
        log: (log ?? LogSpy()).call,
        clock: clock,
      );

  test(
      'R17 reason survives driver replacement, busy and errors; scoped recovery replaces it',
      () async {
    final cfg = testConfig(key, writableBuckets: {'shelf'})
        .copyWith(authToken: () async => 'token');
    final rejected =
        syncWith(MockClient((_) async => http.Response('', 401)), config: cfg);
    expect((await rejected.status()).reason, isNull);
    expect((await rejected.run(readSchemas: {}, only: ['shelf'])).reason,
        ValenceSyncReason.unauthorized);
    final broken = syncWith(
        MockClient((_) async => throw StateError('server fault')),
        config: cfg);
    expect((await broken.status()).reason, 'unauthorized');
    await expectLater(
        broken.run(readSchemas: {}, only: ['shelf']), throwsStateError);
    expect((await broken.status()).reason, 'unauthorized');
    await rejected.acquireLease();
    expect((await broken.run(readSchemas: {})).reason, ValenceSyncReason.busy);
    expect((await broken.status()).reason, 'unauthorized');
    await rejected.releaseLease();
    final recovered = syncWith(
        MockClient((_) async =>
            http.Response('{"rows":[],"max":0,"more":false}', 200)),
        config: cfg);
    await recovered.run(readSchemas: {}, only: ['shelf']);
    expect((await recovered.status()).reason, 'ok');
    expect((await recovered.status()).lastSyncedAt, isNull);
    await store.hostPrefSet('valence.sync.reason', 'futureReason');
    expect((await recovered.status()).reason, 'futureReason');
  });

  group('the lease (§5.6)', () {
    test('one holder at a time', () async {
      final a = syncWith(MockClient((_) async => http.Response('{}', 200)));
      final b = syncWith(MockClient((_) async => http.Response('{}', 200)));
      expect(await a.acquireLease(), isTrue);
      expect(await b.acquireLease(), isFalse, reason: 'one sync at a time, across isolates');
      await a.releaseLease();
      expect(await b.acquireLease(), isTrue);
    });

    test('an expired lease can be taken over', () async {
      final now = DateTime(2026, 10, 17, 12);
      final a = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      expect(await a.acquireLease(), isTrue);
      // Two minutes and a second later, the holder is presumed dead.
      final b = syncWith(
        MockClient((_) async => http.Response('{}', 200)),
        clock: () => now.add(const Duration(minutes: 2, seconds: 1)),
      );
      expect(await b.acquireLease(), isTrue);
    });

    test('a lease time in the future counts as expired', () async {
      // Clock skew or tampering must not be able to park every sync for ever.
      await store.hostPrefSet('valence.sync.lease', '${DateTime(2030).millisecondsSinceEpoch}');
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)));
      expect(await s.acquireLease(), isTrue);
    });

    test('a non-numeric lease value does not wedge sync', () async {
      await store.hostPrefSet('valence.sync.lease', 'not a number');
      expect(await syncWith(MockClient((_) async => http.Response('{}', 200))).acquireLease(), isTrue);
    });

    test('renew pushes the lease forward, so a long pull keeps it', () async {
      var now = DateTime(2026, 10, 17, 12);
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      await s.acquireLease();
      now = now.add(const Duration(minutes: 1, seconds: 30));
      await s.renewLease();
      now = now.add(const Duration(minutes: 1, seconds: 30));
      // Three minutes after acquiring, but only 90 s after renewing, so it is still held.
      final other = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      expect(await other.acquireLease(), isFalse);
    });

    test('a run that throws still releases the lease', () async {
      final s = syncWith(
        MockClient((_) => throw const SocketException('down')),
        config: testConfig(key, dataSchemas: {'plants': 1}),
      );
      await s.run(readSchemas: {'plants': 1});
      expect(await store.hostPrefGet('valence.sync.lease'), isNull);
    });

    test('run skips when another sync holds the lease', () async {
      final other = syncWith(MockClient((_) async => http.Response('{}', 200)));
      await other.acquireLease();
      final log = LogSpy();
      final s = syncWith(MockClient((_) async => fail('must not reach the network')), log: log);
      final result = await s.run(readSchemas: {'plants': 1});
      expect(result.changed, 0);
      expect(log.has('another sync holds the lease'), isTrue);
      // F-40: without the reason, this is bit-for-bit "you are already up to date", so a freshness
      // indicator reports confident freshness over data that was never looked at.
      expect(result.reason, ValenceSyncReason.busy);
      expect(result.offline, isFalse);
    });

    test('a lease left by a process that is gone is taken over, not waited out', () async {
      // The lease keeps the UI isolate and the background isolate apart, and those share a process. A
      // foreign pid therefore means a launch that crashed or was force-stopped, and waiting out its two
      // minutes blocks every sync of the new launch while reporting each one as a successful empty sync.
      final now = DateTime(2026, 10, 21, 12);
      await store.hostPrefSet('valence.sync.lease', '${now.millisecondsSinceEpoch}:${pid + 1}');
      final log = LogSpy();
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now, log: log);
      expect(await s.acquireLease(), isTrue);
      expect(log.has('which is gone'), isTrue);
      // Our own live lease is still respected, which is the whole point of having one.
      final mine = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      expect(await mine.acquireLease(), isFalse);
    });

    test('a lease written by an older host, with no owner, is cleared rather than waited out', () async {
      final now = DateTime(2026, 10, 21, 12);
      await store.hostPrefSet('valence.sync.lease', '${now.millisecondsSinceEpoch}');
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      expect(await s.acquireLease(), isTrue);
    });

    test('a completed run reports ok, and a run that could not reach the server reports offline', () async {
      final ok = syncWith(MockClient((_) async => http.Response('{"rows":[],"max":0,"more":false}', 200)));
      expect((await ok.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.ok);
      final down = syncWith(MockClient((_) => throw const SocketException('down')));
      final r = await down.run(readSchemas: {'plants': 1});
      expect(r.reason, ValenceSyncReason.offline);
      expect(r.offline, isTrue, reason: 'the old field keeps its old meaning');
    });
  });

  group('incomplete runs (R26, §5.6)', () {
    for (final status in [401, 403, 500]) {
      for (final bucket in ['plants', 'shelf']) {
        test('anonymous $status on $bucket is failed, not ok or unauthorized', () async {
          final sync = syncWith(
            MockClient((_) async => http.Response('', status)),
            config: testConfig(key, writableBuckets: {'shelf'}),
          );
          var expired = 0;
          sync.onUnauthorized = () => expired++;
          final result = await sync.run(readSchemas: {'plants': 1}, only: [bucket]);
          expect(result.reason, ValenceSyncReason.failed);
          expect(result.toJson()['reason'], 'failed');
          expect((await sync.status()).reason, 'failed');
          final replacement = syncWith(
            MockClient((_) async => throw StateError('not used for status')),
          );
          expect((await replacement.status()).reason, 'failed');
          expect(result.offline, isFalse);
          expect(expired, 0);
          expect((await sync.status()).lastSyncedAt, isNull);
        });
      }
    }

    for (final body in [
      '<html>',
      '{"rows":[],"max":0,"more":true}',
      '{"rows":[{"k":"b","v":2,"u":2},{"k":"a","v":1,"u":1}],"max":2,"more":false}',
    ]) {
      test('invalid pull page reports failed: $body', () async {
        final sync = syncWith(MockClient((_) async => http.Response(body, 200)));
        expect((await sync.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.failed);
        expect(await store.maxUsn('plants', 1), 0);
        expect((await sync.status()).lastSyncedAt, isNull);
      });
    }

    test('partial progress is retained, failures do not stamp freshness, and recovery resets reason', () async {
      var failing = false;
      var page = 0;
      final sync = syncWith(MockClient((req) async {
        if (!failing) return http.Response('{"rows":[],"max":0,"more":false}', 200);
        page++;
        if (page > 1) return http.Response('', 500);
        return http.Response(jsonEncode({'rows': [row('a', 1, 1)], 'max': 1, 'more': true}), 200);
      }));
      expect((await sync.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.ok);
      final stamp = (await sync.status()).lastSyncedAt;
      expect(stamp, isNotNull);
      failing = true;
      final partial = await sync.run(readSchemas: {'plants': 1});
      expect(partial.reason, ValenceSyncReason.failed);
      expect((await sync.status()).reason, 'failed');
      expect(partial.changed, 1);
      expect(await store.get('plants', 1, 'a'), 1);
      expect(await store.maxUsn('plants', 1), 1);
      expect((await sync.status()).lastSyncedAt, stamp);
      failing = false;
      expect((await sync.run(readSchemas: {'plants': 1}, only: ['plants'])).reason, ValenceSyncReason.ok);
      expect((await sync.status()).lastSyncedAt, stamp);
      expect((await sync.status()).reason, 'ok');
    });

    for (final response in [http.Response('', 500), http.Response('<html>', 200)]) {
      test('failed push keeps queued writes: ${response.statusCode}', () async {
        await store.put('shelf', 'a', 1, opId: 'queued-a');
        final sync = syncWith(MockClient((req) async => req.method == 'POST'
            ? response
            : http.Response('{"rows":[],"max":0,"more":false}', 200)),
            config: testConfig(key, writableBuckets: {'shelf'}));
        final result = await sync.run(readSchemas: {});
        expect(result.reason, ValenceSyncReason.failed);
        expect(result.pending, 1);
        expect(await store.get('shelf', 1, 'a'), 1);
        expect((await sync.status()).lastSyncedAt, isNull);
      });
    }

    for (final failAt in ['index', 'chunk']) {
      test('static $failAt failure reports failed', () async {
        final sync = syncWith(MockClient((req) async {
          if (req.url.path.endsWith('index.json')) {
            return failAt == 'index' ? http.Response('invalid', 200)
                : http.Response('[{"to":1,"file":"one.json"}]', 200);
          }
          return http.Response('', 500);
        }), config: testConfig(key, syncMode: ValenceSyncMode.staticChunks));
        expect((await sync.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.failed);
        expect((await sync.status()).lastSyncedAt, isNull);
      });
    }

    test('a scoped run that matches nothing reports failed and overwrites no observation', () async {
      final log = LogSpy();
      final sync = syncWith(
          MockClient((req) async => req.url.path.endsWith('/plants')
              ? http.Response('{"rows":[],"max":0,"more":false}', 200)
              : http.Response('', 401)),
          config: testConfig(key, writableBuckets: {'shelf'})
              .copyWith(authToken: () async => 'token'),
          log: log);
      sync.onUnauthorized = () {};
      // A real run records the refusal that the page draws "sign in again" from.
      expect((await sync.run(readSchemas: {'plants': 1})).reason,
          ValenceSyncReason.unauthorized);
      expect((await sync.status()).reason, 'unauthorized');

      // `buckets` is page-supplied, so a name this bundle no longer has is reachable on demand.
      // It attempts nothing, so it may neither claim success nor erase the refusal.
      final empty = await sync.run(readSchemas: {'plants': 1}, only: ['plantz']);
      expect(empty.reason, ValenceSyncReason.failed);
      expect(empty.buckets, isEmpty);
      expect(empty.changed, 0);
      expect(log.has('matched no syncable bucket'), isTrue, reason: log.toString());
      expect((await sync.status()).reason, 'unauthorized');
      expect((await sync.status()).lastSyncedAt, isNull);

      // A scope that matches is unchanged: it attempts, and reports what happened.
      expect((await sync.run(readSchemas: {'plants': 1}, only: ['plants'])).reason,
          ValenceSyncReason.ok);
      expect((await sync.status()).reason, 'ok');
    });

    test('offline outranks a server failure without losing the offline flag', () async {
      final sync = syncWith(MockClient((req) async {
        if (req.url.path.endsWith('/plants')) return http.Response('', 500);
        throw const SocketException('no route');
      }), config: testConfig(key, writableBuckets: {'shelf'}));
      final result = await sync.run(readSchemas: {'plants': 1});
      expect(result.reason, ValenceSyncReason.offline);
      expect(result.offline, isTrue);
    });

    test('authenticated rejection outranks an unrelated server failure', () async {
      final sync = syncWith(MockClient((req) async =>
          http.Response('', req.url.path.endsWith('/plants') ? 500 : 401)),
          config: testConfig(key, writableBuckets: {'shelf'})
              .copyWith(authToken: () async => 'token'));
      var expired = 0;
      sync.onUnauthorized = () => expired++;
      expect((await sync.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.unauthorized);
      expect(expired, 1);
    });
  });

  group('pull (§5.3)', () {
    test('a paged pull applies every page and loops while more is true', () async {
      final r = recordingClient((req) async {
        final since = int.parse(req.url.queryParameters['since']!);
        if (since == 0) {
          return http.Response(
            jsonEncode({'rows': [row('a', 1, 1), row('b', 2, 2)], 'max': 2, 'more': true}),
            200,
          );
        }
        return http.Response(jsonEncode({'rows': [row('c', 3, 3)], 'max': 3, 'more': false}), 200);
      });
      final applied = await syncWith(r.client).pullPair('plants', 1);
      expect(applied, 3);
      expect(await store.maxUsn('plants', 1), 3);
      expect(r.seen.map((q) => q.url.queryParameters['since']), ['0', '2']);
    });

    test('the request carries since, schema and limit', () async {
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200));
      await syncWith(r.client, config: testConfig(key, pullPageLimit: 500)).pullPair('plants', 2);
      final q = r.seen.single.url;
      expect(q.path, endsWith('/plants'));
      expect(q.queryParameters, {'since': '0', 'schema': '2', 'limit': '500'});
    });

    test('a pull resumes from the pair’s own max_usn, never from 0', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 40)], maxUsnAfter: 40);
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 40, 'more': false}), 200));
      await syncWith(r.client).pullPair('plants', 1);
      expect(r.seen.single.url.queryParameters['since'], '40');
    });

    test('each pair resumes from its own max_usn', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 10)], maxUsnAfter: 10);
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200));
      final s = syncWith(r.client);
      await s.pullPair('plants', 1);
      await s.pullPair('plants', 2);
      expect(r.seen.map((q) => q.url.queryParameters['since']), ['10', '0']);
    });

    test('the lease is renewed after every applied page', () async {
      var now = DateTime(2026, 10, 17, 12);
      var page = 0;
      final s = syncWith(
        MockClient((_) async {
          now = now.add(const Duration(minutes: 1, seconds: 30));
          page++;
          return http.Response(
            jsonEncode({'rows': [row('k$page', page, page)], 'max': page, 'more': page < 3}),
            200,
          );
        }),
        clock: () => now,
      );
      await s.acquireLease();
      await s.pullPair('plants', 1);
      // Four and a half minutes of pulling, but renewed each page, so nobody else may start.
      final other = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      expect(await other.acquireLease(), isFalse);
    });

    test('a non-200 stops the pull and leaves max_usn alone', () async {
      final log = LogSpy();
      final applied = await syncWith(MockClient((_) async => http.Response('nope', 503)), log: log).pullPair('plants', 1);
      expect(applied, 0);
      expect(await store.maxUsn('plants', 1), 0);
      expect(log.has('HTTP 503'), isTrue);
    });

    test('a body that does not decode stops the pull and says so', () async {
      final log = LogSpy();
      await syncWith(MockClient((_) async => http.Response('<html>', 200)), log: log).pullPair('plants', 1);
      expect(log.has('cannot decode'), isTrue);
    });

    test('more true with no rows stops rather than spinning for ever', () async {
      final log = LogSpy();
      var calls = 0;
      await syncWith(
        MockClient((_) async {
          calls++;
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': true}), 200);
        }),
        log: log,
      ).pullPair('plants', 1);
      expect(calls, 1);
      expect(log.has('claimed more rows but sent none'), isTrue);
    });

    test('a byte budget stops the pull and backs off', () async {
      final log = LogSpy();
      final applied = await syncWith(
        MockClient((req) async {
          final since = int.parse(req.url.queryParameters['since']!);
          return http.Response(
            jsonEncode({'rows': [row('k$since', 'x' * 400, since + 1)], 'max': since + 1, 'more': true}),
            200,
          );
        }),
        log: log,
      ).pullPair('plants', 1, byteBudget: 100);
      // The budget is a stop-after signal: the page that crosses it is still applied, and then the pull
      // backs off rather than looping. Without it, a manifest requiring a large pair has no bound at all.
      expect(applied, 1);
      expect(log.has('byte budget'), isTrue);
    });

    test('a public read-only bucket is pulled without a bearer token', () async {
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200));
      final config = ValenceConfig(
        appId: 'com.example.app',
        keyring: {key.keyId: key.publicKeyBase64},
        bridgeVersion: 1,
        syncBase: 'https://sync.test',
        dataSchemas: const {'plants': 1},
        authToken: () async => 'secret-token',
      );
      await syncWith(r.client, config: config).pullPair('plants', 1);
      expect(r.seen.single.headers.containsKey('authorization'), isFalse);
    });

    test('a user bucket carries the bearer token the app supplies', () async {
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200));
      final config = ValenceConfig(
        appId: 'com.example.app',
        keyring: {key.keyId: key.publicKeyBase64},
        bridgeVersion: 1,
        syncBase: 'https://sync.test',
        writableBuckets: const {'shelf'},
        authToken: () async => 'secret-token',
      );
      await syncWith(r.client, config: config).pullPair('shelf', 1);
      expect(r.seen.single.headers['authorization'], 'Bearer secret-token');
    });
  });

  group('a rejected token (§4.4)', () {
    ValenceConfig authConfig() => ValenceConfig(
          appId: 'com.example.app',
          keyring: {key.keyId: key.publicKeyBase64},
          bridgeVersion: 1,
          syncBase: 'https://sync.test',
          dataSchemas: const {'plants': 1},
          writableBuckets: const {'shelf'},
          authToken: () async => 'expired-token',
        );

    test('a 401 on a user bucket reports unauthorized, tells the page once, and keeps the token', () async {
      var asked = 0;
      final log = LogSpy();
      final sync = syncWith(
        MockClient((req) async {
          asked++;
          // The public bucket is fine; only the authenticated ones are rejected.
          if (req.url.path.endsWith('/plants')) {
            return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
          }
          return http.Response('{"error":"expired"}', 401);
        }),
        config: authConfig(),
        log: log,
      );
      var expiries = 0;
      sync.onUnauthorized = () => expiries++;

      await store.put('shelf', 'mine', {'n': 1}, opId: 'op-1');
      final result = await sync.run(readSchemas: {'plants': 1});

      // Both the pull and the push of `shelf` were rejected, and the page is told once.
      expect(expiries, 1, reason: 'one login prompt per run, not one per request');
      expect(result.reason, ValenceSyncReason.unauthorized);
      expect(
        result.offline,
        isFalse,
        reason: 'the server answered, so the old offline flag keeps its old meaning',
      );
      expect(log.has('HTTP 401'), isTrue);
      expect(asked, greaterThan(1));
      // Nothing is lost: the queued write stays queued and pushes once a new token arrives.
      expect(await store.outboxBuckets(), ['shelf']);
    });

    test('a 401 outranks offline, because only one of them the page can fix', () async {
      final sync = syncWith(
        MockClient((req) async {
          if (req.url.path.endsWith('/plants')) throw const SocketException('no route');
          return http.Response('{}', 401);
        }),
        config: authConfig(),
      );
      final result = await sync.run(readSchemas: {'plants': 1});
      expect(result.reason, ValenceSyncReason.unauthorized);
      expect(result.offline, isTrue, reason: 'it really was offline for the public bucket too');
    });

    test('a 401 on a bucket that carried no token is a server problem, not an expired login', () async {
      // A misconfigured CDN in front of a public bucket can answer 401. Treating that as an expired
      // login would show a login screen to an app that has no login at all.
      final log = LogSpy();
      final sync = syncWith(
        MockClient((_) async => http.Response('{}', 401)),
        config: testConfig(key, dataSchemas: {'plants': 1}),
        log: log,
      );
      var expiries = 0;
      sync.onUnauthorized = () => expiries++;
      final result = await sync.run(readSchemas: {'plants': 1});
      expect(expiries, 0);
      expect(result.reason, ValenceSyncReason.failed);
      expect(log.has('HTTP 401'), isTrue, reason: 'still logged, because something is wrong');
    });

    test('the next run tells the page again, so a failed refresh is not swallowed', () async {
      final sync = syncWith(
        MockClient((_) async => http.Response('{}', 401)),
        config: authConfig(),
      );
      var expiries = 0;
      sync.onUnauthorized = () => expiries++;
      await sync.run(readSchemas: const {});
      await sync.run(readSchemas: const {});
      expect(expiries, 2);
    });
  });

  group('the static CDN variant (§5.3)', () {
    ValenceConfig staticConfig() => testConfig(
          key,
          syncBase: 'https://cdn.test',
          syncMode: ValenceSyncMode.staticChunks,
          dataSchemas: {'plants': 1},
        );

    test('the index drives which chunks are fetched', () async {
      final r = recordingClient((req) async {
        if (req.url.path.endsWith('index.json')) {
          return http.Response(
            jsonEncode([
              {'from': 1, 'to': 2, 'file': 'c-0001.json.gz'},
              {'from': 3, 'to': 4, 'file': 'c-0002.json.gz'},
            ]),
            200,
          );
        }
        final n = req.url.path.endsWith('c-0001.json.gz') ? 1 : 3;
        return http.Response(
          jsonEncode({'rows': [row('k$n', n, n), row('k${n + 1}', n + 1, n + 1)], 'max': n + 1, 'more': false}),
          200,
        );
      });
      final applied = await syncWith(r.client, config: staticConfig()).pullPair('plants', 1);
      expect(applied, 4);
      expect(await store.maxUsn('plants', 1), 4);
      expect(r.seen.map((q) => q.url.pathSegments.last),
          ['index.json', 'c-0001.json.gz', 'c-0002.json.gz']);
    });

    test('chunks at or below max_usn are skipped', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('k1', 1, 2)], maxUsnAfter: 2);
      final r = recordingClient((req) async {
        if (req.url.path.endsWith('index.json')) {
          return http.Response(
            jsonEncode([
              {'from': 1, 'to': 2, 'file': 'c-0001.json.gz'},
              {'from': 3, 'to': 4, 'file': 'c-0002.json.gz'},
            ]),
            200,
          );
        }
        return http.Response(jsonEncode({'rows': [row('k3', 3, 3)], 'max': 4, 'more': false}), 200);
      });
      await syncWith(r.client, config: staticConfig()).pullPair('plants', 1);
      expect(r.seen.map((q) => q.url.pathSegments.last), ['index.json', 'c-0002.json.gz']);
    });

    test('a gzipped chunk body is decoded', () async {
      final body = jsonEncode({'rows': [row('a', 1, 1)], 'max': 1, 'more': false});
      final r = recordingClient((req) async {
        if (req.url.path.endsWith('index.json')) {
          return http.Response(jsonEncode([{'from': 1, 'to': 1, 'file': 'c.json.gz'}]), 200);
        }
        return http.Response.bytes(gzip.encode(utf8.encode(body)), 200);
      });
      expect(await syncWith(r.client, config: staticConfig()).pullPair('plants', 1), 1);
      expect(await store.get('plants', 1, 'a'), 1);
    });

    test('an index entry whose file name tries to escape is ignored', () async {
      final r = recordingClient((req) async {
        if (req.url.path.endsWith('index.json')) {
          return http.Response(
            jsonEncode([
              {'from': 1, 'to': 9, 'file': '../../etc/passwd'},
              {'from': 1, 'to': 9, 'file': 'a/b.json'},
            ]),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      await syncWith(r.client, config: staticConfig()).pullPair('plants', 1);
      expect(r.seen, hasLength(1), reason: 'only the index was fetched');
    });

    test('a malformed index stops the pull and says so', () async {
      final log = LogSpy();
      await syncWith(
        MockClient((_) async => http.Response('{"not":"a list"}', 200)),
        config: staticConfig(),
        log: log,
      ).pullPair('plants', 1);
      expect(log.has('not a list'), isTrue);
    });

    test('a writable bucket still uses the API, because push needs an endpoint', () async {
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200));
      final config = testConfig(
        key,
        syncBase: 'https://cdn.test',
        syncMode: ValenceSyncMode.staticChunks,
        writableBuckets: {'shelf'},
      );
      await syncWith(r.client, config: config).pullPair('shelf', 1);
      expect(r.seen.single.url.queryParameters['since'], '0');
    });
  });

  group('push (§5.5)', () {
    test('queued ops are posted, acknowledged ids cleared and the echo applied', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      final r = recordingClient((req) async {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        final ops = body['ops']! as List;
        expect(ops, hasLength(1));
        expect((ops.single as Map)['id'], 'op-a');
        return http.Response(
          jsonEncode({'acked': ['op-a'], 'rows': [row('a', {'v': 1}, 77)]}),
          200,
        );
      });
      final config = testConfig(key, writableBuckets: {'shelf'});
      expect(await syncWith(r.client, config: config).pushBucket('shelf'), 1);
      expect(await store.outbox('shelf'), isEmpty);
      expect((await store.list('shelf', 1)).single.usn, 77);
      expect(r.seen.single.url.path, endsWith('/shelf/push'));
    });

    test('a delete is pushed as d 1 with a null value', () async {
      await store.put('shelf', 'a', null, opId: 'op-a');
      Map<String, Object?>? sentOp;
      final client = MockClient((req) async {
        sentOp = ((jsonDecode(req.body) as Map)['ops'] as List).single as Map<String, Object?>;
        return http.Response(jsonEncode({'acked': ['op-a'], 'rows': []}), 200);
      });
      await syncWith(client, config: testConfig(key, writableBuckets: {'shelf'})).pushBucket('shelf');
      expect(sentOp!['d'], 1);
      expect(sentOp!['v'], isNull);
    });

    test('a non-200 keeps the ops queued', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      final log = LogSpy();
      final n = await syncWith(
        MockClient((_) async => http.Response('nope', 500)),
        config: testConfig(key, writableBuckets: {'shelf'}),
        log: log,
      ).pushBucket('shelf');
      expect(n, 0);
      expect(await store.outbox('shelf'), hasLength(1));
      expect(log.has('keeping 1 ops queued'), isTrue);
    });

    test('an empty outbox makes no request', () async {
      final r = recordingClient((_) async => fail('must not post'));
      expect(await syncWith(r.client, config: testConfig(key, writableBuckets: {'shelf'})).pushBucket('shelf'), 0);
      expect(r.seen, isEmpty);
    });
  });

  group('one run (§5.6)', () {
    test('a run pulls the active bundle’s read schemas, then pushes', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      final r = recordingClient((req) async {
        if (req.method == 'POST') return http.Response(jsonEncode({'acked': ['op-a'], 'rows': []}), 200);
        return http.Response(jsonEncode({'rows': [row('p', 1, 1)], 'max': 1, 'more': false}), 200);
      });
      final config = testConfig(key, dataSchemas: {'plants': 2}, writableBuckets: {'shelf'});
      final result = await syncWith(r.client, config: config).run(readSchemas: {'plants': 2});
      expect(result.buckets, containsAll(['plants', 'shelf']));
      expect(result.offline, isFalse);
      expect(r.seen.first.url.queryParameters['schema'], '2');
    });

    test('an offline run reports offline rather than throwing', () async {
      final result = await syncWith(
        MockClient((_) => throw const SocketException('no route to host')),
        config: testConfig(key, dataSchemas: {'plants': 1}),
      ).run(readSchemas: {'plants': 1});
      expect(result.offline, isTrue);
      expect(result.changed, 0);
    });

    test('no syncBase means nothing to do, not an error', () async {
      final result = await syncWith(
        MockClient((_) async => fail('must not reach the network')),
        config: testConfig(key, syncBase: ''),
      ).run(readSchemas: {'plants': 1});
      expect(result.buckets, isEmpty);
      expect(result.offline, isFalse);
    });

    test('only filters the run to the named buckets', () async {
      final r = recordingClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200));
      await syncWith(r.client).run(readSchemas: {'plants': 1, 'idx': 1}, only: ['plants']);
      expect(r.seen, hasLength(1));
      expect(r.seen.single.url.path, endsWith('/plants'));
    });

    test('an outbox row for a bucket that is no longer writable is left alone', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      final log = LogSpy();
      await syncWith(
        MockClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200)),
        config: testConfig(key, dataSchemas: {}),
        log: log,
      ).run(readSchemas: {});
      expect(await store.outbox('shelf'), hasLength(1));
      expect(log.has('not writable'), isTrue);
    });
  });

  group('a writable bucket is pulled as well as pushed (§5.5)', () {
    ValenceConfig userCfg() => testConfig(key, dataSchemas: {'plants': 1}, writableBuckets: {'shelf'});

    test('a run pulls every writable bucket, so a second device sees the row', () async {
      // A writable bucket can never appear in `readSchemas`: that is the active manifest's
      // `requires.data`, and both check 5 and the CLI refuse a writable bucket there. Pulled only through
      // that map, a user bucket is push-only — device B never sees device A's row, and a reinstall comes
      // back empty — so §5.5's "A writes 4, A syncs, B writes 7, A syncs leaves A holding 7" is impossible.
      final asked = <String>[];
      final s = syncWith(
        MockClient((req) async {
          asked.add(req.url.path);
          if (req.url.path.endsWith('/shelf')) {
            return http.Response(
              jsonEncode({'rows': [row('from-b', {'n': 7}, 701)], 'max': 701, 'more': false}),
              200,
            );
          }
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
        config: userCfg(),
      );

      final result = await s.run(readSchemas: {'plants': 1});
      expect(asked.any((p) => p.endsWith('/shelf')), isTrue, reason: 'the writable bucket is pulled');
      expect(result.buckets, contains('shelf'));
      expect(await store.get('shelf', 1, 'from-b'), {'n': 7});
      expect(await store.maxUsn('shelf', 1), 701, reason: 'so the next pull is incremental');
    });

    test('a pull never clobbers a write that has not been acknowledged', () async {
      // The pull of a writable bucket is exactly where applyPullPage's outbox skip earns its keep: the row
      // the user just wrote must survive until its own push is acked.
      await store.put('shelf', 'mine', {'n': 4}, opId: 'op-1');
      final s = syncWith(
        MockClient((req) async {
          if (req.url.path.endsWith('/shelf')) {
            return http.Response(
              jsonEncode({'rows': [row('mine', {'n': 99}, 901)], 'max': 901, 'more': false}),
              200,
            );
          }
          if (req.url.path.endsWith('/shelf/push')) {
            return http.Response(jsonEncode({'acked': ['op-1'], 'rows': [row('mine', {'n': 4}, 902)]}), 200);
          }
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
        config: userCfg(),
      );
      await s.run(readSchemas: {'plants': 1});
      expect(await store.get('shelf', 1, 'mine'), {'n': 4}, reason: 'the local write won until it was acked');
      expect(await store.outboxBuckets(), isEmpty, reason: 'and then it was pushed');
    });

    test('`only` still scopes the run', () async {
      final asked = <String>[];
      final s = syncWith(
        MockClient((req) async {
          asked.add(req.url.path);
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
        config: userCfg(),
      );
      await s.run(readSchemas: {'plants': 1}, only: ['shelf']);
      expect(asked.any((p) => p.endsWith('/shelf')), isTrue);
      expect(asked.any((p) => p.endsWith('/plants')), isFalse, reason: 'only scoped it out');
    });
  });
}
