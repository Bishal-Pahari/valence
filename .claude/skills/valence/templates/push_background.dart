// Copy to the host's lib/push_background.dart when opting into Firebase push.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:valence/valence.dart';

import 'valence/config.g.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundMessage(RemoteMessage message) => ValencePush.handleBackground(
  message.data,
  hasNotification: message.notification != null,
  sync: () async { await Valence.backgroundSync(valenceConfig); },
);
