// Migrating a 0.3 app, whose host was generated into its own repo, onto this package.
//
// The point of these tests is data safety. A 0.3 app has real user rows in `kv` and `outbox`, a pulled
// `max_usn` per pair, and a `state.json` holding `current`, `floor` and `bad`. None of it may be lost,
// re-pulled from zero, or re-trialled when the host runtime is swapped underneath it.
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
  late Directory documents;

  setUpAll(() async {
    key = await TestKey.create();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    support = await Directory.systemTemp.createTemp('valence-migration');
    // On Android these two are `files` and `app_flutter`, and 0.3's §5.1 allowed either.
    documents = await Directory.systemTemp.createTemp('valence-migration-docs');
    ValenceStore.resetCacheForTests();
  });

  /// Builds the database a 0.3 generated host would have left behind.
  ///
  /// The §5.1 schema has not changed, so this is written with raw SQL rather than through the package, to
  /// prove the package reads a file it did not create.
  Future<void> writeLegacyDatabase(String fileName, {Directory? dir}) async {
    final db = await databaseFactoryFfi.openDatabase('${(dir ?? support).path}${Platform.pathSeparator}$fileName');
    await db.execute(
      'CREATE TABLE kv (bucket TEXT NOT NULL, schema INTEGER NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, '
      'usn INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (bucket, schema, key)) WITHOUT ROWID',
    );
    await db.execute('CREATE INDEX kv_bucket_usn ON kv (bucket, schema, usn)');
    await db.execute(
      'CREATE TABLE bucket (name TEXT NOT NULL, schema INTEGER NOT NULL, max_usn INTEGER NOT NULL, '
      'synced_at INTEGER, PRIMARY KEY (name, schema))',
    );
    await db.execute(
      'CREATE TABLE outbox (id TEXT PRIMARY KEY, bucket TEXT NOT NULL, key TEXT NOT NULL, value TEXT, '
      'deleted INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
    );
    await db.execute('CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('PRAGMA user_version = 1');

    // Pulled read-only data, at two schemas, as a device mid-bump holds it.
    for (final pair in [(1, 'old'), (2, 'new')]) {
      await db.insert('kv', {
        'bucket': 'plants',
        'schema': pair.$1,
        'key': 'fern',
        'value': jsonEncode({'name': 'Fern', 'gen': pair.$2}),
        'usn': 1500,
        'deleted': 0,
      });
      await db.insert('bucket', {
        'name': 'plants',
        'schema': pair.$1,
        'max_usn': 1500,
        'synced_at': 1792000000000,
      });
    }
    // The user's own rows: one synced, one still queued, one pending delete.
    await db.insert('kv', {
      'bucket': 'shelf',
      'schema': 1,
      'key': 'p-1',
      'value': jsonEncode({'note': 'synced'}),
      'usn': 77,
      'deleted': 0,
    });
    await db.insert('bucket', {'name': 'shelf', 'schema': 1, 'max_usn': 77, 'synced_at': 1792000000000});
    await db.insert('kv', {
      'bucket': 'shelf',
      'schema': 1,
      'key': 'p-2',
      'value': jsonEncode({'note': 'mine, not yet pushed'}),
      'usn': -1,
      'deleted': 0,
    });
    await db.insert('outbox', {
      'id': 'legacy-op-1',
      'bucket': 'shelf',
      'key': 'p-2',
      'value': jsonEncode({'note': 'mine, not yet pushed'}),
      'deleted': 0,
      'created_at': 1792000000000,
    });
    await db.insert('kv', {
      'bucket': 'shelf',
      'schema': 1,
      'key': 'p-3',
      'value': 'null',
      'usn': -1,
      'deleted': 1,
    });
    await db.insert('outbox', {
      'id': 'legacy-op-2',
      'bucket': 'shelf',
      'key': 'p-3',
      'value': null,
      'deleted': 1,
      'created_at': 1792000000001,
    });
    await db.insert('prefs', {'key': 'theme', 'value': 'dark'});
    await db.close();
    // Closed here only because this is the fixture writer, standing in for the old process exiting.
    ValenceStore.resetCacheForTests();
  }

  /// Writes the `state.json` a 0.3 host would have left, at the same path this package uses.
  void writeLegacyState(Map<String, Object?> state) {
    final dir = Directory('${support.path}${Platform.pathSeparator}valence')..createSync(recursive: true);
    File('${dir.path}${Platform.pathSeparator}state.json').writeAsStringSync(jsonEncode(state));
  }

  Future<Valence> openPackage({String databaseName = 'valence.db', Directory? documentsDir}) => Valence.open(
        ValenceConfig(
          appId: 'com.example.app',
          keyring: {key.keyId: key.publicKeyBase64},
          bridgeVersion: 1,
          otaBase: 'https://ota.test',
          syncBase: 'https://sync.test',
          writableBuckets: const {'shelf'},
          dataSchemas: const {'plants': 2},
          databaseName: databaseName,
        ),
        log: LogSpy().call,
        client: MockClient(
          (_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200),
        ),
        supportDir: support,
        documentsDir: documentsDir ?? documents,
      );

  group('the database carries over unchanged', () {
    test('a 0.3 database whose file name was valence.db opens with every row intact', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();

      expect(await v.dataGet('plants', 'fern'), {'name': 'Fern', 'gen': 'new'},
          reason: 'resolved against the configured schema 2');
      expect(await v.store.get('plants', 1, 'fern'), {'name': 'Fern', 'gen': 'old'},
          reason: 'the old schema is still readable, so a revert is safe');
      expect(await v.dataGet('shelf', 'p-1'), {'note': 'synced'});
      expect(await v.dataGet('shelf', 'p-2'), {'note': 'mine, not yet pushed'});
      expect(await v.prefsGet('theme'), 'dark');
    });

    test('a 0.3 database under its own file name opens when databaseName points at it', () async {
      // This is the one knob a 0.3 adopter has to set: generated hosts picked their own name.
      await writeLegacyDatabase('fieldnote.db');
      final v = await openPackage(databaseName: 'fieldnote.db');
      expect(await v.dataGet('shelf', 'p-1'), {'note': 'synced'});
      expect(await v.pendingWrites(), 2);
    });

    test('pointing at the wrong name creates an empty store instead of destroying the old one', () async {
      // The failure mode to rule out: a silent fresh start that looks like data loss. The old file is
      // untouched, so setting databaseName correctly recovers everything.
      await writeLegacyDatabase('fieldnote.db');
      final v = await openPackage();
      expect(await v.dataGet('shelf', 'p-1'), isNull);
      ValenceStore.resetCacheForTests();
      final recovered = await openPackage(databaseName: 'fieldnote.db');
      expect(await recovered.dataGet('shelf', 'p-1'), {'note': 'synced'});
    });

    test('the outbox survives, so unsent writes are still sent', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      final ops = await v.store.outbox('shelf');
      expect(ops.map((o) => o.id), ['legacy-op-1', 'legacy-op-2']);
      expect(ops.last.deleted, isTrue, reason: 'the pending delete is still a delete');
      expect(await v.pendingWrites(), 2);
    });

    test('a queued write is pushed with its original op id, so it stays idempotent', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      final posted = <String>[];
      final sync = ValenceSync(
        store: v.store,
        config: v.config,
        client: MockClient((req) async {
          if (req.method == 'POST') {
            posted.addAll([
              for (final op in (jsonDecode(req.body) as Map)['ops']! as List) (op as Map)['id']! as String,
            ]);
            return http.Response(jsonEncode({'acked': posted, 'rows': []}), 200);
          }
          return http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200);
        }),
      );
      await sync.pushBucket('shelf');
      expect(posted, ['legacy-op-1', 'legacy-op-2']);
      expect(await v.store.outbox('shelf'), isEmpty);
    });

    test('max_usn carries over, so no pair re-pulls from zero', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      expect(await v.store.maxUsn('plants', 1), 1500);
      expect(await v.store.maxUsn('plants', 2), 1500);
      expect(await v.store.maxUsn('shelf', 1), 77);

      final seen = <String>[];
      final sync = ValenceSync(
        store: v.store,
        config: v.config,
        client: MockClient((req) async {
          seen.add(req.url.toString());
          return http.Response(jsonEncode({'rows': [], 'max': 1500, 'more': false}), 200);
        }),
      );
      await sync.pullPair('plants', 2);
      expect(seen.single, contains('since=1500'));
      expect(seen.single, isNot(contains('since=0')),
          reason: 'a restart from zero would re-apply 1500 rows on every launch, for ever');
    });

    test('both schemas still count as synced, so a schema bump is not re-gated', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      expect(await v.store.syncedPairs(), {
        'plants': {1, 2},
        'shelf': {1}
      });
    });

    test('v1 outbox migration preserves insertion order, ids, values and deletes', () async {
      await writeLegacyDatabase('valence.db');
      final db = await databaseFactoryFfi.openDatabase('${support.path}/valence.db');
      await db.update('outbox', {'id': 'z-first', 'created_at': 100}, where: 'id = ?', whereArgs: ['legacy-op-1']);
      await db.update('outbox', {'id': 'a-second', 'created_at': 0}, where: 'id = ?', whereArgs: ['legacy-op-2']);
      await db.close();
      final v = await openPackage();
      var ops = await v.store.outbox('shelf');
      expect(ops.map((o) => o.id), ['z-first', 'a-second']);
      expect(jsonDecode(ops.first.value!), {'note': 'mine, not yet pushed'});
      expect(ops.last.deleted, isTrue);
      expect(ops.last.value, isNull);
      await v.store.put('shelf', 'p-4', 'new', opId: '0-new');
      await v.store.db.execute('VACUUM');
      ValenceStore.resetCacheForTests();
      final reopened = await openPackage();
      ops = await reopened.store.outbox('shelf');
      expect(ops.map((o) => o.id), ['z-first', 'a-second', '0-new']);
      expect(await reopened.store.maxUsn('plants', 2), 1500);
    });

    test('user_version upgrades to 2 without losing old outbox data', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      final version = await v.store.db.rawQuery('PRAGMA user_version');
      expect(version.first.values.first, 2);
    });
  });

  group('the update state carries over unchanged', () {
    test('current, floor and bad are read as the 0.3 host wrote them', () async {
      writeLegacyState({
        'installId': '11111111-2222-4333-8444-555555555555',
        'port': 17899,
        'current': 1792169481,
        'previous': 1792100000,
        'pending': null,
        'trial': null,
        'trialFails': 0,
        'serving': null,
        'bad': [1792168990],
        'floor': 1792000000,
      });
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      expect(v.state.installId, '11111111-2222-4333-8444-555555555555',
          reason: 'the rollout cohort and the port must not change under the user');
      expect(v.state.port, 17899, reason: 'otherwise the origin moves and web storage is lost');
      expect(v.state.current, 1792169481);
      expect(v.state.previous, 1792100000);
      expect(v.state.floor, 1792000000);
      expect(v.state.bad, [1792168990], reason: 'a bundle this install rejected stays rejected');
    });

    test('a 0.3 state mid-trial is honoured rather than reset', () async {
      writeLegacyState({
        'installId': 'i',
        'current': 100,
        'trial': 200,
        'trialFails': 1,
        'serving': 200,
        'bad': <int>[],
        'floor': 0,
      });
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      expect(v.state.trial, 200);
      expect(v.state.trialFails, 1, reason: 'the strike already spent is not forgiven');
      expect(v.state.serving, 200);
    });

    test('a 0.3 state with extra fields a newer host writes is still readable', () async {
      writeLegacyState({'installId': 'i', 'current': 100, 'somethingNewer': {'a': 1}});
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      expect(v.state.current, 100);
    });

    test('no state.json at all is a clean first launch, not an error', () async {
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      expect(v.state.current, isNull);
      expect(v.state.installId, isNotEmpty);
    });

    test('the package writes the state back at the same path', () async {
      writeLegacyState({'installId': 'i', 'current': 100});
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      v.state.pending = 150;
      v.updater.save();
      final onDisk = jsonDecode(
        File('${support.path}${Platform.pathSeparator}valence${Platform.pathSeparator}state.json')
            .readAsStringSync(),
      ) as Map<String, Object?>;
      expect(onDisk['current'], 100);
      expect(onDisk['pending'], 150);
      expect(onDisk['installId'], 'i');
    });
  });

  group('a 0.3 database in the documents directory is adopted', () {
    // The failure this rules out is total, silent, user-visible data loss on upgrade: 0.3's §5.1 named no
    // directory, so a conforming host could have used documents, and 0.4 opens appSupport. Without the
    // move the user sees a fresh install with their rows still on disk, and `host.database` — a file name,
    // not a path — cannot reach them.
    String docPath(String name) => '${documents.path}${Platform.pathSeparator}$name';
    String supportPath(String name) => '${support.path}${Platform.pathSeparator}$name';

    test('every row arrives, and the write-ahead-log sidecars move with the database', () async {
      await writeLegacyDatabase('valence.db', dir: documents);
      // Stand-ins for a real WAL and shared-memory file. Moving the `.db` alone would discard every commit
      // still in the log, which for a syncing app is the last sync.
      File(docPath('valence.db-wal')).writeAsStringSync('wal-bytes');
      File(docPath('valence.db-shm')).writeAsStringSync('shm-bytes');
      final log = LogSpy();

      final v = await Valence.open(
        ValenceConfig(
          appId: 'com.example.app',
          keyring: {key.keyId: key.publicKeyBase64},
          bridgeVersion: 1,
          otaBase: 'https://ota.test',
          writableBuckets: const {'shelf'},
          dataSchemas: const {'plants': 2},
        ),
        log: log.call,
        client: MockClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200)),
        supportDir: support,
        documentsDir: documents,
      );

      expect(await v.dataGet('shelf', 'p-1'), {'note': 'synced'});
      expect(await v.dataGet('plants', 'fern'), {'name': 'Fern', 'gen': 'new'});
      expect(await v.pendingWrites(), 2, reason: 'the outbox came too, so unsent writes are not lost');
      expect(await v.store.maxUsn('plants', 2), 1500, reason: 'the cursor came too, so nothing re-pulls from zero');
      expect(File(supportPath('valence.db-wal')).existsSync(), isTrue);
      expect(File(supportPath('valence.db-shm')).existsSync(), isTrue);
      expect(File(docPath('valence.db')).existsSync(), isFalse, reason: 'moved, not copied');
      expect(log.lines.join('\n'), contains('moved the 0.3 database'),
          reason: 'an operator reading the log can tell this happened');
    });

    test('it respects the configured file name', () async {
      await writeLegacyDatabase('fieldnote.db', dir: documents);
      final v = await openPackage(databaseName: 'fieldnote.db');
      expect(await v.dataGet('shelf', 'p-1'), {'note': 'synced'});
      expect(File(supportPath('fieldnote.db')).existsSync(), isTrue);
    });

    test('an existing appSupport database wins, and the legacy file is left untouched', () async {
      // Two databases means the app has already run on 0.4. Overwriting the live one with a stale copy
      // would be the same data loss in the other direction, so the move does not happen at all.
      await writeLegacyDatabase('valence.db');
      await writeLegacyDatabase('valence.db', dir: documents);
      final stale = File(docPath('valence.db')).lengthSync();

      final v = await openPackage();
      expect(await v.dataGet('shelf', 'p-1'), {'note': 'synced'});
      expect(File(docPath('valence.db')).existsSync(), isTrue, reason: 'nothing was moved or deleted');
      expect(File(docPath('valence.db')).lengthSync(), stale);
    });

    test('the second launch is a no-op and logs nothing about moving', () async {
      await writeLegacyDatabase('valence.db', dir: documents);
      await openPackage();
      ValenceStore.resetCacheForTests();
      final log = LogSpy();
      final again = await Valence.open(
        ValenceConfig(
          appId: 'com.example.app',
          keyring: {key.keyId: key.publicKeyBase64},
          bridgeVersion: 1,
          otaBase: 'https://ota.test',
          writableBuckets: const {'shelf'},
          dataSchemas: const {'plants': 2},
        ),
        log: log.call,
        client: MockClient((_) async => http.Response(jsonEncode({'rows': [], 'max': 0, 'more': false}), 200)),
        supportDir: support,
        documentsDir: documents,
      );
      expect(await again.dataGet('shelf', 'p-1'), {'note': 'synced'});
      expect(log.lines.join('\n'), isNot(contains('moved the 0.3 database')));
    });

    test('a fresh install with no legacy database anywhere just starts empty', () async {
      final v = await openPackage();
      expect(await v.dataGet('shelf', 'p-1'), isNull);
      expect(await v.pendingWrites(), 0);
    });

    test('nothing is moved when both directories are the same place', () async {
      // path_provider can return one directory for both on some platforms. The guard keeps the adoption
      // from renaming the live database onto itself.
      await writeLegacyDatabase('valence.db');
      final v = await openPackage(documentsDir: support);
      expect(await v.dataGet('shelf', 'p-1'), {'note': 'synced'});
    });
  });

  group('the CAS and manifests carry over', () {
    test('a manifest and its files written by a 0.3 host are re-verified and served', () async {
      // Same paths, same bytes, same signature: the package re-verifies rather than trusting, and a
      // bundle a 0.3 host downloaded passes because the format has not changed.
      final b = await signBundle(key, seq: 1792169481);
      final dir = Directory('${support.path}${Platform.pathSeparator}valence');
      b.writeTo(
        manifestsDir: Directory('${dir.path}${Platform.pathSeparator}manifests'),
        casDir: Directory('${dir.path}${Platform.pathSeparator}cas'),
      );
      writeLegacyState({'installId': 'i', 'current': 1792169481, 'floor': 0});
      await writeLegacyDatabase('valence.db');
      final v = await openPackage();
      final served = await v.updater.activateForUiStart();
      expect(served.seq, 1792169481, reason: 'no re-download, and no fallback to the built-in bundle');
    });
  });
}
