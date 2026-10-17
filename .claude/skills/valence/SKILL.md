---
name: valence
description: Set up, release and audit the Valence architecture. A Flutter host runs a signed over-the-air web bundle (SvelteKit or any static SPA) on top of an offline-first native SQLite data layer, with incremental sync and a typed bridge generated from one schema. One web codebase serves both the website and the app, and UI changes ship without app-store review.
when_to_use: The user runs /valence, or asks to put a web app inside a mobile app, ship mobile UI changes without store review (OTA or code push), add offline data to a hybrid app, or audit or release an existing valence setup.
argument-hint: "[init|release|doctor] [--channel name] [--rollout 0-100] [--floor seq] [--urgent]"
---

# /valence

Builds this architecture as open contracts:

- a **Flutter host** that the stores review rarely;
- a **web UI** shipped as signed OTA bundles;
- **native SQLite** fed by a bundled seed plus incremental sync;
- a **typed bridge** generated from `bridge.schema.json`.

**[references/contracts.md](references/contracts.md) is the spec. Read it fully before writing or reviewing any code.** Every rule below points back to a section of it.

Tooling that ships with this skill (it is tested, so copy it rather than rewriting it):

| File | Use |
|---|---|
| `${CLAUDE_SKILL_DIR}/scripts/valence.mjs` | Zero-dependency CLI: `keygen`, `codegen`, `bundle`, `verify`, `pointer`, `seed`, `version` |
| `scripts/valence.test.mjs` (framework repo only, not shipped in the npm package) | The CLI's own tests, including compiling the generated Dart. Run them when you change `valence.mjs`. |
| `${CLAUDE_SKILL_DIR}/templates/` | `bridge.schema.json` (starter IDL), `valence.config.json`, `client.ts` (web bridge client), `AGENTS.section.md` (the hand-off rules) |
| `${CLAUDE_SKILL_DIR}/../../agents/` | `valence-docs-scout`, `valence-builder`, `valence-reviewer` |

**If a named agent type isn't installed**, spawn `general-purpose` instead and paste the body of the matching agent file at the top of its prompt.

## Mode

Arguments: `$ARGUMENTS`

- `init`, or empty with no `valence/valence.config.json` in the project: set up the architecture (§Init).
- `release`: sign and stage a new OTA bundle (§Release).
- `doctor`, or empty when a config exists: audit only. Change nothing unless the user asks (§Doctor).

