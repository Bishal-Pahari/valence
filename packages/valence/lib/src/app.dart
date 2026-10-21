import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'runtime.dart';
import 'wire.dart';

/// Turns one message from the JS channel into a reply. The generated `bridgeDispatch`, partially applied.
typedef ValenceDispatch = Future<String> Function(String raw, String nonce);

/// The host widget: the loopback server, the WebView, the navigation lock, the back gesture, the ready
/// timer and the lifecycle triggers (contracts §2.4, §3, §4.2, §7).
///
/// Put it at the root of the app. It runs the §2.4 UI-start transitions in `initState`, which is the only
/// place they may run: a background launch must not consume a trial.
class ValenceApp extends StatefulWidget {
  /// Creates the host.
  const ValenceApp({
    required this.valence,
    required this.dispatch,
    this.loading,
    this.onError,
    this.log = defaultValenceLogger,
    super.key,
  });

  /// The open runtime, from `Valence.open`.
  final Valence valence;

  /// `(raw, nonce) => bridgeDispatch(handlers, raw, nonce: nonce)`.
  final ValenceDispatch dispatch;

  /// Shown while the first bundle is being resolved. A plain centred spinner by default.
  final Widget? loading;

  /// Shown when there is no servable bundle at all. The default reports the error as selectable text.
  final Widget Function(Object error)? onError;

  /// Where the host's own lines go.
  final ValenceLogger log;

  @override
  State<ValenceApp> createState() => _ValenceAppState();
}

class _ValenceAppState extends State<ValenceApp> with WidgetsBindingObserver implements ValenceHostView {
  WebViewController? _controller;
  Object? _error;
  String _origin = '';

  /// Event scripts waiting for `window.__valence` to exist.
  final List<String> _buffered = [];
  bool _pageLoaded = false;

  /// The ready timer counts **foreground** time only, so a backgrounded app costs a trial nothing.
  final Stopwatch _readyClock = Stopwatch();
  Timer? _readyTicker;

  Timer? _updateTicker;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  /// The last `max_usn` each pair was reported to the page with, so resume can re-derive `sync.changed`.
  final Map<String, int> _lastSeenUsn = {};

  /// Whether [_start] has finished, so a resume can tell steady state from start-up (§3).
  ///
  /// The observer is registered in [initState], and on Android it fires *during* the first launch — so
  /// without this, backgrounding a cold app runs an update check alongside the §2.4 UI-start transition
  /// that is still in flight, and a resume handler sees a server and a manifest that do not exist yet.
  bool _started = false;

