import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:valence/valence.dart';

import 'package:valence/src/log.dart';
import 'helpers.dart';

void main() {
  late TestKey key;
  setUpAll(() async => key = await TestKey.create());
  testWidgets('waiting is observational, repeats, and stops after completion',
      (tester) async {
    final log = LogSpy();
    final gate = Completer<int>();
    var finished = false;
    final result =
        logDatabaseWait('store.get', () => gate.future, log.call).then((value) {
      finished = true;
      return value;
    });
    await tester.pump(const Duration(seconds: 9));
    expect(log.lines, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(log.lines.single, contains('waiting operation=store.get'));
    expect(finished, isFalse,
        reason: 'a diagnostic must not time out the read');
    await tester.pump(const Duration(seconds: 10));
    expect(log.lines.length, 2);
    gate.complete(42);
    await tester.pump();
    expect(await result, 42);
    expect(log.lines.last, contains('completed operation=store.get'));
    await tester.pump(const Duration(seconds: 30));
    expect(log.lines.length, 3, reason: 'the timer is cancelled');
  });

  testWidgets(
      'failures preserve identity/trace and do not print exception data',
      (tester) async {
    final log = LogSpy();
    final gate = Completer<int>();
    final error = StateError('private-token-and-sql-argument');
    final stack = StackTrace.fromString('original-operation-stack');
    Object? observed;
    StackTrace? observedStack;
    final result = logDatabaseWait('store.put', () => gate.future, log.call)
        .then<void>((_) {}, onError: (Object e, StackTrace st) {
      observed = e;
      observedStack = st;
    });
    await tester.pump(const Duration(seconds: 10));
    gate.completeError(error, stack);
    await tester.pump();
    await result;
    expect(observed, same(error));
    expect(observedStack.toString(), stack.toString());
    expect(log.lines.last, contains('failed operation=store.put'));
    expect(log.toString(), isNot(contains('private-token')));
    await tester.pump(const Duration(seconds: 20));
    expect(log.lines.length, 2);
  });

  testWidgets('fast operations and throwing diagnostic sinks keep their result',
      (tester) async {
    final log = LogSpy();
    expect(await logDatabaseWait('store.get', () async => 7, log.call), 7);
    await tester.pump(const Duration(seconds: 20));
    expect(log.lines, isEmpty);
    final gate = Completer<int>();
    void broken(String _) => throw StateError('sink failed');
    final result = logDatabaseWait('store.get', () => gate.future, broken);
    final trace = StartupTrace(broken)..start('store');
    await tester.pump(const Duration(seconds: 10));
    gate.complete(8);
    await tester.pump();
    expect(await result, 8);
    trace.complete();
    trace.fail();
  });

  testWidgets(
      'real store and sync boundaries name concurrent pending operations',
      (tester) async {
    ValenceStore.resetCacheForTests();
    final log = LogSpy();
    final database = _WaitingDatabase();
    final store = await ValenceStore.open('private-file-path',
        factory: _WaitingFactory(database), log: log.call);
    final read = store.get('private-bucket', 1, 'private-key');
    final pref = store.prefGet('private-pref');
    final write = store.put('private-bucket', 'private-key', 'private-value',
        opId: 'private-op');
    final sync =
        ValenceSync(store: store, config: testConfig(key), log: log.call);
    final status = sync.status();
    final lease = sync.acquireLease();
    await tester.pump(const Duration(seconds: 10));
    final waiting =
        log.lines.where((line) => line.startsWith('store: waiting')).toList();
    for (final name in [
      'store.get',
      'store.prefGet',
      'store.put',
      'sync.status',
      'sync.acquireLease'
    ]) {
      expect(waiting.where((line) => line.contains('operation=$name ')),
          hasLength(1));
    }
    expect(
        waiting
            .map((line) => RegExp(r'id=\d+').firstMatch(line)!.group(0))
            .toSet(),
        hasLength(5));
    expect(log.toString(), isNot(contains('private-')));
    database.gate.complete();
    await tester.pump();
    expect(await read, isNull);
    expect(await pref, isNull);
    await write;
    await status;
    expect(await lease, isFalse);
    await tester.pump(const Duration(seconds: 20));
    expect(log.lines.where((line) => line.startsWith('store: waiting')),
        hasLength(5));
    ValenceStore.resetCacheForTests();
  });

  testWidgets('pending open is labelled before it returns', (tester) async {
    ValenceStore.resetCacheForTests();
    final gate = Completer<Database>();
    final log = LogSpy();
    final store = ValenceStore.open('private-path',
        factory: _WaitingFactory.pending(gate.future), log: log.call);
    await tester.pump(const Duration(seconds: 10));
    expect(log.lines.single, contains('waiting operation=store.open'));
    gate.complete(_WaitingDatabase()..gate.complete());
    await tester.pump();
    await store;
    expect(log.lines.last, contains('completed operation=store.open'));
    ValenceStore.resetCacheForTests();
  });

  testWidgets('the first cached opener owns diagnostics for later operations',
      (tester) async {
    ValenceStore.resetCacheForTests();
    final first = LogSpy();
    final second = LogSpy();
    final database = _WaitingDatabase();
    final store = await ValenceStore.open('cached-private-path',
        factory: _WaitingFactory(database), log: first.call);
    final cached =
        await ValenceStore.open('cached-private-path', log: second.call);
    expect(cached, same(store));
    final read = cached.get('private-bucket', 1, 'private-key');
    await tester.pump(const Duration(seconds: 10));
    expect(first.lines.single, contains('waiting operation=store.get'));
    expect(second.lines, isEmpty);
    database.gate.complete();
    await tester.pump();
    await read;
    ValenceStore.resetCacheForTests();
  });

  test('a lock on a sync-owned operation is labelled, not just timed',
      () async {
    // The lease transaction and the status read belong to sync, not the store, and they called the wait
    // logger directly — so a real SQLITE_BUSY produced "store: failed operation=sync.acquireLease" with
    // no lock label, on two of the writes most likely to contend with the UI isolate. §5.1.1 promises
    // confirmed lock errors are labelled separately, whichever layer owns the query.
    ValenceStore.resetCacheForTests();
    final log = LogSpy();
    final database = _WaitingDatabase();
    final store = await ValenceStore.open('private-file-path',
        factory: _WaitingFactory(database), log: log.call);
    final sync =
        ValenceSync(store: store, config: testConfig(key), log: log.call);
    final lease = sync.acquireLease();
    final status = sync.status();
    database.gate.completeError(LockedDatabaseException());
    await expectLater(lease, throwsA(isA<DatabaseException>()));
    await expectLater(status, throwsA(isA<DatabaseException>()));
    expect(log.lines,
        contains('store: database locked operation=sync.acquireLease'));
    expect(log.lines, contains('store: database locked operation=sync.status'));
    expect(log.toString(), isNot(contains('private-')));
    ValenceStore.resetCacheForTests();
  });

  test('store lock wrapper preserves the error and logs no SQL or arguments',
      () async {
    ValenceStore.resetCacheForTests();
    final log = LogSpy();
    final error = LockedDatabaseException();
    final stack = StackTrace.fromString('original-open-stack');
    Object? observed;
    StackTrace? observedStack;
    try {
      await ValenceStore.open('private-path',
          factory: _WaitingFactory.pending(Future.error(error, stack)),
          log: log.call);
    } catch (e, st) {
      observed = e;
      observedStack = st;
    }
    expect(observed, same(error));
    expect(observedStack.toString(), stack.toString());
    expect(log.lines, ['store: database locked operation=store.open']);
    expect(log.toString(), isNot(contains('sql')));
    expect(log.toString(), isNot(contains('private-path')));
    ValenceStore.resetCacheForTests();
  });
}

class _WaitingFactory implements DatabaseFactory {
  _WaitingFactory(Database db) : result = Future.value(db);
  _WaitingFactory.pending(this.result);
  final Future<Database> result;

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) =>
      result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WaitingDatabase implements Database {
  final gate = Completer<void>();

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
      int? offset}) async {
    await gate.future;
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql,
          [List<Object?>? arguments]) async =>
      [
        {'n': 0}
      ];

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
      {bool? exclusive}) async {
    await gate.future;
    // The diagnostic observes the transaction future, not its internal SQL.
    return null as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
