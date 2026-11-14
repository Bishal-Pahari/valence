/// Opt-in Firebase Messaging transport for Valence.
library;

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:valence/valence.dart';

/// Creates a push service after the host initializes Firebase.
/// Startup captures taps without requesting permission or fetching a token.
ValencePush createFirebasePush({ValenceLogger log = defaultValenceLogger}) =>
    ValencePush(transport: FirebasePushTransport(), log: log);

ValencePushMessage _message(RemoteMessage message) => ValencePushMessage(
      id: message.messageId,
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
      hasNotification: message.notification != null,
      image: message.notification?.android?.imageUrl ??
          message.notification?.apple?.imageUrl,
    );

/// FCM on Android and APNs through FCM on iOS (experimental and untested).
/// Initialize Firebase before constructing this transport.
final class FirebasePushTransport implements ValencePushTransport {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Stream<ValencePushMessage> get received =>
      FirebaseMessaging.onMessage.map(_message);
  @override
  Stream<ValencePushMessage> get tapped =>
      FirebaseMessaging.onMessageOpenedApp.map(_message);
  @override
  Stream<String> get tokens => _messaging.onTokenRefresh;
  @override
  Future<ValencePushMessage?> initial() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _message(message);
  }

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