  Valence get _valence => widget.valence;
  ValenceLogger get _log => widget.log;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _valence.attach(this);
    _valence.onUpdateReady = (seq) => runScript(eventScript('bundle.updateReady', {'seq': seq}));
    unawaited(_start());
  }

  @override
  void dispose() {
    _valence.detach(this);
    _readyTicker?.cancel();
    _updateTicker?.cancel();
    unawaited(_connectivity?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    // The server is closed, but the store is deliberately **not**: sqflite keys open databases by path
    // inside the platform plugin, so closing here would invalidate the handle a background isolate holds.
    unawaited(_valence.server?.close());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Startup
  // ---------------------------------------------------------------------------

  Future<void> _start() async {
    try {
      // §2.4: the UI-start transitions, here and nowhere else.
      final manifest = await _valence.updater.activateForUiStart();
      final server = await ValenceServer.bind(
        config: _valence.config,
        state: _valence.state,
        casDir: Directory('${_valence.dir.path}${Platform.pathSeparator}cas'),
        hostDir: Directory('${_valence.dir.path}${Platform.pathSeparator}host'),
        log: _log,
      );
      _valence.updater.save(); // bind may have moved state.port
      _valence.bound(server, manifest);
      _origin = server.origin;
      _log('serving bundle ${manifest.seq} on ${server.origin}');

      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel('Valence', onMessageReceived: _onBridgeMessage);
      // Without this, a JavaScript error during the bundle's bootstrap produces nothing at all — no log,
      // no onWebResourceError, just a dark rectangle — while the host is working correctly (§3).
      await controller.setOnConsoleMessage((m) => _log('webview[${m.level.name}] ${m.message}'));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onHttpError: (e) => _log('webview http ${e.response?.statusCode} for ${e.request?.uri}'),
          onWebResourceError: (e) => _log('webview resource error ${e.errorCode}: ${e.description}'),
        ),
      );
      await controller.loadRequest(Uri.parse(server.origin));
      if (!mounted) return;
      setState(() => _controller = controller);

      await _valence.permissions.refresh(baseline: true);
      if (!mounted) return;
      _armTriggers();
    } on Object catch (e, st) {
      _log('host: could not start: $e\n$st');
      // Deliberate: a failed start-up still counts as "no longer starting", so a later resume runs the
      // update check and the sync. That is the only in-process route out of a transient failure — a bind
      // collision, or an `activateForUiStart` that a fixing release would resolve — and `_reclaimPort`
      // is a no-op with no server, so there is nothing for it to touch.
      _started = true;
      if (mounted) setState(() => _error = e);
    }
  }

  void _armTriggers() {
    // From here a resume is steady state, so it may run the triggers below (§3).
    _started = true;
    // §2.3: on UI start, on resume, and every 30 minutes in the foreground. Never blocking the first paint.
    unawaited(_checkForUpdate());
    unawaited(_syncNow());
    _updateTicker = Timer.periodic(_valence.config.updateInterval, (_) => unawaited(_checkForUpdate()));
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _log('sync: connectivity came back');
        unawaited(_syncNow());
      }
    });
  }

  // ---------------------------------------------------------------------------
  // The bridge trust boundary
  // ---------------------------------------------------------------------------

  void _onBridgeMessage(JavaScriptMessage message) {
    unawaited(() async {
      final nonce = _valence.server?.nonce ?? '';
      // bridgeDispatch never throws: it checks the nonce, decodes strictly and turns everything into a
      // reply. An empty nonce means no server, and every message is then denied.
      final reply = await widget.dispatch(message.message, nonce);
      _logBridgeError(reply);
      await _controller?.runJavaScript(bridgeReplyScript(reply));
    }());
  }

  /// Logs every error reply the host sends back (§4.3).
  ///
  /// A bridge method that throws is otherwise invisible to everybody: `bridgeDispatch` turns it into an
  /// error reply, the page's `await call(...)` rejects inside an effect nobody awaited, and nothing reaches
  /// a log or a screen. This is the one place that sees all of them.
  void _logBridgeError(String reply) {
    if (!reply.contains('"ok":false')) return;
    try {
      final decoded = jsonDecode(reply);
      final e = decoded is Map<String, Object?> ? decoded['e'] : null;
      if (e is Map<String, Object?>) _log('bridge error ${e['code']}: ${e['message']}');
    } on FormatException {
      // bridgeDispatch builds the reply with jsonEncode, so this cannot happen; not worth a crash if it does.
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    // The main frame is locked to the loopback origin, and `/_host/` is not a main-frame navigation: those
    // URLs are for subresources only. Serving attacker-supplied bytes as a document on the bundle's origin
    // would hand the page's nonce — and the whole bridge — to them (§3, §7).
    if (_isOurOrigin(uri) && !_isHostPath(uri.path)) {
      return NavigationDecision.navigate;
    }
    if (request.isMainFrame) {
      _log('nav: opening ${request.url} outside the app');
      unawaited(
        _valence.openExternal(request.url).catchError((Object e) {
          _log('nav: refused ${request.url}: $e');
        }),
      );
    } else {
      // No off-origin subframes, ever: a JavaScriptChannel cannot tell which frame a message came from.
      _log('nav: blocked the off-origin subframe ${request.url}');
    }
    return NavigationDecision.prevent;
  }

  bool _isOurOrigin(Uri uri) {
    if (_origin.isEmpty) return false;
    final ours = Uri.parse(_origin);
    return uri.scheme == ours.scheme && uri.host == ours.host && uri.port == ours.port;
  }

  static bool _isHostPath(String path) {
    final segments = normaliseRequestPath(path);
    return segments == null || (segments.isNotEmpty && segments.first == '_host');
  }

  // ---------------------------------------------------------------------------
  // Page lifecycle and the ready timer
  // ---------------------------------------------------------------------------

  void _onPageStarted(String url) {
    _log('webview started $url');
    _pageLoaded = false;
    final state = _valence.state;
    // Armed only while serving a trial. A `current` page is not on probation, so a slow start costs it
    // nothing — and a ready timeout on a `current` page must count no failure at all.
    if (state.trial != null && state.serving == state.trial) {
      _readyClock
        ..reset()
        ..start();
      _readyTicker?.cancel();
      _readyTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_readyClock.elapsed < _valence.config.readyTimeout) return;
        unawaited(_onReadyTimeout());
      });
    } else {
      _stopReadyTimer();
    }
  }

  void _onPageFinished(String url) {
    _log('webview finished $url');
    _pageLoaded = true;
    // window.__valence does not exist until the entry page has loaded, so events emitted before now were
    // buffered. Flushed again after every reload, because an update or a reverted trial reloads the page.
    final queued = [..._buffered];
    _buffered.clear();
    for (final script in queued) {
      unawaited(_controller?.runJavaScript(script) ?? Future<void>.value());
    }
  }

  void _stopReadyTimer() {
    _readyTicker?.cancel();
    _readyTicker = null;
    _readyClock
      ..stop()
      ..reset();
  }

  Future<void> _onReadyTimeout() async {
    _stopReadyTimer();
    final trial = _valence.state.trial;
    if (trial == null || _valence.state.serving != trial) {
      // Nothing on probation. A timeout here means the app is slow, not that a release is bad.
      _log('ready: timed out with no trial on screen; counting nothing');
      return;
    }
    _log(
        'ready: app.ready did not arrive within ${_valence.config.readyTimeout.inSeconds}s for trial $trial');
    _valence.updater.countFailure();
    await _reloadCurrent();
  }

  @override
  Future<void> handleReady() async {
    final state = _valence.state;
    final trial = state.trial;
    // It commits only if app.ready comes from the page that is serving the trial. A ready() from a
    // `current` page never commits anything, and neither does a late ready() from a page whose trial has
    // already been given up on — by then `trial` is null, and without the guard `null == null` would
    // commit `current = null`.
    if (trial == null || state.serving != trial) {
      _log('ready: app.ready from a page that is not serving a trial; nothing to commit');
      return;
    }
    final manifest = _valence.manifest;
    if (manifest == null || manifest.seq != trial) {
      _log('ready: app.ready for trial $trial but the served manifest is ${manifest?.seq}; not committing');
      return;
    }
    _stopReadyTimer();
    await _valence.updater.commitTrial(manifest);
  }

  @override
  void runScript(String script) {
    if (_pageLoaded && _controller != null) {
      unawaited(_controller!.runJavaScript(script));
      return;
    }
    _buffered.add(script);
  }

  @override
  Future<void> reloadPage() async {
    // Step 4 only. `applyUpdate` has already promoted the trial and set `serving`, so re-running the
    // UI-start transitions would make step 2's crash check true by construction and spend a strike on the
    // bundle this reload is about to show (§2.4).
    await _swapBundle(await _valence.updater.serveAfterApplyUpdate());
  }

  Future<void> _reloadCurrent() async {
    // `current`, explicitly: the trial stays set so the *next* UI start retries it once, which is the
    // retry §2.4 grants after a single failure. Re-running the transitions would take step 4's trial
    // branch and show the failing bundle again 15 s later, spending that retry here instead.
    await _swapBundle(await _valence.updater.serveCurrent());
  }

  /// Serves a different bundle.
  ///
  /// §3: swapping the active bundle restarts the server, and the old one is **closed before binding
  /// again** — otherwise the host collides with its own listening socket, moves to a new port and rotates
  /// the nonce in the middle of a fallback.
  Future<void> _swapBundle(ValenceManifest manifest) async {
    final old = _valence.server;
    final keepNonce = old?.nonce;
    await old?.close();
    final server = await ValenceServer.bind(
      config: _valence.config,
      state: _valence.state,
      casDir: Directory('${_valence.dir.path}${Platform.pathSeparator}cas'),
      hostDir: Directory('${_valence.dir.path}${Platform.pathSeparator}host'),
      log: _log,
      keepNonce: keepNonce,
    );
    _valence.updater.save();
    _valence.bound(server, manifest);
    _origin = server.origin;
    _pageLoaded = false;
    _log('serving bundle ${manifest.seq} on ${server.origin}');
    await _controller?.loadRequest(Uri.parse(server.origin));
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_readyTicker != null) _readyClock.start();
        unawaited(_onResume());
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // The ready timer counts foreground time, so it pauses with the app.
        _readyClock.stop();
    }
  }

  Future<void> _onResume() async {
    // §3: the resume callback can arrive before start-up finishes, and `_start` runs the same triggers at
    // its end anyway — so there is nothing here that a mid-startup resume needs to do, and running it
    // would put an update check alongside the UI-start transition still in flight.
    if (!_started) {
      _log('resume: start-up has not finished, so this resume does nothing');
      return;
    }
    await _reclaimPort();
    final permissions = await _valence.permissions.refresh();
    if (!mounted) return;
    if (permissions.isNotEmpty) runScript(eventScript('permissions.changed', {'permissions': permissions}));
    runScript(eventScript('app.resumed', const <String, Object?>{}));
    unawaited(_checkForUpdate());
    await _syncNow();
  }

  /// iOS can reclaim listening sockets while the app is suspended (§3).
  ///
  /// If the same port comes back, the nonce is kept and the page keeps working. If it does not, the port
  /// and the nonce both rotate and the page is reloaded: the old page must not keep running against a port
  /// we no longer own.
  Future<void> _reclaimPort() async {
    final server = _valence.server;
    if (server == null) return;
    if (await _isOurServerAlive(server)) return;
    _log('resume: the loopback socket was reclaimed; rebinding port ${server.port}');
    await server.close();
    final manifest = _valence.manifest;
    if (manifest == null) return;
    final rebound = await ValenceServer.bind(
      config: _valence.config,
      state: _valence.state,
      casDir: Directory('${_valence.dir.path}${Platform.pathSeparator}cas'),
      hostDir: Directory('${_valence.dir.path}${Platform.pathSeparator}host'),
      log: _log,
      keepNonce: server.nonce,
    );
    _valence.updater.save();
    _valence.bound(rebound, manifest);
    final samePort = rebound.port == server.port;
    _origin = rebound.origin;
    if (samePort) {
      _log('resume: reclaimed port ${rebound.port}, keeping the nonce and the page');
      return;
    }
    _log('resume: could not reclaim port ${server.port}; moved to ${rebound.port} and reloading');
    _pageLoaded = false;
    await _controller?.loadRequest(Uri.parse(rebound.origin));
  }

  Future<bool> _isOurServerAlive(ValenceServer server) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(Uri.parse('${server.origin}/_host/alive'));
      final res = await req.close();
      await res.drain<void>();
      return res.headers.value('x-valence') == 'alive';
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      await _valence.updater.checkForUpdate();
    } on Object catch (e) {
      _log('update: check failed: $e');
    }
  }

  Future<void> _syncNow() async {
    try {
      final result = await _valence.syncNow();
      // For state rather than one-shot notifications, prefer re-deriving to replaying: compare each pair's
      // max_usn with the last value the page was told, and report only the ones that moved (§4.2, §5.6).
      final moved = <String>[];
      final schemas = _valence.manifest?.requiresData ?? _valence.config.dataSchemas;
      for (final bucket in {...result.buckets, ...schemas.keys, ..._valence.config.writableBuckets}) {
        final schema = _valence.config.writableBuckets.contains(bucket) ? 1 : schemas[bucket] ?? 1;
        final usn = await _valence.store.maxUsn(bucket, schema);
        if (_lastSeenUsn[bucket] != usn) {
          _lastSeenUsn[bucket] = usn;
          moved.add(bucket);
        }
      }
      // sync.changed, bundle.updateReady and app.resumed are the runtime's own events, so the package
      // builds them with the same jsonEncode-based helper the generated BridgeEvents uses. An app's own
      // events go through valence.emit(BridgeEvents.myEvent(...)).
      if (moved.isNotEmpty) runScript(eventScript('sync.changed', {'buckets': moved}));
    } on Object catch (e) {
      _log('sync: run failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.onError?.call(error) ??
          Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('$error', textAlign: TextAlign.center),
              ),
            ),
          );
    }
    final controller = _controller;
    if (controller == null) {
      return widget.loading ?? const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Android users expect back to go back, and a Scaffold holding a WebViewWidget pops its only route
    // instead — so the first swipe from any sub-screen closes the app. It is the most common complaint
    // about WebView apps on Android and the first thing a Play reviewer does (§3).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (await controller.canGoBack()) {
          await controller.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(body: WebViewWidget(controller: controller)),
    );
  }
}
