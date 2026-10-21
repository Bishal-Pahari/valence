// The whole host, for an app that adds one native method of its own.
//
// Everything the spec calls the host — the loopback server, the updater and its rollback, the SQLite
// store, sync, the bridge trust boundary, the WebView with its navigation lock and back gesture — is in
// the `valence` package. This file is the app-specific part, and that is all of it.
import 'package:flutter/material.dart';
import 'package:valence/valence.dart';
import 'package:valence_example_haptics/haptics.dart';

import 'valence/bridge.g.dart';
import 'valence/config.g.dart';

Future<void> main() async {
  final valence = await Valence.open(valenceConfig, hostBuild: 1);
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
/// is registered here — the separate haptics plugin supplies the native tap.
class AppHandlers extends ValenceBuiltins implements BridgeHandlers {
  AppHandlers(super.valence) : super(plugins: [const HapticsPlugin()]);
}
