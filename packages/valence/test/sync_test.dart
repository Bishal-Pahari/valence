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
      await store.prefSet('valence.sync.lease', '${DateTime(2030).millisecondsSinceEpoch}');
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)));
      expect(await s.acquireLease(), isTrue);
    });

    test('a non-numeric lease value does not wedge sync', () async {
      await store.prefSet('valence.sync.lease', 'not a number');
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
      expect(await store.prefGet('valence.sync.lease'), isNull);
    });

    test('run skips when another sync holds the lease', () async {
      final other = syncWith(MockClient((_) async => http.Response('{}', 200)));
      await other.acquireLease();
      final log = LogSpy();
      final s = syncWith(MockClient((_) async => fail('must not reach the network')), log: log);
      final result = await s.run(readSchemas: {'plants': 1});
      expect(result.changed, 0);
      expect(log.has('another sync holds the lease'), isTrue);
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
}
