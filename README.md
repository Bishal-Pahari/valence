# Valence

**Keep the core. Swap the shell.** Your web app becomes your mobile app's interface. A small Flutter core ships through the stores once; every UI release after that is signed, tried on each phone and rolled back on its own if it fails. Data lives in native SQLite, so it works offline.

> **Android today · iOS experimental.** Everything here has been built and run on Android, on real devices and emulators. The iOS paths are specified and implemented but **nobody has run them**: there is no Apple hardware on the machines Valence is developed and tested on. Treat iOS as experimental and untested until that changes.

Every UI change to a native app normally waits on App Store and Play review, and teams end up maintaining the same logic twice, once for the web and once for mobile. Valence fixes both:

- **One web codebase** (SvelteKit, or any SPA that builds to static files) is both the website and the app's UI.
- **Over-the-air UI updates**: the web build is shipped as a signed bundle. Phones verify it, try it, and roll back automatically if it fails to start.
- **Offline first**: data lives in native SQLite, starts from a seed bundled in the app, and updates incrementally ("give me everything after update #1234"). Corrections to bundled data are just newer rows.
- **A typed bridge**: one schema generates the Dart host interface and the TypeScript client, so web and native can't drift apart.
- **Bring your own login**: your web app authenticates against your own API and hands the host the token. The host keeps it in the Android Keystore — not in the database — and sends `Authorization: Bearer` on every sync of the user's data, including the background runs the page is not awake for. The page can replace or clear the token, and never read it back.
- **Two packages, not generated code**: the Flutter host is [`valence`](https://pub.dev/packages/valence) on pub.dev and the web client is [`@getvalence/bridge`](https://www.npmjs.com/package/@getvalence/bridge) on npm. Your `main.dart` is about twenty lines; a fix to the runtime arrives with an ordinary update instead of being hand-applied to every app.

## How it works

```
┌──────────────────────── Flutter host (store-reviewed, rarely changes) ────────────────────────┐
│  WebView ── http://127.0.0.1:<port>/ ──► Loopback server ──► verified files (by sha256)       │
│     ▲  "Valence" JS channel: typed bridge generated from bridge.schema.json                 │
│     ▼                                                                                          │
│  Bridge ──► SQLite (kv · bucket · outbox · prefs) ◄── Sync: pull by usn, push via outbox       │
│                 ▲ seed.db shipped in the app          Updater: pointer → signed manifest → files│
└────────────────────────────────────────────────────────────────────────────────────────────────┘
         static OTA host (R2 / S3 / CDN)                    your sync API (or static chunks)
```

| What changed | How it reaches users | Store review? |
|---|---|---|
| UI, copy, styles, web logic | Signed OTA bundle, staged rollout (10% → 50% → 100%) | No |
| Data, or a fix to bundled data | Sync (a new row with a higher sequence number) | No |
| A new native capability, or a new feature area | App release | Yes |

**The update lifecycle:**

1. The app downloads only the files whose hash changed.
2. On the next launch it starts the new bundle as a *trial*.
3. The web app calls `ready()` once it has painted — on every path that paints, including a first-run screen — which commits the update.
4. If it crashes, or `ready()` doesn't arrive within 15 s of foreground time, the device goes back to the last good version. After a second failure it marks the new one bad. The bundle built into the app is the final fallback.
5. To roll back a release everywhere, release the last good commit again. It gets a new, higher sequence number, so devices move forward to it.

**The bridge is locked down:**

- it is reachable only from pages the app's own server delivered (a per-launch nonce);
- every message is decoded strictly against the schema;
- the page runs under a CSP that comes from the signed manifest;
- the `valence.` key prefix is the host's, in prefs and in secure storage alike, which is what makes the stored token unreadable by the page.

## Is it allowed by the stores?

Yes, within limits.

- **Apple:** the Developer Program License Agreement §3.3.1(B) allows downloaded *interpreted* code (JS in WebKit) as long as it doesn't change the app's advertised purpose, bypass OS security, or create a storefront. The policy reading is current; the **iOS implementation is untested** (see above), so no Valence app has been through App Store review yet.
- **Google Play** exempts "JavaScript in a webview".
- **Native code can never be downloaded**, and the bundler refuses it.

The framework also enforces the usual rejection traps:

- **"repackaged website"** (Apple guideline 4.2): the host must add real native value, such as offline use, widgets and notifications;
- **purpose drift**: new top-level routes are flagged for a store release;
- **untrusted pages getting bridge access** (Play): the bridge is locked to the local origin.

Details and exact policy quotes are in [contracts.md §7](.claude/skills/valence/references/contracts.md).

## Quick start

From your project root:

```
npm create valence@latest
```

The wizard sets up everything that doesn't need AI, in a few seconds:

1. **Detects** your web app (SvelteKit, Next.js static export, Astro or Vite), its package manager, an existing Flutter project, and your app id. It only asks for what it can't detect.
2. **Writes** `valence/valence.config.json` and the bridge schema, and declares `@getvalence/bridge` in your web app. It also adds `.gitattributes` and `.gitignore` entries.
3. **Generates** your Ed25519 signing key (outside the repo) and the typed bridge code for Dart and TypeScript.
4. **Installs** the `/valence` Claude Code skill and its agents into `.claude/`, or into `~/.claude/` with `--global`.
5. **Offers to launch** `claude "/valence init"`, which adds the `valence` package, writes the small setup, wires your own native methods, runs the tests and gets an independent review.

Other commands:

```
npx create-valence@latest update    # update the vendored CLI, skill and agents to the latest version
npx create-valence doctor           # quick health check
npx create-valence codegen --check  # any CLI command: keygen | codegen | bundle | verify | pointer | seed | version
```

It's safe to run again: it never overwrites your config, your schema or files you've edited. Pass `--yes` to accept the detected defaults without prompts, for CI.

## Use it in Claude Code

```
/valence init      # detect your web app, add the host package, keys, bridge, offline store, tests
/valence release   # build, sign and stage an OTA bundle; prints upload commands, uploads only after you confirm
/valence doctor    # audit: versions vs latest docs, policy checks, signatures, tests
```

`init` uses three agents:

1. **docs-scout** checks the latest stack docs and store policies.
2. **Two builders** work in parallel: one on the Flutter host, one on the web side. Neither writes the runtime — they add the packages and wire up what is specific to your app.
3. **An independent reviewer** checks the result.

It hands off an `AGENTS.md` section, so every future agent and contributor follows the same rules.

**Without Claude Code**, the CLI works on its own. The wizard vendors it into your repo, so CI needs no install:

```
node valence/valence.mjs keygen | codegen [--check] | bundle [--builtin|--store] | verify | pointer | seed
```

## Repository

| Path | |
|---|---|
| [contracts.md](.claude/skills/valence/references/contracts.md) | The spec: formats, protocols, state machine, policy rules, test matrix |
| [SKILL.md](.claude/skills/valence/SKILL.md) | The `/valence` workflows and the verified stack baseline |
| [scripts/valence.mjs](.claude/skills/valence/scripts/valence.mjs) | Zero-dependency CLI; tests: `node --test .claude/skills/valence/scripts/valence.test.mjs` |
| [.claude/agents/](.claude/agents/) | docs-scout, builder, reviewer |
| [packages/valence/](packages/valence/) | The Flutter host runtime, published as `valence`. Includes the §8 test matrix and an example app. |
| [packages/bridge/](packages/bridge/) | The web bridge client, published as `@getvalence/bridge`. Zero runtime dependencies. |
| [docs/migrating-from-0.3.md](docs/migrating-from-0.3.md) | Moving a 0.3 app with a generated host onto the packages, without losing data |
| [AGENTS.md](AGENTS.md) | Rules for anyone (human or agent) changing this repo |

## Status

The runtime includes [host widget tests](docs/host-widget-tests.md) for startup/resume, navigation
locks, bridge nonce forwarding, buffered events, trial-ready timeouts and disposal. They pump the real
host with a stub native WebView; Android device verification remains a separate gate.

**0.4 beta, package-first.** The runtime is no longer generated per app: `valence` (pub.dev) is the whole Flutter host and `@getvalence/bridge` (npm) is the whole web client, both with their own test suites, and `valence codegen` emits only the typed, app-specific half and imports the rest. Moving from 0.3 is [one documented pass](docs/migrating-from-0.3.md) that keeps your data, your update state and your signing key.

**Android is tested. iOS is experimental and untested** — its rules are implemented and specified, but there is no Apple hardware here, so nothing about them is claimed as verified.

**Not in scope:**

- **Third-party mini-app stores** (Apple guideline 4.7).
- **CRDTs and real-time collaboration.**
- **Downloading native code.**

## Your own backend in 0.4

`http.request` calls your own API natively, restricted to exact `http.origins` origins compiled into the host. It attaches the stored user token, returns redirects without following them, and supports bounded UTF-8 text bodies. New at schema 4; guard with `has()` on older hosts. An origin change needs codegen and a store build. Online HTTP does not replace offline sync: the [reference REST adapter](examples/rest-sync-adapter/) shows durable cursors, tombstones and idempotent pushes. [Guide](https://getvalence.pages.dev/docs/guides/your-backend/). Android is tested; iOS is experimental and untested.

## License

[MIT](LICENSE) © 2026 Bishal Pahari

## Offline tooling in 0.4

`data.getMany` reads up to 500 keys in one bridge call; `sync.status` reports pending operations (including deletes) without a network call. Both are schema-3 additions: guard them with `has()`. `ota.channel` selects the host channel, and OTA builds now default to the recorded store bridge version; guard newer calls or explicitly raise `--requires-bridge`. `seedSchemas` plus `<bucket>.v<N>.json` seeds multiple declared schemas together. Test doubles can opt into generated `BridgeHandlersDefaults`.

Run `node valence/valence.mjs doctor --tests` for mechanical checks and mapped unit tests. Broken bridge versions, incompatible local OTA requirements, database paths, PEM keys inside Git and invalid connection URLs fail with a fix. WARN means missing or unexecuted evidence; installed database adoption and device behavior still need a device run. [Full guide](https://getvalence.pages.dev/docs/guides/offline-tooling/).

Sync correctness: pull cursors advance only through returned rows, never push echoes or a later server-head max. Fresh pairs satisfy OTA activation only after all pages or static chunks complete. Progress resumes after an interruption. Pending publication retains the data lease; GC protects in-flight manifests and retries stale snapshots. Step 7 waits up to five seconds for ordinary sync. Outbox operations use a durable insertion ordinal; database version 2 migrates legacy queued ids, values and deletes without changing bucket cursors or user rows.

## Adaptive UI in 0.4

ValenceApp draws edge-to-edge and publishes safe-area CSS variables on rotation and resize. Android text zoom follows system font size; optional app.info().fontScale reports it. The schema-7 app.appearance event reports system dark mode, high contrast and reduced motion. Your page supplies semantic HTML and content padding. [Accessibility guide](docs/accessibility.md). iOS is experimental and untested.

### Lifecycle, connectivity and update status

Bridge version 6 answers the three questions a page in a browser tab gets from the platform and a page in
the host cannot. `app.lifecycle` fires on the way *out* as well as in, with four states —
`foreground`, `background`, `inactive`, `detached` — mapped from Flutter's five and emitted only on a
change, because Android delivers `hidden` and then `paused` for one backgrounding. Persist on
`background`: `detached` usually never arrives. `app.online` reports the OS's network **interfaces**,
not reachability, so it decides whether to *try* while `SyncResult.reason` says whether the last attempt
worked. `app.state()` returns both, for a page that mounted after the transition. `sync.done` carries
the whole `SyncResult` after every run the host made on its own, `changed: 0` included — which
`sync.changed` never could, and most runs move nothing. `bundle.status()` names why the last update
check stopped, from a closed set of eleven: `rejected` means a release no device will take, and
`waitingForData` is the healthy stall four hosts read as "no update". Drive it from
`bundle.updateReady`, which fires for **every** pending bundle rather than only an `--urgent` one —
polling on resume races the check, so a page otherwise hears about an update one resume late.
[Full guide](https://getvalence.pages.dev/docs/guides/lifecycle/).

### Reading a bucket bigger than 500 rows

`data.list` clamps `limit` to 500 (an unbounded reply kills the WebView), so `data.list`'s `after` takes
the last key of the previous page and resumes strictly after it — a complete read of any bucket. Without
it a bucket past the clamp had none, and a truncated list is indistinguishable from a short one: a stored
key outside the first page reads as a key the device has never held. `data.count` reports how many live
rows a bucket holds without reading any of them. Both are version 5; `after` is a new *param* on a
since-1 method, so gate it on `has("data.count")`, the sibling that ships with it, rather than on
`has("data.list")`. Not on `app.info().bridge >= 5` either: that is the app's **own** schema version,
so it is already above 5 in any app that has added five methods of its own, and the comparison is true
on the very hosts that reject the param. A built-in may now grow an optional param the same way it may grow an optional
returned field, additive against a recorded store baseline.

The database lives at `<applicationSupportDirectory>/<databaseName>`; `host.database` names the file and
the directory is fixed. A 0.3 host may have used the application documents directory instead, so the
package adopts such a database on open — `-wal` and `-shm` move with it, the `.db` last, an existing
destination is never overwritten, and the move is logged. A locked open (a schema migration's
`BEGIN EXCLUSIVE` against the WorkManager job the same launch fires) is retried; `backgroundSync` then
reports `reason: "busy"` rather than failing the job.
