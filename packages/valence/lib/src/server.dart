import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'config.dart';
import 'dev.dart';
import 'log.dart';
import 'manifest.dart';
import 'state.dart';

/// The id shape the host generates for a `/_host/` file. Validated on the way back in.
final _hostFileId = RegExp(r'^[0-9a-f]{24}$');

/// Content types a WebView will not execute. A `/_host/` response may only carry one of these.
///
/// These bytes are not ours — they come from a camera, a download or a remote server — and they are served
/// on the bundle's own origin. A `JavaScriptChannel` is per-WebView, not per-document, so a `text/html` or
/// `image/svg+xml` response navigated to directly could `fetch('/')`, read the nonce out of the entry
/// page's `<meta>` and use the whole bridge (§3).
const hostFileContentTypes = <String>{
  'application/octet-stream',
  'application/pdf',
  'audio/aac',
  'audio/mp4',
  'audio/mpeg',
  'audio/wav',
  'image/avif',
  'image/gif',
  'image/heic',
  'image/jpeg',
  'image/png',
  'image/webp',
  'text/plain',
  'video/mp4',
  'video/quicktime',
  'video/webm',
};

const _extTypes = <String, String>{
  '.avif': 'image/avif',
  '.css': 'text/css; charset=utf-8',
  '.gif': 'image/gif',
  '.htm': 'text/html; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
  '.otf': 'font/otf',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8',
  '.wasm': 'application/wasm',
  '.webm': 'video/webm',
  '.webmanifest': 'application/manifest+json',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.xml': 'application/xml; charset=utf-8',
};

/// Splits a request path into its segments, or returns null when it must be answered with 400.
///
/// **Normalise once, before choosing a branch.** Without this step the reserved prefix is bypassable:
/// `//_host/media/<id>` does not start with `/_host/`, cannot be a manifest path, and has no file
/// extension, so it falls through to the SPA fallback and returns the entry page with HTTP 200. A page's
/// own URL join produces it by accident (§3).
///
/// One leading slash and at most one trailing slash are the ordinary shape of a route, so they are
/// stripped rather than rejected. Anything else empty, `.` or `..` is a 400.
List<String>? normaliseRequestPath(String path) {
  if (!path.startsWith('/')) return null;
  // Checked on the raw path, before any slash is stripped: otherwise "//" collapses to the root and an
  // empty segment has slipped through the one guard that exists to catch it.
  if (path.contains('//')) return null;
  var rest = path.substring(1);
  if (rest.endsWith('/')) rest = rest.substring(0, rest.length - 1);
  if (rest.isEmpty) return const [];
  final segments = rest.split('/');
  for (final s in segments) {
    if (s.isEmpty || s == '.' || s == '..') return null;
  }
  return segments;
}

/// The loopback `HttpServer` that the WebView loads from (contracts §3).
///
/// It owns the per-install port, the per-launch nonce, the three serving branches in their contractual
/// order, and the lazy integrity re-check of content-addressed files.
final class ValenceServer {
  ValenceServer._(this._server, this.port, this.nonce, this._casDir, this._hostDir, this._log, this._dev);

