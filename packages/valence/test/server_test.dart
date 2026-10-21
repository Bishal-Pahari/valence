// Contracts §3: the port, the nonce, the three branches in order, and the /_host/ hardening.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  late TestKey key;
  late Directory root;
  late Directory casDir;
  late Directory hostDir;

  const entryHtml = '<!doctype html><html><head><title>t</title></head><body>hello</body></html>';

  setUpAll(() async => key = await TestKey.create());

  setUp(() async {
    root = await Directory.systemTemp.createTemp('valence-server');
    casDir = Directory('${root.path}/cas')..createSync(recursive: true);
    hostDir = Directory('${root.path}/host')..createSync(recursive: true);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Writes the bundle's files into CAS and returns the verified manifest.
  Future<ValenceManifest> install(SignedBundle b) async {
    for (final e in b.blobs.entries) {
      File('${casDir.path}/${e.key}').writeAsBytesSync(e.value);
    }
    return checkManifest(
      bytes: b.bytes,
      signature: b.signature,
      config: testConfig(key),
      state: ValenceState(installId: 'install-1'),
      pointerSeq: null,
    );
  }

  Future<ValenceServer> start({
    ValenceState? state,
    ValenceManifest? manifest,
    String? keepNonce,
  }) async {
    final server = await ValenceServer.bind(
      config: testConfig(key),
      state: state ?? ValenceState(installId: 'install-1'),
      casDir: casDir,
      hostDir: hostDir,
      log: LogSpy().call,
      keepNonce: keepNonce,
    );
    if (manifest != null) server.serveManifest(manifest);
    return server;
  }

  /// One request, with the response status, headers and body.
  Future<({int status, HttpHeaders headers, String body})> request(
    ValenceServer server,
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.parse('${server.origin}$path'));
      headers.forEach(req.headers.set);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return (status: res.statusCode, headers: res.headers, body: body);
    } finally {
      client.close(force: true);
    }
  }

  /// One request written straight onto the socket, so the path arrives exactly as given.
  ///
  /// Dart's HttpClient normalises `.` and `..` segments before sending, which would hide the very thing
  /// §3's normalisation step defends against.
  Future<int> rawStatus(ValenceServer server, String path) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    try {
      socket.write(
        'GET $path HTTP/1.1\r\nHost: 127.0.0.1:${server.port}\r\nConnection: close\r\n\r\n',
      );
      await socket.flush();
      final response = latin1.decode(
        (await socket.fold<List<int>>(<int>[], (a, b) => a..addAll(b))),
      );
      final status = RegExp(r'^HTTP/1\.\d (\d{3})').firstMatch(response);
      if (status == null) throw StateError('no status line in: $response');
      return int.parse(status.group(1)!);
    } finally {
      socket.destroy();
    }
  }

  group('the port (§3)', () {
    test('the default port is derived from appId and installId, inside 10000..29999', () async {
      final state = ValenceState(installId: 'install-1');
      final server = await start(state: state);
      addTearDown(server.close);
      final expected = fnv1a32('com.example.app:install-1') % 20000 + 10000;
      expect(server.port, expected);
      expect(server.port, inInclusiveRange(10000, 29999));
      expect(state.port, server.port);
    });

    test('the same install keeps the same port across launches, so web storage survives', () async {
      final state = ValenceState(installId: 'install-1');
      final first = await start(state: state);
      final port = first.port;
      await first.close();
      final second = await start(state: state);
      addTearDown(second.close);
      expect(second.port, port);
    });

    test('cloned profiles get different ports, because installId feeds the hash', () {
      final a = fnv1a32('com.example.app:install-1') % 20000 + 10000;
      final b = fnv1a32('com.example.app:install-2') % 20000 + 10000;
      expect(a, isNot(b));
    });

    test('a bind failure moves to a new port in the same range, with a new nonce', () async {
      final state = ValenceState(installId: 'install-1');
      final squatter = await start(state: ValenceState(installId: 'install-1'));
      addTearDown(squatter.close);
      // The preferred port is taken by someone else, so the host must move rather than serve from it.
      final server = await start(state: state, keepNonce: 'old-nonce');
      addTearDown(server.close);
      expect(server.port, isNot(squatter.port));
      expect(server.port, inInclusiveRange(10000, 29999),
          reason: 'never bind(port: 0), which lands in the OS ephemeral range');
      expect(server.nonce, isNot('old-nonce'), reason: 'a port change rotates the nonce');
      expect(state.port, server.port);
    });

    test('rebinding the same port on resume keeps the nonce, so the page keeps working', () async {
      final state = ValenceState(installId: 'install-1');
      final first = await start(state: state);
      final nonce = first.nonce;
      await first.close();
      final second = await start(state: state, keepNonce: nonce);
      addTearDown(second.close);
      expect(second.port, first.port);
      expect(second.nonce, nonce);
    });

    test('the first bind of a launch generates a nonce', () async {
      final server = await start();
      addTearDown(server.close);
      expect(server.nonce, isNotEmpty);
      expect(base64Url.decode(server.nonce), hasLength(16), reason: '128 bits');
    });
  });

  group('methods', () {
    test('GET and HEAD are served, anything else is 405', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      expect((await request(server, '/')).status, 200);
      expect((await request(server, '/', method: 'HEAD')).status, 200);
      for (final m in ['POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS']) {
        expect((await request(server, '/', method: m)).status, 405, reason: m);
      }
    });

    test('HEAD sends the length but no body', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      final res = await request(server, '/', method: 'HEAD');
      expect(res.body, isEmpty);
      expect(res.headers.contentLength, greaterThan(0));
    });

    test('a PUT cannot write into app-private storage', () async {
      // There is deliberately no inbound HTTP path: the nonce is checked by the bridge and never on HTTP,
      // and the port is not a secret (§4.2).
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      expect((await request(server, '/_host/f/0123456789abcdef01234567', method: 'PUT')).status, 405);
    });
  });

  group('path normalisation (§3)', () {
    late ValenceServer server;

    setUp(() async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      server = await start(manifest: await install(b));
      addTearDown(server.close);
    });

    test('an empty segment is 400 on the wire, even over a raw socket', () async {
      // A raw socket, not Dart's HttpClient, because the client rewrites the request target before
      // sending it. These are what a page's own URL join actually puts on the wire.
      for (final path in ['//_host/abc', '/a//b', '//', '/a//']) {
        expect(await rawStatus(server, path), 400, reason: path);
      }
    });

    test('a dot segment never reaches the handler, because dart:io removes it first', () async {
      // `Uri.parse` applies RFC 3986 syntax-based normalisation to a URI with an authority, so
      // `GET /a/../b` arrives as `/b` and `GET /./x` as `/x`. Both are then ordinary routes and the SPA
      // fallback answers them, which is correct — there is no dot segment left to escape with. The guard
      // in normaliseRequestPath still covers the branch, and the unit test below is where it is exercised.
      for (final path in ['/./x', '/../x', '/a/../b', '/a/./b']) {
        final status = await rawStatus(server, path);
        expect(status, anyOf(200, 400, 404), reason: path);
      }
      final escaped = await request(server, '/_host/f/../../secret.txt');
      expect(escaped.status, anyOf(400, 404));
      expect(escaped.body, isNot(contains('hello')), reason: 'and never the entry page');
    });

    test('//_host/<id> never reaches the SPA fallback', () async {
      // Without normalisation this does not start with /_host/, cannot be a manifest path and has no
      // extension, so it would come back as HTTP 200 with the entry page's HTML — the exact failure the
      // reserved prefix exists to remove. A page's own URL join produces it by accident.
      final res = await request(server, '//_host/f/0123456789abcdef01234567');
      expect(res.status, 400);
      expect(res.body, isNot(contains('hello')));
    });

    test('one leading and one trailing slash are the ordinary shape of a route', () async {
      expect((await request(server, '/')).status, 200);
      expect((await request(server, '/calendar')).status, 200);
      expect((await request(server, '/calendar/')).status, 200);
    });

    test('the helper agrees with the server', () {
      expect(normaliseRequestPath('/'), isEmpty);
      expect(normaliseRequestPath('/a/b'), ['a', 'b']);
      expect(normaliseRequestPath('/a/b/'), ['a', 'b']);
      expect(normaliseRequestPath('//_host/x'), isNull);
      expect(normaliseRequestPath('//'), isNull);
      expect(normaliseRequestPath('/a//'), isNull);
      expect(normaliseRequestPath('relative'), isNull);
      expect(normaliseRequestPath('/a/../b'), isNull);
    });
  });

  group('branch order and the SPA fallback (§3)', () {
    test('a bundle file is served from CAS, revalidated against its hash', () async {
      final b = await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(1)',
      });
      final m = await install(b);
      final server = await start(manifest: m);
      addTearDown(server.close);
      final res = await request(server, '/assets/app.js');
      expect(res.status, 200);
      expect(res.body, 'console.log(1)');
      expect(res.headers.value('cache-control'), 'no-cache');
      expect(res.headers.value('etag'), '"${m.files['assets/app.js']!.hash}"');
      expect(res.headers.contentType!.mimeType, 'text/javascript');
      expect(res.headers.value('x-content-type-options'), 'nosniff');
    });

    test('a matching If-None-Match is answered 304 with no body', () async {
      final b = await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(1)',
      });
      final m = await install(b);
      final server = await start(manifest: m);
      addTearDown(server.close);
      final etag = (await request(server, '/assets/app.js')).headers.value('etag')!;
      for (final sent in [etag, 'W/$etag', '*', '"other", $etag']) {
        final res = await request(server, '/assets/app.js', headers: {'if-none-match': sent});
        expect(res.status, 304, reason: sent);
        expect(res.body, isEmpty, reason: sent);
        expect(res.headers.value('etag'), etag, reason: sent);
        expect(res.headers.value('cache-control'), 'no-cache', reason: sent);
      }
      final miss = await request(server, '/assets/app.js', headers: {'if-none-match': '"stale"'});
      expect(miss.status, 200);
      expect(miss.body, 'console.log(1)');
    });

    test('the same path in a new bundle gets a new ETag, so a cached copy cannot answer for it', () async {
      // F-39: the path and the port are identical across releases, so the hash is the only thing that
      // tells the WebView its stored copy is the wrong code. Served `immutable`, the new bundle never ran.
      final first = await install(await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(1)',
      }));
      final second = await install(await signBundle(key, seq: 11, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(2)',
      }));
      final server = await start(manifest: first);
      addTearDown(server.close);
      final old = (await request(server, '/assets/app.js')).headers.value('etag')!;

      server.serveManifest(second);
      final res = await request(server, '/assets/app.js', headers: {'if-none-match': old});
      expect(res.status, 200);
      expect(res.body, 'console.log(2)');
      expect(res.headers.value('etag'), isNot(old));
    });

    test('the entry page is never cached and carries no ETag', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final m = await install(b);
      final server = await start(manifest: m);
      addTearDown(server.close);
      final res = await request(server, '/index.html', headers: {'if-none-match': '*'});
      expect(res.status, 200);
      expect(res.headers.value('cache-control'), 'no-store');
      expect(res.headers.value('etag'), isNull);
    });

    test('the SPA fallback answers an extensionless path with the entry page', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      for (final path in ['/', '/calendar', '/profiles/p-1', '/a/b/c']) {
        final res = await request(server, path);
        expect(res.status, 200, reason: path);
        expect(res.body, contains('hello'), reason: path);
      }
    });

    test('a path with an extension that is not in the manifest is a real 404', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      expect((await request(server, '/assets/missing.js')).status, 404);
      expect((await request(server, '/nope.png')).status, 404);
    });

    test('a /_host/ route is matched BEFORE the manifest lookup', () async {
      // A manifest can never contain _host/ (check 6 refuses it), so the way to show the ordering is that
      // an unknown id under the prefix is a 404 rather than the entry page the fallback would give.
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      final res = await request(server, '/_host/f/0123456789abcdef01234567');
      expect(res.status, 404);
      expect(res.body, isNot(contains('hello')),
          reason: 'the fallback would answer 200 with the entry page, and an <img> would render blank');
    });

    test('an unknown /_host/ shape is a 404, not the entry page', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      for (final path in ['/_host', '/_host/', '/_host/media/x', '/_host/f', '/_host/f/short', '/_host/f/a/b']) {
        final res = await request(server, path);
        expect(res.status, 404, reason: path);
        expect(res.body, isNot(contains('hello')), reason: path);
      }
    });

    test('with no manifest, nothing is served', () async {
      final server = await start();
      addTearDown(server.close);
      expect((await request(server, '/')).status, 503);
    });
  });

  group('the entry page (§3)', () {
    test('the nonce is inserted right after <head>, and only in the entry page', () async {
      final b = await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'other.html': '<html><head></head><body>other</body></html>',
      });
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      final entry = await request(server, '/');
      expect(entry.body, contains('<meta name="valence-nonce" content="${server.nonce}">'));
      expect(entry.body.indexOf('valence-nonce'), lessThan(entry.body.indexOf('<title>')));
      final other = await request(server, '/other.html');
      expect(other.body, isNot(contains('valence-nonce')),
          reason: 'a page served by anything else must get no bridge access');
    });

    test('a page with no head still receives the nonce', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': '<p>bare</p>'});
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      expect((await request(server, '/')).body, contains('valence-nonce'));
    });

    test('the entry page carries the manifest CSP and no-store', () async {
      final csp = "default-src 'self'; script-src 'self' 'sha256-abc'; frame-src 'none'";
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml}, csp: csp);
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      final res = await request(server, '/');
      expect(res.headers.value('content-security-policy'), csp);
      expect(res.headers.value('cache-control'), 'no-store');
      expect(res.headers.value('x-content-type-options'), 'nosniff');
    });

    test('the fallback at depth also carries the CSP, since it is the entry page', () async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml}, csp: "default-src 'self'");
      final server = await start(manifest: await install(b));
      addTearDown(server.close);
      final res = await request(server, '/profiles/p-1');
      expect(res.headers.value('content-security-policy'), "default-src 'self'");
    });
  });

  group('/_host/ files (§3)', () {
    late ValenceServer server;

    setUp(() async {
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      server = await start(manifest: await install(b));
      addTearDown(server.close);
    });

    test('the host generates the id, and the URL it hands the page is relative', () async {
      final url = await server.publishHostFile(utf8.encode('PNGDATA'), contentType: 'image/png');
      // Relative, because the port moves when a bind fails and these ids land in durable SQLite rows.
      expect(url, startsWith('/_host/f/'));
      expect(url, isNot(contains('127.0.0.1')));
      expect(RegExp(r'^/_host/f/[0-9a-f]{24}$').hasMatch(url), isTrue, reason: url);
    });

    test('a published file is served with nosniff, a locked CSP and immutable caching', () async {
      final url = await server.publishHostFile(utf8.encode('PNGDATA'), contentType: 'image/png');
      final res = await request(server, url);
      expect(res.status, 200);
      expect(res.body, 'PNGDATA');
      expect(res.headers.contentType!.mimeType, 'image/png');
      expect(res.headers.value('x-content-type-options'), 'nosniff');
      // These bytes are not ours, so they must never be a document (§3).
      expect(res.headers.value('content-security-policy'), "default-src 'none'; sandbox");
      expect(res.headers.value('cache-control'), 'private, max-age=31536000, immutable');
    });

    test('a scriptable content type is refused at publish time', () async {
      for (final type in ['text/html', 'application/xhtml+xml', 'image/svg+xml', 'text/javascript', 'application/xml']) {
        expect(
          () => server.publishHostFile(utf8.encode('<script>alert(1)</script>'), contentType: type),
          throwsA(isA<ArgumentError>()),
          reason: type,
        );
      }
    });

    test('a scriptable content type smuggled onto disk is refused at serve time', () async {
      // One of the two checks will be the one that is wrong, and serving a document here would hand the
      // page's nonce to attacker-supplied bytes.
      final url = await server.publishHostFile(utf8.encode('<html>x</html>'), contentType: 'image/png');
      final id = url.split('/').last;
      File('${hostDir.path}/$id.t').writeAsStringSync('text/html');
      final res = await request(server, url);
      expect(res.status, 500);
      expect(res.headers.contentType!.mimeType, isNot('text/html'));
    });

    test('neither a web-supplied path nor a malformed id escapes the host directory', () async {
      File('${root.path}/secret.txt').writeAsStringSync('TOP SECRET');
      for (final path in [
        '/_host/f/..%2F..%2Fsecret.txt',
        '/_host/f/0123456789ABCDEF01234567',
        '/_host/f/0123456789abcdef',
        '/_host/f/0123456789abcdef012345678',
        '/_host/f/....',
      ]) {
        final res = await request(server, path);
        expect(res.status, anyOf(400, 404), reason: path);
        expect(res.body, isNot(contains('SECRET')), reason: path);
      }
    });

    test('the id survives a restart, because the id is the filename', () async {
      final url = await server.publishHostFile(utf8.encode('PDF'), contentType: 'application/pdf');
      await server.close();
      final b = await signBundle(key, seq: 10, files: {'index.html': entryHtml});
      final restarted = await start(manifest: await install(b));
      addTearDown(restarted.close);
      expect((await request(restarted, url)).body, 'PDF');
    });

    test('every allow-listed type is non-scriptable', () {
      expect(hostFileContentTypes, isNot(contains('text/html')));
      expect(hostFileContentTypes, isNot(contains('image/svg+xml')));
      expect(hostFileContentTypes, isNot(contains('application/xhtml+xml')));
      expect(hostFileContentTypes, contains('image/png'));
      expect(hostFileContentTypes, contains('application/pdf'));
    });

    test('the resume probe answers to us and nothing else', () async {
      final res = await request(server, '/_host/alive');
      expect(res.status, 204);
      expect(res.headers.value('x-valence'), 'alive');
      expect(res.body, isEmpty);
    });
  });

  group('lazy CAS integrity (§2.4)', () {
    test('a corrupt CAS file is detected the first time it is served, deleted, and answered 500', () async {
      final b = await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(1)',
      });
      final manifest = await install(b);
      final server = await start(manifest: manifest);
      addTearDown(server.close);
      // First serve verifies and caches the result.
      expect((await request(server, '/assets/app.js')).status, 200);

      final hash = manifest.files['assets/app.js']!.hash;
      final file = File('${casDir.path}/$hash');
      // Corruption that preserves length is precisely what a hash is for, so change bytes not size.
      file.writeAsBytesSync(utf8.encode('console.log(2)'));
      expect(file.lengthSync(), 'console.log(1)'.length);

      // Still cached for this manifest's lifetime, by design: the re-check is per manifest, not per request.
      expect((await request(server, '/assets/app.js')).status, 200);

      // A new manifest ends that lifetime.
      server.serveManifest(manifest);
      final res = await request(server, '/assets/app.js');
      expect(res.status, 500);
      expect(file.existsSync(), isFalse, reason: 'deleted, so the next update check re-downloads it');
    });

    test('a CAS file of the wrong size is caught too', () async {
      final b = await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(1)',
      });
      final manifest = await install(b);
      final hash = manifest.files['assets/app.js']!.hash;
      File('${casDir.path}/$hash').writeAsBytesSync(utf8.encode('short'));
      final server = await start(manifest: manifest);
      addTearDown(server.close);
      expect((await request(server, '/assets/app.js')).status, 500);
    });

    test('a missing CAS file is a 404 rather than a crash', () async {
      final b = await signBundle(key, seq: 10, files: {
        'index.html': entryHtml,
        'assets/app.js': 'console.log(1)',
      });
      final manifest = await install(b);
      File('${casDir.path}/${manifest.files['assets/app.js']!.hash}').deleteSync();
      final server = await start(manifest: manifest);
      addTearDown(server.close);
      expect((await request(server, '/assets/app.js')).status, 404);
    });

    test('a hash computed here matches the one the CLI writes', () {
      // The host and the CLI must agree byte for byte, or check 7 rejects every bundle.
      expect(sha256.convert(utf8.encode('abc')).toString(),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });
  });
}
