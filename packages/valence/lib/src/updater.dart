import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'log.dart';
import 'manifest.dart';
import 'state.dart';
import 'store.dart';
import 'sync.dart';

/// Reads one of the app's bundled assets. Injected so the updater is testable without a Flutter binding.
typedef ValenceAssetReader = Future<Uint8List> Function(String key);

/// Runs [work] on the first post-frame callback. Injected so the updater is testable without a frame.
void _postFrame(Future<void> Function() work) =>
    SchedulerBinding.instance.addPostFrameCallback((_) => work());

/// The manifest fetch is capped, because it is read before anything about it is trusted.
const _manifestSizeCap = 1024 * 1024;

/// How long the pointer fetch may take before the check gives up for this run.
const _pointerTimeout = Duration(seconds: 5);

/// The canonical check order (§2.3) and the activation state machine (§2.4).
///
/// The whole of §2.4 rests on one invariant: *no path promotes, re-downloads or serves a seq in
/// [ValenceState.bad].* Every method here is written to preserve it.
final class ValenceUpdater {
  /// Creates an updater over an already-open [store].
  ValenceUpdater({
    required this.config,
    required this.state,
    required this.stateFile,
    required this.casDir,
    required this.manifestsDir,
    required this.store,
    required this.sync,
    required ValenceAssetReader readAsset,
    http.Client? client,
    ValenceLogger log = defaultValenceLogger,
    void Function(Future<void> Function()) afterFrame = _postFrame,
    this.onUpdateReady,
  })  : _readAsset = readAsset,
        _afterFrame = afterFrame,
        _client = client ?? http.Client(),
        _log = log;

  /// The app's configuration.
  final ValenceConfig config;

  /// The live state. Mutated in place and saved through [save].
  final ValenceState state;

  /// Where [state] is persisted.
  final File stateFile;

  /// The content-addressed file store.
  final Directory casDir;

  /// Where verified manifests and their signatures are kept.
  final Directory manifestsDir;

  /// The open data store, for §2.3 step 7 and for garbage collection.
  final ValenceStore store;

  /// The sync driver, whose lease step 7 takes.
  final ValenceSync sync;

  /// Called when a bundle marked `urgent` becomes pending, so the host can emit `bundle.updateReady`.
  ///
  /// Mutable because the host widget attaches after the runtime is open.
  void Function(int seq)? onUpdateReady;

  /// The active manifest and the hashes its server deleted as corrupt. Set by `Valence.bound`.
  ///
  /// A closure rather than two fields, because the server is rebound on every bundle swap and resume.
  ({ValenceManifest manifest, Set<String> corrupt})? Function()? repairFrom;

  final ValenceAssetReader _readAsset;
  final http.Client _client;
  final ValenceLogger _log;
  final void Function(Future<void> Function()) _afterFrame;

  /// Why the built-in bundle was refused, for the native error screen on an install with no `current`.
  String? _builtinFailure;

  /// The refusal already logged in this process, so a frozen install logs it once, not once per launch.
  String? _refusalLogged;

  bool _gcScheduled = false;

  /// CAS hashes written by §2.3 step 6 whose manifest is not on disk yet.
  ///
  /// Step 6 renames files into CAS **before** step 8 writes the manifest and sets `pending`, and step 7
  /// sits between them and can take minutes. A collection scheduled in that window computes its kept set
  /// from live state, does not see the seq being downloaded, and deletes the files it has just fetched —
  /// after which §2.3 step 1 stops on `pointer.seq <= pending` for ever and nothing re-fetches them. The
  /// bundle then fails its trial twice and a healthy release lands in `bad` (§2.4).
  final _inFlight = <String>{};
  final _publishing = <int, ValenceManifest>{};
  int _publicationRevision = 0;
  Future<int?>? _checking;

  /// Persists [state] atomically.
  void save() => state.save(stateFile);

  // ===========================================================================
  // §2.3 Host update algorithm
  // ===========================================================================

  /// Runs one update check: pointer, rollout, manifest, checks 1 to 7, data requirements, pending.
  ///
  /// **Every stop logs its reason.** An update that declines to apply looks exactly like one that failed —
  /// the pointer and the manifest are fetched and verified, and then nothing happens while `pending` stays
  /// null. Steps 2, 5 and 7 stop on a perfectly healthy system, and step 7 can stay stopped for days.
  ///
  /// Returns the seq that became pending, or null.
  Future<int?> checkForUpdate() => _checking ??= _checkOnce().whenComplete(() => _checking = null);

