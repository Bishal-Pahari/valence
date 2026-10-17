# Changelog

Newest first. One version for `create-valence`, `@getvalence/bridge` and the `valence` pub package.

## Unreleased

Everything below is unpublished. The headline is the packaging change; under it
are the test-week fixes, logged by four independent teams who built Android apps
from the public docs and wrote down what broke. The version for this batch is the
maintainer's call.

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
