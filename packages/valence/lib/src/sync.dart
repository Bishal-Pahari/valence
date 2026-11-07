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
  ///
  /// Also a **local** failure that stopped a run already under way: a background isolate meeting the UI
  /// isolate's lock mid-run reports this rather than throwing (§5.6, K F-80). Not `busy`, which promises
  /// nothing was attempted.
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
      {required this.pending,
      required this.lastSyncedAt,
      required this.offline,
      this.reason,
      this.leaseKind,
      this.leaseAgeMs});

  /// Remaining operations, including deletes and repeated edits.
  final int pending;

  /// Last successful unscoped sync, in epoch milliseconds; null before one.
  final int? lastSyncedAt;

  /// Whether the last attempted run had a transport failure; false before an attempt.
  final bool offline;

  /// Last completed attempt, including scoped runs; null before one. An open string set.
  final String? reason;

  /// What kind of run holds the sync lease right now, or null when nothing does (§5.6).
  ///
  /// `foreground`, `background` or `push` — and `unknown` for a lease written by a host older than this
  /// one, which records no kind. **Never null just because the kind is unreadable:** null means a run
  /// starting now would not be refused, and conflating "free" with "held by something I cannot name" is
  /// the diagnosability bug this field exists to close (C F-44).
  ///
  /// An open string set, read the same way as [reason].
  final String? leaseKind;

  /// How long the current holder has held the lease, in milliseconds, or null when it is free.
  ///
  /// Measured from when the holder **took** the lease, not from its last renewal (K F-81). Those are
  /// different numbers because [ValenceSync.renewLease] rewrites the row after every applied page, and
  /// the renewal is what [syncLeaseTtl] is judged against — so a row-dated age falls back towards zero
  /// every page and a reader watching one hold sees it decrease. An age that goes backwards is not an
  /// age, and this is the one instrument §5.6 offers for a lease it declines to pre-empt (K F-80).
  /// A row written before this field was recorded has no take-time, so it reports the row's age. The
  /// number never goes negative: a row dated ahead of now reports zero (K F-83).
  ///
  /// Non-null on exactly the same condition as [leaseKind]: the lease is within [syncLeaseTtl] of now
  /// **on either side** *and* owned by this process, which is the predicate
  /// [ValenceSync.acquireLease] refuses on. A lease this host would take over — expired, further ahead
  /// than the TTL, or left by a launch that is gone — reports free, because it is not what a `busy`
  /// answer is about. The log names those cases instead. A row *this process wrote* that reads as
  /// future-dated reports **held**, with an age of zero: a matching pid means a sibling isolate that is
  /// running, and the clock is not the instrument for that question (K F-83).
  final int? leaseAgeMs;
}

/// What kind of run holds the sync lease (§5.6). The wire values are the names.
enum ValenceSyncKind {
  /// A run on the UI isolate: UI start, resume, connectivity, `sync.now`, or the updater's step 7 pull.
  foreground,

  /// A run in the background isolate, fired by `workmanager` or BGTaskScheduler.
  background,

  /// A run woken by a data-only push message.
  push,
}

/// The prefs key holding the sync lease. Reserved: the bridge refuses `valence.*` from the page (§4.2).
const syncLeaseKey = 'valence.sync.lease';

/// How long a lease stays valid. A holder that dies releases it by expiry.
const syncLeaseTtl = Duration(minutes: 2);

