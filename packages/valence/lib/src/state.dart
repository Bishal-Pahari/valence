import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// The activation state from contracts §2.4, held in `<appSupport>/valence/state.json`.
///
/// Every field is a bundle `seq` except [installId], [port], [trialFails] and [bad]. The one invariant
/// worth remembering: *no path promotes, re-downloads or serves a seq in [bad].*
final class ValenceState {
  /// Creates a state. Use [load] rather than this, except in tests.
  ValenceState({
    required this.installId,
    this.port,
    this.current,
    this.previous,
    this.pending,
    this.trial,
    this.trialFails = 0,
    this.serving,
    List<int> bad = const [],
    this.floor = 0,
    this.builtinRefused,
  }) : bad = [...bad];

  /// Reads the state, or makes a fresh one with a new [installId] if the file is absent or unreadable.
  ///
  /// A corrupt file is replaced rather than thrown: the alternative is an app that cannot start, and
  /// everything here except [installId] is recoverable from the built-in bundle.
  static ValenceState load(File file) {
    try {
      if (file.existsSync()) return ValenceState.fromJson(jsonDecode(file.readAsStringSync()));
    } on Object {
      // fall through to a fresh state
    }
    return ValenceState(installId: newInstallId());
  }

  /// Decodes the on-disk shape. Unknown fields are ignored, so an older host reads a newer file.
  factory ValenceState.fromJson(Object? raw) {
    final j = raw is Map<String, Object?> ? raw : const <String, Object?>{};
    int? seq(String k) {
      final v = j[k];
      return v is int && v >= 1 ? v : null;
    }

    final id = j['installId'];
    return ValenceState(
      installId: id is String && id.isNotEmpty ? id : newInstallId(),
      port: seq('port'),
      current: seq('current'),
      previous: seq('previous'),
      pending: seq('pending'),
      trial: seq('trial'),
      trialFails: j['trialFails'] is int ? j['trialFails']! as int : 0,
      serving: seq('serving'),
      bad: [
        for (final b in (j['bad'] is List ? j['bad']! as List : const []))
          if (b is int && b >= 1) b,
      ],
      floor: j['floor'] is int && (j['floor']! as int) >= 0 ? j['floor']! as int : 0,
      // A String, and anything else (including the int an 0.4.0-beta.0 host wrote) reads as absent —
      // which costs one re-verify and is always safe.
      builtinRefused: j['builtinRefused'] is String && (j['builtinRefused']! as String).isNotEmpty
          ? j['builtinRefused']! as String
          : null,
    );
  }

  /// A random v4-shaped id made on first launch. Never a device id: it picks the rollout cohort and the port.
  static String newInstallId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Identifies this install for the rollout gate and the port. Survives everything but a reinstall.
  final String installId;

  /// The loopback port, kept across launches so the page's web storage survives.
  int? port;

  /// The committed bundle this install serves.
  int? current;

  /// The bundle before [current]. Kept so garbage collection has something to fall back to.
  int? previous;

  /// A verified, downloaded bundle waiting for the next UI start.
  int? pending;

  /// A bundle being tried. It has not committed, so a crash or a ready timeout counts against it.
  int? trial;

  /// Failed starts of [trial]. At 2 the trial goes into [bad].
  int trialFails;

  /// The trial seq while that trial is on screen and still unconfirmed. Otherwise null.
  int? serving;

  /// The seqs this install refuses, for ever (below [floor] entries may be pruned at commit).
  final List<int> bad;

  /// The lowest seq this install may run. A high-water mark that never goes down.
  int floor;

  /// Identifies the built-in bundle whose checks failed, so step 1 stops re-paying for it (§2.4).
  ///
  /// A fingerprint of the manifest bytes **and** the host's bridge version, not the seq: the usual cause
  /// of a refusal is `requires.bridge` above what the host reports, and that fix ships as a Dart change
  /// with the same assets and so the same seq. Keyed on the seq alone, step 1 would skip on the very host
  /// built to fix it.
  ///
  /// Cleared as soon as a built-in bundle passes, or once `current` has overtaken it. A refused built-in
  /// bundle is never added to [bad]: it is not a release this install can decline.
  String? builtinRefused;

  /// The on-disk shape.
  Map<String, Object?> toJson() => {
        'installId': installId,
        'port': port,
        'current': current,
        'previous': previous,
        'pending': pending,
        'trial': trial,
        'trialFails': trialFails,
        'serving': serving,
        'bad': bad,
        'floor': floor,
        'builtinRefused': builtinRefused,
      };

  /// Writes atomically: a temp file, flushed, then renamed, so a kill mid-write cannot truncate the state.
  void save(File file) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    final out = tmp.openSync(mode: FileMode.write);
    try {
      out.writeStringSync(jsonEncode(toJson()));
      out.flushSync();
    } finally {
      out.closeSync();
    }
    tmp.renameSync(file.path);
  }

  @override
  String toString() => 'ValenceState${toJson()}';
}
