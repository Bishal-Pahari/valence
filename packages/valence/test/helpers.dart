// Shared fixtures for the contracts §8 test matrix.
//
// The signing key is generated per test run rather than checked in, so the signature checks are exercised
// against real Ed25519 rather than mocked out. A test can therefore sign a tampered manifest, sign with
// the wrong key, or hand over a valid signature for different bytes.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';

/// A generated signing key plus the keyring entry a host would compile in.
final class TestKey {
  TestKey(this.keyId, this.keyPair, this.publicKeyBase64);

  /// Makes a fresh Ed25519 key.
  static Future<TestKey> create([String keyId = 'k1']) async {
    final pair = await Ed25519().newKeyPair();
    final pub = await pair.extractPublicKey();
    return TestKey(keyId, pair, base64Encode(pub.bytes));
  }

  final String keyId;
  final SimpleKeyPair keyPair;
  final String publicKeyBase64;

  /// Signs exactly [bytes] and returns the base64 signature, as the `.sig` file holds it.
  Future<String> sign(List<int> bytes) async {
    final sig = await Ed25519().sign(bytes, keyPair: keyPair);
    return base64Encode(sig.bytes);
  }
}

/// A signed bundle: the exact manifest bytes, its signature, and the file bodies by hash.
final class SignedBundle {
  const SignedBundle(this.bytes, this.signature, this.manifest, this.blobs);

  final Uint8List bytes;
  final String signature;
  final Map<String, Object?> manifest;
  final Map<String, List<int>> blobs;

  int get seq => manifest['seq']! as int;

  /// Writes the manifest, its signature and every file into a directory pair, as the updater expects.
  void writeTo({required Directory manifestsDir, required Directory casDir}) {
    manifestsDir.createSync(recursive: true);
    casDir.createSync(recursive: true);
    File('${manifestsDir.path}/$seq.json').writeAsBytesSync(bytes);
    File('${manifestsDir.path}/$seq.json.sig').writeAsStringSync(signature);
    for (final e in blobs.entries) {
      File('${casDir.path}/${e.key}').writeAsBytesSync(e.value);
    }
  }

  /// Lays the bundle out the way `valence bundle --builtin` does, for an asset reader.
  Map<String, Uint8List> asAssets(String dir) => {
        '$dir/manifest.json': bytes,
        '$dir/manifest.json.sig': Uint8List.fromList(utf8.encode(signature)),
        for (final e in blobs.entries) '$dir/files/${e.key}': Uint8List.fromList(e.value),
      };
}

/// Builds and signs a manifest over a set of files, the way `valence bundle` does.
///
/// [files] maps a relative bundle path to its body. [overrides] is merged over the manifest last, so a
/// test can corrupt exactly one field and leave the signature valid — which is how check 2 to check 6 are
/// distinguished from check 1.
Future<SignedBundle> signBundle(
  TestKey key, {
  required int seq,
  String appId = 'com.example.app',
  Map<String, String> files = const {'index.html': '<html><head></head><body>hi</body></html>'},
  String entry = 'index.html',
  int floor = 0,
  int requiresBridge = 1,
  Map<String, int> requiresData = const {},
  String csp = "default-src 'self'",
  bool urgent = false,
  List<String> routes = const ['/'],
  Map<String, Object?> overrides = const {},
}) async {
  final blobs = <String, List<int>>{};
  final fileEntries = <String, Object?>{};
  for (final e in files.entries) {
    final body = utf8.encode(e.value);
    final hash = sha256.convert(body).toString();
    blobs[hash] = body;
    fileEntries[e.key] = {'h': hash, 'n': body.length};
  }
  final manifest = <String, Object?>{
    'format': 1,
    'appId': appId,
    'seq': seq,
    'version': '2026.10.17+$seq',
    'floor': floor,
    'requires': {'bridge': requiresBridge, 'data': requiresData},
    'entry': entry,
    'csp': csp,
    'urgent': urgent,
    'routes': routes,
    'files': fileEntries,
    'createdAt': '2026-10-17T10:00:00Z',
    'keyId': key.keyId,
    ...overrides,
  };
  // The CLI writes pretty-printed JSON with a trailing newline, and the signature covers those exact
  // bytes. Matching it here keeps the fixture honest about what hosts receive.
  final bytes = Uint8List.fromList(utf8.encode('${const JsonEncoder.withIndent('  ').convert(manifest)}\n'));
  return SignedBundle(bytes, await key.sign(bytes), manifest, blobs);
}

