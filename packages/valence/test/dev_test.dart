import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';
import 'package:valence/src/dev.dart';

// Keep the real upstream handshake, then simulate a downstream socket failure.
class _FailedUpgradeRequest extends Fake implements HttpRequest {
  _FailedUpgradeRequest(this.request);
  final HttpRequest request;
  @override
  String get method => request.method;
  @override
  Uri get uri => request.uri;
  @override
  HttpHeaders get headers => request.headers;
  @override
  HttpResponse get response => _FailedUpgradeResponse(request.response);
}

class _FailedUpgradeResponse extends Fake implements HttpResponse {
  _FailedUpgradeResponse(this.response);
  final HttpResponse response;
  @override
  HttpHeaders get headers => response.headers;
  @override
  set statusCode(int value) => response.statusCode = value;
  @override
  set contentLength(int value) => response.contentLength = value;
  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) async =>
      throw const HttpException('downstream socket failed');
}

void main() {
  test('development accepts only explicit HTTP(S) origins', () {
    for (final url in ['file:///tmp', 'http://u:p@localhost', 'http://localhost/x',
      'http://localhost?x', 'http://localhost#x', '//localhost']) {
      expect(() => ValenceDevProxy(url), throwsArgumentError);
    }
  });

  test('invalid dev URL allocates no HTTP client', () {
    var clients = 0;
    HttpOverrides.runZoned(() {
      expect(() => ValenceDevProxy('file:///tmp'), throwsArgumentError);
    }, createHttpClient: (_) {
      clients++;
      throw StateError('unexpected HTTP client allocation');
    });
    expect(clients, 0);
  });

  test('every read of VALENCE_DEV_URL is guarded by kDebugMode (§3.1)', () {
    // R9's requirement is that a release build contains none of this path, and that holds only
    // because each read is a compile-time constant the AOT compiler can fold away. Drop the
    // `kDebugMode` from any one of them and the sentinel URL becomes a live const in the release
    // snapshot with ValenceDevProxy reachable from bind() — while `dart analyze`, every suite here
    // and the root suite all stay green. tool/check-release-dev.mjs proves exclusion against a built
    // APK, but nothing except a person remembering to run it stood between that edit and a shipped
    // dev proxy. This is the cheap half: the guard cannot quietly leave the source.
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run flutter test from the package root');
    const call = "String.fromEnvironment('VALENCE_DEV_URL')";
    var found = 0;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Whitespace collapsed, so the check does not depend on where the formatter broke the line.
      final source = entity.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      for (var i = source.indexOf(call); i >= 0; i = source.indexOf(call, i + 1)) {
        found++;
        final before = source.substring(i < 120 ? 0 : i - 120, i);
        expect(before, contains('kDebugMode'),
            reason: '${entity.path} reads the dev URL unguarded: ...$before$call');
      }
    }
    expect(found, 3,
        reason: 'server.dart, app.dart and runtime.dart each read it once; if that '
            'changed, confirm the new site is guarded and update this count');
  });

  late HttpServer upstream;
  late HttpServer proxy;
  late ValenceDevProxy dev;
  late HttpClient client;
  final seen = <HttpRequest>[];
  late Completer<void> remoteClosed;

  setUp(() async {
    seen.clear();
    remoteClosed = Completer<void>();
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((req) async {
      seen.add(req);
      if (req.uri.path == '/redirect') {
        req.response.statusCode = 302;
        req.response.headers.set('location', 'http://127.0.0.1:1/');
      } else if (WebSocketTransformer.isUpgradeRequest(req)) {
        final socket = await WebSocketTransformer.upgrade(req,
            protocolSelector: (protocols) => protocols.contains('vite-hmr') ? 'vite-hmr' : null);
        socket.listen((message) => socket.add(message), onDone: () {
          if (req.uri.path == '/upgrade-failure') remoteClosed.complete();
        });
        return;
      } else {
        req.response.headers.contentType = req.uri.path == '/module.js'
            ? ContentType('text', 'javascript') : ContentType.html;
        req.response.write('<!doctype html><html><head><script>bootstrap()</script></head><body>dev</body></html>');
      }
      await req.response.close();
    });
    dev = ValenceDevProxy('http://127.0.0.1:${upstream.port}');
    proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    proxy.listen((req) async {
      try {
        await dev.handle(req.uri.path == '/upgrade-failure'
            ? _FailedUpgradeRequest(req) : req, 'launch-secret');
      } on Object {
        req.response.statusCode = 502;
        await req.response.close();
      }
    });
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    dev.close();
    await proxy.close(force: true);
    await upstream.close(force: true);
  });

  Future<HttpClientResponse> get(String path, {String method = 'GET'}) async {
    final req = await client.openUrl(method, Uri.parse('http://127.0.0.1:${proxy.port}$path'));
    req.headers.set('authorization', 'Bearer never-forward');
    req.headers.set('cookie', 'secret=never-forward');
    return req.close();
  }

  test('HTML receives nonce before scripts, no cache, and no frame permission', () async {
    final res = await get('/nested?x=1');
    final html = await res.transform(utf8.decoder).join();
    expect(html, startsWith('<!doctype html>'));
    expect(html.indexOf('valence-nonce'), lessThan(html.indexOf('<script>')));
    expect(html, contains('launch-secret'));
    expect(res.headers.value('cache-control'), 'no-store');
    expect(res.headers.value('content-security-policy'), contains("frame-src 'none'"));
    expect(seen.single.uri.toString(), '/nested?x=1');
    expect(seen.single.headers.value('authorization'), isNull);
    expect(seen.single.headers.value('cookie'), isNull);
  });

  test('modules are unmodified and HEAD has no body', () async {
    final res = await get('/module.js');
    expect(await res.transform(utf8.decoder).join(), isNot(contains('valence-nonce')));
    final head = await get('/', method: 'HEAD');
    expect(await head.fold<int>(0, (n, bytes) => n + bytes.length), 0);
  });

  test('redirects and writes never reach a different server or mutate upstream', () async {
    final redirect = await get('/redirect');
    expect(redirect.statusCode, 502);
    await redirect.drain<void>();
    final write = await get('/', method: 'POST');
    expect(write.statusCode, 405);
    await write.drain<void>();
    expect(seen.length, 1);
  });

  test('HMR messages and negotiated protocol cross the proxy in both directions', () async {
    final socket = await WebSocket.connect('ws://127.0.0.1:${proxy.port}/?token=hmr', protocols: ['vite-hmr']);
    expect(socket.protocol, 'vite-hmr');
    final messages = StreamIterator<Object?>(socket);
    socket.add('hot-update');
    expect(await messages.moveNext().timeout(const Duration(seconds: 3)), isTrue);
    expect(messages.current, 'hot-update');
    socket.add([1, 2, 3]);
    expect(await messages.moveNext().timeout(const Duration(seconds: 3)), isTrue);
    expect(messages.current, [1, 2, 3]);
    await messages.cancel();
    await socket.close();
  });

  test('WebSocket redirects are refused', () async {
    await expectLater(WebSocket.connect('ws://127.0.0.1:${proxy.port}/redirect'), throwsA(isA<WebSocketException>()));
    expect(seen.length, 1);
  });

  test('failed downstream upgrade closes its connected upstream socket', () async {
    await expectLater(WebSocket.connect('ws://127.0.0.1:${proxy.port}/upgrade-failure'),
        throwsA(isA<WebSocketException>()));
    expect(seen.single.uri.path, '/upgrade-failure');
    await remoteClosed.future.timeout(const Duration(seconds: 3));
  });

  test('real host keeps reserved routes native under the compile-time dev define', () async {
    const url = String.fromEnvironment('VALENCE_DEV_URL');
    final root = await Directory.systemTemp.createTemp('valence-dev-host');
    HttpServer? fixed;
    if (url.isNotEmpty) {
      fixed = await HttpServer.bind(InternetAddress.loopbackIPv4, Uri.parse(url).port);
      fixed.listen((req) async {
        req.response.headers.contentType = ContentType.html;
        req.response.write('<script>dev()</script>');
        await req.response.close();
      });
    }
    final host = await ValenceServer.bind(
      config: const ValenceConfig(appId: 'com.example.dev', keyring: {}, bridgeVersion: 1),
      state: ValenceState(installId: 'dev'), casDir: root, hostDir: root, log: (_) {},
    );
    try {
      final alive = await (await client.getUrl(Uri.parse('${host.origin}/_host/alive'))).close();
      expect(alive.headers.value('x-valence'), 'alive');
      await alive.drain<void>();
      final res = await (await client.getUrl(Uri.parse(host.origin))).close();
      final body = await res.transform(utf8.decoder).join();
      expect(res.statusCode, url.isEmpty ? 503 : 200);
      if (url.isNotEmpty) expect(body, contains(host.nonce));
    } finally {
      await host.close();
      await fixed?.close(force: true);
      root.deleteSync(recursive: true);
    }
  });
}
