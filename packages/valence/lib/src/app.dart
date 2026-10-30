import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'appearance.dart';
import 'runtime.dart';
import 'restoration.dart';
import 'wire.dart';

/// Turns one message from the JS channel into a reply. The generated `bridgeDispatch`, partially applied.
typedef ValenceDispatch = Future<String> Function(String raw, String nonce);

/// Flutter's five lifecycle states as the four a page sees (§4.6).
///
/// Top-level and pure on purpose: [ValenceApp] needs a WebView platform to build at all, so the mapping
/// and the dedupe it feeds are the half of this that a unit test can reach.
ValenceLifecycle valenceLifecycleFor(AppLifecycleState state) =>
    switch (state) {
      AppLifecycleState.resumed => ValenceLifecycle.foreground,
      AppLifecycleState.inactive => ValenceLifecycle.inactive,
      // Android delivers hidden and then paused for one backgrounding. One transition, so one event.
      AppLifecycleState.hidden ||
      AppLifecycleState.paused =>
        ValenceLifecycle.background,
      AppLifecycleState.detached => ValenceLifecycle.detached,
    };

/// Whether a connectivity report means online: **any** interface that is not `none` (§4.6).
///
/// connectivity_plus reports a list, and a device on Wi-Fi and VPN at once has two entries — so a check
/// written against `results.first` calls a working device offline whenever the VPN sorts first. This is
/// interface state and never reachability.
bool valenceOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

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