/// A lease row this host would be refused by: its age and the kind of run holding it.
typedef _HeldLease = ({int ageMs, String kind});

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
    this.kind = ValenceSyncKind.foreground,
  })  : _client = client ?? http.Client(),
        _log = log,
        _now = clock ?? DateTime.now;

  /// What kind of run this driver performs, recorded in the lease and reported by [status] (§5.6).
  ///
  /// A property of the driver rather than of one [run]: the UI isolate builds exactly one, and the
  /// updater's step 7 pull shares it, which is honest — that pull runs on the foreground triggers.
  final ValenceSyncKind kind;

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
        () => store.db.query('prefs', where: 'key IN (?, ?, ?, ?)', whereArgs: [
              'valence.sync.lastSyncedAt',
              'valence.sync.offline',
              'valence.sync.reason',
              syncLeaseKey,
            ]),
        _log);
    final values = {for (final row in rows) row['key']: row['value']};
    // Read in the same query as the observations: one round trip rather than two. It is not an atomic
    // snapshot and does not need to be — `pendingWrites` is a separate read, the clock is sampled after
    // the query returns, and `run` relies on a lease released since its refusal reading as free.
    final held = _heldLease(values[syncLeaseKey] as String?, _now().millisecondsSinceEpoch);
    return ValenceSyncStatus(
      pending: await store.pendingWrites(),
      lastSyncedAt: int.tryParse(values['valence.sync.lastSyncedAt'] as String? ?? ''),
      offline: values['valence.sync.offline'] == 'true',
      reason: values['valence.sync.reason'] as String?,
      leaseKind: held?.kind,
      leaseAgeMs: held?.ageMs,
    );
  }

  /// Bytes of row payload this driver has applied. Used to budget §2.3 step 7.
  int bytesApplied = 0;

  /// When [run] took the lease, for the held-for figure in its release line.
  int _leaseTakenAt = 0;

  // ---------------------------------------------------------------------------
  // The lease (§5.6)
  // ---------------------------------------------------------------------------

  /// Takes the lease, or returns false when another sync holds it.
  ///
  /// sqflite runs `transaction` as `BEGIN IMMEDIATE`, which is what makes the read-then-write atomic
  /// across isolates. A lease time in the **future**, from clock skew or tampering, counts as expired —
  /// but only when it is further ahead than the TTL, and never for a row this process wrote (K F-83).
  Future<bool> acquireLease() async {
    var now = 0;
    var taken = false;
    await databaseOperation(
        'sync.acquireLease',
        () => store.db.transaction((txn) async {
              // Sampled **inside** the transaction, after `BEGIN IMMEDIATE` has stopped waiting — not
              // before the call (K F-83). The wait is the whole problem: a sibling isolate mid-pull holds
              // the file, so this transaction can start seconds after the method was called, and a `now`
              // from before the wait is older than the renewal it is about to read. The row then looks
              // future-dated, the clock-moved branch below takes a *live* lease away from a run that is
              // still working, and two syncs write one database — on a device whose clock never moved.
              // It then writes that stale `now` back as its own take-time, so the next reader sees an age
              // that is eleven seconds too old. Both numbers come from this one line.
              now = _now().millisecondsSinceEpoch;
              final rows = await txn.query(
                'prefs',
                columns: ['value'],
                where: 'key = ?',
                whereArgs: [syncLeaseKey],
                limit: 1,
              );
              final raw = rows.isEmpty ? null : rows.first['value'] as String;
              final (held, owner, leftBy, _) = _readLease(raw);
              final live = held != null && held > now - syncLeaseTtl.inMilliseconds && held <= now;
              // The mirror of the foreign-pid rule below, and the belt to its braces: a pid that is *mine*
              // means a sibling isolate that is running, so the TTL is not the instrument for it. A row
              // ahead of us by less than the TTL is therefore held, not expired, and the clock is not
              // consulted about it. Beyond the TTL the clock really has moved and the row is freed, which
              // is what keeps this self-healing rather than a two-minute block that a backwards clock
              // could extend indefinitely.
              final mine = held != null && owner == pid && held > now && held - now < syncLeaseTtl.inMilliseconds;
              // A lease recorded by **another process** cannot be held by anything running now. The lease exists to
              // keep the UI isolate and the background isolate apart, and those share this process (§5.6), so the
              // only way to see a foreign pid is a launch that is gone: a crash, a force-stop, or Android reclaiming
              // the app. Waiting out the two minutes in that case blocks every sync of the new launch and reports
              // each one as a successful empty sync, which is exactly when a user has just reopened a stale app.
              // A recycled pid that matches ours degrades to the old behaviour: we wait for the expiry.
              //
              // ponytail: single-process assumption. A host that puts a service in its own `android:process` would
              // need the owner to be a token both processes agree on, written at launch.
              if ((live || mine) && owner == pid) return;
              // Every row we displace is named, not only the foreign-pid one: an expired or
              // future-dated takeover is otherwise byte-identical in the log to a clean acquisition, and
              // it is the state a developer chasing a leak most needs explained — `status()` reports it
              // free, correctly, so the log is the only place left to say a row was there.
              if (held != null) {
                // Never a negative "written ... ago": a number that reads as an age and is not one sends a
                // developer looking for the wrong fault, which is how K F-83 spent a day being a clock bug.
                final age = now - held;
                final when = age < 0 ? 'dated ${-age}ms in the future' : 'written ${age}ms ago';
                // The expiry is named first when it applies, because it is what freed the row whoever wrote
                // it; a foreign pid is the reason only for a row that would otherwise be live, or one ahead
                // of us — where the clock is *not* the reason, since the pid already settled it. Only a row
                // of our own can get here ahead of `now`, and only by more than the TTL, which is the one
                // case where "the clock moved" is a claim worth making (K F-83).
                final why = held <= now - syncLeaseTtl.inMilliseconds
                    ? 'past its ${syncLeaseTtl.inMinutes}-minute expiry'
                    : owner == null
                        ? 'written by an older host, which records no owner'
                        : owner != pid
                            ? 'left by process $owner, which is gone'
                            : 'further ahead than its ${syncLeaseTtl.inMinutes}-minute expiry, so the clock moved';
                diagnosticLog(_log, 'sync: taking over a lease (kind=${leftBy ?? 'unknown'}, $when): $why');
              }
              await txn.insert(
                'prefs',
                {'key': syncLeaseKey, 'value': _leaseValue(now, now)},
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              taken = true;
            }),
        _log);
    if (taken) {
      // Logged here rather than in `run`, so the three paths that take the lease without going through
      // it — §2.3 step 7's pull, the GC's pair step and the §4.4 account switch — get the pair too.
      // Without that, the worst case is F-44's own: a reconnect fires a sync *and* an update check, and
      // step 7 holds the lease across several pairs' downloads, so the page's probe collects twenty
      // `holder=foreground` lines with no "took the lease" anywhere to pair them against.
      _leaseTakenAt = now;
      diagnosticLog(_log, 'sync: took the lease kind=${kind.name} pid=$pid');
    }
    return taken;
  }

  /// Pushes the lease forward. Call after every applied page, so a long `since = 0` pull keeps it.
  ///
  /// Renewing rewrites the kind too, so the holder a refused run is told about is the holder as of the
  /// last page rather than as of acquisition. It **carries the take-time through unchanged**, because
  /// that is the only field a renewal must not move: it is what [ValenceSyncStatus.leaseAgeMs] is
  /// measured from, and rewriting it is what made the reported age fall towards zero every page
  /// (K F-81). Zero means this driver never took the lease — the §4.4 account switch renews nothing,
  /// so the only reader of that branch is a test — and the renewal then starts the age here.
  Future<void> renewLease() {
    final now = _now().millisecondsSinceEpoch;
    return store.hostPrefSet(syncLeaseKey, _leaseValue(now, _leaseTakenAt == 0 ? now : _leaseTakenAt));
  }

  String _leaseValue(int millis, int takenAt) => '$millis:$pid:${kind.name}:$takenAt';

  /// Reads the lease row as `(millis, pid, kind, takenAt)`.
  ///
  /// `<millis>:<pid>:<kind>:<takenAt>` since K F-81; `<millis>` is the last renewal, which is what the
  /// TTL is judged against, and `<takenAt>` is acquisition, which is what the reported age is measured
  /// from. The fields are appended, never redefined: §5.6's first diagnostics wrote
  /// `<millis>:<pid>:<kind>`, a 0.4 host before them wrote `<millis>:<pid>` and a 0.3 host wrote
  /// `<millis>`. All of them read back with the trailing fields null, and a null owner never matches
  /// this process — so the first launch after an upgrade clears it.
  ///
  /// **A host older than this one reads a three-field row as live with no owner**, because its parser
  /// took everything after the first colon as the pid and `int.tryParse` refuses `4893:foreground`. It
  /// therefore takes the row over, which is the right action — a downgrade means the writer is gone — but
  /// it loses the pid and its log line calls a newer row an older one. Mutual exclusion is unaffected:
  /// two hosts of different versions can never run at once.
  static (int?, int?, String?, int?) _readLease(String? raw) {
    if (raw == null) return (null, null, null, null);
    final parts = raw.split(':');
    return (
      int.tryParse(parts[0]),
      parts.length > 1 ? int.tryParse(parts[1]) : null,
      parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      parts.length > 3 ? int.tryParse(parts[3]) : null,
    );
  }

  /// The lease as a run starting now would find it: non-null exactly when [acquireLease] would refuse.
  ///
  /// The two read the same predicate so they cannot drift — a status that reported a holder this host
  /// would simply take over would send a developer looking for a lease leak that does not exist.
  /// A held row with no kind — written before this revision, by a launch whose pid this process
  /// happens to have — reports `unknown` rather than reading as free.
  static _HeldLease? _heldLease(String? raw, int now) {
    final (held, owner, kind, takenAt) = _readLease(raw);
    if (held == null || owner != pid) return null;
    // One predicate with `acquireLease`, including the ahead-of-us case: a row this process wrote is a
    // sibling that is running, so it is held whichever side of `now` its timestamp falls, and only a move
    // bigger than the TTL frees it (K F-83). Reporting such a row free while `acquireLease` refuses on it
    // is the drift this doc comment exists to forbid — it would answer `busy` with no holder to name.
    if (held <= now - syncLeaseTtl.inMilliseconds || held - now >= syncLeaseTtl.inMilliseconds) return null;
    // Liveness is the renewal's question and the age is acquisition's, so they read different fields.
    // A take-time in the future — a row from before the clock moved back, or one an older host wrote
    // without the field — falls back to the renewal. Never a negative age: §5.6 asks a developer to
    // compare this against "is the holder stuck?", and a negative number answers a different question
    // (K F-81), so a renewal that is itself ahead of us floors at zero rather than going backwards.
    final from = (takenAt != null && takenAt <= now) ? takenAt : held;
    return (ageMs: from > now ? 0 : now - from, kind: kind ?? 'unknown');
  }

  /// Releases the lease.
  ///
  /// Logs the other half of the pair [acquireLease] opens, so a holder that was torn down without
  /// reaching here is a *missing* line rather than something inferred from a later `busy`.
  /// A `heldForMs` above [syncLeaseTtl] says the lease had already expired and may have been taken over
  /// mid-run, which this unconditional delete then clears out from under its new holder.
  Future<void> releaseLease() async {
    await store.hostPrefSet(syncLeaseKey, null);
    // Zero when this driver never took it: the account switch releases unconditionally, and a line
    // claiming a 56-year hold would be the kind of wrong number these diagnostics exist to stop.
    if (_leaseTakenAt == 0) return;
    final held = _now().millisecondsSinceEpoch - _leaseTakenAt;
    _leaseTakenAt = 0;
    diagnosticLog(_log, 'sync: released the lease kind=${kind.name} heldForMs=$held');
  }

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
    final bool took;
    try {
      took = await acquireLease();
    } on Object catch (e) {
      // A lock *here* is the one case `busy` describes exactly: no lease, no pull, no push, nothing
      // observed. The UI isolate is writing and is itself about to sync, so this is the same answer the
      // locked store open gives, for the same reason (§5.6).
      if (!isDatabaseLocked(e)) rethrow;
      diagnosticLog(_log, 'sync: the database was locked taking the lease, so this run never started '
          'kind=${kind.name}');
      return const ValenceSyncResult([], 0, false, ValenceSyncReason.busy);
    }
    if (!took) {
      // Name the holder and its age, or four iterations of "busy" evidence cannot tell a foreground run
      // that is legitimately still working from a cancelled background isolate that never released
      // (C F-44). `status()` re-reads the row, so a lease released in the microseconds since the refusal
      // reports free — which is itself the answer, and better than naming a holder that has gone.
      // And the read is guarded, because it is only a *diagnostic*: the answer is already decided. The
      // single state that reaches this branch is a sibling mid-pull holding the file, which is exactly
      // when this read can lock — so throwing here would answer a bridge error where §5.6 promises
      // `busy`, on the one path where "nothing was attempted" is unambiguously true.
      ValenceSyncStatus? held;
      try {
        held = await status();
      } on Object catch (e) {
        if (!isDatabaseLocked(e)) rethrow;
      }
      diagnosticLog(
          _log,
          held == null
          ? 'sync: another sync holds the lease; skipping this run (the database was locked reading who '
              'holds it, which is the holder still writing) kind=${kind.name}'
          : held.leaseKind == null
          ? 'sync: another sync holds the lease; skipping this run (it was released before this line, '
              'so the next run should get it) kind=${kind.name}'
          : 'sync: another sync holds the lease; skipping this run '
              'holder=${held.leaseKind} heldForMs=${held.leaseAgeMs} refused=${kind.name}');
      return ValenceSyncResult([], 0, false, ValenceSyncReason.busy, held?.pending ?? 0);
    }
    final touched = <String>[];
    var changed = 0;
    var attempted = 0;
    var offline = false;
    var unauthorized = false;
    var reason = ValenceSyncReason.failed;
    void applied(String bucket, int count) {
      changed += count;
      if (!touched.contains(bucket)) touched.add(bucket);
    }

    try {
      _unauthorized = false;
      _incomplete = false;
      Object? primaryError;
      StackTrace? primaryStack;
      try {
        final wanted = only?.toSet();
        for (final e in readSchemas.entries) {
          if (wanted != null && !wanted.contains(e.key)) continue;
          attempted++;
          try {
            await _pullPair(e.key, e.value, onApplied: (n) => applied(e.key, n));
            if (!touched.contains(e.key)) touched.add(e.key);
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
            await _pullPair(bucket, 1, onApplied: (n) => applied(bucket, n));
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
      } on Object catch (e, stack) {
        primaryError = e;
        primaryStack = stack;
        rethrow;
      } finally {
        unauthorized = _unauthorized;
        try {
          await releaseLease();
        } on Object catch (cleanupError) {
          // Logged *before* either branch below, because every one of them leaves this block: the two
          // likeliest pairings — a lock during work with a lock on the release, and a real bug with a lock
          // on the release — both rethrow, and §5.6 asks for this line precisely because the row then
          // stands until the TTL expires it. Without it, "took" with no "released" is indistinguishable
          // from a torn-down isolate, which is the inference S9's diagnostics exist to remove. A cleanup
          // failure that is *not* a lock gets a line too when it is about to be dropped for a primary
          // error: an unreported disk fault is the kind of thing that is only ever found in a log.
          diagnosticLog(
              _log,
              isDatabaseLocked(cleanupError)
                  ? 'sync: could not release the lease, so it stands until it expires '
                      'kind=${kind.name}: $cleanupError'
                  : 'sync: releasing the lease failed, so it stands until it expires '
                      'kind=${kind.name}: $cleanupError');
          // A cleanup lock must not turn a non-lock failure into a recovered result.
          if (primaryError != null &&
              (!isDatabaseLocked(primaryError) || isDatabaseLocked(cleanupError))) {
            Error.throwWithStackTrace(primaryError, primaryStack!);
          }
          if (!isDatabaseLocked(cleanupError)) rethrow;
        }
      }
    } on Object catch (e) {
      if (!isDatabaseLocked(e)) rethrow;
      // Keep committed progress even if a later page, observation write or lease release locks.
      // A lock does not erase an earlier authentication or network failure either (contracts 5.6).
      reason = unauthorized
          ? ValenceSyncReason.unauthorized
          : offline
              ? ValenceSyncReason.offline
              : ValenceSyncReason.failed;
      // The counters stay in the line. Where the caller's own backstop answers instead of this result —
      // the background isolate's does, with zeros — this is the only surviving record of what was
      // applied, because a successful `applyPullPage` logs nothing.
      diagnosticLog(
          _log,
          'sync: the database was locked mid-run, so this run stopped short '
          'kind=${kind.name} pid=$pid pulled=${touched.length} changed=$changed');
    }
    // A lock on the last read must not discard a classified result. The whole point of the paragraph
    // above is that a run which committed pages reports them, and the outbox count is the one field that
    // still needs the database after the lease is gone — so losing the result to *that* read would undo
    // the fix on exactly the contended device it was written for. `run` is also called by a page, which
    // the background isolate's backstop cannot help: that frame returns zeros, and only here are the
    // buckets and the `changed` count still in hand. An unknown count reads as 0, which is what the
    // `busy` and open-failure paths already return, and the log line is what distinguishes them.
    // Non-locks still throw, so a real bug reaches the caller.
    var pending = 0;
    try {
      pending = await store.pendingWrites();
    } on Object catch (e) {
      if (!isDatabaseLocked(e)) rethrow;
      // An unknown count reads as zero, which is what `busy` and a locked open already answer — but those
      // two say nothing about the data, and `ok` does. `ok` with `pending: 0` is rendered as "everything
      // is saved", over an outbox this run could not read, so the outcome degrades to `failed`: the run
      // was attempted and is incomplete, which is exactly what §5.6 gives that word to. The buckets and
      // the `changed` count are still the ones it earned. The *persisted* outcome is left as it was: the
      // data sync really did complete, and poisoning `sync.status` for every later read because one count
      // was unreadable for a few seconds would be the opposite of this rule.
      if (reason == ValenceSyncReason.ok) reason = ValenceSyncReason.failed;
      diagnosticLog(
          _log,
          'sync: the database was locked reading the outbox count, so this result says 0 pending '
          'and reports $reason kind=${kind.name} pid=$pid');
    }
    return ValenceSyncResult(touched, changed, offline, reason, pending);
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
  Future<int> pullPair(String bucket, int schema, {int? byteBudget}) =>
      _pullPair(bucket, schema, byteBudget: byteBudget);

  Future<int> _pullPair(String bucket, int schema,
      {int? byteBudget, void Function(int)? onApplied}) async {
    budgetExhausted = false;
    if (config.syncMode == ValenceSyncMode.staticChunks &&
        !config.writableBuckets.contains(bucket)) {
      return _pullStatic(bucket, schema, byteBudget: byteBudget, onApplied: onApplied);
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
      final count = await store.applyPullPage(
        bucket: bucket,
        schema: schema,
        rows: page.rows,
        maxUsnAfter: cursor,
        complete: !page.more,
      );
      applied += count;
      onApplied?.call(count);
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
  Future<int> _pullStatic(String bucket, int schema,
      {int? byteBudget, void Function(int)? onApplied}) async {
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
      final count = await store.applyPullPage(
        bucket: bucket,
        schema: schema,
        rows: page.rows,
        maxUsnAfter: chunk.to,
        complete: false,
      );
      applied += count;
      onApplied?.call(count);
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

  /// §5.3's row shape. **`u` must be non-negative**, which strict decoding owes §5.5.1: the union gives
  /// cache rows `usn: -2` and a pending write `-1`, and those two numbers are the only way a page can
  /// tell a local-only overlay from a row the server vouched for. A pull that accepted `u: -2` would
  /// write a `kv` row no `data.list` reader could distinguish from its own cache — so a server could make
  /// its rows read as page-supplied, or make a page's retention logic delete rows it does not own. A
  /// server USN counts up from 1; a negative one is malformed, and it would also corrupt `max_usn`.
  bool _validRow(Object? r) =>
      r is Map<String, Object?> && r['k'] is String && r['u'] is int && (r['u'] as int) >= 0;

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
