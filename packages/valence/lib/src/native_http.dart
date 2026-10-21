import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wire.dart';

/// Text response from the app's own API (contracts §4.5).
final class ValenceHttpResponse {
  /// Creates a bounded response. HTTP error statuses remain ordinary responses.
  const ValenceHttpResponse(this.status, this.headers, this.body);

  /// HTTP status, including unfollowed redirects and errors.
  final int status;

  /// Response headers, excluding cookie-setting headers.
  final Map<String, String> headers;

  /// Strictly decoded UTF-8 text.
  final String body;
}

/// Native HTTP behind the generated strict bridge decoder. No cookies or redirects.
final class ValenceHttp {
  /// [clientFactory] must return a fresh client: every request closes its own client.
  ValenceHttp({
    required this.origins,
    required this.token,
    required this.onUnauthorized,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// Origins compiled into the native host, never taken from an OTA manifest.
  final Set<String> origins;

  /// Read per request, with the same precedence as authenticated sync.
  final Future<String?> Function() token;

  /// Called for a 401 on a request that carried the host token.
  final void Function() onUnauthorized;
  final http.Client Function() _clientFactory;

  /// UTF-8 body limit in each direction.
  static const bodyLimit = 64 * 1024;

  /// Header limit in each direction.
  static const headerLimit = 16 * 1024;

  static final _name = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
  static const _forbidden = {
    'authorization',
    'cookie',
    'cookie2',
    'host',
    'origin',
    'referer',
    'connection',
    'content-length',
    'transfer-encoding',
    'upgrade',
    'te',
    'trailer',
    'expect',
    'accept-encoding',
    'keep-alive',
  };

  /// Performs a bounded text request, returning all HTTP statuses unchanged.
  Future<ValenceHttpResponse> request({
    required String url,
    String? method,
    Object? headers,
    String? body,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const BridgeError(BridgeErrorCode.params,
          'expected an absolute HTTP(S) URL without credentials or fragment');
    }
    // Validate allowlist entries as origins too. A path must never silently grant its whole origin.
    final allowed = origins.any((entry) {
      final u = Uri.tryParse(entry);
      return u != null &&
          {'http', 'https'}.contains(u.scheme) &&
          u.host.isNotEmpty &&
          u.userInfo.isEmpty &&
          (u.path.isEmpty || u.path == '/') &&
          !u.hasQuery &&
          !u.hasFragment &&
          u.origin == uri.origin;
    });
    if (!allowed) {
      throw const BridgeError(BridgeErrorCode.denied,
          'origin is not in the host web.connect allowlist');
    }
    final verb = method ?? 'GET';
    if (!{'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'}
            .contains(verb) ||
        (body != null && {'GET', 'HEAD'}.contains(verb))) {
      throw const BridgeError(
          BridgeErrorCode.params, 'invalid method or body on GET/HEAD');
    }
    final values = <String, String>{};
    if (headers != null) {
      if (headers is! Map<String, Object?>) {
        throw const BridgeError(
            BridgeErrorCode.params, 'headers must be an object of strings');
      }
      for (final e in headers.entries) {
        final name = e.key.toLowerCase();
        if (_name.firstMatch(e.key)?.end != e.key.length ||
            e.value is! String ||
            !(e.value! as String).codeUnits.every((c) => c >= 32 && c <= 126) ||
            values.containsKey(name)) {
          throw const BridgeError(
              BridgeErrorCode.params, 'invalid or duplicate header');
        }
        if (_forbidden.contains(name) ||
            name.startsWith('proxy-') ||
            name.startsWith('sec-')) {
          throw const BridgeError(
              BridgeErrorCode.denied, 'header is controlled by the host');
        }
        values[name] = e.value! as String;
      }
    }
    _checkHeaders(values);
    final bytes = utf8.encode(body ?? '');
    if (bytes.length > bodyLimit) {
      throw const BridgeError(
          BridgeErrorCode.tooLarge, 'request body exceeds 64 KiB');
    }

    http.Client? client;
    var expired = false;
    Future<ValenceHttpResponse> send() async {
      final bearer = await token();
      // Token lookup can finish after the deadline. Never start a late request.
      if (expired) {
        throw const BridgeError(
            BridgeErrorCode.internal, 'HTTP deadline exceeded');
      }
      if (bearer != null && bearer.isNotEmpty) {
        values['authorization'] = 'Bearer $bearer';
      }
      _checkHeaders(values);
      final connection = _clientFactory();
      client = connection;
      final req = http.Request(verb, uri)..followRedirects = false;
      req.bodyBytes = bytes;
      req.headers.addAll(values);
      final response = await connection.send(req);
      if (response.statusCode == 401 && values.containsKey('authorization')) {
        onUnauthorized();
      }
      _checkHeaders(response.headers);
      final result = <int>[];
      if ((response.contentLength ?? 0) > bodyLimit) {
        throw const BridgeError(
            BridgeErrorCode.tooLarge, 'response body exceeds 64 KiB');
      }
      await for (final chunk in response.stream) {
        if (result.length + chunk.length > bodyLimit) {
          throw const BridgeError(
              BridgeErrorCode.tooLarge, 'response body exceeds 64 KiB');
        }
        result.addAll(chunk);
      }
      return ValenceHttpResponse(
          response.statusCode,
          {
            for (final e in response.headers.entries)
              if (!{'set-cookie', 'set-cookie2'}.contains(e.key.toLowerCase()))
                e.key: e.value,
          },
          utf8.decode(result));
    }

    try {
      return await send().timeout(const Duration(seconds: 20), onTimeout: () {
        expired = true;
        client?.close();
        throw const BridgeError(
            BridgeErrorCode.internal, 'HTTP deadline exceeded');
      });
    } on BridgeError {
      rethrow;
    } on Object {
      // Transport/decoder exceptions can contain URLs, headers or remote text. Do not reflect them.
      throw const BridgeError(
          BridgeErrorCode.internal, 'HTTP transport or UTF-8 decoding failed');
    } finally {
      expired = true;
      client?.close();
    }
  }

  static void _checkHeaders(Map<String, String> headers) {
    final size = headers.entries.fold<int>(
        0, (n, e) => n + utf8.encode('${e.key}: ${e.value}\r\n').length);
    if (size > headerLimit) {
      throw const BridgeError(
          BridgeErrorCode.tooLarge, 'HTTP headers exceed 16 KiB');
    }
  }
}