  Future<int?> _checkOnce() async {
    if (config.otaBase.isEmpty) {
      _log('update: no otaBase configured, nothing to check');
      return null;
    }

    // Before step 1, because step 1 is where a repair would otherwise be unreachable.
    await _repairActiveBundle();

    // --- Step 1: the pointer, decoded strictly. -----------------------------
    final ({int seq, int rollout})? pointer;
    try {
      final res = await _client
          .get(Uri.parse('${config.otaBase}/${config.appId}/channels/${config.channel}.json'))
          .timeout(_pointerTimeout);
      if (res.statusCode != 200) {
        _log('update: step 1 stopped, pointer returned HTTP ${res.statusCode}');
        return null;
      }
      pointer = decodePointer(res.body);
    } on Object catch (e) {
      _log('update: step 1 stopped, pointer fetch failed: $e');
      return null;
    }
    if (pointer == null) {
      _log('update: step 1 stopped, the pointer did not decode as {seq, rollout}');
      return null;
    }

    // A pointer below `pending` means the team pulled that release.
    if (state.pending != null && pointer.seq < state.pending!) {
      _log('update: pointer ${pointer.seq} is below pending ${state.pending}; dropping pending');
      state.pending = null;
      save();
    }
    final current = state.current ?? 0;
    if (pointer.seq <= current) {
      _log('update: step 1 stopped, pointer ${pointer.seq} is not above current $current');
      return null;
    }
    if (state.bad.contains(pointer.seq)) {
      _log('update: step 1 stopped, seq ${pointer.seq} is in bad for this install');
      return null;
    }
    if (state.pending != null && pointer.seq <= state.pending!) {
      _log('update: step 1 stopped, seq ${pointer.seq} is not above pending ${state.pending}');
      return null;
    }
    // `trial` belongs in this list. A trial is above `current` and has not committed, so without this
    // guard the periodic check re-downloads the bundle that is on screen right now and sets `pending` to
    // it. That stale `pending` then either survives the commit and re-trials a live bundle, or survives
    // the two-strike `bad` marking and resurrects a bundle this install has already rejected.
    if (state.trial != null && pointer.seq <= state.trial!) {
      _log('update: step 1 stopped, seq ${pointer.seq} is not above the trial ${state.trial}');
      return null;
    }

    // --- Step 2: the rollout gate. ------------------------------------------
    final bucket = fnv1a32('${state.installId}:${pointer.seq}') % 100;
    if (bucket >= pointer.rollout) {
      _log('update: step 2 stopped, this install is outside the ${pointer.rollout}% rollout '
          'for seq ${pointer.seq} (cohort $bucket)');
      return null;
    }

    // --- Step 3: the manifest and its signature. ----------------------------
    final Uint8List bytes;
    final String signature;
    try {
      final base = '${config.otaBase}/${config.appId}/manifests/${pointer.seq}';
      final mRes = await _client.get(Uri.parse('$base.json'));
      if (mRes.statusCode != 200) {
        _log('update: step 3 stopped, manifest returned HTTP ${mRes.statusCode}');
        return null;
      }
      if (mRes.bodyBytes.length > _manifestSizeCap) {
        _log('update: step 3 stopped, manifest is ${mRes.bodyBytes.length} bytes, over the '
            '$_manifestSizeCap byte cap');
        return null;
      }
      final sRes = await _client.get(Uri.parse('$base.json.sig'));
      if (sRes.statusCode != 200) {
        _log('update: step 3 stopped, signature returned HTTP ${sRes.statusCode}');
        return null;
      }
      bytes = mRes.bodyBytes;
      signature = sRes.body;
    } on Object catch (e) {
      _log('update: step 3 stopped, manifest fetch failed: $e');
      return null;
    }

    // --- Step 4: checks 1 to 6. ---------------------------------------------
    final ValenceManifest m;
    try {
      m = await checkManifest(
        bytes: bytes,
        signature: signature,
        config: config,
        state: state,
        pointerSeq: pointer.seq,
      );
    } on ValenceCheckFailure catch (f) {
      _log('update: step 4 stopped, $f');
      return null;
    }

    // --- Step 5: the total size of what is not already in CAS. --------------
    var needed = 0;
    final missing = <String, ValenceFileEntry>{};
    for (final e in m.files.entries) {
      if (_casFile(e.value.hash).existsSync()) continue;
      if (missing.containsKey(e.value.hash)) continue;
      missing[e.value.hash] = e.value;
      needed += e.value.size;
    }
    if (needed > config.bundleSizeCap) {
      _log('update: step 5 stopped, seq ${m.seq} needs $needed new bytes, over the '
          '${config.bundleSizeCap} byte cap');
      return null;
    }

    // --- Step 6: download each missing file, verify it (check 7), rename. ---
    // Every hash of this manifest is in flight until step 8 records it, not just the ones being
    // downloaded: a file already in CAS may be shared only with a bundle this collection is dropping.
    _inFlight.addAll(m.files.values.map((f) => f.hash));
    _publishing[m.seq] = m;
    _publicationRevision++;
    var dataLeaseHeld = false;
    try {
      try {
        await casDir.create(recursive: true);
        for (final e in missing.entries) {
          if (!await _downloadCasFile(m, e.key, e.value)) return null;
        }
      } on Object catch (e) {
        _log('update: step 6 stopped, download failed: $e');
        return null;
      }

      // --- Step 7: the data requirements. The updater *pulls* here. ---------
      if (!await _satisfyDataRequirements(m, onLeaseAcquired: () => dataLeaseHeld = true)) return null;

      // --- Step 8: make it pending. -----------------------------------------
      await manifestsDir.create(recursive: true);
      await _manifestFile(m.seq).writeAsBytes(m.bytes, flush: true);
      await _signatureFile(m.seq).writeAsString(signature.trim(), flush: true);
      state.pending = m.seq;
      save();
      _log('update: seq ${m.seq} is pending (${m.files.length} files)');
      if (m.urgent) onUpdateReady?.call(m.seq);
      return m.seq;
    } finally {
      // Cleared whether or not the check completed. A run that stopped at step 6 or 7 leaves orphan files
      // that the next collection is then free to take.
      if (dataLeaseHeld) await sync.releaseLease();
      _inFlight.removeAll(m.files.values.map((f) => f.hash));
      _publishing.remove(m.seq);
      _publicationRevision++;
    }
  }

