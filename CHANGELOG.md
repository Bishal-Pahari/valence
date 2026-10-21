# Changelog

Newest first. One version for `create-valence`, `@getvalence/bridge` and the `valence` pub package.

## Unreleased

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
