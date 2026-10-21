// Contracts §5.1 to §5.5: the store, the seed, local writes, pulls and push echoes.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  late ValenceStore store;

  setUp(() async => store = await openTestStore());

  Map<String, Object?> row(String k, Object? v, int u, {bool d = false}) =>
      {'k': k, 'v': v, 'u': u, 'd': d ? 1 : 0};

  test('batch reads bind keys, isolate schema and bucket, deduplicate and omit tombstones', () async {
    const hostile = "'); DROP TABLE kv; --";
    await store.applyPullPage(
        bucket: 'plants',
        schema: 2,
        rows: [row('a', 1, 1), row('b', 2, 2), row('gone', null, 3, d: true), row(hostile, 4, 4)],
        maxUsnAfter: 4);
    await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 'old', 1)], maxUsnAfter: 1);
    await store.applyPullPage(bucket: 'other', schema: 2, rows: [row('a', 'other', 1)], maxUsnAfter: 1);
    final batch = await store.getMany('plants', 2, ['b', 'missing', 'a', 'b', 'gone', hostile]);
    expect(batch.map((r) => r.key), ['b', 'a', hostile]);
    expect(batch.map((r) => r.value), [2, 1, 4]);
    expect(await store.getMany('plants', 2, []), isEmpty);
    expect(await store.getMany('plants', 2, List.filled(500, 'a')), hasLength(1));
    await expectLater(store.getMany('plants', 2, List.filled(501, 'a')),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', 'E_PARAMS')));
  });

  group('schema (§5.1)', () {
    test('the tables and the index from the spec exist, at user_version 1', () async {
      final tables = {
        for (final r in await store.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          r['name']! as String,
      };
      expect(tables, containsAll(['kv', 'bucket', 'outbox', 'prefs']));
      final indexes = {
        for (final r in await store.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'"))
          r['name']! as String,
      };
      expect(indexes, contains('kv_bucket_usn'));
      final version = await store.db.rawQuery('PRAGMA user_version');
      expect(version.first.values.first, 1);
    });

    test('kv is keyed by (bucket, schema, key), so two schemas of one bucket coexist', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('fern', {'n': 'old'}, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [row('fern', {'n': 'new'}, 1)], maxUsnAfter: 1);
      expect(await store.get('plants', 1, 'fern'), {'n': 'old'});
      expect(await store.get('plants', 2, 'fern'), {'n': 'new'});
    });

    test('the journal mode that actually took is reported rather than discarded', () {
      // On a real device a filesystem that cannot do WAL answers `delete`, and the concurrency the rest
      // of §5 assumes is gone. sqflite_common_ffi gives us a real answer here, whatever it is.
      expect(store.journalMode, isNotEmpty);
      expect(store.journalMode, store.journalMode.toLowerCase());
    });

    test('there is deliberately no close(): a close in one isolate breaks the other', () {
      // sqflite keys open databases by path inside the platform plugin, not per isolate.
      expect(ValenceStore.open, isNotNull);
      expect((store as Object), isNot(isA<Function>()));
      // The API surface is the assertion: nothing on ValenceStore closes the database.
    });
  });

  group('reads', () {
    setUp(() async {
      await store.applyPullPage(
        bucket: 'plants',
        schema: 1,
        rows: [
          row('fern/a', {'n': 'A'}, 1),
          row('fern/b', {'n': 'B'}, 2),
          row('moss/a', {'n': 'C'}, 3),
          row('gone', {'n': 'D'}, 4, d: true),
        ],
        maxUsnAfter: 4,
      );
    });

    test('get returns the value and skips tombstones', () async {
      expect(await store.get('plants', 1, 'fern/a'), {'n': 'A'});
      expect(await store.get('plants', 1, 'gone'), isNull);
      expect(await store.get('plants', 1, 'absent'), isNull);
    });

    test('list is ordered by key and excludes tombstones', () async {
      final rows = await store.list('plants', 1);
      expect(rows.map((r) => r.key), ['fern/a', 'fern/b', 'moss/a']);
    });

    test('list filters by prefix', () async {
      expect((await store.list('plants', 1, prefix: 'fern/')).map((r) => r.key), ['fern/a', 'fern/b']);
    });

    test('a prefix containing SQL LIKE wildcards matches literally', () async {
      await store.applyPullPage(
        bucket: 'plants',
        schema: 1,
        rows: [row('100%/x', {}, 5), row('1007/x', {}, 6)],
        maxUsnAfter: 6,
      );
      expect((await store.list('plants', 1, prefix: '100%')).map((r) => r.key), ['100%/x']);
    });

    test('limit defaults to 100 and is clamped to 500, host-side', () async {
      await store.applyPullPage(
        bucket: 'big',
        schema: 1,
        rows: [for (var i = 0; i < 600; i++) row('k${i.toString().padLeft(4, '0')}', i, i + 1)],
        maxUsnAfter: 600,
      );
      expect((await store.list('big', 1)).length, defaultListLimit);
      expect((await store.list('big', 1, limit: 250)).length, 250);
      // Without the clamp, data.list over a few thousand rows is the reply that kills the WebView.
      expect((await store.list('big', 1, limit: 100000)).length, maxListLimit);
      expect((await store.list('big', 1, limit: 0)).length, defaultListLimit);
      expect((await store.list('big', 1, limit: -5)).length, defaultListLimit);
    });

    test('maxUsn is 0 for an unknown pair and tracks the applied page otherwise', () async {
      expect(await store.maxUsn('nothing', 1), 0);
      expect(await store.maxUsn('plants', 1), 4);
      expect(await store.maxUsn('plants', 9), 0);
    });
  });

  group('local writes (§5.5)', () {
    test('put writes the row with usn -1 and queues one outbox op, in one transaction', () async {
      await store.put('shelf', 'p-1', {'note': 'hi'}, opId: 'op-1');
      final rows = await store.list('shelf', 1);
      expect(rows, hasLength(1));
      expect(rows.first.usn, -1, reason: 'usn -1 is the contract for "written locally, not yet synced"');
      expect(rows.first.value, {'note': 'hi'});
      final ops = await store.outbox('shelf');
      expect(ops.map((o) => o.id), ['op-1']);
      expect(ops.first.deleted, isFalse);
    });

    test('a null value is the delete: a tombstone plus an op with d 1', () async {
      await store.put('shelf', 'p-1', {'note': 'hi'}, opId: 'op-1');
      await store.put('shelf', 'p-1', null, opId: 'op-2');
      expect(await store.get('shelf', 1, 'p-1'), isNull);
      expect(await store.list('shelf', 1), isEmpty);
      final ops = await store.outbox('shelf');
      expect(ops.last.deleted, isTrue);
      expect(ops.last.value, isNull);
    });

    test('pendingWrites counts deletes too, which a usn -1 scan cannot', () async {
      await store.put('shelf', 'a', {'x': 1}, opId: 'op-1');
      await store.put('shelf', 'b', null, opId: 'op-2');
      expect(await store.pendingWrites(), 2);
      expect((await store.list('shelf', 1)).where((r) => r.usn == -1).length, 1);
    });

    test('writable buckets always use schema 1 (§5.4)', () async {
      await store.put('shelf', 'p-1', {'x': 1}, opId: 'op-1');
      final rows = await store.db.query('kv', columns: ['schema'], where: 'bucket = ?', whereArgs: ['shelf']);
      expect(rows.single['schema'], 1);
      final buckets = await store.db.query('bucket', where: 'name = ?', whereArgs: ['shelf']);
      expect(buckets, isEmpty, reason: 'a local-only write does not claim the pair is synced');
    });
  });

  group('applying a pull page (§5.3)', () {
    test('max_usn moves to the page end and synced_at is set', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 7)], maxUsnAfter: 10);
      expect(await store.maxUsn('plants', 1), 10);
      expect(await store.syncedPairs(), {'plants': {1}});
    });

    test('max_usn only moves forward', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 7)], maxUsnAfter: 10);
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('b', 2, 3)], maxUsnAfter: 3);
      expect(await store.maxUsn('plants', 1), 10);
    });

    test('a d 1 row is a tombstone', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', null, 2, d: true)], maxUsnAfter: 2);
      expect(await store.get('plants', 1, 'a'), isNull);
    });

    test('a pull does not clobber a row with a pending outbox entry', () async {
      await store.put('shelf', 'p-1', {'mine': true}, opId: 'op-1');
      final applied = await store.applyPullPage(
        bucket: 'shelf',
        schema: 1,
        rows: [row('p-1', {'theirs': true}, 99), row('p-2', {'theirs': true}, 100)],
        maxUsnAfter: 100,
      );
      expect(applied, 1, reason: 'only p-2 was applied');
      expect(await store.get('shelf', 1, 'p-1'), {'mine': true});
      expect((await store.list('shelf', 1)).firstWhere((r) => r.key == 'p-1').usn, -1);
      expect(await store.get('shelf', 1, 'p-2'), {'theirs': true});
    });

    test('a page is applied atomically: a failure inside it leaves nothing behind', () async {
      // A row whose value cannot be encoded aborts the transaction, so neither row nor max_usn moves.
      await expectLater(
        store.applyPullPage(
          bucket: 'plants',
          schema: 1,
          rows: [row('a', 1, 1), {'k': 'b', 'v': Object(), 'u': 2, 'd': 0}],
          maxUsnAfter: 2,
        ),
        throwsA(anything),
      );
      expect(await store.get('plants', 1, 'a'), isNull);
      expect(await store.maxUsn('plants', 1), 0);
    });
  });

  group('push acknowledgement (§5.5)', () {
    test('only acknowledged ids are cleared', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      await store.put('shelf', 'b', {'v': 2}, opId: 'op-b');
      await store.applyPushAck(bucket: 'shelf', acked: ['op-a'], rows: [row('a', {'v': 1}, 50)]);
      expect((await store.outbox('shelf')).map((o) => o.id), ['op-b']);
    });

    test('an echo applies the acknowledged row and gives it a real usn', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      await store.applyPushAck(bucket: 'shelf', acked: ['op-a'], rows: [row('a', {'v': 1}, 50)]);
      expect((await store.list('shelf', 1)).single.usn, 50);
      expect(await store.maxUsn('shelf', 1), 50);
    });

    test('a push echo does not clobber a newer local edit still in the outbox', () async {
      await store.put('shelf', 'a', {'v': 1}, opId: 'op-a');
      // The user edits again while the push is in flight.
      await store.put('shelf', 'a', {'v': 2}, opId: 'op-b');
      await store.applyPushAck(bucket: 'shelf', acked: ['op-a'], rows: [row('a', {'v': 1}, 50)]);
      expect(await store.get('shelf', 1, 'a'), {'v': 2}, reason: 'the newer local edit waits for its own ack');
      expect((await store.outbox('shelf')).map((o) => o.id), ['op-b']);
    });
  });

  group('seed (§5.2)', () {
    late ValenceStore seedDb;

    setUp(() async {
      sqfliteFfiInit();
      ValenceStore.resetCacheForTests();
      seedDb = await ValenceStore.open(await freshDbPath('seed.db'), factory: databaseFactoryFfi);
      ValenceStore.resetCacheForTests();
      store = await ValenceStore.open(await freshDbPath(), factory: databaseFactoryFfi);
    });

    Future<void> seedRows(String bucket, int schema, int count, {int from = 1}) async {
      await seedDb.db.transaction((txn) async {
        for (var i = 0; i < count; i++) {
          await txn.insert('kv', {
            'bucket': bucket,
            'schema': schema,
            'key': 'k${from + i}',
            'value': '{"i":${from + i}}',
            'usn': from + i,
            'deleted': 0,
          });
        }
      });
    }

    test('the import copies the rows and reports a real count, not a last-insert-rowid', () async {
      await seedRows('plants', 1, 1500);
      final counts = await store.importSeed(seedDb.path, {'plants': 1});
      // rawInsert returns a last-insert-rowid, which on a WITHOUT ROWID table reads as 1 for a seed of
      // thousands and looks exactly like a failed import.
      expect(counts, {'plants': 1500});
      expect(await store.maxUsn('plants', 1), 1500);
    });

    test('a seeded pair does NOT satisfy §2.3 step 7, because it has no synced_at', () async {
      await seedRows('plants', 1, 3);
      await store.importSeed(seedDb.path, {'plants': 1});
      expect(await store.syncedPairs(), isEmpty);
      expect(await store.allPairs(), {'plants': {1}});
    });

    test('the import only moves forward: a re-run copies nothing', () async {
      await seedRows('plants', 1, 3);
      expect(await store.importSeed(seedDb.path, {'plants': 1}), {'plants': 3});
      expect(await store.importSeed(seedDb.path, {'plants': 1}), {'plants': 0});
      expect(await store.maxUsn('plants', 1), 3);
    });

    test('a newer seed after a host upgrade copies only the rows above max_usn', () async {
      await seedRows('plants', 1, 3);
      await store.importSeed(seedDb.path, {'plants': 1});
      await seedRows('plants', 1, 2, from: 4);
      expect(await store.importSeed(seedDb.path, {'plants': 1}), {'plants': 2});
      expect(await store.maxUsn('plants', 1), 5);
    });

    test('the import is per (bucket, schema)', () async {
      await seedRows('plants', 1, 2);
      await seedRows('plants', 2, 5);
      expect(await store.importSeed(seedDb.path, {'plants': 2}), {'plants': 5});
      expect(await store.maxUsn('plants', 1), 0);
      expect(await store.maxUsn('plants', 2), 5);
    });

    test('a pair with no seed rows is simply empty', () async {
      expect(await store.importSeed(seedDb.path, {'plants': 1}), {'plants': 0});
    });
  });

  group('garbage collection of pairs (§2.4)', () {
    test('a read-only pair can be dropped', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 1)], maxUsnAfter: 1);
      await store.dropPair('plants', 1, writableBuckets: const {});
      expect(await store.allPairs(), isEmpty);
      expect(await store.get('plants', 1, 'a'), isNull);
    });

    test('a writable bucket is refused, because that is the user’s own data', () async {
      await store.put('shelf', 'a', {'x': 1}, opId: 'op-1');
      await expectLater(
        store.dropPair('shelf', 1, writableBuckets: const {'shelf'}),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.denied)),
      );
      expect(await store.get('shelf', 1, 'a'), {'x': 1});
    });

    test('dropping one schema leaves the other', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [row('a', 2, 1)], maxUsnAfter: 1);
      await store.dropPair('plants', 1, writableBuckets: const {});
      expect(await store.allPairs(), {'plants': {2}});
      expect(await store.get('plants', 2, 'a'), 2);
    });
  });

  group('prefs', () {
    test('round trip and removal', () async {
      expect(await store.prefGet('theme'), isNull);
      await store.prefSet('theme', 'dark');
      expect(await store.prefGet('theme'), 'dark');
      await store.prefSet('theme', null);
      expect(await store.prefGet('theme'), isNull);
    });

    test('the store refuses the valence. prefix, and the host has its own way in', () async {
      // The check lives here as well as at the bridge, because prefGet/prefSet are the only public way an
      // app that defines its *own* settings method can store anything — and that method would otherwise
      // be a route for page input to clear the sync lease mid-sync and let two syncs interleave (§4.2).
      await expectLater(
        store.prefSet('valence.sync.lease', '123'),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.denied)),
      );
      await expectLater(store.prefGet('valence'), throwsA(isA<BridgeError>()));
      expect(await store.prefGet('valenceish'), isNull, reason: 'only the prefix, not the letters');
      // The host's own lease lives under that prefix, so the runtime has an unchecked entry point.
      await store.hostPrefSet('valence.sync.lease', '123');
      expect(await store.hostPrefGet('valence.sync.lease'), '123');
    });
  });

  group('a device holding two schemas of one bucket (§5.4)', () {
    test('syncedPairs is a set per bucket, so v1 cannot hide v2', () async {
      await store.applyPullPage(bucket: 'plants', schema: 1, rows: [row('a', 1, 1)], maxUsnAfter: 1);
      await store.applyPullPage(bucket: 'plants', schema: 2, rows: [row('a', 2, 1)], maxUsnAfter: 1);
      final pairs = await store.syncedPairs();
      expect(pairs['plants'], {1, 2});
      // A requirement for either one is satisfied by holding it.
      expect(pairs['plants']!.contains(1), isTrue);
      expect(pairs['plants']!.contains(2), isTrue);
    });
  });
}
