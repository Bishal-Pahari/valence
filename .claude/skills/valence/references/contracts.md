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
4. `seq >= state.floor`;
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
   - **Take the §5.6 sync lease first.** This is a second sync path on the same triggers as the ordinary one — both run on UI start and on resume — so without the lease a host runs two concurrent syncs over the same `(bucket, schema)`: interleaved page transactions, racing `max_usn` writes and racing outbox-skip decisions, which is exactly what "one sync at a time" exists to prevent. Renew the lease after every applied page, as §5.6 requires, and release it when step 7 finishes. **If the lease cannot be acquired, stop and log; the next check retries.** That is not a failure and must not count as one — the sync holding the lease was very likely fired by the same trigger.
   - For each `requires.data` `(bucket, schema)` pair the device does not already hold, pull it from **that pair's own `max_usn`**, which is 0 the first time. Never a hard-coded `since = 0`: `synced_at` only becomes non-null once a pull completes (§5.2), so on a flaky link a restart-from-zero re-applies everything it already has, on every UI start, every resume and every 30-minute check, for ever.
   - **Budget it like step 5.** Stop and log once this check has applied more than the app's data cap (default 50 MB across all pairs), and back off before trying again. A manifest can require many pairs and a pair can be large; nothing else bounds this.
   - **A step 7 written as "make sure the pairs are synced" can never pass.** Ordinary sync pulls only the pairs the **active** bundle reads, which during a bump are the *old* schemas, so a newly required pair has no other route onto the device. Nothing else in the system will ever unpark the bundle: `pending` stays null for ever and the app silently stops updating. That is the whole read-only schema-bump feature, disabled, with no user-visible symptom.
   - If a pull fails, or the device is offline, **stop and log which pair it was waiting for.** The bundle is not pending until its data is there, and an offline device refusing a bump it cannot read is the property that makes the bump safe.
   - **Track what is synced as a set of schemas per bucket, not a bucket → schema map.** During a bump a device legitimately holds `plants` v1 *and* v2 at once, because the old UI must keep reading v1 for the trial to be reversible. A `Map<String, int>` lets the v1 entry hide the v2 entry, so the bundle still looks unsatisfied after a successful pull.
8. **Make it pending.** Write the manifest bytes to `<appSupport>/valence/manifests/<signed seq>.json`, plus the `.sig`, and set `state.pending = seq`.
   - If `urgent` is set, emit `bundle.updateReady`; the web app may then call `bundle.applyUpdate`, which reloads the UI.
   - Otherwise the bundle applies at the next UI start (the WeChat model).

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

## 4. Typed bridge

### 4.1 IDL: `valence/bridge.schema.json`

```json
{
  "version": 2,
  "methods": {
    "app.ready":          { "since": 1, "params": {}, "returns": "void" },
    "app.info":           { "since": 1, "params": {}, "returns": "AppInfo" },
    "data.get":           { "since": 1, "params": { "bucket": "string", "key": "string" }, "returns": "json?" },
    "data.list":          { "since": 1, "params": { "bucket": "string", "prefix": "string?", "limit": "int?" }, "returns": "Row[]" },
    "data.put":           { "since": 1, "params": { "bucket": "string", "key": "string", "value": "json?" }, "returns": "void" },
    "sync.now":           { "since": 1, "params": { "buckets": "string[]?" }, "returns": "SyncResult" },
    "prefs.get":          { "since": 1, "params": { "key": "string" }, "returns": "string?" },
    "prefs.set":          { "since": 1, "params": { "key": "string", "value": "string?" }, "returns": "void" },
    "open.external":      { "since": 1, "params": { "url": "string" }, "returns": "void" },
    "bundle.applyUpdate": { "since": 1, "params": {}, "returns": "void" },
    "secure.get":         { "since": 2, "params": { "key": "string" }, "returns": "string?" },
    "secure.set":         { "since": 2, "params": { "key": "string", "value": "string" }, "returns": "void" },
    "secure.delete":      { "since": 2, "params": { "key": "string" }, "returns": "void" },
    "auth.setToken":      { "since": 2, "params": { "token": "string?" }, "returns": "void" },
    "auth.hasToken":      { "since": 2, "params": {}, "returns": "bool" }
  },
  "events": {
    "sync.changed":       { "since": 1, "payload": { "buckets": "string[]" } },
    "bundle.updateReady": { "since": 1, "payload": { "seq": "int" } },
    "app.resumed":        { "since": 1, "payload": {} },
    "auth.expired":       { "since": 2, "payload": {} }
  },
  "types": {
    "AppInfo":    { "platform": "string", "host": "int", "bridge": "int", "bundle": "int", "locale": "string" },
    "Row":        { "key": "string", "value": "json", "usn": "int" },
    "SyncResult": { "buckets": "string[]", "changed": "int", "offline": "bool", "reason": "string?" }
  }
}
```

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
- `E_INTERNAL`.

