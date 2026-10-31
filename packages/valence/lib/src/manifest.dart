import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'config.dart';
import 'state.dart';

final _hash = RegExp(r'^[0-9a-f]{64}$');
final _bucketName = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// One entry of `manifest.files`.
final class ValenceFileEntry {
  /// Creates an entry.
  const ValenceFileEntry(this.hash, this.size);

  /// Lowercase hex sha256 of the file's bytes. Also its name in the content-addressed store.
  final String hash;

  /// The file's exact length in bytes.
  final int size;
}

/// A signed bundle manifest (contracts §2.2).
///
/// Nothing here is trusted until [checkManifest] has run: the constructor only decodes.
final class ValenceManifest {
  /// Creates a manifest. Use [checkManifest]; this is public only so tests can build one.
  const ValenceManifest({
    required this.bytes,
    required this.format,
    required this.appId,
    required this.seq,
    required this.version,
    required this.floor,
    required this.requiresBridge,
    this.minHost,
    required this.requiresData,
    required this.entry,
    required this.csp,
    required this.urgent,
    required this.routes,
    required this.files,
    required this.keyId,
  });

  /// Decodes the exact bytes the signature covers.
  ///
  /// Unknown top-level fields are ignored on purpose: the manifest is additive within a `format`, so a
  /// bundle built by a newer CLI must still load. A changed *meaning* gets a new `format` instead.
  factory ValenceManifest.decode(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (e) {
      throw ValenceCheckFailure(1, 'manifest is not JSON: $e');
    }
    if (decoded is! Map<String, Object?>) throw ValenceCheckFailure(1, 'manifest is not an object');
    // Bound to a fresh local: Dart does not promote a variable that a closure captures, and the two
    // helpers below are closures.
    final raw = decoded;

    int reqInt(String k, {int min = 0}) {
      final v = raw[k];
      if (v is! int || v < min) throw ValenceCheckFailure(6, '$k must be an integer >= $min, got $v');
      return v;
    }

    String reqString(String k) {
      final v = raw[k];
      if (v is! String || v.isEmpty) throw ValenceCheckFailure(6, '$k must be a non-empty string');
      return v;
    }

    final requires = raw['requires'];
    if (requires is! Map<String, Object?>) throw ValenceCheckFailure(6, 'requires must be an object');
    final data = requires['data'] ?? const <String, Object?>{};
    if (data is! Map<String, Object?>) throw ValenceCheckFailure(6, 'requires.data must be an object');

    final rawFiles = raw['files'];
    if (rawFiles is! Map<String, Object?>) throw ValenceCheckFailure(6, 'files must be an object');
    final files = <String, ValenceFileEntry>{};
    for (final e in rawFiles.entries) {
      final f = e.value;
      if (f is! Map<String, Object?>) throw ValenceCheckFailure(6, 'files["${e.key}"] must be an object');
      final h = f['h'];
      final n = f['n'];
      if (h is! String || !_hash.hasMatch(h)) {
        throw ValenceCheckFailure(6, 'files["${e.key}"].h must be 64 lowercase hex characters');
      }
      if (n is! int || n < 0) throw ValenceCheckFailure(6, 'files["${e.key}"].n must be a size >= 0');
      files[e.key] = ValenceFileEntry(h, n);
    }

    final routes = raw['routes'];
    final urgent = raw['urgent'];
    return ValenceManifest(
      bytes: bytes,
      format: raw['format'] is int ? raw['format']! as int : -1,
      appId: reqString('appId'),
      seq: reqInt('seq', min: 1),
      version: raw['version'] is String ? raw['version']! as String : '',
      floor: reqInt('floor'),
      requiresBridge: requires['bridge'] is int ? requires['bridge']! as int : 1,
      minHost: raw['minHost'] is int ? raw['minHost']! as int : null,
      requiresData: {
        for (final e in data.entries) e.key: e.value is int ? e.value! as int : -1,
      },
      entry: reqString('entry'),
      csp: raw['csp'] is String ? raw['csp']! as String : '',
      urgent: urgent is bool && urgent,
      routes: [
        for (final r in (routes is List ? routes : const []))
          if (r is String) r,
      ],
      files: files,
      keyId: reqString('keyId'),
    );
  }

  /// The exact bytes the signature covers. Written verbatim when the bundle becomes pending.
  final Uint8List bytes;

  /// The manifest format. Only 1 is understood.
  final int format;

  /// The app this bundle belongs to (canonical check 2).
  final String appId;

