import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant, RootIsolateToken;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'log.dart';
import 'wire.dart';

/// An untrusted push payload. Never navigate, evaluate code or authenticate from it.
final class ValencePushMessage {
  /// Creates metadata for the bridge. Images are metadata, never fetched by Dart.
  const ValencePushMessage(
      {this.id, this.data = const {}, this.title, this.body, this.image});

  /// Converts Firebase's native delivery envelope.
  factory ValencePushMessage.fromRemote(RemoteMessage message) =>
      ValencePushMessage(
        id: message.messageId,
        data: message.data,
        title: message.notification?.title,
        body: message.notification?.body,
        image: message.notification?.android?.imageUrl ??
            message.notification?.apple?.imageUrl,
      );

  /// Provider message id; may be absent.
  final String? id;

  /// Untrusted application data, not a command except for the exact sync hint.
  final Map<String, dynamic> data;

  /// Notification title, if any.
  final String? title;

  /// Notification body, if any.
  final String? body;

  /// Optional image metadata. Only HTTPS image URLs are exposed.
  final String? image;

  /// The schema-5 wire record.
  Map<String, Object?> toJson() {
    final uri = image == null ? null : Uri.tryParse(image!);
    return {
      'id': id,
      'data': data,
      'title': title,
      'body': body,
      'image':
          uri?.scheme == 'https' && uri!.host.isNotEmpty && uri.userInfo.isEmpty
              ? image
              : null,
    };
  }
}

/// Platform boundary for Firebase Messaging, also usable for deterministic tests.
abstract interface class ValencePushTransport {
  /// Foreground delivery only.
  Stream<RemoteMessage> get received;

  /// Notification taps that resume an existing process.
  Stream<RemoteMessage> get tapped;

  /// Rotated FCM registration tokens.
  Stream<String> get tokens;

  /// The notification that started a fresh process, if any.
  Future<RemoteMessage?> initial();

  /// Current settings, or a user-facing permission request when requested.
  Future<String> permission({required bool request});

  /// FCM registration token, also on iOS. Null before APNs registration.
  Future<String?> token();
}

final class _FirebasePushTransport implements ValencePushTransport {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Stream<RemoteMessage> get received => FirebaseMessaging.onMessage;
  @override
  Stream<RemoteMessage> get tapped => FirebaseMessaging.onMessageOpenedApp;
  @override
  Stream<String> get tokens => _messaging.onTokenRefresh;
  @override
  Future<RemoteMessage?> initial() => _messaging.getInitialMessage();
  @override
  Future<String> permission({required bool request}) async {
    final settings = request
        ? await _messaging.requestPermission(
            alert: true, badge: true, sound: true)
        : await _messaging.getNotificationSettings();
    return settings.authorizationStatus.name;
  }

  @override
  Future<String?> token() async {
    // FlutterFire forbids token API calls on Apple before APNs registration.
    if (Platform.isIOS && await _messaging.getAPNSToken() == null) return null;
    return _messaging.getToken();
  }
}

/// Opt-in remote push, contracts §6.4. Initialize Firebase before constructing it.
///
/// This object subscribes and captures the initial tap without requesting permission
/// or fetching a registration token during offline startup. Call [dispose] when the
/// host is permanently discarded. Background callbacks use [handleBackground],
/// never a UI runtime or this instance.
final class ValencePush {
  /// Creates the Firebase adapter or uses an injected platform boundary.
  ValencePush(
      {ValencePushTransport? transport,
      ValenceLogger log = defaultValenceLogger})
      : _transport = transport ?? _FirebasePushTransport(),
        _log = log;

  final ValencePushTransport _transport;
  final ValenceLogger _log;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  ValencePushMessage? _pendingTap;
  bool _live = false;
  bool _started = false;
  bool _disposed = false;
  bool _tapDuringStart = false;
  Future<void>? _starting;
  void Function(String)? _emit;
  Future<void> Function()? _sync;