  /// Re-fetches files of the **active** bundle that its server found corrupt and deleted.
  ///
  /// §2.4 promises that a rotted CAS file is re-downloaded by the next update check, but step 1 stops on
  /// `pointer.seq <= current` — so for the bundle being served there is no step 6 to reach, and nothing
  /// else looks at the active manifest's files. If the rotted file is the entry page, the app is a blank
  /// screen until some *newer* release happens to ship. Each file still goes through check 7.
  Future<void> _repairActiveBundle() async {
    final active = repairFrom?.call();
    if (active == null || active.corrupt.isEmpty) return;
    final wanted = <String, ValenceFileEntry>{};
    for (final f in active.manifest.files.values) {
      if (active.corrupt.contains(f.hash) && !_casFile(f.hash).existsSync()) wanted[f.hash] = f;
    }
    if (wanted.isEmpty) return;
    _log('update: repairing ${wanted.length} corrupt file(s) of the active bundle ${active.manifest.seq}');
    _inFlight.addAll(wanted.keys);
    try {
      await casDir.create(recursive: true);
      for (final e in wanted.entries) {
        if (!await _downloadCasFile(active.manifest, e.key, e.value)) {
          _log('update: could not repair ${e.key}; the server will keep answering 500 for it');
        }
      }
    } on Object catch (e) {
      _log('update: repair of the active bundle failed: $e');
    } finally {
      _inFlight.removeAll(wanted.keys);
    }
  }

  Future<bool> _downloadCasFile(ValenceManifest m, String hash, ValenceFileEntry entry) async {
    final res = await _client.get(Uri.parse('${config.otaBase}/${config.appId}/files/$hash'));
    if (res.statusCode != 200) {
      _log('update: step 6 stopped, file $hash returned HTTP ${res.statusCode}');
      return false;
    }
    final bytes = res.bodyBytes;
    // Check 7: each downloaded file's sha256 and size, before it is given its content-addressed name.
    if (bytes.length != entry.size) {
      _log('update: step 6 stopped, file $hash is ${bytes.length} bytes, manifest says ${entry.size}');
      return false;
    }
    final actual = sha256.convert(bytes).toString();
    if (actual != hash) {
      _log('update: step 6 stopped, file $hash hashes to $actual');
      return false;
    }
    final tmp = File('${casDir.path}${Platform.pathSeparator}tmp-$hash');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(_casFile(hash).path);
    return true;
  }

