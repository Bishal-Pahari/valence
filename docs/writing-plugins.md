# Writing a Valence plugin

The contract is [§4.10](../.claude/skills/valence/references/contracts.md#410-native-plugins).
The complete [guide](https://getvalence.pages.dev/docs/guides/plugins/) covers
fragments, handlers, events, web types and platform setup. A runnable local
[Dart plugin and matching npm types package](../packages/valence/example/plugins/haptics/)
are wired into the example app.

1. Install the Dart plugin and npm types packages and follow their native setup notes.
2. List project-root-relative fragment paths in `valence/valence.config.json.plugins`.
   A published fragment declares no `since`; stamp it from the entry instead:
   `{"path": "...", "since": {"acmeScan.read": 3}}`, covering every method and event.
3. For a new capability, bump the app's bridge schema version and use a `since`
   above the recorded store version. Package versions do not determine `since`,
   which is why a published fragment cannot carry one and does not have to be edited.
4. Run `node valence/valence.mjs codegen`; extend `ValenceBuiltins` with
   `super(plugins: [MyPlugin()])`. Only merged schema methods get dispatch cases.
5. Call through `bridge.g.ts` with `has()` guards and a browser shim where needed.
6. Run the generated-code, native and web gates, then make a store release.

After a tooling or bridge upgrade, regenerate and run your web TypeScript build.
The generated client passes both method and event capability tables to the bridge;
use a matching CLI/bridge snapshot pair. An unchanged version string alone does
not establish snapshot compatibility. Doctor checks shipped plugin definitions
against the merged schema and still rejects changes or removal.

Choose one lower-camel namespace for methods/events and its PascalCase prefix
for types. Fragments may reference only their own named types. Conflicts are errors,
including identical definitions. Core namespaces, including `share`, are reserved. Metadata fields
name the Dart package, npm package and setup document; tooling executes none of them.

The registry snapshots method ownership. Missing implementations return
`E_UNSUPPORTED`; methods not in the schema return `E_UNKNOWN` without calling a
plugin. The generated adapters strictly decode parameters before invocation and
typed JSON results before replying. Native subscriptions can emit generated
`BridgeEvents` scripts with `valence.emit`. The app/plugin owns initialization and
cleanup; registration does not schedule background work.

Review plugins as trusted native dependencies: they have host privileges. Keep
permissions, secret handling and origin/scheme restrictions in native code. Never
expose the registry as a raw WebView channel. The built-in `open.external` uses
the same API and preserves the runtime's allowlist; applications cannot replace it.

Android is tested. iOS is experimental and untested. The emulator verifies haptic
channel invocation, not felt vibration.