**Messages are JSON strings, capped at 256 KB of UTF-8 in each direction (`MAX_MESSAGE_BYTES`).**

- On Android a message travels through Binder, whose transaction buffer is around 1 MB and is shared across the process. Overrunning it kills the WebView, with no reply and no error either side can catch.
- **Inbound (JS → host), `@getvalence/bridge` refuses before `postMessage`,** because that is the only point where a promise still exists to reject with `E_TOO_LARGE`. It measures `TextEncoder().encode(msg).length`, not `msg.length`: a 100,000-character Japanese note is ~300 KB of UTF-8 and only ~100,000 UTF-16 code units, so a length check passes it and the host then rejects a message it cannot reply to. **This check is cooperative, not a control** — any page can call `window.Valence.postMessage` directly — so it is a usability guard. A host that also caps inbound size must extract the `id` *before* rejecting, so the reply can be delivered; a host that only logs and drops leaves the page's promise pending for ever, since the client has no per-call timeout.
- **Outbound (host → JS) is the half that bites,** and the generated dispatcher caps it: it has the `id`, so an over-cap reply is replaced by `E_TOO_LARGE` rather than sent. Without that cap a single large reply can kill the WebView mid-trial — and if the WebView dies while `serving == trial`, the ready timer times out, the next launch counts the second strike, and §2.4 puts a **healthy** bundle in `bad`, which is final. A release rolled back for ever with no crash log is the worst outcome in the system, and an uncapped reply is a way to reach it.
  - **`data.list`'s `limit` therefore has a default of 100 and a hard maximum of 500,** clamped by the host rather than trusted from the page. Without them `data.list({bucket})` over a few thousand rows is that failure.
- **So the bridge is not the path for bytes.** There is no blob, no file handle and no shared scratch directory, and base64 adds a third again on top. Native bytes reach the page over the loopback server's reserved `/_host/` prefix (§3). Bytes going the other way — an image to share, a file to upload — are **regenerated host-side from parameters**: the page sends what to draw, or a key the host already holds, and the host produces the bytes. There is deliberately no inbound HTTP path. The server is GET and HEAD only (§3), the nonce is checked by `bridgeDispatch` and never on HTTP, and the port is not a secret — so a `PUT /_host/…` would let any app on the device write into app-private storage unauthenticated.
- **A method that does take bytes validates in this order,** because the page is untrusted and "a share method" is otherwise a way to write attacker-chosen bytes to disk under an attacker-chosen name: cap the *encoded* length before decoding; decode; check the magic bytes against the type the method claims; require the file name to be a plain leaf matching an explicit pattern; write into a scratch directory the host wipes before each use.

**The host is a trust boundary.**

- Every message goes through the generated `bridgeDispatch` with the current nonce and strict decoders: unknown fields, wrong types and non-JSON input are all rejected.
- Scripts are built only by the generated helpers, which use `jsonEncode`. Raw strings are never concatenated into a script.
- `open.external` accepts only `https:`, `mailto:` and `tel:` URLs.
- **The `valence.` prefix is reserved for the host.** `prefs.get` and `prefs.set` reject `valence.*` keys with `E_DENIED`, so the web can't tamper with internal state such as the sync lease.

