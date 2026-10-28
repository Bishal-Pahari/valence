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

The generated `hostPluginNamespaces` and `hostPluginMethods` describe the native
registrations required by the merged fragments, including event-only plugins.
Constructing `ValenceBuiltins` checks both through `ValencePluginRegistry.checked`.
A missing plugin or declared method throws `StateError` with a registration fix
in every build mode. Regenerate after upgrading; old generated handlers retain
the old behavior. Add a host test that constructs your real `AppHandlers` before
shipping. Doctor names the requirements as a warning because it cannot prove
which native instances your Dart code constructs. Neither check proves native
permissions, initialization or platform behavior.

The registry snapshots method ownership. Direct registry calls without generated
requirements still report missing methods as `E_UNSUPPORTED`; methods not in the schema return `E_UNKNOWN` without calling a
plugin. The generated adapters strictly decode parameters before invocation and
typed JSON results before replying. `E_PARAMS` is for invalid arguments; malformed
native results return `E_INTERNAL`. Errors deliberately thrown by the plugin keep
their code. Native subscriptions can emit generated `BridgeEvents` scripts with
`valence.emit`. The app/plugin owns initialization and
cleanup; registration does not schedule background work.

Review plugins as trusted native dependencies: they have host privileges. Keep
permissions, secret handling and origin/scheme restrictions in native code. Never
expose the registry as a raw WebView channel. The built-in `open.external` uses
the same API and preserves the runtime's allowlist; applications cannot replace it.

`Valence.dataPut` enforces writable buckets and rejects dot keys. Native
`valence.store.put` bypasses that page boundary, so the plugin owns sync correctness.
Ordinary pref and secure APIs still refuse `valence.` keys, and `openExternal`
still checks schemes for native callers. Explicit host-pref/token APIs and the
public database handle remain privileged escape hatches: plugins are not sandboxed.

Only generated `bridge.g.ts` is checked against the merged schema. Published npm
types are hand-maintained and are not verified by codegen. The CLI's exported
`PLUGIN_RESERVED` set is compared with `ValencePluginRegistry.reservedNamespaces`
by the generated-Dart gate. Upgrade vendored tooling with the runtime and regenerate.

Android is tested. iOS is experimental and untested. The emulator verifies haptic
channel invocation, not felt vibration.

## Publishing and listing

Distribution is ordinary publishing: the Dart half to pub.dev, the web types to npm.
There is no registry, resolver or marketplace, and nothing is fetched on a plugin's
behalf — `plugins[].path` always names a file already on disk, so ship
`valence.plugin.json` inside the npm package and let apps point at
`node_modules/@you/your-plugin/valence.plugin.json`.

A package can also extend the host **without** being a plugin. `valence_push`
implements `ValencePushTransport` for `push.*`, a namespace core already owns, so it
has no fragment, no namespace and no `plugins` entry: it is a pub dependency and a
constructor argument. Which shape a package uses decides how it is installed.

The site's [plugin directory](https://getvalence.pages.dev/docs/guides/plugin-directory/)
lists both shapes and says what a listing asks for. It is a hand-maintained docs page:
being listed records that a package exists and declares a fragment, not that anyone
read the code — and a plugin is trusted native code with host privileges.
