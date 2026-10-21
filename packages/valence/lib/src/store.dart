import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'wire.dart';

/// One row of a bucket, as `data.get` and `data.list` return it.
final class ValenceRow {
  /// Creates a row.
  const ValenceRow(this.key, this.value, this.usn);

  /// The row's key within its bucket.
  final String key;

  /// The decoded JSON value.
  final Object? value;

  /// The server's update sequence number, or `-1` for a local write that has not been acknowledged.
  ///
  /// `-1` is part of the contract, not an implementation detail: the page reads "written locally, not yet
  /// synced" off this. A pending *delete* leaves no row, so it cannot be counted this way (§5.5).
  final int usn;
}

/// One outbox entry: a local write waiting for the server to acknowledge it.
final class ValenceOutboxOp {
  /// Creates an op.
  const ValenceOutboxOp(this.id, this.bucket, this.key, this.value, this.deleted);

  /// The idempotency key the server echoes back in `acked`.
  final String id;

  /// The writable bucket this op belongs to.
  final String bucket;

  /// The row's key.
  final String key;

  /// The JSON text written, or null for a delete.
  final String? value;

  /// Whether this op is a delete (a tombstone).
  final bool deleted;
}

/// The default and maximum `data.list` page sizes (contracts §4.2).
///
/// Without them `data.list({bucket})` over a few thousand rows builds a reply that overruns Binder and
/// kills the WebView — and a WebView death while a trial is on screen spends a strike.
const defaultListLimit = 100;

/// The hard cap `data.list` clamps `limit` to, host-side, rather than trusting the page.
const maxListLimit = 500;

/// The schema from contracts §5.1. `user_version` is carried by sqflite's own `version` argument.
const _schemaSql = [
  'CREATE TABLE kv (bucket TEXT NOT NULL, schema INTEGER NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, '
      'usn INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (bucket, schema, key)) WITHOUT ROWID',
  'CREATE INDEX kv_bucket_usn ON kv (bucket, schema, usn)',
  'CREATE TABLE bucket (name TEXT NOT NULL, schema INTEGER NOT NULL, max_usn INTEGER NOT NULL, '
      'synced_at INTEGER, PRIMARY KEY (name, schema))',
  'CREATE TABLE outbox (id TEXT PRIMARY KEY, bucket TEXT NOT NULL, key TEXT NOT NULL, value TEXT, '
      'deleted INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
  'CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
];

/// The `kv`, `bucket`, `outbox` and `prefs` tables, with the pragmas and lifetime rules of §5.1.
///
/// **Never close it.** sqflite keys open databases by path *inside the platform plugin*, not per isolate,
/// so a `close()` in a `workmanager` isolate or a widget's `dispose()` invalidates the handle the UI
/// isolate holds, and the next bridge call fails with `database_closed`. [open] caches one instance per
/// path per isolate and there is deliberately no `close`.
final class ValenceStore {
  ValenceStore._(this.db, this.path, this.journalMode);

  static final Map<String, Future<ValenceStore>> _open = {};

  /// Opens (or returns the already-open) store at [path].
  ///
  /// Each isolate calls this on the same path and gets the same plugin-side connection back. A background
  /// isolate must call `DartPluginRegistrant.ensureInitialized()` before its first call, or the plugin is
  /// not registered in that isolate at all.
  static Future<ValenceStore> open(String path, {DatabaseFactory? factory}) =>
      _open.putIfAbsent(path, () => _openAt(path, factory ?? databaseFactory));