**Emitting an event.** The host runs the generated builder in the WebView: `controller.runJavaScript(BridgeEvents.syncChanged(buckets: [...]))`. The builder renders the whole call through `jsonEncode`.

- **`window.__valence` does not exist until the entry page has loaded,** so an event emitted before that is silently dropped — and the interesting ones arrive exactly then (a notification tap that cold-starts the app, connectivity returning during startup). **The host buffers event scripts and flushes them on `onPageFinished`,** and flushes again after every reload, because an update or a reverted trial reloads the page.
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
- `has(m)` and `connect()`;
- `on(event, fn)`, whose unsubscribe returns `void` so it is a valid React effect cleanup;
- `ready()`;
- `installShim()`;
- `inHost()` and `BridgeError`.

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
"auth.setToken":  { "since": 2, "params": { "token": "string?" }, "returns": "void" },
"auth.hasToken":  { "since": 2, "params": {}, "returns": "bool" }
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
- and on every request the host performs for the page once `http.request` exists (R11).

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

**What logout does not do.** Clearing the token leaves the local SQLite rows exactly where they are. The
host has no "wipe user data" operation, because only the app knows which buckets are the user's and
whether the device is shared. An app that must forget a user deletes those rows itself with
`data.put(bucket, key, null)` — and should know that the tombstones then push to the server.

---

## 5. Data layer

### 5.1 SQLite schema (host, sqflite)

```sql
CREATE TABLE kv (bucket TEXT NOT NULL, schema INTEGER NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, usn INTEGER NOT NULL,
                 deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (bucket, schema, key)) WITHOUT ROWID;
CREATE INDEX kv_bucket_usn ON kv (bucket, schema, usn);
CREATE TABLE bucket (name TEXT NOT NULL, schema INTEGER NOT NULL, max_usn INTEGER NOT NULL, synced_at INTEGER,
                     PRIMARY KEY (name, schema));
CREATE TABLE outbox (id TEXT PRIMARY KEY, bucket TEXT NOT NULL, key TEXT NOT NULL, value TEXT,
                     deleted INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL);
PRAGMA user_version = 1;
```

- `value` is JSON text. HTTP gzip handles compression on the wire.
- Migrations use `user_version` and are append-only.
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

- Rows come in ascending `usn` order.
- Apply each page in **one transaction**, set `max_usn` for that `(bucket, schema)` to the last row's `u`, and loop while `more` is true.
- A row with `d: 1` is a tombstone, so set `deleted = 1`. `max_usn` only moves forward.
- **Rows whose `(bucket, key)` has pending outbox entries are skipped**: the local write wins until the server acknowledges it.
- Remote "fixes" (corrections to bundled data) are just rows with a higher `usn`. There's no separate patch mechanism.

**Static variant** (CDN-only, no backend), for public read-only buckets: publish `{SYNC_BASE}/{bucket}/v{schema}/index.json`, listing `[{"from": usn, "to": usn, "file": "c-0007.json.gz"}]`. Each chunk has the same `rows` shape. The client fetches the chunks whose `to` is above `max_usn`.

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
- **The loser is never told.** A pull applies the winning row straight over the local one, and the outbox protects a local write only until it is acknowledged, so "A writes 4, A syncs, B writes 7, A syncs" leaves A holding 7 with no record it ever said 4. An app that must show the disagreement **puts the writer in the key** (`<session>:<sku>:<device>` rather than `<session>:<sku>`), so two writers never collide and a review screen can show both. The cost is one row per writer per record, so use a key the app can enumerate.

### 5.6 When sync runs, and concurrency

- **Triggers:**
  - on UI start, on resume and when connectivity comes back (connectivity_plus);
  - when the web app calls `sync.now`;
  - periodically in the background via `workmanager`: on Android at least every 15 minutes; on iOS it's best effort through BGTaskScheduler.