  /// §2.3 step 7. Pulls every `requires.data` pair the device does not already hold.
  ///
  /// This is **not** a passive check. Ordinary sync pulls only the pairs the *active* bundle reads, which
  /// during a bump are the old schemas, so a newly required pair has no other route onto the device.
  /// A step 7 written as "make sure the pairs are synced" can never pass: `pending` stays null for ever
  /// and the app silently stops updating, with no user-visible symptom.
  Future<bool> _satisfyDataRequirements(ValenceManifest m, {required void Function() onLeaseAcquired}) async {
    if (m.requiresData.isEmpty) return true;
    // Take the §5.6 lease first. This is a second sync path on the same triggers as the ordinary one, so
    // without the lease a host runs two concurrent syncs over the same pair. Failing to acquire is not a
    // failure: the sync holding it was very likely fired by the same trigger.
    final wait = Stopwatch()..start();
    var acquired = await sync.acquireLease();
    while (!acquired && wait.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      acquired = await sync.acquireLease();
    }
    if (!acquired) {
      _log('update: step 7 stopped, another sync holds the lease after a 5-second wait; the next check retries');
      return false;
    }
    onLeaseAcquired();
    // Held is a set of schemas per bucket, not a bucket-to-schema map: during a bump a device legitimately
    // holds plants v1 *and* v2 at once, and a map lets the v1 entry hide the v2 entry.
    final held = await store.syncedPairs();
    final wanted = <String, int>{
      for (final e in m.requiresData.entries)
        if (!(held[e.key]?.contains(e.value) ?? false)) e.key: e.value,
    };
    if (wanted.isEmpty) return true;
    if (config.syncBase.isEmpty) {
      _log('update: step 7 stopped, seq ${m.seq} needs ${_pairs(wanted)} but no syncBase is configured');
      return false;
    }

    final before = sync.bytesApplied;
    for (final e in wanted.entries) {
      final budget = config.dataSizeCap - (sync.bytesApplied - before);
      if (budget <= 0) {
        _log('update: step 7 stopped, seq ${m.seq} hit the ${config.dataSizeCap} byte data cap '
            'before ${e.key} v${e.value}; backing off');
        return false;
      }
      try {
        // From this pair's own max_usn, which is 0 the first time. Never a hard-coded since = 0.
        final rows = await sync.pullPair(e.key, e.value, byteBudget: budget);
        _log('update: step 7 pulled $rows rows for ${e.key} v${e.value}');
      } on Object catch (err) {
        _log('update: step 7 stopped, seq ${m.seq} is waiting for ${e.key} v${e.value}: $err');
        return false;
      }
    }
    // Re-read rather than assume: only a valid final page or complete static index sets synced_at.
    // Partial pages retain their cursor without satisfying activation.
    final after = await store.syncedPairs();
    final short = <String, int>{
      for (final e in m.requiresData.entries)
        if (!(after[e.key]?.contains(e.value) ?? false)) e.key: e.value,
    };
    if (short.isNotEmpty) {
      _log('update: step 7 stopped, seq ${m.seq} is still waiting for ${_pairs(short)}');
      return false;
    }
    return true;
  }

  static String _pairs(Map<String, int> pairs) =>
      pairs.entries.map((e) => '${e.key} v${e.value}').join(', ');

  // ===========================================================================
  // §2.4 Activation state machine
  // ===========================================================================

  /// Runs the UI-start transitions and returns the manifest to serve.
  ///
  /// **Only call this when the host widget is about to load a bundle.** Never from `main()` and never from
  /// a background isolate: an iOS background launch or a `workmanager` run must not consume a trial.
  Future<ValenceManifest> activateForUiStart() async {
    // --- Step 1: a newer built-in bundle wins. ------------------------------
    await _installBuiltinIfNewer();

    // --- Step 2: a crashed trial. ------------------------------------------
    // The `trial != null` half is load-bearing: in the ordinary no-trial state both fields are null, so a
    // bare `serving == trial` is satisfied on every launch, counts a failure each time, reaches two
    // strikes and marks whatever is being served bad.
    if (state.trial != null && state.serving == state.trial) {
      _log('update: the last UI start showed trial ${state.trial} and did not confirm it');
      countFailure();
    }

    // --- Step 3: a pending bundle, with no trial. --------------------------
    if (state.trial == null && state.pending != null) {
      final pending = state.pending!;
      // `current` and the floor are tested here, not only at download time, because a pointer can move
      // backwards, which can leave a `pending` behind a `current` or a floor that a later commit raised.
      final current = state.current ?? 0;
      if (pending <= current) {
        _log('update: dropping pending $pending, which is not above current $current');
        state.pending = null;
      } else if (pending < state.floor) {
        _log('update: dropping pending $pending, which is below the floor ${state.floor}');
        state.pending = null;
      } else if (state.bad.contains(pending)) {
        _log('update: dropping pending $pending, which is in bad for this install');
        state.pending = null;
        // A dropped pending is a change to the kept set, so what it referenced becomes collectable.
        scheduleGarbageCollect();
      } else {
        state.trial = pending;
        state.pending = null;
        state.trialFails = 0;
        _log('update: promoting $pending to a trial');
      }
      save();
    }

    return _serve();
  }

  /// Serves the bundle `applyUpdate` just promoted, **without** re-running the UI-start transitions.
  ///
  /// `applyUpdate` has already set `trial` and `serving`, so going back through
  /// [activateForUiStart] would make step 2's `trial != null && serving == trial` true by construction
  /// and spend a strike on the bundle it is about to show (§2.4 step 2).
  Future<ValenceManifest> serveAfterApplyUpdate() => _serve();

