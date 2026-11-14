// Contracts §5.3 to §5.6: paged pulls, push, the static variant, and the one-sync-at-a-time lease.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
      // Clock skew or tampering must not be able to park every sync for ever. This row records no owner,
      // so the K F-83 rule below does not apply to it: nothing running now can be holding it.
      await store.hostPrefSet('valence.sync.lease', '${DateTime(2030).millisecondsSinceEpoch}');
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)));
      expect(await s.acquireLease(), isTrue);
    });

    test('a sibling isolate keeps a lease the acquirer reads as future-dated (K F-83)', () async {
      // `BEGIN IMMEDIATE` waits behind the sibling's writes, so a clock sampled before the transaction
      // starts is older than the renewal the transaction then reads: the row looks future-dated, the
      // clock-moved branch takes a *live* lease away from a run that is still working, and two syncs
      // write one database — on a device whose clock never moved, which is how this was filed as a clock
      // bug. The acquisition now samples inside the transaction; the stale clock here is that wait, in
      // the only form a test can hold still. A pid that is mine means a sibling that is running.
      final taken = DateTime(2026, 11, 8, 0, 43, 18);
      final holder = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => taken);
      expect(await holder.acquireLease(), isTrue);
      final log = LogSpy();
      final late = syncWith(MockClient((_) async => fail('must not reach the network')),
          clock: () => taken.subtract(const Duration(seconds: 11)), log: log);
      expect(await late.acquireLease(), isFalse, reason: 'two syncs over one database is what the lease prevents');
      expect(log.has('taking over a lease'), isFalse);
      // The refusal's own number is what §5.6 offers in place of the pre-emption it declines, so it may
      // not go negative either: `status` and `acquireLease` read one predicate and must agree the row is
      // held, and "written -11080ms ago" is not an age.
      final status = await late.status();
      expect(status.leaseKind, 'foreground');
      expect(status.leaseAgeMs, 0);
      expect(log.has('written -'), isFalse);
    });

    test('a clock that really moved back still frees the lease (K F-83)', () async {
      // The other side of the same rule: ahead of us by *more* than the TTL is a clock that moved, not a
      // sibling, and it must not park sync for as long as the clock stays behind.
      final taken = DateTime(2026, 11, 8, 0, 43, 18);
      final holder = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => taken);
      expect(await holder.acquireLease(), isTrue);
      final log = LogSpy();
      final after = syncWith(MockClient((_) async => http.Response('{}', 200)),
          clock: () => taken.subtract(const Duration(minutes: 3)), log: log);
      expect(await after.acquireLease(), isTrue);
      expect(log.has('at or beyond its 2-minute expiry, so the clock moved'), isTrue);
      expect(log.has('dated 180000ms in the future'), isTrue, reason: 'the magnitude, with its direction');
    });

    test('a row written now reads as an age of about zero, never a negative one (K F-83)', () async {
      final now = DateTime(2026, 11, 8, 1, 46, 21);
      final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
      expect(await s.acquireLease(), isTrue);
      expect((await s.status()).leaseAgeMs, 0);
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

    // S9 / C F-44: `busy` alone cannot tell a foreground run that is legitimately still working from a
    // cancelled background isolate that never released, which is what four iterations of app-c's
    // evidence says about itself. These are the diagnostics that turn the next reproduction into a
    // diagnosis; they deliberately change nothing about acquisition or expiry.
    group('who holds it (S9)', () {
      test('status names the holder and its age, and reports free when nothing holds it', () async {
        var now = DateTime(2026, 11, 4, 9);
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        final free = await s.status();
        expect(free.leaseKind, isNull, reason: 'null means a run starting now would not be refused');
        expect(free.leaseAgeMs, isNull);
        expect(await s.acquireLease(), isTrue);
        now = now.add(const Duration(milliseconds: 1500));
        final held = await s.status();
        expect(held.leaseKind, 'foreground');
        expect(held.leaseAgeMs, 1500);
        await s.releaseLease();
        expect((await s.status()).leaseKind, isNull);
      });

      test('the age belongs to the holder, and a renewal does not reset it (K F-81)', () async {
        // The renewal rewrites the lease row after every applied page, so an age dated from the row
        // falls back towards zero each page: on a device one continuous hold reported 628, 69, 81, 785
        // and 1060 ms while its real age ran 301 to 2054 ms, and two refusals against a 100-second
        // lease reported 28 ms and 58 ms. Section 5.6 declines to pre-empt a holder and makes this
        // number the instrument instead (K F-80), so an age that decreases points away from the cause.
        // Monotonic across a renewal is the cheap property that catches it.
        var now = DateTime(2026, 11, 7, 16, 27);
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        // Read through a *different* driver throughout: the refusals that report this are in the other
        // isolate, which has no in-memory take-time and can only read the row.
        final reader = syncWith(MockClient((_) async => fail('must not reach the network')),
            clock: () => now);
        expect(await s.acquireLease(), isTrue);
        now = now.add(const Duration(seconds: 1));
        expect((await reader.status()).leaseAgeMs, 1000);
        await s.renewLease();
        now = now.add(const Duration(milliseconds: 500));
        expect((await reader.status()).leaseAgeMs, 1500,
            reason: 'the renewal must carry the take-time through, not restart it');
        // The renewal still moves the TTL, which is the thing it exists for: this lease is live two
        // minutes past acquisition because it was renewed 90 seconds in.
        now = now.add(const Duration(milliseconds: 88500));
        await s.renewLease();
        now = now.add(const Duration(seconds: 30));
        expect((await reader.status()).leaseKind, 'foreground');
        expect((await reader.status()).leaseAgeMs, 120000);
        // And the release line now measures the same thing the refusals reported, which is what made
        // the device evidence unreadable: only `released` was right before this.
        final log = LogSpy();
        final paired = syncWith(MockClient((_) async => http.Response('{}', 200)),
            log: log, clock: () => now);
        await store.hostPrefSet('valence.sync.lease', null);
        expect(await paired.acquireLease(), isTrue);
        now = now.add(const Duration(seconds: 3));
        await paired.renewLease();
        final reported = (await reader.status()).leaseAgeMs;
        await paired.releaseLease();
        expect(log.has('heldForMs=$reported'), isTrue, reason: '${log.lines}');
      });

      test('a renewal by a driver that never took the lease dates the age from itself', () async {
        // Section 4.4's account switch releases without acquiring, so a zero take-time is reachable;
        // a row claiming a 56-year-old holder is the shape these diagnostics exist to stop.
        var now = DateTime(2026, 11, 7, 16, 27);
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        await s.renewLease();
        now = now.add(const Duration(seconds: 2));
        expect((await s.status()).leaseAgeMs, 2000);
      });

      test('a take-time the clock moved past reports the row age, never a negative one', () async {
        // A row written before the device clock went backwards. Section 5.6 asks a developer to compare
        // this against "is the holder stuck?", which a negative number cannot answer.
        final now = DateTime(2026, 11, 7, 16, 27);
        final at = now.millisecondsSinceEpoch;
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        await store.hostPrefSet('valence.sync.lease', '${at - 5000}:$pid:foreground:${at + 60000}');
        expect((await s.status()).leaseAgeMs, 5000);
      });

      test('the kind is the holder\'s, so a background run is distinguishable', () async {
        final now = DateTime(2026, 11, 4, 9);
        final bg = ValenceSync(
          store: store,
          config: testConfig(key, dataSchemas: {'plants': 1}),
          client: MockClient((_) async => http.Response('{}', 200)),
          log: LogSpy().call,
          clock: () => now,
          kind: ValenceSyncKind.background,
        );
        expect(await bg.acquireLease(), isTrue);
        // Read through a *different* driver: the kind comes off the row, not off the reader.
        final reader = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        expect((await reader.status()).leaseKind, 'background');
      });

      test('a lease this host would take over reports free, not held', () async {
        // Expired, far-future and foreign-pid leases are all ones `acquireLease` ignores, so reporting
        // them as holders would send a developer hunting a leak that the next run resolves by itself.
        // A row of *ours* dated inside the TTL on either side is a sibling that is running and reports
        // held, which is the K F-83 test above; the one here is ahead by more than the TTL, where the
        // clock really did move and the row is freed.
        final now = DateTime(2026, 11, 4, 9);
        final at = now.millisecondsSinceEpoch;
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        for (final raw in [
          '${at - 120001}:$pid:foreground',
          '${at + 120001}:$pid:foreground',
          '$at:${pid + 1}:background',
        ]) {
          await store.hostPrefSet('valence.sync.lease', raw);
          expect((await s.status()).leaseKind, isNull, reason: raw);
          expect((await s.status()).leaseAgeMs, isNull, reason: raw);
        }
      });

      test('a held lease written by an older host says unknown rather than free', () async {
        // The two 0.4 forms that record no kind. "Free" would be a lie on the one path where the page is
        // asking *because* it was refused.
        final now = DateTime(2026, 11, 4, 9);
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)), clock: () => now);
        await store.hostPrefSet('valence.sync.lease', '${now.millisecondsSinceEpoch}:$pid');
        expect((await s.status()).leaseKind, 'unknown');
        expect((await s.status()).leaseAgeMs, 0);
      });

      test('a refused run logs the holder and its age; a run logs taking and releasing', () async {
        var now = DateTime(2026, 11, 4, 9);
        final holder = ValenceSync(
          store: store,
          config: testConfig(key, dataSchemas: {'plants': 1}),
          client: MockClient((_) async => http.Response('{}', 200)),
          log: LogSpy().call,
          clock: () => now,
          kind: ValenceSyncKind.background,
        );
        await holder.acquireLease();
        now = now.add(const Duration(seconds: 7));
        final log = LogSpy();
        final refused = syncWith(MockClient((_) async => fail('must not reach the network')),
            log: log, clock: () => now);
        expect((await refused.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.busy);
        expect(log.has('holder=background'), isTrue);
        expect(log.has('heldForMs=7000'), isTrue);
        expect(log.has('refused=foreground'), isTrue);
        // And the pair of lines that makes a lease a background isolate never released a *missing* line
        // rather than an inference: an isolate torn down by WorkManager runs no `finally`.
        await holder.releaseLease();
        final ran = LogSpy();
        final s = syncWith(MockClient((_) async => http.Response('{"rows":[],"max":0,"more":false}', 200)),
            log: ran, clock: () => now);
        await s.run(readSchemas: {'plants': 1});
        expect(ran.has('took the lease kind=foreground'), isTrue);
        // heldForMs, not just the line: the docs tell an operator to judge a suspected leak by this
        // number, and an unset take-time would print an epoch-sized one with the test still green.
        expect(ran.has('released the lease kind=foreground heldForMs=0'), isTrue);
      });

      test('the took line dates the take-time it recorded, so the pair brackets heldForMs', () async {
        // K F-85. The line is emitted after the sample — the `BEGIN IMMEDIATE` wait, the read and the
        // commit sit between them — so on a device the two lease lines bracketed 91ms around a hold the
        // host correctly reported as 3039. Without the trail on the line there is nothing in the log
        // that accounts for the gap, and §5.6's old cross-reference, §5.1.1's `waiting` line, only fires
        // after ten seconds. A clock that answers later on each call is what a contended device is.
        // **One driver and one clock**, because the §8 claim is about the two lines *agreeing*: the
        // release's `heldForMs` minus the `took` line's trail is the gap a reader measures between the
        // two log timestamps. Two drivers would prove each number separately and tie neither, and a
        // regression that made the trail exceed the hold would pass.
        final at = DateTime(2026, 11, 4, 9);
        // 1: the in-transaction sample. 2: the trail, read when the line is written. 3: the release.
        const trail = 2951, hold = 4951;
        final steps = [
          at,
          at.add(const Duration(milliseconds: trail)),
          at.add(const Duration(milliseconds: hold)),
        ];
        var call = 0;
        final log = LogSpy();
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)),
            log: log, clock: () => steps[call < steps.length ? call++ : steps.length - 1]);
        expect(await s.acquireLease(), isTrue);
        expect(log.has('took the lease kind=foreground pid=$pid (dated ${trail}ms ago)'), isTrue);
        await s.releaseLease();
        // The release measures from the sample, not from the line, so the pair brackets it: a reader
        // subtracting the two log timestamps sees `hold - trail`, and the trail on the line is what
        // closes that gap. Both halves asserted against one timeline, and the gap is non-zero.
        expect(log.has('released the lease kind=foreground heldForMs=$hold'), isTrue);
        expect(hold - trail, 2000, reason: 'the bracket this test exists to pin is not zero');
        // Never a negative: a clock corrected backwards between the sample and the line reads as 0,
        // for the same reason `leaseAgeMs` floors there (K F-83).
        final back = LogSpy();
        var m = 0;
        final b = syncWith(MockClient((_) async => http.Response('{}', 200)),
            log: back, clock: () => m++ == 0 ? at : at.subtract(const Duration(seconds: 30)));
        expect(await b.acquireLease(), isTrue);
        expect(back.has('(dated 0ms ago)'), isTrue);
        // And a clock that *throws* on the trail read does not cost the caller its lease: the row is
        // already committed and `taken` is already true, so a diagnostic that threw here would leak the
        // lease for the whole TTL while reporting that the acquisition failed.
        await b.releaseLease();
        final thrown = LogSpy();
        var k = 0;
        final c = syncWith(MockClient((_) async => http.Response('{}', 200)),
            log: thrown, clock: () => k++ == 0 ? at : throw StateError('a clock may not break a lease'));
        expect(await c.acquireLease(), isTrue);
        expect(thrown.has('took the lease kind=foreground pid=$pid (dated 0ms ago)'), isTrue);
      });

      test('the pair covers the three paths that take the lease outside run()', () async {
        // Step 7's pull, the GC's pair step and the account switch all acquire directly. Without the
        // lines here, F-44's own case — a reconnect whose update check holds the lease across several
        // pairs' downloads — gives a page twenty holder= lines with nothing to pair them against.
        var now = DateTime(2026, 11, 4, 9);
        final log = LogSpy();
        final s = syncWith(MockClient((_) async => http.Response('{}', 200)),
            log: log, clock: () => now);
        expect(await s.acquireLease(), isTrue);
        expect(log.has('took the lease kind=foreground'), isTrue);
        now = now.add(const Duration(milliseconds: 2500));
        await s.releaseLease();
        expect(log.has('released the lease kind=foreground heldForMs=2500'), isTrue);
        // A release by a driver that never took it says nothing, rather than claiming a 56-year hold:
        // the account switch releases unconditionally.
        final naive = LogSpy();
        await syncWith(MockClient((_) async => http.Response('{}', 200)), log: naive).releaseLease();
        expect(naive.has('released the lease'), isFalse);
      });

      test('every displaced row is named, not only the one left by another process', () async {
        // status() reports an expired or future-dated lease free, correctly — so the log is the only
        // place that can say a row was there, and it used to say nothing for either case.
        final now = DateTime(2026, 11, 4, 9);
        final at = now.millisecondsSinceEpoch;
        for (final (raw, expected) in [
          ('${at - 180000}:${pid + 1}:background', 'past its 2-minute expiry'),
          ('${at + 180000}:$pid:foreground', 'at or beyond its 2-minute expiry, so the clock moved'),
          ('${at + 180000}:$pid:foreground', 'dated 180000ms in the future'),
          // Ahead of us but not ours: the pid settled it, so the clock is not the reason given.
          ('${at + 60000}:${pid + 1}:push', 'which is gone'),
          ('${at - 1000}:${pid + 1}:push', 'which is gone'),
          ('${at - 1000}', 'records no owner'),
        ]) {
          await store.hostPrefSet('valence.sync.lease', raw);
          final log = LogSpy();
          final s = syncWith(MockClient((_) async => http.Response('{}', 200)),
              clock: () => now, log: log);
          expect(await s.acquireLease(), isTrue, reason: raw);
          expect(log.has(expected), isTrue, reason: raw);
          await s.releaseLease();
        }
        // An empty lease row is not a displaced holder and says nothing.
        final clean = LogSpy();
        expect(
            await syncWith(MockClient((_) async => http.Response('{}', 200)),
                    clock: () => now, log: clean)
                .acquireLease(),
            isTrue);
        expect(clean.has('taking over a lease'), isFalse);
      });

      test('a throwing logger cannot leak the lease it is tracing', () async {
        // The take/release lines are observational. Before they went through diagnosticLog, a host whose
        // log routed into a not-yet-initialised crash reporter threw between acquisition and the
        // try/finally — leaving the row on disk, owner == pid, so every sync for two minutes answered
        // busy. That is the F-44 symptom, reachable from the diagnostic itself.
        final s = ValenceSync(
          store: store,
          config: testConfig(key, dataSchemas: {'plants': 1}),
          client: MockClient((_) async => http.Response('{"rows":[],"max":0,"more":false}', 200)),
          log: (_) => throw StateError('the sink is not ready'),
        );
        expect((await s.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.ok);
        expect(await store.hostPrefGet('valence.sync.lease'), isNull);
      });
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
      // A negative usn is refused here too, but by the strict-USN-order check rather than by the row
      // shape, so the case that pins `_validRow`'s bound is the static one below — this path would
      // still refuse it with the bound removed, and a test that cannot fail is worse than none.
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

    test('a chunk row with a negative usn is refused, so no server row can read as a cache row', () async {
      // The dynamic path refuses this already, for a different reason: it checks strict USN order
      // against the cursor, and -2 is not above it. A static chunk has no such check — `maxUsnAfter`
      // comes from the index, not from the rows — so without `_validRow`'s non-negative bound this
      // page writes a `kv` row at usn -2, which is what §5.5.1 tells a page means "my own cache
      // overlay". A page pruning by `usn === -2` would then delete a server row, and native code
      // reading provenance from `kv` could not tell the two apart either.
      for (final bad in [-1, -2]) {
        final r = recordingClient((req) async {
          if (req.url.path.endsWith('index.json')) {
            return http.Response(jsonEncode([{'from': 1, 'to': 5, 'file': 'c.json'}]), 200);
          }
          return http.Response(jsonEncode({'rows': [row('a', 1, bad)], 'max': 5}), 200);
        });
        final sync = syncWith(r.client, config: staticConfig());
        expect((await sync.run(readSchemas: {'plants': 1})).reason, ValenceSyncReason.failed,
            reason: 'usn $bad must make the run incomplete');
        expect(await store.get('plants', 1, 'a'), isNull, reason: 'usn $bad must write no row');
        expect(await store.maxUsn('plants', 1), 0);
      }
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

  test('the lease row is written from the clock after the wait, not before it (K F-83)', () async {
    // The root cause, pinned on its own. `BEGIN IMMEDIATE` waits for the sibling isolate, so a clock read
    // before the call is older than the row the transaction then writes — and the `mine` predicate covers
    // the *data* half of K F-83 independently, which means the sample could be hoisted back out of the
    // transaction and every other test here would still pass. What would silently come back is the
    // reported age: the row would carry a take-time from before the wait, so the next reader is told a
    // hold is seconds older than it is, which is K F-81's symptom arriving by a second route.
    var now = DateTime(2026, 11, 8, 0, 42, 57);
    // Eleven seconds is what the device log showed between the two readings.
    final waiting = await ValenceStore.open(await freshDbPath('waited.db'),
        factory: _WaitingFactory(() => now = now.add(const Duration(seconds: 11))));
    final s = ValenceSync(
      store: waiting,
      config: testConfig(key, dataSchemas: {'plants': 1}),
      client: MockClient((_) async => fail('must not reach the network')),
      log: LogSpy().call,
      clock: () => now,
    );
    expect(await s.acquireLease(), isTrue);
    final afterTheWait = now.millisecondsSinceEpoch;
    final raw = (await waiting.hostPrefGet('valence.sync.lease'))!.split(':');
    expect(raw.first, '$afterTheWait', reason: 'the renewal the TTL is judged against');
    expect(raw.last, '$afterTheWait', reason: 'and the take-time every reported age is measured from');
  });
}

/// A database whose every transaction costs time, which is what `BEGIN IMMEDIATE` does when the other
/// isolate holds the file. Nothing in `flutter_test` can hold a real cross-isolate lock, so the wait is
/// modelled as the test clock moving while the transaction starts.
final class _WaitingFactory implements DatabaseFactory {
  _WaitingFactory(this.wait);
  final void Function() wait;
  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) async =>
      _WaitingDatabase(await databaseFactoryFfi.openDatabase(path, options: options), wait);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _WaitingDatabase implements Database {
  _WaitingDatabase(this.inner, this.wait);
  final Database inner;
  final void Function() wait;
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) {
    wait();
    return inner.transaction(action, exclusive: exclusive);
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) => inner.execute(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) =>
      inner.rawQuery(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> query(String table,
          {bool? distinct,
          List<String>? columns,
          String? where,
          List<Object?>? whereArgs,
          String? groupBy,
          String? having,
          String? orderBy,
          int? limit,
          int? offset}) =>
      inner.query(table,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset);
  @override
  Future<int> insert(String table, Map<String, Object?> values,
          {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) =>
      inner.insert(table, values,
          nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      inner.delete(table, where: where, whereArgs: whereArgs);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
