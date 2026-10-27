# Migrating from 0.3

In 0.3, `/valence init` **generated** the host runtime — about 1,500 lines of Dart — into your Flutter
project, and copied a `client.ts` into your web app. Every app carried its own copy, so a fix to a
security path reached nobody. From 0.4 the runtime is two published packages:

| | |
|---|---|
| [`valence`](https://pub.dev/packages/valence) on pub.dev | The whole Flutter host |
| [`@getvalence/bridge`](https://www.npmjs.com/package/@getvalence/bridge) on npm | The whole web client |

`valence codegen` now emits only what is specific to your app, and imports the rest.

**Your data and your update state carry over untouched.** This is not a reinstall: the SQLite file, the
outbox, every pair's `max_usn`, and `state.json`'s `current`, `floor`, `bad` and `trial` are read exactly
as your 0.3 host wrote them. The package's own test suite covers that
([`migration_test.dart`](../packages/valence/test/migration_test.dart)), including a mid-trial state and a
queued write keeping its original op id.

## Before you start

- Commit everything. This deletes files.
- Note your database file name. If your 0.3 host called it anything other than `valence.db`, you need
  one config line — see [Keeping your database](#keeping-your-database).
- Keep `.valence/baseline.json`. It is what makes the schema guard work, and a missing one reads as
  "no store build yet".

## 1. Update the tooling

```sh
npx create-valence@latest update
```

That replaces `valence/valence.mjs` and the `/valence` skill. Then start a **new** Claude Code session, or
the skill is not registered.

## 2. Add the two packages

```sh
cd <your flutter host>
flutter pub add valence

cd <your web app>
npm install @getvalence/bridge
```

`flutter pub add valence` brings the verified stack with it: `webview_flutter`, `sqflite`,
`path_provider`, `cryptography`, `crypto`, `http`, `url_launcher` and `connectivity_plus`. Remove those
from your own `pubspec.yaml` **only if nothing else in your app uses them directly.**

`workmanager` is not one of them. The package deliberately does not depend on it — it applies the Kotlin
Gradle Plugin and warns on every Android build — so if you register background sync, keep it.

## 3. Delete the generated runtime

From your Flutter host:

```
lib/valence/server.dart        → the package's loopback server
lib/valence/updater.dart       → the package's updater and state machine
lib/valence/store.dart         → the package's SQLite store
lib/valence/sync.dart          → the package's sync and lease
lib/valence/host.dart          → ValenceApp
lib/valence/bridge.dart        → the generated ValenceBuiltins, plus your own methods (step 4)
lib/valence/manifest.dart      → if your host had one; the package verifies manifests
lib/valence/state.dart         → if your host had one
```

From your web app:

```
<web lib>/client.ts            → @getvalence/bridge
```

**Keep** `lib/valence/bridge.g.dart`, `lib/valence/config.g.dart` and `<web lib>/bridge.g.ts` — codegen
rewrites them in step 5 — and **keep** `<web lib>/shim.ts`, which is your own browser fallbacks.

Your 0.3 host's own Dart test files for the updater, the state machine, the store, the bridge and sync
can go too: that is the contracts §8 matrix, and it is now the package's suite, run on every release of
the package rather than once in your repo. Keep any test of your *own* bridge methods.

## 4. Write the two small files

`lib/main.dart` becomes about twenty lines:

```dart
import 'package:flutter/material.dart';
import 'package:valence/valence.dart';

import 'valence/bridge.g.dart';
import 'valence/config.g.dart';

Future<void> main() async {
  final valence = await Valence.open(valenceConfig, hostBuild: 1);
  final handlers = AppHandlers(valence);
  runApp(
    MaterialApp(
      home: ValenceApp(
        valence: valence,
        dispatch: (raw, nonce) => bridgeDispatch(handlers, raw, nonce: nonce),
      ),
    ),
  );
}
```

`hostBuild` is your Android `versionCode` or iOS `CFBundleVersion`. It is what `app.info` reports as
`host`.

`lib/valence/handlers.dart` keeps **only the methods your 0.3 `bridge.dart` wrote itself**:

```dart
class AppHandlers extends ValenceBuiltins implements BridgeHandlers {
  AppHandlers(super.valence);

  @override
  Future<void> hapticsTap() async => HapticFeedback.lightImpact();
}
```

Delete your implementations of `app.ready`, `app.info`, `data.get`, `data.list`, `data.put`, `sync.now`,
`prefs.get`, `prefs.set`, `open.external` and `bundle.applyUpdate`. The generated `ValenceBuiltins`
implements all of them by delegating to the runtime, and **that is where the §4.2 and §5.4 policy lives**
— the writable-bucket check, the reserved `valence.` prefs keys, the `open.external` scheme allow-list and
the `data.list` clamp. Keeping your own copies is how those drift.

The analyzer tells you exactly what is left: anything still abstract on `BridgeHandlers` is a method the
package does not implement, which means it is yours.

## 5. Regenerate and check

```sh
node valence/valence.mjs codegen
cd <your flutter host> && flutter pub get && dart analyze --fatal-infos lib test && flutter test
```

`config.g.dart` changes shape in this release. 0.3 emitted five loose constants; 0.4 emits one
`valenceConfig`:

| 0.3 | 0.4 |
|---|---|
| `valenceAppId` | `valenceConfig.appId` |
| `valenceKeyring` | `valenceConfig.keyring` |
| `valenceOtaBase` | `valenceConfig.otaBase` |
| `valenceSyncBase` | `valenceConfig.syncBase` |
| `valenceWritableBuckets` | `valenceConfig.writableBuckets` |

If `codegen` refuses with *"is implemented by the valence package, so its params must stay …"*, your
schema redefined a built-in method. The built-ins are delegated to the runtime, so a changed shape would
compile and then pass the wrong arguments — only a device would notice. Restore the shape it names and add
your variant under a new name; the schema is additive only anyway.

On the web side, your imports move from `client.ts` to the generated file:

```ts
// 0.3
import { call, has, on, ready, connect, BridgeError } from '$lib/valence/client';

// 0.4
import { call, has, on, ready, connect, BridgeError } from '$lib/valence/bridge.g';
```

Import from `bridge.g.ts`, **not** from `@getvalence/bridge`. The generated file is what binds your
method table, so `call('data.get', { bucket, key })` is type-checked against *your* schema; importing the
package directly loses that. Your `shim.ts` can now be typed as the generated `AppShim`, which makes a
fallback with the wrong signature a compile error.

## Optional: take the 0.4 auth methods

Nothing in the migration requires this, but if your app has a login, 0.4 is the release that gives it
somewhere to keep a token. Add five methods and one event to `valence/bridge.schema.json`, bump
`version` to `2`, and run `codegen` again:

```json
"secure.get":     { "since": 2, "params": { "key": "string" }, "returns": "string?" },
"secure.set":     { "since": 2, "params": { "key": "string", "value": "string" }, "returns": "void" },
"secure.delete":  { "since": 2, "params": { "key": "string" }, "returns": "void" },
"auth.setToken":  { "since": 2, "params": { "token": "string?" }, "returns": "void" },
"auth.hasToken":  { "since": 2, "params": {}, "returns": "bool" }
```

```json
"auth.expired":   { "since": 2, "payload": {} }
```

They are built-ins, so there is no handler to write — `ValenceBuiltins` delegates them to the package.
What they do and what they deliberately do not do is on the [Login and secrets](https://getvalence.pages.dev/docs/guides/auth/) page.

If more than one person can use the device, take the account switch with them — two more params on
`auth.setToken` and `auth.account`, at version 13 rather than 2:
[Signing users in and out](https://getvalence.pages.dev/docs/guides/accounts/).

**The bump has one consequence:** `requires.bridge` follows the schema version, so your next OTA release
declares `2` and the hosts already in the field stop taking it until your store build lands. If you need
one more release to reach them, pin it with `valence bundle --requires-bridge 1`.

## Keeping your database

The package opens `<appSupport>/valence.db` by default. If your 0.3 host chose a different file name,
say so once in `valence/valence.config.json`:

```json
{
  "host": { "dir": "mobile", "database": "my_app.db" }
}
```

codegen puts it into `valenceConfig.databaseName`, and the package reads your existing rows.

**Get this right before you ship.** Pointing at the wrong name does not fail loudly — it creates a new,
empty store next to the full one, and the app looks like a fresh install to the user. Check the file name
that is actually on a device:

```sh
adb shell run-as <your applicationId> ls files/../app_flutter
```

## What does not change

- **`state.json` stays where it is**, at `<appSupport>/valence/state.json`, and is read as written.
  `current`, `previous`, `pending`, `trial`, `trialFails`, `serving`, `bad`, `floor` and `installId` all
  carry over, so a device mid-trial is not re-trialled and a bundle in `bad` stays refused. 0.4 adds
  `builtinRefused`; an absent field reads as null.
- **Your CAS files and manifests carry over.** The package re-verifies a manifest on disk before serving
  it, so nothing has to be re-downloaded.
- **`installId` carries over**, so a device stays in the same rollout cohort and on the same loopback
  port — which means the page's web storage survives too.
- **Your signing key, keyring and `.valence/baseline.json`** are untouched. `seq` and `floor` keep
  rising; this is not a key rotation.
- **The bundle format, the manifest, the wire protocol and the sync protocol** are unchanged. An OTA
  bundle built by 0.3 is served by a 0.4 host, and the reverse.

## The release that ships it

Swapping the host runtime is a **store release**: `lib/` changed, so the APK changed. Nothing about it
reaches existing devices over the air.

1. `node valence/valence.mjs bundle --builtin`, then `verify`.
2. `node valence/valence.mjs bundle --store`, which records the reviewed routes and schema.
3. Build, submit, and only then stage OTA releases on top.

Run `/valence doctor` first. It compares the built-in manifest's `requires.bridge` against the generated
`hostBridgeVersion`, which is the one mismatch that leaves a fresh install with nothing to serve.

Sync correctness: pull cursors advance only through returned rows, never push echoes or a later server-head max. Fresh pairs satisfy OTA activation only after all pages or static chunks complete. Progress resumes after an interruption. Pending publication retains the data lease; GC protects in-flight manifests and retries stale snapshots. Step 7 waits up to five seconds for ordinary sync. Outbox operations use a durable insertion ordinal; database version 2 migrates legacy queued ids, values and deletes without changing bucket cursors or user rows.
This update prevents new cursor skips. It cannot infer rows omitted by an older host that already persisted an advanced cursor. Recover those omissions by republishing affected server records with newer USNs or providing a new read-only schema; do not delete the device database or its outbox.

## Optional deep links

Schema 5 adds `link.initial` and `link.opened`; existing schema methods retain their meaning. Regenerate, compile `links.origins` and add native registrations in a store build. `onLink()` is inert on older hosts. See [deep links](deep-links.md).


Local reminders: enable Android core library desugaring even in hosts that leave notifications disabled. To adopt schema-11 notify.* and badge.*, add native receivers and a status drawable, set notifications.enabled, regenerate and ship a store build. Coordinate IDs with existing custom reminders; preserve any shipped pre-schema-11 custom notify.schedule shape and handler. See [the guide](local-notifications.md).
