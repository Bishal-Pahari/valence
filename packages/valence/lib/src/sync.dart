import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'config.dart';
import 'log.dart';
import 'store.dart';

/// Why a sync run ended the way it did (contracts §5.6).
///
/// Without this, "I was not allowed to try" and "you are already up to date" are the same answer —
/// `changed: 0, offline: false` — so a freshness indicator reports confident freshness over stale data,
/// and a page that retries on an empty result cannot tell there is anything to retry.
enum ValenceSyncReason {
  /// The run happened. `changed` is then the real answer, zero included.
  ok,

  /// Another sync held the lease, so **nothing was attempted**. Not evidence of anything about the data.
  busy,

  /// The run was attempted and at least one request could not reach the server.
  offline,
}

/// What one sync run did, as `sync.now` returns it.
final class ValenceSyncResult {
  /// Creates a result.
  const ValenceSyncResult(this.buckets, this.changed, this.offline, [this.reason = ValenceSyncReason.ok]);

  /// The buckets this run touched.
  final List<String> buckets;

  /// How many rows were applied.
  final int changed;

  /// True when the run could not reach the server at all.
  final bool offline;

  /// Why the run ended as it did. `busy` means the run never started.
  final ValenceSyncReason reason;
}

/// The prefs key holding the sync lease. Reserved: the bridge refuses `valence.*` from the page (§4.2).
const syncLeaseKey = 'valence.sync.lease';

/// How long a lease stays valid. A holder that dies releases it by expiry.
const syncLeaseTtl = Duration(minutes: 2);

