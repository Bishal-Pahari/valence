# Changelog

## Unreleased: capability and status fields

Schema 15 adds nullable builtins, persisted sync reason and signed pending urgency. Regenerate and ship a store build; declaring builtins also requires current optional params on declared built-ins. Earlier hosts and schemas keep working. Account changes clear the new sync observation.

## Unreleased: a published plugin installs without editing it

- **A `plugins` entry can be `{path, since}`,** stamping each of a fragment's methods and events with
  an app bridge version. `since` is an app version, so no fragment shipped in a pub package could
  carry a number right for every app that installs it: a published plugin was installable only by
  editing a file inside `~/.pub-cache` or copying the fragment into your repo and re-stamping it per
  app. Nothing changes for a fragment that stamps itself; the two forms are exclusive per entry, and a
  stamp naming something the fragment does not declare is an error. The example's haptics plugin now
  uses the published form, which is the shape to copy.

## Unreleased: hardening the two newest trust boundaries

Review of the combined feature merge found no broken security path in live development (R9) or native
plugins (R10) — release builds really do exclude the dev server, and a plugin really cannot redefine a
built-in. These are the gaps around them.

- **An event over the 256 KB cap is now dropped instead of sent.** Replies were measured and events were
  not, because every built-in payload is small and host-bounded. Plugins made an event payload arbitrary,
  and an oversized one kills the WebView — which, if a trial bundle is on screen, spends one of its
  strikes and can get a healthy bundle marked bad.
- **A plugin fragment path must stay inside the project.** `..` was accepted, so a build could depend on
  a file outside the repo and the reviewed schema recorded in `.valence/baseline.json` would have no
  source in it.
- **The dev-server guard now has a test.** Release exclusion rests on each read of `VALENCE_DEV_URL`
  being a `kDebugMode` compile-time constant. Removing one left every suite green, with the dev proxy
  live in the release snapshot; a package test now fails instead, and the release workflow says to run
  `check-release-dev.mjs` against the artefact you submit.
- `check-release-dev.mjs` also reads app bundles (`base/lib/<abi>/libapp.so`), not just APKs. It is the
  bundle you upload to Play.

## Unreleased: three more ways an account switch could leak across accounts

All three are §4.4 hardening, found by review of the account work. None needs an app change.

- **A `data.put` during a switch is now refused** with `E_INTERNAL`, for the whole transition including
  the wait for the sync lease. The lease ordered a switch against sync and nothing ordered it against a
  local write, so a write from the outgoing account's page could commit after the clear and be pushed
  under the incoming account's token. A write already running is now allowed to finish before the clear
  rather than after it. If you fire writes while awaiting `auth.setToken`, disable the form for the
  duration and make a refused write again afterwards — nothing was stored.
- **The `E_PENDING` guard no longer depends on having a writable bucket.** A host whose `writable` set
  had become empty skipped the outbox check entirely, so a switch succeeded silently over queued writes
  and kept them — to be pushed under the new account's token the day a writable bucket came back.
- **The account id is written before the token on every path**, not just on a switch. On an adoption the
  old order could lose the id and keep the token, which made the next sign-in as somebody else look like
  another adoption rather than a switch — leaving the first account's rows and queued writes in place
  under the second account's token.

## Unreleased: the bridge tarball is built from its own source

`@getvalence/bridge` ships compiled output (`dist/`), which is build output and not in git. Nothing made
`npm pack` or `npm publish` rebuild it, so either could tarball a stale `dist/` under a current version
number — two different APIs behind one version string. A `prepack` hook now runs the build, so the
published package always matches the source it claims to be.

If you ever saw `TS2554: Expected 1 arguments, but got 2` inside your generated `bridge.g.ts`, that was
this: your installed bridge predated event gating while your generated file expected it. Upgrade the
package rather than silencing the error — JavaScript drops the extra argument, which would leave `has()`
answering `false` for every event on every host. The release recipe no longer needs a separate
`npm run build`.

## Unreleased: task restoration

Task restoration now checks the native account before loading a restored route, clears drafts on account switch/sign-out and refuses late route captures from the previous account. Refresh and first-account adoption keep the live draft.

Schema 8 adds `state.save({json})` and `state.restore()` for a task-local UI blob (65,536 JSON UTF-8 bytes). ValenceApp restores the local path/query/hash after OS process reclamation. Explicit task closure starts fresh; a different bundle seq clears the snapshot. Save promptly and keep durable records in SQLite. iOS is experimental and untested.

## Unreleased: deep links

Open local screens from Android App Links or custom schemes with schema-9
`link.initial`, `link.opened` and the web `onLink()` helper. Regenerate the bridge,
compile `links.origins` and add matching native registrations in a store build.
Existing hosts remain supported; OTA cannot expand accepted origins. New
`assetlinks` and `aasa` commands write website association documents for separate
HTTPS hosting. iOS is experimental and untested. See [setup](docs/deep-links.md).

