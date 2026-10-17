import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'log.dart';
import 'manifest.dart';
import 'server.dart';
import 'state.dart';
import 'store.dart';
import 'sync.dart';
import 'updater.dart';
import 'wire.dart';

export 'config.dart' show ValenceConfig, ValenceSyncMode;
export 'log.dart' show ValenceLogger, defaultValenceLogger;
export 'manifest.dart'
    show
        ValenceCheckFailure,
        ValenceFileEntry,
        ValenceManifest,
        checkManifest,
        decodePointer,
        fnv1a32,
        isReservedBundlePath,
        isSafeBundlePath;
export 'server.dart' show ValenceServer, hostFileContentTypes, normaliseRequestPath;
export 'state.dart' show ValenceState;
export 'store.dart' show ValenceOutboxOp, ValenceRow, ValenceStore, defaultListLimit, maxListLimit;
export 'sync.dart' show ValenceSync, ValenceSyncResult;
export 'updater.dart' show ValenceUpdater;
export 'wire.dart' show BridgeError, BridgeErrorCode, maxMessageBytes;

/// What `app.info` reports.
final class ValenceAppInfo {
  /// Creates an info record.
  const ValenceAppInfo({
    required this.platform,
    required this.host,
    required this.bridge,
    required this.bundle,
    required this.locale,
  });

  /// `android`, `ios`, or whatever `Platform.operatingSystem` says.
  final String platform;

  /// The native app's build number, as passed to [Valence.open].
  final int host;

  /// The host's bridge version. This is the generated `hostBridgeVersion`, never a second literal.
  final int bridge;

  /// The seq of the bundle currently being served.
  final int bundle;

  /// The device locale, for example `en_US`.
  final String locale;
}

/// What the runtime needs from the widget that owns the WebView.
///
/// [ValenceApp] implements it. An app that builds its own WebView can too.
abstract interface class ValenceHostView {
  /// Runs one script in the WebView, or buffers it until the entry page has loaded.
  void runScript(String script);

  /// Reloads the WebView from the server's origin.
  Future<void> reloadPage();

  /// Handles `app.ready` from the page: commits a trial, or does nothing for a `current` page.
  Future<void> handleReady();
}

/// The Valence host runtime.
///
/// Open it once in `main()`, hand it to [ValenceApp], and let the generated bridge handlers delegate the
/// built-in methods to it. Everything the spec calls the host — the loopback server, the updater, the
/// store, sync and the trust boundary — lives behind this object.
///
/// ```dart
/// void main() async {
///   final valence = await Valence.open(valenceConfig);
///   final handlers = AppHandlers(valence);
///   runApp(MaterialApp(
///     home: ValenceApp(
///       valence: valence,
///       dispatch: (raw, nonce) => bridgeDispatch(handlers, raw, nonce: nonce),
///     ),
///   ));
/// }
/// ```
final class Valence {
  Valence._({
    required this.config,
    required this.state,
    required this.store,
    required this.sync,
    required this.updater,
    required this.dir,
    required this.hostBuild,
    required ValenceLogger log,
  }) : _log = log;

  /// Opens the runtime: the data store, the seed import, the state file and the updater.
  ///
  /// Does **not** bind the server and does **not** run any §2.4 transition: those belong to the host
  /// widget, because an iOS background launch must not consume a trial.
  ///
  /// [hostBuild] is your native build number, reported by `app.info` so the web app can tell which store
  /// build it is running on.
  static Future<Valence> open(
    ValenceConfig config, {
    int hostBuild = 0,
    ValenceLogger log = defaultValenceLogger,
    http.Client? client,
    Directory? supportDir,
  }) async {
    final support = supportDir ?? await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}valence');
    await dir.create(recursive: true);
    // ponytail: backup exclusion is platform setup, not a Dart call. iOS needs
    // NSURLIsExcludedFromBackupKey on this directory from AppDelegate, Android needs
    // dataExtractionRules/fullBackupContent. See the package README; a plugin would be the upgrade path.

    // The database lives *outside* valence/, because it holds user data and should be backed up.
    final store = await ValenceStore.open(
      '${support.path}${Platform.pathSeparator}${config.databaseName}',
    );
    if (!store.isWal) {
      log('store: journal_mode is "${store.journalMode}", not wal; the concurrency the data layer '
          'assumes is not available on this filesystem');
    }

    final stateFile = File('${dir.path}${Platform.pathSeparator}state.json');
    final state = ValenceState.load(stateFile);
    final sync = ValenceSync(store: store, config: config, client: client, log: log);
    final updater = ValenceUpdater(
      config: config,
      state: state,
      stateFile: stateFile,
      casDir: Directory('${dir.path}${Platform.pathSeparator}cas'),
      manifestsDir: Directory('${dir.path}${Platform.pathSeparator}manifests'),
      store: store,
      sync: sync,
      readAsset: readAsset,
      client: client,
      log: log,
    );