class _ValenceAppState extends State<ValenceApp>
    with WidgetsBindingObserver
    implements ValenceHostView {
  static const _devUrl =
      kDebugMode ? String.fromEnvironment('VALENCE_DEV_URL') : '';
  static const _devMode = kDebugMode && _devUrl != '';

  WebViewController? _controller;
  Object? _error;
  String _origin = '';
  ValenceAppearance? _appearance;
  bool _appearanceScheduled = false;

  /// One-shot event scripts waiting for `window.__valence` to exist.
  ///
  /// The §4.6 state events are **not** in here: they are dropped when no page is loaded, because
  /// `app.state()` re-derives them. What is left is kept not because nothing could re-derive it —
  /// `sync.status()` carries most of what `sync.done` does — but because `sync.changed` and the
  /// `sync.done` for the same run have to stay ordered, and dropping either half breaks a pairing the
  /// page is told it can rely on.
  final List<String> _buffered = [];

  /// Bounded, because `onPageFinished` is not guaranteed. A host whose entry page never finishes, on a
  /// device the host keeps syncing for, would otherwise grow this list for the life of the process. The
  /// oldest go first: for every event in here the newest is the one worth delivering.
  static const _maxBuffered = 64;

  bool _pageLoaded = false;

  /// The ready timer counts **foreground** time only, so a backgrounded app costs a trial nothing.
  final Stopwatch _readyClock = Stopwatch();
  Timer? _readyTicker;

  Timer? _updateTicker;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

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
    _valence.onUpdateReady =
        (seq) => runScript(eventScript('bundle.updateReady', {'seq': seq}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _valence.attach(this, flutterView: View.of(context));
  }

  @override
  void dispose() {
    unawaited(_valence.links.close());

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
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (!mounted) return;
      // §2.4: the UI-start transitions, here and nowhere else.
      final manifest = _devMode
          ? await _valence.updater.developmentManifest()
          : await _valence.updater.activateForUiStart();
      final server = await ValenceServer.bind(
        config: _valence.config,
        state: _valence.state,
        casDir: Directory('${_valence.dir.path}${Platform.pathSeparator}cas'),
        hostDir: Directory('${_valence.dir.path}${Platform.pathSeparator}host'),
        log: _log,
      );
      _valence.updater.save(); // bind may have moved state.port
      _valence.bound(server, manifest);
      await _valence.prepareRestoration(manifest.seq);
      _origin = server.origin;
      if (_devMode) {
        _log('dev: serving upstream ${Uri.parse(_devUrl).origin} on ${server.origin}; '
            'OTA checks, trials, ready commits and bundle.applyUpdate are disabled '
            '(signed schema context ${manifest.seq})');
      } else {
        _log('serving bundle ${manifest.seq} on ${server.origin}');
      }

      final controller = WebViewController();
      await _setTextZoom(controller);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel('Valence',
          onMessageReceived: _onBridgeMessage);
      // Without this, a JavaScript error during the bundle's bootstrap produces nothing at all — no log,
      // no onWebResourceError, just a dark rectangle — while the host is working correctly (§3).
      await controller.setOnConsoleMessage(
          (m) => _log('webview[${m.level.name}] ${m.message}'));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onUrlChange: (change) {
            if (change.url != null) {
              _valence.restoration.observe(change.url!, _origin);
            }
          },
          onHttpError: (e) => _log(
              'webview http ${e.response?.statusCode} for ${e.request?.uri}'),
          onWebResourceError: (e) =>
              _log('webview resource error ${e.errorCode}: ${e.description}'),
        ),
      );
      await controller.loadRequest(
          Uri.parse('${server.origin}${_valence.restoration.route}'));
      if (!mounted) return;
      setState(() => _controller = controller);
      if (_pageLoaded) _publishAppearance(forceEvent: true);

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
    // §2.3: start, resume, foreground interval and live connectivity reports. Never block first paint.
    unawaited(_checkForUpdate());
    unawaited(_syncNow());
    _updateTicker = Timer.periodic(
        _valence.config.updateInterval, (_) => unawaited(_checkForUpdate()));
    _connectivity =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    // The stream only reports *changes*, so without this a page that asks `app.state()` on a cold start
    // reads the optimistic default rather than an answer (§4.6).
    unawaited(_readConnectivity());
  }

  Future<void> _readConnectivity() async {
    try {
      _noteConnectivity(await Connectivity().checkConnectivity());
    } on Object catch (e) {
      _log('connectivity: could not read the current state: $e');
    }
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final online = _noteConnectivity(results);
    // The sync trigger is "connectivity came back", so it fires on any report with a live interface, not
    // only on the edge: a Wi-Fi-to-cellular handover is two live reports and the run in between failed.
    if (online) {
      _log('sync: connectivity came back');
      unawaited(_syncNow());
      // Background sync may run here, but update discovery belongs to the foreground UI.
      // Handover reports count too; the updater coalesces overlapping checks and keeps its data lease.
      if (_valence.appState().lifecycle == ValenceLifecycle.foreground) {
        _log('update: connectivity came back in the foreground');
        unawaited(_checkForUpdate());
      }
    }
  }

  /// Records connectivity and returns whether we are online. The runtime emits `app.online` (§4.6).
  bool _noteConnectivity(List<ConnectivityResult> results) {
    final online = valenceOnline(results);
    _valence.noteOnline(online);
    return online;
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
      if (e is Map<String, Object?>) {
        _log('bridge error ${e['code']}: ${e['message']}');
      }
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
    return uri.scheme == ours.scheme &&
        uri.host == ours.host &&
        uri.port == ours.port;
  }

  static bool _isHostPath(String path) {
    final segments = normaliseRequestPath(path);
    return segments == null ||
        (segments.isNotEmpty && segments.first == '_host');
  }

  // ---------------------------------------------------------------------------
  // Page lifecycle and the ready timer
  // ---------------------------------------------------------------------------

  void _onPageStarted(String url) {
    _valence.restoration.observe(url, _origin);
    _log('webview started $url');
    _pageLoaded = false;
    _valence.links.beginPage();
    final state = _valence.state;
    // Armed only while serving a trial. A `current` page is not on probation, so a slow start costs it
    // nothing — and a ready timeout on a `current` page must count no failure at all.
    if (!_devMode && state.trial != null && state.serving == state.trial) {
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
    _publishAppearance(forceEvent: true);
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
    if (_devMode) {
      _log('dev: handleReady skipped; app.ready does not commit a trial');
      return;
    }
    final state = _valence.state;
    final trial = state.trial;
    // It commits only if app.ready comes from the page that is serving the trial. A ready() from a
    // `current` page never commits anything, and neither does a late ready() from a page whose trial has
    // already been given up on — by then `trial` is null, and without the guard `null == null` would
    // commit `current = null`.
    if (trial == null || state.serving != trial) {
      _log(
          'ready: app.ready from a page that is not serving a trial; nothing to commit');
      return;
    }
    final manifest = _valence.manifest;
    if (manifest == null || manifest.seq != trial) {
      _log(
          'ready: app.ready for trial $trial but the served manifest is ${manifest?.seq}; not committing');
      return;
    }
    _stopReadyTimer();
    await _valence.updater.commitTrial(manifest);
  }

  @override
  bool get pageLoaded => _pageLoaded && _controller != null;

  @override
  void runScript(String script) {
    if (pageLoaded) {
      unawaited(_controller!.runJavaScript(script));
      return;
    }
    _buffered.add(script);
    if (_buffered.length > _maxBuffered) {
      _buffered.removeAt(0);
      _log(
          'event: the buffer is full at $_maxBuffered; dropping the oldest undelivered event');
    }
  }

  @override
  Future<void> reloadPage() async {
    if (_devMode) {
      _log('dev: reloadPage skipped; signed bundle reload is disabled');
      return;
    }
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
    _valence.restoration.activate(manifest.seq);
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
    _noteLifecycle(state);
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
        if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) {
          unawaited(_captureRoute());
        }
    }
  }

  Future<void> _captureRoute() async {
    final seq = _valence.manifest?.seq;
    final controller = _controller;
    final origin = _origin;
    final accountRevision = _valence.restoration.accountRevision;
    try {
      final url = await controller?.currentUrl();
      if (mounted &&
          seq == _valence.manifest?.seq &&
          controller == _controller &&
          origin == _origin &&
          accountRevision == _valence.restoration.accountRevision &&
          url != null) {
        _valence.restoration.observe(url, origin);
      }
    } on Object catch (e) {
      _log('restoration: could not capture route: $e');
    }
  }

  /// §4.6: the five platform states as the four the page sees, recorded only when they change.
  ///
  /// Not gated on `_started`, unlike the resume *work* below: a transition during start-up must still
  /// update what `app.state()` returns, so the page that loads next reads the truth. The runtime decides
  /// whether an event can be delivered — during start-up no page is loaded, so it is dropped, not queued.
  void _noteLifecycle(AppLifecycleState state) {
    final mapped = valenceLifecycleFor(state);
    if (_valence.appState().lifecycle == mapped) return;
    // Logged as well as emitted. The page can only report the events it *received*, so without a host-side
    // line there is no way to tell "the platform never sent it" from "the script never ran".
    _log('lifecycle: ${state.name} -> ${mapped.name}');
    _valence.noteLifecycle(mapped);
  }

  Future<void> _onResume() async {
    if (!mounted) return;
    _scheduleAppearance();

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
    if (permissions.isNotEmpty) {
      runScript(
          eventScript('permissions.changed', {'permissions': permissions}));
    }
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
    _log(
        'resume: the loopback socket was reclaimed; rebinding port ${server.port}');
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
      _log(
          'resume: reclaimed port ${rebound.port}, keeping the nonce and the page');
      return;
    }
    _log(
        'resume: could not reclaim port ${server.port}; moved to ${rebound.port} and reloading');
    _pageLoaded = false;
    await _controller?.loadRequest(Uri.parse(rebound.origin));
  }

  Future<bool> _isOurServerAlive(ValenceServer server) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req =
          await client.getUrl(Uri.parse('${server.origin}/_host/alive'));
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
    if (_devMode) {
      _log('dev: update check skipped; OTA discovery is disabled');
      return;
    }
    try {
      await _valence.updater.checkForUpdate();
    } on Object catch (e) {
      _log('update: check failed: $e');
    }
  }

  Future<void> _syncNow() async {
    try {
      // `Valence.syncNow` emits sync.changed and then sync.done for the run, so that `data.put`'s own
      // push — which never passes through here — reports itself too (§4.6).
      await _valence.syncNow();
    } on Object catch (e) {
      _log('sync: run failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  ValenceAppearance _systemAppearance() => ValenceAppearance.fromMediaQuery(
      MediaQueryData.fromView(View.of(context)));

  Future<void> _setTextZoom(WebViewController controller) async {
    if (!mounted) return;
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setTextZoom(_systemAppearance().textZoom);
    }
  }

  void _publishAppearance({bool forceEvent = false}) {
    if (!mounted) return;
    final next = _systemAppearance();
    final previous = _appearance;
    if (previous == null || !next.samePreferences(previous)) {
      setState(() => _appearance = next);
    } else {
      _appearance = next;
    }
    final controller = _controller;
    if (controller != null) {
      unawaited(_setTextZoom(controller)
          .catchError((Object e) => _log('layout: text zoom failed: $e')));
      if (_pageLoaded) {
        runScript(next.script(
          scaleRootFont: Platform.isIOS,
          emitEvent:
              forceEvent || previous == null || !next.samePreferences(previous),
        ));
      }
    }
  }

  // Metrics can arrive before startup finishes, in bursts, or while backgrounded.
  // Read the owning view after the next frame; no reload and no pending-event replay.
  void _scheduleAppearance() {
    if (!mounted || _appearanceScheduled) return;
    _appearanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appearanceScheduled = false;
      _publishAppearance();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeMetrics() => _scheduleAppearance();

  @override
  void didChangeTextScaleFactor() => _scheduleAppearance();

  @override
  void didChangePlatformBrightness() => _scheduleAppearance();

  @override
  void didChangeAccessibilityFeatures() => _scheduleAppearance();

  @override
  Widget build(BuildContext context) {
    return RootRestorationScope(
      restorationId: 'valence.${_valence.config.appId}',
      child: ValenceRestorationScope(
        model: _valence.restoration,
        onReady: () => unawaited(_start()),
        child: _buildHost(context),
      ),
    );
  }

  Widget _buildHost(BuildContext context) {
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
      return widget.loading ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: ((_appearance ?? _systemAppearance()).darkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              (_appearance ?? _systemAppearance()).darkMode
                  ? Brightness.light
                  : Brightness.dark,
        ),
        child: Scaffold(body: WebViewWidget(controller: controller)),
      ),
    );
  }
}