If you were invoked on your own (the user didn't type `/valence`), confirm before **init** or **release**, since both write many files or publish. **doctor** is safe to run.

## Non-negotiables

These are enforced by `valence.mjs`, the builder and the reviewer.

1. **Use the canonical check order and trust nothing before the signature passes.** The order is:
   1. the signature over the exact manifest bytes;
   2. `appId`;
   3. `seq == pointer.seq`;
   4. `seq >= state.floor`;
   5. `requires`;
   6. well-formed paths, hashes and sizes;
   7. each file's sha256 and size.

   The built-in bundle goes through the same path (contracts, top of the file, plus §2.3 and §2.4).
2. **Downloaded bundles never contain native code**, and an OTA update never changes the app's advertised purpose (§7).
3. **The private signing key never enters a repo.** It lives in `~/.valence/keys/` or the `VALENCE_SIGNING_KEY` env var. `valence keygen` and `valence bundle` enforce this, and `bundle` also checks the key against `keyring.json`.
4. **Only our own pages can reach the bridge:**
   - the main frame is locked to `http://127.0.0.1:<port>/`;
   - there are no off-origin subframes;
   - every message carries the per-launch nonce the server put in the entry page;
   - every message is decoded strictly by the generated code;
   - the CSP header comes from the signed manifest (§3, §4.2, §7).
5. **The bridge schema is additive only.** Once a store build ships the schema, `codegen` refuses to change or remove anything in it; add `name.v2` instead (§4.1).
6. **First launch works fully offline** from the built-in bundle plus `seed.db`, and never blocks on a download (§5.2, Apple guideline 4.2.3(ii)).
7. **Durable state lives in native SQLite through the bridge.** The web app's localStorage and IndexedDB are only a cache (§3, origin note).
8. **No CRDTs and no general two-way sync.** Server-published buckets are pulled, and user buckets use an outbox with last-writer-wins per key (§5.5).
9. **The host must add real native value** (at least two §6 items), or Apple rejects it as a repackaged website (guideline 4.2).
10. **Follow the target project's own AGENTS.md and CLAUDE.md** (formatter, import order, package manager) in every file you write there.

## Init

### Phase 0: Orient (read only)

- Run `git status --short --branch`. Never stash, reset or commit. If the tree is dirty, only touch files this setup owns.
- Read the target's AGENTS.md and CLAUDE.md and note its conventions.
- Detect the following:
  - **The web app.** A `package.json` with `@sveltejs/kit`, `vite`, `next` (static export), `astro` and so on. Note its package manager (from the lockfile), its build command and its static output directory.
  - **An existing Flutter project.** A `pubspec.yaml` with a `flutter:` section.
  - **A monorepo layout.**
- Check the toolchains: `flutter --version`, `dart --version`, `node -v` (Node 22.13 or later). **If any is missing, stop.** Print the official install link. Never install an SDK silently.
- **The web app must be able to build to static files.** If its pages need a server, stop and explain how to switch to SPA mode. For SvelteKit, that means `adapter-static` with `fallback: 'index.html'` and `export const ssr = false` in the root layout. The docs-scout confirms the current syntax.

### Phase 1: Docs check (in the background, started now)

Spawn the `valence-docs-scout` agent with `run_in_background: true`. Its prompt:

> Compare the current stack against the baseline table in `${CLAUDE_SKILL_DIR}/SKILL.md` (§Stack baseline) and the policy sources in `${CLAUDE_SKILL_DIR}/references/contracts.md` §7. Target project root: `<root>`. Detected web framework: `<x>`. Local Flutter: `<version>`. Write `<root>/.valence/stack-check.md`.

**Gate:** don't start Phase 4 until its report is in. If it reports **breaking** drift for a layer, adapt that layer's code. Then write the decision under `## Decisions` in `stack-check.md` with the source URL.

### Phase 2: Defaults (ask only what blocks you)

- **Infer:**
  - `appId` from the existing Android `applicationId` or iOS bundle id. Otherwise ask.
  - `host.dir` = `mobile/`.
  - The web paths, from Phase 0.
  - The `data` buckets: `{}` until the user names some.
- **Ask in one AskUserQuestion call, and only for what you can't infer:**
  - the `appId`;
  - the OTA base URL (R2, S3 or any static host; a placeholder is fine for now);
  - the sync backend: an existing API, static chunks (§5.3) or none yet.

### Phase 3: Contracts and keys (main loop, in order)

**If the user already ran `npm create valence@latest`,** most of this phase (and Phase 2) is done: config, vendored CLI, schema, client, git attributes, key and codegen. Check each output, skip the steps whose output exists, and don't regenerate the key. Usually only the formatter ignores and the key-backup reminder remain.

1. **Copy the tooling.**
   - Copy `scripts/valence.mjs` to `valence/valence.mjs`.
   - Copy `templates/bridge.schema.json` to `valence/`.
   - Fill `templates/valence.config.json` with the detected values and write it to `valence/valence.config.json`.
   - Add `.valence/dist-ota/` to `.gitignore`.
   - **Write `.gitattributes`, one pattern per line** (git ignores a line with several patterns): `<host.dir>/assets/valence/** -text`, `*.g.dart text eol=lf`, `*.g.ts text eol=lf` and `valence/*.json text eol=lf`. Without it, Git for Windows rewrites the line endings in the built-in bundle and breaks every signature (§1).
   - **Add `bridge.g.ts` to the project's formatter ignores** (`.prettierignore`, Biome `files.ignore`). `codegen --check` tolerates `dart format`, but not changed quote styles.
2. **Generate the signing key** with `node valence/valence.mjs keygen`. Then **tell the user** where the private key is and that they must back it up in their password manager and add it to CI as the `VALENCE_SIGNING_KEY` secret. If it's lost, rotating the key takes a store release, because the keyring is compiled into the host (§2.2).
   - If `keyring.json` already has the `keyId`, **don't** run keygen. Ask the user for the existing key (it lives in their secret store); `valence` refuses to overwrite a keyring entry.
3. **Generate the bridge code** with `node valence/valence.mjs codegen`. It writes `bridge.g.ts`, `bridge.g.dart` and `config.g.dart`.
4. **Copy the web client:** `templates/client.ts` goes to `<web.lib>/client.ts`.

### Phase 4: Build (two builder agents in parallel, with separate files)

Spawn two `valence-builder` agents in a single message. **Each one owns only its listed paths.** Each prompt contains:

- which layer it owns;
- the exact paths;
- the stack versions from `stack-check.md`;
- "Read `${CLAUDE_SKILL_DIR}/references/contracts.md` first";
- the target's conventions;
- "Report the files you changed, the tests you ran and their output."

**Host builder.** It owns `<host.dir>/**`, except the `*.g.dart` files.

- Run `flutter create --org <reverse-domain of appId> --project-name <snake name> --platforms android,ios <host.dir>` if the project doesn't exist yet.
- Add these dependencies: `webview_flutter`, `sqflite`, `path_provider`, `cryptography`, `crypto`, `http`, `url_launcher`, `connectivity_plus` and `workmanager`. `crypto` gives you the synchronous `sha256.convert(bytes)` that check 7 needs per file; `cryptography` only has an async `hash()`, which is awkward inside the download-and-rename loop.
- Write the runtime in `lib/valence/`:
  - `server.dart`: the per-install port, the nonce injected into the entry page, and the CSP header (§3)
  - `updater.dart`: the canonical check order, the state machine with `trialFails`, and GC only at commit (§2.3, §2.4)
  - `store.dart`: per-`(bucket, schema)` storage, WAL plus `busy_timeout` **through `rawQuery`**, one never-closed instance shared with the background isolate, and the seed import (§5.1, §5.2, §5.4)
  - `sync.dart`: pull and push, the echo skip, and the sync lease (§5.3–§5.6)
  - `bridge.dart`, which implements `BridgeHandlers`, passes the server's nonce to `bridgeDispatch`, and only allows `open.external` for `https`, `mailto` and `tel` (§4.2)
  - `host.dart`: the WebView widget, the navigation lock, no off-origin subframes, the foreground-only ready timer, the queue that holds events until `onPageFinished`, and `setOnConsoleMessage` plus `onPageStarted`/`onPageFinished`/`onHttpError` logging (§2.4, §3, §4.2, §7)
- Declare `assets/valence/builtin/`, `assets/valence/builtin/files/` and `assets/valence/seed.db` in `pubspec.yaml`.
- Platform setup:
  - Android: the network security config allowing cleartext to `127.0.0.1` only, and `dataExtractionRules`/`fullBackupContent` excluding `valence/`;
  - iOS: the App Transport Security (ATS) loopback setting, as confirmed by the docs-scout, and `isExcludedFromBackup` on the `valence/` directory.
- Wire in two or more of the §6 native-value items.
- Tests: the Dart unit tests for the updater, state machine, store, sync and bridge rows of §8, plus one `integration_test` for an offline cold start.

**Web builder.** It owns `<web.lib>/**` (except `bridge.g.ts`), the web framework config, the root layout's startup call, `shim.ts` and package scripts.

- **Static build:** configure it with relative-safe asset paths (§3).
- **Root layout:** call `connect()` and then `ready()` after the first meaningful paint.
- **Shim:** write `shim.ts` with browser fallbacks (`fetch` against the same sync API, `localStorage` for prefs) and install it with `installShim`.
- **No CSP meta tag.** Inside the app, the host sends the CSP from the signed manifest as a header (§3). The website keeps whatever CSP its hosting sets. If the app calls APIs other than `sync.base`, list their origins in `valence.config.json` under `web.connect`.
- **Package scripts:** add `valence:codegen`, `valence:bundle` and `valence:release`.
- **List, don't rewrite:** report every durable use of localStorage or IndexedDB in app code (file and line) so the user can decide. Don't refactor feature code.

### Phase 5: Integrate and verify (main loop)

Run these in order. Fix and rerun on any failure, up to 3 attempts per failure; after that, report it as a blocker with the output.

1. `node valence/valence.mjs codegen --check`
2. Build the web app, then run `node valence/valence.mjs bundle --builtin`, then `node valence/valence.mjs verify --manifest <host>/assets/valence/builtin/manifest.json --files <host>/assets/valence/builtin/files`.
3. Run `node valence/valence.mjs seed --from <dumps>`. With no data yet, use an empty directory, which gives a valid empty seed. Report any "has no seed file" warnings: those buckets stay empty offline until the first sync.
4. In `<host.dir>`, run `flutter pub get`, then `dart analyze --fatal-infos lib test`, then `flutter test`.
5. If an Android SDK is present (`flutter doctor`), run `flutter build apk --debug`. Build iOS only on macOS.
6. If `flutter devices` lists a device or emulator, run the offline-cold-start `integration_test`. Otherwise report "skipped: no device". Don't count it as passed, and say explicitly that **the first launch has not been shown to open the database**: `sqflite_common_ffi` accepts things Android's `SQLiteDatabase` rejects (§5.1), so the green unit suite is not evidence for that path.

### Phase 6: Independent review

Spawn `valence-reviewer`, never yourself, against the changed files. Fix every CRITICAL and HIGH finding, rerun Phase 5, and re-review only the files that changed. List MEDIUM and LOW findings for the user.

### Degraded mode: no subagents

Phases 1, 4 and 6 spawn agents. If your harness can't (headless, or subagents disabled), don't stop — do the work in the main loop in this order, and **say in the hand-off which steps ran degraded**:

1. **Instead of Phase 1,** read §Stack baseline below and check its dates. Record in `.valence/stack-check.md` that no scout ran and the baseline is unverified for this run. Then be conservative: pin the versions the baseline names rather than resolving `latest`, and treat a build failure inside a listed package as drift to investigate, not as your own bug.
2. **Instead of Phase 4,** write the host first and the web side second, in the file order Phase 4 lists. Read `references/contracts.md` in full before the first file. Run `dart analyze --fatal-infos` after each file rather than at the end, so an error is attributable to what you just wrote.
3. **Phase 5 is unchanged,** and it is now your only safety net. Run every step, and don't let the device step pass silently (see step 6 there).
4. **Instead of Phase 6,** review in a **separate pass**: re-read §2.3, §2.4, §3, §5.1 and §7, then the code, and work `.claude/agents/valence-reviewer.md` as a checklist, writing down the evidence for each item. **Self-review is weaker than independent review, and the hand-off must say so,** with a recommendation to run `/valence doctor` from a fresh session before the first store submission. Never present a self-review as an independent one.

### Phase 7: Hand-off

1. **AGENTS.md.** Append `templates/AGENTS.section.md` to the target's `AGENTS.md`, filling in its paths. Create the file if it doesn't exist. Replace an existing `## Valence` section rather than adding a second one.
2. **CLAUDE.md.** If the target has a `CLAUDE.md` without `@AGENTS.md`, add that line. Claude Code reads AGENTS.md on its own only when there is no CLAUDE.md.
3. **Agents.** Copy `valence-reviewer.md` into the target's `.claude/agents/`, so future changes get the same review.
4. **Report**, in this order:
   - what was built (paths);
   - the stack versions used, and any drift with its decision;
   - test results with real output counts;
   - what was skipped and why;
   - the key backup reminder;
   - next commands: `/valence release --channel beta --rollout 100` and `/valence doctor`.

## Release

**For a store submission** (a new native capability, a new feature area, or the first release), build the app's built-in bundle with `node valence/valence.mjs bundle --store` instead of `--builtin`, then build the Flutter app.

- `--store` records the routes and bridge schema the stores reviewed in `.valence/baseline.json`. From then on, `codegen` keeps that schema additive-only, and `valence bundle` warns about routes the stores haven't seen.
- Commit `baseline.json` along with the release.
- **Nothing stops a store build made with plain `--builtin`**, and if that happens the shipped schema stays editable. If the project has CI for store builds, make that job run `valence bundle --store`, and offer to add it.

The steps below are for **OTA releases**.

1. **Preconditions.** `codegen --check` passes and the web tests pass. State the channel (default `production`) and rollout (default `10`) back to the user.
2. **Build and sign.** Build the web app, then run `node valence/valence.mjs bundle [--floor N] [--urgent]`.
   - If it warns about a **new top-level route**, stop and ask whether the change needs a store update instead (DPLA 3.3.1(B)(a)).
   - If it warns that the route check is **INACTIVE**, there is no routes directory to scan and nothing declared. Add the app's top-level routes as `web.declaredRoutes` in `valence.config.json` and re-run, so later releases are diffed against something. (If instead it says scanning *found only "/"*, the check is working: confirm with the user that the app really has one top-level route before declaring anything.)
   - Raise `--floor` only when the release fixes a security bug. It can never go back down.
   - **Commit `.valence/baseline.json`** afterwards. It holds `lastSeq`, which keeps `seq` increasing across machines and CI.
3. **Verify** the new manifest with `valence verify`.
4. **Stage the pointer** with `node valence/valence.mjs pointer --channel <c> --rollout <n>`.
5. **Upload.**
   - Detect the user's storage tool: `wrangler r2 object put`, `aws s3 sync`, `gsutil rsync` or `rclone`.
   - Print the exact commands in this order: **files, then manifests, then the pointer last**, so devices never see a pointer to missing files.
   - **Run them only after the user explicitly confirms**, because publishing is outward-facing.
6. **Ramp** from 10 to 50 to 100 while watching for `app.ready` timeouts and crash reports.
   - **To roll back, roll forward.** Check out the last good web commit, build it, run `valence bundle` (which gives it a new, higher seq), then point the channel at it.
   - Pointing the channel at an older seq only cancels pending downloads. Devices that already committed the bad bundle keep it until something newer arrives (§2.4).
   - Devices still trying a bad bundle revert on their own after two failed starts.

## Doctor (read only)

Report a PASS, WARN or FAIL table, with a fix command for each row that isn't a PASS:

- **CLI version.** `node valence/valence.mjs version` against the skill's copy, `node ${CLAUDE_SKILL_DIR}/scripts/valence.mjs version`.
- **Generated code.** `codegen --check`.
- **Docs drift.** Spawn the docs-scout.
- **Bundle and seed.** The built-in bundle verifies, and `seed.db` exists.
- **Policy:**
  - routes compared with `.valence/baseline.json`, and whether that comparison is active at all (`web.declaredRoutes` for an app that routes in JavaScript);
  - no native files in the web output;
  - in the host (grep for each): the navigation lock, no off-origin subframes, `bridgeDispatch(… nonce:)`, the CSP header from `manifest.csp`, and the `open.external` scheme allow-list;
  - `.gitattributes` covers the built-in bundle;
  - at least two §6 items.
- **Tests.** Run the host and web tests and report the counts.

## Stack baseline (verified 2026-10-15 from pub.dev, npm and Flutter release JSON)

| Item | Version | Note |
|---|---|---|
| Flutter / Dart | 3.47.7 / 3.13.5 (stable, 2026-10-08) | `sqflite` 2.4.4+2 needs Flutter 3.44 or later |
| webview_flutter | 4.14.1 (2026-07-07) | **default WebView**. `flutter_inappwebview` has had no stable release since 6.1.5 (2024-10-08) |
| sqflite | 2.4.4+2 (2026-10-13) | Local store. Drift 2.35.2 is fine if the app already uses it |
| cryptography | 2.9.0 (2025-11-21) | Ed25519 verify on the device |
| workmanager | 0.10.10 (2026-09-07) | Background sync; best effort on iOS. **Applies the Kotlin Gradle Plugin, and every Android build warns that future Flutter versions will refuse to build plugins that do** (observed 2026-10-17). Still current; re-check by 2026-12. If it becomes unbuildable, drive `WorkManager` and `BGTaskScheduler` through a platform channel — §5.6 specifies the triggers, not the package |
| home_widget | 0.10.0 (2026-09-17) | Optional native value (§6) |
| the other §6 packages | **not pinned here** | `share_plus`, `flutter_local_notifications` and `local_auth` are named in contracts §6 with the native setup each needs, but no version in this table has been verified against a primary source. Resolve them with the docs-scout before relying on an API |
| path_provider / url_launcher / connectivity_plus / http | 2.1.6 / 6.3.3 / 7.3.2 / 1.6.0 | |
| @sveltejs/kit / adapter-static | 3.1.0 / 4.0.0 | Kit 3 needs Node 22+ and TypeScript 6+, and always emits `modulepreload` (one reason we don't use `file://`) |
| Apple App Store Review Guidelines | last updated 2026-06-08 | Guidelines 2.5.2, 4.2, 4.3(b), 4.7.x |
| Apple Developer Program License Agreement (DPLA) | attachment dated 2026-10-13 | §3.3.1(B): interpreted code is allowed; it must not change the app's purpose, bypass OS security, or create a storefront |
| Google Play Device and Network Abuse policy | retrieved 2026-10-14 | JS in a webview is exempt; no JS interface on untrusted content |

## Gotchas (each has cost someone a day)

- **A random loopback port wipes web storage on every launch**, because the origin includes the port. Use a fixed port per install, derived from `appId` and `installId` and kept below 30000 (§3).
- **Never serve from a port you failed to bind.** Another process may own it, so move to a new port. The nonce is what keeps a stranger's page off the bridge.
- **`file://` breaks ES modules on Android WebView**, and service workers in WKWebView need App-Bound Domains, which break script message handlers. Serve from loopback.
- **iOS kills listening sockets while the app is suspended.** Rebind the same port on resume, or lazily loaded chunks will 404.
- **A webview_flutter `JavaScriptChannel` is visible to every frame.** That's why the navigation lock, no off-origin subframes and `frame-src 'none'` are mandatory, not optional.
- **SvelteKit's entry page has an inline boot script**, so a plain `default-src 'self'` CSP renders a blank app. `valence bundle` hashes inline scripts into `manifest.csp`; the host sends that as a header.
- **Git on Windows rewrites line endings** in the built-in bundle and breaks signatures. `.gitattributes` with `-text` is mandatory.
- **A pull or a push echo must not overwrite a row that has a pending outbox entry**, or user edits vanish (§5.3, §5.5).
- **Pointing the channel at an older seq doesn't roll anyone back.** Roll forward with a new seq instead.
- **Garbage collection must keep the `pending` and `trial` files.** Otherwise a healthy update 404s and gets marked bad.
- **The update check has to stop on `trial` too, or the rollback never sticks.** While a seq is on trial it is above `current` and `pending` is null, so an unguarded check re-pends the bundle that is failing; after two strikes mark it bad, that stale `pending` promotes it straight back with `trialFails` reset, for ever. Stop on `trial`, drop a `pending` that equals the seq you just marked bad or committed, and never promote a `pending` that is in `bad` (§2.3 step 1, §2.4).
- **§2.3 step 7 is a pull, not a check.** Ordinary sync only fetches the pairs the *active* bundle reads, so a bundle that requires a new `(bucket, schema)` pair has no other way to get it. A host that only checks parks the update for ever: `pending` stays null, the app stops updating, and nothing is logged. Pull the missing pair from `since = 0`, and track synced pairs as a set per bucket — a bucket → schema map lets v1 hide v2 during a bump (§2.3, §5.4).
- **Log every reason the updater stops.** A declined update and a failed one look identical from outside: pointer fetched, manifest verified, then silence. Say which step stopped and what it was waiting for, or the only way to debug a phone that will not update is to read the host's source (§2.3).
- **Background launches must not touch the state machine.** iOS BGTask and workmanager runs `main()` without a UI; only the host widget moves `pending` to `trial`.
- **Flutter asset directories aren't recursive.** Declare `assets/valence/builtin/` and `assets/valence/builtin/files/` separately.
- **sqflite on Android rejects row-returning pragmas through `execute()`.** `PRAGMA journal_mode = WAL` and `busy_timeout` have to go through `rawQuery`, or the app dies on its first launch. `sqflite_common_ffi` accepts both, so every unit test passes while the phone can't start (§5.1).
- **sqflite handles are process-wide, not per isolate.** Closing the database in a `workmanager` run or in `dispose()` breaks the UI isolate's handle. Never close it (§5.1).
- **Declaring the Valence assets breaks `flutter test` until they exist.** Flutter refuses to build an asset bundle for a missing directory, so run `valence seed` and `valence bundle --builtin` before any `flutter` command in a fresh checkout.
- **The SPA fallback swallows every host route you put after it.** It answers any extensionless path, so a photo id the host doesn't recognise comes back as HTTP 200 with the entry page's HTML — a blank `<img>` and nothing in either log. Serve the host's own routes under the reserved `/_host/` prefix, *before* the manifest lookup, and hand the page a relative URL because the port moves (§3).
- **Build the web app with an absolute base.** With `base: './'` the entry page asks for `./assets/app.js`; served as the fallback for `/a/b` the webview resolves that to `/a/b/assets/app.js`, which has an extension and so is a real 404. Cold start always loads `/`, so this only appears on a reload or a back gesture onto a nested route — a blank screen with no error. `valence bundle` warns (§3).
- **`jsonEncode` output is safe to embed in `runJavaScript`** (ES2019 allows U+2028), but never concatenate raw strings into scripts.
- **The updater must compare `requires.bridge` against the generated `hostBridgeVersion`.** A second literal drifts: bump the schema, and the host refuses its own built-in bundle with nothing left to serve — on every install, from first launch. §8 tests that a bundle requiring exactly `hostBridgeVersion` is *accepted*, which is the half everyone forgets.
- **A bundle needs a bridge version the host doesn't have?** Build with `--requires-bridge <old>` and guard newer calls with `has()`. Otherwise older hosts never receive the update.
