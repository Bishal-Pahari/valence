# Valence contracts (the spec)

This file is the source of truth for every layer. Code must match it. If code and spec disagree, fix the code or change the spec in the same commit. Never let them drift.

**Platform status: Android is tested, iOS is experimental and untested.** Every rule here has been exercised on Android devices and emulators. The iOS rules — App Groups for the widget (§5.6), `NSURLIsExcludedFromBackupKey` (§2.4), WKWebView's App-Bound Domains, `BGTaskScheduler` (§5.6), and the App Store policy reading in §7 — are specified and must be implemented, but **no one has run them**: there is no Apple hardware on the machines Valence is developed and tested on. Keep implementing them; do not state them as verified.

Layers:

```
┌──────────────────────── Flutter host (store-reviewed, rarely changes) ────────────────────────┐
│  WebView ── http://127.0.0.1:<port>/ ──► Loopback server ──► CAS files (verified by manifest)  │
│     ▲  JS channel "Valence" (typed bridge + per-launch nonce, generated from the IDL)        │
│     ▼                                                                                          │
│  Bridge dispatcher ──► Store (SQLite: kv / bucket / outbox / prefs) ◄── Sync (pull + push)     │
│                        ▲ seed.db (bundled)                 Updater (pointer → manifest → CAS)  │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
   OTA host (static: R2 / S3 / any CDN)             Sync API (your backend, or static chunks)
```

What ships in which update:

- **Store update:** the host, its bridge methods, the built-in bundle, and the seed database.
- **OTA bundle (signed):** HTML, CSS, JS, images and fonts. This is the web UI.
- **Sync:** data rows.

**Canonical manifest check order.** Every host and every tool uses this order, and §2.3 is normative:

1. Ed25519 signature over the exact bytes;
2. `appId`;
3. `seq == pointer.seq`;
4. `seq >= state.floor` — **including for the built-in bundle**, which is why §2.2 refuses a floor above the store build's seq;
5. `requires`;
6. every path, hash and size field is well formed;
7. each downloaded file's sha256 and size.

---

## 1. Project layout (target app)

```
<root>/
  <web app>/                  existing web app (any SPA that builds to static files)
  mobile/                     Flutter host
    pubspec.yaml                   depends on `valence` (pub.dev): the whole host runtime of §2, §3, §4.2 and §5
    lib/main.dart                  ~20 lines: Valence.open(valenceConfig) + ValenceApp + the app's handlers
    lib/valence/                   bridge.g.dart  config.g.dart   (generated, never edited)
    lib/valence/handlers.dart      this app's own bridge methods only, extending the generated ValenceBuiltins
    assets/valence/builtin/        built-in bundle: manifest.json, manifest.json.sig, files/<sha256>  (written by `valence bundle --builtin`)
    assets/valence/seed.db         bundled SQLite seed (written by `valence seed`)
  valence/
    valence.config.json            appId, keyId, web/host paths, OTA and sync base URLs, data schemas, writable buckets,
                              and web.declaredRoutes for apps whose routes can't be scanned (§7)
    bridge.schema.json        bridge IDL (§4)
    keyring.json              public keys {keyId: base64 raw Ed25519}; compiled into the host by codegen
    valence.mjs                    zero-dependency CLI copied from the skill: keygen | codegen | bundle | verify | pointer | seed
  <web lib>/                  bridge.g.ts (generated) + shim.ts (browser fallback)
  package.json                depends on `@getvalence/bridge` (npm): the whole web client of §4.3
  .valence/
    baseline.json             committed: {storeSeq, storeRoutes, storeSchema, lastSeq, floor}. Append-only:
                              a missing file reads as "no store build yet", which silently disables the
                              additive-only guard, so restore it from git rather than rebuilding it
    stack-check.md            committed: latest docs-scout report
    dist-ota/                 gitignored: signed output ready to upload
  .gitattributes              one pattern per line (see below)
```

- **The runtime is two published packages, not generated code.** `valence` on pub.dev is the host: the loopback server and its nonce, the canonical check order, the activation state machine and its rollback, signature and manifest verification, the SQLite store and the §5.1 pragmas, the seed import, sync and its lease, strict bridge decoding, and the WebView with its navigation lock, back gesture and console capture. `@getvalence/bridge` on npm is the web client of §4.3. `valence codegen` emits **only** what is app-specific — the typed method and event tables, the payload types, `bridgeDispatch`, `BridgeEvents`, the `ValenceBuiltins` delegations and `valenceConfig` — and imports the rest.
  - **An app never vendors, copies or patches either package.** Before this split, every app carried its own 1,500-line host, and a fix to a security path reached none of them. A bug goes upstream; `flutter pub upgrade valence` and `npm update @getvalence/bridge` are how the fix arrives.
  - Their versions are **independent of the CLI's**, and of each other's, and of the schema's `BRIDGE_VERSION`. `pubspec.lock` and the web lockfile are committed, so CI resolves what the machine resolved.
  - What an app still owns, because a package cannot write it: the native project files (Android cleartext config and backup rules, iOS ATS and the backup exclusion), the `pubspec.yaml` asset declarations, the background-sync registration, the §6 native-value items and their setup, and its own bridge methods.
- **`appId` becomes the Android `applicationId`,** and the host's Kotlin package is Flutter's `namespace`, so the two normally differ. That is an ordinary Android arrangement, but a lot of Flutter plugins assume they match and build class names as `<applicationId>.<ClassName>`. **Prefer a fully-qualified class name whenever a plugin asks for one** (§6.2); the failure is a `ClassNotFoundException` inside the plugin's own Kotlin, which no analyzer and no unit test can see.
- **The signing private key** lives **outside the repo**, at `~/.valence/keys/<appId>.<keyId>.pem`, or comes from the `VALENCE_SIGNING_KEY` CI secret.
  - `valence keygen` refuses any key directory inside a git work tree, links included.
  - It refuses to reuse a `keyId` already in `keyring.json`.
  - `valence bundle` refuses a key whose public half doesn't match `keyring.json`.
- **`.gitattributes` is mandatory.** Git for Windows' `core.autocrlf` otherwise rewrites the built-in bundle's bytes, and every signature and hash breaks. Git ignores a line with several patterns, so write one pattern per line:

  ```
  <host dir>/assets/valence/** -text
  *.g.dart text eol=lf
  *.g.ts text eol=lf
  valence/*.json text eol=lf
  ```
- **Exclude generated files from formatters** (`.prettierignore`, Biome ignore). `codegen --check` ignores whitespace and trailing-comma changes (so `dart format` is fine), but it doesn't ignore changed quote styles.

---

## 2. OTA bundle format

### 2.1 Static host layout

```
<OTA_BASE>/<appId>/channels/<channel>.json        pointer       Cache-Control: max-age=60
<OTA_BASE>/<appId>/manifests/<seq>.json           manifest      immutable
<OTA_BASE>/<appId>/manifests/<seq>.json.sig       signature     immutable
<OTA_BASE>/<appId>/files/<sha256-hex>             file bytes    immutable, content-addressed
```

Upload order: **files, then manifests, then the pointer last.**

The pointer is unsigned, so the rollout can change without re-signing:

```json
{ "seq": 43, "rollout": 10 }
```

Hosts decode it strictly: `seq` must be an integer ≥ 1 and `rollout` an integer from 0 to 100. Anything else means "no update".

**What the unsigned pointer can and can't do.** If the CDN is compromised, an attacker can:

- freeze devices on their current bundle, by never advancing the pointer;
- change who is in the rollout cohort.

They **cannot**:

- serve unsigned code;
- change any signed field;
- push a device below its floor;
- serve a manifest under a different seq (check 3).

Don't rely on the floor to stop a freeze; it doesn't.

### 2.2 Manifest (signed)

```json
{
  "format": 1,
  "appId": "com.example.app",
  "seq": 43,
  "version": "2026.10.15+43",
  "floor": 40,
  "requires": { "bridge": 3, "data": { "calendar": 2 } },
  "entry": "index.html",
  "csp": "default-src 'self'; script-src 'self' 'sha256-…'; … frame-src 'none'; object-src 'none'",
  "urgent": false,
  "routes": ["/", "/calendar", "/settings"],
  "files": { "index.html": { "h": "<64 lowercase hex>", "n": 1834 } },
  "createdAt": "2026-10-15T10:00:00Z",
  "keyId": "k1"
}
```

- `seq`: a strictly increasing integer, and the bundle's identity.
  - `valence bundle` sets it to `max(clock seconds, baseline.lastSeq + 1, highest local manifest + 1)`.
  - Commit `baseline.json` after each release.
  - `version` is for display only.
  - **A store build always outranks the OTA release staged before it,** because its `seq` is higher and §2.4 step 1 gives a newer built-in bundle the win. So `bundle --store` leaves the channel pointing at a release no device will ever install again, and an update-path test quietly becomes a test that there is no update. **Cut the OTA release after the store build, never before it**; `bundle --store` warns when a channel points below the seq it just wrote.
- `floor`: the lowest `seq` a device may run after it commits this bundle.
  - Devices keep `state.floor` as a high-water mark that never goes down.
  - `valence bundle` refuses a floor below the previous one.
  - Raise it when a release fixes a security bug.
  - **The floor applies to the built-in bundle too**, and that is the part worth stating rather than leaving to inference. The bundle inside the APK is the one artifact every device is guaranteed to have — what a wiped or offline phone falls back to, and the only code a store review ever saw. A floor above its `seq` retires it *from the client side*, with no store release and no review, and it also retires `previous`: §2.4's ladder is left with `current` and nothing underneath. If the floor-raising bundle itself later fails a check — a host upgrade needing a newer bridge, a corrupt CAS file, a `bad` entry — the device has nowhere to go, and recovery is a store release with a `seq` above the floor: a full review cycle, which is what OTA exists to avoid.
  - **So `valence bundle --floor N` refuses `N > baseline.storeSeq`** for an OTA build, naming the store build's seq and the two ways forward: raise the floor to at most that seq (which strands every OTA below it and keeps the APK runnable — almost always what is wanted), or ship a store build above `N` first and raise the floor once it is live. A `--store` build is its own fallback, so its own `seq` is the ceiling, which the existing `floor > seq` check already enforces. A floor **carried forward** above `storeSeq` warns instead of refusing, because the floor carries forward on its own and refusing would make every later release unbuildable.
  - **The floor is stickier than it looks:** the next `bundle` with no `--floor` at all inherits it.
- `requires.bridge` is the minimum host bridge version. `requires.data` lists the bucket schema versions this UI reads (§5.4).
  - **Check 5 compares it against the generated `hostBridgeVersion` (§4.3), never a second literal.** A host whose updater compares against its own constant can under-report its bridge version, pass the whole §8 suite, build, sign and ship — and then refuse its *own* built-in bundle on first launch, with nothing left to serve, on every install, after a routine schema bump. A generated constant exists to stop exactly that drift, so the comparison has to use it.
  - **Default to the last store baseline for OTA builds.** OTA `requires.bridge` defaults to `baseline.storeSchema.version`, or the local schema version before any store baseline. Built-in/store builds default to the local schema version. `--requires-bridge` overrides either. Guard newer calls with `has()`; the below-schema warning names them. The baseline records only the newest store build, so explicitly pin lower if an older one is still supported.