## Unreleased - permissions (R3)

- Added schema-9 permission checks, serialized foreground requests, app settings and resume changes. Hosts opt in with `permissions.kinds`, native declarations, codegen and a store build. Android checks preserve uncertain denial; iOS remains experimental and untested.

## Unreleased - local reminders

Schema 11 adds built-in local reminders: notify.schedule/cancel/pending/channels.set, notify.permission, consuming notify.initial, notify.tapped/notify.action and best-effort badge.set/clear. Opt in with notifications.enabled, regenerate, install native receivers/icon/desugaring and ship a store build. Exact requests report downgrades honestly; one-shot epoch times need no device timezone lookup. Images are bounded PNG/JPEG bytes; every action opens the UI. iOS is experimental and untested. Android hosts now need core library desugaring even when the feature is disabled, because the native plugin ships with the runtime. Existing custom notification IDs must be coordinated; pre-schema-11 custom methods retain their shipped shapes and app-owned handlers.


## Unreleased - remote push

Remote push is opt-in in schema 12: `push.token`, passive/explicit `push.permission`, consuming `push.initial`, `push.received`, `push.tapped` and `push.tokenChanged`. Firebase runs only in configured hosts; exact data-only sync hints use the existing native sync without touching OTA state. Android notification images use FCM background display; foreground messages reach the page. **Device validation is blocked: needs Firebase project. iOS/APNs is experimental and untested.** Existing hosts must add the additive schema, regenerate, configure Firebase and ship a store build. Unicode line separators are escaped in event/reply scripts without changing JSON values.

## Unreleased: live development

- `valence dev` starts a Vite-compatible development script and prints the Flutter debug command.
- Debug builds can proxy the explicitly chosen server through the owned loopback origin, with
  the typed bridge and HMR WebSockets working together. No schema or version bump is required.
- Release/profile builds exclude the path even with the define supplied. Dev mode preserves
  OTA trial state, disables updates and blocks workers. Use separate dev app ids and test accounts.

## Unreleased: image sharing

Schema-14 `share.image` shares a PNG/JPEG with a caption from capped inline bytes
or the active signed bundle. Regenerate and ship a store build to add it; use
`has()` on older hosts. Existing custom methods declared before schema 14 keep
their signature and handlers. Results describe native selection, not delivery.
The iOS path is experimental and untested. Package versions are unchanged.

Sync correctness: pull cursors advance only through returned rows, never push echoes or a later server-head max. Fresh pairs satisfy OTA activation only after all pages or static chunks complete. Progress resumes after an interruption. Pending publication retains the data lease; GC protects in-flight manifests and retries stale snapshots. Step 7 waits up to five seconds for ordinary sync. Outbox operations use a durable insertion ordinal; database version 2 migrates legacy queued ids, values and deletes without changing bucket cursors or user rows.

## Unreleased

### System layout and accessibility

ValenceApp now requests edge-to-edge layout and publishes system-bar/cutout insets as CSS variables. Existing pages must apply them to content and fixed controls. Android text zoom follows system font size. Codegen supports optional AppInfo.fontScale without changing old schemas; schema 7 adds app.appearance (dark mode, high contrast, reduced motion). Add its schema entry, regenerate and ship a host update. iOS root-font scaling is experimental and untested; the guide covers its limits.
## Unreleased: account switching is safe

Schema version 13. `auth.setToken` takes two more params and `auth.account()` is new, because a token is
replaced far more often than a user changes and the host could not tell the two apart.

- **`auth.setToken(token, {account})`** records your own opaque id for the user beside the token. The
  same id again is a refresh and does nothing else. A **different** id, or `auth.setToken(null)` with an
  id recorded, is an account switch.
- **A switch refuses to run over queued writes.** It throws the new **`E_PENDING`** and changes nothing —
  not the token, not the id, not a row. The host attaches whatever token is stored at the moment it makes
  the request, so a switch over a full outbox would have pushed user A's rows under user B's credentials
  from a background sync minutes later. `{discardPending: true}` is the only way past, and it deletes
  those writes unsent.
- **A switch clears every writable bucket** — rows, `max_usn` cursor and the whole outbox, in one
  transaction, under the sync lease, *before* the new token is stored — and emits `sync.changed` for
  them. Read-only buckets, prefs and your own `secure.*` keys are untouched. The wipe is local: no
  tombstone is pushed, so user A's rows stay on your server.
- **Nothing changes for an app that does not pass `account`.** Sign-out keeps the 0.3 behaviour exactly
  (the token goes, the rows stay), and the first call that names an id when none is recorded *adopts* it
  and clears nothing — otherwise upgrading would wipe the data of the user holding the phone.
