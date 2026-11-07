// The real host widget, not a reimplementation of its security or lifecycle policy (contracts §8).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valence/valence.dart';
import 'package:valence/codegen.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'helpers.dart';
import 'webview_stub.dart';

/// What iOS reports when the WebView's content process is killed to reclaim memory (§3).
const contentProcessGone = WebResourceError(
  errorCode: 2,
  description: 'WKErrorDomain: the web content process was terminated',
  errorType: WebResourceErrorType.webContentProcessTerminated,
  isForMainFrame: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestKey key;
  late SignedBundle builtin;
  late SignedBundle trial;
  late Directory support;
  late Valence runtime;
  late StubWebViewPlatform webview;
  late LogSpy log;
  late List<String> requests;
  Future<http.Response> Function(http.Request)? respond;
  late List<String> launches;
  late List<String> platformCalls;
  late List<(String, String)> messages;
  late StreamController<Object?> connectivity;
  HttpOverrides? previousHttp;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    key = await TestKey.create();
    builtin = await signBundle(key, seq: 10);
    trial = await signBundle(key, seq: 20);
    sqfliteFfiInit();
  });

  setUp(() async {
    support = await Directory.systemTemp.createTemp('valence-widget-');
    ValenceStore.resetCacheForTests();
    webview = StubWebViewPlatform();
    WebViewPlatform.instance = webview;
    log = LogSpy();
    requests = [];
    respond = null;
    launches = [];
    platformCalls = [];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    messages = [];
    previousHttp = HttpOverrides.current;
    // Flutter's default HTTP stub returns 400 even for our real loopback liveness probe.
    HttpOverrides.global = null;
    connectivity = StreamController<Object?>.broadcast();
    messenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        MockStreamHandler.inline(onListen: (_, sink) {
      connectivity.stream.listen(sink.success);
    }));
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      launches.add((call.arguments as Map)['url'] as String);
      return true;
    });
    final assets = builtin.asAssets('assets/valence/builtin');
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final bytes = assets[name];
      return bytes == null ? null : ByteData.sublistView(bytes);
    });
    runtime = await Valence.open(
      testConfig(key,
              writableBuckets: {'shelf'},
              dataSchemas: {'days': 1},
              cacheBuckets: {'days'})
          .copyWith(
        bundleCheckedEvent: true,
        // Off-device `links.start()` is skipped (§6.3), so this only lets a test hand the mailbox an
        // intent the allowlist accepts; nothing else in the host reads it.
        linkOrigins: {'myapp://app'},
        readyTimeout: const Duration(milliseconds: 80),
        updateInterval: const Duration(seconds: 5),
      ),
      supportDir: support,
      documentsDir: support,
      databaseFactory: databaseFactoryFfi,
      secure: testSecure({}),
      client: MockClient((request) async {
        requests.add(request.url.toString());
        if (respond != null) return respond!(request);
        return request.url.host == 'sync.test'
            ? http.Response('{"rows":[],"max":0,"more":false}', 200)
            : http.Response('', 404);
      }),
      log: log.call,
    );
  });

  tearDown(() async {
    await connectivity.close();
    messenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), null);
    messenger.setMockMessageHandler('flutter/assets', null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await runtime.server?.close();
    // Test-owned database only, after the widget and native callbacks are gone.
    await runtime.store.db.close();
    support.deleteSync(recursive: true);
    HttpOverrides.global = previousHttp;
  });

  Future<void> drain(WidgetTester tester) async {
    // Disk, SQLite and real loopback I/O cannot complete in testWidgets' fake async zone.
    // Bounded polling fails with evidence rather than hanging the suite.
    for (var i = 0; i < 200; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      if (webview.controllers.isNotEmpty &&
          webview.controller.loads.isNotEmpty) {
        await tester.pump();
        return;
      }
      if (log.lines.any((s) => s.contains('host: could not start'))) break;
    }
    fail('host did not load: ${log.lines}');
  }

  Future<void> io(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() completed,
      String description) async {
    // Verification and SQLite use real I/O; a fixed sleep races other test files.
    final elapsed = Stopwatch()..start();
    while (!completed() && elapsed.elapsed < const Duration(seconds: 5)) {
      await io(tester);
    }
    expect(completed(), isTrue, reason: '$description: ${log.lines}');
    await tester.pump();
  }

  Future<void> waitForPending(WidgetTester tester) => waitFor(
      tester,
      () =>
          runtime.state.pending == trial.seq &&
          runtime.bundleStatus().reason == ValenceBundleReason.ready,
      'verified pending update');

  Future<void> mount(WidgetTester tester,
      {bool pending = false, bool blocked = false}) async {
    if (pending) {
      trial.writeTo(
          manifestsDir: Directory('${runtime.dir.path}/manifests'),
          casDir: Directory('${runtime.dir.path}/cas'));
      runtime.state.current = builtin.seq;
      runtime.state.pending = trial.seq;
      builtin.writeTo(
          manifestsDir: Directory('${runtime.dir.path}/manifests'),
          casDir: Directory('${runtime.dir.path}/cas'));
    }
    if (blocked) webview.configureGate = Completer<void>();
    await tester.runAsync(() => tester.pumpWidget(MaterialApp(
            home: ValenceApp(
          valence: runtime,
          log: log.call,
          dispatch: (raw, nonce) async {
            messages.add((raw, nonce));
            return '{"id":"test","ok":true,"r":null}';
          },
        ))));
    // Registered first, so timers/observers are gone even when an assertion fails.
    addTearDown(() async {
      if (webview.configureGate case final gate? when !gate.isCompleted) {
        gate.complete();
        await drain(tester);
      }
      await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
      await io(tester);
    });
    if (!blocked) {
      await drain(tester);
    } else {
      for (var i = 0; i < 200 && webview.controllers.isEmpty; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
      expect(webview.controllers, hasLength(1));
    }
  }

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
    await tester.runAsync(
        () async => tester.binding.handleAppLifecycleStateChanged(state));
    await tester.pump();
  }

  if (const String.fromEnvironment('VALENCE_DEV_URL') != '') {
    testWidgets(
        'dev diagnostics identify bypasses without changing OTA evidence',
        (tester) async {
      // A previous signed run left an unconfirmed trial. Development must neither
      // spend its remaining strike nor promote/commit it, even after ready/resume.
      runtime.state
        ..trial = trial.seq
        ..serving = trial.seq
        ..trialFails = 1;
      await mount(tester, pending: true);
      await io(tester);
      final before = runtime.state.toJson();
      final saved = File('${runtime.dir.path}/state.json').readAsStringSync();
      final controller = webview.controller;
      final host = tester.state(find.byType(ValenceApp)) as ValenceHostView;
      await tester.runAsync(() async {
        controller.navigation.started(runtime.server!.origin);
        await runtime.appReady();
        await runtime.applyUpdate();
        await host.reloadPage();
        await runtime.checkBundleUpdate();
      });
      await lifecycle(tester, AppLifecycleState.paused);
      await lifecycle(tester, AppLifecycleState.resumed);
      await io(tester);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5200)));
      await io(tester);
      expect(runtime.state.toJson(), before);
      expect(File('${runtime.dir.path}/state.json').readAsStringSync(), saved);
      expect(controller.loads, hasLength(1));
      expect(requests.where((url) => !url.startsWith('https://sync.test/')),
          isEmpty);
      expect(requests, isNotEmpty, reason: 'ordinary sync still runs');
      expect(log.lines.where((line) => line.startsWith('serving bundle ')),
          isEmpty);
      expect(
          log.has(
              'dev: serving upstream ${Uri.parse(const String.fromEnvironment('VALENCE_DEV_URL')).origin}'),
          isTrue);
      for (final message in [
        'OTA checks, trials, ready commits and bundle.applyUpdate are disabled',
        'dev: handleReady skipped',
        'dev: reloadPage skipped',
        'dev: update check skipped',
        'dev: bundle.applyUpdate skipped',
      ]) {
        expect(log.has(message), isTrue, reason: message);
      }
      expect(
          log.lines
              .where((line) => line.startsWith('dev: update check skipped'))
              .length,
          greaterThanOrEqualTo(3),
          reason: 'startup, explicit, resume and periodic check');
      expect(log.lines.join('\n'), isNot(contains(runtime.server!.nonce)));
    });
  } else {
    testWidgets('signed startup retains bundle diagnostic without dev warnings',
        (tester) async {
      await mount(tester);
      await io(tester);
      expect(log.has('serving bundle ${builtin.seq} on '), isTrue);
      expect(log.lines.where((line) => line.startsWith('dev:')), isEmpty);
    });
  }

  Future<http.Response> serveTrial(http.Request request,
      {bool validSignature = true}) async {
    if (request.url.host == 'sync.test') {
      return http.Response('{"rows":[],"max":0,"more":false}', 200);
    }
    final path = request.url.path;
    if (path.endsWith('/channels/production.json')) {
      return http.Response('{"seq":20,"rollout":100}', 200);
    }
    if (path.endsWith('/manifests/20.json')) {
      return http.Response.bytes(trial.bytes, 200);
    }
    if (path.endsWith('/manifests/20.json.sig')) {
      return http.Response(
          validSignature ? trial.signature : builtin.signature, 200);
    }
    final blob = trial.blobs[path.split('/').last];
    return blob == null
        ? http.Response('', 404)
        : http.Response.bytes(blob, 200);
  }

  int pointerRequests() =>
      requests.where((url) => url.endsWith('/channels/production.json')).length;

  testWidgets(
      'R31 native block pauses trial, denies queued bridge and accepts signed withdrawal',
      (tester) async {
    await mount(tester, pending: true);
    // Captured while there still is one: the teardown below forgets the server as well as closing it,
    // so that a later resume cannot mistake it for a socket iOS reclaimed and rebind it (§2.5).
    final origin = runtime.server!.origin;
    final policy = await tester
        .runAsync(() => signBundle(key, seq: 50, overrides: {'minHost': 2}));
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) return http.Response('{"seq":50,"rollout":100}', 200);
      if (request.url.path.endsWith('/50.json')) return http.Response.bytes(policy!.bytes, 200);
      if (request.url.path.endsWith('/50.json.sig')) return http.Response(policy!.signature, 200);
      return http.Response('', 404);
    };
    connectivity.add(['none']);
    await io(tester);
    connectivity.add(['wifi']);
    await waitFor(
        tester, () => runtime.updater.storeUpdateRequired, 'mandatory policy');
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byKey(const ValueKey('stub-webview')), findsNothing);
    expect(runtime.state.trial, 20);
    expect(runtime.state.trialFails, 0);
    expect(runtime.state.serving, isNull);
    final before = messages.length;
    webview.controller.channel
        .onMessageReceived(const JavaScriptMessage(message: '{}'));
    await io(tester);
    expect(messages.length, before);
    await tester.pump(const Duration(seconds: 1));
    expect(runtime.state.trialFails, 0);
    // Taking the page out of the widget tree is not taking it down. The controller and the loopback
    // server have to go too, or the old page keeps running behind the blocking screen: its timers fire,
    // its own CSP-allowed origins stay reachable, and the host keeps pushing events into it.
    final scripts = webview.controller.scripts.length;
    runtime.emit('window.__valence&&window.__valence.e("x",{})');
    await io(tester);
    expect(webview.controller.scripts.length, scripts);
    expect(
        await tester.runAsync(() async {
          try {
            await http.get(Uri.parse('$origin/'));
            return 'answered';
          } on Object {
            return 'closed';
          }
        }),
        'closed');
    // Same manifest cannot be rewritten by an unsigned pointer; a later signed withdrawal can unblock.
    final withdrawal = await tester.runAsync(() => signBundle(key, seq: 60));
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) return http.Response('{"seq":60,"rollout":100}', 200);
      if (request.url.path.endsWith('/60.json')) return http.Response.bytes(withdrawal!.bytes, 200);
      if (request.url.path.endsWith('/60.json.sig')) return http.Response(withdrawal!.signature, 200);
      final blob = withdrawal!.blobs[request.url.path.split('/').last];
      return blob == null
          ? http.Response('', 404)
          : http.Response.bytes(blob, 200);
    };
    await tester.runAsync(() => tester.tap(find.text('Check again')));
    await waitFor(
        tester,
        () =>
            !runtime.updater.storeUpdateRequired &&
            webview.controllers.length == 2 &&
            webview.controllers.last.loads.isNotEmpty,
        'signed withdrawal');
    expect(find.text('Update required'), findsNothing);
    await io(tester);
  });

  testWidgets(
      'R31 cached policy blocks cold UI without consuming pending or trial',
      (tester) async {
    final policy = await tester
        .runAsync(() => signBundle(key, seq: 50, overrides: {'minHost': 2}));
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) return http.Response('{"seq":50,"rollout":100}', 200);
      if (request.url.path.endsWith('/50.json')) return http.Response.bytes(policy!.bytes, 200);
      if (request.url.path.endsWith('/50.json.sig')) return http.Response(policy!.signature, 200);
      return http.Response('', 404);
    };
    await tester.runAsync(() => runtime.updater.checkForUpdate());
    runtime.state.pending = 20;
    final before = runtime.state.toJson();
    respond = (_) async => http.Response('', 404);
    // Startup arms sync even while the native blocker is visible. Keep its real SQLite I/O
    // outside fake time, as mount() does, and drain it after disposal before closing the DB.
    await tester.runAsync(() => tester.pumpWidget(MaterialApp(
        home: ValenceApp(
            valence: runtime,
            log: log.call,
            dispatch: (raw, nonce) async =>
                throw StateError('must not dispatch')))));
    addTearDown(() async {
      await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
      await io(tester);
    });
    await io(tester);
    expect(find.text('Update required'), findsOneWidget);
    expect(webview.controllers, isEmpty);
    expect(runtime.state.toJson(), before);
  });

  /// Blocks mid-session, leaving the blocking screen up and the server closed.
  Future<String> blockMidSession(WidgetTester tester) async {
    await mount(tester, pending: true);
    final origin = runtime.server!.origin;
    final policy = await tester
        .runAsync(() => signBundle(key, seq: 50, overrides: {'minHost': 2}));
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) return http.Response('{"seq":50,"rollout":100}', 200);
      if (request.url.path.endsWith('/50.json')) return http.Response.bytes(policy!.bytes, 200);
      if (request.url.path.endsWith('/50.json.sig')) return http.Response(policy!.signature, 200);
      return http.Response('', 404);
    };
    connectivity.add(['none']);
    await io(tester);
    connectivity.add(['wifi']);
    await waitFor(
        tester, () => runtime.updater.storeUpdateRequired, 'mandatory policy');
    expect(find.text('Update required'), findsOneWidget);
    return origin;
  }

  Future<String> probe(WidgetTester tester, String origin) async =>
      await tester.runAsync(() async {
        try {
          await http.get(Uri.parse('$origin/'));
          return 'answered';
        } on Object {
          return 'closed';
        }
      }) ??
      'closed';

  testWidgets('a block survives a background and resume with no server rebound',
      (tester) async {
    final origin = await blockMidSession(tester);
    // iOS reclaims listening sockets during a suspend, so the resume rebinds a server whose liveness
    // probe fails — and a *deliberately* closed one that is still referenced looks identical. Without
    // `unbound()` the resume put the bundle and the `/_host/` routes back on 127.0.0.1, on the kept
    // nonce, behind the blocking screen (§2.5).
    await lifecycle(tester, AppLifecycleState.paused);
    await lifecycle(tester, AppLifecycleState.resumed);
    await io(tester);
    expect(runtime.server, isNull);
    expect(runtime.manifest, isNull);
    expect(await probe(tester, origin), 'closed');
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byKey(const ValueKey('stub-webview')), findsNothing);
  });

  testWidgets('overlapping withdrawal checks start the page once',
      (tester) async {
    await blockMidSession(tester);
    final withdrawal = await tester.runAsync(() => signBundle(key, seq: 60));
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) return http.Response('{"seq":60,"rollout":100}', 200);
      if (request.url.path.endsWith('/60.json')) return http.Response.bytes(withdrawal!.bytes, 200);
      if (request.url.path.endsWith('/60.json.sig')) return http.Response(withdrawal!.signature, 200);
      final blob = withdrawal!.blobs[request.url.path.split('/').last];
      return blob == null
          ? http.Response('', 404)
          : http.Response.bytes(blob, 200);
    };
    // Two "Check again" taps without awaiting the first check. Both used to capture `wasBlocked = true`
    // and both run the whole transition: a second `activateForUiStart` reads the first one's own
    // `serving` as a previous crash and spends a §2.4 strike, and a second server, ticker and
    // connectivity subscription are bound with the first of each leaked.
    await tester.runAsync(() => tester.tap(find.text('Check again')));
    await tester.runAsync(() => tester.tap(find.text('Check again')));
    await waitFor(
        tester,
        () =>
            !runtime.updater.storeUpdateRequired &&
            webview.controllers.length == 2 &&
            webview.controllers.last.loads.isNotEmpty,
        'signed withdrawal');
    await io(tester);
    expect(find.text('Update required'), findsNothing);
    expect(webview.controllers, hasLength(2));
    expect(runtime.state.trialFails, 0);
    expect(runtime.state.trial, trial.seq);
  });

  testWidgets(
      'foreground reconnect replaces offline with verified pending without reloading',
      (tester) async {
    await mount(tester);
    await io(tester);
    final controller = webview.controller;
    controller.navigation.finished(controller.loads.last.toString());
    final status = runtime.bundleStatus();
    expect(status.reason, ValenceBundleReason.offline);
    final before = pointerRequests();
    connectivity.add(['none']);
    await io(tester);
    expect(pointerRequests(), before);
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    respond = (request) async {
      if (request.url.path.endsWith('/manifests/20.json')) await gate.future;
      return serveTrial(request);
    };
    connectivity.add(['none', 'wifi']);
    await io(tester);
    expect(pointerRequests(), before + 1);
    expect(runtime.state.pending, isNull);
    gate.complete();
    await waitForPending(tester);
    final after = runtime.bundleStatus();
    expect(pointerRequests(), before + 1);
    expect(after.reason, ValenceBundleReason.ready);
    expect(after.checkedAt, greaterThan(status.checkedAt!));
    expect(after.pending, trial.seq);
    expect(runtime.manifest!.seq, builtin.seq);
    expect(runtime.state.trial, isNull);
    expect(controller.loads, hasLength(1));
    expect(controller.scripts.where((s) => s.contains('bundle.updateReady')),
        hasLength(1));
  });

  testWidgets(
      'explicit checks report incompatible offers without pending or apply',
      (tester) async {
    await mount(tester);
    await io(tester);
    final controller = webview.controller;
    controller.navigation.finished(controller.loads.last.toString());
    controller.scripts.clear();
    final incompatible = await signBundle(key, seq: 20, requiresBridge: 20);
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) {
        return http.Response('{"seq":20,"rollout":100}', 200);
      }
      if (request.url.path.endsWith('/20.json.sig')) {
        return http.Response(incompatible.signature, 200);
      }
      if (request.url.path.endsWith('/20.json')) {
        return http.Response.bytes(incompatible.bytes, 200);
      }
      return http.Response('', 404);
    };
    final before = pointerRequests();
    await tester.runAsync(() => Future.wait([
          runtime.checkBundleUpdate(),
          runtime.checkBundleUpdate(),
        ]));
    await io(tester);
    expect(pointerRequests(), before + 1);
    expect(runtime.bundleStatus().reason, ValenceBundleReason.needsStoreUpdate);
    expect(runtime.bundleStatus().requiredBridge, 20);
    expect(runtime.state.pending, isNull);
    expect(runtime.state.trial, isNull);
    expect(controller.loads, hasLength(1));
    final events =
        controller.scripts.where((s) => s.contains('bundle.checked'));
    expect(events, hasLength(1));
    expect(events.single, contains('needsStoreUpdate'));
    expect(events.single, contains('requiredBridge'));
    expect(controller.scripts.where((s) => s.contains('bundle.updateReady')),
        isEmpty);
  });

  testWidgets('explicit checks enforce a signed mid-session store block',
      (tester) async {
    await mount(tester);
    await io(tester);
    final policy = await signBundle(key, seq: 20, overrides: {'minHost': 20});
    respond = (request) async {
      if (request.url.path.endsWith('/channels/production.json')) {
        return http.Response('{"seq":20,"rollout":100}', 200);
      }
      if (request.url.path.endsWith('/20.json.sig')) {

        return http.Response(policy.signature, 200);

      }
      if (request.url.path.endsWith('/20.json')) {

        return http.Response.bytes(policy.bytes, 200);

      }
      return http.Response('', 404);
    };
    await tester.runAsync(() => runtime.checkBundleUpdate());
    await tester.pump();
    expect(find.text('Update required'), findsOneWidget);
    expect(runtime.server, isNull);
    expect(runtime.state.serving, isNull);
    expect(runtime.state.trialFails, 0);
  });

  testWidgets('live handovers coalesce concurrent update checks',
      (tester) async {
    await mount(tester);
    await io(tester);
    final before = pointerRequests();
    final gate = Completer<http.Response>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(http.Response('', 404));
    });
    respond = (request) async => request.url.host == 'ota.test'
        ? gate.future
        : http.Response('{"rows":[],"max":0,"more":false}', 200);
    connectivity.add(['mobile']);
    await io(tester);
    expect(pointerRequests(), before + 1);
    connectivity.add(['wifi']);
    await io(tester);
    expect(pointerRequests(), before + 1);
    gate.complete(http.Response('{"seq":10,"rollout":100}', 200));
    await io(tester);
    expect(runtime.bundleStatus().reason, ValenceBundleReason.uptodate);
    // Even without an offline edge, a later live report retries a completed check.
    connectivity.add(['mobile']);
    await io(tester);
    expect(pointerRequests(), before + 2);
  });

  testWidgets(
      'background reconnect syncs but leaves the update check to resume',
      (tester) async {
    await mount(tester);
    final controller = webview.controller;
    controller.navigation.finished(controller.loads.last.toString());
    // Reconnect must start after startup releases its lease, not race a busy sync.
    await waitFor(
        tester,
        () => controller.scripts.any((s) => s.contains('sync.done')),
        'startup sync completion');
    await lifecycle(tester, AppLifecycleState.paused);
    final before = pointerRequests();
    final syncBefore =
        requests.where((url) => url.contains('sync.test')).length;
    connectivity.add(['none']);
    connectivity.add(['wifi']);
    await waitFor(
        tester,
        () =>
            requests.where((url) => url.contains('sync.test')).length >
            syncBefore,
        'background reconnect sync request');
    expect(runtime.appState().online, isTrue);
    expect(pointerRequests(), before);
    expect(requests.where((url) => url.contains('sync.test')).length,
        greaterThan(syncBefore));
    respond = serveTrial;
    await lifecycle(tester, AppLifecycleState.resumed);
    await waitForPending(tester);
    expect(pointerRequests(), before + 1);
    expect(runtime.state.pending, trial.seq);
  });

  testWidgets(
      'reconnect still rejects an invalid signature without publishing pending',
      (tester) async {
    await mount(tester);
    await io(tester);
    respond = (request) => serveTrial(request, validSignature: false);
    webview.controller.navigation
        .finished(webview.controller.loads.last.toString());
    connectivity.add(['wifi']);
    await io(tester);
    expect(runtime.bundleStatus().reason, ValenceBundleReason.rejected);
    expect(runtime.state.pending, isNull);
    expect(runtime.manifest!.seq, builtin.seq);
    expect(webview.controller.loads, hasLength(1));
    expect(
        webview.controller.scripts
            .where((s) => s.contains('bundle.updateReady')),
        isEmpty);
  });

  testWidgets(
      'a launch destination pre-empts the restored route and keeps the draft',
      (tester) async {
    // The whole §4.8/§6.3 collision: the OS reclaimed the task while the user was on one screen, and
    // they came back by tapping something that names another. Restoring the first one would put a
    // stale third destination on screen in front of a page whose §6.3 arbiter can only see two.
    //
    // `prepareRestoration` is called rather than the widget tree restarted, because an in-process
    // restart is not the launch under test: `ValenceApp.dispose` closes the link mailbox, which a real
    // cold start refills in `Valence.open` before the first frame. This is the host's own call, with
    // the host's own objects, at the point the cold start makes it. The load it feeds is the startup
    // `loadRequest` above and the device row in §8.
    await mount(tester);
    await io(tester);
    final origin = runtime.server!.origin;
    webview.controller.navigation
        .urlChanged(UrlChange(url: '$origin/day/2026-11-13'));
    runtime.stateSave({'draft': 'half-written'});
    expect(runtime.restoration.route, '/day/2026-11-13');

    runtime.links.receive('myapp://app/day/2026-11-07');
    expect(runtime.launchDestination, 'link');
    await tester
        .runAsync(() => runtime.prepareRestoration(runtime.manifest!.seq));

    expect(runtime.restoration.route, '/',
        reason: 'the tap is the destination the user chose; the saved route is '
            'a stale third answer the page cannot arbitrate');
    expect(runtime.stateRestore(), {'draft': 'half-written'},
        reason: "the route is pre-empted; the draft is the user's own work");
    expect(runtime.links.hasPending, isTrue,
        reason: 'the host reads the mailbox and never consumes it');
    expect(
        log.lines.where((l) =>
            l.startsWith('restoration: a link launch destination pre-empts')),
        hasLength(1));

    // The model is what the host navigates to, so a reload after the pre-emption goes to the root page
    // and not to the route that was pre-empted.
    await tester.runAsync(
        () async => webview.controller.navigation.resourceError(contentProcessGone));
    await io(tester);
    expect(webview.controller.loads.last.toString(), '$origin/');
  });

  testWidgets('a start that carries no launch tap still restores its route',
      (tester) async {
    await mount(tester);
    await io(tester);
    final origin = runtime.server!.origin;
    webview.controller.navigation
        .urlChanged(UrlChange(url: '$origin/day/2026-11-13'));
    expect(runtime.launchDestination, isNull);
    await tester
        .runAsync(() => runtime.prepareRestoration(runtime.manifest!.seq));
    expect(runtime.restoration.route, '/day/2026-11-13',
        reason: 'R7 is unchanged for the launch it was written for');
    expect(log.lines.where((l) => l.contains('launch destination pre-empts')),
        isEmpty);
    await io(tester);
  });

  testWidgets('URL changes record only safe local restoration routes',
      (tester) async {
    await mount(tester);
    await io(tester);
    final origin = runtime.server!.origin;
    webview.controller.navigation
        .urlChanged(UrlChange(url: '$origin/shelf/fern?q=green#care'));
    expect(runtime.restoration.route, '/shelf/fern?q=green#care');
    for (final url in [
      'https://evil.invalid/',
      '$origin/_host/alive',
      '$origin/x%00y'
    ]) {
      webview.controller.navigation.urlChanged(UrlChange(url: url));
      expect(runtime.restoration.route, '/shelf/fern?q=green#care');
    }
  });

  testWidgets(
      'an account switch invalidates an awaiting background route capture',
      (tester) async {
    await mount(tester);
    await tester.runAsync(() => runtime.authSetToken('jwt-a', account: 'a'));
    final controller = webview.controller;
    controller.currentUrlGate = Completer<String?>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(() => runtime.authSetToken('jwt-b', account: 'b'));
    controller.currentUrlGate!
        .complete('${runtime.server!.origin}/shelf/a?draft=private');
    await io(tester);
    expect(runtime.restoration.route, '/');
    expect(runtime.stateRestore(), isNull);
  });

  testWidgets(
      'I-61: resume during startup changes state but starts no work or event',
      (tester) async {
    await mount(tester, blocked: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(runtime.server, isNotNull,
        reason: 'startup is held after binding, before triggers');
    await lifecycle(tester, AppLifecycleState.paused);
    expect(runtime.appState().lifecycle, ValenceLifecycle.background);
    await lifecycle(tester, AppLifecycleState.resumed);
    await io(tester);
    expect(runtime.appState().lifecycle, ValenceLifecycle.foreground);
    expect(requests, isEmpty);
    expect(log.lines, contains(contains('this resume does nothing')));
    webview.configureGate!.complete();
    await drain(tester);
    // A loaded WebView does not mean the asynchronous SQLite lease has finished.
    // Wait for the observed triggers instead of assuming a fixed delay is enough under load.
    for (var i = 0;
        i < 1000 && !requests.any((r) => r.contains('sync.test'));
        i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    final controller = webview.controller;
    controller.navigation.finished(controller.loads.last.toString());
    expect(controller.scripts.where((s) => s.contains('app.resumed')), isEmpty);
    expect(requests.where((r) => r.contains('/channels/')), isNotEmpty);
    expect(requests.where((r) => r.contains('sync.test')), isNotEmpty);
    expect(controller.loads, hasLength(1));
    expect(runtime.state.trialFails, 0);
    expect(find.byKey(const ValueKey('stub-webview')), findsOneWidget);
  });

  testWidgets(
      'navigation locks origin, host documents and every off-origin subframe',
      (tester) async {
    await mount(tester);
    final controller = webview.controller;
    final origin = runtime.server!.origin;
    Future<NavigationDecision> navigate(String url, bool main) async =>
        controller.navigation
            .request(NavigationRequest(url: url, isMainFrame: main));
    for (final main in [true, false]) {
      expect(await navigate('$origin/route?q=one#two', main),
          NavigationDecision.navigate);
      for (final path in [
        '/_host/media/abc',
        '/%5fhost/media/abc',
        '//_host/media/abc'
      ]) {
        expect(await navigate('$origin$path', main), NavigationDecision.prevent,
            reason: path);
      }
      for (final url in [
        'https://outside.test/a',
        'http://127.0.0.1:1/',
        'http://localhost:${runtime.server!.port}/',
        'javascript:alert(1)',
        'file:///tmp/page.html'
      ]) {
        expect(await navigate(url, main), NavigationDecision.prevent,
            reason: url);
      }
    }
    await io(tester);
    expect(launches, ['https://outside.test/a'],
        reason: 'only allowed main-frame external URLs launch');
  });

  testWidgets('back uses web history before asking the OS to close the app',
      (tester) async {
    await mount(tester);
    webview.controller.hasHistory = true;
    await tester.binding.handlePopRoute();
    await io(tester);
    expect(webview.controller.backCount, 1);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    webview.controller.hasHistory = false;
    await tester.binding.handlePopRoute();
    await io(tester);
    expect(webview.controller.backCount, 1);
    expect(platformCalls.where((call) => call == 'SystemNavigator.pop'),
        hasLength(1));
  });

  testWidgets('JS channel passes the live nonce and sends an escaped reply',
      (tester) async {
    await mount(tester);
    final controller = webview.controller;
    expect(controller.javaScriptMode, JavaScriptMode.unrestricted);
    expect(controller.channel.name, 'Valence');
    controller.channel.onMessageReceived(
        const JavaScriptMessage(message: '{"m":"app.info"}'));
    await tester.pump();
    expect(messages, [('{"m":"app.info"}', runtime.server!.nonce)]);
    expect(controller.scripts.last,
        bridgeReplyScript('{"id":"test","ok":true,"r":null}'));
    await io(tester);
  });

  testWidgets(
      'one-shot events flush once; lifecycle state is re-derived; reload buffers again',
      (tester) async {
    await mount(tester);
    await io(tester);
    final controller = webview.controller;
    runtime.emit('one-shot');
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.paused);
    expect(runtime.appState().lifecycle, ValenceLifecycle.background);
    expect(controller.scripts, isEmpty);
    controller.navigation.finished(controller.loads.last.toString());
    expect(controller.scripts.where((s) => s == 'one-shot'), hasLength(1));
    expect(
        controller.scripts.where((s) => s.contains('app.lifecycle')), isEmpty);
    controller.navigation.finished(controller.loads.last.toString());
    expect(controller.scripts.where((s) => s == 'one-shot'), hasLength(1));
    final before = controller.scripts.length;
    await lifecycle(tester, AppLifecycleState.resumed);
    await io(tester);
    expect(
        controller.scripts
            .skip(before)
            .where((s) => s.contains('app.lifecycle')),
        hasLength(1));
    expect(
        controller.scripts.skip(before).where((s) => s.contains('app.resumed')),
        hasLength(1));
    await tester.runAsync(() async =>
        controller.navigation.started(controller.loads.last.toString()));
    runtime.emit('after-reload');
    expect(controller.scripts, isNot(contains('after-reload')));
    controller.navigation.finished(controller.loads.last.toString());
    expect(controller.scripts, contains('after-reload'));
  });

  testWidgets('ready commits only the served trial and cancels its timeout',
      (tester) async {
    await mount(tester, pending: true);
    expect(runtime.state.trial, trial.seq);
    await tester.runAsync(() async =>
        webview.controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(runtime.appReady);
    expect(runtime.state.current, trial.seq);
    expect(runtime.state.trial, isNull);
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    expect(runtime.state.trialFails, 0);
    expect(webview.controller.loads, hasLength(1));
    expect(log.lines.where((line) => line.startsWith('ready: timed out')),
        isEmpty);
  });

  testWidgets(
      'trial timeout ignores background time, counts once and reloads current without retrying',
      (tester) async {
    await mount(tester, pending: true);
    final controller = webview.controller;
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    await lifecycle(tester, AppLifecycleState.paused);
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    expect(runtime.state.trialFails, 0);
    expect(runtime.state.serving, trial.seq);
    await lifecycle(tester, AppLifecycleState.resumed);
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await io(tester);
    expect(runtime.state.trialFails, 1, reason: '${log.lines}');
    expect(runtime.state.trial, trial.seq,
        reason: 'the next UI start owns the retry');
    expect(runtime.state.serving, isNull,
        reason: 'serving is the trial marker, not the current seq');
    expect(runtime.manifest!.seq, builtin.seq);
    expect(controller.loads, hasLength(2));
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(runtime.appReady);
    await tester.pump(const Duration(seconds: 5));
    expect(runtime.state.current, builtin.seq,
        reason: 'late ready from fallback cannot commit trial');
    expect(runtime.state.trialFails, 1);
    expect(controller.loads, hasLength(2));
  });

  testWidgets(
      'a ready() between an applyUpdate swap and the new document commits nothing',
      (tester) async {
    // The state identifies the trial by *seq*, and `applyUpdate` sets it while the document that called
    // it is still on screen and still dispatching -- a swap sets the state and the manifest, then awaits
    // the load. A second `ready()` from that outgoing page (an SPA re-mounting its root starts no page,
    // which is one way to send one) matches every seq check and would otherwise commit a bundle that has
    // never rendered: no trial left, no strike to spend, and no rollback if it white-screens. The ready
    // timer cannot answer this, because it is still armed for the trial being replaced.
    await mount(tester, pending: true);
    final controller = webview.controller;
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    expect(runtime.state.serving, trial.seq);

    // A second bundle, promoted mid-session by the page, as `bundle.updateReady` invites.
    final next = await signBundle(key, seq: 30);
    next.writeTo(
        manifestsDir: Directory('${runtime.dir.path}/manifests'),
        casDir: Directory('${runtime.dir.path}/cas'));
    runtime.state.pending = next.seq;
    await tester.runAsync(runtime.applyUpdate);
    expect(runtime.state.trial, next.seq);
    expect(runtime.state.serving, next.seq,
        reason: 'promoted and served, but no document has started on it');
    expect(controller.loads, hasLength(2),
        reason: 'the swap asked for one: ${log.lines}');

    // The outgoing page speaks. Every seq check passes; only "does this document belong to it" does not.
    await tester.runAsync(runtime.appReady);
    expect(runtime.state.current, builtin.seq,
        reason: 'seq 30 never rendered, so it cannot be committed: ${log.lines}');
    expect(runtime.state.trial, next.seq, reason: 'it is still on trial');
    expect(runtime.state.trialFails, 0, reason: 'and it has spent no strike');
    expect(
        log.lines.where((l) => l.contains('predates its swap')), hasLength(1),
        reason: '${log.lines}');

    // Once its own document starts, the same call commits normally.
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(runtime.appReady);
    expect(runtime.state.current, next.seq, reason: '${log.lines}');
    expect(runtime.state.trial, isNull);
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await io(tester);
  });

  testWidgets(
      'a rollback refuses the given-up page cache writes until its replacement starts',
      (tester) async {
    await mount(tester, pending: true);
    final controller = webview.controller;
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(() => runtime.dataCache('days', 'a', {'n': 1}));
    expect(await tester.runAsync(() => runtime.dataGet('days', 'a')), isNotNull);

    // The ready window expires, so the trial is given up on, its overlays are dropped and `current` is
    // reloaded -- but no document has started on it yet, and the given-up page is still on screen and
    // still dispatching. This is the window §5.5.1's refusal exists for.
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await io(tester);
    expect(runtime.state.trialFails, 1, reason: '${log.lines}');
    expect(controller.loads, hasLength(2),
        reason: 'current was reloaded, but no page has started on it');
    await tester.runAsync(() async {
      Object? thrown;
      try {
        await runtime.dataCache('days', 'b', {'n': 2});
      } on Object catch (e) {
        thrown = e;
      }
      expect(
          thrown,
          isA<BridgeError>()
              .having((e) => e.code, 'code', BridgeErrorCode.denied),
          reason: '${log.lines}');
    });

    // The document the rollback's own swap asked for is what reopens it.
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(() => runtime.dataCache('days', 'c', {'n': 3}));
    expect(await tester.runAsync(() => runtime.dataGet('days', 'c')), {'n': 3});
    expect(await tester.runAsync(() => runtime.dataGet('days', 'a')), isNull,
        reason: 'the trial took its overlays with it');
    expect(await tester.runAsync(() => runtime.dataGet('days', 'b')), isNull,
        reason: 'and the write it attempted mid-rollback never landed');
  });

  testWidgets(
      'a rollback whose swap throws leaves the cache closed, and the given-up '
      'page cannot reopen it by navigating itself', (tester) async {
    await mount(tester, pending: true);
    final controller = webview.controller;
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(() => runtime.dataCache('days', 'a', {'n': 1}));

    // Take the swap's target away: `current`'s manifest is gone from disk and the built-in asset is
    // unreadable, so §2.4 step 4 has nothing left to serve and throws. §5.5.1 says a launch that
    // throws leaves the cache closed, which is why `_onReadyTimeout` has no `finally`.
    File('${runtime.dir.path}/manifests/${builtin.seq}.json').deleteSync();
    messenger.setMockMessageHandler('flutter/assets', (_) async => null);

    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await io(tester);
    expect(runtime.state.trialFails, 1, reason: '${log.lines}');
    expect(
        log.lines.where((l) =>
            l.contains('rollback: serving current') &&
            l.contains('data.cache stays closed')),
        hasLength(1),
        reason: 'the swap threw and said so: ${log.lines}');
    expect(controller.loads, hasLength(1),
        reason: 'a swap that throws loads no page');

    Future<Object?> refused(String key) => tester.runAsync<Object?>(() async {
          try {
            await runtime.dataCache('days', key, {'n': 2});
            return null;
          } on Object catch (e) {
            return e;
          }
        });
    final denied = isA<BridgeError>()
        .having((e) => e.code, 'code', BridgeErrorCode.denied);

    expect(await refused('b'), denied,
        reason: 'the cache stays closed after a failed swap: ${log.lines}');

    // The given-up page navigates itself -- `location.replace('/login')`, one plausible reason a page
    // never calls `app.ready()`. That is a page start and it is not the one a swap asked for, so it
    // must not hand the page this refusal protects against an open cache.
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    expect(await refused('c'), denied,
        reason: 'a self-navigation is not the swap\'s own document: '
            '${log.lines}');
    expect(await tester.runAsync(() => runtime.dataGet('days', 'b')), isNull);
    expect(await tester.runAsync(() => runtime.dataGet('days', 'c')), isNull);
  });

  testWidgets('current pages never arm a failure timer or commit a null trial',
      (tester) async {
    await mount(tester);
    await tester.runAsync(() async =>
        webview.controller.navigation.started(runtime.server!.origin));
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await io(tester);
    await tester.runAsync(runtime.appReady);
    expect(runtime.state.current, builtin.seq);
    expect(runtime.state.trial, isNull);
    expect(runtime.state.trialFails, 0);
    expect(runtime.state.bad, isEmpty);
    expect(runtime.state.previous, isNull,
        reason: 'current ready must not recommit the builtin');
    expect(log.lines.where((line) => line.startsWith('ready: timed out')),
        isEmpty);
    expect(webview.controller.loads, hasLength(1));
  });

  testWidgets(
      'a dead content process reloads the same route and counts no trial failure',
      (tester) async {
    await mount(tester, pending: true);
    final controller = webview.controller;
    expect(runtime.state.serving, trial.seq);
    await tester.runAsync(() async =>
        controller.navigation.started('${runtime.server!.origin}/notes'));
    await tester.runAsync(
        () async => controller.navigation.resourceError(contentProcessGone));
    await io(tester);
    expect(controller.loads, hasLength(2));
    expect(controller.loads.last.toString(), '${runtime.server!.origin}/notes',
        reason: 'the same bundle, at the route the user was on');
    expect(runtime.manifest!.seq, trial.seq,
        reason: 'the device killed the renderer, so the trial stays on screen');
    // The ticker armed for the page that died must not fire: its timeout would spend a §2.4 strike.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await io(tester);
    expect(runtime.state.trialFails, 0, reason: '${log.lines}');
    expect(runtime.state.serving, trial.seq);
    expect(log.lines.where((line) => line.startsWith('ready: timed out')),
        isEmpty);
  });

  testWidgets(
      'a renderer recovery in the background arms the trial window but does not run it',
      (tester) async {
    await mount(tester, pending: true);
    final controller = webview.controller;
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    // Backgrounded *first*: the pause transition that stops the ready clock has already happened, so
    // nothing is left to stop a clock the recovery page starts.
    await lifecycle(tester, AppLifecycleState.paused);
    await io(tester);
    await tester.runAsync(
        () async => controller.navigation.resourceError(contentProcessGone));
    await io(tester);
    expect(controller.loads, hasLength(2));
    // The recovery page starts while the app is still in the background.
    await tester.runAsync(() async =>
        controller.navigation.started('${runtime.server!.origin}/'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await io(tester);
    expect(runtime.state.trialFails, 0, reason: '${log.lines}');
    expect(runtime.state.serving, trial.seq,
        reason: 'background seconds are not the §2.4 window, so no strike is spent');
    // Resuming is what starts it, and the window then runs in full.
    await lifecycle(tester, AppLifecycleState.resumed);
    await io(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await io(tester);
    expect(runtime.state.trialFails, 1, reason: '${log.lines}');
  });

  testWidgets(
      'a resume that reclaims the port reloads a page that is not there',
      (tester) async {
    await mount(tester);
    final controller = webview.controller;
    await tester.runAsync(
        () async => controller.navigation.started(runtime.server!.origin));
    controller.navigation.finished(runtime.server!.origin);
    // iOS can reclaim the listening socket and kill the content process in the same suspend, so the
    // renderer-loss reload runs against a port the host does not own yet.
    await lifecycle(tester, AppLifecycleState.paused);
    await tester.runAsync(() => runtime.server!.close());
    await tester.runAsync(
        () async => controller.navigation.resourceError(contentProcessGone));
    await io(tester);
    expect(controller.loads, hasLength(2));
    await lifecycle(tester, AppLifecycleState.resumed);
    await waitFor(
        tester,
        () => log.lines.any((line) => line.contains('with no page loaded')),
        'the rebind reported a reload');
    expect(controller.loads, hasLength(3),
        reason:
            'the rebound socket gets the page back instead of leaving it dead');
    expect(
        controller.loads.last.toString(), startsWith(runtime.server!.origin));
  });

  testWidgets(
      'a content process that keeps dying stops being reloaded and frees the trial',
      (tester) async {
    await mount(tester, pending: true);
    final controller = webview.controller;
    expect(runtime.state.serving, trial.seq);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () async => controller.navigation.resourceError(contentProcessGone));
      await io(tester);
    }
    expect(controller.loads, hasLength(4),
        reason: 'the start-up load plus three recoveries, then no more');
    expect(
        log.lines.where((line) => line.contains('died again after 3 reloads')),
        hasLength(1));
    expect(find.byKey(const ValueKey('stub-webview')), findsNothing,
        reason:
            'the error view replaces the WebView, and the controller with it');
    // §2.4 step 2 reads `serving == trial` as "the process died while serving a trial". A device that
    // ran out of memory must not be that, or two evictions put a healthy release in `bad` for ever.
    expect(runtime.state.serving, isNull);
    expect(runtime.state.trial, trial.seq,
        reason: 'the next UI start retries it');
    expect(runtime.state.trialFails, 0);
    final reread = ValenceState.load(File('${runtime.dir.path}/state.json'));
    expect(reread.serving, isNull,
        reason: 'and it is persisted, not just in memory');
    expect(reread.trial, trial.seq);
  });

  testWidgets(
      'disposal stops triggers, closes the server and keeps the database usable',
      (tester) async {
    await mount(tester, pending: true);
    await io(tester);
    await tester.runAsync(() async =>
        webview.controller.navigation.started(runtime.server!.origin));
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await io(tester);
    final count = requests.length;
    await lifecycle(tester, AppLifecycleState.paused);
    await lifecycle(tester, AppLifecycleState.resumed);
    connectivity.add(['wifi']);
    // Both the real ready ticker (1s) and update ticker (5s) must have had time to fire.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5200)));
    await io(tester);
    expect(requests.length, count);
    expect(runtime.state.trialFails, 0);
    expect(await tester.runAsync(() => runtime.store.db.rawQuery('SELECT 1')), [
      {'1': 1}
    ]);
    await tester.runAsync(() async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 200);
      try {
        await expectLater(client.getUrl(Uri.parse(runtime.server!.origin)),
            throwsA(isA<SocketException>()));
      } finally {
        client.close(force: true);
      }
    });
  });
}
