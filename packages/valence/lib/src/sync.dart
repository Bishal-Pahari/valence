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
  /// Every attempted operation completed. `changed` is the real answer, zero included.
  ///
  /// An app with no `syncBase` also reports `ok`: there is no server for its data to be stale against,
  /// so "nothing to do" is the honest answer rather than a blocked or failed run.
  ok,

  /// Another sync held the lease, so **nothing was attempted**. Not evidence of anything about the data.
  busy,

  /// The run was attempted and at least one request could not reach the server.
  offline,

  /// The server rejected the bearer token with 401, so an authenticated bucket was not read or written
  /// (§4.4). The data is stale, and no amount of retrying fixes it until the page sets a new token.
  ///
  /// The values here are an open set, and a page must treat one it does not recognise as a run that did
  /// not fully succeed (§4.4). On the host side a `switch` over this enum stops compiling when a value is
  /// added, which is the intended way to find the places that assumed three.
  unauthorized,

  /// A server response or protocol failure left a pull or push incomplete. An anonymous 401 is
  /// a server failure too: it does not expire a login. Applied rows and queued writes are retained.
  failed,
}

/// What one sync run did, as `sync.now` returns it.
final class ValenceSyncResult {
  /// Creates a result.
  const ValenceSyncResult(this.buckets, this.changed, this.offline,
      [this.reason = ValenceSyncReason.ok, this.pending = 0]);

  /// The buckets this run touched.
  final List<String> buckets;

  /// How many rows were applied.
  final int changed;

  /// True when the run could not reach the server at all.
  final bool offline;

  /// Why the run ended as it did. `busy` means the run never started.
  final ValenceSyncReason reason;

  /// Remaining outbox operations, including deletes.
  final int pending;

  /// The `SyncResult` wire shape, for the `sync.done` event (§4.6).
  ///
  /// Every field, including the two the generated `SyncResult` type may not declare: an app's `on()`
  /// handler reads what it knows about and the rest costs nothing, while a page generated against the
  /// newer schema on an older host is the case §4.3's "a grown field is always nullable" covers.
  Map<String, Object?> toJson() => {
        'buckets': buckets,
        'changed': changed,
        'offline': offline,
        'reason': reason.name,
        'pending': pending,
      };
}

/// Local sync observations. [offline] is the last attempt, not current connectivity (§7.1).
final class ValenceSyncStatus {
  /// Creates a local status snapshot.
  const ValenceSyncStatus(
      {required this.pending, required this.lastSyncedAt, required this.offline, this.reason});

  /// Remaining operations, including deletes and repeated edits.
  final int pending;

  /// Last successful unscoped sync, in epoch milliseconds; null before one.
  final int? lastSyncedAt;

  /// Whether the last attempted run had a transport failure; false before an attempt.
  final bool offline;

  /// Last completed attempt, including scoped runs; null before one. An open string set.
  final String? reason;
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

  /// Called the first time a request carrying the bearer token comes back 401 (§4.4).
  ///
  /// [Valence] wires this to the `auth.expired` event. A background isolate has no page to tell, so it
  /// leaves this null and the log line is the only record.
  void Function()? onUnauthorized;

  /// Whether this run has already seen a 401. Reset per [run], so the event fires at most once a run.
  bool _unauthorized = false;
  bool _incomplete = false;

  /// Whether the last [pullPair] stopped because it had spent its `byteBudget`, rather than because the
  /// pair was finished or the link failed.
  ///
  /// The updater's step 7 reads this: a pair left short by the configured data cap is `toobig` (§4.6),
  /// not `waitingForData`. The two look identical from the outside — the pair is simply not in
  /// `syncedPairs()` — and telling a developer their data is unavailable when their own cap stopped the
  /// download sends them looking at the server.
  bool budgetExhausted = false;

  /// Reads persisted observations and current outbox depth without taking the sync lease.
  Future<ValenceSyncStatus> status() async {
    final rows = await databaseOperation(
        'sync.status',
        () => store.db.query('prefs', where: 'key IN (?, ?, ?)', whereArgs: [
              'valence.sync.lastSyncedAt',
              'valence.sync.offline',
              'valence.sync.reason',
            ]),
        _log);
    final values = {for (final row in rows) row['key']: row['value']};
    return ValenceSyncStatus(
      pending: await store.pendingWrites(),
      lastSyncedAt: int.tryParse(values['valence.sync.lastSyncedAt'] as String? ?? ''),
      offline: values['valence.sync.offline'] == 'true',
      reason: values['valence.sync.reason'] as String?,
    );
  }

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
    await databaseOperation(
        'sync.acquireLease',
        () => store.db.transaction((txn) async {
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
              if (live) {
                _log(owner == null
                    ? 'sync: clearing a lease written by an older host, which records no owner'
                    : 'sync: taking over a lease left by process $owner, which is gone');
              }
              await txn.insert(
                'prefs',
                {'key': syncLeaseKey, 'value': _leaseValue(now)},
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              taken = true;
            }),
        _log);
    return taken;
  }