  /// This bundle's identity: a strictly increasing integer.
  final int seq;

  /// A display string. Never compared or ordered.
  final String version;

  /// The lowest seq a device may run after it commits this bundle.
  final int floor;

  /// The minimum host bridge version (canonical check 5).
  final int requiresBridge;

  /// Signed mandatory host bridge floor; absent means no mandatory update.
  final int? minHost;

  /// The read-only `(bucket, schema)` pairs this UI reads (§5.4).
  final Map<String, int> requiresData;

  /// The entry page, which must be one of [files].
  final String entry;

  /// The `Content-Security-Policy` the host sends with the entry page.
  final String csp;

  /// Whether the page should be offered the update mid-session through `bundle.applyUpdate`.
  final bool urgent;

  /// The top-level routes, compared with the store-reviewed baseline (§7).
  final List<String> routes;

  /// Every file in the bundle, by relative POSIX path.
  final Map<String, ValenceFileEntry> files;

  /// Which keyring entry signed this manifest.
  final String keyId;
}

/// A stop in the canonical check order or in the §2.3 algorithm, with the step that stopped.
///
/// Every stop is logged. An update that *declines* to apply looks exactly like one that failed — the
/// pointer and manifest are fetched and verified, and then nothing happens — so the step number and the
/// reason are the only way to tell a healthy decline from a broken device (§2.3).
final class ValenceCheckFailure implements Exception {
  /// Creates a failure naming the step from the canonical order, or the §2.3 step number.
  const ValenceCheckFailure(this.step, this.reason, {this.requiredBridge});

  /// A verified check-5 host incompatibility, never inferred from error text.
  final int? requiredBridge;

  /// The check or algorithm step that stopped.
  final int step;

  /// What it was waiting for, or what was wrong.
  final String reason;

  @override
  String toString() => 'check $step: $reason';
}

/// `_host/` belongs to the host's own routes (§3), so the server would shadow a bundle file there.
///
/// Refused by `valence bundle`, by `valence verify` and here, so a manifest signed by an older tool
/// cannot smuggle one in.
bool isReservedBundlePath(String path) => path == '_host' || path.startsWith('_host/');

/// A relative POSIX path with no empty, `.` or `..` segment, no leading `/`, no `\` and no NUL.
bool isSafeBundlePath(String path) {
  if (path.isEmpty || path.startsWith('/')) return false;
  if (path.contains('\\') || path.contains('\u0000')) return false;
  for (final seg in path.split('/')) {
    if (seg.isEmpty || seg == '.' || seg == '..') return false;
  }
  return true;
}

