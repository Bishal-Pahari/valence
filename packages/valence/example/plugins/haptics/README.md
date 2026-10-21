# Haptics plugin example

The Dart package, schema fragment and matching npm types package live together here.
The app declares the Dart path dependency and lists `plugins/haptics/valence.plugin.json`
in its Valence config. Run codegen from the example directory, then register
`const HapticsPlugin()` in `ValenceBuiltins`' `plugins` argument.

Native setup: this plugin uses Flutter's built-in haptic platform channel. It needs
no manifest entries, permission prompts, initialization or disposal. Calls are
foreground UI actions; no background execution is provided. Android's emulator can
verify channel invocation but cannot establish felt vibration. iOS is experimental
and untested. Real plugins must document permissions, native setup and cleanup here.

Web consumers call `call('haptics.tap')` through their generated bridge. The matching
`web-types` npm package exports `HapticsMethods` for shim authors; it neither sends
raw bridge messages nor introduces a second client. In this fixture the method
already existed at since 1; a new app capability must use a since above its store
baseline and needs a new store release.