  /// Serves `current` after a ready timeout, leaving `trial` for the next UI start.
  ///
  /// §2.4: "on timeout, count a failure, then reload `current` right away". Re-entering
  /// [activateForUiStart] would take step 4's trial branch instead and show the failing bundle a second
  /// time, 15 s later — burning in this session the retry the spec grants to the *next* UI start.
  Future<ValenceManifest> serveCurrent() => _serve(ignoreTrial: true);

  /// §2.4 step 4.
  Future<ValenceManifest> _serve({bool ignoreTrial = false}) async {
    if (!ignoreTrial && state.trial != null) {
      final trial = await _loadManifest(state.trial!);
      if (trial != null) {
        state.serving = state.trial;
        save();
        return trial;
      }
      // The manifest is gone, which should be impossible because garbage collection keeps it. Treat it as
      // a failed trial rather than refusing to start.
      _log('update: trial ${state.trial} has no manifest on disk; counting it as a failure');
      countFailure();
      save();
    }
    if (state.current != null) {
      final current = await _loadManifest(state.current!);
      if (current != null) {
        state.serving = null;
        save();
        return current;
      }
      _log('update: current ${state.current} has no manifest on disk; falling back to the built-in bundle');
    }
    // install: true, not a bare load. Serving a built-in manifest whose files never passed check 7 means
    // the server 404s the entry page and the user gets a blank screen with nothing in the log — so a
    // built-in bundle that cannot be installed must not be servable either.
    final builtin = await _loadBuiltinManifest(install: true);
    if (builtin == null) {
      // A fresh install of a broken store build. There is no bundle left to render an error in, so the
      // host's only honest move is a native screen naming the check that failed: a blank WebView is both
      // undebuggable and the worst possible shape for a guideline 4.2.3(ii) review (§2.4).
      throw StateError(
        'valence: no bundle to serve. The built-in bundle was refused: '
        '${_builtinFailure ?? 'it is missing from ${config.builtinAssetDir}'}. '
        'The usual cause is requires.bridge above the version this host reports at check 5. Run '
        '"valence doctor", then "valence bundle --builtin", and check that ${config.builtinAssetDir} is '
        'declared in pubspec.yaml.',
      );
    }
    state.serving = null;
    save();
    return builtin;
  }

  /// §2.4 step 1. Installs the built-in bundle when a store update shipped a newer one.
  ///
  /// Gated on the built-in seq being above `current`, so it runs once per store release and is a no-op on
  /// every launch after that. That is what keeps an ordinary launch to a state read, a promotion decision
  /// and a bind.
  Future<void> _installBuiltinIfNewer() async {
    final id = await _builtinIdentity();
    // No readable built-in manifest at all. Step 4 is where that becomes visible, if there is nothing
    // else left to serve.
    if (id == null) return;

    // A refusal leaves `current` where it was, so the step-1 gate below is true again on the very next
    // launch and for ever. Without this skip, a broken store build re-verifies an Ed25519 signature in
    // front of every first frame on an install that is already beyond saving (§2.4).
    final refused = state.builtinRefused;
    if (refused != null && refused == id.fingerprint) {
      if (_refusalLogged != refused) {
        _refusalLogged = refused;
        _log('update: the built-in bundle ${id.seq} was refused; skipping step 1 until a store update '
            'changes it or the host it runs on');
      }
      return;
    }

    // The seq gate comes **before** the verify, not after. §2.4 budgets an ordinary launch at the state
    // read, the promotion decision and the bind; loading first would put an asset read, a manifest decode,
    // a pure-Dart Ed25519 verify and an existsSync per bundle file in front of every first frame, on every
    // launch, for a step that is a no-op after the first launch of a store build.
    if (id.seq <= (state.current ?? 0)) {
      if (refused != null) {
        state.builtinRefused = null;
        save();
      }
      return;
    }

    final builtin = await _loadBuiltinManifest(install: true);
    if (builtin == null) {
      // Nothing else in the state changes — not `current`, not `bad`. A built-in bundle is not a release
      // this install can decline, and the next store update replaces it.
      state.builtinRefused = id.fingerprint;
      save();
      return;
    }
    if (state.builtinRefused != null) {
      state.builtinRefused = null;
      save();
    }

    state.previous = state.current;
    state.current = builtin.seq;
    if (state.pending != null && state.pending! <= builtin.seq) {
      _log('update: built-in ${builtin.seq} drops pending ${state.pending}');
      state.pending = null;
    }
    if (state.trial != null && state.trial! <= builtin.seq) {
      _log('update: built-in ${builtin.seq} drops trial ${state.trial}');
      if (state.serving == state.trial) state.serving = null;
      state.trial = null;
      state.trialFails = 0;
    }
    // A store install is user-initiated and is itself the replacement, so it overrides an earlier OTA
    // judgement rather than being blocked by it.
    if (state.bad.remove(builtin.seq)) {
      _log('update: built-in ${builtin.seq} was in bad; a store install clears that');
    }
    save();
    _log('update: installed the built-in bundle ${builtin.seq} as current');
    // A store release is the only thing that ever changes the built-in bundle's `requires.data`, which is
    // what pins the oldest read-only pairs — so this is the event most likely to free disk, and a GC that
    // runs only after a commit never sees it (§2.4).
    scheduleGarbageCollect();
  }

