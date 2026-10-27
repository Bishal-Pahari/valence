// Contracts section 5.2: row import and its completion marker are separate outcomes.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestKey key;
  late Directory support;
  late Uint8List seedBytes;

  setUpAll(() async {
    sqfliteFfiInit();
    key = await TestKey.create();
    final seed = await openTestStore();
    await seed.applyPullPage(
        bucket: 'plants',
        schema: 1,
        rows: [
          {'k': 'fern', 'v': 'seed', 'u': 1, 'd': 0}
        ],
        maxUsnAfter: 1);
    await seed.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    seedBytes = File(seed.path).readAsBytesSync();
  });

  setUp(() async {
    support = await Directory.systemTemp.createTemp('valence-seed-runtime');
    ValenceStore.resetCacheForTests();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
        'flutter/assets', (_) async => ByteData.sublistView(seedBytes));
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
  });

  Future<Valence> open(_SeedFactory factory, LogSpy log, {int build = 42}) =>
      Valence.open(
        testConfig(key, dataSchemas: {'plants': 1}),
        hostBuild: build,
        supportDir: support,
        documentsDir: support,
        databaseFactory: factory,
        secure: testSecure({}),
        log: log.call,
      );

  test('seed marker survives transient locks without repeating the row import',
      () async {
    final factory = _SeedFactory(markerFailures: 2);
    final log = LogSpy();
    final v = await open(factory, log);
    expect(await v.dataGet('plants', 'fern'), 'seed');
    expect(await v.store.hostPrefGet('valence.seed.imported'),
        '42.${seedBytes.length}');
    expect(factory.markerAttempts, 3);
    expect(factory.imports, 1);
    expect(log.has('import failed'), isFalse);
    expect(log.has('retrying'), isTrue);
    expect(log.has('completion marker recorded after retry'), isTrue);
  });

  test('exhausted marker retries retain rows and retry safely on next launch',
      () async {
    final factory = _SeedFactory(markerFailures: 99);
    final log = LogSpy();
    final v = await open(factory, log);
    expect(await v.dataGet('plants', 'fern'), 'seed');
    expect(factory.markerAttempts, 5);
    expect(await v.store.hostPrefGet('valence.seed.imported'), isNull);
    expect(log.has('rows imported; completion marker not recorded'), isTrue);
    expect(log.has('import incomplete'), isFalse);
    await v.store.applyPullPage(
        bucket: 'plants',
        schema: 1,
        rows: [
          {'k': 'fern', 'v': 'synced', 'u': 2, 'd': 0}
        ],
        maxUsnAfter: 2);
    factory.markerFailures = 0;
    final next = await open(factory, LogSpy());
    expect(await next.dataGet('plants', 'fern'), 'synced');
    expect(await next.store.maxUsn('plants', 1), 2);
    expect(await next.store.hostPrefGet('valence.seed.imported'),
        '42.${seedBytes.length}');
    expect(factory.imports, 2);
  });

  test('non-lock marker error is reported separately and is not retried',
      () async {
    final factory = _SeedFactory(
        markerFailures: 1, markerError: StateError('disk failure'));
    final log = LogSpy();
    final v = await open(factory, log);
    expect(await v.dataGet('plants', 'fern'), 'seed');
    expect(factory.markerAttempts, 1);
    expect(await v.store.hostPrefGet('valence.seed.imported'), isNull);
    expect(log.has('rows imported; completion marker not recorded'), isTrue);
    expect(log.has('import incomplete'), isFalse);
  });

  test('row import failure never records completion or claims rows imported',
      () async {
    final factory = _SeedFactory(importError: StateError('broken seed'));
    final log = LogSpy();
    final v = await open(factory, log);
    expect(factory.markerAttempts, 0);
    expect(await v.store.hostPrefGet('valence.seed.imported'), isNull);
    expect(log.has('import incomplete'), isTrue);
    expect(log.has('rows imported'), isFalse);
  });

  test('a failed upgrade marker preserves the preceding completed build',
      () async {
    final factory = _SeedFactory(markerError: StateError('disk failure'));
    final v = await open(factory, LogSpy());
    factory.markerFailures = 1;
    await open(factory, LogSpy(), build: 43);
    expect(await v.store.hostPrefGet('valence.seed.imported'),
        '42.${seedBytes.length}');
    expect(factory.imports, 2);
    await open(factory, LogSpy(), build: 43);
    expect(await v.store.hostPrefGet('valence.seed.imported'),
        '43.${seedBytes.length}');
    expect(factory.imports, 3);
  });

  test(
      'completed seed is skipped until the host build or extracted file changes',
      () async {
    final factory = _SeedFactory();
    final v = await open(factory, LogSpy());
    final skipped = LogSpy();
    await open(factory, skipped);
    expect(skipped.has('seed: skipped'), isTrue);
    expect(factory.imports, 1);
    expect(factory.markerAttempts, 1);
    await open(factory, LogSpy(), build: 43);
    expect(factory.imports, 2);
    File('${v.dir.path}${Platform.pathSeparator}seed.db').deleteSync();
    await open(factory, LogSpy(), build: 43);
    expect(factory.imports, 3);
    // SQLite permits trailing bytes. Changing length models a rebuilt asset at the same host build.
    final longer = Uint8List(seedBytes.length + 4096)
      ..setRange(0, seedBytes.length, seedBytes);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'flutter/assets', (_) async => ByteData.sublistView(longer));
    await open(factory, LogSpy(), build: 43);
    expect(factory.imports, 4);
    expect(await v.store.hostPrefGet('valence.seed.imported'),
        '43.${longer.length}');
  });
}

// Real SQLite for the import, with faults only at the marker/ATTACH boundary.
class _SeedFactory implements DatabaseFactory {
  _SeedFactory({this.markerFailures = 0, this.markerError, this.importError});
  int markerFailures;
  final Object? markerError;
  final Object? importError;
  int markerAttempts = 0;
  int imports = 0;

  @override
  Future<Database> openDatabase(String path,
          {OpenDatabaseOptions? options}) async =>
      _SeedDatabase(
          await databaseFactoryFfi.openDatabase(path, options: options), this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeedDatabase implements Database {
  _SeedDatabase(this.inner, this.faults);
  final Database inner;
  final _SeedFactory faults;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (sql.startsWith('ATTACH')) {
      faults.imports++;
      if (faults.importError != null) throw faults.importError!;
    }
    await inner.execute(sql, arguments);
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    if (table == 'prefs' && values['key'] == 'valence.seed.imported') {
      faults.markerAttempts++;
      if (faults.markerFailures-- > 0) {
        throw faults.markerError ?? LockedDatabaseException();
      }
    }
    return inner.insert(table, values,
        nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);
  }

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
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
          {bool? exclusive}) =>
      inner.transaction(action, exclusive: exclusive);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
