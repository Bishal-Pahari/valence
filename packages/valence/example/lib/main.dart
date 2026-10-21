// The whole host, for an app that adds one native method of its own.
//
// Everything the spec calls the host — the loopback server, the updater and its rollback, the SQLite
// store, sync, the bridge trust boundary, the WebView with its navigation lock and back gesture — is in
// the `valence` package. This file is the app-specific part, and that is all of it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:valence/valence.dart';

import 'valence/bridge.g.dart';
import 'valence/config.g.dart';

/// Firebase invokes this entry point without constructing a UI or updater.
@pragma('vm:entry-point')
Future<void> pushBackgroundMessage(RemoteMessage message) =>
    ValencePush.handleBackground(
      message.data,
      hasNotification: message.notification != null,
      sync: () async {
        await Valence.backgroundSync(valenceConfig);
      },
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ValencePush? push;
  if (const bool.fromEnvironment('VALENCE_PUSH')) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(pushBackgroundMessage);
    push = ValencePush();
  }
  final valence = await Valence.open(valenceConfig, hostBuild: 1, push: push);
  final handlers = AppHandlers(valence);
  runApp(
    MaterialApp(
      title: 'Valence example',
      debugShowCheckedModeBanner: false,
      home: ValenceApp(
        valence: valence,
        dispatch: (raw, nonce) => bridgeDispatch(handlers, raw, nonce: nonce),
      ),
    ),
  );
}

/// This app's bridge methods.
///
/// `ValenceBuiltins` is generated, and already implements `app.*`, `data.*`, `prefs.*`, `sync.*`,
/// `open.external` and `bundle.*` by delegating to the runtime. Only what is genuinely native to this app
/// is left to write — here, one haptic tap.
class AppHandlers extends ValenceBuiltins implements BridgeHandlers {
  AppHandlers(super.valence);

  @override
  Future<void> hapticsTap() async => HapticFeedback.lightImpact();
}