  /// The built-in bundle's seq, plus a fingerprint of everything that decides whether it is servable.
  ///
  /// Verifies nothing: step 1 needs the seq to decide whether to run at all, and the fingerprint to decide
  /// whether a refusal it already paid for still applies. Both must be far cheaper than the verify.
  ///
  /// **The fingerprint covers the manifest bytes and the host's own bridge version, not just the seq.**
  /// The usual cause of a refusal is `requires.bridge` above the version the host reports at check 5, and
  /// the fix for that is a Dart change shipped with the *same* `assets/valence/builtin/` — same seq. A
  /// seq-only key would then skip step 1 on the very host built to fix it, leaving the install wedged for
  /// ever with no way out but another store release. The same goes for a re-checkout that repairs a
  /// CRLF-mangled asset without moving the seq.
  Future<({int seq, String fingerprint})?> _builtinIdentity() async {
    try {
      final bytes = await _readAsset('${config.builtinAssetDir}/manifest.json');
      final decoded = jsonDecode(utf8.decode(bytes));
      final seq = decoded is Map<String, Object?> ? decoded['seq'] : null;
      if (seq is! int || seq < 1) return null;
      final digest = sha256.convert(bytes).toString().substring(0, 16);
      return (seq: seq, fingerprint: '$seq.${config.bridgeVersion}.$digest');
    } on Object {
      return null;
    }
  }

  /// Counts one failed start of the trial, in the one place that may do so.
  ///
  /// Runs from the UI-start crash check or from a ready timeout. **If `trial` is null there is nothing to
  /// count:** a ready timeout on a `current` page means the app is slow, not that a release is bad.
  void countFailure() {
    final trial = state.trial;
    if (trial == null) {
      _log('update: no trial, so nothing to count as a failure and nothing to mark bad');
      return;
    }
    state.trialFails += 1;
    state.serving = null;
    if (state.trialFails >= 2) {
      if (!state.bad.contains(trial)) state.bad.add(trial);
      state.trial = null;
      state.trialFails = 0;
      // Without this, the stale pending promotes the bundle straight back with trialFails reset, for ever.
      if (state.pending != null && state.pending! <= trial) {
        _log('update: dropping pending ${state.pending}, at or below the bundle just marked bad');
        state.pending = null;
      }
      _log('update: trial $trial failed twice; marking it bad');
      // Scheduled, not run here: the WebView is still showing the trial page, whose lazily loaded chunks
      // and fonts are CAS files this marking has just made collectable. The caller reloads `current` first.
      scheduleGarbageCollect();
    } else {
      // One failure can be a user who opened and closed the app at once, so the next UI start tries again.
      _log('update: trial $trial failed once; it gets one more UI start');
    }
    save();
  }

  /// Commits the trial that is on screen, after `app.ready` arrived from it.
  ///
  /// The caller has already checked that `trial != null && serving == trial`: a `ready()` from a `current`
  /// page commits nothing, and neither does a late `ready()` from a page whose trial was given up on — by
  /// then `trial` is null, and without the guard `null == null` would commit `current = null`.
  Future<void> commitTrial(ValenceManifest trialManifest) async {
    state.previous = state.current;
    state.current = trialManifest.seq;
    state.trial = null;
    state.trialFails = 0;
    state.serving = null;
    if (state.pending != null && state.pending! <= trialManifest.seq) {
      _log('update: dropping pending ${state.pending}, at or below the committed ${trialManifest.seq}');
      state.pending = null;
    }
    if (trialManifest.floor > state.floor) state.floor = trialManifest.floor;
    // §2.3 check 4 already refuses seqs below the floor, so `bad` only has to remember the rest. Otherwise
    // it grows for the life of the install.
    state.bad.removeWhere((b) => b < state.floor);
    save();
    _log('update: committed ${trialManifest.seq}, floor is now ${state.floor}');
    scheduleGarbageCollect();
  }