- **The background isolate shares the UI's database connection.** sqflite registers open databases by path in the platform plugin, so each isolate opens the same path, gets the same connection, and neither may close it; a background isolate also needs `DartPluginRegistrant.ensureInitialized()` first (§5.1). The lease below serialises *syncs*; it says nothing about database lifetimes. Because the connection is shared, keep pull pages small (§5.3 caps them at 500) so a long background transaction doesn't queue the UI's reads behind it.
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
| native share and haptics | `share_plus`, plus Flutter's own `HapticFeedback` | none for text; an image is **not** sent across the bridge (§4.2) — the page sends what to draw and the host renders it |
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
- **Set `tz.local` from the device's real zone, and schedule wall-clock times, not instants.** The plugin re-derives every stored notification against `tz.local` whenever the clock, the timezone or the device changes. Scheduling an absolute instant (`tz.TZDateTime.from(utc, tz.UTC)`) passes every unit test and then **deletes every scheduled alarm** on the first `TIME_SET` — six before a clock change, zero after, nothing in the log. Building the same times in the device's zone leaves all six intact.
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
- `ota.channel` defaults to `production` and must match `[A-Za-z0-9_-]+`. Codegen emits `valenceOtaChannel` and wires it into `valenceConfig.channel`; the updater follows that channel. Bundles remain channel-neutral. Changing a compiled host's channel needs a host build.
- OTA `requires.bridge` defaults to `baseline.storeSchema.version`, falling back to the local schema version before any store baseline. Built-in and store builds default to the local schema version. An explicit `--requires-bridge` still wins. Building below the local version names the methods needing `has()` guards; it does not make unguarded calls safe.
- `seedSchemas: {bucket: int[]}` optionally declares additional read-only schemas the project may seed. Current `data` schemas are implicitly declared. `seed --from` accepts legacy `<bucket>.json` and `<bucket>.v<N>.json` files with `{schema, rows}`. A versioned filename must match its payload; every pair must be declared, duplicates fail atomically, and multiple schemas coexist. Missing **current pairs** warn even if an older pair was seeded. Writable buckets remain schema 1 and cannot be declared in `seedSchemas`.
- Codegen emits an opt-in `BridgeHandlersDefaults` mixin implementing every handler with `E_UNSUPPORTED`. Use it for test doubles or partial hosts; production hosts should extend `ValenceBuiltins` and explicitly implement their own methods. A defaults mixin must not mask the built-in implementations.
- `node valence/valence.mjs doctor [--tests]` runs mechanical diagnostics without an AI session. It checks config, codegen freshness, built-in signature/files/host bridge/data compatibility, current seed coverage, baseline and stack report presence, declared `nativeValue` (at least two distinct §6 capabilities), resolved Flutter dependencies, and app test-matrix evidence. Rows are `PASS`, `WARN` (missing or unexecuted evidence), or `FAIL` (a check ran and failed); any failure exits nonzero. Missing evidence never passes. `nativeValue` is a declaration, not proof of device behavior. `.valence/test-matrix.json` maps stable layer IDs `bridge`, `loopback`, `updater`, `store-sync`, `integration` to app-relative Flutter `test/` or `integration_test/` files; doctor lists every ID. `--tests` executes mapped unit tests; integration rows stay WARN and need a separate device run. File mappings are evidence pointers, not proof that assertions cover the contract. Doctor does not certify store approval or emulator behavior.

## 8. Test matrix (minimum; all must pass before "done")

R12 regression rows: batch reads preserve requested order, deduplicate, isolate bucket/schema, omit tombstones, bind hostile keys, and reject over-limit input; sync status counts deletes and survives reopen, preserves observations on busy and errors, timestamps only successful unscoped runs; generated defaults dispatch as `E_UNSUPPORTED`; old schemas still generate without grown fields; channel validation and beta pointer URL; store-baseline OTA default with explicit and built-in overrides; multi-schema seed declaration/duplicate/atomicity/current-coverage checks; doctor reports missing evidence as WARN and real failures as FAIL.

