import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Debug-only proxy; every runtime reference is behind a compile-time guard.
final class ValenceDevProxy {
  ValenceDevProxy(String url) : upstream = Uri.parse(url) {
    if (!{'http', 'https'}.contains(upstream.scheme) ||
        upstream.host.isEmpty ||
        upstream.userInfo.isNotEmpty ||
        upstream.hasQuery ||
        upstream.hasFragment ||
        (upstream.path.isNotEmpty && upstream.path != '/')) {
      throw ArgumentError(
          'VALENCE_DEV_URL must be an HTTP(S) origin without credentials');
    }
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  }

  final Uri upstream;
  late final HttpClient _client;
  final Set<WebSocket> _sockets = {};

  void close() {
    _client.close(force: true);
    for (final socket in _sockets) {
      unawaited(socket.close());
    }
  }

  Future<WebSocket> _connect(Uri target, List<String> protocols) async {
    final request = await _client.getUrl(target);
    request.followRedirects = false;
    final rng = Random.secure();
    final key = base64Encode(List.generate(16, (_) => rng.nextInt(256)));
    request.headers
      ..set('connection', 'Upgrade')
      ..set('upgrade', 'websocket')
      ..set('sec-websocket-version', '13')
      ..set('sec-websocket-key', key);
    if (protocols.isNotEmpty) request.headers.set('sec-websocket-protocol', protocols.join(', '));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final expected = base64Encode(sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11')).bytes);
    final protocol = response.headers.value('sec-websocket-protocol');
    if (response.statusCode != HttpStatus.switchingProtocols ||
        response.headers.value('upgrade')?.toLowerCase() != 'websocket' ||
        response.headers.value('sec-websocket-accept') != expected ||
        (protocol != null && !protocols.contains(protocol))) {
      await response.drain<void>();
      throw const WebSocketException('development WebSocket handshake refused');
    }
    return WebSocket.fromUpgradedSocket(await response.detachSocket(), serverSide: false, protocol: protocol);
  }

  Future<void> handle(HttpRequest req, String nonce) async {
    if (req.method != 'GET' && req.method != 'HEAD') {
      req.response.statusCode = HttpStatus.methodNotAllowed;
      await req.response.close();
      return;
    }
    final target = upstream.replace(
        path: req.uri.path, query: req.uri.hasQuery ? req.uri.query : null);
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final remote = await _connect(target,
          req.headers.value('sec-websocket-protocol')?.split(',').map((p) => p.trim()).toList() ?? []);
      final WebSocket local;
      try {
        local = await WebSocketTransformer.upgrade(req,
            protocolSelector: (protocols) =>
                remote.protocol != null && protocols.contains(remote.protocol)
                    ? remote.protocol
                    : null);
      } on Object {
        await remote.close();
        rethrow;
      }
      _sockets.addAll([local, remote]);
      void finish() {
        _sockets.removeAll([local, remote]);
        unawaited(local.close());
        unawaited(remote.close());
      }

      local.listen(remote.add, onDone: finish, onError: (Object _) => finish());
      remote.listen(local.add, onDone: finish, onError: (Object _) => finish());
      return;
    }
    // No inbound cookies, Authorization, Origin or native bearer token are forwarded.
    final request = await _client.openUrl(req.method, target);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.drain<void>();
      req.response.statusCode = HttpStatus.badGateway;
      await req.response.close();
      return;
    }
    req.response.statusCode = response.statusCode;
    req.response.headers
      ..set('cache-control', 'no-store')
      ..set('content-security-policy',
          "frame-src 'none'; frame-ancestors 'none'; object-src 'none'; worker-src 'none'")
      ..set('x-content-type-options', 'nosniff');
    final type = response.headers.contentType;
    if (type != null) req.response.headers.contentType = type;
    if (req.method == 'HEAD') {
      await response.drain<void>();
    } else if (type?.mimeType == 'text/html') {
      // ponytail: development HTML is capped at 4 MiB; production uses signed CAS files.
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 4 * 1024 * 1024) {
          throw const FormatException('dev HTML exceeds 4 MiB');
        }
      }
      final tag =
          '<meta name="valence-nonce" content="${const HtmlEscape().convert(nonce)}">';
      final html = utf8.decode(bytes);
      final head = RegExp(r'<head\b[^>]*>', caseSensitive: false).firstMatch(html);
      final doctype = RegExp(r'^\s*<!doctype\b[^>]*>', caseSensitive: false).firstMatch(html);
      final at = head?.end ?? doctype?.end ?? 0;
      req.response.add(utf8.encode(html.replaceRange(at, at, tag)));
    } else {
      await req.response.addStream(response);
    }
    await req.response.close();
  }
}
