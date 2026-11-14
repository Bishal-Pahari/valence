import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  late ValenceStore store;
  late TestKey key;
  setUpAll(() async => key = await TestKey.create());
  setUp(() async => store = await openTestStore());
  Map<String, Object?> row(String k, int u) => {'k': k, 'v': u, 'u': u, 'd': 0};

  test('CR-1 push echo never skips an interleaved other-device write', () async {
    await store.applyPullPage(bucket: 'notes', schema: 1, rows: [row('old', 100)], maxUsnAfter: 100);
    await store.put('notes', 'mine', 102, opId: 'op');
    await store.applyPushAck(bucket: 'notes', acked: ['op'], rows: [row('mine', 102)]);
    final sync = ValenceSync(
        store: store,
        config: testConfig(key, writableBuckets: {'notes'}),
        client: MockClient((req) async {
          final since = int.parse(req.url.queryParameters['since']!);
          return http.Response(
              jsonEncode({
                'rows': [if (since < 101) row('other', 101), if (since < 102) row('mine', 102)],
                'max': 102,
                'more': false
              }),
              200);
        }));
    await sync.pullPair('notes', 1);
    expect(await store.get('notes', 1, 'other'), 101);
    expect(await store.maxUsn('notes', 1), 102);
  });

  test('CR-2 F-29 pulls 600 rows when max names the later server head', () async {
    final cursors = <int>[];
    final sync = ValenceSync(
        store: store,
        config: testConfig(key),
        client: MockClient((req) async {
          final since = int.parse(req.url.queryParameters['since']!);
          cursors.add(since);
          final rows = [for (var u = since + 1; u <= 600 && u <= since + 500; u++) row('k$u', u)];
          return http.Response(jsonEncode({'rows': rows, 'max': 600, 'more': since < 500}), 200);
        }));
    expect(await sync.pullPair('catalog', 2), 600);
    expect(cursors, [0, 500]);
    expect(await store.get('catalog', 2, 'k600'), 600);
  });

  for (final mode in ['http', 'budget', 'throw']) {
    test('CR-3 partial $mode pull cannot mark a fresh pair complete and resumes progress', () async {
      var first = true;
      var repaired = false;
      final sync = ValenceSync(
          store: store,
          config: testConfig(key),
          client: MockClient((req) async {
            final since = int.parse(req.url.queryParameters['since']!);
            if (since == 0) {
              return http.Response(
                  jsonEncode({
                    'rows': [row('a', 1)],
                    'max': 1,
                    'more': true
                  }),
                  200);
            }
            if (!repaired) {
              first = false;
              if (mode == 'throw') throw http.ClientException('lost connection');
              return http.Response('unavailable', 500);
            }
            return http.Response(
                jsonEncode({
                  'rows': [row('b', 2)],
                  'max': 2,
                  'more': false
                }),
                200);
          }));
      try {
        await sync.pullPair('catalog', 2, byteBudget: mode == 'budget' ? 1 : null);
      } on http.ClientException {/* expected */}
      expect((await store.syncedPairs())['catalog'], isNull);
      expect(await store.maxUsn('catalog', 2), 1);
      if (mode != 'budget') expect(first, isFalse);
      repaired = true;
      await sync.pullPair('catalog', 2);
      expect((await store.syncedPairs())['catalog'], {2});
      expect(await store.get('catalog', 2, 'b'), 2);
    });
  }

  test('CR-6 outbox insertion order survives equal or backwards clocks and VACUUM', () async {
    await store.put('notes', 'k', 1, opId: 'z-first');
    await store.put('notes', 'k', 2, opId: 'a-second');
    await store.db.update('outbox', {'created_at': 100});
    expect((await store.outbox('notes')).map((o) => o.id), ['z-first', 'a-second']);
    await store.db.update('outbox', {'created_at': 0}, where: 'id = ?', whereArgs: ['a-second']);
    await store.db.execute('VACUUM');
    expect((await store.outbox('notes')).map((o) => o.id), ['z-first', 'a-second']);
  });
  for (final budget in [false, true]) {
    test('CR-3 static partial chunks stay incomplete until resumed budget=$budget', () async {
      var recovered = false;
      final sync = ValenceSync(
          store: store,
          config: testConfig(key, syncMode: ValenceSyncMode.staticChunks),
          client: MockClient((req) async {
            if (req.url.path.endsWith('index.json')) {
              return http.Response(
                  jsonEncode([
                    {'from': 1, 'to': 1, 'file': 'one.json'},
                    {'from': 2, 'to': 2, 'file': 'two.json'}
                  ]),
                  200);
            }
            if (req.url.path.endsWith('one.json')) {
              return http.Response(
                  jsonEncode({
                    'rows': [row('a', 1)],
                    'max': 1
                  }),
                  200);
            }
            if (!recovered) return http.Response('down', 500);
            return http.Response(
                jsonEncode({
                  'rows': [row('b', 2)],
                  'max': 2
                }),
                200);
          }));
      await sync.pullPair('catalog', 2, byteBudget: budget ? 1 : null);
      expect((await store.syncedPairs())['catalog'], isNull);
      expect(await store.maxUsn('catalog', 2), 1);
      recovered = true;
      await sync.pullPair('catalog', 2, byteBudget: 1);
      expect((await store.syncedPairs())['catalog'], {2});
      expect(await store.get('catalog', 2, 'b'), 2);
    });
  }
}
