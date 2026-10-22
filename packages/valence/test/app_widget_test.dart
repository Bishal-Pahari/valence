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
  late List<String> launches;
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
    launches = [];
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
    await io(tester);
    final controller = webview.controller;
    controller.navigation.finished(controller.loads.last.toString());
    expect(controller.scripts.where((s) => s.contains('app.resumed')), isEmpty);
    expect(requests.where((r) => r.contains('/channels/')), hasLength(1));
    expect(requests.where((r) => r.contains('sync.test')), hasLength(1));
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
    await tester.pump(const Duration(seconds: 20));
    await tester.runAsync(runtime.appReady);
    expect(runtime.state.current, builtin.seq);
    expect(runtime.state.trial, isNull);
    expect(runtime.state.trialFails, 0);
    expect(runtime.state.bad, isEmpty);
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