  /// Captures OS events. Does not contact Firebase for a token or prompt the user.
  /// Calling it twice attaches no duplicate listeners.
  Future<void> start(
      {required void Function(String) emit,
      required Future<void> Function() sync}) {
    if (_disposed) throw StateError('push was disposed');
    if (_started) return _starting!;
    _started = true;
    _emit = emit;
    _sync = sync;
    return _starting = _start();
  }

  Future<void> _start() async {
    void onError(Object _) => _log('push: platform event unavailable');
    _subscriptions.add(_transport.received.listen((message) {
      _event('push.received',
          {'message': ValencePushMessage.fromRemote(message).toJson()});
      if (isSyncHint(message.data,
          hasNotification: message.notification != null)) {
        unawaited(_runSync());
      }
    }, onError: onError));
    _subscriptions.add(_transport.tapped.listen((message) {
      _tapDuringStart = true;
      _tap(message);
    }, onError: onError));
    _subscriptions.add(_transport.tokens.listen((token) {
      _event('push.tokenChanged', {'token': token});
    }, onError: onError));
    try {
      final message = await _transport.initial();
      if (!_disposed && !_tapDuringStart && message != null) _tap(message);
    } catch (_) {
      _log('push: initial notification unavailable');
    }
  }

  Future<void> _runSync() async {
    try {
      await _sync?.call();
    } catch (_) {
      // Do not expose push contents, tokens, or a native request error to logs.
      _log('push: sync hint failed; normal sync will retry');
    }
  }

  void _tap(RemoteMessage message) {
    final record = ValencePushMessage.fromRemote(message);
    if (!_fits('push.tapped', {'message': record.toJson()})) return;
    if (_live) {
      _event('push.tapped', {'message': record.toJson()});
    } else {
      // ponytail: retain only the latest pre-subscription tap, not a durable inbox.
      _pendingTap = record;
    }
  }

  bool _fits(String name, Map<String, Object?> payload) {
    try {
      if (utf8.encode(eventScript(name, payload)).length <= maxMessageBytes) {
        return true;
      }
    } catch (_) {
      // Reject non-JSON transport data as well as oversized envelopes.
    }
    _log('push: invalid or oversized event dropped');
    return false;
  }

  void _event(String name, Map<String, Object?> payload) {
    if (!_disposed && _fits(name, payload)) {
      _emit?.call(eventScript(name, payload));
    }
  }

  /// Consumes the initial tap after subscriptions have been installed by the page.
  Future<ValencePushMessage?> initial() async {
    await _starting;
    _live = true;
    final result = _pendingTap;
    _pendingTap = null;
    return result;
  }

  /// Permission inspection never prompts; requests happen only on explicit opt-in.
  Future<String> permission({bool request = false}) =>
      _transport.permission(request: request);

  /// Registration token, never the R1 login token. No automatic backend upload.
  Future<String?> token() async {
    final status = await permission();
    if (status != 'authorized' && status != 'provisional') return null;
    return _transport.token();
  }

  /// The only accepted remote command: an exact data-only sync hint.
  static bool isSyncHint(Map<String, dynamic> data,
          {required bool hasNotification}) =>
      !hasNotification && data.length == 1 && data['valence'] == 'sync';

  /// Runs in the app's top-level Firebase background callback. Never opens a UI
  /// runtime, starts a server, consumes a trial, or trusts payload-supplied config.
  static Future<void> handleBackground(
    Map<String, dynamic> data, {
    required bool hasNotification,
    required Future<void> Function() sync,
  }) async {
    if (!isSyncHint(data, hasNotification: hasNotification)) return;
    WidgetsFlutterBinding.ensureInitialized();
    if (RootIsolateToken.instance == null) {
      DartPluginRegistrant.ensureInitialized();
    }
    await sync();
  }

  /// Stops subscriptions. Does not delete the provider registration or any data.
  Future<void> dispose() async {
    _disposed = true;
    _pendingTap = null;
    _emit = null;
    _sync = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
