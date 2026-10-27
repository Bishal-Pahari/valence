# Changelog

## Unreleased: development mode identifies skipped OTA operations

Debug hosts now log the upstream origin and disabled OTA behavior at startup. Calls to ready,
signed reload, update checks and applyUpdate log their development bypass rather than appearing
silent. Restart without VALENCE_DEV_URL to validate signed offline starts and rollback. No
schema, package version or host setup changes are required.

## Unreleased: explicit LAN development trust

- `valence dev` now binds loopback by default. A LAN address or hostname requires
  `--allow-lan`; that mode binds all interfaces and names the cleartext full-bridge
  risk before starting. Add the flag to existing physical-device dev commands.
  Manual Flutter defines remain explicit trust grants; release/profile exclusion
  is unchanged. Refresh vendored tooling when upgrading.


## Unreleased: capability and status fields

Schema 15 adds nullable builtins, persisted sync reason and signed pending urgency. Regenerate and ship a store build; declaring builtins also requires current optional params on declared built-ins. Earlier hosts and schemas keep working. Account changes clear the new sync observation.

## Unreleased: dev-mode and plugin hardening

- `Valence.emit` enforces the §4.2 256 KB envelope cap, so an oversized event — now possible because
  §4.10 lets a plugin emit one — is dropped with a log line instead of killing the WebView and spending
  a trial strike.
- A test asserts every `VALENCE_DEV_URL` read in `lib/` is guarded by `kDebugMode` in the same
  expression, which is what makes the §3.1 dev path compile-time absent from release builds.
- `tool/check-release-dev.mjs` matches app-bundle AOT paths (`base/lib/<abi>/libapp.so`) as well as APK
  ones.

## Unreleased: account-switch hardening (§4.4)

- `Valence.dataPut` throws `E_INTERNAL` for the duration of an account transition, which now spans the
  sync-lease wait as well as the clear. Writes already in flight are drained before `clearWritable`, so
  one cannot commit after the delete and be pushed under the next account's token.
- `ValenceStore.clearWritable` no longer returns early on an empty bucket set: the outbox check, the
  outbox delete and the sync-observation reset are not bucket-specific and always run. Only the
  `kv`/`bucket` deletes are conditional.
- `auth.setToken` records the account id before writing the token on the non-switch paths too, matching
  the switch, so an interrupted adoption cannot leave a token with no recorded identity.

## Unreleased: task restoration

Task restoration now checks the native account before loading a restored route, clears drafts on account switch/sign-out and refuses late route captures from the previous account. Refresh and first-account adoption keep the live draft.

Schema 8 adds `state.save({json})` and `state.restore()` for a task-local UI blob (65,536 JSON UTF-8 bytes). ValenceApp restores the local path/query/hash after OS process reclamation. Explicit task closure starts fresh; a different bundle seq clears the snapshot. Save promptly and keep durable records in SQLite. iOS is experimental and untested.

## Unreleased - permissions (R3)

- Added schema-9 permission checks, serialized foreground requests, app settings and resume changes. Hosts opt in with `permissions.kinds`, native declarations, codegen and a store build. Android checks preserve uncertain denial; iOS remains experimental and untested.

## Unreleased - local reminders

Schema 11 adds built-in local reminders: notify.schedule/cancel/pending/channels.set, notify.permission, consuming notify.initial, notify.tapped/notify.action and best-effort badge.set/clear. Opt in with notifications.enabled, regenerate, install native receivers/icon/desugaring and ship a store build. Exact requests report downgrades honestly; one-shot epoch times need no device timezone lookup. Images are bounded PNG/JPEG bytes; every action opens the UI. iOS is experimental and untested. Android hosts now need core library desugaring even when the feature is disabled, because the native plugin ships with the runtime. Existing custom notification IDs must be coordinated; pre-schema-11 custom methods retain their shipped shapes and app-owned handlers.


## Unreleased - remote push