/// A config wired to [key], with the host bridge version check 5 compares against.
ValenceConfig testConfig(
  TestKey key, {
  String appId = 'com.example.app',
  int bridgeVersion = 1,
  String otaBase = 'https://ota.test',
  String syncBase = 'https://sync.test',
  Set<String> writableBuckets = const {},
  Map<String, int> dataSchemas = const {},
  int bundleSizeCap = 50 * 1024 * 1024,
  int dataSizeCap = 50 * 1024 * 1024,
  ValenceSyncMode syncMode = ValenceSyncMode.api,
  int pullPageLimit = 500,
}) =>
    ValenceConfig(
      appId: appId,
      keyring: {key.keyId: key.publicKeyBase64},
      bridgeVersion: bridgeVersion,
      otaBase: otaBase,
      syncBase: syncBase,
      syncMode: syncMode,
      writableBuckets: writableBuckets,
      dataSchemas: dataSchemas,
      bundleSizeCap: bundleSizeCap,
      dataSizeCap: dataSizeCap,
      pullPageLimit: pullPageLimit,
    );

/// Opens a store on a fresh temp file.
///
/// A file rather than `:memory:`, because sqflite keys open databases by path and would hand every test
/// the same in-memory connection. `sqflite_common_ffi` is also more permissive than Android's
/// `SQLiteDatabase` — it accepts `execute` for pragmas — so a green suite here is not evidence that the
/// store opens on a phone. That is the §8 integration row.
Future<ValenceStore> openTestStore([String? path]) async {
  sqfliteFfiInit();
  ValenceStore.resetCacheForTests();
  return ValenceStore.open(path ?? await freshDbPath(), factory: databaseFactoryFfi);
}

/// A path in a fresh temp directory, so each test starts from an empty database.
Future<String> freshDbPath([String name = 'valence.db']) async {
  final dir = await Directory.systemTemp.createTemp('valence-test');
  return '${dir.path}${Platform.pathSeparator}$name';
}

/// A [ValenceSecure] over flutter_secure_storage's own in-memory platform (contracts §4.4).
///
/// The real class, not a stand-in: the reserved-prefix refusals and the token key are what the tests are
/// about, and only the Keystore call underneath is replaced. [data] is the storage, so a test can inspect
/// where a value landed.
ValenceSecure testSecure(Map<String, String> data, {ValenceLogger log = _silent}) {
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(data);
  return ValenceSecure(log: log);
}

/// A [ValenceSecure] whose platform throws, as a device with a broken Keystore does.
ValenceSecure brokenSecure({ValenceLogger log = _silent}) {
  FlutterSecureStoragePlatform.instance = _BrokenSecureStoragePlatform();
  return ValenceSecure(log: log);
}

void _silent(String _) {}

final class _BrokenSecureStoragePlatform extends FlutterSecureStoragePlatform {
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) => _fail();

  @override
  Future<void> delete({required String key, required Map<String, String> options}) => _fail();

  @override
  Future<void> deleteAll({required Map<String, String> options}) => _fail();

  @override
  Future<String?> read({required String key, required Map<String, String> options}) => _fail();

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) => _fail();

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) => _fail();

  Future<Never> _fail() => Future.error(MissingPluginException('no secure storage on this platform'));
}

/// `SQLITE_BUSY`, worded and coded exactly as Android reports it when the schema upgrade's
/// `BEGIN EXCLUSIVE` loses the race with another isolate's open (contracts §5.6).
final class LockedDatabaseException extends DatabaseException {
  LockedDatabaseException()
      : super("database is locked (code 5 SQLITE_BUSY) sql 'BEGIN EXCLUSIVE' args [] during open, closing...");

  @override
  int? getResultCode() => 5;

  @override
  Object? get result => null;
}

/// A factory that refuses the first [locks] opens as locked, then behaves like the real one.
///
/// Standing in for the other isolate holding the file: nothing in `flutter_test` can take a real exclusive
/// lock across isolates, and the behaviour under contention is the whole point.
final class LockingDatabaseFactory implements DatabaseFactory {
  LockingDatabaseFactory(this.inner, {this.locks = 1});

  final DatabaseFactory inner;
  int locks;

  /// How many opens have been attempted, so a test can tell a retry from a single try.
  int attempts = 0;

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) {
    attempts++;
    if (locks-- > 0) return Future.error(LockedDatabaseException());
    return inner.openDatabase(path, options: options);
  }

  @override
  Future<String> getDatabasesPath() => inner.getDatabasesPath();

  @override
  Future<void> setDatabasesPath(String path) => inner.setDatabasesPath(path);

  @override
  Future<void> deleteDatabase(String path) => inner.deleteDatabase(path);

  @override
  Future<bool> databaseExists(String path) => inner.databaseExists(path);

  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) => inner.writeDatabaseBytes(path, bytes);

  @override
  Future<Uint8List> readDatabaseBytes(String path) => inner.readDatabaseBytes(path);
}

/// Collects log lines, so a test can assert that a stop was *reported* and not just taken.
final class LogSpy {
  final List<String> lines = [];

  void call(String message) => lines.add(message);

  bool has(String fragment) => lines.any((l) => l.contains(fragment));

  @override
  String toString() => lines.join('\n');
}
