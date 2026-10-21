import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'log.dart';
import 'manifest.dart';
import 'native_http.dart';
import 'secure.dart';
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
export 'native_http.dart' show ValenceHttp, ValenceHttpResponse;
export 'secure.dart' show ValenceSecure, secureAuthTokenKey;
export 'server.dart' show ValenceServer, hostFileContentTypes, normaliseRequestPath;
export 'state.dart' show ValenceState;
export 'store.dart' show ValenceOutboxOp, ValenceRow, ValenceStore, defaultListLimit, isDatabaseLocked, maxListLimit;
export 'sync.dart' show ValenceSync, ValenceSyncReason, ValenceSyncResult, ValenceSyncStatus;
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
    required this.secure,
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
    Directory? documentsDir,
    ValenceSecure? secure,
    DatabaseFactory? databaseFactory,
  }) async {
    // `open` is awaited in `main()` **before** `runApp`, and `runApp` is what would otherwise create the
    // binding — but the store's directory (path_provider), the seed (rootBundle) and secure storage all
    // travel over platform channels, which need it. Done here rather than asking every app's `main()` to
    // remember, because forgetting fails only on a device: `flutter_test` always has a binding, so the
    // whole unit suite passes while the first real launch dies with "Binding has not yet been
    // initialized" before a single frame. It is idempotent, and it returns an existing test binding
    // unchanged.
    WidgetsFlutterBinding.ensureInitialized();
    final support = supportDir ?? await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}valence');
    await dir.create(recursive: true);
    // ponytail: backup exclusion is platform setup, not a Dart call. iOS needs
    // NSURLIsExcludedFromBackupKey on this directory from AppDelegate, Android needs
    // dataExtractionRules/fullBackupContent. See the package README; a plugin would be the upgrade path.

    // The database lives *outside* valence/, because it holds user data and should be backed up.
    final store = await _openStore(config, support, documentsDir, log, databaseFactory);
    if (!store.isWal) {
      log('store: journal_mode is "${store.journalMode}", not wal; the concurrency the data layer '
          'assumes is not available on this filesystem');
    }

    final stateFile = File('${dir.path}${Platform.pathSeparator}state.json');
    final state = ValenceState.load(stateFile);
    final keystore = secure ?? ValenceSecure(log: log);
    // §4.4: the stored token is the *fallback*. An app with its own refresh loop in Dart keeps its
    // `authToken` callback and nothing here overrides it, which is what makes this additive for a host
    // that already had one.
    final sync = ValenceSync(
      store: store,
      config: config.authToken == null ? config.copyWith(authToken: keystore.authToken) : config,
      client: client,
      log: log,
    );
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
      secure: keystore,
      dir: dir,
      hostBuild: hostBuild,
      log: log,
    );
    // The widget attaches later, so route the urgent-update callback through the runtime.
    updater.onUpdateReady = (seq) => valence.onUpdateReady?.call(seq);
    // §4.4: a rejected token is the page's problem to fix, so it has to reach the page. Buffered like
    // every other event, which matters here because a cold start's first sync beats the entry page.
    sync.onUnauthorized = () => valence.emit(eventScript('auth.expired', const <String, Object?>{}));
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

  /// Keystore- and Keychain-backed storage for the bearer token and the page's own secrets (§4.4).
  final ValenceSecure secure;

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
    // The server can delete a rotted CAS file and answer 500, but it cannot re-fetch one: §2.3 step 1
    // stops on `pointer.seq <= current`, so a bundle that is already current never reaches step 6. The
    // updater has to be told where to look (§2.4, "CAS integrity is re-checked lazily").
    updater.repairFrom = () => (manifest: manifest, corrupt: server.corruptHashes);
  }

  /// §5.2: imports the bundled seed on first launch **and after a host upgrade**, not on every launch.
  ///
  /// `Valence.open` is awaited in `main()` before `runApp`, so the extraction is in front of the first
  /// frame: copying a multi-megabyte asset to disk and attaching it every cold start is exactly the launch
  /// cost §2.4 budgets against. The import itself is idempotent — it only copies rows above the local
  /// `max_usn` for the pair — so the stamp only has to be right about *when the asset could have changed*,
  /// which is a host upgrade.
  Future<void> _importSeed() async {
    if (config.dataSchemas.isEmpty) return;
    final seedPath = '${dir.path}${Platform.pathSeparator}seed.db';
    final seedFile = File(seedPath);
    final ByteData asset;
    try {
      asset = await rootBundle.load(config.seedAsset);
    } on Object catch (e) {
      _log('seed: no bundled seed at ${config.seedAsset} ($e); the app starts with an empty store');
      return;
    }
    // The host build plus the asset length: the build alone misses a seed changed by an OTA-era rebuild
    // at the same version, and the length alone misses a same-size replacement across an upgrade.
    final stamp = '$hostBuild.${asset.lengthInBytes}';
    final done = await store.hostPrefGet(_seedStamp) == stamp && seedFile.existsSync();
    if (!done) {
      try {
        await seedFile.writeAsBytes(asset.buffer.asUint8List(), flush: true);
      } on Object catch (e) {
        _log('seed: could not write $seedPath ($e); the app starts with an empty store');
        return;
      }
    }
    try {
      final counts = await store.importSeed(seedPath, config.dataSchemas, additionalSchemas: {
        for (final e in config.seedSchemas.entries)
          if (config.dataSchemas.containsKey(e.key) && !config.writableBuckets.contains(e.key)) e.key: e.value,
      });
      final moved = counts.values.fold<int>(0, (a, b) => a + b);
      if (moved > 0) _log('seed: imported $counts');
      // Stamped only after a clean import, so a crash mid-import retries on the next launch.
      await store.hostPrefSet(_seedStamp, stamp);
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

  /// `data.getMany`, using the active bundle's schema just like [dataGet].
  Future<List<ValenceRow>> dataGetMany(String bucket, List<String> keys) =>
      store.getMany(bucket, schemaFor(bucket), keys);

  /// `sync.status`. A local snapshot; never starts a network request.
  Future<ValenceSyncStatus> syncStatus() => sync.status();

  /// `data.list`. The host clamps `limit`, rather than trusting the page (§4.2).
  ///
  /// [after] resumes strictly after that key, which is how a page reads a bucket larger than the clamp.
  Future<List<ValenceRow>> dataList(String bucket, {String? prefix, int? limit, String? after}) =>
      store.list(bucket, schemaFor(bucket), prefix: prefix, limit: limit, after: after);

  /// `data.count`. Live rows only, resolved against the same schema as [dataList].
  Future<int> dataCount(String bucket, {String? prefix}) => store.count(bucket, schemaFor(bucket), prefix: prefix);

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
        return const ValenceSyncResult([], 0, true, ValenceSyncReason.offline);
      }),
    );
  }

  /// `sync.now`.
  Future<ValenceSyncResult> syncNow({List<String>? buckets}) => sync.run(
        readSchemas: _manifest?.requiresData ?? config.dataSchemas,
        only: buckets,
      );

  /// The pref recording which seed has already been imported (§5.2).
  static const _seedStamp = 'valence.seed.imported';

  /// `prefs.get`. The page may not read the host's own keys.
  ///
  /// The `valence.` refusal lives in [ValenceStore.prefGet], not here, so it also covers an app that
  /// defines its own settings method and reaches the store directly (§4.2). The runtime's own keys go
  /// through `hostPrefGet`/`hostPrefSet`.
  Future<String?> prefsGet(String key) => store.prefGet(key);

  /// `prefs.set`. The page may not write the host's own keys. See [prefsGet].
  Future<void> prefsSet(String key, String? value) => store.prefSet(key, value);

  /// `secure.get`. The page may not read the host's own keys, the stored token among them (§4.4).
  Future<String?> secureGet(String key) => secure.get(key);

  /// `secure.set`. A non-null value: [secureDelete] is the only delete.
  Future<void> secureSet(String key, String value) => secure.set(key, value);

  /// `secure.delete`.
  Future<void> secureDelete(String key) => secure.delete(key);

  /// `auth.setToken`. A null [token] clears it. The host attaches it to every user-bucket request (§4.4).
  Future<void> authSetToken(String? token) => secure.setAuthToken(token);

  /// `auth.hasToken`. Whether a token is stored — the only thing the page may learn about it.
  Future<bool> authHasToken() => secure.hasAuthToken();

  /// `http.request`: online text RPC restricted to the host's compiled origins (§4.5).
  Future<ValenceHttpResponse> httpRequest({
    required String url,
    String? method,
    Object? headers,
    String? body,
  }) =>
      ValenceHttp(
        origins: config.httpOrigins,
        token: config.authToken ?? secure.authToken,
        onUnauthorized: () =>
            emit(eventScript('auth.expired', const <String, Object?>{})),
      ).request(url: url, method: method, headers: headers, body: body);

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
    Directory? documentsDir,
    ValenceSecure? secure,
    DatabaseFactory? databaseFactory,
  }) async {
    final support = supportDir ?? await getApplicationSupportDirectory();
    final ValenceStore store;
    try {
      store = await _openStore(config, support, documentsDir, log, databaseFactory);
    } on Object catch (e) {
      // A background run that cannot even open the store has not observed anything, and the UI isolate
      // holding the file is itself about to sync. `busy` is the honest answer and the one the page's
      // freshness line already knows how to not lie about; a throw would be a WorkManager FAILURE instead.
      if (!isDatabaseLocked(e)) rethrow;
      log('sync: the UI isolate holds the database, so this background run did not start');
      return const ValenceSyncResult([], 0, false, ValenceSyncReason.busy);
    }
    // The same token the UI isolate uses (§4.4). There is no page to tell about a 401 here, so
    // `onUnauthorized` stays null and the log line is the record.
    final keystore = secure ?? ValenceSecure(log: log);
    final sync = ValenceSync(
      store: store,
      config: config.authToken == null ? config.copyWith(authToken: keystore.authToken) : config,
      client: client,
      log: log,
    );
    // The active manifest is not loaded in a background isolate, so the configured schemas are what this
    // can follow. They are the schemas the store build reads, which is the conservative choice.
    return sync.run(readSchemas: config.dataSchemas);
  }

  /// Opens the store at `<appSupport>/<databaseName>`, adopting a 0.3 database left in the application
  /// *documents* directory first.
  ///
  /// 0.3's contract never named a directory — §5.1 said only that the database lives outside `valence/` —
  /// so a conforming 0.3 host could have used either `path_provider` directory, and on Android those are
  /// different places (`files` and `app_flutter`). 0.4 fixes the choice to appSupport, which would
  /// otherwise create an empty database beside a full one and present a fresh install to a user whose
  /// data is still on disk. `host.database` cannot fix it: it names the file, not the directory.
  ///
  /// The package does this rather than the app because it is the only component that knows nothing else
  /// holds the file open yet.
  static Future<ValenceStore> _openStore(
    ValenceConfig config,
    Directory support,
    Directory? documentsDir,
    ValenceLogger log,
    DatabaseFactory? factory,
  ) async {
    final path = '${support.path}${Platform.pathSeparator}${config.databaseName}';
    if (!File(path).existsSync()) {
      await _adoptLegacyDatabase(path, config.databaseName, documentsDir, log);
    }
    // A locked open is retried rather than thrown. The schema upgrade takes `BEGIN EXCLUSIVE`, and the
    // launch that runs it is exactly the launch WorkManager fires the registered periodic job on, so the
    // UI isolate and the background isolate race for the file (§5.6). `busy_timeout` does not cover it:
    // the lock is refused before the connection that would wait on it exists. The budget matches the sync
    // lease's own five seconds, after which the caller decides — `backgroundSync` reports `busy`, and
    // `open` rethrows, because an app with no store cannot start.
    for (var attempt = 0;; attempt++) {
      try {
        return await ValenceStore.open(path, factory: factory);
      } on Object catch (e) {
        if (attempt >= 4 || !isDatabaseLocked(e)) rethrow;
        log('store: the database is locked by another isolate; retrying in one second');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Moves a 0.3 database and its write-ahead-log sidecars from the documents directory. See [_openStore].
  static Future<void> _adoptLegacyDatabase(
    String path,
    String name,
    Directory? documentsDir,
    ValenceLogger log,
  ) async {
    final Directory documents;
    try {
      documents = documentsDir ?? await getApplicationDocumentsDirectory();
    } on Object catch (e) {
      // A platform without the plugin, or a test binding without it. Nothing to adopt; never fatal.
      log('store: could not look for a 0.3 database: $e');
      return;
    }
    if (documents.path == File(path).parent.path) return;
    final legacy = '${documents.path}${Platform.pathSeparator}$name';
    if (!File(legacy).existsSync()) return;
    final moved = <String>[];
    try {
      // `-wal` first and the `.db` last. Until the `.db` lands the destination is still "no database", so a
      // crash midway leaves the 0.3 copy readable and the next launch retries the whole move. Moving the
      // `.db` alone would discard every commit still in the write-ahead log — for a syncing app, the last
      // sync.
      for (final suffix in const ['-wal', '-shm', '']) {
        final from = File('$legacy$suffix');
        if (!from.existsSync()) continue;
        // ponytail: rename, not copy. Both path_provider directories live in the app's private data on
        // every platform it supports, so they share a filesystem. A cross-device move would throw here and
        // be logged; copy-then-delete is the upgrade path if one ever does.
        from.renameSync('$path$suffix');
        moved.add('$name$suffix');
      }
    } on FileSystemException catch (e) {
      // The UI isolate and a background sync can reach this at the same moment on the launch that migrates.
      // Whoever renames first wins; the loser finds the source gone with the destination already correct.
      log(File(path).existsSync()
          ? 'store: another isolate moved the 0.3 database first'
          : 'store: moving the 0.3 database from ${documents.path} failed, so this launch starts empty: ${e.message}');
      return;
    }
    if (moved.isNotEmpty) log('store: moved the 0.3 database to ${File(path).parent.path} (${moved.join(', ')})');
  }

  /// Reads one asset as bytes. Used for the built-in bundle and the seed.
  static Future<Uint8List> readAsset(String key) async => (await rootBundle.load(key)).buffer.asUint8List();
}