  /// Pushes the lease forward. Call after every applied page, so a long `since = 0` pull keeps it.
  Future<void> renewLease() =>
      store.hostPrefSet(syncLeaseKey, _leaseValue(_now().millisecondsSinceEpoch));

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
      return ValenceSyncResult([], 0, false, ValenceSyncReason.ok, await store.pendingWrites());
    }
    if (!await acquireLease()) {
      _log('sync: another sync holds the lease; skipping this run');
      return ValenceSyncResult([], 0, false, ValenceSyncReason.busy, await store.pendingWrites());
    }
    _unauthorized = false;
    _incomplete = false;
    final touched = <String>[];
    var changed = 0;
    var attempted = 0;
    var offline = false;
    late final ValenceSyncReason reason;
    try {
      final wanted = only?.toSet();
      for (final e in readSchemas.entries) {
        if (wanted != null && !wanted.contains(e.key)) continue;
        attempted++;
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
        attempted++;
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
          _incomplete = true;
          _log('sync: outbox holds ops for "$bucket", which is not writable; leaving them alone');
          continue;
        }
        attempted++;
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
      // A scoped run whose buckets match nothing attempts nothing, and `buckets` is page-supplied
      // (§5.6), so without this a page could turn a durable `unauthorized` into a reported success
      // on demand by naming a bucket this bundle no longer has.
      final nothingAttempted = only != null && attempted == 0;
      if (nothingAttempted) {
        _log('sync: scoped run matched no syncable bucket (${only.join(', ')}); '
            'nothing was attempted and the stored outcome is left as it was');
      }
      // Classify while holding the lease, before another run can reset the attempt flags.
      // Auth rejection outranks transport failure, which outranks an incomplete server response.
      reason = _unauthorized
          ? ValenceSyncReason.unauthorized
          : offline
              ? ValenceSyncReason.offline
              : _incomplete || nothingAttempted
                  ? ValenceSyncReason.failed
                  : ValenceSyncReason.ok;
      // Persist the outcome before releasing the lease: a later run must not be overwritten.
      // A run that observed nothing writes nothing, so it cannot overwrite one that did.
      if (!nothingAttempted) {
        await databaseOperation(
            'sync.observations',
            () => store.db.transaction((txn) async {
                  final observations = {
                    'valence.sync.reason': reason.name,
                    'valence.sync.offline': offline.toString(),
                    if (!offline && !_unauthorized && !_incomplete && only == null)
                      'valence.sync.lastSyncedAt': _now().millisecondsSinceEpoch.toString(),
                  };
                  for (final entry in observations.entries) {
                    await txn.insert('prefs', {'key': entry.key, 'value': entry.value},
                        conflictAlgorithm: ConflictAlgorithm.replace);
                  }
                }),
            _log);
      }
    } finally {
      await releaseLease();
    }
    return ValenceSyncResult(touched, changed, offline, reason, await store.pendingWrites());
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
    budgetExhausted = false;
    if (config.syncMode == ValenceSyncMode.staticChunks &&
        !config.writableBuckets.contains(bucket)) {
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
      final headers = await _headers(bucket);
      final res = await _client.get(uri, headers: headers);
      // Only a request that actually carried the token can be an auth failure. A public bucket behind a
      // misconfigured CDN can answer 401 too, and that is a server problem, not an expired login.
      if (res.statusCode == 401 && headers.containsKey('authorization')) {
        _rejected('pull $bucket v$schema');
        return applied;
      }
      if (res.statusCode != 200) {
        _incomplete = true;
        _log('sync: pull $bucket v$schema since $since returned HTTP ${res.statusCode}');
        return applied;
      }
      spent += res.bodyBytes.length;
      bytesApplied += res.bodyBytes.length;
      final page = _decodePage(res.body);
      if (page == null) {
        _incomplete = true;
        _log('sync: pull $bucket v$schema returned a body this host cannot decode');
        return applied;
      }
      var cursor = since;
      for (final row in page.rows) {
        final usn = row['u']! as int;
        if (usn <= cursor) {
          _incomplete = true;
          _log('sync: pull $bucket v$schema did not advance in strict USN order');
          return applied;
        }
        cursor = usn;
      }
      if (page.more && page.rows.isEmpty) {
        _incomplete = true;
        _log('sync: pull $bucket v$schema claimed more rows but sent none; stopping');
        return applied;
      }
      applied += await store.applyPullPage(
        bucket: bucket,
        schema: schema,
        rows: page.rows,
        maxUsnAfter: cursor,
        complete: !page.more,
      );
      // §5.6: renew after every applied page, so a long pull cannot let a second sync start.
      await renewLease();
      if (!page.more) return applied;
      if (byteBudget != null && spent >= byteBudget) {
        _incomplete = true;
        budgetExhausted = true;
        _log(
            'sync: pull $bucket v$schema hit the $byteBudget byte budget after $applied rows; backing off');
        return applied;
      }
    }
  }

  /// The CDN-only variant: an index of chunk ranges, then the chunks above `max_usn` (§5.3).
  Future<int> _pullStatic(String bucket, int schema, {int? byteBudget}) async {
    final base = '${config.syncBase}/$bucket/v$schema';
    final indexRes = await _client.get(Uri.parse('$base/index.json'));
    if (indexRes.statusCode != 200) {
      _incomplete = true;
      _log('sync: static index for $bucket v$schema returned HTTP ${indexRes.statusCode}');
      return 0;
    }
    final Object? rawIndex;
    try {
      rawIndex = jsonDecode(indexRes.body);
    } on Object catch (e) {
      _incomplete = true;
      _log('sync: static index for $bucket v$schema is not JSON: $e');
      return 0;
    }
    if (rawIndex is! List) {
      _incomplete = true;
      _log('sync: static index for $bucket v$schema is not a list');
      return 0;
    }
    final chunks = <({int to, String file})>[];
    for (final c in rawIndex) {
      if (c is! Map) {
        _incomplete = true;
        return 0;
      }
      final to = c['to'];
      final file = c['file'];
      if (to is int &&
          file is String &&
          file.isNotEmpty &&
          !file.contains('/') &&
          !file.contains('..')) {
        chunks.add((to: to, file: file));
      } else {
        _incomplete = true;
        return 0;
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
        _incomplete = true;
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
      final page = _decodePage(body, requireMore: false);
      if (page == null) {
        _incomplete = true;
        _log('sync: static chunk ${chunk.file} has a body this host cannot decode');
        return applied;
      }
      applied += await store.applyPullPage(
        bucket: bucket,
        schema: schema,
        rows: page.rows,
        maxUsnAfter: chunk.to,
        complete: false,
      );
      await renewLease();
      if (byteBudget != null && spent >= byteBudget && chunks.any((c) => c.to > chunk.to)) {
        _incomplete = true;
        budgetExhausted = true;
        _log('sync: static pull $bucket v$schema hit the $byteBudget byte budget; backing off');
        return applied;
      }
    }
    await store.completePull(bucket, schema);
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
    final authHeaders = await _headers(bucket);
    final res = await _client.post(
      Uri.parse('${config.syncBase}/$bucket/push'),
      headers: {'content-type': 'application/json', ...authHeaders},
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
    if (res.statusCode == 401 && authHeaders.containsKey('authorization')) {
      // The ops stay queued: a rejected token loses nothing, and they push once the page sets a new one.
      _rejected('push $bucket');
      return 0;
    }
    if (res.statusCode != 200) {
      _incomplete = true;
      _log('sync: push $bucket returned HTTP ${res.statusCode}; keeping ${ops.length} ops queued');
      return 0;
    }
    final Object? raw;
    try {
      raw = jsonDecode(res.body);
    } on Object catch (e) {
      _incomplete = true;
      _log('sync: push $bucket returned a body that is not JSON: $e');
      return 0;
    }
    if (raw is! Map<String, Object?>) {
      _incomplete = true;
      _log('sync: push $bucket returned a body that is not an object');
      return 0;
    }
    if (raw['acked'] is! List ||
        raw['rows'] is! List ||
        (raw['acked'] as List).any((a) => a is! String) ||
        (raw['rows'] as List).any((r) => !_validRow(r))) {
      _incomplete = true;
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

  /// Records a rejected token and tells the page once (§4.4).
  ///
  /// The token is **kept**: a refresh flow usually has to present the expired one, and clearing it here
  /// would also throw away a token that a clock-skewed or briefly misconfigured server rejected.
  void _rejected(String what) {
    _incomplete = true;
    _log('sync: $what returned HTTP 401; the bearer token was rejected');
    if (_unauthorized) return;
    _unauthorized = true;
    onUnauthorized?.call();
  }

  Future<Map<String, String>> _headers(String bucket) async {
    // §5.3: the bearer token is for user buckets. A public read-only bucket is fetched unauthenticated,
    // so a CDN can serve it and a cache can keep it.
    if (!config.writableBuckets.contains(bucket)) return const {};
    final token = await config.authToken?.call();
    return token == null || token.isEmpty ? const {} : {'authorization': 'Bearer $token'};
  }

  bool _validRow(Object? r) => r is Map<String, Object?> && r['k'] is String && r['u'] is int;

  ({List<Map<String, Object?>> rows, int max, bool more})? _decodePage(String body,
      {bool requireMore = true}) {
    final Object? raw;
    try {
      raw = jsonDecode(body);
    } on Object {
      return null;
    }
    if (raw is! Map<String, Object?>) return null;
    final rows = raw['rows'];
    if (rows is! List) return null;
    if (raw['max'] is! int ||
        (requireMore && raw['more'] is! bool) ||
        rows.any((r) => !_validRow(r))) {
      _incomplete = true;
      return null;
    }
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
