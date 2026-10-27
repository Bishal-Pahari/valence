import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'server.dart';
import 'wire.dart';

/// Task-local UI state (contracts §4.7). Never written to the app's database.
final class ValenceRestoration extends ChangeNotifier {
  int? _seq;
  String _route = '/';
  String? _json;
  String? _account;
  int _accountRevision = 0;

  /// Invalidates route captures that began before an account change.
  int get accountRevision => _accountRevision;

  /// Discards an untrusted snapshot when its native account cannot be checked.
  void clear() {
    _accountRevision++;
    _account = null;
    _route = '/';
    _json = null;
    notifyListeners();
  }

  /// Binds the snapshot to the native account, never its bearer token.
  /// First-account adoption retains the live draft; restored mismatches never do.
  void bindAccount(String? account, {bool adopt = false}) {
    final fingerprint = account == null
        ? null
        : sha256.convert(utf8.encode(account)).toString();
    if (_account == fingerprint) return;
    _accountRevision++;
    _account = fingerprint;
    if (!adopt) {
      _route = '/';
      _json = null;
    }
    notifyListeners();
  }

  /// Current safe path, query and fragment, without any origin.
  String get route => _route;

  /// Latest saved blob, decoded afresh so callers cannot mutate the snapshot.
  Object? restore() => _json == null ? null : jsonDecode(_json!);

  /// Rejects oversize JSON before replacing the previous state.
  void save(Object? value) {
    final encoded = value == null ? null : jsonEncode(value);
    if (encoded != null && utf8.encode(encoded).length > 65536) {
      throw const BridgeError(
          BridgeErrorCode.params, 'state.save exceeds 65536 UTF-8 bytes');
    }
    _json = encoded;
    notifyListeners();
  }

  /// Drops UI state across an update/rollback, while leaving OTA state untouched.
  void activate(int seq) {
    if (_seq == seq) return;
    _seq = seq;
    _route = '/';
    _json = null;
    notifyListeners();
  }

  /// Accepts a route only after checking the current loopback origin.
  void observe(String url, String origin) {
    final uri = Uri.tryParse(url);
    final base = Uri.tryParse(origin);
    if (uri == null ||
        base == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        !const {'http', 'https'}.contains(base.scheme) ||
        uri.origin != base.origin ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    final route =
        '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}';
    if (!safeRoute(route) || route == _route) return;
    _route = route;
    notifyListeners();
  }

  /// A restored route must never reach host files or choose another origin.
  static bool safeRoute(String route) {
    if (utf8.encode(route).length > 4096 ||
        !route.startsWith('/') ||
        route.startsWith('//')) {
      return false;
    }
    try {
      final full = Uri.decodeComponent(route);
      if (full.contains('\\') || full.runes.any((c) => c < 32 || c == 127)) {
        return false;
      }
      final uri = Uri.parse(route);
      if (uri.hasScheme || uri.hasAuthority) return false;
      final decoded = Uri.decodeComponent(route.split(RegExp(r'[?#]')).first);
      if (decoded.startsWith('//') ||
          decoded.contains('\\') ||
          decoded.contains('%') ||
          decoded.runes.any((c) => c < 32 || c == 127)) {
        return false;
      }
      final segments = decoded.split('/');
      if (segments.any((s) => s == '.' || s == '..') ||
          segments.contains('_host')) {
        return false;
      }
      return normaliseRequestPath(decoded) != null;
    } on FormatException {
      return false;
    }
  }

  /// Internal OS restoration envelope. The origin and nonce are never included.
  String snapshot() => jsonEncode(
      {'seq': _seq, 'route': _route, 'json': _json, 'account': _account});

  /// Validates OS data as untrusted input before it can influence navigation.
  void hydrate(String? snapshot) {
    _seq = null;
    _route = '/';
    _json = null;
    _account = null;
    if (snapshot == null || utf8.encode(snapshot).length > 450000) return;
    try {
      final data = jsonDecode(snapshot);
      if (data is! Map<String, dynamic> ||
          data['seq'] is! int ||
          data['route'] is! String ||
          !safeRoute(data['route'] as String)) {
        return;
      }
      final blob = data['json'];
      final account = data['account'];
      if (account != null &&
          (account is! String ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(account))) {
        return;
      }
      if (blob != null &&
          (blob is! String || utf8.encode(blob).length > 65536)) {
        return;
      }
      if (blob != null) jsonDecode(blob as String);
      _seq = data['seq'] as int;
      _route = data['route'] as String;
      _json = blob as String?;
      _account = account as String?;
    } on FormatException {
      // Corrupt or obsolete restoration data starts fresh.
    }
  }
}

/// Bridges the task-local model to Flutter's native restoration bucket.
class ValenceRestorationScope extends StatefulWidget {
  /// Internal host wiring; [onReady] runs after OS data has arrived.
  const ValenceRestorationScope(
      {required this.model,
      required this.onReady,
      required this.child,
      super.key});

  /// The runtime's UI model.
  final ValenceRestoration model;

  /// Starts the host once restoration is available.
  final VoidCallback onReady;

  /// The host content.
  final Widget child;

  @override
  State<ValenceRestorationScope> createState() =>
      _ValenceRestorationScopeState();
}

class _ValenceRestorationScopeState extends State<ValenceRestorationScope>
    with RestorationMixin {
  final _snapshot = RestorableStringN(null);
  @override
  String get restorationId => 'page';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_snapshot, 'snapshot');
    widget.model.hydrate(_snapshot.value);
    if (initialRestore) {
      widget.model.addListener(_save);
      widget.onReady();
    }
  }

  void _save() {
    _snapshot.value = widget.model.snapshot();
    // A platform WebView update need not schedule a Flutter frame.
    ServicesBinding.instance.restorationManager.flushData();
  }

  @override
  void dispose() {
    widget.model.removeListener(_save);
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
