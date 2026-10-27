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
      testConfig(key, writableBuckets: {'shelf'}).copyWith(
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
          reason: 'startup, resume and periodic check');
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
      return http.Response(validSignature ? trial.signature : builtin.signature, 200);
    }
    final blob = trial.blobs[path.split('/').last];
    return blob == null ? http.Response('', 404) : http.Response.bytes(blob, 200);
  }

  int pointerRequests() =>
      requests.where((url) => url.endsWith('/channels/production.json')).length;

  testWidgets('foreground reconnect replaces offline with verified pending without reloading',
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
    respond = serveTrial;
    connectivity.add(['none', 'wifi']);
    await io(tester);
    final after = runtime.bundleStatus();
    expect(pointerRequests(), before + 1);
    expect(after.reason, ValenceBundleReason.ready);
    expect(after.checkedAt, greaterThan(status.checkedAt!));
    expect(after.pending, trial.seq);
    expect(runtime.manifest!.seq, builtin.seq);
    expect(runtime.state.trial, isNull);
    expect(controller.loads, hasLength(1));
    expect(controller.scripts.where((s) => s.contains('bundle.updateReady')), hasLength(1));
  });

  testWidgets('live handovers coalesce concurrent update checks', (tester) async {
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

  testWidgets('background reconnect syncs but leaves the update check to resume',
      (tester) async {
    await mount(tester);
    await io(tester);
    await lifecycle(tester, AppLifecycleState.paused);
    final before = pointerRequests();
    final syncBefore = requests.where((url) => url.contains('sync.test')).length;
    connectivity.add(['none']);
    connectivity.add(['wifi']);
    await io(tester);
    expect(runtime.appState().online, isTrue);
    expect(pointerRequests(), before);
    expect(requests.where((url) => url.contains('sync.test')).length, greaterThan(syncBefore));
    respond = serveTrial;
    await lifecycle(tester, AppLifecycleState.resumed);
    await io(tester);
    expect(pointerRequests(), before + 1);
    expect(runtime.state.pending, trial.seq);
  });

  testWidgets('reconnect still rejects an invalid signature without publishing pending',
      (tester) async {
    await mount(tester);
    await io(tester);
    respond = (request) => serveTrial(request, validSignature: false);
    webview.controller.navigation.finished(webview.controller.loads.last.toString());
    connectivity.add(['wifi']);
    await io(tester);
    expect(runtime.bundleStatus().reason, ValenceBundleReason.rejected);
    expect(runtime.state.pending, isNull);
    expect(runtime.manifest!.seq, builtin.seq);
    expect(webview.controller.loads, hasLength(1));
    expect(webview.controller.scripts.where((s) => s.contains('bundle.updateReady')), isEmpty);
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