- **`null` is the sign-out; an empty string is not.** `auth.setToken('')` clears the token and no data,
  exactly as before. And check your `auth.expired` handler before you adopt `account`: if it signs the
  user out, that call becomes a wipe of the user who is about to log straight back in. Refresh the
  token instead, which is what the 401 rule has always asked for.
- **Gate the params on `has('auth.account')`,** never on `app.info().bridge`. They are params, so they
  have no `since` of their own, and an older host rejects them with `E_PARAMS`. `valence codegen` refuses
  to emit them without `auth.account` declared beside them.

**What you must do:** nothing, unless your app can be used by more than one person on one device. Then
add the two params and `auth.account` to `valence/bridge.schema.json` at your next version, regenerate,
and pass `account` on sign-in.

## Unreleased: lifecycle, connectivity and update status

Bridge version 6. Three events and two methods for the three questions a page in a browser tab answers
from the platform and a page in the host cannot.

- **`app.lifecycle`** fires on the way *out* as well as in, with four states — `foreground`,
  `background`, `inactive`, `detached` — mapped from Flutter's five. Android delivers `hidden` and then
  `paused` for one backgrounding, so both are `background` and only changes are emitted. Persist on
  `background`: `detached` usually never arrives, because the engine is tearing down and there may be no
  WebView left to run the script. `app.resumed` is unchanged.
- **`app.online`** reports what the OS says about network *interfaces* — the same source as the
  "connectivity came back" sync trigger — and is explicitly **not** reachability. Use it to decide
  whether to *try*; use `SyncResult.reason` or `sync.status().offline` to say whether the last attempt
  worked.
- **`app.state()`** returns both current values, for a page that mounts after the transition: a cold
  start from a notification tap, or the reload an applied update does.
- **`sync.done`** carries the whole `SyncResult` after every completed run the host made on its own,
  including `changed: 0`, `busy` and `unauthorized`. `sync.changed` is silent when a run moved nothing,
  and most runs move nothing, so a "last synced" line could previously only be updated by a sync the page
  asked for itself.
- **`bundle.status()`** says why an update declined, from a closed set: `idle`, `unconfigured`,
  `uptodate`, `rollout`, `bad`, `offline`, `rejected`, `toobig`, `waitingForData`, `busy`, `ready`,
  alongside `serving`, `pending`, `trial`, `offered` and `checkedAt`. It never starts a request.
  `rejected` means a published release is unservable on every device and is worth an alert of your own;
  `waitingForData` is a healthy state that can last for days on an offline device, and is the one four
  hosts mistook for "no update".
- **`bundle.updateReady` now fires for every pending bundle,** not only one released with `--urgent`.
  It is the push signal that pairs with `bundle.status()`, and `bundle.applyUpdate` has never required
  `urgent`, so gating the event on the flag left a page with nothing but polling — and polling on
  resume races the update check, which finishes a few hundred milliseconds after the read. The result
  was that a page learned about an update on the resume *after* the one that found it.
  **What you must do:** nothing, unless you relied on the event meaning "urgent". Read
  `bundle.status()` on mount and re-read it on `bundle.updateReady`; `urgent` is now purely the
  release's request to be offered mid-session, which your page decides how to honour.
- **A data-cap stop reports `toobig`, not `waitingForData`.** When the configured `dataSizeCap` ran out
  *inside* a pair's pull rather than before it, `bundle.status().reason` blamed unavailable data for
  what was the app's own limit — and sent you to inspect a server that was answering correctly.
- **`has()` now answers for events too, not only methods.** `on()` for an event an older host has never
  heard of subscribes happily and then never fires: nothing throws, nothing logs, and the feature behind
  the listener quietly stops happening. Gate the *feature*, not the subscription. On the web `has()` is
  false for every event, since there is no host to emit one, so one branch covers both an old host and
  the website build. **What you must do:** regenerate — `bridge.g.ts` now passes `EVENT_SINCE` to
  `createBridge` alongside `METHOD_SINCE`, and that second argument is **required**. Upgrading the
  package without regenerating is a build error naming the file to regenerate, rather than `has()`
  quietly answering `false` for every event on every host.
- **Two new `codegen` refusals, both closing a silent gate.** Declaring `data.list`'s `after` without
  also declaring `data.count` is refused: the sibling *is* the gate, so without it `has('data.count')`
  is false on every host you will ever ship — including the ones that accept the cursor — and a page
  following the docs never pages at all. And one name may no longer be both a method and an event,
  because `has()` resolves a name to one answer and would otherwise report `false` for an event your
  host really does emit.
- **`data.list`'s `after` cursor advances past an empty first key.** `''` is a valid key — `data.put`
  refuses only `.` and `..` — and the host was reading `after: ''` as "no cursor", so a bucket whose
  first key was empty returned that same row on every page and could never be read completely.