  /// `bundle.applyUpdate`: the only transition that runs mid-session, and a **full** trial promotion.
  ///
  /// Returns the seq now on trial, or null when there was nothing to promote. The ready timer and failure
  /// counting then apply unchanged, so a white-screening urgent bundle costs two strikes and reverts like
  /// any other.
  Future<int?> applyUpdate() async {
    final pending = state.pending;
    if (pending == null) {
      _log('update: applyUpdate with no pending bundle; nothing to do');
      return null;
    }
    if (state.bad.contains(pending)) {
      _log('update: applyUpdate dropping pending $pending, which is in bad');
      state.pending = null;
      save();
      scheduleGarbageCollect();
      return null;
    }
    final current = state.current ?? 0;
    if (pending <= current || pending < state.floor) {
      _log('update: applyUpdate dropping pending $pending (current $current, floor ${state.floor})');
      state.pending = null;
      save();
      return null;
    }
    state.trial = pending;
    state.pending = null;
    state.trialFails = 0;
    state.serving = pending;
    save();
    _log('update: applyUpdate promoted $pending to a trial');
    return pending;
  }

  // ===========================================================================
  // Garbage collection (§2.4)
  // ===========================================================================

  /// Queues [garbageCollect] for the first post-frame callback, at most once per frame (§2.4).
  ///
  /// Never inside the transition that scheduled it. Step 1 already pays for a manifest decode, a signature
  /// verify and a hash of every file it installs in front of the first frame, and a directory walk, a stat
  /// per file and a SQLite transaction on top of that is exactly the launch that must not get slower. It
  /// also keeps a two-strike marking from deleting CAS files under the page still on screen.
  void scheduleGarbageCollect() {
    if (_gcScheduled) return;
    _gcScheduled = true;
    _afterFrame(() async {
      try {
        await garbageCollect();
      } on Object catch (e) {
        // A collection that fails costs disk, not correctness: every kept path is still on disk.
        _log('gc: collection failed: $e');
      } finally {
        // Cleared last, so a transition during a run schedules the *next* collection rather than a second
        // concurrent one racing this one's deletes.
        _gcScheduled = false;
      }
    });
  }

  /// Deletes every manifest, CAS file and read-only data pair that no kept bundle needs.
  ///
  /// Keeps `current`, `previous`, `pending`, `trial` and the built-in bundle. Prefer
  /// [scheduleGarbageCollect]; this is the body, and a test's entry point.
  Future<void> garbageCollect() async {
    final revision = _publicationRevision;
    final publishing = Map<int, ValenceManifest>.of(_publishing);
    final keptSeqs = <int>{
      ...[state.current, state.previous, state.pending, state.trial].whereType<int>(),
      ...publishing.keys,
    };
    final builtin = await _loadBuiltinManifest();
    if (builtin != null) keptSeqs.add(builtin.seq);

    final keptManifests = <ValenceManifest>[];
    for (final seq in keptSeqs) {
      final m = publishing[seq] ?? ((builtin != null && seq == builtin.seq) ? builtin : await _loadManifest(seq));
      if (m != null) keptManifests.add(m);
    }

    // Publication may have completed while signature or asset verification yielded.
    // Retry before deleting anything using a stale kept set.
    if (revision != _publicationRevision) return garbageCollect();

    final keptHashes = <String>{
      ..._inFlight,
      for (final m in keptManifests)
        for (final f in m.files.values) f.hash,
    };

    if (manifestsDir.existsSync()) {
      for (final e in manifestsDir.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final seq = int.tryParse(name.replaceAll(RegExp(r'\.json(\.sig)?$'), ''));
        if (seq == null || keptSeqs.contains(seq)) continue;
        try {
          e.deleteSync();
        } on Object catch (err) {
          _log('gc: could not delete $name: $err');
        }
      }
    }

    if (casDir.existsSync()) {
      for (final e in casDir.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        // A `tmp-<hash>` is a download mid-rename, which is not a hash and so would never be in the kept
        // set. Deleting it loses the file and leaves step 6 renaming something that is gone.
        if (keptHashes.contains(name) || name.startsWith('tmp-')) continue;
        try {
          e.deleteSync();
        } on Object catch (err) {
          _log('gc: could not delete cas/$name: $err');
        }
      }
    }

    // Read-only pairs no kept manifest requires. **Writable buckets are skipped before the kept-pairs
    // test, not after:** no manifest ever lists one in `requires.data`, because that field is only about
    // read-only schema co-versioning — so a rule phrased as "delete every pair no manifest requires"
    // destroys all of the user's own data on the first commit after an OTA.
    final required = <String, Set<int>>{};
    for (final m in keptManifests) {
      for (final e in m.requiresData.entries) {
        required.putIfAbsent(e.key, () => <int>{}).add(e.value);
      }
    }
    //
    // The lease covers the pair step only. §2.3 step 7 pulls a required pair while holding it, and that
    // bundle's manifest is not on disk until step 8 — so a collection that walks the kept set in the middle
    // of step 7 sees a freshly pulled pair that no *kept* manifest requires yet, deletes it, and leaves a
    // `pending` whose data is gone. Nothing re-pulls it either: step 1 of §2.3 stops once
    // `pointer.seq <= pending`. Publication retains the same lease through durable pending state.
    if (!await sync.acquireLease()) {
      _log('gc: another sync holds the lease; leaving read-only pairs to the next collection');
      return;
    }
    try {
      final pairs = await store.allPairs();
      if (revision != _publicationRevision) return;
      for (final e in pairs.entries) {
        if (config.writableBuckets.contains(e.key)) continue;
        for (final schema in e.value) {
          if (required[e.key]?.contains(schema) ?? false) continue;
          if (revision != _publicationRevision) return;
          _log('gc: dropping unrequired read-only pair ${e.key} v$schema');
          try {
            await store.dropPair(e.key, schema, writableBuckets: config.writableBuckets);
          } on Object catch (err) {
            _log('gc: could not drop ${e.key} v$schema: $err');
          }
        }
      }
    } finally {
      await sync.releaseLease();
    }
  }