- `csp` is computed by `valence bundle`: the hashes of the entry page's inline scripts, plus `connect-src` from `sync.base` and `web.connect`. The host sends it as the entry page's `Content-Security-Policy` header (§3).
- `routes` lists the top-level routes. They are compared with the store-reviewed baseline (§7).
- Each `files` path is a relative POSIX path with no empty, `.` or `..` segments, no leading `/`, no `\`, and no NUL. `h` must match `^[0-9a-f]{64}$`. **A first segment of `_host` is refused:** that prefix belongs to the host's own routes (§3), and a bundle file there would be shadowed by them. `valence bundle` and `verify` refuse it, and so does check 6, so a manifest signed by an older tool cannot smuggle one in.
- **The `.sig` file is the base64 Ed25519 signature over the exact manifest bytes, with no trailing newline.** Hosts trim whitespace anyway.
- The host embeds a keyring, `{keyId: publicKey}`. It picks the key by `keyId` with an own-property lookup. To rotate keys, ship a host that has both keys, then switch signing.

### 2.3 Host update algorithm

Run it on UI start, on resume, and every 30 minutes while in the foreground. **Never block the first paint on it.**

1. **Fetch the pointer** (5 s timeout) and decode it strictly.
   - If `pointer.seq < state.pending`, drop `pending`. The team pulled that release.
   - If `pointer.seq <= current`, or `pointer.seq` is in `bad`, or `pointer.seq <= state.pending`, or `pointer.seq <= state.trial`, stop.
   - **`trial` belongs in that list.** A trial is above `current` and has not committed yet, so without this guard the 30-minute check re-downloads the bundle that is on screen right now and sets `pending` to it. That stale `pending` then either survives the commit and re-trials a bundle already running, or survives the two-strike `bad` marking and resurrects a bundle this install has already rejected. §2.4 guards the same loop from the other end.
2. **Rollout gate:** `fnv1a32(installId + ":" + seq) % 100 < rollout`. If it fails, stop. `installId` is a random UUID made on first launch; never use a device ID.
3. **Fetch `manifests/<pointer.seq>.json`** (size cap 1 MB) and its `.sig`.
4. **Run checks 1–6** from the canonical order. Any failure means stop and log; never retry the same seq within this run.
   - **Check 5 is the bridge version plus the *shape* of `requires.data`** — every key a known read-only bucket name matching `^[A-Za-z0-9_-]{1,64}$`, no key in `valenceWritableBuckets`, every value a positive integer. Whether those pairs are *present* is step 7's job, not check 5's: a host that rejects here for a pair it does not hold never reaches step 7, and the update parks for ever with nothing logged. The name check is not optional, because step 7 interpolates these keys into a sync URL — a signed manifest must not be able to name the user's own writable bucket or an arbitrary path.
5. **Check the total size.** If the sum of `n` for files not already in CAS is over the app's cap (default 50 MB), stop.
6. **Download each missing file** to `<appSupport>/valence/cas/tmp-*`. Verify its sha256 and size (check 7), then rename it to `cas/<h>`.
7. **Data requirements (§5.4).** The updater **pulls** here. This is not a passive check.
   - **Take the §5.6 sync lease first.** This is a second sync path on the same triggers as the ordinary one — both run on UI start and on resume — so without the lease a host runs two concurrent syncs over the same `(bucket, schema)`: interleaved page transactions, racing `max_usn` writes and racing outbox-skip decisions, which is exactly what "one sync at a time" exists to prevent. Renew the lease after every applied page, as §5.6 requires, and hold it until step 8 durably publishes the manifest, signature and pending state (or this check stops). **If acquisition is busy, wait up to five seconds with 25 ms retries; then stop and log that the next check retries.** That is not a failure and must not count as one — the sync holding the lease was very likely fired by the same trigger.
   - For each `requires.data` `(bucket, schema)` pair the device does not already hold, pull it from **that pair's own `max_usn`**, which is 0 the first time. Never a hard-coded `since = 0`: `synced_at` only becomes non-null once a pull completes (§5.2), so on a flaky link a restart-from-zero re-applies everything it already has, on every UI start, every resume and every 30-minute check, for ever.
   - **Budget it like step 5.** Stop and log once this check has applied more than the app's data cap (default 50 MB across all pairs), and back off before trying again. A manifest can require many pairs and a pair can be large; nothing else bounds this.
   - **A step 7 written as "make sure the pairs are synced" can never pass.** Ordinary sync pulls only the pairs the **active** bundle reads, which during a bump are the *old* schemas, so a newly required pair has no other route onto the device. Nothing else in the system will ever unpark the bundle: `pending` stays null for ever and the app silently stops updating. That is the whole read-only schema-bump feature, disabled, with no user-visible symptom.
   - If a pull fails, or the device is offline, **stop and log which pair it was waiting for.** The bundle is not pending until its data is there, and an offline device refusing a bump it cannot read is the property that makes the bump safe.
   - **Track what is synced as a set of schemas per bucket, not a bucket → schema map.** During a bump a device legitimately holds `plants` v1 *and* v2 at once, because the old UI must keep reading v1 for the trial to be reversible. A `Map<String, int>` lets the v1 entry hide the v2 entry, so the bundle still looks unsatisfied after a successful pull.
8. **Make it pending.** Write the manifest bytes to `<appSupport>/valence/manifests/<signed seq>.json`, plus the `.sig`, and set `state.pending = seq`.
   - **Emit `bundle.updateReady` with the new `seq`, for every pending bundle.** The web app may then call `bundle.applyUpdate`, which reloads the UI, or show its own "an update is ready" line, or ignore it.
   - Release the sync lease and publish the completed `bundle.status` outcome before emitting, so a status read triggered by the event sees `ready`, the offered seq and the completed timestamp together.
   - **Not only an `urgent` one.** `applyUpdate` has never required `urgent` and `bundle.status` tells every page to call it, so gating the one *push* signal on the flag left a page with nothing but polling — and polling on resume races this very line: the check finds the bundle a few hundred milliseconds after the read, so the page learns about it on the resume *after* the one that found it. (Observed: a page subscribed for 55 seconds while the host logged `seq … is pending`, and the line appeared only on the next foreground.) **Emitting is not applying.** The host still waits for the next UI start on its own; the event only means a verified bundle is there.
   - `urgent` therefore says *the release wants this offered mid-session*, and the page decides what to do with the event. It does not control whether the event fires.
   - If no page is loaded, the event buffers and flushes with the other one-shots (§4.6).
   - Otherwise — a page that ignores the event — the bundle applies at the next UI start (the WeChat model).

**Every stop in this algorithm logs its reason.** An update that declines to apply looks exactly like one that failed: the pointer and the manifest are fetched and verified, and then nothing happens while `pending` stays null. Steps 2, 5 and 7 stop on a perfectly healthy system, and step 7 can stay stopped for days, so each stop names its step and what it is waiting for. Without that line the only way to diagnose a phone that will not take an update is to read the host's source.


### 2.4 Activation state machine

The state lives in `<appSupport>/valence/state.json`. Write it atomically: write a temp file, flush, then rename.

```json
{ "installId": "…", "port": 23817, "current": 42, "previous": 41, "pending": 43, "trial": null, "trialFails": 0, "serving": null, "bad": [39], "floor": 40, "builtinRefused": null }
```

`serving` is the trial seq while a trial is on screen and still unconfirmed. Otherwise it is null.

**When transitions run.** They run when the host widget is about to load a bundle (UI start), **never in `main()` or in a background isolate.** iOS background launches and workmanager runs must not consume a trial.

**What that costs, and what may be deferred.** Step 1 below decodes a manifest, verifies an Ed25519 signature and hashes every file it installs, which is real work in front of the first frame — but it is **gated on the built-in seq being above `current`** and it sets `current = builtin`, so it runs once per store release and is a no-op on every launch after that. The budget for an ordinary launch is the state read, the promotion decision and the bind: tens of milliseconds, not hundreds. If a host is slower than that, time `installBuiltin`, the UI-start transition and `Store.open` separately before blaming any of them. What may move off the first-paint path: the update check (§2.3 says never block the first paint on it) and sync. What may not: the promotion decision, because the page that loads has to be the one the state machine chose; and the seed import, because §5.2's first launch has to paint *with data* — an empty first screen is what guideline 4.2.3(ii) is about.

**CAS integrity is re-checked lazily, not at startup.** Nothing re-hashes the store on launch: step 1 skips files already in CAS, and after the first launch of a store build step 1 does not run at all. A file verified at download time (check 7) can still rot on disk afterwards, so the check has to live somewhere — and the only honest place is where the bytes are used. **The server verifies a CAS file's size and sha256 the first time it serves that file for the active manifest, and caches the result for that manifest's lifetime.** **On a mismatch it deletes the file, answers 500, and records the hash so it can be re-fetched.** For a *pending* bundle that happens at §2.3 step 6 on the next check. For the bundle already being **served** there is no step 6 to reach — step 1 stops on `pointer.seq <= current`, and nothing else in the algorithm looks at the active manifest's files — so the update check needs a **repair pass before step 1** that re-fetches the active manifest's deleted files from `files/<hash>`, through check 7 like any other download. Without it a rotted entry page is a permanent blank screen until some unrelated, newer release happens to ship. That is the mechanism behind §8's "a corrupt CAS file is re-downloaded" row. A size comparison is not a substitute: a corruption that preserves length is precisely what a hash is for.

At UI start:

1. **A newer built-in bundle wins.** If the built-in bundle's seq is above `current` (a store update shipped it):
   - first install it into CAS through the same checks as an OTA bundle, skipping check 3 because a built-in bundle has no pointer;
   - set `previous = current` and `current = builtin`;
   - drop `pending` and `trial` if they are at or below it, and clear `serving` if its trial was dropped;
   - **schedule garbage collection** (see below). A store release changes the built-in bundle's `requires.data`, which is the thing pinning the oldest read-only pairs on the device — so it is the single event most likely to make a pair collectable, and a GC that runs only after a commit never sees it.
   - **If the built-in bundle fails its checks, nothing is promoted.** Log which check failed, then serve `current` at step 4 if there is one. A built-in bundle is never added to `bad`: it is not a release this install can decline, and the next store update replaces it. Nothing else in the state changes — including the `bad` list, so the bullet below about releasing a built-in seq from `bad` applies only once the checks have passed.
     - **Record the refusal** (`state.builtinRefused`) and skip the work until it no longer applies. `current` stays where it was, so the step-1 gate is true again on the very next launch and for ever: without this, every launch re-decodes the manifest and re-verifies the signature in front of the first frame on an install that is already broken. Log it once per process, not once per launch.
       - **Key the record on the manifest bytes *and* the host's own bridge version, not on the seq.** The usual cause below is `requires.bridge` above what the host reports at check 5, and the fix for that is a *host* change — a new APK shipping the **same** `assets/valence/builtin/`, and therefore the same seq. Keyed on the seq alone, step 1 skips on the very host built to fix it, and the install stays wedged for ever with no way out but a second store release. The same applies to a re-checkout that repairs a CRLF-mangled asset without moving the seq. A short fingerprint — `<seq>.<bridgeVersion>.<first bytes of sha256(manifest.json)>` — is enough, and reading those bytes is already how step 1 learns the seq.
       - **Gate on the seq before loading, not after.** The decision to run step 1 at all needs only the `seq` field out of the manifest. Verifying first and comparing afterwards puts an asset read, a manifest decode, an Ed25519 verify and a `stat` per bundle file in front of **every** first frame, for a step that is a no-op after the first launch of a store build.
     - **With no `current`, that install is unrecoverable and must say so** rather than painting a blank WebView. This is a fresh install of a broken store build — the most expensive mistake a release pipeline can make — and the host's only honest move is a native error screen naming the failed check, because there is no bundle to render one in. Guideline 4.2.3(ii) is about an empty first screen, so a blank WebView is also the worst possible shape for review.
     - The usual cause is not corruption but a **bridge-version mismatch**: `requires.bridge` on the built-in bundle above the version the host reports at check 5 (§2.2). `codegen --check` catches a stale generated constant and `bundle --builtin` now compares the two numbers itself, so what is left to go wrong is a host that reports its bridge version from **anywhere but the generated constant** — a second, hand-written field. Nothing can see that from outside the host source, and `verify` cannot: "verifies" only ever meant signatures and hashes, never "will run". /valence doctor compares the built-in manifest with the generated constant and fails on a mismatch; a host with its own field needs the check 5 test from §8 as well.
     - **An install frozen this way cannot be fixed over the air by default.** An OTA bundle cut from the same schema inherits the same `requires.bridge` and is refused at §2.3 check 5 for the same reason, and the CLI will not warn because the baseline now records the new number. The hotfix has to be built with `--requires-bridge <the version the host actually reports>`. Otherwise it is a new store release.
2. **A crashed trial.** If **`trial != null`** and `serving == trial`, the last UI start showed the trial and the process died before the trial was confirmed or timed out. Count it as a failure (see below).
   - **The `trial != null` half is load-bearing.** In the ordinary no-trial state both fields are null, so a condition written as just `serving == trial` is satisfied on every launch: the host counts a failure each time, reaches two strikes, and marks whatever it is serving bad. Every comparison of `serving` and `trial` in this section carries that guard.
3. **A pending bundle, with no trial.** Promote `pending` only if it is **above `current`, at or above `state.floor`, and not in `bad`**. Then set `trial = pending`, clear `pending` and reset `trialFails` to 0. A `pending` that fails any of the three is dropped and nothing is promoted.
   - `current` and the floor are tested here, not only at download time, because a pointer can move backwards — the team pulling a release is a documented action — which can leave a `pending` behind a `current` that a later commit raised, or behind a floor that same commit raised. §2.3 check 4 looks at the floor only when the bundle is fetched.
4. **Serve.** If there's a trial, serve it and set `serving = trial`. Otherwise serve `current`, or the built-in bundle if there's no `current`. If that built-in bundle failed step 1's checks, there is nothing left to serve: surface it natively (step 1) rather than binding the server to a manifest the host has already refused.

**Counting a failure** happens in exactly one place, and only when there is a trial to count against. It runs from step 2 or on a ready timeout:

- **if `trial` is null, there is nothing to count.** Do nothing and add nothing to `bad`. A ready timeout on a `current` page means the app is slow, not that a release is bad;
- increment `trialFails` and set `serving = null`;
- if `trialFails` reaches **2**, add the trial to `bad`, clear `trial` and `trialFails`, and **drop `pending` if it is at or below the trial's seq**;
- otherwise keep the trial: the next UI start tries it once more, since one failure can be a user who opened and closed the app at once.

**`bad` is the list of seqs this install refuses.** The invariant is one line: *no path promotes, re-downloads or serves a seq in `bad`.* Four places where that would otherwise be ambiguous:

- **`applyUpdate` promotes only through step 3,** so it inherits all three of step 3's tests (see below);
- **`current` is never added to `bad`.** Only a trial is, and only by the two-strike rule above. A host that can put `current` in `bad` has nothing left to serve;
- **a built-in bundle whose seq is in `bad` is removed from `bad` as step 1 installs it.** A store install is user-initiated and is itself the replacement, so it overrides an earlier OTA judgement rather than being blocked by it;
- **entries below `state.floor` may be pruned at commit.** §2.3 check 4 already refuses them, so the list only has to remember seqs at or above the floor. Otherwise `bad` grows for the life of the install.

**The ready timer.**

- It is armed **only while serving a trial** (`trial != null && serving == trial`). A `current` page is not on probation, so a slow start costs it nothing.
- It counts **15 s of foreground time**, starting at the entry page's `onPageStarted` and paused while the app is in the background.
- **It commits only if `app.ready()` comes from the page that is serving the trial** (`trial != null && serving == trial`). A `ready()` from a `current` page never commits anything, and neither does a late `ready()` from a page whose trial has already been given up on — by then `trial` is null, and without the guard `null == null` would commit `current = null`. On commit:
  - `previous = current`, `current = trial`, `trial = null`, `trialFails = 0`, `serving = null`;
  - drop `pending` if it is **at or below** the seq just committed, so the next UI start neither re-trials the live bundle nor promotes something the commit has overtaken;
  - `state.floor = max(state.floor, manifest.floor)`;
  - then run garbage collection.
- **The page's side of the contract is "exactly one `ready()` per page load, on every path that paints — including the paths that show no data."** Stating it as "after the first meaningful paint" is what everyone writes and what everyone implements as *the end of the data load*, because that is where the first meaningful paint usually is. A first-run gate that asks the user something, an empty state, a permission prompt, an error screen and an offline screen all paint without that load ever finishing, and on a fresh install one of them **is** the whole first launch. The bundle then never reports ready, the host counts a failed trial, and two launches later perfectly good code is in `bad` and rolled back. The symptom arrives as "the OTA is broken", which points at the update system rather than at the one screen that forgot to speak. Put the call in a mount effect that every rendered path reaches, keep it to one call per page load, and treat a conditional that can return before `ready()` as a bug.
- **The trial proves the bundle only because the server revalidates.** All this machinery asks is "did a page call `ready()`", and before 0.4 the serving rules let a stale WebView cache answer that question with the *previous* release's JavaScript (§3, "Serving"): healthy-looking `committed` lines over code that never changed. A host that keeps `immutable` on bundle files has no working rollback, whatever this section says.
- **A mid-session reload runs step 4 only, never steps 1 to 3.** Both reload paths — `applyUpdate` and a ready timeout — are mid-session, and re-entering the UI-start transitions breaks each of them in a different way. After `applyUpdate`, `trial` and `serving` are already set, so step 2's `serving == trial` is true **by construction** and the host spends a strike on the bundle it is about to show; two of those and a healthy release is in `bad`. After a timeout, step 4's first branch serves the **trial** again rather than `current`, so the user sees the broken bundle twice 15 s apart and the retry this section grants to the *next UI start* is consumed in the same session. So: after `applyUpdate`, serve the trial; after a timeout, serve `current` explicitly and leave `trial` set for the next launch.
- **On timeout,** count a failure, then reload `current` right away — **and only then let the scheduled GC run.** The WebView is still showing the trial page until the reload lands, and its lazily loaded chunks, fonts and images are CAS files that the two-strike marking has just made collectable. Deleting them under a live page produces a filesystem error where §2.4's delete-and-500 path should be, and that path cannot recover a seq which is now in `bad`. The same ordering applies to `applyUpdate` dropping a bad `pending` mid-session.

**Garbage collection** is **scheduled** by any transition that changed the kept set — a commit, a built-in supersede (step 1), a dropped `pending` or `trial` (steps 1 and 3), the two-strike `bad` marking, and `applyUpdate`'s drop of a bad `pending`. It **runs on the first post-frame callback after that**, never inside the transition and never from a background isolate: step 1 already pays for a manifest decode, a signature verify and a hash of every file it installs in front of the first frame, and a directory walk, a `stat` per file and a SQLite transaction on top of that is exactly the launch that must not get slower.

- **A commit is not the only thing that frees disk, and it is not the most important one.** The built-in bundle's `requires.data` is what pins the oldest read-only pairs, and a store release is the only thing that ever changes it — so the one event most likely to make a pair collectable is precisely the one a commit-only GC misses. An app that ships mostly by store release, or a user who never leaves the app open long enough for the 30-minute check to find an OTA, then never collects anything: on an offline-first app those stale pairs are the largest thing on disk.
- **A supersede collects one release behind.** Step 1 sets `previous = current`, so the store build it replaces is still kept — what a supersede actually frees is whatever fell out of `previous`, which is the store build *before* it, or an OTA bundle. Two store releases in a row therefore collect the first one's pairs on the second. That is the lag, and it is fine; what was broken was collecting nothing, ever.
- **Take the §5.6 sync lease before deleting pairs, and skip the pair step if it cannot be taken.** §2.3 step 7 pulls a required pair while holding that lease, and its manifest is not on disk until step 8 — so a GC that walks the kept set in the middle of step 7 sees a freshly pulled pair that no *kept* manifest requires yet, deletes it, and leaves a `pending` whose data is gone. Nothing re-pulls it either: step 1 of §2.3 stops once `pointer.seq <= pending`.
- **CAS files carry the same hazard, and need the same protection.** Step 6 renames files into CAS **before** step 8 writes the manifest, and step 7 sits between them. A collection in that window computes its kept set from the live state, cannot see the seq being downloaded, and deletes exactly what step 6 has just fetched — after which step 1 stops on `pointer.seq <= pending` for ever, the trial 404s its entry page, and two strikes put a **healthy** release into `bad`. **Hold the hashes of a manifest being fetched in an in-flight set from step 5 until step 8 completes or the run gives up, and treat that set as kept.** Skip `tmp-*` names too: a download mid-rename is not a hash, so it is never in the kept set, and deleting it leaves step 6 renaming a file that is gone. Only *manifests* are genuinely safe to sweep without this, because no manifest for an in-flight bundle exists on disk.
- **Keep** the manifests for `current`, `previous`, `pending`, `trial` and the built-in bundle, plus every CAS file they reference.
- **Delete** every other manifest and CAS file.
- **Delete** each **read-only** `(bucket, schema)` pair that no kept manifest requires (§5.4).
- **Never delete a writable bucket this way.** No manifest ever lists one in `requires.data` — that field is only about read-only schema co-versioning — so a rule phrased as "delete every pair no manifest requires" destroys all of the user's own data on the first commit after an OTA. Skip `valenceWritableBuckets` before the kept-pairs test, and refuse them again in the store's drop path.

**`bundle.applyUpdate`** is the only transition that runs mid-session, and it is a **full trial promotion**, not a shortcut:

- if there is no `pending`, or `pending` is in `bad`, it is a no-op (drop a bad `pending` as in step 3) and returns normally;
- otherwise run step 3 and step 4 exactly as at UI start: `trial = pending`, clear `pending`, `trialFails = 0`, serve the trial, `serving = trial`, reload the WebView and start the ready timer;
- the ready timer and failure counting then apply unchanged, so a white-screening urgent bundle costs two strikes and reverts like any other.

An urgent release must not be a rollback blind spot. The method is reachable only from the page the host is already serving, so it can't be used to skip a check.

**`applyUpdate` does not require `urgent`,** and never has: any `pending` promotes. `urgent` is the release's request that the page offer it mid-session; `bundle.updateReady` fires for every pending bundle either way (§2.3 step 8), so a page can show "an update is ready" whenever one is.

**Rollback means rolling forward.**

- Re-release the last good web commit with `valence bundle`. That gives it a new, higher seq.
- Pointing the channel at an older seq only cancels pending downloads (step 1 of §2.3). Devices that already committed the bad bundle stay on it until something newer arrives.
- Devices still trying a bad bundle revert on their own.

**Backups.** Exclude all of `<appSupport>/valence/` from device backups:

- iOS: `NSURLIsExcludedFromBackupKey`;
- Android: `dataExtractionRules` and `fullBackupContent`.

A restore then starts clean from the built-in bundle, with a new `installId` (no cloned rollout cohort and no stale trial). The SQLite database lives outside `valence/` and is backed up, because it holds user data.

---

## 3. Loopback server (dart:io `HttpServer`)

### Port

- The default port is `fnv1a32(appId + ":" + installId) % 20000 + 10000`, persisted in `state.port`.
- That range avoids the OS ephemeral ranges (Android 32768+, iOS 49152+).
- `installId` keeps the port from being precomputed from the `appId`, and gives cloned profiles (work profile, dual apps) different ports.
- **The port is not a secret.** A loopback scan finds it in about a second. The nonce is what actually protects the bridge.
- **If the persisted port can't be bound, never load or keep a page from it.** Pick a random free port **in the same 10000 to 30000 range** — retry `rng.nextInt(20000) + 10000` until a bind succeeds, never `bind(port: 0)`, which returns an OS ephemeral port and lands exactly in the range this scheme exists to avoid — then persist it and load from that. Web storage for that origin is lost, which is acceptable: durable data lives in SQLite (§5).
- **Swapping the active bundle restarts the server.** Applying an update and reverting a failed trial both change the manifest the server maps paths through, so **close the old server before binding again**. Otherwise the host collides with its own listening socket, moves to a new port and rotates the nonce in the middle of a fallback.

### Nonce

- A 128-bit random nonce is generated whenever the server binds a **new** port, including the first bind of a launch.
- **Rebinding the same port on resume keeps the nonce,** because the loaded page still holds it. The nonce rotates only together with a port change, and every port change reloads the page.
- When serving the entry page, the server inserts `<meta name="valence-nonce" content="<nonce>">` right after `<head>`.
- `bridgeDispatch(…, nonce:)` rejects any message without it (`E_DENIED`).
- So a page served by anything other than our own server, such as another app that grabbed the port, gets no bridge access.

### Serving

Handle GET and HEAD only; any other method is 405. **Normalise the path once before choosing a branch:** percent-decode it (`requestedUri.path` already does this in `dart:io`) and then **400 any path with an empty, `.` or `..` segment.** Without that step the reserved prefix below is bypassable — `//_host/media/<id>` does not start with `/_host/`, cannot be a manifest path, and has no file extension, so it falls through to branch 3 and returns the entry page with HTTP 200. A page's own URL join produces it by accident.

Then three branches, **in this order**:

1. **Host routes, under the reserved `/_host/` prefix.** Anything the host itself serves to the page — a captured photo, a generated PDF, a downloaded attachment — lives here and is matched *before* the manifest. A bundle may not ship a file under `_host/`: `valence bundle` refuses it, check 6 refuses it on the device (§2.2), so the prefix cannot collide with the web build.
2. **A bundle file.** Map the path to a hash through the active manifest, then serve `cas/<h>`.
3. **The SPA fallback.** A path with no file extension gets the `entry` file. Anything else is 404.

**The order is the contract, because the fallback is broad.** It answers any extensionless path, so a host route placed *after* the manifest lookup is swallowed by it: a missing photo at `/media/<unknown-id>` returns **HTTP 200 with the entry page's HTML**. That is the hardest failure in the system to notice — an `<img>` renders a blank square, a `fetch` parses HTML as JSON, and neither side logs anything. Reserving `/_host/` and matching it first is what makes an unknown host route a 404 the caller can act on.

**Returning a file to the page** (the `/_host/` branch). The bridge carries JSON only (§4.2), so this is the only path from native bytes to the WebView, and every decision in it has a wrong answer that fails silently or dangerously:

- **the host generates the id, never the page.** 24 hex characters or similar, validated on the way back in against the same pattern that produced it. A web-supplied path is never joined to a directory — `/_host/media/..%2Fsecret`, a short id and an upper-case id are all 404;
- **the URL handed to the page is relative** (`/_host/media/<id>`). The port moves when a bind fails, and when a resume cannot reclaim the socket (below) — and these ids get stored in durable SQLite rows, so an absolute `http://127.0.0.1:<port>/…` is dead after the next rebind and stays dead;
- **these bytes are not ours, so they must never be a document.** This branch serves whatever a camera, a download or a remote server produced, on the same origin as the bundle. A `/_host/` response therefore carries `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; sandbox`, and a `Content-Type` from an **allow-list of non-scriptable types** — never `text/html`, `application/xhtml+xml`, `image/svg+xml` or anything else a WebView will execute. Without all three, `location.href = '/_host/dl/<id>'` loads attacker-supplied markup same-origin with **no CSP at all**; a `JavaScriptChannel` is per-WebView, not per-document, so that document can `fetch('/')`, read the nonce out of the entry page's `<meta>`, and use the whole bridge. §7's "the bridge is reachable only from our own pages" depends on this branch never serving a page;
- **the navigation lock is the entry path, not the origin.** `onNavigationRequest` permits `http://127.0.0.1:<port>/` and the bundle's own routes; it does not permit `/_host/…` as a main-frame navigation. Those URLs are for subresources;
- serve it `Cache-Control: private, max-age=31536000, immutable` — the id is content-addressed by construction.

**`/_host/` is same-origin, so the computed CSP's `'self'` already covers it** for `img-src` and `media-src` in the *bundle's* pages. Don't rely on a laxer directive happening to be there.

**The fallback serves the entry page at any depth, so the entry page's own asset URLs must be absolute.** A build with a relative base (`base: './'` in Vite) emits `<script src="./assets/index-xxxx.js">`; served as the fallback for `/profiles/p-1`, the WebView resolves that to `/profiles/assets/index-xxxx.js`, which has a file extension and is therefore a genuine 404. The page never runs, so nothing in it can report the blank screen. It survives a cold start — that always loads `origin/` — and appears only on a reload, a WebView process restart, a back gesture onto a nested route or an iOS resume after the socket was reclaimed. `valence bundle` warns about it. Whichever knob your framework uses, the output must reference assets from the origin root: `base: '/'` in Vite; in SvelteKit it is the setting that controls *relative* asset paths rather than the deployment subpath, so check your version's docs.

- Headers:
  - the entry file: `Cache-Control: no-store` and `Content-Security-Policy: <manifest.csp>`;
  - other files: `Cache-Control: no-cache` and `ETag: "<the file's sha256 from the manifest>"`, and a `If-None-Match` naming that tag is answered `304` with no body;
  - `Content-Type` from a small extension map;
  - `X-Content-Type-Options: nosniff`.

**A bundle file's URL is stable across releases, so the hash — not the URL — has to be the cache key.** The path comes from the web build and the port survives a resume, so `/assets/index-Ba1jK_XS.js` means a different file in every release that happens to emit that name. Serving it `max-age=31536000, immutable`, which is what a CDN would do and what Valence did before 0.4, tells the WebView it may use its stored copy for a year without asking: the new bundle downloads, verifies, activates, and the page that renders is the **old** one. Nothing reports it. The update log says `committed`, because the trial only asks that *some* page call `ready()` (§2.4) and the old page does — so the safety net is satisfied by the very code the release was meant to replace, and the next broken release is never rolled back either.

It is easy to believe this cannot happen, because a build tool usually puts a content hash in the file name. Two things escape that: anything copied verbatim out of `public/` (icons, fonts, `manifest.webmanifest`, a service worker), and any release where only such a file changed. There is no safe subset, so there is no exception: `no-cache` plus the hash as a strong `ETag` is **always** correct, and it is not `no-store` — the WebView keeps its copy and a revalidation that matches is one loopback round trip with an empty body. Conditional requests to `127.0.0.1` cost microseconds; being wrong costs a release nobody can tell failed.

`/_host/` files are the one exception, and they keep `immutable`: their ids are content-addressed by construction, so that URL can never mean different bytes.

**A service worker puts the whole hole back, and the server cannot stop it.** A precaching worker answers from Cache Storage without asking the server at all, so `no-cache` and the `ETag` never run and the page that renders is the previous release's — identical to the `immutable` failure above, including the trial committing on the old page's `ready()`. A bundle does not need one: its files are already on the device and served from loopback, which is what a service worker exists to approximate. Register it only when `inHost()` is false, or leave it out of the build the bundle is cut from. `valence bundle` warns when it sees a registration in the output.

### The system back gesture

Android users expect back to go back, and a `Scaffold` holding a `WebViewWidget` pops its only route instead — so the first swipe from any sub-screen **closes the app.** It is the most common complaint about WebView apps on Android and the first thing a Play reviewer does. Wrap the scaffold:

```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) async {
    if (await controller.canGoBack()) {
      await controller.goBack();
    } else {
      await SystemNavigator.pop();
    }
  },
  child: Scaffold(body: WebViewWidget(controller: controller)),
)
```

Two things make it work, and neither is obvious from the rest of §3:

- **`onNavigationRequest` never fires for `history.pushState`,** so a host author who has only read the navigation lock has no reason to think the page has navigable history at all. The web app needs real History API routes for there to be anything to go back to.
- **History is safe against a reverted trial.** Every entry is a same-origin loopback path, answered from the *currently served* manifest, so going back cannot reach a bundle the host has given up on. The URL is the same; the bytes behind it are whatever is live.

If the web app has modal state of its own it wants the gesture for, the host can emit an event and let the page consume it, but it must still close the app when nothing handles it. Swallowing back is worse than popping too eagerly.

### Logs

