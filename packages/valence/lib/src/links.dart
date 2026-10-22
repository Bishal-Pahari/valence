import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';

/// An accepted external link mapped to a local route (contracts §6.3).
final class ValenceLink {
  /// Creates a link record. Use [ValenceLinks.accept] for untrusted input.
  const ValenceLink({required this.url, required this.path});

  /// The external URL. Treat it as untrusted data, never as authorization.
  final String url;

  /// The local path, query and fragment, without the external origin.
  final String path;
}

/// Store-compiled link policy and startup mailbox. No WebView navigation occurs here.
final class ValenceLinks {
  /// Creates a listener. An empty [origins] set denies every link.
  ValenceLinks({required this.origins, required this.onOpened});

  /// Exact HTTPS or custom-scheme origins compiled into the store build.
  final Set<String> origins;

  /// Called for accepted intents after the page has drained [initial].
  void Function(ValenceLink) onOpened;
  StreamSubscription<String>? _subscription;
  ValenceLink? _pending;
  bool _listening = false;
  bool _closed = false;

  /// Maps a URL to a safe route, or returns null without logging its contents.
  ValenceLink? accept(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (utf8.encode(raw).length > 8192 ||
        RegExp(r'[\x00-\x20\x7f\\]').hasMatch(raw) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(raw) ||
        uri.userInfo.isNotEmpty ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9+.-]*$').hasMatch(scheme) ||
        const {
          'http',
          'javascript',
          'data',
          'file',
          'content',
          'intent',
          'about',
          'blob'
        }.contains(scheme) ||
        (scheme != 'https' && uri.hasPort)) {
      return null;
    }
    final origin = '$scheme://${uri.authority.toLowerCase()}';
    if (!origins.contains(origin)) return null;
    final rawPath = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://[^/?#]+([^?#]*)')
        .firstMatch(raw)
        ?.group(1);
    if (rawPath == null) return null;
    final path = rawPath.isEmpty ? '/' : rawPath;
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        RegExp(r'%2f|%5c', caseSensitive: false).hasMatch(path)) {
      return null;
    }
    String decoded;
    try {
      decoded = Uri.decodeComponent(path);
    } on FormatException {
      return null;
    }
    if (RegExp(r'[\x00-\x20\x7f\\]').hasMatch(decoded) ||
        decoded.split('/').any((s) => s == '.' || s == '..') ||
        decoded == '/_host' ||
        decoded.startsWith('/_host/')) {
      return null;
    }
    return ValenceLink(
      url: raw,
      path:
          '$path${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}',
    );
  }

  /// Starts early; dependency callbacks let tests exercise startup races without a device.
  Future<void> start(
      {Future<String?> Function()? getInitial, Stream<String>? stream}) async {
    if (_subscription != null || _closed || origins.isEmpty) return;
    final plugin = getInitial == null || stream == null ? AppLinks() : null;
    final queued = <String>[];
    var starting = true;
    _subscription = (stream ?? plugin!.stringLinkStream).listen((uri) {
      if (starting) {
        // ponytail: keep only the latest 16 startup intents; the UI mailbox is latest-wins.
        if (queued.length == 16) queued.removeAt(0);
        queued.add(uri);
      } else {
        receive(uri);
      }
    }, onError: (Object _) {/* Do not log URLs or platform error details. */});
    String? launch;
    try {
      launch = await (getInitial ?? plugin!.getInitialLinkString)();
    } on Exception {/* No initial intent is a valid startup. */}
    if (_closed) return;
    if (launch != null) receive(launch);
    var skippedLaunch = false;
    for (final uri in queued) {
      if (!skippedLaunch && launch == uri) {
        skippedLaunch = true;
        continue;
      }
      receive(uri);
    }
    starting = false;
  }

  /// Accepts one OS intent. Repeated taps after startup are intentionally preserved.
  void receive(String uri) {
    if (_closed) return;
    final link = accept(uri);
    if (link == null) return;
    if (_listening) {
      onOpened(link);
    } else {
      _pending = link;
    }
  }

  /// Returns delivery to the mailbox while a new WebView page subscribes.
  /// Already consumed links are not replayed; a still-pending link is retained.
  void beginPage() {
    _listening = false;
  }

  /// Consumes the page's mailbox and enables subsequent live events.
  ValenceLink? initial() {
    _listening = true;
    final result = _pending;
    _pending = null;
    return result;
  }

  /// Cancels the native subscription when the UI host is disposed.
  Future<void> close() async {
    _closed = true;
    _pending = null;
    await _subscription?.cancel();
  }
}
