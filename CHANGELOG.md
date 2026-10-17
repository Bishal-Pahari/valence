# Changelog

Newest first. One version for `create-valence`, `@getvalence/bridge` and the `valence` pub package.

## Unreleased

Everything below is on `test-week-fixes` and **not published**. Four independent
teams built Android apps from the public docs during test week and logged what
broke; these are the fixes. The version for this batch is the maintainer's call.

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
