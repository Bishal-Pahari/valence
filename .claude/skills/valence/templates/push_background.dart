// Install valence_push (and Firebase imports below) before copying this callback.
// In main(), initialize Firebase then pass createFirebasePush() to Valence.open.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:valence/valence.dart';

import 'valence/config.g.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundMessage(RemoteMessage message) => ValencePush.handleBackground(
  message.data,
  hasNotification: message.notification != null,
  sync: () async { await Valence.backgroundSync(valenceConfig); },
);