**The host forwards the WebView's own output, or a broken bundle is undiagnosable.** Wire `setOnConsoleMessage`, plus `onPageStarted`, `onPageFinished` and `onHttpError`, in `host.dart`. Without them a JavaScript error during the bundle's bootstrap produces nothing at all — no log, no `onWebResourceError`, just a dark rectangle — while the host is working correctly. It is three lines, and it is the first thing to check when a bundle never reaches `ready()`.

**The host also logs every bridge error it returns**, at least in debug builds. `bridgeDispatch` never throws (§4.3): it turns a handler's exception into an error reply, the page's `await call(...)` rejects inside an effect nobody awaited, and the whole failure reaches neither a log nor a screen. A handler that throws on every call is then indistinguishable from one that works — the UI says the reminder is set, and no alarm exists. One line at the dispatch site is the difference between a one-line diagnosis and an afternoon.

### Resume

- **The resume callback can arrive before start-up has finished. Ignore it until the first activation has completed.** On Android the lifecycle observer fires during the first launch, *while* §1's start-up sequence is still running — so a resume handler that touches the server, the store or the active bundle can run before any of them exists (`LateInitializationError`, or whatever your language calls it). §2.3's "the update check runs on UI start, on resume" and the rebind below both describe steady state; neither says when steady state begins. Guard the resume path on "has the host finished starting", or register the observer only after the first `activateForUiStart`. This is the same class of rule as "no transition runs from a background isolate" (§8).
- **The same observer feeds `app.lifecycle` and `app.online` (§4.6).** The host maps Flutter's five lifecycle states onto four of its own, emits only changes, and keeps the current pair for `app.state()`. The start-up guard above applies to the resume *work*, not to the recording: a transition during start-up still updates what `app.state()` returns, even though no page exists to receive the event and the event is therefore dropped rather than queued. The page that loads next reads the current pair and has missed nothing.
- iOS can reclaim listening sockets while the app is suspended. On `AppLifecycleState.resumed`, probe the server and rebind the same port.
- If rebinding succeeds, keep the nonce, so the page keeps working.
- If rebinding fails, rotate the port and the nonce and reload the page. The old page must not keep running against a port we no longer own.
- *Residual risk:* between a reclaim and the rebind, a lazy chunk request could be answered by another process. The upgrade path is request interception (`WKURLSchemeHandler` on iOS, `WebViewAssetLoader` on Android) once webview_flutter exposes it, or a small platform plugin. Until then, keep the startup route's chunks preloaded.

### Platform setup

- **Android:** `res/xml/network_security_config.xml` permits cleartext for `127.0.0.1` only.
- **iOS:** use the App Transport Security (ATS) loopback setting the docs-scout confirms. Never `NSAllowsArbitraryLoads`.

### Why not the alternatives

- **`file://`:** SvelteKit 3 and Vite builds emit ES modules plus `modulepreload`, and Android WebView blocks module scripts from `file://` because the origin is null.
- **Service workers:** in WKWebView they need App-Bound Domains, which restrict script injection and message handlers.

---


### 3.1 Debug development server (R9)

Only `kDebugMode && String.fromEnvironment('VALENCE_DEV_URL') != ''` enables development.
Profile and release ignore the define; the proxy branch and upstream URL are tree-shaken.
The URL is an explicit developer trust grant, never config or manifest data: an HTTP(S) origin
without credentials, query, fragment or a path. Use `http://10.0.2.2:5173` on Android emulators,
or a reachable LAN origin. Use test accounts and data in development.

The WebView still loads the owned loopback origin. A debug-only GET/HEAD proxy fetches the
chosen server, injects the launch nonce before scripts, disables caching and proxies HMR
WebSockets. Reserved `/_host/` paths remain native. Redirects are refused. Neither request
credentials nor native bearer tokens are forwarded. A frame-src/frame-ancestors CSP forbids
subframes and workers, preventing dev service workers from persisting into a store build. Main-frame navigation retains the ordinary origin lock and strict bridge decoding.
Hot updates retain the page and nonce; document reloads re-inject the same launch nonce.
Dev pages cannot consume, commit or fail OTA trials; automatic OTA checks and applyUpdate
are disabled. A verified current or built-in bundle above the floor supplies the schema context.
Sync remains available. Use a separate development app id to isolate local data and accounts.

Development startup logs the upstream origin and explicitly says OTA checks, trials, ready commits
and `bundle.applyUpdate` are disabled. It must not label the development page as a served signed
bundle; the verified bundle supplies schema context only. Each bypassed `handleReady`, `reloadPage`,
update check and `applyUpdate` logs a `dev:` line naming the skipped operation. A resolved bridge
call in this mode is not evidence of trial commit or promotion. Restart without the define to test
signed offline starts and rollback. Diagnostics contain the origin only, never the nonce or tokens.

`valence dev --web-dir web --port 5173` runs the local package's `dev` script with
`--host 0.0.0.0 --port 5173 --strictPort` and prints the matching debug Flutter command.
`--device-host` changes the printed emulator/LAN address. Package scripts are trusted local
code. Stop the command to stop its child. Signing keys, baseline and codegen do not change.
The initial CLI supports Vite-compatible dev arguments (including Vite-based frameworks);
other frameworks can start their own server and use the printed Flutter define directly.

R9 matrix: nonce before scripts; no-cache; HMR WebSocket round-trip; reserved host routes;
denied methods, redirects and credential forwarding; dev does not commit or fail trials;
release AOT built with a dev define excludes the upstream URL and proxy implementation.


## 4. Typed bridge

### Schema 15 returned-field additions (R17)

Schema 15 adds only nullable returned fields: `AppInfo.builtins: int?`,
`SyncStatus.reason: string?`, and `BundleStatus.urgent: bool?`. Existing fields
and method shapes retain their meanings. Older schemas omit these fields from
generated delegations; newer pages on older hosts receive null/missing values.
The store baseline remains unchanged until a store release records the new host.

`builtins` reports the Valence built-in capability revision, currently 15,
independently of the application's `bridge` schema number. Missing means unknown,
so `(info.builtins ?? 0) >= 5` gates the `data.list.after` addition correctly even
when an app's own schema number is larger. Existing method/event `has()` gates
remain valid. A revision certifies built-in implementation support, not that an
optional method is declared or enabled by this store build.
Declaring `AppInfo.builtins` opts into current built-in parameter shapes:
codegen refuses it if any declared built-in omits a supported optional parameter
(currently `data.list.after` and `auth.setToken.account/discardPending`). This
prevents reporting a revision whose grown params the strict dispatcher rejects.
Methods may still be omitted; gate their presence with `has()` as before.

`reason` is the last completed ordinary sync attempt's outcome, persisted beside
the offline observation. Scoped attempts count too; it does not certify that all
buckets succeeded. Busy/skipped runs and exceptions preserve the previous outcome.
A migrated or never-attempted database returns null; no-server runs preserve it.
Account switch/sign-out clears this observation with the other account-owned sync
observations. It is an open string set; unknown reasons are not success. Existing
anonymous-401 semantics are unchanged. An app needing an acknowledgement tied to
one authenticated bucket must still track its explicit scoped check.

`urgent` describes the currently pending bundle's signed manifest, never the
pointer's offered bundle or the currently serving bundle. No pending bundle,
failed re-verification or a concurrent pending change returns null. Both false
and true are meaningful. Reading it verifies local manifest bytes and never
downloads or activates anything. The synchronous Dart `bundleStatus()` API remains;
generated schemas declaring urgency use additive `bundleStatusWithUrgency()`.
Urgency is a UI hint, never permission to bypass trial, ready, rollback or user
confirmation policy. Every pending update still emits `bundle.updateReady`.

### 4.1 IDL: `valence/bridge.schema.json`

```json
{
  "version": 6,
  "methods": {
    "app.ready":          { "since": 1, "params": {}, "returns": "void" },
    "app.info":           { "since": 1, "params": {}, "returns": "AppInfo" },
    "app.state":          { "since": 6, "params": {}, "returns": "AppState" },
    "data.get":           { "since": 1, "params": { "bucket": "string", "key": "string" }, "returns": "json?" },
    "data.list":          { "since": 1, "params": { "bucket": "string", "prefix": "string?", "limit": "int?", "after": "string?" }, "returns": "Row[]" },
    "data.count":         { "since": 5, "params": { "bucket": "string", "prefix": "string?" }, "returns": "int" },
    "data.getMany":       { "since": 3, "params": { "bucket": "string", "keys": "string[]" }, "returns": "Row[]" },
    "data.put":           { "since": 1, "params": { "bucket": "string", "key": "string", "value": "json?" }, "returns": "void" },
    "sync.now":           { "since": 1, "params": { "buckets": "string[]?" }, "returns": "SyncResult" },
    "sync.status":        { "since": 3, "params": {}, "returns": "SyncStatus" },
    "prefs.get":          { "since": 1, "params": { "key": "string" }, "returns": "string?" },
    "prefs.set":          { "since": 1, "params": { "key": "string", "value": "string?" }, "returns": "void" },
    "open.external":      { "since": 1, "params": { "url": "string" }, "returns": "void" },
    "bundle.applyUpdate": { "since": 1, "params": {}, "returns": "void" },
    "bundle.status":      { "since": 6, "params": {}, "returns": "BundleStatus" },
    "secure.get":         { "since": 2, "params": { "key": "string" }, "returns": "string?" },
    "secure.set":         { "since": 2, "params": { "key": "string", "value": "string" }, "returns": "void" },
    "secure.delete":      { "since": 2, "params": { "key": "string" }, "returns": "void" },
    "auth.setToken":      { "since": 2, "params": { "token": "string?", "account": "string?", "discardPending": "bool?" }, "returns": "void" },
    "auth.hasToken":      { "since": 2, "params": {}, "returns": "bool" },
    "auth.account":       { "since": 13, "params": {}, "returns": "string?" },
    "http.request":       { "since": 4, "params": { "url": "string", "method": "string?", "headers": "json?", "body": "string?" }, "returns": "HttpResponse" }
  },
  "events": {
    "sync.changed":       { "since": 1, "payload": { "buckets": "string[]" } },
    "sync.done":          { "since": 6, "payload": { "result": "SyncResult" } },
    "bundle.updateReady": { "since": 1, "payload": { "seq": "int" } },
    "app.resumed":        { "since": 1, "payload": {} },
    "app.lifecycle":      { "since": 6, "payload": { "state": "string" } },
    "app.online":         { "since": 6, "payload": { "online": "bool" } },
    "auth.expired":       { "since": 2, "payload": {} }
  },
  "types": {
    "AppInfo":      { "platform": "string", "host": "int", "bridge": "int", "bundle": "int", "locale": "string" },
    "AppState":     { "lifecycle": "string", "online": "bool" },
    "Row":          { "key": "string", "value": "json", "usn": "int" },
    "SyncResult":   { "buckets": "string[]", "changed": "int", "offline": "bool", "reason": "string?", "pending": "int?" },
    "SyncStatus":   { "pending": "int", "lastSyncedAt": "int?", "offline": "bool" },
    "BundleStatus": { "serving": "int", "pending": "int?", "trial": "int?", "reason": "string", "offered": "int?", "checkedAt": "int?" },
    "HttpResponse": { "status": "int", "headers": "json", "body": "string" }
  }
}
```

**`AppInfo.bridge` is the app's own schema `version`, not Valence's built-in version.** It is the same integer as `requires.bridge`'s default and as the `hostBridgeVersion` codegen emits, and the app numbers it: an app that adds six methods of its own is at 6 regardless of which built-ins it carries. It answers exactly one question — *does this host run my schema or an older one of mine* — and `has()` answers it per name. It is **not** a Valence capability number, so it must never be compared against a built-in's version (§4.2, the `after` gate). The two coincide only for an app that has never added a method.

The type language is `string | int | num | bool | json | void | <TypeName>`. A `[]` suffix means a list and a `?` suffix means nullable; for example `json[]?` is a nullable list. `json` allows any JSON value, including null.

**A `json` param generates the TypeScript type `Json`, which is an index signature,** and a TS `interface` has no implicit index signature — so the obvious `export interface Snapshot { … }` will not pass to a `json` field, with the opaque "Index signature for type 'string' is missing". Declare the shape as a `type` alias instead. Prefer a named schema type to `json` wherever the shape is actually known: it generates a strict decoder on both sides.

**`codegen` rejects:**

- names that would break the generated code: Dart reserved words and built-in identifiers, `Object` members, and `toJson`/`fromJson`;
- reserved type names (`Json`, `String`, `Methods` and so on);
- two names that become the same identifier (`dataX.get` and `data.xGet`).

**Evolution rules (enforced):**

- **The schema is additive only.** `valence bundle --store` (the built-in bundle of a build you submit to the stores) records the shipped schema in `baseline.storeSchema`. A plain `--builtin` build for local testing doesn't. From then on, `codegen`:
  - refuses to change or remove any method, event or type that a store build shipped;
  - refuses to lower `version`;
  - requires every new method and event to have `since` above the shipped `version`, so `has()` stays truthful on old hosts.
- To change something, add a new method (`name.v2`) with `since = version + 1`, and bump `version`.
- `data.put` is allowed only on buckets listed in `writable`.
- **`--store` checks the schema against the recorded baseline before replacing it,** with the same three rules, and refuses the build otherwise. `--rebaseline` overrides that, and warns. Without this, the guard above is one command away from being gone: `--store` is the only writer of `storeSchema`, so re-running it rewrites the record that the check is made against — and a change `codegen` had just refused then passes with nothing left to show it was ever refused. `baseline.json` is the only evidence of what the stores reviewed and nobody can reconstruct it afterwards, so `--store` also prints what it recorded (`bridge`, `routes`, and every name new since the last one). Treat the file as append-only in review.
- **Additive-only is a *wire and store* guarantee, not source compatibility.** Old bundles keep working, `has()` degrades gracefully and the stores see a superset — but a new method lands in the generated `BridgeHandlers` interface, so the host and every test double stop compiling until it is implemented. That is intentional: the one thing worse than a compile error here is a shipped schema with no handler behind it. Bump the schema and write the handler in the same commit.

### 4.2 Wire protocol

| Direction | Mechanism | Payload |
|---|---|---|
| JS → host | `window.Valence.postMessage(str)` (webview_flutter `JavaScriptChannel` named `Valence`) | `{"id": n, "n": "<nonce>", "m": "data.get", "p": {…}}` |
| host → JS (reply) | `runJavaScript(bridgeReplyScript(reply))`, which produces `window.__valence&&window.__valence.r(<json>)` | `{"id": n, "ok": true, "v": …}` or `{"id": n, "ok": false, "e": {"code", "message"}}` |
| host → JS (event) | `runJavaScript(BridgeEvents.<name>(…))`, which produces `window.__valence&&window.__valence.e("<name>",<json>)` | the event payload |

Error codes. **The set is closed:** add to it here rather than inventing one per app, or four native capabilities produce four conventions and a typed bridge stops being uniform.

- `E_UNKNOWN`: the method isn't in the generated table.
- `E_PARAMS`: the params failed decoding.
- `E_UNSUPPORTED`: the host bridge is older than the method's `since`.
- `E_DENIED`: a bad nonce, a write to a non-writable bucket, or a disallowed URL scheme.
- `E_CANCELLED`: the user backed out of native UI. Cancellation is not an error, not a denial and not a fault, and it is the *most common* outcome of every picker, camera, share sheet and biometric prompt — the spec's own built-ins only dodge the question because none of them opens modal UI. **Throw it only when the success type cannot express absence:** prefer a nullable return (`Media?`) where the type can say "nothing", and reserve the code for a non-nullable one.
- `E_TOO_LARGE`: the message is over the cap below.
- `E_PENDING`: the call would have discarded local writes that have not reached the server. The only
  thrower is `auth.setToken` on an account switch (§4.4); it names the number of queued writes, and the
  caller either syncs them or passes `{discardPending: true}`. A refusal, not a fault: nothing changed.
- `E_INTERNAL`.

**Messages are JSON strings, capped at 256 KB of UTF-8 in each direction (`MAX_MESSAGE_BYTES`).**

- On Android a message travels through Binder, whose transaction buffer is around 1 MB and is shared across the process. Overrunning it kills the WebView, with no reply and no error either side can catch.
- **Inbound (JS → host), `@getvalence/bridge` refuses before `postMessage`,** because that is the only point where a promise still exists to reject with `E_TOO_LARGE`. It measures `TextEncoder().encode(msg).length`, not `msg.length`: a 100,000-character Japanese note is ~300 KB of UTF-8 and only ~100,000 UTF-16 code units, so a length check passes it and the host then rejects a message it cannot reply to. **This check is cooperative, not a control** — any page can call `window.Valence.postMessage` directly — so it is a usability guard. A host that also caps inbound size must extract the `id` *before* rejecting, so the reply can be delivered; a host that only logs and drops leaves the page's promise pending for ever, since the client has no per-call timeout.
- **Outbound (host → JS) is the half that bites,** and the generated dispatcher caps it: it has the `id`, so an over-cap reply is replaced by `E_TOO_LARGE` rather than sent. Without that cap a single large reply can kill the WebView mid-trial — and if the WebView dies while `serving == trial`, the ready timer times out, the next launch counts the second strike, and §2.4 puts a **healthy** bundle in `bad`, which is final. A release rolled back for ever with no crash log is the worst outcome in the system, and an uncapped reply is a way to reach it.
  - **`data.list`'s `limit` therefore has a default of 100 and a hard maximum of 500,** clamped by the host rather than trusted from the page. Without them `data.list({bucket})` over a few thousand rows is that failure.
  - **`after` is what makes the clamp survivable, and it is not optional for correctness.** Pass the last key of the previous page and the scan resumes strictly after it. Without it a bucket past 500 rows has **no complete read at all**, and the damage is not a short list — a truncated list is indistinguishable from a short one, so a stored key that happens to fall outside the first page reads as a key the device has never heard of. (Observed: a configured device shown a first-run chooser because its saved row was row 600 of 912.) A prefix is not a general answer; real key spaces are not evenly distributed, and one prefix can cover almost every key. Implementation: `key` is the leading column of `kv`'s primary key, so this is an index range scan, and paging by key rather than by offset means a concurrent sync cannot shift rows across a page boundary. A cursor key that no longer exists still resumes in the right place. **An absent cursor is `null`, never the empty string:** `''` is a valid key — only `.` and `..` are refused — so a host that reads `after: ''` as "no cursor" hands back the same first row on every page, and a bucket whose first key is empty can never be enumerated at all.
  - **`data.count` answers the size and presence questions without reading rows.** "How much does this device hold?" and "is this key space empty?" otherwise cost every row's JSON through the cap that started this paragraph. Live rows only: a tombstone is not a row the page can read.
  - **`after` is a param on a `since: 1` method, so `has('data.list')` cannot gate it.** Gate on `has('data.count')` — the two ship together at version 5. A host older than that rejects the unknown field with `E_PARAMS`, because the generated decoders are strict (§4.3).
    - **Never `app.info().bridge >= 5`.** `AppInfo.bridge` is the **app's own schema `version`**, which the app numbers itself, and it coincides with Valence's built-in version only for an app that has never added a method. An app with six methods of its own is at version 6 *before* `after` exists, so `app.info().bridge >= 5` is true on every host it has ever shipped — including the one that answers `E_PARAMS`. The gate reads as the more robust of the two and is the one that breaks, and it breaks on exactly the apps big enough to need paging. (Observed: an app at schema 6 took this gate and shipped a bundle that threw `E_PARAMS` on every installed host.)
    - **A grown param's only gate is a sibling name, and `codegen` requires it.** A param has no `since` of its own, so the one thing a page can read is another *method or event* that arrived in the same version — `has('data.count')` for `after`. So a built-in that grows a param ships alongside a name at that version, **and the runtime records which name that is**: an app that declares `after` without declaring `data.count` is refused, because otherwise the one gate this section permits answers `false` on every host that app will ever ship, including the ones that accept the cursor, and a page following this advice never pages at all. The check is in `assertBuiltinShapes`, not `assertAdditive`, because the trap needs no store baseline — a schema can be born with the param and without the sibling.
    - **Which is also why a grown param requires the schema `version` to rise with it.** `assertAdditive` refuses a built-in that gains a param while `version` stays at the shipped number: the sibling needs a version to arrive at, and the recorded store baseline needs to see the change.
  - **A key `.` or `..` is refused by `data.put` with `E_PARAMS`.** They are the two values `encodeURIComponent` leaves untouched, so a server that maps a key into a URL path sees them resolve away as dot segments and the write lands on the collection or the root. A server that rejects the batch for it then rejects the **same** queued write on every later run, because push replays the outbox (§5.5): one bad key and nothing in that bucket syncs again, with no method the page could use to clear it. Refusing at the trust boundary is what keeps that out of the outbox; a server-side check is defence in depth, not the fix.
- **Large byte payloads stay outside the bridge.** The bounded exception is `share.image` (section 4.11): at most 128 KiB of inline PNG/JPEG bytes or an active signed bundle image key. There is no blob, no file handle and no shared scratch directory, and base64 adds a third again on top. Native bytes reach the page over the loopback server's reserved `/_host/` prefix (§3). Outside that bounded exception, bytes going the other way — an image to share, a file to upload — are **regenerated host-side from parameters**: the page sends what to draw, or a key the host already holds, and the host produces the bytes. There is deliberately no inbound HTTP path. The server is GET and HEAD only (§3), the nonce is checked by `bridgeDispatch` and never on HTTP, and the port is not a secret — so a `PUT /_host/…` would let any app on the device write into app-private storage unauthenticated.
- **A method that does take bytes validates in this order,** because the page is untrusted and "a share method" is otherwise a way to write attacker-chosen bytes to disk under an attacker-chosen name: cap the *encoded* length before decoding; decode; check the magic bytes against the type the method claims; require the file name to be a plain leaf matching an explicit pattern; write into a scratch directory the host wipes before each use.

