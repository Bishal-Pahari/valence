import 'dart:convert';
import 'dart:io' show Cookie;

import 'log.dart';
import 'secure.dart';

/// The reserved secure-storage key the persisted half of the jar lives at (contracts §4.4, §4.5.1).
///
/// Inside the reserved `valence.` namespace, so `secure.get` can never read it back — the same property
/// the bearer token has, for the same reason: a page that could read a session cookie could replay it.
const secureCookieJarKey = 'valence.http.cookies';

/// The one origin a store build may opt into a host-held cookie jar for (contracts §4.5.1).
///
/// Compiled from `http.cookieJar` by `valence codegen`; an OTA manifest can never supply it.
final class ValenceCookieJar {
  /// Creates the policy. [origin] must be an exact HTTP(S) origin, also present in `http.origins`.
  const ValenceCookieJar({
    required this.origin,
    this.csrfCookie,
    this.csrfHeader,
  });

  /// The exact origin whose cookies this jar holds. No other origin is ever sent them.
  final String origin;

  /// The cookie whose value is mirrored into [csrfHeader], for a double-submit CSRF pair.
  final String? csrfCookie;

  /// The header [csrfCookie]'s value is written to. The page may not supply it (§4.5.1).
  final String? csrfHeader;

  /// The lowercase header name the page is refused, or null when no pair is configured.
  String? get deniedHeader => csrfHeader?.toLowerCase();
}

/// One stored cookie. [expires] is null for a session cookie, which never reaches secure storage.
final class _Jarred {
  const _Jarred(this.name, this.value, this.path, this.expires);

  final String name;
  final String value;
  final String path;
  final DateTime? expires;

  int get size => utf8.encode('$name=$value').length;
}