  // ===========================================================================
  // Manifest loading
  // ===========================================================================

  File _casFile(String hash) => File('${casDir.path}${Platform.pathSeparator}$hash');
  File _manifestFile(int seq) => File('${manifestsDir.path}${Platform.pathSeparator}$seq.json');
  File _signatureFile(int seq) => File('${manifestsDir.path}${Platform.pathSeparator}$seq.json.sig');

  /// Loads a manifest already on disk, re-running checks 1, 2, 5 and 6.
  ///
  /// Re-verified rather than trusted: the file has been sitting in app storage since it was downloaded,
  /// and the signature is cheap next to the cost of serving an unsigned bundle. Check 3 is skipped (there
  /// is no pointer here) and so is check 4, because the floor is tested where a bundle is promoted.
  Future<ValenceManifest?> _loadManifest(int seq) async {
    final file = _manifestFile(seq);
    final sig = _signatureFile(seq);
    if (!file.existsSync() || !sig.existsSync()) return null;
    try {
      return await checkManifest(
        bytes: file.readAsBytesSync(),
        signature: sig.readAsStringSync(),
        config: config,
        state: ValenceState(installId: state.installId, floor: 0),
        pointerSeq: null,
      );
    } on ValenceCheckFailure catch (f) {
      _log('update: manifest $seq on disk failed re-verification: $f');
      return null;
    }
  }

  ValenceManifest? _builtinCache;

  /// Reads and verifies the built-in bundle from the app's assets.
  ///
  /// With [install] set, any of its files missing from CAS are written there first, through check 7 — the
  /// same path an OTA bundle takes, minus check 3, because a built-in bundle has no pointer.
  Future<ValenceManifest?> _loadBuiltinManifest({bool install = false}) async {
    if (_builtinCache != null && !install) return _builtinCache;
    final Uint8List bytes;
    final String signature;
    try {
      bytes = await _readAsset('${config.builtinAssetDir}/manifest.json');
      signature = utf8.decode(await _readAsset('${config.builtinAssetDir}/manifest.json.sig'));
    } on Object catch (e) {
      _builtinFailure = 'it is missing from ${config.builtinAssetDir} ($e)';
      _log('update: no built-in bundle in assets (${config.builtinAssetDir}): $e');
      return null;
    }
    final ValenceManifest m;
    try {
      m = await checkManifest(
        bytes: bytes,
        signature: signature,
        config: config,
        state: ValenceState(installId: state.installId, floor: 0),
        pointerSeq: null,
      );
    } on ValenceCheckFailure catch (f) {
      _builtinFailure = '$f';
      _log('update: the built-in bundle failed verification: $f');
      return null;
    }
    if (install) {
      await casDir.create(recursive: true);
      await manifestsDir.create(recursive: true);
      for (final f in m.files.values) {
        final target = _casFile(f.hash);
        if (target.existsSync()) continue;
        final data = await _readAsset('${config.builtinAssetDir}/files/${f.hash}');
        // Check 7, on the built-in bundle too: an asset can be repacked by a build step.
        if (data.length != f.size || sha256.convert(data).toString() != f.hash) {
          _builtinFailure = 'check 7: file ${f.hash} failed its hash or size';
          _log('update: built-in file ${f.hash} failed its hash or size; refusing the built-in bundle');
          return null;
        }
        final tmp = File('${casDir.path}${Platform.pathSeparator}tmp-${f.hash}');
        await tmp.writeAsBytes(data, flush: true);
        await tmp.rename(target.path);
      }
      // Written into manifests/ as well, so every later launch loads `current` the same way whether it
      // came from the store or over the air.
      if (!_manifestFile(m.seq).existsSync()) {
        await _manifestFile(m.seq).writeAsBytes(m.bytes, flush: true);
        await _signatureFile(m.seq).writeAsString(signature.trim(), flush: true);
      }
    }
    _builtinCache = m;
    return m;
  }
}
