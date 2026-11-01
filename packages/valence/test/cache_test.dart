// Disposable REST data must never become server history or cross an account boundary (§5.5.1).
import 'dart:async';
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
  late Valence v;
  var requests = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    ValenceStore.resetCacheForTests();
    requests = 0;
    v = await Valence.open(
      testConfig(await TestKey.create(),
          dataSchemas: {'days': 1, 'trusted': 1},
          cacheBuckets: {'days'},
          writableBuckets: {'notes'}),
      supportDir: await Directory.systemTemp.createTemp('valence-cache'),
      secure: testSecure({}),
      log: (_) {},
      client: MockClient((_) async {
        requests++;
        return http.Response(
            jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
      }),
    );
  });

  Matcher error(String code) =>
      throwsA(isA<BridgeError>().having((e) => e.code, 'code', code));
  Map<String, Object?> row(String key, Object? value, int usn,
          {bool deleted = false}) =>
      {'k': key, 'v': value, 'u': usn, 'd': deleted ? 1 : 0};

  test(
      'offline cache persists without sync, cursor, freshness, outbox or activation readiness',
      () async {
    final view = _CacheView();
    v.attach(view);
    await v.dataCache('days', 'today', {'sunrise': '06:14'});
    expect(await v.dataGet('days', 'today'), {'sunrise': '06:14'});
    expect(
        (await v.dataGetMany('days', ['missing', 'today', 'today'])).single.usn,
        -2);
    expect(await v.dataCount('days'), 1);
    expect(await v.store.maxUsn('days', 1), 0);
    expect(await v.store.syncedPairs(), isEmpty);
    expect(await v.store.allPairs(), {
      'days': {1}
    });
    final status = await v.syncStatus();
    expect(status.pending, 0);
    expect(status.lastSyncedAt, isNull);
    expect(requests, 0);
    expect(view.scripts, isEmpty);
    ValenceStore.resetCacheForTests();
    final reopened =
        await ValenceStore.open(v.store.path, factory: databaseFactoryFfi);
    expect(await reopened.get('days', 1, 'today'), {'sunrise': '06:14'});
  });

  test(
      'cache overlay, eviction and pull/tombstone precedence preserve server history',
      () async {
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('today', 'server', 7)],
        maxUsnAfter: 7);
    await v.dataCache('days', 'today', 'REST');
    expect(await v.dataGet('days', 'today'), 'REST');
    expect(await v.store.maxUsn('days', 1), 7);
    expect((await v.store.db.query('kv')).single['value'], '"server"');
    expect(await v.dataCount('days'), 1);
    await v.dataCache('days', 'today', null);
    expect(await v.dataGet('days', 'today'), 'server');
    await v.dataCache('days', 'today', 'REST');
    await v.dataCache('days', 'unrelated', 'keep');
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('today', 'new', 8)],
        maxUsnAfter: 8);
    expect(await v.dataGet('days', 'today'), 'new');
    expect((await v.dataList('days')).first.usn, 8);
    await v.dataCache('days', 'today', 'again');
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('today', null, 9, deleted: true)],
        maxUsnAfter: 9);
    expect(await v.dataGet('days', 'today'), isNull);
    expect(await v.dataGet('days', 'unrelated'), 'keep');
    expect(await v.dataCount('days'), 1);
  });

  test(
      'one key-ordered cursor covers mixed sources, duplicates, empty keys and literal prefixes',
      () async {
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('', 0, 1), row('a', 1, 2), row('c', 3, 3)],
        maxUsnAfter: 3);
    for (final key in ['', 'b', 'c', 'd', 'x%_1']) {
      await v.dataCache('days', key, key);
    }
    final seen = <String>[];
    String? after;
    while (true) {
      final page = await v.dataList('days', after: after, limit: 1);
      if (page.isEmpty) break;
      seen.add(page.single.key);
      after = page.single.key;
      // Switching the source of a cursor key must not repeat or skip it.
      if (after == 'c') await v.dataCache('days', 'c', null);
    }
    expect(seen, ['', 'a', 'b', 'c', 'd', 'x%_1']);
    expect(await v.dataCount('days'), 6);
    expect((await v.dataList('days', prefix: 'x%_')).single.key, 'x%_1');
    expect(await v.dataCount('days', prefix: 'x%_'), 1);
    expect(
        (await v.dataGetMany('days', ['d', 'a', 'd', 'none']))
            .map((r) => r.key),
        ['d', 'a']);
  });

  test('read-only boundary, dot keys and encoded byte cap fail before writing',
      () async {
    await expectLater(v.dataCache('unknown', 'k', 1), error('E_PARAMS'));
    await expectLater(v.dataCache('notes', 'k', 1), error('E_DENIED'));
    await expectLater(v.dataCache('trusted', 'k', 1), error('E_DENIED'));
    for (final key in ['.', '..']) {
      await expectLater(v.dataCache('days', key, 1), error('E_PARAMS'));
    }
    await v.dataCache(
        'days', 'cap', 'a' * 65534); // JSON quotes consume two bytes.
    await expectLater(
        v.dataCache('days', 'cap', 'é' * 32768), error('E_TOO_LARGE'));
    expect(await v.dataGet('days', 'cap'), 'a' * 65534);
    expect(await v.store.pendingWrites(), 0);
  });

  test('schema changes isolate caches and GC discovers cache-only pairs',
      () async {
    await v.dataCache('days', 'today', 'old');
    await v.store.cache('days', 2, 'today', 'new');
    expect(await v.store.get('days', 1, 'today'), 'old');
    expect(await v.store.get('days', 2, 'today'), 'new');
    expect(await v.store.allPairs(), {
      'days': {1, 2}
    });
    await v.store.dropPair('days', 1, writableBuckets: {'notes'});
    expect(await v.store.get('days', 1, 'today'), isNull);
    expect(await v.store.get('days', 2, 'today'), 'new');
    expect(await v.store.allPairs(), {
      'days': {2}
    });
    expect(await v.store.syncedPairs(), isEmpty);
  });

  test(
      'a new store build revokes retained overlays before reads without touching server rows',
      () async {
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('today', 'server', 6)],
        maxUsnAfter: 6);
    await v.dataCache('days', 'today', 'REST');
    await v.store.cache('trusted', 1, 'keep', 'granted');
    await v.store.put('notes', 'unsent', 'edit', opId: 'original');
    final updated = await Valence.open(
        v.config.copyWith(cacheBuckets: {'trusted'}),
        supportDir: v.dir.parent,
        secure: v.secure,
        log: (_) {});
    expect(await updated.dataGet('days', 'today'), 'server');
    expect(await updated.dataGet('trusted', 'keep'), 'granted');
    expect(await updated.store.maxUsn('days', 1), 6);
    expect((await updated.store.outbox('notes')).single.id, 'original');
    await expectLater(
        updated.dataCache('days', 'today', 'again'), error('E_DENIED'));
    final disabled = await Valence.open(v.config.copyWith(cacheBuckets: {}),
        supportDir: v.dir.parent, secure: v.secure, log: (_) {});
    expect(await disabled.dataGet('trusted', 'keep'), isNull);
    expect(await disabled.dataGet('days', 'today'), 'server');
  });

  test(
      'account adoption/refresh retain cache; refused switch retains it; switch/sign-out clear it',
      () async {
    final view = _CacheView();
    v.attach(view);
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('synced', 'server', 4)],
        maxUsnAfter: 4);
    await v.dataCache('days', 'private', 'A');
    await v.authSetToken('a', account: 'A');
    await v.authSetToken('a2', account: 'A');
    expect(await v.dataGet('days', 'private'), 'A');
    await v.store.put('notes', 'unsent', 'edit', opId: 'unsent');
    await expectLater(v.authSetToken('b', account: 'B'), error('E_PENDING'));
    expect(await v.dataGet('days', 'private'), 'A');
    view.scripts.clear();
    await v.authSetToken('b', account: 'B', discardPending: true);
    expect(await v.dataGet('days', 'private'), isNull);
    // §5.5.1: the switch's `sync.changed` names the cache-enabled buckets too, or a page holding a
    // rendered list of overlays never learns the rows under it have gone.
    expect(
        view.scripts.where((s) => s.contains('sync.changed')).join(),
        contains('days'));
    // A writable bucket's rows go with the account; a read-only bucket's *synced* rows are not the
    // account's to take, and only the overlay over them is cleared.
    expect(await v.dataGet('days', 'synced'), 'server');
    expect(await v.store.maxUsn('days', 1), 4);
    await v.dataCache('days', 'private', 'B');
    await v.authSetToken(null);
    expect(await v.dataGet('days', 'private'), isNull);
    expect(await v.dataGet('days', 'synced'), 'server');
  });

  test(
      'a cache write already queued behind a transaction is cleared before the new account',
      () async {
    await v.authSetToken('a', account: 'A');
    final entered = Completer<void>();
    final release = Completer<void>();
    final held = v.store.db.transaction((txn) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final write = v.dataCache('days', 'private', 'A');
    final switching = v.authSetToken('b', account: 'B');
    release.complete();
    await Future.wait([held, write, switching]);
    expect(await v.dataGet('days', 'private'), isNull);
    expect(await v.authAccount(), 'B');
  });

  test(
      'seed import replaces only imported cache keys and does not forge sync readiness',
      () async {
    await v.dataCache('days', 'today', 'REST');
    await v.dataCache('days', 'other', 'keep');
    final seed = await databaseFactoryFfi.openDatabase('${v.store.path}.seed');
    await seed
        .execute('CREATE TABLE kv (bucket TEXT, schema INTEGER, key TEXT, '
            'value TEXT, usn INTEGER, deleted INTEGER)');
    await seed.insert('kv', {
      'bucket': 'days',
      'schema': 1,
      'key': 'today',
      'value': '"seed"',
      'usn': 3,
      'deleted': 0
    });
    await seed.close();
    expect(await v.store.importSeed('${v.store.path}.seed', {'days': 1}),
        {'days': 1});
    expect(await v.dataGet('days', 'today'), 'seed');
    expect(await v.dataGet('days', 'other'), 'keep');
    expect(await v.store.syncedPairs(), isEmpty);
  });

  test('v2 upgrade adds cache while retaining server rows and queued writes',
      () async {
    await v.store.put('notes', 'edit', {'text': 'mine'}, opId: 'original');
    await v.store.applyPullPage(
        bucket: 'days',
        schema: 1,
        rows: [row('today', 'server', 8)],
        maxUsnAfter: 8);
    final path = v.store.path;
    await v.store.db.execute('DROP TABLE cache');
    await v.store.db.execute('PRAGMA user_version = 2');
    await v.store.db
        .close(); // Fixture only: simulate an older host before package open.
    ValenceStore.resetCacheForTests();
    final migrated = await ValenceStore.open(path, factory: databaseFactoryFfi);
    expect(
        (await migrated.db.rawQuery('PRAGMA user_version'))
            .single
            .values
            .single,
        3);
    expect(await migrated.get('days', 1, 'today'), 'server');
    expect(await migrated.maxUsn('days', 1), 8);
    expect((await migrated.outbox('notes')).single.id, 'original');
    await migrated.cache('days', 1, 'tomorrow', 'REST');
    expect(await migrated.get('days', 1, 'tomorrow'), 'REST');
  });
}

class _CacheView implements ValenceHostView {
  final scripts = <String>[];
  @override
  bool get pageLoaded => true;
  @override
  void runScript(String script) => scripts.add(script);
  @override
  Future<void> reloadPage() async {}
  @override
  Future<void> handleReady() async {}
}
