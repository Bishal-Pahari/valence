# Changelog

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
- **§4.2** — the strict decoders, the closed error-code set, the 256 KB UTF-8 message cap in both
  directions, and event scripts built only through `jsonEncode`.
- **§5** — the SQLite store with the pragmas through `rawQuery`, a never-closed connection shared across
  isolates, the seed import counted with `changes()`, per-`(bucket, schema)` storage, the outbox, pull
  paging, push with its echo skip, and the sync lease.
- **§3 back gesture, console capture and resume** — `PopScope` asking the WebView first,
  `setOnConsoleMessage` plus the page callbacks, and port reclaiming on resume that keeps the nonce when
  the same port comes back.

Also here, and not in the generated hosts it replaces:

- `ValenceConfig.authToken`, so a user-scoped bucket can carry a bearer token.
- `ValenceConfig.syncMode: staticChunks`, the CDN-only pull from §5.3's static variant.
- `ValenceConfig.databaseName`, so a 0.3 app whose generated host chose its own file name keeps its data.
- `Valence.publishHostFile`, the only path from native bytes to the page.
- `Valence.pendingWrites()`, which counts queued deletes a `usn == -1` scan cannot see.

268 tests. `dart analyze --fatal-infos` clean.