/// Pull, push and the one-sync-at-a-time lease (contracts §5.3 to §5.6).
///
/// Every sync path takes the lease, **including the updater's step 7 pull**, which runs on the same
/// triggers as the ordinary sync. Without that, a host runs two concurrent syncs over the same
/// `(bucket, schema)`: interleaved page transactions, racing `max_usn` writes and racing outbox-skip
/// decisions, which is exactly what one-at-a-time exists to prevent.
final class ValenceSync {
  /// Creates a sync driver over an open [store].
  ValenceSync({
    required this.store,
    required this.config,
    http.Client? client,
    ValenceLogger log = defaultValenceLogger,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _log = log,
        _now = clock ?? DateTime.now;

  /// The open store. Never closed, by either isolate (§5.1).
  final ValenceStore store;

  /// The app's configuration.
  final ValenceConfig config;

  final http.Client _client;
  final ValenceLogger _log;
  final DateTime Function() _now;

  /// Bytes of row payload this driver has applied. Used to budget §2.3 step 7.
  int bytesApplied = 0;

  // ---------------------------------------------------------------------------
  // The lease (§5.6)
  // ---------------------------------------------------------------------------

  /// Takes the lease, or returns false when another sync holds it.
  ///
  /// sqflite runs `transaction` as `BEGIN IMMEDIATE`, which is what makes the read-then-write atomic
  /// across isolates. A lease time in the **future**, from clock skew or tampering, counts as expired.
  Future<bool> acquireLease() async {
    final now = _now().millisecondsSinceEpoch;
    var taken = false;
    await store.db.transaction((txn) async {
      final rows = await txn.query(
        'prefs',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [syncLeaseKey],
        limit: 1,
      );
      final (held, owner) = _readLease(rows.isEmpty ? null : rows.first['value'] as String);
      final live = held != null && held > now - syncLeaseTtl.inMilliseconds && held <= now;
      // A lease recorded by **another process** cannot be held by anything running now. The lease exists to
      // keep the UI isolate and the background isolate apart, and those share this process (§5.6), so the
      // only way to see a foreign pid is a launch that is gone: a crash, a force-stop, or Android reclaiming
      // the app. Waiting out the two minutes in that case blocks every sync of the new launch and reports
      // each one as a successful empty sync, which is exactly when a user has just reopened a stale app.
      // A recycled pid that matches ours degrades to the old behaviour: we wait for the expiry.
      //
      // ponytail: single-process assumption. A host that puts a service in its own `android:process` would
      // need the owner to be a token both processes agree on, written at launch.
      if (live && owner == pid) return;
      if (live) _log('sync: taking over a lease left by process $owner, which is gone');
      await txn.insert(
        'prefs',
        {'key': syncLeaseKey, 'value': _leaseValue(now)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      taken = true;
    });
    return taken;
  }

  /// Pushes the lease forward. Call after every applied page, so a long `since = 0` pull keeps it.
  Future<void> renewLease() => store.hostPrefSet(syncLeaseKey, _leaseValue(_now().millisecondsSinceEpoch));

  String _leaseValue(int millis) => '$millis:$pid';

  /// `<millis>:<pid>`. A value written by an older host is just `<millis>`, and reads back with a null
  /// owner, which never matches this process — so the first launch after an upgrade clears it.
  static (int?, int?) _readLease(String? raw) {
    if (raw == null) return (null, null);
    final colon = raw.indexOf(':');
    if (colon < 0) return (int.tryParse(raw), null);
    return (int.tryParse(raw.substring(0, colon)), int.tryParse(raw.substring(colon + 1)));
  }

  /// Releases the lease.
  Future<void> releaseLease() => store.hostPrefSet(syncLeaseKey, null);

  // ---------------------------------------------------------------------------
  // One run
  // ---------------------------------------------------------------------------

  /// Pulls every pair the device holds, then pushes every writable bucket with queued ops.
  ///
  /// [readSchemas] is the active manifest's `requires.data`: ordinary sync follows the **active** bundle,
  /// which is why a newly required pair has no route onto the device except §2.3 step 7. Writable buckets
  /// are pulled separately, because they can never appear in it.
  Future<ValenceSyncResult> run({
    required Map<String, int> readSchemas,
    List<String>? only,
  }) async {
    if (config.syncBase.isEmpty) {
      _log('sync: no syncBase configured, nothing to do');
      return const ValenceSyncResult([], 0, false);
    }
    if (!await acquireLease()) {
      _log('sync: another sync holds the lease; skipping this run');
      return const ValenceSyncResult([], 0, false, ValenceSyncReason.busy);
    }
    final touched = <String>[];
    var changed = 0;
    var offline = false;
    try {
      final wanted = only?.toSet();
      for (final e in readSchemas.entries) {
        if (wanted != null && !wanted.contains(e.key)) continue;
        try {
          changed += await pullPair(e.key, e.value);
          touched.add(e.key);
        } on SocketException catch (err) {
          offline = true;
          _log('sync: offline pulling ${e.key} v${e.value}: $err');
        } on http.ClientException catch (err) {
          offline = true;
          _log('sync: offline pulling ${e.key} v${e.value}: $err');
        }
      }
      // Writable buckets are pulled too, at schema 1 (§5.4). They can never be in `readSchemas`: that is
      // the active manifest's `requires.data`, and both check 5 and the CLI refuse a writable bucket
      // there. Without this a user bucket is push-only — device B never sees device A's row, a reinstall
      // comes back empty, and §5.5's "A writes 4, A syncs, B writes 7, A syncs leaves A holding 7" cannot
      // happen at all. Pulled before the push, so the outbox skip in applyPullPage is what protects a
      // write that has not been acknowledged yet.
      for (final bucket in config.writableBuckets) {
        if (wanted != null && !wanted.contains(bucket)) continue;
        try {
          changed += await pullPair(bucket, 1);
          if (!touched.contains(bucket)) touched.add(bucket);
        } on SocketException catch (err) {
          offline = true;
          _log('sync: offline pulling $bucket v1: $err');
        } on http.ClientException catch (err) {
          offline = true;
          _log('sync: offline pulling $bucket v1: $err');
        }
      }
      for (final bucket in await store.outboxBuckets()) {
        if (wanted != null && !wanted.contains(bucket)) continue;
        if (!config.writableBuckets.contains(bucket)) {
          // Only a writable bucket can have an outbox row, so this means the config changed under us.
          _log('sync: outbox holds ops for "$bucket", which is not writable; leaving them alone');
          continue;
        }
        try {
          changed += await pushBucket(bucket);
          if (!touched.contains(bucket)) touched.add(bucket);
        } on SocketException catch (err) {
          offline = true;
          _log('sync: offline pushing $bucket: $err');
        } on http.ClientException catch (err) {
          offline = true;
          _log('sync: offline pushing $bucket: $err');
        }
      }
    } finally {
      await releaseLease();
    }
    return ValenceSyncResult(touched, changed, offline, offline ? ValenceSyncReason.offline : ValenceSyncReason.ok);
  }

  // ---------------------------------------------------------------------------
  // Pull (§5.3)
  // ---------------------------------------------------------------------------

  /// Pulls one `(bucket, schema)` pair from **its own** `max_usn`, page by page, until `more` is false.
  ///
  /// Never from a hard-coded `since = 0`: `synced_at` only becomes non-null once a pull completes, so on a
  /// flaky link a restart-from-zero re-applies everything the device already holds, on every UI start,
  /// every resume and every periodic check, for ever.
  ///
  /// Returns the rows applied. Stops early and logs when [byteBudget] is exhausted.
  Future<int> pullPair(String bucket, int schema, {int? byteBudget}) async {
    if (config.syncMode == ValenceSyncMode.staticChunks && !config.writableBuckets.contains(bucket)) {
      return _pullStatic(bucket, schema, byteBudget: byteBudget);
    }
    var applied = 0;
    var spent = 0;
    while (true) {
      final since = await store.maxUsn(bucket, schema);
      final uri = Uri.parse('${config.syncBase}/$bucket').replace(queryParameters: {
        'since': '$since',
        'schema': '$schema',
        'limit': '${config.pullPageLimit}',
      });
      final res = await _client.get(uri, headers: await _headers(bucket));
      if (res.statusCode != 200) {
        _log('sync: pull $bucket v$schema since $since returned HTTP ${res.statusCode}');
        return applied;
      }
      spent += res.bodyBytes.length;
      bytesApplied += res.bodyBytes.length;
      final page = _decodePage(res.body);
      if (page == null) {
        _log('sync: pull $bucket v$schema returned a body this host cannot decode');
        return applied;
      }
      applied += await store.applyPullPage(
        bucket: bucket,
        schema: schema,
        rows: page.rows,
        maxUsnAfter: page.max > since ? page.max : since,
      );
      // §5.6: renew after every applied page, so a long pull cannot let a second sync start.
      await renewLease();
      if (!page.more) return applied;
      if (page.rows.isEmpty) {
        // `more: true` with no rows would spin for ever against a server that is wrong about itself.
        _log('sync: pull $bucket v$schema claimed more rows but sent none; stopping');
        return applied;
      }
      if (byteBudget != null && spent >= byteBudget) {
        _log('sync: pull $bucket v$schema hit the $byteBudget byte budget after $applied rows; backing off');
        return applied;
      }
    }
  }

  /// The CDN-only variant: an index of chunk ranges, then the chunks above `max_usn` (§5.3).
  Future<int> _pullStatic(String bucket, int schema, {int? byteBudget}) async {
    final base = '${config.syncBase}/$bucket/v$schema';
    final indexRes = await _client.get(Uri.parse('$base/index.json'));
    if (indexRes.statusCode != 200) {
      _log('sync: static index for $bucket v$schema returned HTTP ${indexRes.statusCode}');
      return 0;
    }
    final Object? rawIndex;
    try {
      rawIndex = jsonDecode(indexRes.body);
    } on Object catch (e) {
      _log('sync: static index for $bucket v$schema is not JSON: $e');
      return 0;
    }
    if (rawIndex is! List) {
      _log('sync: static index for $bucket v$schema is not a list');
      return 0;
    }
    final chunks = <({int to, String file})>[];
    for (final c in rawIndex) {
      if (c is! Map) continue;
      final to = c['to'];
      final file = c['file'];
      if (to is int && file is String && file.isNotEmpty && !file.contains('/') && !file.contains('..')) {
        chunks.add((to: to, file: file));
      }
    }
    chunks.sort((a, b) => a.to.compareTo(b.to));
    var applied = 0;
    var spent = 0;
    for (final chunk in chunks) {
      final since = await store.maxUsn(bucket, schema);
      if (chunk.to <= since) continue;
      final res = await _client.get(Uri.parse('$base/${chunk.file}'));
      if (res.statusCode != 200) {
        _log('sync: static chunk ${chunk.file} returned HTTP ${res.statusCode}');
        return applied;
      }
      spent += res.bodyBytes.length;
      bytesApplied += res.bodyBytes.length;
      // The chunks are published gzipped. http decompresses when the server sets Content-Encoding, so only
      // decode by hand when the bytes still look like a gzip member.
      final body = res.bodyBytes.length > 2 && res.bodyBytes[0] == 0x1f && res.bodyBytes[1] == 0x8b
          ? utf8.decode(gzip.decode(res.bodyBytes))
          : res.body;
      final page = _decodePage(body);
      if (page == null) {
        _log('sync: static chunk ${chunk.file} has a body this host cannot decode');
        return applied;
      }
      applied += await store.applyPullPage(
        bucket: bucket,
        schema: schema,
        rows: page.rows,
        maxUsnAfter: page.max > chunk.to ? page.max : chunk.to,
      );
      await renewLease();
      if (byteBudget != null && spent >= byteBudget) {
        _log('sync: static pull $bucket v$schema hit the $byteBudget byte budget; backing off');
        return applied;
      }
    }
    return applied;
  }

  // ---------------------------------------------------------------------------
  // Push (§5.5)
  // ---------------------------------------------------------------------------

  /// Pushes one writable bucket's queued ops, then clears the acknowledged ones and applies the echo.
  ///
  /// Idempotent by op id, so a retry after a lost response cannot duplicate a write.
  Future<int> pushBucket(String bucket) async {
    final ops = await store.outbox(bucket);
    if (ops.isEmpty) return 0;
    final res = await _client.post(
      Uri.parse('${config.syncBase}/$bucket/push'),
      headers: {'content-type': 'application/json', ...await _headers(bucket)},
      body: jsonEncode({
        'ops': [
          for (final op in ops)
            {
              'id': op.id,
              'k': op.key,
              'v': op.value == null ? null : jsonDecode(op.value!),
              'd': op.deleted ? 1 : 0,
            },
        ],
      }),
    );
    if (res.statusCode != 200) {
      _log('sync: push $bucket returned HTTP ${res.statusCode}; keeping ${ops.length} ops queued');
      return 0;
    }
    final Object? raw;
    try {
      raw = jsonDecode(res.body);
    } on Object catch (e) {
      _log('sync: push $bucket returned a body that is not JSON: $e');
      return 0;
    }
    if (raw is! Map<String, Object?>) {
      _log('sync: push $bucket returned a body that is not an object');
      return 0;
    }
    final acked = <String>[
      for (final a in (raw['acked'] is List ? raw['acked']! as List : const []))
        if (a is String) a,
    ];
    final rows = <Map<String, Object?>>[
      for (final r in (raw['rows'] is List ? raw['rows']! as List : const []))
        if (r is Map<String, Object?>) r,
    ];
    await store.applyPushAck(bucket: bucket, acked: acked, rows: rows);
    return acked.length;
  }

  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _headers(String bucket) async {
    // §5.3: the bearer token is for user buckets. A public read-only bucket is fetched unauthenticated,
    // so a CDN can serve it and a cache can keep it.
    if (!config.writableBuckets.contains(bucket)) return const {};
    final token = await config.authToken?.call();
    return token == null || token.isEmpty ? const {} : {'authorization': 'Bearer $token'};
  }

  ({List<Map<String, Object?>> rows, int max, bool more})? _decodePage(String body) {
    final Object? raw;
    try {
      raw = jsonDecode(body);
    } on Object {
      return null;
    }
    if (raw is! Map<String, Object?>) return null;
    final rows = raw['rows'];
    if (rows is! List) return null;
    return (
      rows: [
        for (final r in rows)
          if (r is Map<String, Object?>) r,
      ],
      max: raw['max'] is int ? raw['max']! as int : 0,
      more: raw['more'] == true,
    );
  }
}