  /// Binds the server, preferring the port already in [state].
  ///
  /// A bind failure means another process owns that port, so the host moves to a **new random port in the
  /// same 10000 to 30000 range** and rotates the nonce — never `bind(port: 0)`, which returns an OS
  /// ephemeral port and lands exactly in the range this scheme avoids. [state] is updated but not saved;
  /// the caller saves it.
  static Future<ValenceServer> bind({
    required ValenceConfig config,
    required ValenceState state,
    required Directory casDir,
    required Directory hostDir,
    ValenceLogger log = defaultValenceLogger,
    String? keepNonce,
  }) async {
    final dev = kDebugMode && _devUrl != '' ? ValenceDevProxy(_devUrl) : null;
    final rng = Random.secure();
    final preferred = state.port ?? (fnv1a32('${config.appId}:${state.installId}') % 20000 + 10000);
    HttpServer? server;
    var port = preferred;
    var rotated = false;
    for (var attempt = 0; attempt < 12 && server == null; attempt++) {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: false);
      } on SocketException catch (e) {
        log('server: port $port is not bindable ($e); picking another in 10000..29999');
        port = rng.nextInt(20000) + 10000;
        rotated = true;
      }
    }
    if (server == null) {
      if (kDebugMode) dev?.close();
      throw StateError('valence: could not bind a loopback port in 10000..29999 after 12 attempts');
    }
    // The nonce rotates only together with a port change, and every port change reloads the page. A
    // same-port rebind on resume keeps it, because the loaded page still holds it.
    final nonce = (rotated || keepNonce == null || state.port != port)
        ? base64Url.encode(List<int>.generate(16, (_) => rng.nextInt(256)))
        : keepNonce;
    state.port = port;
    final s = ValenceServer._(server, port, nonce, casDir, hostDir, log, dev);
    server.listen(s._handle, onError: (Object e) => log('server: $e'));
    return s;
  }

  // The URL and constructor disappear in profile/release AOT builds.
  static const _devUrl = kDebugMode ? String.fromEnvironment('VALENCE_DEV_URL') : '';
  final ValenceDevProxy? _dev;

  final HttpServer _server;

  /// The bound loopback port. Not a secret: a loopback scan finds it in about a second. The nonce is what
  /// actually protects the bridge.
  final int port;

  /// The per-launch 128-bit nonce, served in the entry page and required on every bridge message.
  final String nonce;

  final Directory _casDir;
  final Directory _hostDir;
  final ValenceLogger _log;

  ValenceManifest? _manifest;
  final Set<String> _verified = {};
  final Set<String> _corrupt = {};

  /// Hashes of the active manifest that failed their integrity check on first serve and were deleted.
  ///
  /// The server can only delete and 500; re-fetching is the updater's job, and it has to be asked, because
  /// §2.3 step 1 stops before step 6 for a bundle that is already `current` (§2.4).
  Set<String> get corruptHashes => Set.unmodifiable(_corrupt);

  /// The origin the WebView loads, and the only main-frame navigation the host permits.
  String get origin => 'http://127.0.0.1:$port';

  /// The manifest currently being served.
  ValenceManifest? get manifest => _manifest;

  /// Points the server at a bundle.
  ///
  /// Clears the integrity cache, because "verified for this manifest's lifetime" ends here.
  void serveManifest(ValenceManifest m) {
    _manifest = m;
    _verified.clear();
    _corrupt.clear();
  }

  /// Stops listening.
  ///
  /// Applying an update and reverting a failed trial both swap the manifest, and a swap restarts the
  /// server — so **close before binding again**, or the host collides with its own listening socket, moves
  /// to a new port and rotates the nonce in the middle of a fallback (§3).
  Future<void> close() async {
    if (kDebugMode) _dev?.close();
    await _server.close(force: true);
  }

  /// Writes [bytes] under `/_host/` and returns the **relative** URL to hand the page.
  ///
  /// Relative on purpose: the port moves when a bind fails and when a resume cannot reclaim the socket,
  /// and these ids end up in durable SQLite rows, so an absolute `http://127.0.0.1:<port>/…` is dead after
  /// the next rebind and stays dead.
  ///
  /// The **host** generates the id; a web-supplied path is never joined to a directory. [contentType] must
  /// be one of [hostFileContentTypes].
  Future<String> publishHostFile(List<int> bytes, {required String contentType}) async {
    if (!hostFileContentTypes.contains(contentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'not in the /_host/ allow-list of non-scriptable types (contracts §3)',
      );
    }
    final rng = Random.secure();
    final id = List<int>.generate(12, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _hostDir.create(recursive: true);
    // The id is the filename, so the mapping is durable: a page that stored the URL in a SQLite row still
    // resolves it after a restart, when an in-memory registry would have forgotten it.
    await File('${_hostDir.path}${Platform.pathSeparator}$id').writeAsBytes(bytes, flush: true);
    await File('${_hostDir.path}${Platform.pathSeparator}$id.t').writeAsString(contentType, flush: true);
    return '/_host/f/$id';
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      // GET and HEAD only. There is deliberately no inbound HTTP path: the nonce is checked by the bridge
      // and never on HTTP, and the port is not a secret, so a PUT would let any app on the device write
      // into app-private storage unauthenticated (§4.2).
      if (req.method != 'GET' && req.method != 'HEAD') {
        await _text(req, HttpStatus.methodNotAllowed, 'method not allowed');
        return;
      }
      // requestedUri.path is already percent-decoded by dart:io.
      final segments = normaliseRequestPath(req.requestedUri.path);
      if (segments == null) {
        await _text(req, HttpStatus.badRequest, 'bad path');
        return;
      }
      final path = segments.join('/');

      // Branch 1: the host's own routes, matched *before* the manifest. The order is the contract: the SPA
      // fallback answers any extensionless path, so a host route placed after the manifest lookup comes
      // back as HTTP 200 with the entry page's HTML — a blank <img> and nothing in either log (§3).
      if (segments.isNotEmpty && segments.first == '_host') {
        await _serveHostFile(req, segments);
        return;
      }

      if (kDebugMode && _devUrl != '') {
        await _dev!.handle(req, nonce);
        return;
      }

      final m = _manifest;
      if (m == null) {
        await _text(req, HttpStatus.serviceUnavailable, 'no bundle is being served yet');
        return;
      }

      // Branch 2: a bundle file, mapped to a hash through the active manifest.
      final file = m.files[path];
      if (file != null) {
        await _serveBundleFile(req, m, path, file);
        return;
      }

      // Branch 3: the SPA fallback. An extensionless path gets the entry page; anything else is a 404.
      if (_extensionOf(path) == null) {
        final entry = m.files[m.entry];
        if (entry == null) {
          await _text(req, HttpStatus.internalServerError, 'manifest entry is missing');
          return;
        }
        await _serveBundleFile(req, m, m.entry, entry);
        return;
      }
      await _text(req, HttpStatus.notFound, 'not found');
    } on Object catch (e, st) {
      _log('server: unhandled $e\n$st');
      try {
        await _text(req, HttpStatus.internalServerError, 'internal error');
      } on Object {
        // the socket is already gone
      }
    }
  }

  Future<void> _serveHostFile(HttpRequest req, List<String> segments) async {
    // The resume probe: iOS can reclaim a listening socket while the app is suspended, so the host needs
    // to know whether the port still answers *to us* rather than to whoever took it (§3). It reveals
    // nothing, because the nonce is only ever in the entry page.
    if (segments.length == 2 && segments[1] == 'alive') {
      final res = req.response
        ..statusCode = HttpStatus.noContent
        ..headers.set('x-valence', 'alive')
        ..headers.set('X-Content-Type-Options', 'nosniff')
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      await res.close();
      return;
    }
    // /_host/f/<id>, and nothing else. An unknown id is a 404 the caller can act on, never the entry page.
    if (segments.length != 3 || segments[1] != 'f' || !_hostFileId.hasMatch(segments[2])) {
      await _text(req, HttpStatus.notFound, 'not found');
      return;
    }
    final id = segments[2];
    final file = File('${_hostDir.path}${Platform.pathSeparator}$id');
    final typeFile = File('${_hostDir.path}${Platform.pathSeparator}$id.t');
    if (!file.existsSync() || !typeFile.existsSync()) {
      await _text(req, HttpStatus.notFound, 'not found');
      return;
    }
    final contentType = typeFile.readAsStringSync().trim();
    if (!hostFileContentTypes.contains(contentType)) {
      // Refused again at serve time, not only at publish time: one of the two checks will be the one that
      // is wrong, and serving a scriptable document here hands the page's nonce to attacker bytes.
      _log('server: refusing /_host/f/$id, content type "$contentType" is not in the allow-list');
      await _text(req, HttpStatus.internalServerError, 'bad content type');
      return;
    }
    final res = req.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, contentType)
      ..headers.set('X-Content-Type-Options', 'nosniff')
      // These bytes must never be a document, even if the type above is somehow wrong.
      ..headers.set('Content-Security-Policy', "default-src 'none'; sandbox")
      // The id is content-addressed by construction, so the bytes behind it never change.
      ..headers.set(HttpHeaders.cacheControlHeader, 'private, max-age=31536000, immutable');
    await _send(req, res, file.readAsBytesSync());
  }

  Future<void> _serveBundleFile(
    HttpRequest req,
    ValenceManifest m,
    String path,
    ValenceFileEntry entry,
  ) async {
    final file = File('${_casDir.path}${Platform.pathSeparator}${entry.hash}');
    if (!file.existsSync()) {
      _log('server: cas file ${entry.hash} for $path is missing');
      await _text(req, HttpStatus.notFound, 'not found');
      return;
    }

    final isEntry = path == m.entry;
    // The URL of a bundle file is stable across releases — the path comes from the web build and the port
    // survives a resume (§3) — so the *only* thing that distinguishes one release's `assets/index-x.js`
    // from the next one's is the hash behind it. That hash is the validator. Without it a WebView serves
    // the previous bundle's copy of the same URL for a year, the new code never runs, and the trial still
    // ends in `committed` because the old page called `ready()`: the update and its rollback safety net
    // are both defeated, silently (§2.4).
    final etag = '"${entry.hash}"';
    if (!isEntry && _verified.contains(entry.hash) && _ifNoneMatch(req, etag)) {
      final res = req.response
        ..statusCode = HttpStatus.notModified
        ..headers.set(HttpHeaders.etagHeader, etag)
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..headers.set('X-Content-Type-Options', 'nosniff');
      await res.close();
      return;
    }

    var bytes = file.readAsBytesSync();
    // Content-addressed integrity is re-checked **lazily**, the first time this manifest serves this file,
    // and cached for the manifest's lifetime. Nothing re-hashes the store at startup, so a file verified at
    // download time can still rot on disk afterwards, and the only honest place to notice is where the
    // bytes are used. A size comparison is not a substitute: corruption that preserves length is precisely
    // what a hash is for (§2.4).
    if (!_verified.contains(entry.hash)) {
      if (bytes.length != entry.size || sha256.convert(bytes).toString() != entry.hash) {
        _log('server: cas file ${entry.hash} for $path failed its hash or size; deleting it');
        try {
          file.deleteSync();
        } on Object catch (e) {
          _log('server: could not delete the corrupt cas file ${entry.hash}: $e');
        }
        _corrupt.add(entry.hash);
        // 500. The next update check re-fetches it: for a pending bundle through step 6, and for the
        // bundle already being served through the repair pass, which is the only route there is (§2.4).
        await _text(req, HttpStatus.internalServerError, 'corrupt bundle file');
        return;
      }
      _verified.add(entry.hash);
    }

    final res = req.response..statusCode = HttpStatus.ok;
    if (isEntry) {
      bytes = utf8.encode(_withNonce(utf8.decode(bytes), nonce));
      res.headers
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set('Content-Security-Policy', m.csp);
    } else {
      // `no-cache` stores the bytes and revalidates before using them; it is not `no-store`. The WebView
      // keeps its copy and the conditional request that follows costs one loopback round trip and no body.
      res.headers
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..set(HttpHeaders.etagHeader, etag);
    }
    res.headers
      ..set(HttpHeaders.contentTypeHeader, _extTypes[_extensionOf(path) ?? ''] ?? 'application/octet-stream')
      ..set('X-Content-Type-Options', 'nosniff');
    await _send(req, res, bytes);
  }

  Future<void> _send(HttpRequest req, HttpResponse res, List<int> bytes) async {
    res.headers.set(HttpHeaders.contentLengthHeader, '${bytes.length}');
    if (req.method != 'HEAD') res.add(bytes);
    await res.close();
  }

  Future<void> _text(HttpRequest req, int status, String message) async {
    final body = utf8.encode(message);
    final res = req.response
      ..statusCode = status
      ..headers.set(HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8')
      ..headers.set('X-Content-Type-Options', 'nosniff')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    await _send(req, res, body);
  }

  /// True when the request's `If-None-Match` names [etag], so the client's copy is still the right bytes.
  ///
  /// The header is a comma-separated list, each entry optionally weak (`W/"…"`). `*` matches anything that
  /// exists. A request sent before the hash was ever served simply misses and gets the body.
  static bool _ifNoneMatch(HttpRequest req, String etag) {
    // `headers.value` throws when a header arrives twice, and the throw would come back as a 500 for a
    // file the page needs. A browser merges duplicates; anything else on the loopback port need not.
    final sent = req.headers[HttpHeaders.ifNoneMatchHeader];
    if (sent == null) return false;
    for (final raw in sent.expand((v) => v.split(','))) {
      final tag = raw.trim();
      if (tag == '*') return true;
      if ((tag.startsWith('W/') ? tag.substring(2) : tag) == etag) return true;
    }
    return false;
  }

  static String? _extensionOf(String path) {
    final slash = path.lastIndexOf('/');
    final dot = path.lastIndexOf('.');
    if (dot <= slash + 1 || dot == path.length - 1) return null;
    return path.substring(dot).toLowerCase();
  }
}

/// Inserts the per-launch nonce right after `<head>`, so only a page this server produced can reach the
/// bridge. A page served by anything else — another app that grabbed the port — has no nonce and gets
/// `E_DENIED` on every message (§3).
String _withNonce(String html, String nonce) {
  final tag = '<meta name="valence-nonce" content="${const HtmlEscape().convert(nonce)}">';
  final head = RegExp(r'<head[^>]*>', caseSensitive: false).firstMatch(html);
  if (head != null) {
    return html.replaceRange(head.end, head.end, tag);
  }
  // No <head> at all: a WebView synthesises one, and a leading <meta> lands inside it.
  return '$tag$html';
}