/// Runs canonical checks 1 to 6 over one manifest, in order, and returns it.
///
/// [pointerSeq] is null for the built-in bundle, which has no pointer, so check 3 is skipped (§2.4 step 1).
/// Check 7 — each downloaded file's sha256 and size — happens as the files land, in the updater.
///
/// Throws [ValenceCheckFailure] naming the step. Nothing in [bytes] is trusted before check 1 passes;
/// `keyId` is read first only to pick a key out of the keyring, and an own-property lookup at that.
Future<ValenceManifest> checkManifest({
  required Uint8List bytes,
  required String signature,
  required ValenceConfig config,
  required ValenceState state,
  required int? pointerSeq,
  bool checkHostVersion = true,
}) async {
  // 1. The Ed25519 signature over the exact bytes.
  final String keyId;
  try {
    final probe = jsonDecode(utf8.decode(bytes));
    final k = probe is Map<String, Object?> ? probe['keyId'] : null;
    if (k is! String) throw const ValenceCheckFailure(1, 'manifest has no keyId');
    keyId = k;
  } on ValenceCheckFailure {
    rethrow;
  } on Object catch (e) {
    throw ValenceCheckFailure(1, 'manifest is not JSON: $e');
  }
  final publicKey = config.keyring[keyId];
  if (publicKey == null) throw ValenceCheckFailure(1, 'unknown keyId "$keyId"');
  final Uint8List sig;
  try {
    sig = base64Decode(signature.trim());
  } on Object {
    throw const ValenceCheckFailure(1, 'signature is not base64');
  }
  final ok = await Ed25519().verify(
    bytes,
    signature: Signature(
      sig,
      publicKey: SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519),
    ),
  );
  if (!ok) throw const ValenceCheckFailure(1, 'bad manifest signature');

  // Only now are the bytes trusted enough to read as a manifest.
  final m = ValenceManifest.decode(bytes);
  // The format gates how every other field is read, so it comes before any of them.
  if (m.format != 1) throw ValenceCheckFailure(1, 'unsupported manifest format ${m.format}');

  // 2. appId.
  if (m.appId != config.appId) throw ValenceCheckFailure(2, 'manifest is for ${m.appId}, not ${config.appId}');
  if (m.keyId != keyId) throw const ValenceCheckFailure(2, 'keyId changed between the two reads');

  // 3. seq == pointer.seq. Skipped for the built-in bundle.
  if (pointerSeq != null && m.seq != pointerSeq) {
    throw ValenceCheckFailure(3, 'manifest seq ${m.seq} is not the pointer seq $pointerSeq');
  }

  // 4. seq >= state.floor.
  if (m.seq < state.floor) throw ValenceCheckFailure(4, 'seq ${m.seq} is below the floor ${state.floor}');

  // 5. requires: the bridge version, and the *shape* of requires.data.
  //
  // The comparison uses config.bridgeVersion, which codegen wires to the generated hostBridgeVersion.
  // A second literal here would let the host under-report its version and then refuse its own built-in
  // bundle on first launch, with nothing left to serve.
  final raw = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  final bridge = (raw['requires'] as Map<String, Object?>)['bridge'];
  if (bridge is! int || bridge < 1 || bridge > 9007199254740991) {
    throw const ValenceCheckFailure(5, 'requires.bridge must be a positive safe integer');
  }
  final minHost = raw['minHost'];
  if (raw.containsKey('minHost') && (minHost is! int || minHost < 1 || minHost > 9007199254740991)) {
    throw const ValenceCheckFailure(5, 'minHost must be a positive safe integer');
  }
  final needed = m.minHost != null && m.minHost! > m.requiresBridge ? m.minHost! : m.requiresBridge;
  if (checkHostVersion && needed > config.bridgeVersion) {
    throw ValenceCheckFailure(
      5,
      'needs bridge $needed, host has ${config.bridgeVersion}',
      requiredBridge: needed,
    );
  }
  // Whether the pairs are *present* is step 7's job, not this one: rejecting here for a pair the device
  // does not hold yet parks the update for ever with nothing logged.
  for (final e in m.requiresData.entries) {
    if (!_bucketName.hasMatch(e.key)) {
      throw ValenceCheckFailure(5, 'requires.data key "${e.key}" is not a valid bucket name');
    }
    // Step 7 interpolates these keys into a sync URL, so a signed manifest must not be able to name the
    // user's own writable bucket or an arbitrary path.
    if (config.writableBuckets.contains(e.key)) {
      throw ValenceCheckFailure(5, 'requires.data names the writable bucket "${e.key}"');
    }
    if (e.value < 1) {
      throw ValenceCheckFailure(5, 'requires.data["${e.key}"] must be a positive integer');
    }
  }

  // 6. Every path, hash and size field is well formed. Hashes and sizes were validated while decoding.
  if (!m.files.containsKey(m.entry)) throw ValenceCheckFailure(6, 'entry ${m.entry} is not in files');
  for (final path in m.files.keys) {
    if (!isSafeBundlePath(path)) throw ValenceCheckFailure(6, 'unsafe path in manifest: $path');
    if (isReservedBundlePath(path)) {
      throw ValenceCheckFailure(6, '_host/ is reserved for the host\'s own routes: $path');
    }
  }
  if (m.floor > m.seq) throw ValenceCheckFailure(6, 'floor ${m.floor} is above seq ${m.seq}');
  return m;
}

/// Decodes a channel pointer strictly (§2.1). Returns null for anything that is not an update.
///
/// The pointer is unsigned, so this is the one place a CDN gets to influence the host, and the only two
/// things it can do are freeze a device and change the rollout cohort. Anything malformed means
/// "no update" rather than an error.
({int seq, int rollout})? decodePointer(String body) {
  try {
    final raw = jsonDecode(body);
    if (raw is! Map<String, Object?>) return null;
    final seq = raw['seq'];
    final rollout = raw['rollout'];
    if (seq is! int || seq < 1) return null;
    if (rollout is! int || rollout < 0 || rollout > 100) return null;
    return (seq: seq, rollout: rollout);
  } on Object {
    return null;
  }
}

/// FNV-1a 32-bit, used for the rollout gate and the default port. Deterministic across platforms.
int fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h = (h ^ b) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}