**What you have to change in your own host:** nothing, if you leave the schema alone. To take the five,
add them to `bridge.schema.json` with `since: 6`, raise `version` to 6 and regenerate — the `valence`
package implements all of it, so no handler is yours to write. A page must treat a `reason` it does not
recognise as "no update right now" rather than an error, because a newer host can return one that did
not exist when the bundle was built.

## Unreleased: offline tooling

- Add schema-3 data.getMany and sync.status, and optional SyncResult.pending. Regenerate an additive schema and guard the new methods on older hosts.
- Seed multiple declared read-only schemas using seedSchemas and versioned files; the runtime imports each declared pair.
- OTA bundle bridge requirements now default to the recorded store baseline. Guard newer methods; explicitly pin lower if older store builds remain supported. Built-in/store defaults still use the current schema.
- Compile ota.channel and generate opt-in BridgeHandlersDefaults for test doubles.
- Run mechanical doctor diagnostics and mapped unit tests without an interactive session. Unexecuted evidence stays WARN.
- Constrain path_provider_android to the pre-JNI range >=2.2.17 <2.3.0 while compatibility is validated (U-7, 2026-10-21).

Newest first. One version for `create-valence`, `@getvalence/bridge` and the `valence` pub package.

## Unreleased

### Reusable native plugins

`doctor` checks the combined app/plugin schema against the store baseline, so
a shipped plugin is accepted while changing or removing it still fails. After
upgrading tooling or the bridge, regenerate and type-check with a matching
CLI/bridge snapshot pair.

`ValencePlugin` packages can contribute namespaced schema fragments, native
handlers and setup notes, with matching npm types. Config `plugins` lists the
fragments; codegen and bundle merge them before compatibility checks. Conflicts,
reserved namespaces and changes to shipped definitions fail. Generated dispatch
still checks the nonce and strictly decodes parameters/results. Native additions
need a store build. The built-in open group uses the plugin API, and the example
haptic handler is a separate local package. Existing wire shapes stay unchanged.

### Calling your own backend

Call your API with `http.request` (schema 4): the host enforces compiled `http.origins` origins, attaches the stored token, and never follows redirects. Existing hosts need codegen and a store build to add the capability or origins. A reference Node REST-to-sync adapter demonstrates durable pagination, tombstones and idempotent pushes. iOS remains experimental and untested.

Everything below is unpublished. Two headlines: an app can finally log a user
in, and the runtime is two published packages instead of generated code. Under
them are the test-week fixes, logged by four independent teams who built Android
apps from the public docs and wrote down what broke. The version for this batch
is the maintainer's call.

### Logging a user in, at last

Until now an app with private synced data had no auth story at all: four test
apps needed one, none got past it cleanly, and the workarounds all came down to
a token in the `prefs` table — plain text, inside a database meant to be backed
up — that the background sync could not reach anyway.

0.4 adds the smallest thing that actually works, **bring your own token**. You
keep your own login: the web app authenticates against your API however it
already does, then hands the host the token.

```ts
await call('auth.setToken', { token });
```

From then on the host attaches `Authorization: Bearer` to every pull and push of
a **writable** bucket, including the runs it makes by itself on resume, on
reconnect and in the background — which is the whole point, because those happen
while your JavaScript is not running. Public read-only buckets stay
unauthenticated, so a CDN can still serve them.

- **The token is stored in the Android Keystore** (an AES-GCM record with a
  hardware-wrapped key, `minSdk 23`) or the **iOS Keychain** (experimental and
  untested, like every iOS path here), never in SQLite.
- **The page can never read it back.** It lives under the reserved `valence.`
  prefix, which `secure.get` refuses, so `auth.setToken` and `auth.hasToken`
  are the whole surface. There is deliberately no `auth.getToken`.
- **A 401 is reported as a 401:** the new `auth.expired` event fires once per
  sync run and `SyncResult.reason` is `"unauthorized"` — not `"ok"`, which a
  freshness indicator reads as "up to date", and not `"offline"`, which would
  have the page wait for connectivity it has. The token is kept, because a
  refresh flow usually has to present the expired one, and queued writes stay
  queued.
- **`secure.get` / `secure.set` / `secure.delete`** are open to your app for
  other short secrets. `secure.set` takes a non-null value on purpose:
  `secure.delete` is the only delete, so clearing a credential says so at the
  call site.
- **`ValenceConfig.authToken` still wins when you set it**, so a host with its
  own refresh loop in Dart is unaffected.

