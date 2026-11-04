import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cookies.dart';
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
    this.online,
    this.cookies,
    this.maxBodyBytes = bodyLimit,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new {
    RangeError.checkValueInInterval(
        maxBodyBytes, 1, maxMessageBytes, 'maxBodyBytes');
  }

  /// Origins compiled into the native host, never taken from an OTA manifest.
  /// HTTP grants cleartext token trust in release builds too; use HTTPS remotely.
  /// Android network security XML is not a boundary for native Dart HTTP.
  final Set<String> origins;

  /// Read per request, with the same precedence as authenticated sync.
  final Future<String?> Function() token;

  /// Called for a 401 on a request that carried the host token.
  final void Function() onUnauthorized;

  /// The host's current connectivity, if it has one: the `app.online` value (§4.6).
  ///
  /// It turns a transport failure into `E_OFFLINE` when the OS says there is no interface at all. That
  /// is the one failure an offline-first page most wants to tell apart, and it is a host-side fact, so
  /// it leaks nothing about the remote. Left null the failure stays `E_INTERNAL`.
  final bool Function()? online;

  /// The optional §4.5.1 jar for one compiled origin. Null, or a jar this build granted nothing to,
  /// leaves every cookie behaviour exactly as it was: no `Cookie` sent, every `Set-Cookie` discarded.
  final ValenceCookies? cookies;
  final http.Client Function() _clientFactory;

  /// Default response and fixed request UTF-8 body limit.
  static const bodyLimit = 64 * 1024;

  /// Compiled decompressed response limit. Never supplied by a page.
  final int maxBodyBytes;

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

  /// Whether the host owns [name] (lowercase), so neither a page nor a §4.5.1 CSRF mirror may set it.
  ///
  /// The mirror is checked against the same predicate the page is, and `codegen` refuses a configured
  /// header that fails it. Both, because the two lists live on independent release trains: a hand-written
  /// config naming `authorization` or `cookie` here would otherwise have the mirror quietly overwrite the
  /// bearer token or the jar's own `Cookie`.
  static bool hostControlled(String name) =>
      _forbidden.contains(name) ||
      name.startsWith('proxy-') ||
      name.startsWith('sec-');

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
          'origin is not in the host http.origins allowlist');
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
        if (hostControlled(name) ||
            // The §4.5.1 mirrored CSRF header is the host's for this build. A page-chosen value would
            // not match the cookie the server is about to compare it with, so the pair would break
            // silently on exactly the endpoints the jar exists to reach.
            name == cookies?.jar?.deniedHeader) {
          throw const BridgeError(
              BridgeErrorCode.denied, 'header is controlled by the host');
        }
        values[name] = e.value! as String;
      }
    }
    _checkHeaders(values);
    final bytes = utf8.encode(body ?? '');
    if (bytes.length > bodyLimit) {
      // Sizes, not just the fact: "paginate or give up?" is the question a cap raises, and it cannot be
      // answered from a bare refusal. A byte count of the app's own payload discloses nothing.
      throw BridgeError(BridgeErrorCode.tooLarge,
          'request body is ${bytes.length} bytes; the limit is $bodyLimit');
    }

    http.Client? client;
    var expired = false;
    // Read before the token, so the whole request — not just the part after the bearer arrives — is
    // attributed to the account that started it. A sign-out or switch any time from here on makes the
    // response's `Set-Cookie` somebody else's credential, and `absorb` drops it (§4.4).
    final jarGeneration = cookies?.generation;
    Future<ValenceHttpResponse> send() async {
      final bearer = await token();
      // Token lookup can finish after the deadline. Never start a late request.
      if (expired) {
        throw const BridgeError(
            BridgeErrorCode.timeout, 'the 20-second HTTP deadline passed');
      }
      if (bearer != null && bearer.isNotEmpty) {
        values['authorization'] = 'Bearer $bearer';
      }
      // §4.5.1, and only for the one origin the jar owns. Read here rather than before the deadline
      // check so a slow secure-storage read cannot start a late request either.
      final jarred = cookies;
      if (jarred != null && jarred.owns(uri)) {
        final cookie = await jarred.header(uri);
        if (expired) {
          throw const BridgeError(
              BridgeErrorCode.timeout, 'the 20-second HTTP deadline passed');
        }
        if (cookie != null) values['cookie'] = cookie;
        final header = jarred.jar?.csrfHeader?.toLowerCase();
        if (header != null && hostControlled(header)) {
          // Unreachable through codegen, which refuses it. A hand-written config gets a loud failure
          // rather than a mirror that silently replaces the bearer token or the jar's own Cookie.
          throw BridgeError(BridgeErrorCode.internal,
              'the configured CSRF header "$header" is controlled by the host');
        }
        final csrf = await jarred.csrfValue(uri);
        // No cookie yet means no header. The server's own 403 is the honest answer, and a browser
        // sending the pair it does not have would do the same.
        if (header != null && csrf != null) values[header] = csrf;
      }
      // The page's own headers were already measured and named a size before this point. This second
      // check includes the bearer token, the `Cookie` header and the mirror, so naming the total would
      // let a page binary-search the byte length of credentials it cannot read (§4.5.1).
      _checkHeaders(values, disclose: false);
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
      // Before the body caps below, on purpose: the headers arrived, so a `Set-Cookie` on a response
      // too large to return is still a cookie the server set, and the next request needs it. Absorbing
      // cannot fail the request — a malformed cookie or unwritable storage is logged, not thrown.
      if (jarred != null && jarred.owns(uri)) {
        await jarred.absorb(
            uri, response.headersSplitValues['set-cookie'] ?? const <String>[],
            atGeneration: jarGeneration);
      }
      final result = <int>[];
      if (verb != 'HEAD' &&
          response.statusCode != 204 &&
          response.statusCode != 304 &&
          // A compressed Content-Length is not the decompressed size we grant.
          (response.headers['content-encoding'] == null ||
              response.headers['content-encoding'] == 'identity') &&
          (response.contentLength ?? 0) > maxBodyBytes) {
        throw BridgeError(
            BridgeErrorCode.tooLarge,
            'response declares ${response.contentLength} bytes; '
            'the limit is $maxBodyBytes');
      }
      await for (final chunk in response.stream) {
        if (result.length + chunk.length > maxBodyBytes) {
          // Reading stopped here, so this is a lower bound and says so. The actual size is unknown and
          // guessing it would be worse than naming the floor the page can plan a `Range` against.
          throw BridgeError(
              BridgeErrorCode.tooLarge,
              'response body is over the limit of $maxBodyBytes bytes '
              '(${result.length + chunk.length} read before stopping)');
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
            BridgeErrorCode.timeout, 'the 20-second HTTP deadline passed');
      });
    } on BridgeError {
      rethrow;
    } on Object {
      // Transport/decoder exceptions can contain URLs, headers or remote text. Do not reflect them.
      // "No network interface" is the host's own fact, though, and it is the one case where the honest
      // UI is silence rather than an apology — so it gets its own code and no remote text either way.
      if (online?.call() == false) {
        throw const BridgeError(
            BridgeErrorCode.offline, 'the device reports no network interface');
      }
      throw const BridgeError(
          BridgeErrorCode.internal, 'HTTP transport or UTF-8 decoding failed');
    } finally {
      expired = true;
      client?.close();
    }
  }

  static void _checkHeaders(Map<String, String> headers,
      {bool disclose = true}) {
    final size = headers.entries.fold<int>(
        0, (n, e) => n + utf8.encode('${e.key}: ${e.value}\r\n').length);
    if (size > headerLimit) {
      throw BridgeError(
          BridgeErrorCode.tooLarge,
          disclose
              ? 'HTTP headers are $size bytes; the limit is $headerLimit'
              : 'the headers the host adds do not fit under the $headerLimit-byte limit '
                  'beside the ones this request supplied');
    }
  }
}