**The host is a trust boundary.**

- Every message goes through the generated `bridgeDispatch` with the current nonce and strict decoders: unknown fields, wrong types and non-JSON input are all rejected.
- Scripts are built only by the generated helpers, which use `jsonEncode`. Raw strings are never concatenated into a script.
- `open.external` accepts only `https:`, `mailto:` and `tel:` URLs.
- **The `valence.` prefix is reserved for the host.** `prefs.get` and `prefs.set` reject `valence.*` keys with `E_DENIED`, so the web can't tamper with internal state such as the sync lease.

**Emitting an event.** The host runs the generated builder in the WebView: `controller.runJavaScript(BridgeEvents.syncChanged(buckets: [...]))`. The builder renders the whole call through `jsonEncode`.

- **`window.__valence` does not exist until the entry page has loaded,** so an event emitted before that is silently dropped — and the interesting ones arrive exactly then (a notification tap that cold-starts the app, connectivity returning during startup). **The host buffers event scripts and flushes them on `onPageFinished`,** and flushes again after every reload, because an update or a reverted trial reloads the page.
  - **The buffer is bounded**, because `onPageFinished` is not guaranteed: a host whose entry page never finishes, on a device it keeps syncing for, would otherwise grow the list for the life of the process. The oldest go first and the host logs the drop — for every event in it, the newest is the one worth delivering.
  - **§4.6's two state events are the exception and are not buffered at all.** They are state, and the rule below is to re-derive state rather than replay it, so the host drops them when no page is loaded and the page that loads next calls `app.state()`.
- For state rather than one-shot notifications, prefer re-deriving to replaying. `sync.changed` works this way: on resume the host compares each pair's `max_usn` with the last value the page was told (§5.6).

### 4.3 Codegen (`node valence/valence.mjs codegen`)

It emits three files:

- **`mobile/lib/valence/config.g.dart`**, from `valence.config.json` and `keyring.json`: `valenceAppId`, `valenceOtaBase`, `valenceSyncBase`, `valenceKeyring` and `valenceWritableBuckets`.
- **`mobile/lib/valence/bridge.g.dart`**:
  - `const hostBridgeVersion`, which is the value check 5 compares `requires.bridge` against;
  - one strict `fromJson` per type and per params class;
  - the abstract `BridgeHandlers` interface;
  - `bridgeDispatch(h, raw, nonce:)`, which never throws, and which replaces an over-cap reply with `E_TOO_LARGE` (§4.2);
  - the `BridgeEvents` script builders and `bridgeReplyScript`.
- **`<web>/src/lib/valence/bridge.g.ts`**:
  - `Methods` and `Events` type maps;
  - `METHOD_SINCE` and `EVENT_SINCE`;
  - `BRIDGE_VERSION`.

- **`<web>/src/lib/valence/bridge.g.ts`** also binds that table to the runtime with one `createBridge` call and re-exports the surface typed for this app: `call`, `has`, `on`, `ready`, `connect`, `installShim`, plus `BridgeError`, `MAX_MESSAGE_BYTES`, `inHost`, `Json` and `AppShim`. **App code imports from `bridge.g.ts`, never from `@getvalence/bridge` directly** — the generated file is what makes `call('data.get', {bucket, key})` checked against this schema.

`@getvalence/bridge` provides, for every app:

- `call(m, params)`, where params are required whenever any field is required, and which refuses a message over `MAX_MESSAGE_BYTES` of UTF-8;
- `has(name)` and `connect()`;
- `on(event, fn)`, whose unsubscribe returns `void` so it is a valid React effect cleanup;
- `ready()`;
- `installShim()`;
- `inHost()` and `BridgeError`.

**`has()` takes a method name *or* an event name,** because it answers one question — can this host do this — and a caller should not have to know which kind a name is to ask it. `createBridge` therefore receives both generated tables, `METHOD_SINCE` and `EVENT_SINCE`.

- **Gate the feature behind an event, not the subscription.** `on()` for an event a host has never heard of subscribes happily and then never fires. That is harmless for the listener and not harmless for the feature: a page that writes a home-screen widget on `app.lifecycle` simply stops writing it on an older host, with nothing to tell it to keep doing something else instead. The silent no-op is the shape this system keeps producing bugs in, so the gate has to be askable.
- An unknown name is `false`, never a throw: `has()` exists to be asked about names this host may not have.
- On the web `has()` is true for a method the shim implements and **false for every event** — there is no host, so no host event will ever fire.
- **`eventSince` is a required argument, not an optional one.** Defaulted, an app that upgraded `@getvalence/bridge` without regenerating would get `has(<any event>)` answering `false` on every host, silently and for ever — while the widened signature is exactly what lets that call compile. Required, a stale `bridge.g.ts` fails to build and names what to regenerate.
- **Therefore one name is a method or an event, never both.** `has()` resolves a name against one merged table, so a name declared as both would answer for whichever won — `false` for an event the host really does emit. `parseSchema` refuses the collision, in the same pass that refuses two names becoming one identifier.

When `window.Valence` is absent (a normal browser), `call` routes to `shim.ts`, which implements methods with `fetch` and storage or throws `E_UNSUPPORTED`. That is what lets **one web codebase serve both the website and the app**.

The Dart side is symmetrical: `bridge.g.dart` imports its decoders, its reply builders and the reply cap from `package:valence/codegen.dart`, and `BridgeError` and `ValenceConfig` from `package:valence/valence.dart`. Nothing it needs is emitted inline, so a fix to any of them ships with a package upgrade.

**A built-in method may be omitted from the schema; it may not be redefined.** `app.*`, `data.*`, `prefs.*`, `sync.*`, `secure.*`, `auth.*`, `open.external` and `bundle.applyUpdate` are implemented by the `valence` package, and the generated `ValenceBuiltins` delegates to it. An app that never syncs can drop `sync.now` entirely. An app that keeps the name and changes the params or the return shape would compile, pass the wrong arguments to the runtime, and be caught only on a device — so `codegen` refuses it and names the shape it must keep. The *name* of a returned type is the app's; its fields are not.

**A built-in can still *grow*, because the rule above is about redefining, not about extending.** When a runtime release adds a field to a built-in's return type — `SyncResult.reason` in 0.4 is the first — that field is **optional in the schema**: an app that declares it gets it, an app that has not regenerated keeps its old shape and keeps generating code that compiles, and nothing else about the method moves. Both guards know about it: `assertBuiltinShapes` accepts the type with or without the field, and §4.1's additive-only check treats adding it to an already-shipped type as additive — otherwise the one upgrade this paragraph describes would be refused for every app that has ever run `bundle --store`, and the only way through would be `--rebaseline`, which overwrites the schema the stores reviewed. `codegen` still refuses the field at a type other than the one the runtime declares, and still refuses any change to the fields that were always there.

**A grown field is always nullable, because nothing else gates it.** A method carries `since` and is gated by `requires.bridge`; a *field* on a type carries neither. The host's `bridge.g.dart` ships in the APK and the page's `bridge.g.ts` ships in a bundle, so an OTA release generated after the field was added lands on hosts built before it, and those hosts simply do not put it in the reply. Typed `string` that would be a lie the type checker endorses; typed `string?` it is the same "ask whether this host has it" that `has()` gives a method. A page that wants the field without the null check waits for its own store release — the same rule as any other newer capability.

`codegen --check` exits non-zero if the generated files are stale. CI runs it.

### 4.4 Secure storage and the bearer token

Every app with private synced data needs two things the bridge did not have: somewhere to keep a
credential that is not the SQLite file, and a way to make the host's own requests authenticated. Before
this, four apps invented their own, and none of them got past it cleanly — a token in `prefs` is in a
plain-text table inside a backed-up database, and a token the page holds cannot reach the sync driver,
which is the one component that makes the requests.

Valence takes no position on *how* you log a user in. The page does that against your API, by whatever
means, and hands the host the resulting token. That is the whole model: **bring your own token.**

```json
"secure.get":     { "since": 2, "params": { "key": "string" }, "returns": "string?" },
"secure.set":     { "since": 2, "params": { "key": "string", "value": "string" }, "returns": "void" },
"secure.delete":  { "since": 2, "params": { "key": "string" }, "returns": "void" },
"auth.setToken":  { "since": 2, "params": { "token": "string?", "account": "string?", "discardPending": "bool?" }, "returns": "void" },
"auth.hasToken":  { "since": 2, "params": {}, "returns": "bool" },
"auth.account":   { "since": 13, "params": {}, "returns": "string?" }
```

```json
"auth.expired":   { "since": 2, "payload": {} }
```

**Where the bytes go.** Android: the Keystore, through `flutter_secure_storage` — an AES-GCM record in a
preferences file whose key is wrapped by a hardware-backed RSA key, which is what that plugin now does
instead of the deprecated `EncryptedSharedPreferences`. It needs `minSdk 23`. iOS: the Keychain, with
`first_unlock_this_device` accessibility, so a background sync after a reboot-and-no-unlock has no token
and reports itself offline rather than crashing. **The iOS path is written and unverified**, like every
other iOS path in this spec.

- **`secure.set` takes a non-null value and `secure.delete` is the only delete.** `prefs.set(key, null)`
  and `data.put(bucket, key, null)` both delete, so this is deliberately the odd one out: there is one way
  to remove a credential and it says so at the call site. A reviewer reading `secure.set(k, maybeNull)`
  cannot tell whether clearing was intended.
- **The `valence.` prefix is reserved,** exactly as it is for `prefs` (§4.2), and refused with `E_DENIED`.
- **Secure storage is not a cache.** `resetOnError` is on, so a record the platform can no longer decrypt
  — a restored backup, a changed lock screen on some devices, a Keystore the OS has invalidated — is
  dropped rather than thrown. Treat every read as "may be absent": a token that vanishes means the user
  logs in again, which is correct, and anything the app cannot regenerate does not belong here.
- **A failure to reach the platform at all is a null, not an exception.** A host running in a unit test, a
  background isolate without `DartPluginRegistrant.ensureInitialized()`, or a device whose Keystore is
  broken all read as "no value" with a log line. The alternative is an unhandled `MissingPluginException`
  inside a sync, which fails the whole run for a bucket that may not even be authenticated.

**The token.** `auth.setToken(token)` writes it at the reserved key `valence.auth.token`; `auth.setToken(null)`
deletes it. Because the key is reserved, **`secure.get` can never read it back** — the page can set it,
replace it and clear it, and can ask `auth.hasToken()` whether one is there, which is all a login screen
needs after a cold start. The host then attaches it itself:

- `Authorization: Bearer <token>` on every pull and push of a **writable** bucket (§5.3, §5.5);
- and on every `http.request` the host performs for the page (§4.5).

**Public read-only buckets stay unauthenticated,** so a CDN can serve them and a cache can keep them. If a
read-only bucket needs a user's identity it is the wrong shape for this: make it writable, or put the
identity in the path your publisher writes.

**`ValenceConfig.authToken` still wins when set.** An app with its own refresh loop in Dart keeps that
callback, and the stored token is only the fallback — so this is additive for a 0.3 host too.

**A 401 means the token is gone, not that the network is.** The host:

- emits `auth.expired` once per sync run, so the page can show a login screen, refresh and call
  `auth.setToken` again;
- **keeps** the stored token, because a refresh flow usually needs to present the expired one;
- reports `SyncResult.reason == "unauthorized"` for that run.

