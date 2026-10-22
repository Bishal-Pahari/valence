# Changelog

## Unreleased - remote push

Remote push is opt-in in schema 12: `push.token`, passive/explicit `push.permission`, consuming `push.initial`, `push.received`, `push.tapped` and `push.tokenChanged`. Firebase runs only in configured hosts; exact data-only sync hints use the existing native sync without touching OTA state. Android notification images use FCM background display; foreground messages reach the page. **Device validation is blocked: needs Firebase project. iOS/APNs is experimental and untested.** Existing hosts must add the additive schema, regenerate, configure Firebase and ship a store build. Unicode line separators are escaped in event/reply scripts without changing JSON values.

Sync correctness: pull cursors advance only through returned rows, never push echoes or a later server-head max. Fresh pairs satisfy OTA activation only after all pages or static chunks complete. Progress resumes after an interruption. Pending publication retains the data lease; GC protects in-flight manifests and retries stale snapshots. Step 7 waits up to five seconds for ordinary sync. Outbox operations use a durable insertion ordinal; database version 2 migrates legacy queued ids, values and deletes without changing bucket cursors or user rows.

## Unreleased - native HTTP and REST adapter

Call your API with `http.request` (schema 4): the host enforces compiled `http.origins` origins, attaches the stored token, and never follows redirects. Existing hosts need codegen and a store build to add the capability or origins. A reference Node REST-to-sync adapter demonstrates durable pagination, tombstones and idempotent pushes. iOS remains experimental and untested.
## Unreleased - lifecycle, connectivity and update status

Bridge version 6. `ValenceApp` maps Flutter's five lifecycle states onto four and emits `app.lifecycle`
only on a change (`hidden` and `paused` are both `background`, because Android delivers both for one
backgrounding); it emits `app.online` from the connectivity it already watched, reading the current
value at start-up rather than waiting for a change; and it emits `sync.done` with the whole
`ValenceSyncResult` after every completed run, after `sync.changed` for the same run.
`Valence.appState()` and `Valence.bundleStatus()` back the new `app.state` and `bundle.status`
built-ins and never start a request. Every stop in the §2.3 check now records a `ValenceBundleReason`,
so a page can tell a rollout gate from a release waiting for its data from a release no device will
take. Persist on `background`, not `detached`. iOS remains experimental and untested.

## Unreleased: offline tooling

- Add schema-3 data.getMany and sync.status, and optional SyncResult.pending. Regenerate an additive schema and guard the new methods on older hosts.
- Seed multiple declared read-only schemas using seedSchemas and versioned files; the runtime imports each declared pair.
- OTA bundle bridge requirements now default to the recorded store baseline. Guard newer methods; explicitly pin lower if older store builds remain supported. Built-in/store defaults still use the current schema.
- Compile ota.channel and generate opt-in BridgeHandlersDefaults for test doubles.
- Run mechanical doctor diagnostics and mapped unit tests without an interactive session. Unexecuted evidence stays WARN.
- Constrain path_provider_android to the pre-JNI range >=2.2.17 <2.3.0 while compatibility is validated (U-7, 2026-10-21).

## 0.4.0-beta.0

First release. The Flutter host runtime that `/valence init` used to generate into every app now ships as
a package, so a fix reaches every adopter with `flutter pub upgrade` instead of being hand-applied.

Implements contracts.md:

- **§2.3, §2.4** — the canonical manifest check order, the activation state machine with its two-strike
  rollback, roll-forward, and garbage collection that keeps `current`, `previous`, `pending`, `trial` and
  the built-in bundle. Step 7 **pulls** the `requires.data` pairs a bundle needs, under the §5.6 lease.
- **§3** — the loopback server: a per-install port in 10000..29999, a per-launch nonce in the entry page,
  the three serving branches in their contractual order with the reserved `/_host/` prefix matched first,
  path normalisation, and lazy content-addressed integrity re-checking.
- **§4.4** — secure storage and the bearer token: `secure.get/set/delete` over the Android Keystore and
  the iOS Keychain, `auth.setToken` / `auth.hasToken` keeping the token at the reserved
  `valence.auth.token` where the page cannot read it back, `Authorization: Bearer` on every writable
  bucket's pull and push, and `auth.expired` plus `ValenceSyncReason.unauthorized` on a 401. Needs
  `minSdk 23` on Android.
- **§4.2** — the strict decoders, the closed error-code set, the 256 KB UTF-8 message cap in both
  directions, and event scripts built only through `jsonEncode`.
- **§5** — the SQLite store with the pragmas through `rawQuery`, a never-closed connection shared across
  isolates, the seed import counted with `changes()`, per-`(bucket, schema)` storage, the outbox, pull
  paging, push with its echo skip, and the sync lease.
- **§3 back gesture, console capture and resume** — `PopScope` asking the WebView first,
  `setOnConsoleMessage` plus the page callbacks, and port reclaiming on resume that keeps the nonce when
  the same port comes back.

Also here, and not in the generated hosts it replaces:

- `ValenceConfig.authToken`, so an app with its own refresh loop in Dart can own the token instead;
  when it is unset, the host uses whatever the page stored through `auth.setToken`.
- `ValenceConfig.syncMode: staticChunks`, the CDN-only pull from §5.3's static variant.
- `ValenceConfig.databaseName`, so a 0.3 app whose generated host chose its own file name keeps its data.
- `Valence.publishHostFile`, the only path from native bytes to the page.
- `Valence.pendingWrites()`, which counts queued deletes a `usn == -1` scan cannot see.

Corrections an independent review found before this first release, each with a regression test:

- **A writable bucket is pulled as well as pushed**, at schema 1. It can never appear in a manifest’s
  `requires.data`, so a host that pulls only those pairs leaves user data push-only: a second device
  never sees a row, and a reinstall comes back empty.
- **A mid-session reload runs §2.4 step 4 only.** Re-running the UI-start transitions made
  `bundle.applyUpdate` spend a strike on the bundle it was promoting, and made a ready timeout re-serve
  the failing trial instead of `current`.
- **Garbage collection keeps the files of a download in flight.** Step 6 writes CAS before step 8 writes
  the manifest, so a collection in that window could delete what had just been fetched — after which
  nothing re-fetched it and a healthy release failed its trial twice.
- **A refused built-in bundle is remembered by its manifest bytes and the host’s bridge version**, not by
  its seq, so the host upgrade that fixes a check-5 mismatch is not skipped by the record meant to save
  work. The seq gate also runs before the verify, so an ordinary launch does not check a signature.
- **A corrupt file of the *active* bundle is re-fetched** by a repair pass before step 1. Step 1 stops
  before step 6 for a bundle that is already `current`, so a rotted entry page was a permanent blank
  screen.
- **The seed is extracted once per host build**, not on every launch in front of the first frame.
- **`ValenceStore` enforces the reserved `valence.` pref prefix itself**, so an app that defines its own
  settings method cannot become a route to the sync lease.

284 tests. `dart analyze --fatal-infos` clean. `flutter pub publish --dry-run` has 0 warnings.

Firebase dependencies now require iOS 15.0 or later, even with push disabled. Upgrade Runner/extension target settings; iOS remains experimental and untested.

Bridge success and error reply caps now include Unicode separator escaping; oversized errors retain only safe numeric correlation ids.
