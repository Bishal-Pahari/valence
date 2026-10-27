/// The Flutter host runtime for Valence.
///
/// A signed over-the-air web bundle served from a loopback server, an offline-first SQLite store with
/// incremental sync, and a typed bridge generated from one schema. The spec is `contracts.md`; every
/// member here names the section it implements.
///
/// An app needs three things from this library: [Valence.open], [ValenceApp], and [ValenceConfig] — and
/// the last one is generated into `lib/valence/config.g.dart` by `valence codegen`.
library;

export 'src/app.dart' show ValenceApp, ValenceDispatch, valenceLifecycleFor, valenceOnline;
export 'src/runtime.dart'
    show
        BridgeError,
        BridgeErrorCode,
        Valence,
        ValenceAppInfo,
        ValenceAppState,
        ValenceBundleReason,
        ValenceBundleStatus,
        ValenceCheckFailure,
        ValenceConfig,
        ValenceFileEntry,
        ValenceHostView,
        ValenceHttp,
        ValenceHttpResponse,
        ValenceLifecycle,
        ValenceLogger,
        ValenceManifest,
        ValenceOutboxOp,
        ValenceRow,
        ValenceSecure,
        ValenceState,
        ValenceStore,
        ValenceSync,
        ValenceSyncMode,
        ValenceServer,
        ValenceSyncReason,
        ValenceSyncResult,
        ValenceSyncStatus,
        ValenceUpdater,
        checkManifest,
        decodePointer,
        defaultListLimit,
        defaultValenceLogger,
        fnv1a32,
        hostFileContentTypes,
        isDatabaseLocked,
        isReservedBundlePath,
        isSafeBundlePath,
        maxListLimit,
        normaliseRequestPath,
        secureAuthTokenKey,
        secureAuthAccountKey,
        maxMessageBytes;