**`reason` is an open set, and an unknown value means "not ok".** `"unauthorized"` is the first value added
after `ok`/`busy`/`offline`, and a page that compares `reason === 'ok'` keeps working, while one that
compares `reason === 'offline'` to decide "stale" does not. Values may be added; a page must treat
anything it does not recognise as a run that did not fully succeed. (A new *value* is not a new field, so
nothing in §4.3's growth rule gates it — which is exactly why it has to be stated here.)

**Switching accounts (`account`, since 13).** A phone is shared and a token is replaced far more often
than an app changes user, so the host cannot tell a refresh from a different person by the token alone.
`auth.setToken(token, {account})` takes an **opaque account id** — whatever the app's own identity for
that user is, a subject claim or a hash of it, never a password — and the host keeps it beside the token
at the reserved key `valence.auth.account`. It is written only by this method and read back only by
`auth.account()`.

- **The recorded id changing is the switch.** A call naming the same id is a refresh and does nothing but
  replace the token. The first call that names an id when none is recorded **adopts** it and clears
  nothing: that is an app upgrading to the account-aware shape with its current user signed in, and
  wiping there would destroy the data of the very user who is holding the phone.
- **A switch refuses to run over queued writes.** If the outbox is not empty the call throws
  `E_PENDING` and nothing changes — not the token, not a row. Those writes were made by the account
  that is being replaced, and the host attaches whatever token is stored *at the moment the request is
  made*, so letting the switch through sends user A's rows to the server under user B's credentials.
  `{discardPending: true}` is the only way past it, and it means what it says: the queued writes are
  deleted unsent.
  - **The guard does not depend on there being a writable bucket left.** A host whose `writable` set is
    empty — an update that removed the last one — still checks the outbox, still throws `E_PENDING`,
    and still clears the outbox and the sync observations when let through. Rows queued under the
    config that admitted them outlive it, and skipping the check because there is nothing to delete is
    how they would be pushed under the next account's token the day a writable bucket came back.
- **A switch clears every writable bucket:** its `kv` rows, its `bucket` row — the `max_usn` cursor
  and `synced_at` with it — the whole outbox, and the host's own sync observations
  (`valence.sync.lastSyncedAt`, `valence.sync.offline`), in one transaction, **before** the new token is
  stored. B must not see A's rows on a shared phone, B's first pull must start at zero because B's
  server-side `usn` numbering has nothing to do with A's, and `sync.status()` must not answer "synced a
  minute ago" over B's empty buckets.
  - Read-only buckets are **not** touched. They are public, they are the same rows for every user, and
    they are what the app has to show while nobody is signed in.
  - **The clear and the store are both under the §5.6 sync lease**, which the host waits up to five
    seconds for and throws `E_INTERNAL` rather than clearing without. Two different syncs are the
    hazard, and only one of them is obvious: a push already in flight has read the old token and would
    apply its acknowledgements after the wipe — and a sync *starting* in the gap between the clear and
    the token write would pull A's rows straight back, under A's token, because the header is built per
    request. Releasing the lease before the token is written reopens the whole hole on a resume.
  - **Clearing first and storing second**, in that order, because the failure between them has to be
    the recoverable one. After clearing rows, delete the old token, record the new id, rebind task
    restoration (§4.8), then write the new token. Interrupted writes leave the original credentials
    or no bearer, never a new bearer under the old id. Retry sign-in to recover. Storing first and
    clearing second leaves B's token over A's rows, and nothing later notices.
  - **The identity is recorded before the token on every path**, not only on a switch. Secure storage
    writes one key at a time, so the order decides what a half-finished call leaves behind. On an
    adoption the unsafe order loses the id and keeps the token, and a later sign-in as somebody else
    *still* finds no recorded id — so it is a second adoption rather than a switch, and the first
    account's rows and queued writes survive under the second account's token. Recording first means
    an interrupted call leaves the id with the token it already had, and the next different account is
    a real switch.
  - **A local write that arrives during the transition is refused**, with `E_INTERNAL` and a message
    saying nothing was written. The lease orders a switch against *sync*; `data.put` takes no lease
    and bridge messages dispatch concurrently, so without this a write from the outgoing account's
    page could commit after the clear and be pushed under the incoming account's token — the same
    cross-account write `E_PENDING` exists to prevent, by a route `E_PENDING` never sees. The refusal
    covers the whole transition, including the wait for the lease, and a write that was already
    running is allowed to finish *before* the clear rather than after it. Refused and not delayed: held
    and applied afterwards it would simply land in the new account's outbox.
  - `sync.changed` is emitted for the cleared buckets, because a page showing A's list is now showing
    rows that are gone.
  - A bucket the app has **dropped** from `writable` since those rows were written is not in the set the
    host is told to clear, so its rows survive the switch. The host logs them; there is nothing else it
    can do, because it cannot distinguish them from a read-only bucket it no longer syncs.
- **Signing out is the same switch.** `auth.setToken(null)` clears the token, the recorded account and
  the same data, under the same `E_PENDING` guard — but **only for an app that has recorded an
  account**. An app that has never passed one keeps the 0.3 behaviour below exactly, so no app gets a
  data wipe it did not ask for by upgrading its host.
  - **`null` is the sign-out and an empty string is not.** `auth.setToken('')` clears the token exactly
    as it did before, and clears nothing else. A refresh loop that yields `''` on failure, or an app's
    uninitialised state field, is not evidence that a different person is holding the phone, and the
    cost of reading it that way is the user's unsynced data.
  - **A 401 handler that calls `auth.setToken(null)` is a wipe** once the app records an account, which
    is not what "the token expired" means. §4.4's 401 rule is to *keep* the token and let the page
    refresh it; an app that signs the user out there should know it is also deleting their local data.
- **An account id the host cannot read is an error, not an absence.** Every other secure read fails
  open, because the alternative is failing a sync over a bucket that was never authenticated. This one
  cannot: "absent" is the answer that means *no account has ever been recorded*, and that answer turns
  the next sign-in into an adoption — B's token stored over A's rows, silently, on exactly the devices
  whose Keystore is in a bad state. The call throws `E_INTERNAL` and changes nothing.
- **`has('auth.account')` is the gate**, not `app.info().bridge` (§4.2): `account` and
  `discardPending` are params and have no `since` of their own, and an older host **ignores unknown
  params silently only if its decoders let it** — Valence's are strict, so it answers `E_PARAMS`. A page
  that must work on both calls `auth.setToken({token})` without the account when the gate is false, and
  then does its own cleanup, knowing the host will not.

**What logout does not do for an app with no `account`.** Clearing the token leaves the local SQLite rows
exactly where they are. The host has no "wipe user data" operation that it applies on its own, because
only the app knows which buckets are the user's and whether the device is shared. An app that must forget
a user either adopts `account` above, or deletes those rows itself with `data.put(bucket, key, null)` —
and should know that the tombstones then push to the server, which the account switch deliberately does
not do: a wipe is local, and user A's rows stay on A's server.

---

### 4.5 Native HTTP and existing backends

`http.request` is additive at `since: 4` (version 3 includes data.getMany and sync.status). Its params are
`{url: string, method: string?, headers: json?, body: string?}` and its result is
`HttpResponse {status: int, headers: json, body: string}`. The default method is GET;
GET, HEAD, POST, PUT, PATCH, DELETE and OPTIONS are supported. GET/HEAD cannot carry a body.
Bodies are UTF-8 text, including JSON explicitly encoded by the caller. Binary downloads and
multipart uploads are outside this method's scope. HTTP errors return their status and body;
network, timeout and invalid UTF-8 failures return `E_INTERNAL`, without remote or credential text.

The host enforces the **compiled** `http.origins` origin list, emitted as
`ValenceConfig.httpOrigins`. An OTA CSP or page cannot broaden it. Entries are exact HTTP(S)
origins (scheme, hostname, effective port), without credentials, paths, query, fragments or
wildcards. The default is empty: deny all. `sync.base` does not implicitly authorize HTTP calls.
Request URLs must be absolute HTTP(S), without credentials or fragments. All redirects are
returned as 3xx and never followed, including same-origin redirects. Thus a redirect cannot
send the bearer token to another origin. Use HTTPS in production; an explicitly configured HTTP
origin sends credentials in cleartext and is intended for local testing only.

Headers must be an object of string values with valid HTTP names and printable ASCII values.
The page cannot supply Authorization, Proxy-*, Sec-*, Cookie, Cookie2, Host, Origin, Referer,
Connection, Content-Length, Transfer-Encoding, Upgrade, TE, Trailer, Expect, Accept-Encoding or
Keep-Alive (case insensitive). The host obtains the R1 token per request, with
`ValenceConfig.authToken` taking precedence over secure storage, and sets Authorization itself.
A 401 on a request carrying that token emits `auth.expired` once for that request, retains the
token, and still returns the HTTP response. No cookie jar is used; Set-Cookie and Set-Cookie2
are omitted from returned headers. Origins in this list are trusted with the user's token:
an API that echoes credentials can disclose them in its response, so never allow third-party
origins. This is a CORS bypass for the app's API, not a credential firewall against that API.

Each call has a 20-second total deadline, including token lookup and reading the response;
timeout closes its dedicated client. Request and response bodies are capped at 64 KiB each,
headers at 16 KiB each, measured as UTF-8 bytes. Responses are read with a running byte cap,
not buffered without limit. Over-limit input or response returns `E_TOO_LARGE`; forbidden
origins and headers return `E_DENIED`; malformed arguments return `E_PARAMS`. The ordinary
262144-byte bridge envelope cap still applies after JSON encoding (§4.2).

The CSP-only `web.connect` list never grants native access or token trust; it may contain third-party URLs and paths. Native access requires the separate `http.origins` list compiled into the store host.

A POST can succeed on the server while the page receives `E_TOO_LARGE` (response or JSON envelope size) or `E_INTERNAL` (timeout, transport or UTF-8 failure). Use server-enforced idempotency keys when retrying writes. JSON escaping can expand a 64 KiB text body beyond the 256 KiB bridge cap, so the body limit alone does not guarantee a deliverable reply. HEAD, 204 and 304 skip the Content-Length pre-check because that header can describe a representation rather than an actual response body; streamed bytes remain capped.

**Existing REST APIs need an adapter for offline sync.** `http.request` is an online RPC:
it does not populate SQLite, retry, queue a write, or work offline. The reference Node adapter
in `examples/rest-sync-adapter/` maps a REST snapshot onto §5.3/§5.5, assigns durable monotonic
USNs, retains tombstones, and acknowledges push ids idempotently. Its pull `max` is the last
row included when `more` is true, never a later server head that would skip unseen rows.
The example is one loopback-only user's database; multi-user deployments must isolate state
by authenticated identity, enforce authorization and put TLS in front of it.

### 4.6 Lifecycle, connectivity and update status

A page in a browser tab can answer "am I visible?" and "am I online?" from the platform, and it is
never asked "is a new version of me waiting?". Inside the host all three are the host's to answer, and
all three were previously answered only by inference: `app.resumed` fired on the way back in with no
corresponding event on the way out, `SyncResult.offline` described one past attempt rather than the
link, and an update that declined was visible only in the native log.

**`app.lifecycle`** carries `{"state": "foreground" | "background" | "inactive" | "detached"}`. The four
values are the host's, not the platform's, and the mapping is fixed so a page reads the same four on
either OS:

| Flutter `AppLifecycleState` | event `state` |
|---|---|
| `resumed` | `foreground` |
| `inactive` | `inactive` |
| `hidden`, `paused` | `background` |
| `detached` | `detached` |

- **Only a change is emitted.** Android delivers `hidden` and then `paused` for one backgrounding, which
  is one transition to `background`; a page that counted events would count two.
- `inactive` is the transient state behind a notification shade, a permission dialog or an incoming
  call. It is **not** backgrounded, and a page that pauses a video on it flickers. Treat it as
  foreground unless you specifically mean "not interactive".
- `detached` is emitted for completeness and will usually not arrive: the engine is tearing down, so
  there may be no WebView left to run the script. **Never persist from `detached`.** Persist on
  `background`, which is the last state with a live page.
- `app.resumed` still fires, unchanged, on the way back in. It is `app.lifecycle` with
  `state: "foreground"` plus the host's resume work (port reclaim, update check, sync) having been
  started. New code should listen to one or the other, not both.
- **Observed on Android** (emulator, API 36, 2026-10-22): leaving the app delivers `inactive` and then
  `background` **about three seconds later**; returning delivers `inactive` and then `foreground` within
  the same second. `hidden` arrives and `paused` does not arrive separately, so the dedupe is load-bearing
  rather than theoretical. The event script does run while the WebView is off screen — the page receives
  `background` with a timestamp from while it was backgrounded — but **`background` is not a pre-kill
  hook**: three seconds is long enough for the OS to have moved on, so anything that must survive process
  death belongs in the host's route save and `state.save`, not in a `background` handler.

**`app.online`** carries `{"online": bool}` and reports what the OS says about network *interfaces* —
`connectivity_plus`, the same source the "connectivity came back" sync trigger uses. **It is not
reachability.** A device on captive-portal Wi-Fi, or behind a firewall, or with a server that is down,
is `online: true` and every request still fails. The honest pair is: `app.online` to decide whether to
*try*, and `SyncResult.reason`/`sync.status().offline` to say whether the last attempt *worked*. A
freshness indicator built on `app.online` alone lies. Only a change is emitted, and the first value
arrives as soon as the host has one, so a page can also just call `app.state()`.

**`app.state()`** returns `{lifecycle, online}`, the current values of the two events. It exists because
both are state, not notifications: a page that loads after the transition — a cold start from a
notification tap, or the reload an OTA does — would otherwise have to wait for the next change to learn
anything. Prefer re-deriving from `app.state()` on mount to replaying buffered events (§4.2).

**So the two state events are *not* buffered**, unlike every other event in §4.2. If no page is loaded
the host drops them, and the page that loads next calls `app.state()`. Buffering them would be an
unbounded queue — a host whose entry page never loads, on a device moving between networks, has no bound
on how many it collects — holding transitions that are stale by the time anything reads them. The state
is recorded either way, so nothing is lost.

The one-shot events (`sync.changed`, `sync.done`, `bundle.updateReady`, `auth.expired`) still buffer and
flush on `onPageFinished`. Not because nothing could re-derive them — `sync.status()` carries most of
what `sync.done` does — but because **`sync.changed` and the `sync.done` for the same run have to stay
ordered**, and dropping either half breaks a pairing the page is told it can rely on. The buffer is
bounded for the same reason the state events are not in it: `onPageFinished` is not guaranteed, so the
host keeps the newest and logs what it drops.

**`sync.done`** carries `{"result": SyncResult}` — the same record `sync.now` returns, after every run
that completes **in the UI isolate**: UI start, resume, connectivity returning, the push a `data.put`
fires, and the page's own `sync.now`. `sync.changed` says which buckets moved and nothing else; a run
that moved nothing, or was blocked, or hit a 401 emitted no event at all, so a "last synced" line could
only ever be updated by a sync the page itself asked for. **It fires on every such completed run,
including `changed: 0`, `busy` and `unauthorized`**, and the two are ordered: `sync.changed` first (so
the page's data is refetched) then `sync.done`. A schema that declares `sync.done` must also declare the
`SyncResult` type.

**The emission therefore belongs to the runtime's `syncNow`, not to the host widget's triggers.** A
`data.put` pushes by calling `syncNow` directly and never passes through a widget trigger, so a host
that reported only its own triggers would leave the freshness line untouched by the writes the page
itself made — which is most of what moves an outbox.

**The periodic background run is the one that cannot report itself**, and no host can change that: it
runs in a background isolate with no WebView to reach (§5.6). Its work is still visible — it moves
`max_usn`, so the next foreground run's `sync.changed` reports the buckets, and `sync.status()` has the
new `lastSyncedAt` — but there is no `sync.done` for it. A page must not treat "no `sync.done` since I
loaded" as "nothing has synced"; that is what `sync.status()` is for.

**`bundle.status()`** answers "is there an update, and if not, why not?" It returns:

| Field | Meaning |
|---|---|
| `serving` | the seq of the bundle on screen; `0` before one is served |
| `pending` | a verified bundle waiting for `bundle.applyUpdate`, or null |
| `trial` | the seq on probation, or null — equal to `serving` while a trial is on screen |
| `reason` | why the last completed check ended as it did, from the closed set below |
| `offered` | the seq the pointer offered on that check, when it got that far |
| `checkedAt` | when that check finished, epoch milliseconds, or null before the first one |

`reason` is a closed set, and every value maps to a sentence a page can show:

- `idle` — no check has finished yet.
- `unconfigured` — the app has no `ota.base`, so it never checks. Not a fault.
- `uptodate` — the pointer offers nothing above `current`, `pending` or `trial`.
- `rollout` — a newer release exists and this install is outside its rollout percentage (§2.3 step 2).
- `bad` — the offered seq is on this install's `bad` list, so it will never be offered again (§2.4).
- `offline` — the pointer, the manifest, the signature or a file could not be fetched.
- `rejected` — the manifest or a file failed its checks (§2.3 checks 1–7). **This is the one that
  deserves an alert in your own telemetry:** it means a published release is unservable, or the bytes
  were tampered with, and no device will take it.
- `toobig` — over `bundleSizeCap`, or the data pull hit `dataSizeCap`.
- `waitingForData` — step 7 has not finished pulling the `requires.data` pairs, so the bundle exists but
  is not usable yet. On a device that is offline or whose server has not published the pair, this is
  where an update sits indefinitely, and it is the state four hosts mistook for "no update" (§2.3).
- `busy` — step 7 could not take the sync lease within its bounded wait. The next check retries.
- `ready` — the check produced a `pending`. Call `bundle.applyUpdate` when a reload will not lose work.

The set is closed in the same way §4.2's error codes are: add a value here rather than inventing one.
A page must treat a value it does not recognise as "no update right now", never as an error, because a
newer host can return one the bundle was generated before.

All five are `since: 6`, and `bundle.status` reads state the host already keeps — it never starts a
network request, so a page may poll it.


### 4.7 Adaptive layout and accessibility (R8)

`ValenceApp` uses edge-to-edge layout. It publishes `--valence-inset-top`,
`--valence-inset-right`, `--valence-inset-bottom` and `--valence-inset-left` on the
document root in logical CSS pixels, from the owning Flutter view's `viewPadding`
divided by its device pixel ratio. These describe system bars and cutouts, not the
keyboard. The WebView resizes for the keyboard. Values refresh after document load,
rotation, multi-window resize and resume; do not add a native SafeArea around it.
Pages must use a `width=device-width, initial-scale=1` viewport and apply the
variables to their content and fixed controls, with `0px` fallbacks for browsers.
The page may paint backgrounds underneath system bars. The host supplies values,
not automatic content padding. Layout publication must neither navigate nor reload.

`AppInfo` may add `fontScale: "num?"` without changing `app.info`'s original
signature or fields. Old generated schemas remain supported. New hosts return
the system text scale (Flutter's text scaler evaluated at 16 logical pixels,
divided by 16); old hosts omit it, so pages use `info.fontScale ?? 1`.
Android applies the rounded percentage through WebView `setTextZoom`, including
on resume and accessibility/settings changes. Do not multiply CSS text by this
scale again on Android. The experimental iOS path scales the document's original
computed root font size, disables WebKit's additional text autosizing and requires
relative (`rem`/`em`) typography. It does not scale hard-coded pixel fonts. Pinch
zoom remains available. Android's single text-zoom percentage approximates
nonlinear system scaling; it is not a per-size nonlinear mapping.

At schema **7**, `app.appearance` has payload `{darkMode: bool, highContrast: bool,
reducedMotion: bool}`. The host emits an initial snapshot after each page load and
emits again when these values change, including on resume. Subscribe during page
bootstrap, before `ready()`. Values come from the owning view's system brightness
and accessibility features, not the app's chosen Flutter theme. The page can also
read root attributes `data-valence-dark-mode`, `data-valence-high-contrast` and
`data-valence-reduced-motion` (literal `true`/`false`) for CSS styling. Publication
uses JSON-encoded host values, preserves the navigation lock, nonce and CSP, and
does not expose a page-callable system-settings setter. These signals describe OS
preferences; they do not certify the page as accessible. Semantic HTML, TalkBack
testing, contrast, focus order and usable tap targets remain the app's job.

### 4.8 Task state restoration (R7)

Snapshots are bound to the native recorded account (§4.4) as well as the signed bundle seq.
Before loading a restored route, compare its account fingerprint with secure storage; a mismatch
clears both route and blob. A failed account read discards the snapshot and loads the verified root page; it is never treated as proof of an anonymous account. A successful switch
or account-aware sign-out clears and rebinds the live snapshot before releasing the sync lease.
Same-account refresh and first-account adoption retain the current draft; adoption stamps the new
fingerprint. An older OS snapshot without that fingerprint cannot restore into a named account.
The envelope stores only a SHA-256 fingerprint of the opaque id, never the id or bearer token.
This does not clear the page's live DOM: the app must redraw account-owned UI after the switch.

An account switch writes secure state in this order, inside the same sync lease: delete the old
token, store the new account id (or delete it for sign-out), clear/rebind restoration, then store
the new token. A failed write or process death can leave a recorded account without a token;
retrying the sign-in repairs that state. It must never leave the new token under the old identity.
Account-changing calls are serialized in the host, and a refusal does not block later attempts. An app refresh loop must cancel an outstanding refresh when the user changes, or pass the correct explicit account id; a refresh without an id cannot tell the host whose token it is. Interrupted secure writes can leave the new account recorded without a token; retry sign-in to repair it.


`state.save({json: json?}) -> void` and `state.restore() -> json?` are additive at
`since: 8`. Saving null clears the blob. The compact JSON UTF-8 encoding is at most
65,536 bytes; excess is E_PARAMS without replacing the previous value. This is
ephemeral UI state, never credentials or durable user data.

ValenceApp enables Flutter OS state restoration itself. It records the same-origin
route (path, query and hash) as navigation changes and captures it again on background.
Only absolute relative paths up to 4,096 UTF-8 bytes are accepted: no authority,
scheme, backslash, control characters, dot segments or reserved /_host/ paths,
including encoded forms. No persisted origin or port is ever used to navigate.
After OS process reclamation, the restored route is resolved against the newly
bound loopback origin. The blob and route are tied to the served signed bundle seq;
an update or rollback drops both before serving the new bundle. Normal signature,
nonce, navigation and trial-ready checks still run; restoration never commits a trial.

The state lives only in the OS task restoration snapshot, not prefs or state.json.
A fresh task (including Android force-stop or removal from Recents) starts at /
with null. Backgrounding alone retains the current page. state.restore returns the
latest saved/restored blob repeatedly, including in the current process. OS snapshots
are best effort; applications save small UI changes promptly, not only at shutdown.
Android process reclamation is tested with Home then `adb shell am kill <appId>` and
reopening the retained task. iOS uses Flutter restoration too but is experimental
and untested; its app must opt into native state restoration as Flutter documents.

### 4.9 Permissions (schema 10, R3)

`permissions.check({kind}) -> string`, `permissions.request({kind}) -> string`, and
`permissions.openSettings() -> bool` are built-ins at `since: 10`. Kinds are `camera`,
`location` (foreground only), `notifications`, `contacts`, `bluetooth`
(scan and connect, not advertise), `microphone`, and `photos` (the OS library permission group).
Unknown kinds return `E_PARAMS`; known kinds outside the store-compiled
`permissions.kinds` allowlist return `E_DENIED` before any platform call. The default
allowlist is empty. Changing it requires codegen, native declarations and a store
release; a signed OTA cannot grant itself another permission. No background request
or startup prompt is allowed. Requests and opening settings require an attached,
foreground host; otherwise `E_DENIED`. Calls are serialized to prevent overlapping
OS dialogs, and a queued request rechecks foreground state before dispatching one to the platform.

Statuses are `granted`, `denied`, `permanentlyDenied`, `restricted`, `limited`.
Preserve the OS answer: Android checks can report `denied` after a permanent denial;
only a request can disambiguate it. iOS provisional notifications map to `limited`.
Location checks the declared OS permission group. Recommend coarse-only on Android
12+ so approximate foreground access counts as granted; fine location for legacy
Bluetooth is declared only through API 30. If another feature declares fine location
on Android 12+, an approximate-only grant can report denied because the plugin
requires the whole declared group. This is not a precision or service-enabled API. Android photos use storage through API 32 and images from 33;
selected-image access from 34 is limited. iOS library permission includes images and videos; legacy Android storage is also broader than images. Contacts requests the platform group, including write/account permissions if the Android host declared them. Declarations should be minimal; the bridge does not narrow an OS grant. Android Bluetooth before 31 requires
foreground location for scanning; from 31 both scan and connect must be granted.
For combined permissions, return the most restrictive status (restricted,
permanentlyDenied, denied, limited, granted). Unsupported platforms return
`E_UNSUPPORTED`. Native errors remain errors, never fabricated grants.

`permissions.changed({permissions: PermissionState[]})` (since 10), where
`PermissionState = {kind: string, status: string}`, reports only changed configured
kinds on resume. Startup establishes a baseline without prompting or emitting a
change. Successful checks and requests update it. Each kind is checked independently;
one native failure is logged and does not hide changes to the others. Resume checks
share the request queue. The native adapter rechecks foreground after SDK preparation, immediately before dispatching a request. Events use the existing JSON escaping and page buffering;
apps check on startup because these are changes, not a durable event log.

Use `permission_handler` with native Android declarations and iOS usage strings and
compile macros for the configured kinds only. Never enable every permission for a
production app. iOS is experimental and untested. The setup table and runnable
example are in `docs/permissions.md`.

---

### 4.10 Native plugins

A plugin is store-compiled native code, never downloaded code. A Dart package supplies a
`ValencePlugin` implementation, `valence.plugin.json`, and native setup notes; a matching npm
package supplies its web types. The app explicitly installs both packages and registers the
Dart instance in `ValenceBuiltins(valence, plugins: [...])`. Registration alone exposes nothing:
only methods in the merged schema have generated dispatch cases, after the existing nonce and
strict parameter checks. Plugin results are decoded against their declared return type before
replying. Message limits, navigation locks, signatures and reserved secrets remain mandatory.
Plugins are trusted native code, with the same privileges as the host, not a sandbox.

`valence.config.json.plugins` is an optional array of entries, each either a
project-root-relative fragment path or `{path, since}`, where `since` maps every method and
event name in that fragment to an app bridge version. The two forms are exclusive per entry:
the object form requires `since`, and then the fragment must declare none and must be covered
completely; the bare string is the only form in which a fragment declares its own. A `since` key the fragment does not declare is an
error, so a renamed or dropped method cannot keep a stale stamp. This is what lets a
**published** fragment be installed unedited: `since` is an app bridge version, and no package
can know the recorded baseline of every app that installs it (§4.3). The merged schema, and
therefore the recorded store baseline, holds the resolved number, so changing a stamp after a
store build is a change like any other and the additive-only guard refuses it.
Each fragment is `{namespace, dartPackage, npmPackage, setup, types, methods, events}`. Metadata
strings name the packages and the setup document; they are not imports or commands to execute.
The namespace is one lower-camel identifier. All method/event names start with `namespace.`;
all type names start with its PascalCase spelling. Type references are local to that fragment.
Two fragments cannot share a namespace, and no fragment can collide with an app method, event
or type, even with an identical definition. Core namespaces (`share`, `app`, `data`, `prefs`, `sync`,
`open`, `bundle`, `secure`, `auth`, `permissions`, `notify`, `badge`, `push`, `link`, `state`,
`http`) are reserved. Fragments cannot declare a schema version: the app owns the combined
version and each method/event's explicit `since`, in the fragment or in its `plugins` entry.
After a store baseline exists, additions require a higher version; changes/removals are
rejected by the same additive-only guard.
Codegen, bundle and doctor read the effective merged schema when checking the recorded store
baseline, so changing/removing a fragment cannot bypass compatibility checks.

`ValencePlugin` declares a namespace, its exact method set, and
`invoke(Valence, method, Map<String, Object?> params) -> Future<Object?>`. The registry snapshots
these declarations, rejects reserved/duplicate namespaces and invalid methods at construction,
and fails missing handlers with `E_UNSUPPORTED`. Plugins return JSON values and can use generated
`BridgeEvents` scripts through the app's view wiring. They own native initialization, permissions
and cleanup; the registry does not run background tasks or register callbacks. Native setup and
any new capabilities require a store release. Use `has()` for older installed hosts.

The built-in `open.external` delegates through this same registry to `ValenceOpenPlugin`,
which calls the existing scheme-restricted runtime method. Applications cannot replace it.
Its wire shape and `since` do not change. Android is tested; iOS is experimental and untested.

### 4.11 Sharing an image (R14, schema 14)

`share.image` is `since: 14`, with optional string params `bytes`, `path`, `fileName`,
`caption`, returning a string. Exactly one of `bytes` (canonical standard padded base64,
no data URL) or `path` (relative POSIX key in the **active verified manifest**) is required.
Inline bytes are capped at 128 KiB decoded; encoded length is checked before decoding.
The entire JSON envelope still obeys §4.2's 256 KiB cap. A bundle image is capped at 5 MiB,
including the actual bounded CAS read, and its size and SHA-256 are checked again before use.
The page's path is never joined to a directory: the host looks up the manifest entry and
uses only its lowercase 64-character hash. Missing, unsafe, reserved and off-bundle paths
are `E_DENIED`; missing or corrupt CAS data is `E_INTERNAL` without exposing paths.

PNG signature or JPEG SOI magic is required; SVG and other formats are refused with
`E_PARAMS`. This identifies the format, not image validity: the native recipient decodes it.
`fileName`, if present, must match `^[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.(png|jpg|jpeg)$`
and its extension must match the detected format. Otherwise the host supplies `image.png`
or `image.jpg`. Caption is at most 4096 UTF-8 bytes; no caller-controlled MIME or native path.
Bad argument combinations, base64 and names return `E_PARAMS`; size violations return
`E_TOO_LARGE`. Concurrent sharing is refused with `E_DENIED`, and the guard resets on errors.

The package uses `share_plus` to open the Android share sheet (`ACTION_SEND`, temporary
content URI permission), sharing a **copy** rather than the CAS file. The host wipes its
fixed `valence-share` scratch child before each valid use, without touching the cache root
or following a scratch-directory symlink. The plugin may retain its own temporary
copy in the app cache until the OS or plugin evicts it; it must not contain credentials. Empty captions
are omitted. The receiving app may ignore the caption. The string result is `selected`
(target chosen, **not proof of delivery**), `dismissed`, or `unavailable` (no reliable outcome).
Do not retry `unavailable` automatically. Native failures return a generic `E_INTERNAL`.
The iOS activity-controller path uses a host-owned popover anchor and remains experimental
and untested. No storage permission is needed and no native code arrives in an OTA.

Earlier apps used `share.image` as a custom method. A declaration with `since < 14` keeps
its custom signature and handler, even after a schema version bump. Never rewrite a shipped
method to adopt the new signature: keep it or use a separate app-specific method name.
Only `since >= 14` selects and enforces the new package built-in.

The regression matrix for this capability is: runtime tests for both byte caps,
canonical base64, format/name/caption checks, exactly one source, busy/reset,
active-manifest-only lookup, traversal/reserved/URL denial, bounded CAS reads,
missing files and changed size/hash; generated-dispatch tests for strict params,
nonce denial and actual native-plugin marshalling; codegen tests for frozen schema-14
shape and preserved custom pre-14 handlers; Android example checks for inline and
bundle sharing with a caption, without claiming delivery. iOS remains untested.

## 5. Data layer

### 5.1 SQLite schema (host, sqflite)

```sql
CREATE TABLE kv (bucket TEXT NOT NULL, schema INTEGER NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, usn INTEGER NOT NULL,
                 deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (bucket, schema, key)) WITHOUT ROWID;
CREATE INDEX kv_bucket_usn ON kv (bucket, schema, usn);
CREATE TABLE bucket (name TEXT NOT NULL, schema INTEGER NOT NULL, max_usn INTEGER NOT NULL, synced_at INTEGER,
                     PRIMARY KEY (name, schema));
CREATE TABLE outbox (ordinal INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE, bucket TEXT NOT NULL, key TEXT NOT NULL, value TEXT,
                     deleted INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL);
PRAGMA user_version = 2;
```

- **The database lives at `<applicationSupportDirectory>/<databaseName>`,** outside `valence/`, because it holds user data and should be backed up while the CAS should not. `host.database` in `valence.config.json` names the **file**; the directory is fixed and not configurable.
  - 0.3 named no directory here — it said only "outside `valence/`" — so a conforming 0.3 host could have used `getApplicationDocumentsDirectory()` instead, which on Android is a different place (`app_flutter`, against appSupport's `files`). A 0.4 host would then open an empty database beside a full one and present a **fresh install to a user whose rows are still on disk**: silent, total, and with no error. `host.database` cannot fix it, because the problem is the directory.
  - **So the host adopts a 0.3 database on open.** When `<appSupport>/<databaseName>` does not exist and `<documents>/<databaseName>` does, move it there before opening. The host does this rather than the app because it is the only component that knows nothing else holds the file open yet.
  - **Move the `-wal` and `-shm` sidecars with it, and move the `.db` last.** The `.db` alone discards every commit still in the write-ahead log, which for a syncing app is the last sync. Until the `.db` lands the destination is still "no database", so a crash midway leaves the 0.3 copy readable and the next launch retries the whole move.
  - **Never overwrite an existing destination.** Two databases means the app has already run on 0.4, and replacing the live one with a stale copy is the same data loss in the other direction.
  - **Log the move.** It is the one line that tells an operator why a device's row counts changed on an upgrade.
  - Both isolates can reach this on the launch that migrates (§5.6). Whoever renames first wins; the loser's **source** is what has gone, which is what to test — the winner moves the `.db` last, so the destination may legitimately not be there yet.
  - **A move that cannot finish fails the launch. It must never fall through to opening.** This is the sharp edge: opening would *create* an empty database at the destination, and the next launch would find it there, skip the adoption, and never see the user's rows again — silently, for ever. That is the exact data loss the adoption exists to prevent, reached by the code meant to prevent it. Failing is recoverable: the 0.3 copy is intact, a sidecar already moved is waiting at the destination, and the next launch resumes the move from wherever it stopped. "A crash midway is safe" is true of a process kill and **not** of a caught exception, because only the kill skips the open.
- `value` is JSON text. HTTP gzip handles compression on the wire.
- Migrations use `user_version` and are append-only. Version 2 rebuilds outbox with a durable insertion ordinal, copying existing entries in legacy rowid order, preserving ids and payloads. New operations sort by ordinal, independent of timestamps, random ids, clock changes and VACUUM. Existing bucket cursors and user rows remain intact.
- Open the database with WAL mode and a 5-second busy timeout, **through `rawQuery`, not `execute`**, in sqflite's `onConfigure`:

  ```dart
  onConfigure: (db) async {
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.rawQuery('PRAGMA busy_timeout = 5000');
  },
  ```

  Both pragmas return a row, and Android's `SQLiteDatabase` refuses a row-returning statement through `execSQL`, so `execute` throws `Queries can be performed using SQLiteDatabase query or rawQuery methods only` and the app dies on its first launch, before any UI. `sqflite_common_ffi` — the factory every `flutter test` uses — accepts `execute` for pragmas, so **no unit test catches this**. Only a run on a device or emulator does.
- **Never close the database.** sqflite keys open databases **by path inside the platform plugin**, not per isolate, so a `close()` in a `workmanager` isolate or in a widget's `dispose()` invalidates the handle the UI isolate is holding and the next bridge call fails with `database_closed`.
  - A Dart object can't cross an isolate boundary, so "share the store instance" is not the rule. The rule is: **each isolate calls `openDatabase` on the same path** and gets the same plugin-side connection back, and **no isolate ever calls `close()`.** Keep one store object per isolate, lazily opened.
  - A background isolate must call `DartPluginRegistrant.ensureInitialized()` before its first store call, or the plugin isn't registered in that isolate at all. That is the other first-run-on-device failure in this code path.
- **Check that WAL took.** `rawQuery('PRAGMA journal_mode = WAL')` returns the mode that is now in effect; a filesystem that can't do WAL answers `delete` and you lose the concurrency the rest of §5 assumes. Log or assert the returned value rather than discarding it.

### 5.2 Seed

`assets/valence/seed.db` has the same schema and is built by `valence seed`:

- The build is atomic, so a failure keeps the previous seed.
- Every pair must match the current `data` schema or an explicit additional `seedSchemas` declaration (?7.1). Multiple schemas can coexist via `<bucket>.v<N>.json`.
- Every row is `{k: string, v, u: integer ≥ 1, d}`.

On first launch, and after a host upgrade, the host attaches the seed and, for each `(bucket, schema)` pair, copies the seed rows whose `usn` is above the local `max_usn` for that pair. It then updates the `bucket` row. Count the copied rows with `SELECT changes()`: sqflite's `rawInsert` returns a last-insert-rowid, which is meaningless on a `WITHOUT ROWID` table, so a log line built from it reports 1 for a seed of thousands and reads as a failure.

The app must be fully usable offline from the seed plus the built-in bundle. That is required by Apple guideline 4.2.3(ii).

**A seeded pair does not satisfy §2.3 step 7.** That gate is about the server having rows at that schema, so it needs a pull: `synced_at` stays null after a seed import. It costs an offline-first app nothing in practice, because its first bundle is the built-in one and it ships with the matching seed.

### 5.3 Pull (incremental, by update sequence number)

```
GET {SYNC_BASE}/{bucket}?since={max_usn}&schema={n}&limit=500     Authorization: Bearer <token> (user buckets only, §4.4)
200 {"bucket":"calendar","schema":2,"rows":[{"k":"2026-01","v":{…},"u":1235,"d":0}],"max":1240,"more":true}
```

- Rows come in strictly ascending `usn` order, above the requested cursor. `max` may name the server head and never advances the cursor past returned rows. Empty final pages leave the cursor unchanged.
- Apply each page in **one transaction**, set `max_usn` for that `(bucket, schema)` to the last row's `u`, and loop while `more` is true.
- A row with `d: 1` is a tombstone, so set `deleted = 1`. `max_usn` only moves forward.
- **Rows whose `(bucket, key)` has pending outbox entries are skipped**: the local write wins until the server acknowledges it.
- Page progress and completion are separate: only a valid final page (`more:false`), or completion of every selected static chunk, sets `synced_at`. Network/HTTP/decoder errors, non-progressing pages and budget stops leave fresh pairs incomplete. Persist page progress for resumable retries. A previously completed pair retains that history during an incremental refresh.
- Push acknowledgements update individual rows and clear only acknowledged ops; they never advance a pull cursor or mark a pair synced.
- Remote "fixes" (corrections to bundled data) are just rows with a higher `usn`. There's no separate patch mechanism.

**Static variant** (CDN-only, no backend), for public read-only buckets: publish `{SYNC_BASE}/{bucket}/v{schema}/index.json`, listing `[{"from": usn, "to": usn, "file": "c-0007.json.gz"}]`. Each chunk has the same `rows` shape. The client fetches the chunks whose `to` is above `max_usn`.

The updater waits up to five seconds for a competing sync lease (retrying acquisition every 25 ms), then logs a deferral without spending a trial strike. Required-pair completion is checked under the lease, which is held through durable manifest/signature/pending publication. GC includes in-flight publication manifests, restarts a kept-set snapshot if publication changes while verification awaits, and validates its snapshot after taking the data lease. GC never deletes files, manifests or data needed by a newly pending bundle.

### 5.4 Schema co-versioning (data and UI)

**Read-only buckets are stored per `(bucket, schema)`.** A schema change never swaps or rewrites rows in place.

- **The updater pulls the missing pairs itself**, as a numbered sub-step of §2.3 step 7. That step is the normative text; this section is the reasoning behind it. A device may hold several schemas of one bucket at once, and a requirement for either one is satisfied by holding it.
- **The bridge resolves `data.get(bucket, …)`** against the schema that the active bundle's manifest requires. The old UI keeps reading its own schema, so a failed trial reverts with its data intact.
- **Old pairs are deleted** by garbage collection only once no kept manifest requires them (§2.4).
- **The server** must serve every schema version that a live bundle still requires.

**Writable buckets never change schema.**

- They are not listed in `data`; `valence` enforces this.
- They always use `schema = 1`, both in the `kv` and `bucket` keys and in pull requests.
- Their JSON may only gain optional fields, and the server migrates on read.

### 5.5 Push (local-first user data)

```
POST {SYNC_BASE}/{bucket}/push   {"ops":[{"id":"<uuid>","k":"…","v":{…},"d":0}]}
200 {"acked":["<uuid>"],"rows":[{"k":"…","v":{…},"u":1301,"d":0}]}
```

- `data.put` writes the `kv` row immediately with `usn = -1` and adds an `outbox` row. Do both in one transaction.
- **`data.put` with a null `value` is the delete:** write a tombstone and an outbox op with `d: 1`. There is no other delete method, and no way to store a literal JSON `null` as a value.
- **`usn = -1` is part of the contract, not an implementation detail.** `data.list` returns it, so the web app can read "written locally, not yet acknowledged" off a row. A pending *delete* leaves no row, so it can't be counted that way.
- Push is idempotent by op `id`. The server assigns the `usn` and echoes the rows back.
- Delete the acknowledged outbox rows, then apply the echoed rows, **except for keys that still have outbox entries**. A newer local edit waits for its own ack.
- **A writable bucket is pulled as well as pushed, at schema 1.** It can never appear in a manifest's `requires.data` — check 5 and the CLI both refuse one there — so a host that pulls only the pairs `requires.data` names leaves user data **push-only**: device B never sees device A's row, a reinstall comes back empty, and the last-writer-wins rule below cannot happen at all. Pull it before the push in the same run, so the outbox skip is what protects a write that has not been acknowledged yet.
- Conflict rule: the server applies last-writer-wins per key, in arrival order. Push is only for user-scoped buckets. **There are no CRDTs.** If an app needs collaborative editing, that's a different product.
- **An account switch clears the whole outbox** along with the writable rows it belongs to (§4.4). It is
  the one place queued ops are dropped without being sent, it refuses to run at all unless the app asks
  for it with `{discardPending: true}`, and it never pushes a tombstone: the rows leave the device and
  stay on the server, which is where the account that wrote them can still read them.
- **The loser is never told.** A pull applies the winning row straight over the local one, and the outbox protects a local write only until it is acknowledged, so "A writes 4, A syncs, B writes 7, A syncs" leaves A holding 7 with no record it ever said 4. An app that must show the disagreement **puts the writer in the key** (`<session>:<sku>:<device>` rather than `<session>:<sku>`), so two writers never collide and a review screen can show both. The cost is one row per writer per record, so use a key the app can enumerate.

### 5.6 When sync runs, and concurrency

- **Triggers:**
  - on UI start, on resume and when connectivity comes back (connectivity_plus);
  - when the web app calls `sync.now`;
  - periodically in the background via `workmanager`: on Android at least every 15 minutes; on iOS it's best effort through BGTaskScheduler.
- **The background isolate shares the UI's database connection.** sqflite registers open databases by path in the platform plugin, so each isolate opens the same path, gets the same connection, and neither may close it; a background isolate also needs `DartPluginRegistrant.ensureInitialized()` first (§5.1). The lease below serialises *syncs*; it says nothing about database lifetimes. Because the connection is shared, keep pull pages small (§5.3 caps them at 500) so a long background transaction doesn't queue the UI's reads behind it.
- **The *open* is not covered by the lease, and the schema upgrade is where the two isolates collide.** A `user_version` migration runs in `BEGIN EXCLUSIVE`, and the launch that runs it is the launch WorkManager fires the already-registered periodic job on — an app update, for every app. The loser gets `SQLITE_BUSY` (`database is locked ... during open, closing...`) and `busy_timeout` does not help, because the lock is refused before the connection that would wait on it exists. The lease cannot help either: **the lease lives inside the database being opened.** So:
  - **Retry a locked open** for about as long as a lease wait — the reference runtime tries five times, one second apart — and then let the caller decide.
  - **A background sync whose open stays locked reports `reason: "busy"`,** not an error. Nothing was attempted, the UI isolate holding the file is itself about to sync, and a thrown error is a WorkManager `FAILURE` with backoff for a condition that has already resolved.
  - **A UI open that stays locked rethrows,** because an app with no store cannot start. This is the symmetric case and it is the worse one; the retry is what makes it rare.
  - **Never cache a failed open.** An implementation that memoises the open future by path (the §5.1 "same path, same connection" rule invites it) must not memoise the *rejection*, or every later call in that isolate fails against a database that is now perfectly healthy.
- **One sync at a time,** across the UI and background isolates — **including the updater's step 7 pull (§2.3), which is a sync and takes the same lease.**
  - Take a lease row in `prefs` (`valence.sync.lease` = `<epoch ms>:<pid>`, written in `BEGIN IMMEDIATE`).
  - The lease is held only if `now - 2 min < lease <= now`. A lease time in the future, from clock skew or tampering, counts as expired.
  - **A lease recorded by another process is expired too, whatever its timestamp says.** The lease exists to keep the UI isolate and the background isolate apart, and those share one process, so a foreign pid can only be a launch that is gone: a crash, a force-stop, or Android reclaiming the app. Without this the next launch waits out the full two minutes — several launches and resumes on a cold app, each one logging "a sync already holds the lease" and returning an empty result, which a page cannot tell from "up to date". That is worst immediately after a crash, which is exactly when a user is least forgiving. A value with no pid at all, written by an older host, is treated the same way. (Single-process assumption: a host that puts a component in its own `android:process` needs an owner token both processes agree on.)
  - Renew the lease after every applied page, so a long `since = 0` pull doesn't let a second sync start.
  - Release it when the sync finishes.
- **`SyncResult.reason` says whether the run happened at all:** `"busy"` when the lease blocked it, `"offline"` when it ran and could not reach the server, `"unauthorized"` when the server rejected the bearer token (§4.4), `"ok"` otherwise — including an app with no `syncBase`, which has no server for its data to be stale against. Without it, "I was not allowed to try" and "you are already up to date" are the same `{changed: 0, offline: false}`, so a freshness indicator reports confident freshness over stale data and a page that retries on an empty result has nothing to retry on. `offline` keeps its old meaning and its old value; `reason` is additive (§4.3).
- **On resume,** compare each bucket's `max_usn` with the last value sent to the UI, and emit `sync.changed` for the ones that moved. Background runs can't reach the WebView.
- **iOS home widget:** write a small JSON snapshot into the App Group container. **Never put the SQLite file in a shared container**: iOS kills an app that suspends while holding a lock on a shared file (0xdead10cc).

---

## 6. Native value (Apple guideline 4.2, "repackaged website")

Ship at least **two** of these in the host before the first store submission:

| Item | Package (pin) | Native setup Valence does not generate |
|---|---|---|
| offline-first cold start | — | none; the built-in bundle and the seed are it |
| local notifications driven by synced data | `flutter_local_notifications` + `connectivity_plus`, resolved **together** (see §6.1 and the SKILL.md baseline) | requesting `POST_NOTIFICATIONS` at runtime, `RECEIVE_BOOT_COMPLETED` and the plugin's three receivers, core library desugaring, a notification channel created at init, and the timezone setup in §6.1 |
| a home-screen widget fed by a snapshot (§5.6) | `home_widget` **0.10.0** — `^0.8.x` fails the Android build inside the plugin's own Kotlin (`Cannot inline bytecode built with JVM target 11 into bytecode that is being built with JVM target 1.8`) | an `AppWidgetProvider`, a layout, an `appwidget-provider` XML and a manifest receiver on Android; a widget extension and an App Group on iOS (see §6.2) |
| native share and haptics | `share_plus` inside `valence`, plus Flutter's own `HapticFeedback` | schema-14 `share.image` accepts bounded inline PNG/JPEG bytes or an active signed bundle image, with a caption; no storage permission. See section 4.11 |
| biometric lock | `local_auth` | `MainActivity` must extend **`FlutterFragmentActivity`**, not `FlutterActivity`, or every `authenticate()` throws `PlatformException(no_fragment_activity)` |

**Versions live in SKILL.md §Stack baseline, with their dates and their sources** — that is the only table a docs-scout maintains, and the only one that can say how stale it is. The one pin named here is `home_widget`, because §6 is where a reader meets the package and `^0.8.x` costs two Gradle runs to diagnose.

**Resolve the §6 packages together, not one at a time.** Independently valid constraints do not compose: at the versions observed on 2026-10-17, `connectivity_plus` wanted `dbus ^0.8.0` through `nm` while `flutter_local_notifications` wanted `dbus ^0.7.8` through its Linux implementation, so `pub get` refused outright — over two **Linux-only** transitive dependencies, in an Android build that compiles neither. §5.6 requires `connectivity_plus`, so an app that adds notifications has to resolve the pair, and the constraint §6 needs wins over the baseline table's single version.

**This is a list of capabilities that need native work, not a list of things that work out of the box.** Every row but the first fails on a real device while the project builds clean, `dart analyze --fatal-infos` passes, the host tests pass and `doctor` is green — so the §8 matrix is the only place that can catch them, and only if the app adds a row. `flutter create` rewrites `MainActivity`, so the `FlutterFragmentActivity` edit needs a comment saying why it is there.

**A capability whose success is asynchronous must report what the host actually knows, not `ok`.** `notify.schedule` is the worst case: on Android 13+ without `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` the alarm is silently downgraded or refused, so the bridge call succeeds in a few hundred milliseconds, `notify.pending` lists the reminder, the receiver even registers — and it arrives late or not at all. For an app whose purpose is reminding someone, that is the worst failure shape there is. Return `exact` / `inexact` / `blocked` from `AlarmManager.canScheduleExactAlarms()` and surface it on the permission type, so the web app can say so. Google Play restricts `USE_EXACT_ALARM` to apps whose core function is alarms or calendars, so a reminder app either justifies it in review or accepts inexact delivery: that is a §7 question as much as a §5.6 one.

**The §6 capabilities are as fresh as the last UI start, and nothing can make them fresher.** Two rules here are individually right and jointly limiting. §5.6 says a background run cannot reach the WebView; the architecture gives the page sole ownership of the data model and the wording, because the page is the only part that knows the product. So a background sync can pull a fresh week into SQLite and then do nothing with it: it cannot extend the reminder queue past what the last UI start scheduled, and it cannot refresh the widget's snapshot. **A reminder set once and left alone runs dry; a widget shows a stale day** — on exactly the phone whose owner has not opened the app, which is the phone these features exist for. Design for it: re-arm on every UI start and on every `sync.changed`, schedule as far ahead as the data allows rather than as far as the UI is showing, and say in the product what "last updated" means. The alternative — a second copy of the wording in Dart — is a copy that cannot ship over the air, which is the thing Valence exists to avoid. A host-side template a background run could fill is the obvious fix and is **not** in 0.4.

**Native state outlives your bundle, and an OTA release cannot reach it.** An over-the-air bundle can change every line of the product *except* the state a native plugin has already persisted: scheduled notifications and their ids in the plugin's own `shared_prefs`, widget key-value storage, granted permissions, and anything else a §6 item wrote. The sharp edge is identifiers. Change how a notification id is derived between two releases and the old cohort is unreachable — the new code cancels only the ids its own scheme can compute, while a boot or an app-update re-arm faithfully restores *both*, so the user gets every reminder twice a day at a time they never chose, for ever. **Cancel by difference, not by a migration flag:** ask the plugin for its pending requests and cancel every id that is neither in the set about to be scheduled nor already on screen. That clears any past scheme and leaves a notification the user is reading alone (§6.1). The general rule: a store release is the only thing that can migrate native state, so treat an id scheme like a database schema, not like a constant.

**Every bridge method that sets durable native state needs a matching read.** The page is the only owner of "a reminder is set at 06:00" or "the widget says 6 of 7", it owns it in a pref it writes non-atomically, and without a read-back it cannot check what it actually armed — so a divergence between the UI and the device is invisible to the app and to its tests. One test app sat with a card reading 12:00 PM and six alarms at 06:00 and could not tell.

**A bridge method that throws is invisible to everybody.** `bridgeDispatch` turns it into an error reply, the page's `await call(...)` rejects inside an effect nobody awaited, and nothing reaches a log or a screen. The host **logs every bridge error it returns**, at least in debug builds (§3 Logs). Without that line, a 90-minute hunt replaces one log line — which is what it cost to find §6.1's timezone trap.

The reviewer agent checks this.

### 6.1 Local notifications on Android

Everything here is silent when it is wrong: the call succeeds, the UI says "Set", and nothing is ever delivered.

- **Build setup.** `flutter_local_notifications` fails the build with "requires core library desugaring to be enabled" until the host's `android/app/build.gradle.kts` sets `isCoreLibraryDesugaringEnabled = true` and adds `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` — a 1.x desugar library fails the same build. The wizard does not generate either line.
- **Declare `RECEIVE_BOOT_COMPLETED` and the plugin's three receivers** (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver` with the boot intent filter, and `ActionBroadcastReceiver`) in the host's own manifest. **Android cancels every alarm at shutdown**, and the only re-arm triggers this architecture gives you are a UI start and a `sync.changed` — and the user opens the app *because* the reminder arrived. So without these, an overnight reboot (an OS update is the common case) silently ends the whole schedule and nothing ever rebuilds it.
- **Permission.** Android 13+ needs `POST_NOTIFICATIONS`. The plugin *declares* it for you, so the host's job is to **request it at init and report the result** (`requestNotificationsPermission()`): a denied permission is otherwise indistinguishable from a working one, and the host schedules into a void on every modern device with no error anywhere.
- **Create the channel at init, not on first post.** Android drops a notification whose channel does not exist, silently, and the plugin only creates the channel when a notification is *shown* — so if posting is what is broken, the channel never exists and never will.
- **Delivery is best effort.** `SCHEDULE_EXACT_ALARM` is **not pre-granted to a fresh install** of an app targeting API 33 or later, even when the manifest declares it — and a backup-and-restore onto Android 14 withdraws it from an app that had it, which is worth reading next to §2.4's backup rules (`logcat`: "lost permission to set exact alarms"); the plugin then records `inexactAllowWhileIdle` and the alarm can sit minutes past its due time, still pending. `USE_EXACT_ALARM` is the one granted automatically and Google Play restricts it to alarm-clock and calendar apps. A morning reminder does not need to be exact: prefer `inexactAllowWhileIdle`, and report the mode you got so the UI can say "Android may deliver this late" instead of lying.
- **Older app-owned wall-clock scheduling (observed plugin 19.x): set `tz.local` from the device's real zone.** The schema-11 built-in uses plugin 22.3.2+ with explicit absolute UTC one-shot deadlines (?6.5); this historical observation is about the custom daily-reminder implementation. The plugin re-derives every stored notification against `tz.local` whenever the clock, the timezone or the device changes. Scheduling an absolute instant (`tz.TZDateTime.from(utc, tz.UTC)`) passes every unit test and then **deletes every scheduled alarm** on the first `TIME_SET` — six before a clock change, zero after, nothing in the log. Building the same times in the device's zone leaves all six intact.
  - Initialize from `latest_all.dart`, not `latest.dart`. `FlutterTimezone.getLocalTimezone()` can return a legacy alias (`Asia/Katmandu`, one `h`) that the trimmed database does not contain, and `tz.getLocation` throws. Turn an unresolvable zone into a `BridgeError` the page can display.
- **Re-arm from tomorrow, never `cancelAll`, and key ids by date.** Because a background run cannot reach the WebView (§5.6), the only way to keep a rolling window of reminders alive is to re-arm it on every UI start and after every `sync.changed` — and the obvious `cancelAll()` then reschedule **dismisses the notification the user is reading**: they opened the app *because* the reminder arrived, and the re-arm wipes it out from under them 600 ms later. A sync landing while it is on screen does the same. Clear from tomorrow forward, so the id of a reminder already on screen is one the re-arm never touches; turning reminders off still clears from today. Ids derived from a list position shift when a past day drops out, so a re-arm can also overwrite the wrong day.
- **Serialise the re-arm against the user's own edits.** Persist the new hour *before* arming, and put arms behind one promise chain. Otherwise changing the hour arms first and persists second, the sync-driven re-arm reads the old value in the gap, and it schedules the old hour over the top — the user's chosen reminder silently does not happen.
- **The page computes the text, the host schedules it.** The data lives in the host's SQLite while the formatting, the i18n and the product judgement live in the web bundle, which a background run cannot reach (§5.6). So one method takes a *window* of already-formatted, dated lines (an empty list means "off", which makes arm, re-arm and cancel one call), and scheduling stays on the UI isolate.

### 6.2 The home-screen widget

**A widget is native UI, and it is the one part of a Valence app that can only change in a store release.** Its layout, its sizing, the keys it reads and its receiver registration are compiled into the APK, so rewording a label on the home screen is a store submission while rewording the same label one tap away inside the app is an OTA bundle. Say it out loud before anyone plans around it: Valence's pitch does not cover this screen. **Keep the native layout dumb and generic** — slots for a number and two lines of text — so the page still owns the wording through the snapshot.

- **Android needs four pieces Valence does not generate:** an `AppWidgetProvider` subclass, a `RemoteViews` layout, an `appwidget-provider` XML and a receiver in the manifest. Roughly 90 to 150 lines, none of it app-specific. §5.6's only widget paragraph is about iOS App Groups, and it is not the platform most adopters build first.
- **Pass fully-qualified class names.** A Valence host's `applicationId` is the `appId` from `valence.config.json` while its Kotlin package is Flutter's `namespace`, and the two normally differ. Plugins that build class names as `<applicationId>.<ClassName>` — `home_widget` does — then throw `ClassNotFoundException` inside their own Kotlin: invisible to `dart analyze`, invisible to every unit test, and reachable only with a widget actually placed on a home screen. Use `qualifiedAndroidName` (and see §1 on `appId`).
- **A flat map of typed string keys beats a JSON blob.** `RemoteViews` can only set text on a view, so a JSON snapshot has to be parsed in Kotlin for no benefit. Bound the map and keep it to strings.
- **"Pushed" does not mean "shown".** `updateWidget` reports success whether or not the user has ever placed the widget, so return the installed count from `getInstalledWidgets()` and let the page say "widget not added" rather than claiming an update it cannot see.
- **Who refreshes it is a real fork, and §2.4 does not decide it for you.** "Never in a background isolate" is about *bundle activation transitions only*; §5.6 positively requires background work. So a background isolate may refresh the widget — what it may not do is run the web app, because the page is what owns the wording.
  - **Recommended: the page builds the snapshot** on every UI start and after every `sync.changed`, exactly as §6.1's reminder window works. The widget is then only as fresh as the last time the app was open, so **put only values that stay true for that long in it.** A "current" marker is the obvious thing to put there and is wrong within the hour.
  - The alternative — a background isolate building the snapshot from SQLite — keeps the widget fresh and moves user-visible copy and formatting into the host, which is the one thing the one-web-codebase model exists to prevent. An app that takes it ends up maintaining two copies of its copywriting.

---

### 6.3 Deep links and local routing

Schema 9 adds `link.initial() -> Link?` and `link.opened {url:string, path:string}`;
`Link` has `url:string` and `path:string`. `links.origins` in the store configuration
is an exact allowlist such as `["https://links.example.com", "myapp://app"]`.
It defaults to empty. HTTPS and custom schemes with a host are supported; HTTP,
credentials, ports on custom schemes, wildcards and executable/file schemes are denied.
An OTA cannot expand this list. OS intent filters alone do not grant trust.

The runtime instantiates app_links early on UI startup. It holds the latest accepted
link until `link.initial()` is called, then consumes that pending link once. Subsequent
links emit `link.opened`; a repeat tap on the same URL is a new event. Initial and
stream delivery of the same launch intent are deduplicated only during startup.
Links arriving before the page subscribes replace the pending link (latest wins).
Each WebView page start re-arms the mailbox until that page calls `link.initial()`, retaining a pending link without replaying already consumed links.
Background isolates do not start link listeners. Dispose cancels the subscription.

The path is the URL's path (empty becomes `/`), query and fragment; the authority of
a custom link is an allowlisted host, not a route segment. At most 8 KiB UTF-8 per URL.
Reject malformed escapes, control characters, backslashes, encoded path separators,
dot segments, network-path references and `/_host` paths. Links are untrusted input:
they never invoke bridge methods, import tokens or grant authorization. The WebView
navigation lock and bridge nonce remain unchanged.

`onLink(handler?)` on the generated web client is installed after `connect()`. It
subscribes before calling `link.initial`, skips unsupported hosts, and returns an
unsubscribe function. A live event supersedes a pending initial reply. With no
handler it validates the local path again, calls `history.pushState` within the
current origin and dispatches `popstate`; a custom handler receives `{url,path}`.
It never loads an external URL. Each page installs one subscription; SPA routers
can supply their own handler. Call `ready()` on every painted destination.

Android uses app_links with Flutter's deep-link handler disabled, a `singleTop`
activity, BROWSABLE/DEFAULT VIEW filters for custom schemes and `autoVerify=true`
HTTPS filters for App Links. `valence assetlinks --package <id> --fingerprints
<SHA256,...> --out <directory>` writes `.well-known/assetlinks.json`, using the
Android app-signing certificate (Play signing certificate for Play installs).
`valence aasa --app-id <TEAMID.bundle.id> --out <directory>` writes
`.well-known/apple-app-site-association` with `applinks` paths `*`. These generators
do not upload files or alter native registrations. Serve them over HTTPS without
redirects and with JSON content type. iOS additionally needs URL Types, associated
domains entitlements, and `FlutterDeepLinkingEnabled=false`; it is experimental
and untested. Custom schemes are interceptable by other apps; use verified HTTPS
links for sensitive flows and authenticate any action separately.

R6 matrix: cold/warm links, startup deduplication and repeated taps; unlisted and
malformed links denied; query/hash retained; pending initial reply cannot overwrite
a live event or navigate after unsubscribe; generated delegations; association-file
validation; Android cold/warm intents and `pm verify-app-links`/`pm set-app-links`.

### 6.4 Remote push (schema 12, opt-in)

`ValencePush` wraps Firebase Messaging: FCM on Android, APNs through FCM on iOS
(experimental and untested). A host initializes Firebase and passes a push instance
to `Valence.open(push: ...)`. Without one, all `push.*` methods return
`E_UNSUPPORTED`; Valence never initializes Firebase itself or calls messaging
without an adapter. Firebase's own native auto-init is governed by the host's
project configuration, separately from this bridge opt-in.

| Method | Params | Returns |
|---|---|---|
| `push.token` | `{}` | `string?` (FCM registration token, also on iOS; null before APNs registration or when permission is not granted/provisional) |
| `push.permission` | `{request: bool?}` | `string`: `notDetermined`, `denied`, `authorized`, `provisional`; omitted/false only checks, true requests alert/badge/sound permission |
| `push.initial` | `{}` | `PushMessage?`, consumes the latest notification tap buffered before the page subscribes |

All methods/events have `since: 12`. App-owned `push.*` declarations through schema 11 retain their custom shapes and handlers; only declarations at `since: 12` or later opt into the runtime delegations. `PushMessage` is
`{id: string?, data: json, title: string?, body: string?, image: string?}`.
`push.received` and `push.tapped` carry `{message: PushMessage}`;
`push.tokenChanged` carries `{token: string}`. Subscribe before `push.initial`.
The first initial call switches taps to live delivery; later calls return null.
Received events are foreground-only and best effort. Token rotation is live;
call `push.token` again after resume/reconnect and update your authenticated backend.
Tokens identify installations, not users or authentication. Never log them.

Incoming payloads are untrusted display/data values, never scripts, URLs to load,
credentials, schemas, or bundle pointers. The bridge encodes them as JSON with the
existing U+2028/U+2029 escaping and rejects oversized event envelopes (256 KiB).
Success and error replies measure their JSON cap after separator escaping too.
An oversized error returns a bounded `E_TOO_LARGE` envelope, retaining only a
finite numeric correlation id (otherwise null), never echoing an oversized id.
Images are HTTPS metadata only; the Dart bridge never fetches them. Android's FCM
SDK displays a background notification image supplied in `android.notification.image`;
foreground messages reach the page for an in-app presentation. iOS rich images
require a Notification Service Extension using Firebase's extension helper and
`mutable-content: 1`; that setup and all iOS delivery remain untested.

A **data-only** message whose data is exactly `{"valence":"sync"}` requests the
normal lease-protected sync, using store-compiled config and the native token.
Foreground receipt calls the runtime's ordinary sync. The app's top-level,
`@pragma('vm:entry-point')` Firebase background callback calls
`ValencePush.handleBackground(data, hasNotification: ..., sync: ...)` with
`Valence.backgroundSync(valenceConfig)`. It initializes the binding/plugin
registrant, never opens the UI runtime, never closes SQLite, never activates a
bundle, and never acknowledges a trial. Extra fields, notification messages and
all other commands do nothing. Delivery is an OS best effort, subject to quotas,
force-stop and battery restrictions; a push is a hint, never a correctness gate.
Use Android high priority for a timely hint and APNs `content-available: 1`,
`apns-push-type: background`, `apns-priority: 5` on iOS. A busy lease is not success.

Native setup is a store release: Firebase project config, Android notification
permission, Google Play services; iOS APNs key, Push Notifications and Remote
notifications background capability with method swizzling enabled. No service
account key belongs in an app or bundle. R5 device validation is **blocked: needs
Firebase project** until the maintainer supplies the project configuration.

## 7. Store-policy rules (enforced by `valence bundle` and the reviewer)

**The policy text** (retrieved 2026-10-14):

- **Apple Developer Program License Agreement, §3.3.1(B):**

  > "Interpreted code may be downloaded to an Application but only so long as such code: (a) does not change the primary purpose of the Application by providing features or functionality that are inconsistent with the intended and advertised purpose of the Application (b) does not bypass signing, sandbox, or other security features of the OS; and (c) for Applications distributed on the App Store, does not create a store or storefront for other Applications."

- **Google Play, Device and Network Abuse policy:**

  > "an app may not download executable code (such as dex, JAR, .so files) from a source other than Google Play. This restriction does not apply to code that runs in a virtual machine or an interpreter where either provides indirect access to Android APIs (such as JavaScript in a webview or browser)."

  The same policy also flags "a webview with added JavaScript Interface that loads untrusted web content".

**Rules:**

- **The bundle contains no native code.** `valence bundle` rejects these extensions in any path segment: `.so .dex .jar .apk .aab .ipa .dylib .framework .a .o .class .exe .dll`. `.wasm` is allowed because the webview's JS engine runs it, but the reviewer flags it.
- **OTA must not change the app's purpose.**
  - `baseline.storeRoutes` records the routes of the bundle last submitted with a store build.
  - `valence bundle` warns when a release adds a new top-level route. It recurses through SvelteKit `(group)` and `[[optional]]` directories and counts Astro and Next.js page files.
  - **A client-side-routed SPA has no routes directory,** so scanning finds only `/` and the check has nothing to compare. Declare the routes instead: `web.declaredRoutes: ["/", "/shelf"]` in `valence.config.json`. They go into the manifest and the baseline exactly like scanned ones.
    - Each entry is a **single-segment** top-level path starting with `/`; a trailing slash is stripped, so `/shelf/` and `/shelf` are one route. An **empty** array is refused: it claims nothing, and accepting it would silence the warning below by doing exactly the thing the warning is about. `["/"]` is how you claim a genuinely single-route app.
    - **Declared routes are unioned with a scan, never a replacement for it.** Adding them to a project whose routes directory does scan must not quietly switch the scan off, or the next directory someone adds goes unnoticed.
  - **`valence bundle` says so when the check can't work.** If nothing is declared and there is no routes directory to scan, the build warns that the check is **inactive**: an inactive guard that looks active is worse than no guard. If scanning *does* work and finds exactly one route, that is legitimate for a single-screen app, so the build asks for confirmation in different words rather than crying inactive.
  - **A declared list is a self-report.** Silence then means "the declared list has not changed", not "the app's routes have not changed". Scanning is the stronger signal; prefer it where the framework allows it.
  - New feature areas should go out with a store update.
- **The bridge is reachable only from our own pages.**
  - The main frame is locked to `http://127.0.0.1:<port>/` through `NavigationDelegate`; other URLs open externally through `url_launcher`.
  - **No off-origin subframes, ever.** A `JavaScriptChannel` can't tell which frame a message came from, so embeds (video, payments) open externally or in a separate WebView without the channel.
  - The nonce check (§3) applies to every message.
  - The CSP header comes from the signed manifest.
- **No third-party mini apps.** If the app ever hosts other developers' bundles, Apple guidelines 4.7.1 to 4.7.5 apply: Apple's permission for native APIs, a content index and age gating. That is out of scope.
- **First launch never blocks on a download.** Guideline 4.2.3(ii) is satisfied by the built-in bundle plus the seed.

---

### 7.1 Mechanical diagnostics and the remaining 0.4 ledger decisions

- `data.getMany({bucket, keys: string[]}) -> Row[]` is a built-in at `since: 3`. It reads the active bundle's schema, returns live rows in first-requested-key order, omits missing keys and tombstones, and deduplicates keys. Empty input returns an empty list. More than 500 input keys fails with `E_PARAMS`; keys are bound SQL parameters, never SQL text. One batch crosses the bridge once, rather than paying a separate WebView round trip per key (about 15 ms in the test-app emulator measurement; not a performance guarantee).
- `sync.status() -> {pending: int, lastSyncedAt: int?, offline: bool}` is a built-in at `since: 3`, with no network side effect. `pending` counts outbox operations, including deletes and repeated edits. `lastSyncedAt` is the epoch-millisecond time of the last successful **unscoped** sync, persisted in reserved host prefs, or null before one. `offline` describes the last attempted run's transport failure, not current connectivity; it is false before an attempt. Busy runs do not overwrite these observations. A scoped run cannot advance the global timestamp. `SyncResult.pending` is an optional nullable `int?` (§4.3), reporting remaining operations at return time, including busy/offline/no-server results.
  - Schema 15 adds nullable SyncStatus.reason for the last completed ordinary attempt, scoped runs included. Older schemas omit it; apps needing an explicit authenticated-bucket receipt still persist their own outcome. See the R17 returned-field contract.
- `ota.channel` defaults to `production` and must match `[A-Za-z0-9_-]+`. Codegen emits `valenceOtaChannel` and wires it into `valenceConfig.channel`; the updater follows that channel. Bundles remain channel-neutral. Changing a compiled host's channel needs a host build.
- OTA `requires.bridge` defaults to `baseline.storeSchema.version`, falling back to the local schema version before any store baseline. Built-in and store builds default to the local schema version. An explicit `--requires-bridge` still wins. Building below the local version names the methods needing `has()` guards; it does not make unguarded calls safe.
- `seedSchemas: {bucket: int[]}` optionally declares additional read-only schemas the project may seed. Current `data` schemas are implicitly declared. `seed --from` accepts legacy `<bucket>.json` and `<bucket>.v<N>.json` files with `{schema, rows}`. A versioned filename must match its payload; every pair must be declared, duplicates fail atomically, and multiple schemas coexist. Missing **current pairs** warn even if an older pair was seeded. Writable buckets remain schema 1 and cannot be declared in `seedSchemas`.
- Codegen emits an opt-in `BridgeHandlersDefaults` mixin implementing every handler with `E_UNSUPPORTED`. Use it for test doubles or partial hosts; production hosts should extend `ValenceBuiltins` and explicitly implement their own methods. A defaults mixin must not mask the built-in implementations.
- `node valence/valence.mjs doctor [--tests]` runs mechanical diagnostics without an AI session. It checks config, codegen freshness, built-in signature/files/host bridge/data compatibility, current seed coverage, baseline and stack report presence, declared `nativeValue` (at least two distinct §6 capabilities), resolved Flutter dependencies, and app test-matrix evidence. Rows are `PASS`, `WARN` (missing or unexecuted evidence), or `FAIL` (a check ran and failed); any failure exits nonzero. Missing evidence never passes. `nativeValue` is a declaration, not proof of device behavior. `.valence/test-matrix.json` maps stable layer IDs `bridge`, `loopback`, `updater`, `store-sync`, `integration` to app-relative Flutter `test/` or `integration_test/` files; doctor lists every ID. `--tests` executes mapped unit tests; integration rows stay WARN and need a separate device run. File mappings are evidence pointers, not proof that assertions cover the contract. Doctor does not certify store approval or emulator behavior.

### 6.5 Built-in local notifications (schema 11)

Pre-schema-11 custom notify.* and badge.* declarations remain app-owned; codegen preserves their shipped signatures and abstract handlers. Only declarations with since >= 11 use the built-ins below.

Native hosts opt in with compiled `notifications.enabled: true` and a bundled Android drawable
`notifications.icon` (default `ic_stat_valence`). Disabled hosts return `E_UNSUPPORTED` for this group.
Initialization never requests permission and never changes bundle activation, trials or sync.

- `notify.permission({request?: bool}) -> bool` passively checks authorization unless explicitly asked
  to request it. Android exact-alarm access is a separate OS setting; this call does not request it.
- `notify.schedule({id: int, title: string, body?: string, at: int, channel?: string, exact?: bool,
  payload?: string, image?: string, actions?: string[], group?: string}) -> {id: int, timing: string}`.
  `at` is a future Unix epoch millisecond instant, at most 366 days ahead; these are one-shot absolute
  reminders, unaffected by device timezone changes. Daily local-time windows must be recalculated by
  the app when its time zone or user settings change. No implicit recurrence or timezone lookup.
  `timing` is `exact`, `inexact`, `system` (iOS controls delivery), or `blocked` (permission denied;
  nothing enqueued). Android defaults to inexact; an exact request falls back honestly when access is
  absent or is revoked during scheduling. Acceptance is not proof of delivery; Doze, channel settings
  and manufacturer restrictions can still delay or suppress it.
- IDs are app-wide integers 0..2147483647; scheduling the same ID replaces it. At most 64 pending
  requests; replacement at the cap is allowed. Coordinate ID ranges with app-owned plugin use.
  Title/body/payload UTF-8 limits are 256/4096/4096 bytes. `image` is base64 PNG or JPEG only, at most
  96 KiB decoded and 1024 pixels per side, checked before a bounded pixel decode; corrupt pixel data
  is refused before scheduling, rather than silently omitting the image. No URL or page-supplied file
  path is accepted. iOS attachments are written only to a host-owned private directory. Images are
  optional, not downloaded. Actions are up to three unique compiled IDs `open`, `done`, `snooze` with
  those English labels. Each opens the UI, including on iOS; reply inputs are deferred to S1.
- `notify.cancel({id}) -> void` cancels that pending/displayed notification only, never all others.
  `notify.pending() -> {id, title?, body?, payload?}[]` asks the native scheduler, not an app-maintained
  shadow list. Re-arm by ID difference; do not cancel a displayed notification simply to refill a window.
- `notify.channels.set({id, name, importance?: string, sound?: string, group?: string,
  groupName?: string}) -> void` creates Android channels and optional channel groups. Importance is
  `min`, `low`, `default`, `high` or `max`; sound omitted means default, empty means silent, otherwise
  a bundled raw resource name. IDs/resource names are bounded ASCII identifiers, never paths. Existing
  channel sound/importance remains controlled by Android and the user: use a new ID for a new policy.
  The default channel is `valence_reminders`. Notification `group` groups tray entries separately.
- `notify.tapped` and `notify.action` carry `{id: int, payload?: string, action?: string}`. Payloads
  are untrusted data, never evaluated or navigated to. `notify.initial() -> json?` consumes the cold-start
  response once. Cold responses are available only there; warm callbacks emit the respective event.
  Action categories are compiled into the host. Call `notify.initial` after subscribing to warm events.
- `badge.set({n: int}) -> bool`, `badge.clear() -> bool` report whether a supported platform accepted
  the request, not whether the launcher visibly changed. `n` is 0..9999. Android badges are best effort
  and may require vendor permissions and an active notification; iOS requires badge authorization.

Android hosts must enable core library desugaring, keep notification drawable/raw resources in release
builds, and declare POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, ScheduledNotificationReceiver,
ScheduledNotificationBootReceiver (BOOT_COMPLETED, MY_PACKAGE_REPLACED and vendor quick boot actions)
and ActionBroadcastReceiver. Exact scheduling optionally uses SCHEDULE_EXACT_ALARM, never
USE_EXACT_ALARM by default. iOS installs the UNUserNotificationCenter delegate. No background
notification callback runs UI activation. iOS code paths are experimental and untested.

## 8. Test matrix (minimum; all must pass before "done")

R7: bounded multibyte JSON, null clearing, strict nonce/params delegation, task
snapshot restore and fresh-task reset, same-bundle and native-account isolation (including stale OS snapshots and in-flight route captures), refresh/adoption retention, hostile restored
routes (including encoded /_host/), rotated loopback port, unchanged trial checks;
Android Home → am kill → retained-task reopen restores path/query/hash and blob,
force-stop and explicit task removal start fresh.

R3 permissions: unknown/unconfigured kinds and background/queued requests are
denied before platform access; all five statuses and provisional normalization;
legacy/modern Android photos and Bluetooth mappings; serialized dialogs recover
after errors; resume emits changed kinds only, tolerates an individual failure and
does not prompt; generated dispatch retains nonce and strict parameter checks.

R4: disabled group denial; no implicit permission prompt; passive/requested permissions; exact denial
and revocation downgrade; permission refusal schedules nothing; native pending/replacement/cap/cancel;
bounded text/actions/images including dimension, magic, malformed base64 and path attacks; channel
policy validation; callback escaping, malformed/foreign response rejection and consuming cold initial;
badge support/failure; generated strict dispatch/nonce/older-host guards. Android integration: reminder
actually posts with reported timing, warm tap/action and cold tap, image, cancellation, channel creation,
clock-change and reboot persistence. No iOS verification is implied by unit or Android tests.

**R16 mechanical doctor.** Both CLI entry points use the same diagnostics. Every FAIL includes a `Fix:` line and exits nonzero, without rewriting files. Compare schema and generated host bridge versions; validate the recorded store schema; verify local OTA manifests and their files before comparing `requires.bridge` with the recorded store version. An OTA above that version is FAIL: rebuild with the store bridge floor and guard newer calls, or ship the new host first. Missing store evidence is WARN; historical OTA artifacts are checked too, so archive obsolete local releases outside `dist-ota` before rerunning. `host.database` is a plain file name (default `valence.db`), never a path: fail on separators, traversal or an invalid filename, and report `<appSupport>/<name>` with a WARN that actual installed location and legacy adoption need a device check. Never open or move a user's database from doctor. Inspect Git's tracked and untracked, non-ignored files for PEM private-key headers; fail without printing key material, including when the configured signing-key directory resolves inside Git through a link. Git unavailable is WARN, not PASS. Ignored files are outside this scan; this is a working-tree check, not a Git-history secret audit. Validate `web.connect` as HTTP(S) URLs without credentials, whitespace or CSP source syntax; paths remain supported and normalize to origins. Validate `http.origins` separately as exact HTTP(S) origins; browser CSP permission never grants native token access. R16 does not add bridge methods or change package versions.

R12 regression rows: batch reads preserve requested order, deduplicate, isolate bucket/schema, omit tombstones, bind hostile keys, and reject over-limit input; sync status counts deletes and survives reopen, preserves observations on busy and errors, timestamps only successful unscoped runs; generated defaults dispatch as `E_UNSUPPORTED`; old schemas still generate without grown fields; channel validation and beta pointer URL; store-baseline OTA default with explicit and built-in overrides; multi-schema seed declaration/duplicate/atomicity/current-coverage checks; doctor reports missing evidence as WARN and real failures as FAIL. R16 regressions cover bridge drift, malformed baselines, signed but incompatible OTA, bad signatures, database paths, Git key discovery (including untracked files and linked directories), unavailable Git, and invalid browser/native origins.

| Layer | Tests |
|---|---|
| native HTTP (§4.5) | deny unlisted schemes, hosts and ports before token lookup; generated strict decoding and nonce denial reach the runtime; host token callback takes precedence and token is read per request; page credential and transport headers rejected; real cross-origin redirects returned without contacting the target; authenticated 401 emits once; UTF-8 body and header limits, streamed response cap and total deadline (including late token lookup) enforced; malformed UTF-8 and transport errors disclose no remote text |
| reference REST adapter | real 600-row pull over two pages without skipped rows; durable USNs, tombstones and idempotent push across restart; reused operation id with different payload rejected; lost-reply retry returns current winning row; 601 queued operations accepted within the byte limit and replayed without repeating REST writes; **an item key of `.` or `..` is refused for both a write and a delete, before any upstream request, and refuses the whole batch** (those two survive `encodeURIComponent`, so URL resolution strips them as dot segments and the write lands on the upstream's collection or root endpoint instead) |
| `valence.mjs` (the skill's `valence.test.mjs`) | key directory inside git, including through a link; keyring entry never overwritten; signing key must match the keyring; sign/verify round trip; tampering, bad signature, unknown key, other `appId` and unsafe paths rejected; native extensions rejected; **a bundle file under the reserved `_host/` prefix is refused by both `bundle` and `verify`, and a relative asset URL in the entry page warns**; **a service-worker registration in the output warns**; `seq` monotonic with the same clock and a slow clock; floor only rises; **a floor above the store build's seq is refused for an OTA, allowed up to that seq, allowed for a `--store` or `--builtin` build, warned about when carried forward, and warned rather than refused when a pipeline restates a carried floor it is not actually raising** (refusing that deadlocked against "the floor only goes up", leaving no buildable number); CSP hashes (CRLF-safe, `wasm-unsafe-eval` only with `.wasm`); additive-only against `storeSchema`, recorded only by `--store`; **a second `--store` build cannot rewrite the recorded schema with a non-additive one, `--rebaseline` lets it through with a warning, and `--store` reports what it recorded**; **`--store` warns when a channel points below the seq it just wrote**; **`requires.bridge` rising above the shipped store build warns, and `--requires-bridge` silences it**; new names need `since` above the shipped version; reserved and colliding names, **including one name declared as both a method and an event**; **a built-in that grows a param is refused without the sibling name that gates it — with and without a store baseline, the sibling the runtime names rather than any name, and the version bump still required on top**; SvelteKit co-located files aren't routes; `web.declaredRoutes` is validated, feeds the manifest and the baseline, and silences the inactive-check warning a project with no scannable routes gets; atomic and validated seed, with a warning for unseeded buckets; the CLI runs through a link; **a wrong `verify --files` level says the directory is wrong rather than naming the first file as missing**; a built-in may be omitted but not redefined with a different shape, including `secure.*` and `auth.*`; **a built-in's optional field is passed through when the app's type declares it, omitted from the delegation when it does not, still refused at the wrong type, and additive against a type a `--store` build already recorded — while an app's own shipped type may not grow at all**; generated Dart passes `analyze --fatal-infos` against `package:valence` and satisfies the dispatch cases; the generated `bridge.g.ts` binds the package, including `METHOD_SINCE` refusing a method newer than the host and `EVENT_SINCE` gating an event through `has()` |
| updater (dart test) | each check 1–7 rejects; `pointer.seq` below `pending` drops `pending`; the rollout gate is deterministic; size cap; **a bundle requiring exactly `hostBridgeVersion` is accepted**; **check 5 refuses a `requires.data` key that is malformed or writable** (the mirror of "a newer bridge is refused": without it a host can under-report its version and brick itself on first launch after a schema bump); **check 5 compares against the generated constant, not a second literal**; an update isn't pending until its data pairs are synced; **a bundle requiring a pair the device lacks becomes pending only after step 7 pulls that pair, and never on an offline device**; **a device holding v1 and v2 of one bucket satisfies a requirement for either** |
| host widget (`flutter test`, stub WebView platform) | Pump the real `ValenceApp` with signed bundles, SQLite and a loopback socket; replace only native WebView/platform calls. Hold startup open and resume (I-61): no update, sync or resumed event before startup finishes, while lifecycle state still changes. Exercise same-origin navigation, reserved host paths and off-origin subframes; bridge dispatch receives the live nonce. A trial ready commits, a foreground timeout counts one strike and reloads current, background time counts nothing, and current/late ready never commits. Buffered events flush once per page, state events re-derive instead, and disposal cancels timers/subscriptions and closes the server without closing user data. These tests do not prove OS WebView behavior or iOS support. |
| state machine | **a paused GC snapshot cannot delete a newly published pending manifest/CAS; the data lease remains held through pending publication; a competing ordinary sync releasing within the bounded wait allows the same update check to continue; concurrent checks coalesce**; **a mid-session reload runs step 4 only**: `applyUpdate` serves the promoted trial without counting a failure against it, and a ready timeout serves `current` while leaving `trial` set so the next UI start retries it once; **a refused built-in bundle is remembered by manifest bytes and host bridge version, so a host upgrade that fixes check 5 installs it rather than skipping it**, and step 1 reads only the `seq` on an ordinary launch; **a collection that runs between §2.3 steps 6 and 8 keeps the in-flight bundle's CAS files and any `tmp-*`**; **a corrupt file of the *active* bundle is re-fetched by the repair pass before step 1**; trial then ready → committed and floor raised; `ready()` from a `current` page after a timeout never commits the trial; a timeout counts exactly one failure; trial fails once → retried at the next UI start → fails again → marked bad; **a UI start with no trial counts no failure and adds nothing to `bad`** (both `serving` and `trial` are null); **a ready timeout on a `current` page counts no failure**; **a late `ready()` after a trial was given up commits nothing**; **a `pending` below `current` or below `state.floor` is dropped rather than promoted**; **the UI start after two strikes serves `current`, not the bad bundle** (a `pending` in `bad` is dropped, never promoted); **an update check while a seq is on trial does not re-pend it**; **a commit clears a `pending` holding the committed seq**; a crash while `serving == trial` counts one failure; a newer built-in bundle wins and drops older pending and trial; **a built-in bundle that fails its checks promotes nothing, leaves the state untouched, is not added to `bad`, and with no `current` is surfaced rather than served**; GC keeps current, previous, pending, trial and built-in; **GC after a commit leaves writable buckets untouched**; **a supersede collects the pairs that fell out of `previous`, and GC skips the pair step when the sync lease is held**; no transition runs from a background isolate; the ready timer pauses in the background |
| server | the same port across launches; a bind failure means a new port, a new nonce, a reload and never serving from the old port; rebinding the same port on resume keeps the nonce and the page keeps working; the nonce is in the entry page only; **the back gesture goes back through webview history and closes the app only when there is none left**; CSP header on the entry page; GET and HEAD only, any other method 405; a path with an empty, `.` or `..` segment is 400, so `//_host/<id>` never reaches the fallback; the SPA fallback answers an extensionless path; **a `/_host/` route is matched before the manifest lookup, an unknown id under it is 404 rather than the entry page, and neither a web-supplied path nor a malformed id escapes the host's directory; **a `/_host/` response carries `nosniff` and `default-src 'none'; sandbox`, refuses a scriptable `Content-Type`, and is refused as a main-frame navigation**; **a bundle file is served `no-cache` with its sha256 as a strong `ETag`, a matching `If-None-Match` (weak and `*` included) is 304 with no body, and the same path in the next bundle gets a different `ETag`, so a cached copy can never answer for new code**; the entry page stays `no-store` and carries no `ETag`; **every read of `VALENCE_DEV_URL` in the package is guarded by `kDebugMode` in the same expression, so the §3.1 dev path stays compile-time absent from a release build and cannot lose its guard to a refactor without a test failing** |
| the database's own location (§5.1, §5.6) | **a 0.3 database in the documents directory is adopted with its `-wal` and `-shm` sidecars, under the configured file name, with rows, outbox and cursors intact and the move logged; an existing appSupport database wins and the legacy file is left untouched; the second launch is a no-op; a fresh install with nothing to adopt starts empty; one directory serving as both moves nothing**; **a move that cannot finish throws rather than opening an empty database, leaves the 0.3 copy readable, and is resumed by the next launch**; **a locked open is retried rather than thrown, `backgroundSync` reports `reason: busy` instead of failing the WorkManager job once the budget is spent, a UI open rethrows, and a failed open is not cached**; **`isDatabaseLocked`'s message fallback is anchored, so the lock wording appearing in a page-supplied SQL argument is not read as a lock** |
| store and sync | **push echoes never advance pull cursors; a 600-row pull with a later server-head max receives all pages; partial HTTP/static pulls cannot satisfy activation; outbox insertion order survives equal/backwards timestamps, VACUUM and v1 migration**; **a writable bucket is pulled as well as pushed, at schema 1, and a pull never clobbers a local write that has not been acknowledged yet**; paged pull is atomic per page; tombstones; outbox rows aren't clobbered by a pull **or by a push echo**; push ack clears only acknowledged ids; seed import per `(bucket, schema)` only moves forward; writable buckets use schema 1; the sync lease blocks concurrent syncs, is renewed per page, and treats a future timestamp as expired; **a lease recorded by another pid, or by an older host with no pid, is taken over rather than waited out, while our own live lease is still respected**; **a blocked run reports `reason: busy` rather than an empty success, a completed run reports `ok`, and an unreachable server reports `offline` with the old `offline` flag unchanged**; **step 7's pull takes the same lease, stops and logs rather than failing when it cannot, and resumes from the pair's own `max_usn` rather than from 0**; **a stored token is attached as `Authorization: Bearer` to a writable bucket's pull and push and to neither for a public read-only bucket, `ValenceConfig.authToken` wins over the stored one, a secure-storage platform that is absent reads as no token rather than throwing, and a 401 emits `auth.expired` once per run and reports `reason: unauthorized` while keeping the token**; **an account switch (§4.4) clears every writable bucket's rows, cursor and outbox and leaves read-only pairs alone, a refresh of the recorded id and a first id with none recorded clear nothing, a switch or a sign-out over a non-empty outbox throws `E_PENDING` without changing the token, the id or a row, `discardPending` lets both through, sign-out clears nothing for an app that never recorded an id, a held sync lease fails the switch instead of clearing underneath it, the cleared buckets are reported to the page with `sync.changed`, the sync observations behind `sync.status()` go with them, an empty-string token clears the token and no data, an account id the host cannot read throws rather than reading as "none recorded", and the new token is written while the lease is still held**; **a host with no writable buckets left still throws `E_PENDING` over a queued write, a `data.put` dispatched during a transition is refused with `E_INTERNAL` and reaches neither outbox, and the account id is written before the token on an adoption as well as a switch** |
| bridge | **`has()` answers for an event as well as a method** — true below *and at exactly* the host's version, false above it, false for an unknown name rather than throwing, false for every event on the web and true there for a method the shim implements; missing or wrong nonce → `E_DENIED`; unknown method → `E_UNKNOWN`; bad params → `E_PARAMS`; a write to a read-only bucket → `E_DENIED`; **a `data.put` key of `.` or `..` → `E_PARAMS` and nothing queued, while `...`, `a.b` and `.hidden` are accepted**; `prefs.*` and `secure.*` on a `valence.` key → `E_DENIED`, so the stored token is unreadable by the page; `open.external` rejects `javascript:` and `file:`; reply escaping round-trips U+2028 and quotes; **an inbound message over `MAX_MESSAGE_BYTES` of UTF-8 is rejected by `@getvalence/bridge` before `postMessage`, with `E_TOO_LARGE`, rather than killing the webview** (a multi-byte string that is under the cap in UTF-16 code units and over it in bytes is refused); **an over-cap *reply* is replaced by `E_TOO_LARGE` rather than sent**; **`data.list` clamps `limit` to 500 and defaults it to 100**; **`after` reads a bucket past the clamp completely, in key order, with no row repeated or skipped, composes with `prefix`, resumes correctly from a cursor key that has since been deleted, and advances past an empty first key (`''` is a valid key, so an absent cursor is `null` and never `''`); `data.count` reports a size past the clamp, honours `prefix`, is scoped to the pair and omits tombstones**; **a built-in's optional *param* is passed through when the app's schema declares it, omitted from the delegation when it does not, refused at the wrong type or under another name, refused on a different built-in, **refused without a `version` above the shipped one** (a param has no `since`, so a sibling method or event at the same version is the only thing `has()` can gate on — and `app.info().bridge` is the app's own schema version, so it gates nothing here), and additive against a method a `--store` build already recorded — while an app's own shipped method may not grow a param at all, and neither `since` nor any other method-level key may change** |
| lifecycle, connectivity and update status (§4.6) | `hidden` then `paused` emits one `app.lifecycle` with `background`, and a repeat of the same state emits nothing; **the two state events are dropped rather than buffered when no page is loaded, while the one-shot events still buffer and flush**; `inactive` and `detached` map to themselves; `app.state()` reports the pair before any event has been emitted, and a lifecycle change during start-up updates it while the resume *work* stays suppressed; `app.online` emits only on change, with the first value derived from the current connectivity rather than waiting for one; **a connectivity report with several interfaces is online when any of them is not `none`**; `sync.done` carries the whole `SyncResult` after every completed UI-isolate run including `changed: 0`, `busy` and `unauthorized`, **including the push a `data.put` fires**, and is emitted after `sync.changed` for the same run; **the one-shot buffer is bounded and drops its oldest with a log**; `bundle.status` is `idle` before any check, `unconfigured` with no `otaBase`, and reports `uptodate`, `rollout`, `bad`, `offline`, `rejected`, `toobig`, `waitingForData`, `busy` and `ready` for the step that stopped the check, with `offered` set once the pointer decoded and `checkedAt` moving only on a completed check; **a step 7 stop caused by `dataSizeCap` is `toobig` both when the cap ran out inside a pair's pull and when a first pair spent it all before a second pair's pull began**; `serving`/`pending`/`trial` match the live state; **`bundle.updateReady` fires on every transition to `pending` — urgent and not — once for two coalesced concurrent checks, and never for a check that stopped before step 8** |
| dev diagnostics (widget tests) | startup names the validated upstream origin and disabled OTA behavior; ready, signed reload, update checks and apply each log a dev bypass; startup/resume/periodic checks leave activation evidence unchanged and send no OTA requests; sync remains available; signed startup has no dev warning; release AOT excludes the upstream URL, proxy and dev diagnostics |
| integration (`integration_test`, device or emulator) | **first launch opens the database and paints** — the store and sync rows above run on `sqflite_common_ffi`, which is more permissive than Android's `SQLiteDatabase` (it accepts `execute` for pragmas), so a green unit suite is not evidence the store opens on a phone; cold start in airplane mode renders the built-in bundle with seed data; a corrupt CAS file is detected the first time the server serves it, deleted, and re-downloaded by the next update check; a background sync followed by a UI bridge call (the database must still be open); background then resume after 10 minutes, the server is rebound and the page still works; **each §6 item the app ships actually works on the device** — a biometric prompt appears rather than throwing `no_fragment_activity`, and a reminder scheduled N seconds out really posts and reports `exact` or `inexact` rather than `ok`; **a scheduled window survives a clock change** (`cmd alarm set-time`, then the alarms are still there) **and a reboot**; **a re-arm does not cancel a notification already on screen**; **a widget snapshot reaches a placed widget**, and the provider resolves under the fully-qualified class name |

R8 regression rows (§4.7): owning-view logical insets exclude keyboard and change after rotation; system font size and accessibility preferences are read independently of app theme; native Android zoom follows settings changes; repeated iOS root scaling does not compound; publication preserves navigation and nonce; initial/reload appearance delivery and typed unsubscribe; AppInfo.fontScale is optional and additive only at num?, and generated delegates compile with and without it.

R5 regression rows: exact data-only sync hints only; no payload-supplied config, URLs, tokens or trial transitions; passive startup and explicit permission requests; registration gated on permission/APNs; cold-tap consumption and live-tap race; token rotation; JSON escaping and event cap; disabled-host E_UNSUPPORTED and generated strict nonce/params denials. Device delivery/image/silent-sync checks remain blocked until a Firebase project is supplied.

R17 regression rows: independent app/built-in revisions; reporting-schema parameter coherence; nullable returned fields additive against schema 14; legacy delegation omission; persisted unauthorized/scoped-success outcomes, busy/error preservation and account clearing; signed pending urgency true/false, invalid signature/missing/stale sequence refusal and unchanged activation state.