**To take it, add five methods and `auth.expired` at `since: 2` and bump your
schema `version` to 2** — they are built-ins, so there is no handler to write.
That moves `requires.bridge` to 2, so the next OTA release needs the matching
store build; `valence bundle --requires-bridge 1` buys one more release for the
hosts already out there. The [Login and secrets](https://getvalence.pages.dev/docs/guides/auth/)
page has the details, including what Valence deliberately does not do: it is not
an identity provider, there is no per-request scoping, and logging out does not
wipe the rows already on the device.

### The runtime is two packages now

The biggest change since 0.1. `/valence init` used to **generate** about 1,500
lines of Flutter host into every app, plus a `client.ts` into every web app.
Every app therefore carried its own copy of the OTA verification, the rollback
state machine and the bridge trust boundary — and during test week one bug in
the rollback loop had to be fixed by hand in four separate apps.

- **[`valence`](https://pub.dev/packages/valence) on pub.dev is the whole Flutter
  host:** the loopback server and its nonce, the canonical check order, the
  activation state machine and its rollback, signature and manifest
  verification, the SQLite store and its pragmas, the seed import, sync with its
  lease, strict bridge decoding, and the WebView with its navigation lock, back
  gesture and console capture. The contracts §8 matrix is its own test suite.
- **[`@getvalence/bridge`](https://www.npmjs.com/package/@getvalence/bridge) on
  npm is the whole web client:** `call`, `has`, `on`, `ready`, `connect`,
  `installShim`, `inHost` and `BridgeError`. ESM, zero runtime dependencies.
- **`valence codegen` emits only the app-specific half** — the typed method and
  event tables, the payload types, `bridgeDispatch`, `BridgeEvents`,
  `valenceConfig`, and a `ValenceBuiltins` base class that delegates `app.*`,
  `data.*`, `prefs.*`, `sync.*`, `open.external` and `bundle.*` to the runtime.
  Your `main.dart` is about twenty lines and your handlers class holds only
  methods that are genuinely native to your app.
- **A fix now ships once.** `flutter pub upgrade valence` and
  `npm update @getvalence/bridge` are how it reaches you.
- **The wizard, the skill and the builder agent add the packages** instead of
  generating code, and the reviewer treats a vendored or reimplemented runtime
  as a finding in its own right.
- **A built-in method may be omitted from your schema but not redefined.** An
  app that never syncs can drop `sync.now`. One that keeps the name and changes
  the shape would compile and then pass the wrong arguments to the runtime, so
  `codegen` refuses it and names the shape it must keep.

**Migrating from 0.3 is one documented pass** —
[docs/migrating-from-0.3.md](docs/migrating-from-0.3.md). Your SQLite data, your
outbox, every pair's `max_usn`, `state.json` (including a device mid-trial), your
CAS files, your `installId` and your signing key all carry over untouched; the
package's test suite covers that. If your 0.3 host named its database something
other than `valence.db`, one config line keeps it. Swapping the runtime is a
store release, because `lib/` changed.

### One OTA could retire the bundle inside your APK, silently

- **`valence bundle --floor N` now refuses an `N` above your store build's
  `seq`.** The floor applies to the built-in bundle too, which the spec left to
  inference. That bundle is the one artifact every device is guaranteed to
  have — what a wiped or offline phone falls back to, and the only code a store
  review ever saw — so raising the floor past it retired **both** fallbacks a
  device had, from the client side, with no store release. §2.4's ladder was left
  with `current` and nothing underneath, and if that bundle later failed a check
  the only recovery was a store release above the floor: a full review cycle,
  which is exactly what OTA exists to avoid.

  Nothing warned. `verify` was happy, `doctor` was green, and `baseline.json`
  held the number that made it checkable in the file the CLI had just written.

  **What you must do:** nothing, unless a build starts failing — in which case
  the message names your store build's seq and the two ways forward. Raising the
  floor *to* that seq is still allowed and is almost always what you want: it
  strands every OTA below it and keeps the APK runnable. If you already have a
  floor above your store seq, you get a warning rather than a refusal, because
  the floor carries forward on its own and refusing would make every later
  release unbuildable.
- **The reference REST adapter refuses item keys of `.` and `..`.** Those two
  survive `encodeURIComponent`, so URL resolution strips them as dot segments:
  `/items/..` resolves to `/`. An accepted push would have sent an authenticated
  `PUT` or `DELETE` to the upstream's root or collection endpoint. Found by an
  independent review.

### Smaller things the migration got wrong

- **Migration step 2 now covers the `pub add` failure.** An app using
  `flutter_local_notifications` cannot resolve `valence`, because
  `connectivity_plus` wants `dbus ^0.8.0` and the notifications plugin's Linux
  implementation wants `^0.7.8` — two Linux-only packages an Android build never
  compiles. The host guide documented it; the migration page, which is where you
  are standing when it happens, did not. The `dependency_overrides` fix is now
  next to the `flutter pub add` line.
- **`BridgeError`'s import is in the docs.** 0.3 generated it into your
  `bridge.g.dart`; 0.4 imports it from the package without re-exporting, so every
  file that throws one stops compiling with *"The name 'BridgeError' isn't a
  class"*. Add `import 'package:valence/valence.dart';` — the migration page's
  `handlers.dart` example now shows it.
- **`lastSyncedAt` reads `null` after migrating, and the docs say so.**
  `sync.status` is new in 0.4, so no 0.3 host wrote the timestamp: a migrated
  device reports `null` while holding a complete database, and the honest
  rendering of that is "Never synced" under current data. Treat `null` as "not
  known yet" rather than "never". It self-corrects on the first 0.4 sync.
- **A resume can arrive before start-up finishes.** On Android the lifecycle
  observer fires during the first launch, so a resume handler can run before the
  server, the store or the active bundle exists — and worse, can start an update
  check alongside the UI-start transition still in flight. `ValenceApp` now
  ignores a resume until start-up completes (it runs the same triggers itself at
  the end of start-up anyway), and §3 states the rule for hosts that build their
  own WebView.

### A bucket over 500 rows can finally be read completely

- **`data.list` takes an `after` cursor, and there is a new `data.count`**
  (schema version 5). `after` is the last key of the previous page, and the scan
  resumes strictly after it, so a bucket of any size has a complete read.

  The clamp itself was right — an unbounded reply kills the WebView, and that can
  roll back a healthy release — but with no way to page past it, **a bucket over
  500 rows had no complete read at all.** And the damage was not a short list: a
  truncated list is indistinguishable from a short one, so a stored key that
  happened to fall outside the first page read as a key the device had never held.
  One test app showed a first-run location chooser to a device that had been
  configured for days, because the user's saved place was row 600 of 912. A prefix
  is not a general answer; those keys were GeoNames ids and one prefix covered
  about 900 of them.

  `data.count(bucket, prefix?)` answers "how many does this device hold?" and "is
  this key space empty?" with one indexed count instead of paging every row's
  JSON.

  **What you must do:** regenerate, and page anywhere you call `data.list` without
  an explicit `limit`. **`has('data.list')` cannot gate `after`** — it is a new
  *parameter* on a method that has existed since version 1, so it is true on a
  host that will reject the unknown field with `E_PARAMS`. Gate on
  `has('data.count')`, the sibling method that ships in the same version.
  **Not on `app.info().bridge >= 5`:** that field is your app's *own* schema
  `version`, which you number yourself, so it is already above 5 in any app
  that has added five methods of its own — and the comparison is then true on
  exactly the hosts that reject the param. A grown param's only honest gate is
  a sibling method or event at the same version.
- **A built-in can now grow an optional *param*,** not just an optional returned
  field. Before this, a built-in's params were compared literally, so adding one
  would have failed the next `codegen` in every existing app — and `--rebaseline`,
  which overwrites the schema your store build recorded, would have been the only
  way through. An app that has not declared `after` keeps generating code that
  compiles; declaring it at the wrong type, under another name, or on a different
  built-in is still refused, and your own methods still may not grow a param once
  a store build has recorded them.

### Upgrading could silently start your users on an empty database

Found by an independent team migrating a live app holding 30.8 MB of synced
data. **If you are on 0.3, read this before you ship the upgrade.**

- **The package now moves a 0.3 database out of the documents directory.** 0.4
  opens `<applicationSupportDirectory>/<databaseName>`. 0.3's spec never named a
  directory — it said only "outside `valence/`" — so a 0.3 host could equally
  have used `getApplicationDocumentsDirectory()`, and on Android those are two
  different places (`files` and `app_flutter`).

  The bug: such a host, migrated exactly as documented, created a **new, empty**
  database beside the full one and showed the user a fresh install. No error, no
  warning, and `host.database` could not fix it, because that setting names the
  file and the problem was the directory.

  The package now looks for the database in the documents directory when the
  support directory has none, and moves it before opening anything — the `-wal`
  and `-shm` sidecars included, and the `.db` last. Moving the `.db` alone would
  discard every commit still in the write-ahead log, which for a syncing app is
  the last sync. It never overwrites a database that is already there, and it
  logs one line saying what it moved.

  **What you must do:** upgrade the package, then confirm your row counts on a
  device carrying real data — install over the top with `adb install -r`, never
  uninstall first. If you already wrote a move of your own in `main()`, you can
  delete it; the package will find nothing to do.

### A background sync could fail the launch that migrated the database

- **A locked database open is retried, and a blocked background run reports
  `busy` instead of failing.** A schema migration runs in `BEGIN EXCLUSIVE`, and
  the launch that runs it is the launch WorkManager fires your already-registered
  periodic job on — so on every app update the UI isolate and the background
  isolate race for the file, and the loser gets
  `DatabaseException(database is locked (code 5 SQLITE_BUSY))`. The sync lease
  cannot help, because the lease lives inside the database being opened.

  The package now retries a locked open five times a second apart;
  `Valence.backgroundSync` then returns `reason: "busy"` rather than throwing,
  because nothing was attempted and the isolate holding the file is itself about
  to sync. `Valence.open` still rethrows, because an app with no store cannot
  start. A failed open is also no longer cached, which used to leave every later
  call in that isolate failing against a database that was by then healthy.

  **What you must do:** nothing. `busy` in a background run on an upgrade launch
  is expected and not a bug to chase.
- **The host guide's `backgroundSync` example now compiles.**
  `Workmanager().executeTask` wants a `Future<bool>` and `backgroundSync` returns
  a `ValenceSyncResult`, so the one-line example did not build. The guide shows
  the whole callback, and says to return `true` even for an offline or empty run —
  `false` is WorkManager backoff, and the package already has better triggers
  (resume, connectivity) waiting.

### An OTA release could silently not happen, and the rollback could not tell

Found by an independent team's deliberate-break test, and the most important fix
in this batch. **Read the first bullet even if you read nothing else here.**

- **Bundle files are no longer served `Cache-Control: immutable`.** They go out
  `no-cache` with the file's sha256 as an `ETag`, and a revalidation that matches
  is a `304` with no body.

  The bug: a bundle file's URL does not change between releases. The path comes
  from your web build and the host keeps its port across launches, so
  `/assets/index-Ba1jK_XS.js` means *different bytes in every release that emits
  that name*. Told it could keep its copy for a year, the WebView did: the new
  bundle downloaded, verified and activated, and the page on screen was still the
  old one. Worse, the update log said `committed` — a trial only asks that *some*
  page call `ready()`, and the old page obliged. The rollback that protects you
  from a bad release was being satisfied by the release it was testing.

  **What you must do:** nothing, if you use the `valence` package — upgrade it.
  If you wrote your own host, change that header. Content-hashed file names are
  not a defence: anything copied verbatim out of `public/` keeps its name.
- **`valence bundle` warns when your output registers a service worker.** A
  service worker answers from Cache Storage without asking the host's server, so
  a precaching build reopens exactly the hole above. Inside the app you do not
  need one — the bundle is already on the device. Register it only when
  `inHost()` is false.
- **`ready()` is owed by every path that paints, not by your data load.** The
  rule was always "after the first meaningful paint", and everybody implements
  that at the end of the data load, because that is usually where the first paint
  is. A first-run gate, an empty state, a permission prompt and an error screen
  all paint without that load finishing — and on a fresh install one of them can
  be the whole first launch. The bundle then never reports ready, and two
  launches later healthy code is rolled back and it looks like the OTA is broken.

  **What you must do:** check which of your screens reach the call. Putting it in
  a `finally`, or in a mount effect every rendered path reaches, is enough. The
  docs and the startup example now show that shape.

### A sync that was blocked said it had succeeded

- **`SyncResult` has a new `reason`:** `"ok"`, `"busy"` or `"offline"`. A run the
  one-at-a-time lease refused to start used to come back `{changed: 0, offline:
  false}` — bit for bit "you are already up to date" — so an app showing
  freshness showed a confident "just synced" over data nothing had looked at.
- **A lease left by a launch that is gone is taken over, not waited out.** The
  lease now records the owning process. It only ever separates the UI and
  background isolates, which share a process, so a foreign owner can only be a
  crash or a force-stop; before this the next launch was blocked for the full two
  minutes, across several launches and resumes, each one reporting that same
  false freshness. Worst right after a crash, which is when a user is least
  forgiving.

  **What you must do, to take `reason`:** add `"reason": "string?"` to your
  `SyncResult` type in `bridge.schema.json` and run `codegen`. It is optional —
  leave it out and nothing changes. It counts as additive even against a schema a
  `--store` build already recorded, so you do not need `--rebaseline`.

  **It is nullable on purpose.** A method carries `since` and is gated by
  `requires.bridge`; a field on a type carries neither, and your host ships in the
  APK while your page ships in a bundle. So a bundle that reads `reason` will land
  on hosts built before the field existed, and those hosts do not send it. Drop
  the null check only once the store build that has it is the oldest you support.
  This is the first time a built-in has grown a field, and the rule is general.

### Also in the host

- **Garbage collection is scheduled for the first post-frame callback**, not run
  inside the transition. Step 1 already pays for a manifest decode, a signature
  verify and a per-file hash in front of the first frame, and this also stops a
  two-strike marking from deleting CAS files under the trial page still on
  screen. It takes the sync lease before touching read-only pairs.
- **A refused built-in bundle is remembered** (`state.builtinRefused`), so a
  broken store build stops re-verifying an Ed25519 signature on every launch,
  and logs the refusal once per process rather than once per launch.
- **The host logs every bridge error it returns.** A handler that threw used to
  be invisible to everybody: the page's `await call(...)` rejected inside an
  effect nobody awaited, and nothing reached a log or a screen.

### Found by an independent review of the new packages

Each of these has a regression test, and the spec carries the rule.

- **A writable bucket is pulled as well as pushed**, at schema 1. It can never
  appear in a bundle's `requires.data`, so pulling only those pairs left user
  data push-only: a second device never saw a row, and a reinstall came back
  empty.
- **A mid-session reload runs §2.4 step 4 only.** Re-running the UI-start
  transitions made `bundle.applyUpdate` spend a strike on the bundle it was
  promoting, and made a ready timeout re-serve the failing trial rather than
  `current` — so the user saw the broken bundle twice, 15 s apart.
- **Garbage collection keeps the files of a download in flight.** Step 6 writes
  into the content-addressed store before step 8 writes the manifest that keeps
  them, so a collection in that window could delete what had just been fetched,
  and nothing re-fetched it.
- **A corrupt file of the bundle being *served* is re-fetched** by a repair pass
  before step 1. There is no step 6 to reach for a bundle that is already
  `current`, so a rotted entry page was a permanent blank screen.
- **A refused built-in bundle is remembered by its manifest bytes and the host's
  bridge version**, not by its seq, so the host upgrade that fixes a check-5
  mismatch is not skipped by the record meant to save work.
- **The seed is extracted once per host build**, not on every launch in front of
  the first frame.
- **The reserved `valence.` pref prefix is enforced in the store**, so an app
  that defines its own settings method cannot become a route to the sync lease.

### You may need to change your host

- **`bad` is final, in every path.** A bundle marked bad could come straight
  back as a trial, so the two-strike rollback never stuck and a phone could
  serve a broken UI for ever. Marking a trial bad now also drops a `pending`
  holding the same seq, promotion checks `bad`, and the update check stops on
  `trial` as well as on `current`.
- **§2.3 step 7 pulls.** It used to read as a passive check, which can never
  pass: ordinary sync only fetches the pairs the *active* bundle reads, so a
  read-only schema bump — or a brand-new bucket — had no route onto the device
  and the update parked for ever with nothing logged. The updater now takes the
  sync lease and pulls each missing `(bucket, schema)` pair itself.
- **Garbage collection runs after any transition that changed the kept set**,
  not only after a commit. A store release is the event most likely to make an
  old read-only pair collectable, and a commit-only GC never saw it.
- **An unusable built-in bundle is defined.** If it fails its checks nothing is
  promoted, it is never added to `bad`, and with no `current` the host surfaces
  the failed check instead of leaving a blank WebView.
- **SQLite pragmas go through `rawQuery`, and the database is never closed.**
  The documented `execute` form crashed on the first launch of a real Android
  host.
- **The Android back gesture** goes back through WebView history and closes the
  app only when there is none left.
- **Bridge messages are bounded** (`MAX_MESSAGE_BYTES`), in both directions,
  with a new `E_TOO_LARGE`. An oversized base64 image used to kill the WebView
  uncatchably.
- **`/_host/` is reserved** for the host's own routes, with a 404 for an unknown
  id rather than the SPA entry page, and `nosniff` + `default-src 'none';
  sandbox` on the response.

### CLI

- `bundle --store` no longer rewrites the recorded store schema when the change
  is not additive; `--rebaseline` is the deliberate way through, and either way
  the build prints what it recorded.
- `bundle --store` warns when a release channel still points below the seq it
  just wrote (cut the OTA release *after* the store build).
- `bundle --builtin/--store` refuses `--requires-bridge` above the schema
  version, which would make a host refuse its own built-in bundle.
- `bundle` warns when `requires.bridge` rises above the bridge version of the
  last store build, and separately when it is pinned below the schema version.
- `bundle` refuses a bundle file under `_host/` and warns on a relative asset
  base in the entry page.
- `verify --files` says the directory is wrong instead of naming the first file
  as missing.

### Docs and spec

- §6 has an Android half at last: §6.1 for local notifications and §6.2 for the
  home-screen widget, including that a widget is the one screen a Valence app
  **cannot** change over the air.
- Every stop in the update algorithm logs its step and what it is waiting for.
- Buckets are key-value only, and that is now said on the first page.
- **Android is tested; iOS is experimental and untested.**

Firebase dependencies now require iOS 15.0 or later, even with push disabled. Upgrade Runner/extension target settings; iOS remains experimental and untested.

Bridge success and error reply caps now include Unicode separator escaping; oversized errors retain only safe numeric correlation ids.