| Layer | Tests |
|---|---|
| `valence.mjs` (the skill's `valence.test.mjs`) | key directory inside git, including through a link; keyring entry never overwritten; signing key must match the keyring; sign/verify round trip; tampering, bad signature, unknown key, other `appId` and unsafe paths rejected; native extensions rejected; **a bundle file under the reserved `_host/` prefix is refused by both `bundle` and `verify`, and a relative asset URL in the entry page warns**; **a service-worker registration in the output warns**; `seq` monotonic with the same clock and a slow clock; floor only rises; CSP hashes (CRLF-safe, `wasm-unsafe-eval` only with `.wasm`); additive-only against `storeSchema`, recorded only by `--store`; **a second `--store` build cannot rewrite the recorded schema with a non-additive one, `--rebaseline` lets it through with a warning, and `--store` reports what it recorded**; **`--store` warns when a channel points below the seq it just wrote**; **`requires.bridge` rising above the shipped store build warns, and `--requires-bridge` silences it**; new names need `since` above the shipped version; reserved and colliding names; SvelteKit co-located files aren't routes; `web.declaredRoutes` is validated, feeds the manifest and the baseline, and silences the inactive-check warning a project with no scannable routes gets; atomic and validated seed, with a warning for unseeded buckets; the CLI runs through a link; **a wrong `verify --files` level says the directory is wrong rather than naming the first file as missing**; a built-in may be omitted but not redefined with a different shape, including `secure.*` and `auth.*`; **a built-in's optional field is passed through when the app's type declares it, omitted from the delegation when it does not, still refused at the wrong type, and additive against a type a `--store` build already recorded — while an app's own shipped type may not grow at all**; generated Dart passes `analyze --fatal-infos` against `package:valence` and satisfies the dispatch cases; the generated `bridge.g.ts` binds the package, including `METHOD_SINCE` refusing a method newer than the host |
| updater (dart test) | each check 1–7 rejects; `pointer.seq` below `pending` drops `pending`; the rollout gate is deterministic; size cap; **a bundle requiring exactly `hostBridgeVersion` is accepted**; **check 5 refuses a `requires.data` key that is malformed or writable** (the mirror of "a newer bridge is refused": without it a host can under-report its version and brick itself on first launch after a schema bump); **check 5 compares against the generated constant, not a second literal**; an update isn't pending until its data pairs are synced; **a bundle requiring a pair the device lacks becomes pending only after step 7 pulls that pair, and never on an offline device**; **a device holding v1 and v2 of one bucket satisfies a requirement for either** |
| state machine | **a mid-session reload runs step 4 only**: `applyUpdate` serves the promoted trial without counting a failure against it, and a ready timeout serves `current` while leaving `trial` set so the next UI start retries it once; **a refused built-in bundle is remembered by manifest bytes and host bridge version, so a host upgrade that fixes check 5 installs it rather than skipping it**, and step 1 reads only the `seq` on an ordinary launch; **a collection that runs between §2.3 steps 6 and 8 keeps the in-flight bundle's CAS files and any `tmp-*`**; **a corrupt file of the *active* bundle is re-fetched by the repair pass before step 1**; trial then ready → committed and floor raised; `ready()` from a `current` page after a timeout never commits the trial; a timeout counts exactly one failure; trial fails once → retried at the next UI start → fails again → marked bad; **a UI start with no trial counts no failure and adds nothing to `bad`** (both `serving` and `trial` are null); **a ready timeout on a `current` page counts no failure**; **a late `ready()` after a trial was given up commits nothing**; **a `pending` below `current` or below `state.floor` is dropped rather than promoted**; **the UI start after two strikes serves `current`, not the bad bundle** (a `pending` in `bad` is dropped, never promoted); **an update check while a seq is on trial does not re-pend it**; **a commit clears a `pending` holding the committed seq**; a crash while `serving == trial` counts one failure; a newer built-in bundle wins and drops older pending and trial; **a built-in bundle that fails its checks promotes nothing, leaves the state untouched, is not added to `bad`, and with no `current` is surfaced rather than served**; GC keeps current, previous, pending, trial and built-in; **GC after a commit leaves writable buckets untouched**; **a supersede collects the pairs that fell out of `previous`, and GC skips the pair step when the sync lease is held**; no transition runs from a background isolate; the ready timer pauses in the background |
| server | the same port across launches; a bind failure means a new port, a new nonce, a reload and never serving from the old port; rebinding the same port on resume keeps the nonce and the page keeps working; the nonce is in the entry page only; **the back gesture goes back through webview history and closes the app only when there is none left**; CSP header on the entry page; GET and HEAD only, any other method 405; a path with an empty, `.` or `..` segment is 400, so `//_host/<id>` never reaches the fallback; the SPA fallback answers an extensionless path; **a `/_host/` route is matched before the manifest lookup, an unknown id under it is 404 rather than the entry page, and neither a web-supplied path nor a malformed id escapes the host's directory; **a `/_host/` response carries `nosniff` and `default-src 'none'; sandbox`, refuses a scriptable `Content-Type`, and is refused as a main-frame navigation**; **a bundle file is served `no-cache` with its sha256 as a strong `ETag`, a matching `If-None-Match` (weak and `*` included) is 304 with no body, and the same path in the next bundle gets a different `ETag`, so a cached copy can never answer for new code**; the entry page stays `no-store` and carries no `ETag` |
| store and sync | **a writable bucket is pulled as well as pushed, at schema 1, and a pull never clobbers a local write that has not been acknowledged yet**; paged pull is atomic per page; tombstones; outbox rows aren't clobbered by a pull **or by a push echo**; push ack clears only acknowledged ids; seed import per `(bucket, schema)` only moves forward; writable buckets use schema 1; the sync lease blocks concurrent syncs, is renewed per page, and treats a future timestamp as expired; **a lease recorded by another pid, or by an older host with no pid, is taken over rather than waited out, while our own live lease is still respected**; **a blocked run reports `reason: busy` rather than an empty success, a completed run reports `ok`, and an unreachable server reports `offline` with the old `offline` flag unchanged**; **step 7's pull takes the same lease, stops and logs rather than failing when it cannot, and resumes from the pair's own `max_usn` rather than from 0**; **a stored token is attached as `Authorization: Bearer` to a writable bucket's pull and push and to neither for a public read-only bucket, `ValenceConfig.authToken` wins over the stored one, a secure-storage platform that is absent reads as no token rather than throwing, and a 401 emits `auth.expired` once per run and reports `reason: unauthorized` while keeping the token** |
| bridge | missing or wrong nonce → `E_DENIED`; unknown method → `E_UNKNOWN`; bad params → `E_PARAMS`; a write to a read-only bucket → `E_DENIED`; `prefs.*` and `secure.*` on a `valence.` key → `E_DENIED`, so the stored token is unreadable by the page; `open.external` rejects `javascript:` and `file:`; reply escaping round-trips U+2028 and quotes; **an inbound message over `MAX_MESSAGE_BYTES` of UTF-8 is rejected by `@getvalence/bridge` before `postMessage`, with `E_TOO_LARGE`, rather than killing the webview** (a multi-byte string that is under the cap in UTF-16 code units and over it in bytes is refused); **an over-cap *reply* is replaced by `E_TOO_LARGE` rather than sent**; **`data.list` clamps `limit` to 500 and defaults it to 100** |
| integration (`integration_test`, device or emulator) | **first launch opens the database and paints** — the store and sync rows above run on `sqflite_common_ffi`, which is more permissive than Android's `SQLiteDatabase` (it accepts `execute` for pragmas), so a green unit suite is not evidence the store opens on a phone; cold start in airplane mode renders the built-in bundle with seed data; a corrupt CAS file is detected the first time the server serves it, deleted, and re-downloaded by the next update check; a background sync followed by a UI bridge call (the database must still be open); background then resume after 10 minutes, the server is rebound and the page still works; **each §6 item the app ships actually works on the device** — a biometric prompt appears rather than throwing `no_fragment_activity`, and a reminder scheduled N seconds out really posts and reports `exact` or `inexact` rather than `ok`; **a scheduled window survives a clock change** (`cmd alarm set-time`, then the alarms are still there) **and a reboot**; **a re-arm does not cancel a notification already on screen**; **a widget snapshot reaches a placed widget**, and the provider resolves under the fully-qualified class name |
