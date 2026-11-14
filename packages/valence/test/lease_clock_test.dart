// K F-83: a queued lease read must not compare a newer row against an old clock.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  const syncLeaseKey = 'valence.sync.lease';
  test('a queued acquisition respects a sibling renewal made while it waited',
      () async {
    final key = await TestKey.create();
    final store = await openTestStore();
    var now = DateTime(2026, 11, 8);
    ValenceSync driver() => ValenceSync(
          store: store,
          config: testConfig(key),
          client: MockClient((_) async => http.Response('{}', 200)),
          clock: () => now,
        );
    final holder = driver();
    final contender = driver();
    expect(await holder.acquireLease(), isTrue);
    final takenAt = now.millisecondsSinceEpoch;
    final entered = Completer<void>();
    final resume = Completer<void>();
    late String renewed;
    // Hold the real SQLite transaction queue. This transaction represents a sibling's
    // page/renewal completing after the contender starts waiting for its own transaction.
    final renewal = store.db.transaction((txn) async {
      entered.complete();
      await resume.future;
      renewed = '${now.millisecondsSinceEpoch}:$pid:foreground:$takenAt';
      await txn.update(
          'prefs',
          {
            'value': renewed,
          },
          where: 'key = ?',
          whereArgs: [syncLeaseKey]);
    });
    await entered.future;
    final acquisition = contender.acquireLease();
    now = now.add(const Duration(seconds: 11));
    resume.complete();
    await renewal;
    expect(await acquisition, isFalse,
        reason: 'the sibling is still holding the lease');
    expect(await store.hostPrefGet(syncLeaseKey), renewed);
    expect((await contender.status()).leaseAgeMs, 11000);
    await holder.releaseLease();
    expect(await contender.acquireLease(), isTrue);
    await contender.releaseLease();
  });

  test('a queued acquisition dates a new lease after the database wait',
      () async {
    final key = await TestKey.create();
    final store = await openTestStore();
    var now = DateTime(2026, 11, 8);
    ValenceSync driver() => ValenceSync(
          store: store,
          config: testConfig(key),
          client: MockClient((_) async => http.Response('{}', 200)),
          clock: () => now,
        );
    final holder = driver();
    final entered = Completer<void>();
    final resume = Completer<void>();
    final blocker = store.db.transaction((txn) async {
      entered.complete();
      await resume.future;
    });
    await entered.future;
    final acquisition = holder.acquireLease();
    now = now.add(const Duration(minutes: 3));
    resume.complete();
    await blocker;
    expect(await acquisition, isTrue);
    expect(await store.hostPrefGet(syncLeaseKey),
        '${now.millisecondsSinceEpoch}:$pid:foreground:${now.millisecondsSinceEpoch}');
    final contender = driver();
    expect(await contender.acquireLease(), isFalse,
        reason: 'a database wait must not consume the new holder\'s TTL');
    expect((await contender.status()).leaseAgeMs, 0);
    await holder.releaseLease();
  });
}