    final valence = Valence._(
      config: config,
      state: state,
      store: store,
      sync: sync,
      updater: updater,
      dir: dir,
      hostBuild: hostBuild,
      log: log,
    );
    // The widget attaches later, so route the urgent-update callback through the runtime.
    updater.onUpdateReady = (seq) => valence.onUpdateReady?.call(seq);
    await valence._importSeed();
    return valence;
  }

  /// The app's configuration.
  final ValenceConfig config;

  /// The live activation state.
  final ValenceState state;

  /// The data store. Never closed, by any isolate.
  final ValenceStore store;

  /// The sync driver.
  final ValenceSync sync;

  /// The updater and the state machine.
  final ValenceUpdater updater;

  /// `<appSupport>/valence/`. Excluded from device backups by platform setup.
  final Directory dir;

  /// The native build number reported by `app.info`.
  final int hostBuild;

  final ValenceLogger _log;

  ValenceServer? _server;
  ValenceHostView? _view;
  ValenceManifest? _manifest;

  /// Called when a bundle marked `urgent` becomes pending. [ValenceApp] sets it to emit
  /// `bundle.updateReady` into the page, which may then call `bundle.applyUpdate`.
  void Function(int seq)? onUpdateReady;

  /// The bound server, once the host widget has started it.
  ValenceServer? get server => _server;

  /// The bundle being served.
  ValenceManifest? get manifest => _manifest;

  /// Attaches the widget that owns the WebView. Called by [ValenceApp].
  void attach(ValenceHostView view) => _view = view;

  /// Records the server and manifest the host widget is serving. Called by [ValenceApp].
  void bound(ValenceServer server, ValenceManifest manifest) {
    _server = server;
    _manifest = manifest;
    server.serveManifest(manifest);
  }

  Future<void> _importSeed() async {
    if (config.dataSchemas.isEmpty) return;
    final seedPath = '${dir.path}${Platform.pathSeparator}seed.db';
    final seedFile = File(seedPath);
    try {
      final bytes = (await rootBundle.load(config.seedAsset)).buffer.asUint8List();
      // Re-extracted on every launch so a store upgrade's newer seed is seen; the import itself is
      // idempotent, because it only copies rows above the local max_usn for the pair.
      await seedFile.writeAsBytes(bytes, flush: true);
    } on Object catch (e) {
      _log('seed: no bundled seed at ${config.seedAsset} ($e); the app starts with an empty store');
      return;
    }
    try {
      final counts = await store.importSeed(seedPath, config.dataSchemas);
      final moved = counts.values.fold<int>(0, (a, b) => a + b);
      if (moved > 0) _log('seed: imported $counts');
    } on Object catch (e) {
      _log('seed: import failed: $e');
    }
  }

  // ===========================================================================
  // Built-in bridge methods. The generated BridgeHandlers implementation delegates to these, so the
  // logic ships in this package and only the schema-shaped marshalling is generated.
  // ===========================================================================

  /// `app.ready`. Commits a trial bundle, if the page serving it is the one that called.
  Future<void> appReady() async {
    final view = _view;
    if (view == null) {
      _log('bridge: app.ready arrived before a host view was attached');
      return;
    }
    await view.handleReady();
  }

  /// `app.info`.
  ValenceAppInfo appInfo() => ValenceAppInfo(
        platform: Platform.operatingSystem,
        host: hostBuild,
        bridge: config.bridgeVersion,
        bundle: _manifest?.seq ?? 0,
        locale: Platform.localeName,
      );

  /// The schema `data.*` resolves [bucket] against.
  ///
  /// A writable bucket is always schema 1. A read-only bucket uses the schema the **active bundle's**
  /// manifest requires, so the old UI keeps reading its own schema and a failed trial reverts with its
  /// data intact (§5.4).
  int schemaFor(String bucket) {
    if (config.writableBuckets.contains(bucket)) return 1;
    final fromManifest = _manifest?.requiresData[bucket];
    if (fromManifest != null) return fromManifest;
    final fromConfig = config.dataSchemas[bucket];
    if (fromConfig != null) return fromConfig;
    throw BridgeError(
      BridgeErrorCode.params,
      'unknown bucket "$bucket"; declare it under "data" or "writable" in valence.config.json',
    );
  }

  /// `data.get`.
  Future<Object?> dataGet(String bucket, String key) => store.get(bucket, schemaFor(bucket), key);

  /// `data.list`. The host clamps `limit`, rather than trusting the page (§4.2).
  Future<List<ValenceRow>> dataList(String bucket, {String? prefix, int? limit}) =>
      store.list(bucket, schemaFor(bucket), prefix: prefix, limit: limit);

  /// `data.put`. A null [value] is the delete. Refuses a bucket that is not writable.
  Future<void> dataPut(String bucket, String key, Object? value) async {
    if (!config.writableBuckets.contains(bucket)) {
      throw BridgeError(
        BridgeErrorCode.denied,
        '"$bucket" is not a writable bucket; add it to "writable" in valence.config.json',
      );
    }
    await store.put(bucket, key, value, opId: ValenceState.newInstallId());
    // Fire and forget: a local write is durable the moment the transaction commits, and the page must not
    // wait on the network for it.
    unawaited(
      syncNow(buckets: [bucket]).catchError((Object e) {
        _log('sync: background push for $bucket failed: $e');
        return const ValenceSyncResult([], 0, true);
      }),
    );
  }

  /// `sync.now`.
  Future<ValenceSyncResult> syncNow({List<String>? buckets}) => sync.run(
        readSchemas: _manifest?.requiresData ?? config.dataSchemas,
        only: buckets,
      );

  /// `prefs.get`. The page may not read the host's own keys.
  Future<String?> prefsGet(String key) {
    _refuseReservedPrefKey(key);
    return store.prefGet(key);
  }

  /// `prefs.set`. The page may not write the host's own keys.
  Future<void> prefsSet(String key, String? value) {
    _refuseReservedPrefKey(key);
    return store.prefSet(key, value);
  }

  void _refuseReservedPrefKey(String key) {
    // The `valence.` prefix is reserved for the host, so the web cannot tamper with internal state such
    // as the sync lease (§4.2).
    if (key == 'valence' || key.startsWith('valence.')) {
      throw BridgeError(BridgeErrorCode.denied, 'the "valence." pref prefix is reserved for the host');
    }
  }

  /// `open.external`. Only `https:`, `mailto:` and `tel:` leave the app.
  Future<void> openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !const {'https', 'mailto', 'tel'}.contains(uri.scheme.toLowerCase())) {
      throw BridgeError(
        BridgeErrorCode.denied,
        'open.external accepts https, mailto and tel only, not "$url"',
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw BridgeError(BridgeErrorCode.internal, 'nothing on this device could open $url');
    }
  }

  /// `bundle.applyUpdate`. A full trial promotion, then a reload (§2.4).
  Future<void> applyUpdate() async {
    final seq = await updater.applyUpdate();
    if (seq == null) return;
    await _view?.reloadPage();
  }

  // ===========================================================================
  // For app code
  // ===========================================================================

  /// Runs an event script in the WebView, buffering it until the entry page exists.
  ///
  /// `window.__valence` does not exist until the entry page has loaded, so an event emitted before that
  /// is silently dropped — and the interesting ones arrive exactly then. Pass a generated builder:
  ///
  /// ```dart
  /// valence.emit(BridgeEvents.syncChanged(buckets: ['plants']));
  /// ```
  void emit(String script) => _view?.runScript(script);

  /// Writes bytes under the server's reserved `/_host/` prefix and returns the relative URL.
  ///
  /// This is the only path from native bytes to the page: the bridge carries JSON only, capped at
  /// [maxMessageBytes] in each direction (§4.2).
  Future<String> publishHostFile(List<int> bytes, {required String contentType}) {
    final server = _server;
    if (server == null) {
      throw BridgeError(BridgeErrorCode.internal, 'the loopback server is not bound yet');
    }
    return server.publishHostFile(bytes, contentType: contentType);
  }

  /// How many local writes are still waiting to sync, across every writable bucket.
  Future<int> pendingWrites() => store.pendingWrites();

  /// Runs a sync from a background isolate.
  ///
  /// Call `DartPluginRegistrant.ensureInitialized()` first, and open the store on the same path — each
  /// isolate gets the same plugin-side connection back, and **no isolate may close it** (§5.1). This runs
  /// sync only: it never touches the state machine, because a background launch must not consume a trial.
  static Future<ValenceSyncResult> backgroundSync(
    ValenceConfig config, {
    ValenceLogger log = defaultValenceLogger,
    http.Client? client,
    Directory? supportDir,
  }) async {
    final support = supportDir ?? await getApplicationSupportDirectory();
    final store = await ValenceStore.open(
      '${support.path}${Platform.pathSeparator}${config.databaseName}',
    );
    final sync = ValenceSync(store: store, config: config, client: client, log: log);
    // The active manifest is not loaded in a background isolate, so the configured schemas are what this
    // can follow. They are the schemas the store build reads, which is the conservative choice.
    return sync.run(readSchemas: config.dataSchemas);
  }

  /// Reads one asset as bytes. Used for the built-in bundle and the seed.
  static Future<Uint8List> readAsset(String key) async =>
      (await rootBundle.load(key)).buffer.asUint8List();
}
