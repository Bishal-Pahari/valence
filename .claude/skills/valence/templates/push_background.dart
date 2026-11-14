// Install valence_push (and Firebase imports below) before copying this callback.
// In main(), initialize Firebase then pass createFirebasePush() to Valence.open.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:valence/valence.dart';

import 'valence/config.g.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundMessage(RemoteMessage message) => ValencePush.handleBackground(
  message.data,
  hasNotification: message.notification != null,
  // `kind` is what makes a push-woken run distinguishable from the periodic job in the sync lease,
  // in `sync.status` and in the log (§5.6).
  sync: () async { await Valence.backgroundSync(valenceConfig, kind: ValenceSyncKind.push); },
);