  static Future<ValenceStore> _openAt(String path, DatabaseFactory factory) async {
    var mode = 'unknown';
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          // Both pragmas return a row, and Android's SQLiteDatabase refuses a row-returning statement
          // through execSQL — so `execute` throws "Queries can be performed using SQLiteDatabase query or
          // rawQuery methods only" and the app dies on its first launch, before any UI. sqflite_common_ffi,
          // the factory every `flutter test` uses, accepts `execute` here, so no unit test catches it.
          final journal = await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.rawQuery('PRAGMA busy_timeout = 5000');
          // rawQuery returns the mode now in effect. A filesystem that cannot do WAL answers `delete`, and
          // the concurrency the rest of the data layer assumes is gone, so report it rather than discard it.
          mode = '${journal.isEmpty ? 'unknown' : journal.first.values.first}'.toLowerCase();
        },
        onCreate: (db, _) async {
          for (final sql in _schemaSql) {
            await db.execute(sql);
          }
        },
        // Migrations use user_version and are append-only. There is nothing to migrate from yet.
        onUpgrade: (db, from, to) async {},
      ),
    );
    return ValenceStore._(db, path, mode);
  }

  /// Forgets the per-isolate cache. For tests only; it does **not** close anything.
  static void resetCacheForTests() => _open.clear();

  /// The open connection. Exposed so an app can run its own queries in the same transaction scope.
  final Database db;

  /// The database file's path.
  final String path;

  /// The journal mode that actually took, lowercase. Anything but `wal` means degraded concurrency.
  final String journalMode;

  /// True when WAL took. Log or assert this; a `delete` journal is a real finding, not a detail.
  bool get isWal => journalMode == 'wal';

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Returns a row's value, or null when it is absent or a tombstone.
  Future<Object?> get(String bucket, int schema, String key) async {
    final rows = await db.query(
      'kv',
      columns: ['value'],
      where: 'bucket = ? AND schema = ? AND key = ? AND deleted = 0',
      whereArgs: [bucket, schema, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value']! as String);
  }

  /// Reads at most 500 requested keys in one query, omitting missing and deleted rows.
  /// Results follow first-requested-key order; duplicate keys appear once (§7.1).
  Future<List<ValenceRow>> getMany(String bucket, int schema, List<String> keys) async {
    if (keys.length > 500) {
      throw const BridgeError(BridgeErrorCode.params, 'data.getMany accepts at most 500 keys');
    }
    if (keys.isEmpty) return [];
    final unique = keys.toSet();
    final marks = List.filled(unique.length, '?').join(',');
    final rows = await db.query(
      'kv',
      columns: ['key', 'value', 'usn'],
      where: 'bucket = ? AND schema = ? AND deleted = 0 AND key IN ($marks)',
      whereArgs: [bucket, schema, ...unique],
    );
    final byKey = {for (final r in rows) r['key']! as String: r};
    return [
      for (final key in unique)
        if (byKey[key] case final r?) ValenceRow(key, jsonDecode(r['value']! as String), r['usn']! as int),
    ];
  }

  /// Lists live rows in key order, clamping [limit] to [maxListLimit] and defaulting it to
  /// [defaultListLimit].
  ///
  /// The clamp is host-side on purpose: the page is untrusted, and an unbounded list is the reply that
  /// kills the WebView.
  Future<List<ValenceRow>> list(
    String bucket,
    int schema, {
    String? prefix,
    int? limit,
  }) async {
    final n = (limit == null || limit <= 0) ? defaultListLimit : (limit > maxListLimit ? maxListLimit : limit);
    final where = StringBuffer('bucket = ? AND schema = ? AND deleted = 0');
    final args = <Object?>[bucket, schema];
    if (prefix != null && prefix.isNotEmpty) {
      // ESCAPE, so a key prefix containing % or _ matches literally.
      where.write(r" AND key LIKE ? ESCAPE '\'");
      args.add('${prefix.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%');
    }
    final rows = await db.query(
      'kv',
      columns: ['key', 'value', 'usn'],
      where: where.toString(),
      whereArgs: args,
      orderBy: 'key',
      limit: n,
    );
    return [
      for (final r in rows) ValenceRow(r['key']! as String, jsonDecode(r['value']! as String), r['usn']! as int),
    ];
  }

  /// The highest applied `usn` for one `(bucket, schema)` pair, or 0 when the pair is unknown.
  Future<int> maxUsn(String bucket, int schema) async {
    final rows = await db.query(
      'bucket',
      columns: ['max_usn'],
      where: 'name = ? AND schema = ?',
      whereArgs: [bucket, schema],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.first['max_usn']! as int;
  }

  /// Every `(bucket, schema)` pair that has completed at least one pull.
  ///
  /// A **set** of schemas per bucket, not a bucket-to-schema map: during a read-only schema bump a device
  /// legitimately holds `plants` v1 *and* v2 at once, because the old UI must keep reading v1 for the trial
  /// to be reversible. A map lets the v1 entry hide the v2 entry, so a satisfied bundle still looks
  /// unsatisfied after a successful pull (§2.3 step 7, §5.4).
  Future<Map<String, Set<int>>> syncedPairs() async {
    final rows = await db.query('bucket', columns: ['name', 'schema'], where: 'synced_at IS NOT NULL');
    final out = <String, Set<int>>{};
    for (final r in rows) {
      out.putIfAbsent(r['name']! as String, () => <int>{}).add(r['schema']! as int);
    }
    return out;
  }

  /// Every `(bucket, schema)` pair the database holds, synced or not.
  Future<Map<String, Set<int>>> allPairs() async {
    final rows = await db.query('bucket', columns: ['name', 'schema']);
    final out = <String, Set<int>>{};
    for (final r in rows) {
      out.putIfAbsent(r['name']! as String, () => <int>{}).add(r['schema']! as int);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Local writes (§5.5)
  // ---------------------------------------------------------------------------

  /// Writes a row locally and queues it for push, in one transaction.
  ///
  /// A null [value] is **the delete**: it writes a tombstone and an outbox op with `d: 1`. There is no
  /// other delete method, and no way to store a literal JSON null as a value.
  ///
  /// Writable buckets never change schema, so this always uses schema 1 (§5.4). The caller is responsible
  /// for refusing a bucket that is not writable; the bridge does that with `E_DENIED`.
  Future<void> put(String bucket, String key, Object? value, {required String opId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final json = value == null ? null : jsonEncode(value);
    await db.transaction((txn) async {
      await txn.insert(
        'kv',
        {
          'bucket': bucket,
          'schema': 1,
          'key': key,
          'value': json ?? 'null',
          'usn': -1,
          'deleted': value == null ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('outbox', {
        'id': opId,
        'bucket': bucket,
        'key': key,
        'value': json,
        'deleted': value == null ? 1 : 0,
        'created_at': now,
      });
    });
  }

  /// The queued ops for [bucket], oldest first.
  Future<List<ValenceOutboxOp>> outbox(String bucket, {int limit = 200}) async {
    final rows = await db.query(
      'outbox',
      where: 'bucket = ?',
      whereArgs: [bucket],
      orderBy: 'created_at, id',
      limit: limit,
    );
    return [
      for (final r in rows)
        ValenceOutboxOp(
          r['id']! as String,
          r['bucket']! as String,
          r['key']! as String,
          r['value'] as String?,
          (r['deleted']! as int) != 0,
        ),
    ];
  }

  /// How many local writes are still waiting to sync, across every writable bucket.
  ///
  /// The page has no other way to ask: a pending delete leaves no row, so counting `usn == -1` undercounts.
  Future<int> pendingWrites() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM outbox');
    return rows.first['n']! as int;
  }

  /// Which buckets have queued ops. Used to decide what to push.
  Future<Set<String>> outboxBuckets() async {
    final rows = await db.rawQuery('SELECT DISTINCT bucket FROM outbox');
    return {for (final r in rows) r['bucket']! as String};
  }

  // ---------------------------------------------------------------------------
  // Applying server rows (§5.3, §5.5)
  // ---------------------------------------------------------------------------

  /// Applies one pull page in a single transaction and moves `max_usn` to [maxUsnAfter].
  ///
  /// Rows whose key still has an outbox entry are **skipped**: the local write wins until the server
  /// acknowledges it. `max_usn` only moves forward, and `synced_at` is set, which is what makes the pair
  /// count as synced for §2.3 step 7.
  Future<int> applyPullPage({
    required String bucket,
    required int schema,
    required List<Map<String, Object?>> rows,
    required int maxUsnAfter,
  }) async {
    var applied = 0;
    await db.transaction((txn) async {
      final blocked = <String>{
        for (final r in await txn.query('outbox', columns: ['key'], where: 'bucket = ?', whereArgs: [bucket]))
          r['key']! as String,
      };
      for (final r in rows) {
        final key = r['k'];
        final usn = r['u'];
        if (key is! String || usn is! int) continue;
        if (blocked.contains(key)) continue;
        final deleted = r['d'] == 1 || r['d'] == true;
        await txn.insert(
          'kv',
          {
            'bucket': bucket,
            'schema': schema,
            'key': key,
            'value': jsonEncode(r['v']),
            'usn': usn,
            'deleted': deleted ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        applied++;
      }
      await _bumpBucket(txn, bucket, schema, maxUsnAfter, synced: true);
    });
    return applied;
  }

  /// Clears the acknowledged ops and applies the echoed rows, in one transaction.
  ///
  /// Echoed rows for keys that *still* have an outbox entry are skipped: a newer local edit waits for its
  /// own acknowledgement. Without that, a push echo clobbers an edit the user made while the push was in
  /// flight.
  Future<void> applyPushAck({
    required String bucket,
    required List<String> acked,
    required List<Map<String, Object?>> rows,
  }) async {
    await db.transaction((txn) async {
      for (final id in acked) {
        await txn.delete('outbox', where: 'id = ?', whereArgs: [id]);
      }
      final blocked = <String>{
        for (final r in await txn.query('outbox', columns: ['key'], where: 'bucket = ?', whereArgs: [bucket]))
          r['key']! as String,
      };
      var max = 0;
      for (final r in rows) {
        final key = r['k'];
        final usn = r['u'];
        if (key is! String || usn is! int) continue;
        if (usn > max) max = usn;
        if (blocked.contains(key)) continue;
        await txn.insert(
          'kv',
          {
            'bucket': bucket,
            'schema': 1,
            'key': key,
            'value': jsonEncode(r['v']),
            'usn': usn,
            'deleted': (r['d'] == 1 || r['d'] == true) ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (max > 0) await _bumpBucket(txn, bucket, 1, max, synced: true);
    });
  }

  Future<void> _bumpBucket(
    DatabaseExecutor txn,
    String bucket,
    int schema,
    int maxUsn, {
    required bool synced,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await txn.query(
      'bucket',
      columns: ['max_usn'],
      where: 'name = ? AND schema = ?',
      whereArgs: [bucket, schema],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert('bucket', {
        'name': bucket,
        'schema': schema,
        'max_usn': maxUsn,
        'synced_at': synced ? now : null,
      });
      return;
    }
    final current = existing.first['max_usn']! as int;
    await txn.update(
      'bucket',
      {
        // max_usn only moves forward.
        'max_usn': maxUsn > current ? maxUsn : current,
        if (synced) 'synced_at': now,
      },
      where: 'name = ? AND schema = ?',
      whereArgs: [bucket, schema],
    );
  }

  // ---------------------------------------------------------------------------
  // Seed (§5.2)
  // ---------------------------------------------------------------------------

  /// Imports the bundled seed for each `(bucket, schema)` pair in [schemas], skipping rows already held.
  ///
  /// Returns the rows copied per bucket. A seeded pair deliberately does **not** get `synced_at`, because
  /// §2.3 step 7 is about the server having rows at that schema and a seed proves nothing about that.
  Future<Map<String, int>> importSeed(String seedPath, Map<String, int> schemas,
      {Map<String, List<int>> additionalSchemas = const {}}) async {
    if (schemas.isEmpty) return const {};
    final counts = <String, int>{};
    // ATTACH outside a transaction: SQLite refuses it inside one.
    await db.execute('ATTACH DATABASE ? AS valence_seed', [seedPath]);
    try {
      final pairs = {
        for (final e in schemas.entries) e.key: {e.value, ...?additionalSchemas[e.key]},
      };
      for (final e in [for (final b in pairs.entries) for (final n in b.value) MapEntry(b.key, n)]) {
        final from = await maxUsn(e.key, e.value);
        await db.transaction((txn) async {
          await txn.rawInsert(
            'INSERT OR REPLACE INTO kv (bucket, schema, key, value, usn, deleted) '
            'SELECT bucket, schema, key, value, usn, deleted FROM valence_seed.kv '
            'WHERE bucket = ? AND schema = ? AND usn > ?',
            [e.key, e.value, from],
          );
          // rawInsert returns a last-insert-rowid, which is meaningless on a WITHOUT ROWID table: it reads
          // as 1 for a seed of thousands and looks like a failed import. changes() is the row count.
          final changed = await txn.rawQuery('SELECT changes() AS n');
          counts[e.key] = (counts[e.key] ?? 0) + (changed.first['n']! as int);
          final seedMax = await txn.rawQuery(
            'SELECT MAX(usn) AS m FROM valence_seed.kv WHERE bucket = ? AND schema = ?',
            [e.key, e.value],
          );
          final m = seedMax.first['m'];
          if (m is int && m > from) {
            await _bumpBucket(txn, e.key, e.value, m, synced: false);
          }
        });
      }
    } finally {
      await db.execute('DETACH DATABASE valence_seed');
    }
    return counts;
  }

  // ---------------------------------------------------------------------------
  // Garbage collection (§2.4)
  // ---------------------------------------------------------------------------

  /// Deletes one read-only `(bucket, schema)` pair.
  ///
  /// Refuses a writable bucket, as the second half of the §2.4 rule: no manifest ever lists one in
  /// `requires.data`, so a garbage collector phrased as "delete every pair no manifest requires" would
  /// destroy all of the user's own data on the first commit after an OTA. The guard lives here as well as
  /// in the caller, because one of the two will be the one that is wrong.
  Future<void> dropPair(String bucket, int schema, {required Set<String> writableBuckets}) async {
    if (writableBuckets.contains(bucket)) {
      throw BridgeError(
        BridgeErrorCode.denied,
        'refusing to drop the writable bucket "$bucket": that is user data, and no manifest ever '
        'requires it (contracts §2.4)',
      );
    }
    await db.transaction((txn) async {
      await txn.delete('kv', where: 'bucket = ? AND schema = ?', whereArgs: [bucket, schema]);
      await txn.delete('bucket', where: 'name = ? AND schema = ?', whereArgs: [bucket, schema]);
    });
  }

  // ---------------------------------------------------------------------------
  // prefs (§5.6)
  // ---------------------------------------------------------------------------

  /// Reads a pref. Refuses the reserved `valence.` prefix.
  ///
  /// `async`, so the refusal is a rejected future rather than a synchronous throw out of a
  /// Future-returning method — which an unawaited call would turn into an uncatchable crash.
  Future<String?> prefGet(String key) async {
    _refuseReservedPrefKey(key);
    return _prefGet(key);
  }

  /// Writes a pref, or removes it when [value] is null. Refuses the reserved `valence.` prefix. See
  /// [prefGet] on why this is `async`.
  Future<void> prefSet(String key, String? value) async {
    _refuseReservedPrefKey(key);
    return _prefSet(key, value);
  }

  /// The host's own keys, which the reserved prefix exists to protect. Not for app or page code.
  ///
  /// §4.2 reserves `valence.` and the runtime refuses it at the bridge, but the public
  /// [prefGet]/[prefSet] are the only way an app that defines its *own* settings method can store
  /// anything — so the check has to be here too, or that method is a way to clear the sync lease from
  /// page input and let two syncs interleave. Same reasoning as [dropPair] re-checking `writableBuckets`.
  Future<String?> hostPrefGet(String key) => _prefGet(key);

  /// Writes one of the host's own keys. Not for app or page code; see [hostPrefGet].
  Future<void> hostPrefSet(String key, String? value) => _prefSet(key, value);

  static void _refuseReservedPrefKey(String key) {
    if (key == 'valence' || key.startsWith('valence.')) {
      throw BridgeError(BridgeErrorCode.denied, 'the "valence." pref prefix is reserved for the host');
    }
  }

  Future<String?> _prefGet(String key) async {
    final rows = await db.query('prefs', columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  Future<void> _prefSet(String key, String? value) async {
    if (value == null) {
      await db.delete('prefs', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await db.insert('prefs', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
