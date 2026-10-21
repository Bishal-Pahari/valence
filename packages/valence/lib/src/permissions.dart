import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as native;

import 'log.dart';
import 'wire.dart';

/// Permission names accepted by contracts §4.6. These do not grant access by themselves.
const valencePermissionKinds = {
  'camera',
  'location',
  'notifications',
  'contacts',
  'bluetooth',
  'microphone',
  'photos',
};

/// Platform seam for permission dialogs. An implementation must never prompt in [check].
abstract interface class ValencePermissionBackend {
  /// Uses permission_handler on Android and experimental iOS.
  factory ValencePermissionBackend.native({String? platform, Future<int> Function()? androidSdk}) =
      _NativePermissions;

  /// Reads an OS status without prompting.
  Future<String> check(String kind);

  /// Asks the OS and returns its answer. Recheck [isForeground] after preparation, before native dispatch.
  Future<String> request(String kind, {required bool Function() isForeground});

  /// Whether app settings could be opened, not whether permission was granted.
  Future<bool> openSettings();
}

final class _NativePermissions implements ValencePermissionBackend {
  _NativePermissions({String? platform, Future<int> Function()? androidSdk})
      : _platform = platform ?? Platform.operatingSystem,
        _androidSdk = androidSdk ?? (() async => (await DeviceInfoPlugin().androidInfo).version.sdkInt);

  final String _platform;
  final Future<int> Function() _androidSdk;

  void _supported() {
    if (_platform != 'android' && _platform != 'ios') {
      throw BridgeError(BridgeErrorCode.unsupported, 'permissions require Android or iOS');
    }
  }

  Future<List<native.Permission>> _permissions(String kind) async {
    _supported();
    final sdk = _platform == 'android' ? await _androidSdk() : null;
    return switch (kind) {
      'camera' => [native.Permission.camera],
      'location' => [native.Permission.locationWhenInUse],
      'notifications' => [native.Permission.notification],
      'contacts' => [native.Permission.contacts],
      'microphone' => [native.Permission.microphone],
      'photos' => [sdk != null && sdk < 33 ? native.Permission.storage : native.Permission.photos],
      'bluetooth' => sdk == null
          ? [native.Permission.bluetooth]
          : sdk < 31
              ? [native.Permission.locationWhenInUse]
              : [native.Permission.bluetoothScan, native.Permission.bluetoothConnect],
      _ => throw BridgeError(BridgeErrorCode.params, 'unknown permission kind'),
    };
  }

  String _status(native.PermissionStatus status) => switch (status) {
        native.PermissionStatus.provisional => 'limited',
        _ => status.name,
      };

  String _combined(Iterable<native.PermissionStatus> statuses) {
    final names = statuses.map(_status).toSet();
    return ['restricted', 'permanentlyDenied', 'denied', 'limited', 'granted'].firstWhere(names.contains);
  }

  @override
  Future<String> check(String kind) async {
    final permissions = await _permissions(kind);
    final status = _combined(await Future.wait(permissions.map((p) => p.status)));
    // Android cannot distinguish never-requested / Ask every time / permanent denial on a check.
    // Older plugin versions infer permanence from request history; do not expose that guess.
    return _platform == 'android' && status == 'permanentlyDenied' ? 'denied' : status;
  }

  @override
  Future<String> request(String kind, {required bool Function() isForeground}) async {
    final permissions = await _permissions(kind);
    if (!isForeground()) {
      throw BridgeError(BridgeErrorCode.denied, 'permission prompts require a foreground host');
    }
    final result = await permissions.request();
    return _combined(permissions.map((p) => result[p] ?? native.PermissionStatus.denied));
  }

  @override
  Future<bool> openSettings() async {
    _supported();
    return native.openAppSettings();
  }
}

/// Store-compiled allowlist, serialized OS dialogs and resume deltas (contracts §4.6).
final class ValencePermissions {
  /// Creates a foreground UI service; construction makes no platform call.
  ValencePermissions({
    required Set<String> kinds,
    required bool Function() isForeground,
    ValencePermissionBackend? backend,
    ValenceLogger log = defaultValenceLogger,
  })  : kinds = Set.unmodifiable(kinds),
        _isForeground = isForeground,
        _backend = backend ?? ValencePermissionBackend.native(),
        _log = log {
    if (!valencePermissionKinds.containsAll(kinds)) {
      throw ArgumentError.value(kinds, 'kinds', 'unknown permission kind');
    }
  }

  /// Only a store release can change these kinds.
  final Set<String> kinds;
  final bool Function() _isForeground;
  final ValencePermissionBackend _backend;
  final ValenceLogger _log;
  final Map<String, String> _observed = {};
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _allowed(String kind) {
    if (!valencePermissionKinds.contains(kind)) {
      throw BridgeError(BridgeErrorCode.params, 'unknown permission kind "$kind"');
    }
    if (!kinds.contains(kind)) {
      throw BridgeError(BridgeErrorCode.denied, 'permission "$kind" is not enabled in this store build');
    }
  }

  void _foreground() {
    if (!_isForeground()) {
      throw BridgeError(BridgeErrorCode.denied, 'permission prompts require a foreground host');
    }
  }

  /// `permissions.check`; denied kinds never reach the platform.
  Future<String> check(String kind) async {
    _allowed(kind);
    return _serial(() async => _observed[kind] = await _backend.check(kind));
  }

  /// `permissions.request`; a queued call checks foreground again before prompting.
  Future<String> request(String kind) async {
    _allowed(kind);
    _foreground();
    return _serial(() async {
      _foreground();
      return _observed[kind] = await _backend.request(kind, isForeground: _isForeground);
    });
  }

  /// `permissions.openSettings`; true means the settings screen opened.
  Future<bool> openSettings() async {
    _foreground();
    return _serial(() async {
      _foreground();
      return _backend.openSettings();
    });
  }

  /// Baselines startup or returns changed kinds on resume, without any prompt.
  Future<List<Map<String, String>>> refresh({bool baseline = false}) => _serial(() async {
        final changes = <Map<String, String>>[];
        for (final kind in kinds) {
          try {
            final status = await _backend.check(kind);
            final previous = _observed[kind];
            _observed[kind] = status;
            if (!baseline && previous != null && previous != status) {
              changes.add({'kind': kind, 'status': status});
            }
          } on Object catch (e) {
            _log('permissions: check $kind failed: $e');
          }
        }
        return changes;
      });
}
