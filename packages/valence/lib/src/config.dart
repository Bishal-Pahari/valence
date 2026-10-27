/// How the host pulls read-only buckets (contracts §5.3).
enum ValenceSyncMode {
  /// `GET {syncBase}/{bucket}?since=&schema=&limit=` against your own API.
  api,

  /// CDN only, no backend: `{syncBase}/{bucket}/v{schema}/index.json` plus gzipped chunk files.
  ///
  /// Read-only buckets only. Push needs an endpoint, so a writable bucket still needs [api].
  staticChunks,
}

/// Everything about one app that the runtime needs. `valence codegen` writes the literal for this into
/// `lib/valence/config.g.dart`, so an app's `main()` passes `valenceConfig` and nothing else.
final class ValenceConfig {
  /// Creates a configuration. Prefer the generated `valenceConfig` over writing this by hand: the
  /// generated one is checked against `valence.config.json` and `keyring.json` by `codegen --check`.
  const ValenceConfig({
    required this.appId,
    required this.keyring,
    required this.bridgeVersion,
    this.otaBase = '',
    this.syncBase = '',
    this.syncMode = ValenceSyncMode.api,
    this.writableBuckets = const {},
    this.dataSchemas = const {},
    this.seedSchemas = const {},
    this.channel = 'production',
    this.bundleSizeCap = 50 * 1024 * 1024,
    this.dataSizeCap = 50 * 1024 * 1024,
    this.readyTimeout = const Duration(seconds: 15),
    this.updateInterval = const Duration(minutes: 30),
    this.pullPageLimit = 500,
    this.databaseName = 'valence.db',
    this.builtinAssetDir = 'assets/valence/builtin',
    this.seedAsset = 'assets/valence/seed.db',
    this.authToken,
    this.httpOrigins = const {},
    this.linkOrigins = const {},
  });

  /// The reverse-domain id a manifest must carry (canonical check 2).
  final String appId;

  /// `{keyId: base64 raw Ed25519 public key}`, compiled into the host by codegen.
  ///
  /// To rotate, ship a host that holds both keys, then switch signing. Losing the private key costs a
  /// store release, because this map is what the host trusts.
  final Map<String, String> keyring;

  /// The host's bridge version, which canonical check 5 compares `requires.bridge` against.
  ///
  /// Codegen wires this to the generated `hostBridgeVersion`. Never pass a second literal: a host that
  /// under-reports its version refuses its own built-in bundle on first launch, with nothing left to serve.
  final int bridgeVersion;

  /// The static OTA host, for example `https://ota.example.com`. An empty string disables updates.
  final String otaBase;

  /// The sync API base. An empty string disables sync, which is valid for a seed-only app.
  final String syncBase;

  /// Whether read-only buckets come from an API or from static chunks on a CDN.
  final ValenceSyncMode syncMode;

  /// Buckets the page may write through `data.put`. They never change schema and always use schema 1.
  final Set<String> writableBuckets;

  /// Read-only buckets and the schema this build reads, from `data` in `valence.config.json`.
  final Map<String, int> dataSchemas;

  /// Additional declared read-only schemas to import from the bundled seed (§5.2).
  final Map<String, List<int>> seedSchemas;

  /// The OTA channel this build follows, for example `production` or `beta`.
  final String channel;

  /// The cap on a single update's new bytes (canonical check order, §2.3 step 5).
  final int bundleSizeCap;

  /// The cap on what §2.3 step 7 may pull across all `(bucket, schema)` pairs before backing off.
  final int dataSizeCap;

  /// How much foreground time a trial bundle has to call `app.ready` before it counts a failure.
  final Duration readyTimeout;

  /// How often to check for an update while in the foreground.
  final Duration updateInterval;

  /// Rows per pull page. Kept small so a long background transaction does not queue the UI's reads.
  final int pullPageLimit;

  /// The SQLite file name, inside the application support directory.
  ///
  /// Kept configurable for one reason: a 0.3 app whose generated host picked its own name — `fieldnote.db`,
  /// say — must keep reading the user's existing data when it moves to this package. Set it to that name
  /// and nothing has to be migrated. It lives *outside* `valence/` because it holds user data and should
  /// be backed up (§2.4).
  final String databaseName;

  /// The asset directory `valence bundle --builtin` writes into.
  final String builtinAssetDir;

  /// The bundled SQLite seed `valence seed` writes.
  final String seedAsset;

  /// Returns a bearer token for user-scoped bucket requests, or null for public buckets.
  ///
  /// Called per request, so a rotating token works. The host never persists what this returns.
  final Future<String?> Function()? authToken;

  /// Exact HTTP(S) origins trusted with the bearer token by `http.request` (§4.5).
  /// Compiled from `http.origins`; empty denies every request. Never supplied by an OTA manifest.
  final Set<String> httpOrigins;

  /// Exact HTTPS/custom-scheme origins accepted as local routes (§6.3).
  final Set<String> linkOrigins;

  /// Copy with overrides. Handy in tests and for pointing a debug build at a local OTA host.
  ValenceConfig copyWith({
    String? otaBase,
    String? syncBase,
    ValenceSyncMode? syncMode,
    String? channel,
    int? bundleSizeCap,
    int? dataSizeCap,
    Duration? readyTimeout,
    Duration? updateInterval,
    int? pullPageLimit,
    Future<String?> Function()? authToken,
    Set<String>? httpOrigins,
    Set<String>? linkOrigins,
  }) =>
      ValenceConfig(
        appId: appId,
        keyring: keyring,
        bridgeVersion: bridgeVersion,
        otaBase: otaBase ?? this.otaBase,
        syncBase: syncBase ?? this.syncBase,
        syncMode: syncMode ?? this.syncMode,
        writableBuckets: writableBuckets,
        dataSchemas: dataSchemas,
        seedSchemas: seedSchemas,
        channel: channel ?? this.channel,
        bundleSizeCap: bundleSizeCap ?? this.bundleSizeCap,
        dataSizeCap: dataSizeCap ?? this.dataSizeCap,
        readyTimeout: readyTimeout ?? this.readyTimeout,
        updateInterval: updateInterval ?? this.updateInterval,
        pullPageLimit: pullPageLimit ?? this.pullPageLimit,
        databaseName: databaseName,
        builtinAssetDir: builtinAssetDir,
        seedAsset: seedAsset,
        authToken: authToken ?? this.authToken,
        httpOrigins: httpOrigins ?? this.httpOrigins,
        linkOrigins: linkOrigins ?? this.linkOrigins,
      );
}