/// The §4.5.1 jar: cookies for exactly one compiled origin, invisible to the page.
///
/// Held by the runtime for its lifetime, so the secure-storage read happens once rather than per request.
final class ValenceCookies {
  /// Creates the jar. [now] is injectable so expiry is testable without sleeping.
  ValenceCookies({
    required this.jar,
    required ValenceSecure secure,
    Set<String> origins = const {},
    ValenceLogger log = defaultValenceLogger,
    DateTime Function() now = DateTime.now,
  })  : _secure = secure,
        _log = log,
        _now = now {
    // The same three rules `codegen` enforces, enforced again here. `codegen` and the package are on
    // independent release trains, and a host may write `ValenceConfig` by hand — so a cleartext jar, or
    // one aimed at an origin `http.request` cannot reach, must not simply work. Sealed and logged rather
    // than thrown: a misconfigured jar is not a reason an app cannot start.
    final policy = jar;
    if (policy == null) return;
    final uri = Uri.tryParse(policy.origin);
    final loopback = {'127.0.0.1', 'localhost', '[::1]', '::1'};
    final String? refusal;
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.origin != policy.origin) {
      refusal = 'is not an exact, normalised HTTP(S) origin';
    } else if (uri.scheme == 'http' && !loopback.contains(uri.host)) {
      refusal = 'is cleartext and not loopback, so the jar would replay a credential in the clear';
    } else if (origins.isNotEmpty && !origins.contains(uri.origin)) {
      refusal = 'is not in http.origins, so http.request can never reach it';
    } else {
      refusal = null;
    }
    if (refusal != null) {
      _sealed = true;
      _log('cookies: refusing the configured jar — "${policy.origin}" $refusal; no cookie will be '
          'sent or stored. Fix http.cookieJar and run codegen, which refuses this too');
    }
  }

  /// The compiled policy, or null when this build granted no jar.
  final ValenceCookieJar? jar;

  final ValenceSecure _secure;
  final ValenceLogger _log;
  final DateTime Function() _now;

  /// At most this many cookies, so a chatty server cannot grow the jar without bound.
  static const maxCookies = 16;

  /// At most this many bytes in one `name=value`.
  static const maxCookieBytes = 4096;

  /// At most this many bytes across the whole jar.
  static const maxJarBytes = 8 * 1024;

  final Map<String, _Jarred> _cookies = {};

  /// The one load, memoized as a future rather than a flag: a bool set before the platform read awaits
  /// lets a second concurrent call through on an empty jar, and two bridge messages do dispatch at once.
  Future<void>? _loading;

  /// The origin the persisted cookies were set by, so [revoke] can tell a changed build apart.
  String? _origin;

  /// Set when a revocation could not reach secure storage. Fail closed, never fail startup.
  bool _sealed = false;

  /// Whether the build granted a jar at all.
  bool get enabled => jar != null;

  /// Whether [url]'s origin is the jar's origin. Exact match: scheme, host and effective port.
  ///
  /// False while the jar is sealed: a revocation that could not reach secure storage leaves cookies we
  /// were told to forget, so the jar stops working for the process rather than carrying them.
  bool owns(Uri url) {
    final policy = jar;
    if (policy == null || _sealed) return false;
    // `Uri.origin` throws for a non-HTTP(S) scheme or an empty host. `ValenceHttp` rejects both before
    // it gets here, but this is public on the runtime, and "the jar refused" is the only safe answer to
    // a URL that has no origin to compare.
    if (!{'http', 'https'}.contains(url.scheme) || url.host.isEmpty) return false;
    return url.origin == policy.origin;
  }

  /// Drops every cookie, in memory and in secure storage (§4.4 sign-out, §5.3 switch, §4.5.1 revocation).
  ///
  /// Always runs, even for a build with no jar: that is what makes it a revocation rather than a clear.
  /// Memory first, so a write that fails still leaves this launch carrying nothing.
  Future<void> clear() async {
    _cookies.clear();
    _origin = null;
    _loading = Future.value();
    await _secure.write(secureCookieJarKey, null);
  }

  /// Revokes cookies this build no longer grants, at `Valence.open` and before any request (§4.5.1).
  ///
  /// A store build that dropped `http.cookieJar`, or moved it to another origin, must not leave the old
  /// origin's session cookie sitting at rest in the Keystore — and `_load` alone would never notice,
  /// because a jar the build does not grant is never consulted at all.
  /// This runs on every launch of every app, so it must cost nothing when there is nothing to revoke
  /// and must never fail `Valence.open`: an unreachable Keystore would otherwise stop the app starting
  /// at all, which is a far worse outcome than a jar that declines to work.
  Future<void> revoke() async {
    final policy = jar;
    if (policy == null || _sealed) {
      // A read, and a write only when something is actually there. The overwhelming majority of builds
      // grant no jar, and they should pay neither a Keystore write nor its failure.
      _loading = Future.value();
      if (await _secure.read(secureCookieJarKey) == null) return;
      await _revokeOrSeal();
      return;
    }
    await _load();
    // An envelope with no recorded origin is revoked too, not kept: "I do not know whose these are" is
    // not the same answer as "they are this build's", and an older or future envelope shape would
    // otherwise have its cookies adopted by whatever origin this build happens to configure.
    if (_cookies.isNotEmpty && _origin != policy.origin) {
      _log('cookies: the stored jar is ${_origin == null ? 'of no recorded origin' : 'of $_origin'}, '
          'not ${policy.origin}; clearing ${_cookies.length} cookie(s)');
      await _revokeOrSeal();
    }
  }

  Future<void> _revokeOrSeal() async {
    try {
      await clear();
    } on Object catch (e) {
      // The cookies we were told to forget may still be on disk, so this process sends none of them.
      _sealed = true;
      _cookies.clear();
      _log('cookies: could not revoke the stored jar ($e); the jar is disabled for this launch');
    }
  }

  /// The `Cookie` request header for [url], or null when there is nothing to send.
  Future<String?> header(Uri url) async {
    if (!owns(url)) return null;
    await _load();
    await _expire();
    final send = [
      for (final c in _cookies.values)
        if (_pathMatches(_requestPath(url), c.path)) '${c.name}=${c.value}',
    ];
    return send.isEmpty ? null : send.join('; ');
  }

  /// The value of the configured CSRF cookie for [url], or null when there is no pair or no cookie.
  ///
  /// Path-matched like [header], and that is not pedantry: the mirrored header would otherwise hand the
  /// token's value to a path the server scoped the cookie away from, while the `Cookie` half stayed
  /// behind — a half-pair the server must reject, on a path the page chose.
  Future<String?> csrfValue(Uri url) async {
    final name = jar?.csrfCookie;
    if (name == null || !owns(url)) return null;
    await _load();
    await _expire();
    final cookie = _cookies[name];
    if (cookie == null || !_pathMatches(_requestPath(url), cookie.path)) return null;
    return cookie.value;
  }

  /// Takes `Set-Cookie` values from a response. Nothing here can fail the request (§4.5.1).
  Future<void> absorb(Uri url, Iterable<String> setCookies) async {
    if (!owns(url) || setCookies.isEmpty) return;
    await _load();
    var changed = false;
    for (final raw in setCookies) {
      Cookie parsed;
      try {
        parsed = Cookie.fromSetCookieValue(raw);
      } on Object catch (e) {
        _log('cookies: ignored a malformed Set-Cookie from ${url.origin} ($e)');
        continue;
      }
      // Host-only. A `Domain` that is not exactly this host would let a cookie reach a sibling
      // subdomain the app never configured, which is the one widening a jar must never do.
      final domain = parsed.domain;
      if (domain != null &&
          domain.replaceFirst(RegExp(r'^\.'), '').toLowerCase() !=
              url.host.toLowerCase()) {
        _log('cookies: ignored "${parsed.name}" scoped to Domain=$domain, not ${url.host}');
        continue;
      }
      // The jar's own origin may be cleartext loopback (§4.5.1's carve-out, which the reference example
      // uses), and a `Secure` cookie is a server asking for the opposite of that. Honour the ask.
      if (parsed.secure && url.scheme != 'https') {
        _log('cookies: ignored Secure cookie "${parsed.name}"; ${url.origin} is not HTTPS');
        continue;
      }
      // RFC 6265: Max-Age wins over Expires, and zero or less is a deletion.
      final maxAge = parsed.maxAge;
      final expires = maxAge != null
          ? _now().add(Duration(seconds: maxAge))
          : parsed.expires;
      if (maxAge != null && maxAge <= 0 ||
          (expires != null && !expires.isAfter(_now()))) {
        changed = _cookies.remove(parsed.name) != null || changed;
        continue;
      }
      final next = _Jarred(
          parsed.name, parsed.value, _defaultPath(parsed.path, url), expires);
      if (next.size > maxCookieBytes) {
        _log('cookies: dropped "${next.name}", ${next.size} bytes over the '
            '$maxCookieBytes-byte cookie limit');
        continue;
      }
      final replacing = _cookies[next.name];
      final total = _cookies.values.fold<int>(0, (n, c) => n + c.size) -
          (replacing?.size ?? 0) +
          next.size;
      if (replacing == null && _cookies.length >= maxCookies ||
          total > maxJarBytes) {
        _log('cookies: dropped "${next.name}"; the jar is at its '
            '$maxCookies-cookie / $maxJarBytes-byte limit');
        continue;
      }
      _cookies[next.name] = next;
      changed = true;
    }
    if (changed) await _persist();
  }

  /// Loads the persisted cookies once. A session cookie was never written, so it is simply absent.
  Future<void> _load() => _loading ??= _read();

  Future<void> _read() async {
    final raw = await _secure.read(secureCookieJarKey);
    if (raw == null) return;
    try {
      final stored = jsonDecode(raw);
      if (stored is! Map<String, Object?>) return;
      _origin = stored['origin'] is String ? stored['origin'] as String : null;
      final rows = stored['cookies'];
      if (rows is! List) return;
      var bytes = 0;
      for (final row in rows) {
        if (row is! Map<String, Object?>) continue;
        final name = row['name'];
        final value = row['value'];
        final path = row['path'];
        final expires = row['expires'];
        if (name is! String ||
            value is! String ||
            path is! String ||
            expires is! int) {
          continue;
        }
        final cookie = _Jarred(name, value, path,
            DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true));
        // The same caps the write path enforces. Only this process writes this key, so an over-cap
        // envelope means a restored backup or a future shape — neither of which gets to be unbounded.
        if (cookie.size > maxCookieBytes ||
            _cookies.length >= maxCookies ||
            bytes + cookie.size > maxJarBytes) {
          _log('cookies: dropped stored "$name"; the jar is at its caps');
          continue;
        }
        bytes += cookie.size;
        _cookies[name] = cookie;
      }
      await _expire();
    } on Object catch (e) {
      // Unreadable storage is an empty jar, never a failed request: the server will set a cookie again.
      _log('cookies: could not decode the stored jar ($e); starting empty');
      _cookies.clear();
    }
  }

  /// Persists only the cookies that have an expiry. A session cookie belongs to this process (§4.5.1).
  Future<void> _persist() async {
    final rows = [
      for (final c in _cookies.values)
        if (c.expires != null)
          {
            'name': c.name,
            'value': c.value,
            'path': c.path,
            'expires': c.expires!.toUtc().millisecondsSinceEpoch,
          },
    ];
    try {
      await _secure.write(
          secureCookieJarKey,
          rows.isEmpty
              ? null
              : jsonEncode({'origin': jar?.origin, 'cookies': rows}));
    } on Object catch (e) {
      // The jar still works for this process. Failing the page's request over it would be worse.
      _log('cookies: could not persist the jar ($e); it is in memory only');
    }
  }

  /// Drops expired cookies, and writes that through: an expired credential has no business staying at
  /// rest in the Keystore until the next `Set-Cookie` happens to come along.
  Future<void> _expire() async {
    final now = _now();
    final before = _cookies.length;
    _cookies.removeWhere((_, c) => c.expires != null && !c.expires!.isAfter(now));
    if (_cookies.length != before) await _persist();
  }

  static String _requestPath(Uri url) => url.path.isEmpty ? '/' : url.path;

  /// RFC 6265 §5.1.4: a cookie with no `Path` takes the request's directory.
  static String _defaultPath(String? path, Uri url) {
    if (path != null && path.startsWith('/')) return path;
    final at = url.path.lastIndexOf('/');
    return at <= 0 ? '/' : url.path.substring(0, at);
  }

  /// RFC 6265 §5.1.4 path matching.
  static bool _pathMatches(String requestPath, String cookiePath) {
    if (requestPath == cookiePath) return true;
    if (!requestPath.startsWith(cookiePath)) return false;
    return cookiePath.endsWith('/') ||
        requestPath[cookiePath.length] == '/';
  }
}