Remote push is opt-in in schema 12: `push.token`, passive/explicit `push.permission`, consuming `push.initial`, `push.received`, `push.tapped` and `push.tokenChanged`. Firebase runs only in configured hosts; exact data-only sync hints use the existing native sync without touching OTA state. Android notification images use FCM background display; foreground messages reach the page. **Device validation is blocked: needs Firebase project. iOS/APNs is experimental and untested.** Existing hosts must add the additive schema, regenerate, configure Firebase and ship a store build. Unicode line separators are escaped in event/reply scripts without changing JSON values.

## Unreleased: image sharing

`Valence.shareImage` backs schema-14 `share.image` with capped base64 input or a
re-verified active signed bundle image, filename and caption validation, and native
PNG/JPEG sharing through `share_plus`. Selection is not proof of delivery.
iOS remains experimental and untested. Add the method through codegen and a store
build; existing custom pre-14 declarations retain their own handlers.

Sync correctness: pull cursors advance only through returned rows, never push echoes or a later server-head max. Fresh pairs satisfy OTA activation only after all pages or static chunks complete. Progress resumes after an interruption. Pending publication retains the data lease; GC protects in-flight manifests and retries stale snapshots. Step 7 waits up to five seconds for ordinary sync. Outbox operations use a durable insertion ordinal; database version 2 migrates legacy queued ids, values and deletes without changing bucket cursors or user rows.

## Unreleased - native HTTP and REST adapter

Call your API with `http.request` (schema 4): the host enforces compiled `http.origins` origins, attaches the stored token, and never follows redirects. Existing hosts need codegen and a store build to add the capability or origins. A reference Node REST-to-sync adapter demonstrates durable pagination, tombstones and idempotent pushes. iOS remains experimental and untested.
## Unreleased - account switching is safe

Schema version 13. `Valence.authSetToken` takes `account` and `discardPending`, and `Valence.authAccount()`
is new. Recording a different opaque account id, or signing out with one recorded, clears every writable
bucket's rows, `max_usn` cursor and the whole outbox in one transaction under the sync lease, before the
new token is stored, and emits `sync.changed` for those buckets. It throws the new `E_PENDING`
(`BridgeErrorCode.pending`) and changes nothing while the outbox is not empty, unless `discardPending` is
set; it fails with `E_INTERNAL` rather than clearing underneath a sync that holds the lease, and it keeps
the lease until the new token is written, so a sync starting in between cannot pull the previous
account's rows back under the previous account's token. Only `null` is the sign-out — an empty token
clears the token and no data. A refresh of the recorded id, a first id with none recorded, and an app
that never passes one all clear nothing, so a host upgrade cannot wipe an existing user's data. An
account id the Keystore cannot return throws `E_INTERNAL` instead of reading as "none recorded", which
would have made the next sign-in an adoption over the previous account's rows. iOS remains experimental
and untested.

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

- Native extensions can implement `ValencePlugin`, with namespaced schema fragments
  and matching npm types. Generated adapters keep strict decoding; the built-in
  open group uses the same registry without allowing its owner to be replaced.
  The example haptic handler is now a separate local plugin package.

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

## Unreleased - adaptive layout and accessibility

ValenceApp requests edge-to-edge layout, publishes system-bar/cutout inset CSS variables on load and metrics changes, follows Android system text zoom and emits schema-7 app.appearance snapshots. Add optional AppInfo.fontScale: "num?" and regenerate; old schemas remain supported. Existing pages must pad content/fixed controls using the variables and avoid double-scaling Android text. Custom hosts can pass their FlutterView to Valence.attach for matching font-scale reporting. iOS root-font scaling remains experimental and untested.

Firebase dependencies now require iOS 15.0 or later, even with push disabled. Upgrade Runner/extension target settings; iOS remains experimental and untested.

Bridge success and error reply caps now include Unicode separator escaping; oversized errors retain only safe numeric correlation ids.
