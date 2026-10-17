# Valence contracts (the spec)

This file is the source of truth for every layer. Code must match it. If code and spec disagree, fix the code or change the spec in the same commit. Never let them drift.

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
    lib/valence/                   server.dart  updater.dart  store.dart  sync.dart  bridge.dart  host.dart (incl. log capture, §3)
                              bridge.g.dart  config.g.dart   (generated, never edited)
    assets/valence/builtin/        built-in bundle: manifest.json, manifest.json.sig, files/<sha256>  (written by `valence bundle --builtin`)
    assets/valence/seed.db         bundled SQLite seed (written by `valence seed`)
  valence/
    valence.config.json            appId, keyId, web/host paths, OTA and sync base URLs, data schemas, writable buckets,
                              and web.declaredRoutes for apps whose routes can't be scanned (§7)
    bridge.schema.json        bridge IDL (§4)
    keyring.json              public keys {keyId: base64 raw Ed25519}; compiled into the host by codegen
    valence.mjs                    zero-dependency CLI copied from the skill: keygen | codegen | bundle | verify | pointer | seed
  <web lib>/                  bridge.g.ts (generated) + client.ts + shim.ts (browser fallback)
  .valence/
    baseline.json             committed: {storeSeq, storeRoutes, storeSchema, lastSeq, floor}
    stack-check.md            committed: latest docs-scout report
    dist-ota/                 gitignored: signed output ready to upload
  .gitattributes              one pattern per line (see below)
```

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
  - **It is a one-way door, like `floor`.** `valence bundle` defaults it to the schema's `version`, which is right for a store build and wrong for most OTA releases: once a release sits above the bridge version of the store build in the field, those hosts refuse it *and* every later release, including a copy fix or a security patch. `has()` exists so one bundle can serve old and new hosts; this default undoes that. Build with `--requires-bridge <the oldest store build still supported>` and guard the newer calls. The CLI warns whenever the value lands above the bridge version recorded by the last `--store` build — and separately when you pin it *below* the schema version, listing the methods that then need a `has()` guard, because an unguarded call on an older host throws `E_UNSUPPORTED` with no build-time and no store signal. Note the baseline records only the **last** store build: if an older one is still in the field, that is the number to pin to, and only you know it.
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
{ "installId": "…", "port": 23817, "current": 42, "previous": 41, "pending": 43, "trial": null, "trialFails": 0, "serving": null, "bad": [39], "floor": 40 }
```

`serving` is the trial seq while a trial is on screen and still unconfirmed. Otherwise it is null.

**When transitions run.** They run when the host widget is about to load a bundle (UI start), **never in `main()` or in a background isolate.** iOS background launches and workmanager runs must not consume a trial.

**What that costs, and what may be deferred.** Step 1 below decodes a manifest, verifies an Ed25519 signature and hashes every file it installs, which is real work in front of the first frame — but it is **gated on the built-in seq being above `current`** and it sets `current = builtin`, so it runs once per store release and is a no-op on every launch after that. The budget for an ordinary launch is the state read, the promotion decision and the bind: tens of milliseconds, not hundreds. If a host is slower than that, time `installBuiltin`, the UI-start transition and `Store.open` separately before blaming any of them. What may move off the first-paint path: the update check (§2.3 says never block the first paint on it) and sync. What may not: the promotion decision, because the page that loads has to be the one the state machine chose; and the seed import, because §5.2's first launch has to paint *with data* — an empty first screen is what guideline 4.2.3(ii) is about.

**CAS integrity is re-checked lazily, not at startup.** Nothing re-hashes the store on launch: step 1 skips files already in CAS, and after the first launch of a store build step 1 does not run at all. A file verified at download time (check 7) can still rot on disk afterwards, so the check has to live somewhere — and the only honest place is where the bytes are used. **The server verifies a CAS file's size and sha256 the first time it serves that file for the active manifest, and caches the result for that manifest's lifetime.** On a mismatch it deletes the file, answers 500, and the next update check re-downloads it as missing (§2.3 step 6). That is the mechanism behind §8's "a corrupt CAS file is re-downloaded" row. A size comparison is not a substitute: a corruption that preserves length is precisely what a hash is for.

At UI start:

1. **A newer built-in bundle wins.** If the built-in bundle's seq is above `current` (a store update shipped it):
   - first install it into CAS through the same checks as an OTA bundle, skipping check 3 because a built-in bundle has no pointer;
   - set `previous = current` and `current = builtin`;
   - drop `pending` and `trial` if they are at or below it, and clear `serving` if its trial was dropped;
   - **run garbage collection afterwards** (see below). A store release changes the built-in bundle's `requires.data`, which is the thing pinning the oldest read-only pairs on the device — so it is the single event most likely to make a pair collectable, and a GC that runs only after a commit never sees it.
   - **If the built-in bundle fails its checks, nothing is promoted.** Log which check failed and leave the state alone, then serve `current` at step 4 if there is one. A built-in bundle is never added to `bad`: it is not a release this install can decline, and the next store update replaces it.
     - **With no `current`, that install is unrecoverable and must say so** rather than painting a blank WebView. This is a fresh install of a broken store build — the most expensive mistake a release pipeline can make — and the host's only honest move is a native error screen naming the failed check, because there is no bundle to render one in. Guideline 4.2.3(ii) is about an empty first screen, so a blank WebView is also the worst possible shape for review.
     - The usual cause is not corruption but a **bridge-version mismatch**: `requires.bridge` on the built-in bundle above the version the host reports at check 5. `bundle --store` stamps `requires.bridge` from the schema while the host reports its own constant, so any host that reports a second, hand-written number refuses its own built-in bundle on first launch (§2.2). Nothing else in the pipeline compares those two numbers: `codegen --check`, `verify` and `doctor` are all green on a build that cannot start, because "verifies" only ever meant signatures and hashes.
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
- **On timeout,** count a failure, then reload `current` right away.

**Garbage collection** runs after **any transition that changed the kept set** — a commit, a built-in supersede (step 1), a dropped `pending` or `trial` (step 3), and the two-strike `bad` marking. Never from a background isolate, and never before the first paint.

- **A commit is not the only thing that frees disk, and it is not the most important one.** The built-in bundle's `requires.data` is what pins the oldest read-only pairs, and a store release is the only thing that ever changes it — so the one event most likely to make a pair collectable is precisely the one a commit-only GC misses. An app that ships mostly by store release, or a user who never leaves the app open long enough for the 30-minute check to find an OTA, then never collects anything: on an offline-first app those stale pairs are the largest thing on disk.
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
  - other files: `Cache-Control: public, max-age=31536000, immutable`;
  - `Content-Type` from a small extension map;
  - `X-Content-Type-Options: nosniff`.

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
  "version": 1,
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
    "bundle.applyUpdate": { "since": 1, "params": {}, "returns": "void" }
  },
  "events": {
    "sync.changed":       { "since": 1, "payload": { "buckets": "string[]" } },
    "bundle.updateReady": { "since": 1, "payload": { "seq": "int" } },
    "app.resumed":        { "since": 1, "payload": {} }
  },
  "types": {
    "AppInfo":    { "platform": "string", "host": "int", "bridge": "int", "bundle": "int", "locale": "string" },
    "Row":        { "key": "string", "value": "json", "usn": "int" },
    "SyncResult": { "buckets": "string[]", "changed": "int", "offline": "bool" }
  }
}
```

The type language is `string | int | num | bool | json | void | <TypeName>`. A `[]` suffix means a list and a `?` suffix means nullable; for example `json[]?` is a nullable list. `json` allows any JSON value, including null.

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
- **Inbound (JS → host), `client.ts` refuses before `postMessage`,** because that is the only point where a promise still exists to reject with `E_TOO_LARGE`. It measures `TextEncoder().encode(msg).length`, not `msg.length`: a 100,000-character Japanese note is ~300 KB of UTF-8 and only ~100,000 UTF-16 code units, so a length check passes it and the host then rejects a message it cannot reply to. **This check is cooperative, not a control** — any page can call `window.Valence.postMessage` directly — so it is a usability guard. A host that also caps inbound size must extract the `id` *before* rejecting, so the reply can be delivered; a host that only logs and drops leaves the page's promise pending for ever, since `client.ts` has no per-call timeout.
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

The hand-written `client.ts` provides:

- `call(m, params)`, where params are required whenever any field is required, and which refuses a message over `MAX_MESSAGE_BYTES` of UTF-8;
- `has(m)` and `connect()`;
- `on(event, fn)`;
- `ready()`;
- `installShim()`.

When `window.Valence` is absent (a normal browser), `call` routes to `shim.ts`, which implements methods with `fetch` and storage or throws `E_UNSUPPORTED`. That is what lets **one web codebase serve both the website and the app**.

`codegen --check` exits non-zero if the generated files are stale. CI runs it.

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
- Every bucket must be in `valence.config.json` `data` with a matching schema.
- Every row is `{k: string, v, u: integer ≥ 1, d}`.

On first launch, and after a host upgrade, the host attaches the seed and, for each `(bucket, schema)` pair, copies the seed rows whose `usn` is above the local `max_usn` for that pair. It then updates the `bucket` row. Count the copied rows with `SELECT changes()`: sqflite's `rawInsert` returns a last-insert-rowid, which is meaningless on a `WITHOUT ROWID` table, so a log line built from it reports 1 for a seed of thousands and reads as a failure.

The app must be fully usable offline from the seed plus the built-in bundle. That is required by Apple guideline 4.2.3(ii).

**A seeded pair does not satisfy §2.3 step 7.** That gate is about the server having rows at that schema, so it needs a pull: `synced_at` stays null after a seed import. It costs an offline-first app nothing in practice, because its first bundle is the built-in one and it ships with the matching seed.

### 5.3 Pull (incremental, by update sequence number)

```
GET {SYNC_BASE}/{bucket}?since={max_usn}&schema={n}&limit=500     Authorization: Bearer <token> (user buckets only)
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
- Conflict rule: the server applies last-writer-wins per key, in arrival order. Push is only for user-scoped buckets. **There are no CRDTs.** If an app needs collaborative editing, that's a different product.
- **The loser is never told.** A pull applies the winning row straight over the local one, and the outbox protects a local write only until it is acknowledged, so "A writes 4, A syncs, B writes 7, A syncs" leaves A holding 7 with no record it ever said 4. An app that must show the disagreement **puts the writer in the key** (`<session>:<sku>:<device>` rather than `<session>:<sku>`), so two writers never collide and a review screen can show both. The cost is one row per writer per record, so use a key the app can enumerate.

### 5.6 When sync runs, and concurrency

- **Triggers:**
  - on UI start, on resume and when connectivity comes back (connectivity_plus);
  - when the web app calls `sync.now`;
  - periodically in the background via `workmanager`: on Android at least every 15 minutes; on iOS it's best effort through BGTaskScheduler.
- **The background isolate shares the UI's database connection.** sqflite registers open databases by path in the platform plugin, so each isolate opens the same path, gets the same connection, and neither may close it; a background isolate also needs `DartPluginRegistrant.ensureInitialized()` first (§5.1). The lease below serialises *syncs*; it says nothing about database lifetimes. Because the connection is shared, keep pull pages small (§5.3 caps them at 500) so a long background transaction doesn't queue the UI's reads behind it.
- **One sync at a time,** across the UI and background isolates — **including the updater's step 7 pull (§2.3), which is a sync and takes the same lease.**
  - Take a lease row in `prefs` (`valence.sync.lease` = epoch ms, written in `BEGIN IMMEDIATE`).
  - The lease is held only if `now - 2 min < lease <= now`. A lease time in the future, from clock skew or tampering, counts as expired.
  - Renew the lease after every applied page, so a long `since = 0` pull doesn't let a second sync start.
  - Release it when the sync finishes.
- **On resume,** compare each bucket's `max_usn` with the last value sent to the UI, and emit `sync.changed` for the ones that moved. Background runs can't reach the WebView.
- **iOS home widget:** write a small JSON snapshot into the App Group container. **Never put the SQLite file in a shared container**: iOS kills an app that suspends while holding a lock on a shared file (0xdead10cc).

---

## 6. Native value (Apple guideline 4.2, "repackaged website")

Ship at least **two** of these in the host before the first store submission:

| Item | Package | Native setup Valence does not generate |
|---|---|---|
| offline-first cold start | — | none; the built-in bundle and the seed are it |
| local notifications driven by synced data | `flutter_local_notifications` | the `POST_NOTIFICATIONS` runtime permission, **and `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`** for a reminder that has to land on time (see below) |
| a home-screen widget fed by a JSON snapshot (§5.6) | `home_widget` | an `AppWidgetProvider`, a layout and its registration on Android; a widget extension and an App Group on iOS |
| native share and haptics | `share_plus`, plus Flutter's own `HapticFeedback` | none for text; an image is **not** sent across the bridge (§4.2) — the page sends what to draw and the host renders it |
| biometric lock | `local_auth` | `MainActivity` must extend **`FlutterFragmentActivity`**, not `FlutterActivity`, or every `authenticate()` throws `PlatformException(no_fragment_activity)` |

**This is a list of capabilities that need native work, not a list of things that work out of the box.** Every row but the first fails on a real device while the project builds clean, `dart analyze --fatal-infos` passes, the host tests pass and `doctor` is green — so the §8 matrix is the only place that can catch them, and only if the app adds a row. `flutter create` rewrites `MainActivity`, so the `FlutterFragmentActivity` edit needs a comment saying why it is there.

**A capability whose success is asynchronous must report what the host actually knows, not `ok`.** `notify.schedule` is the worst case: on Android 13+ without `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` the alarm is silently downgraded or refused, so the bridge call succeeds in a few hundred milliseconds, `notify.pending` lists the reminder, the receiver even registers — and it arrives late or not at all. For an app whose purpose is reminding someone, that is the worst failure shape there is. Return `exact` / `inexact` / `blocked` from `AlarmManager.canScheduleExactAlarms()` and surface it on the permission type, so the web app can say so. Google Play restricts `USE_EXACT_ALARM` to apps whose core function is alarms or calendars, so a reminder app either justifies it in review or accepts inexact delivery: that is a §7 question as much as a §5.6 one.

The reviewer agent checks this.

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

## 8. Test matrix (minimum; all must pass before "done")

| Layer | Tests |
|---|---|
| `valence.mjs` (the skill's `valence.test.mjs`) | key directory inside git, including through a link; keyring entry never overwritten; signing key must match the keyring; sign/verify round trip; tampering, bad signature, unknown key, other `appId` and unsafe paths rejected; native extensions rejected; **a bundle file under the reserved `_host/` prefix is refused by both `bundle` and `verify`, and a relative asset URL in the entry page warns**; `seq` monotonic with the same clock and a slow clock; floor only rises; CSP hashes (CRLF-safe, `wasm-unsafe-eval` only with `.wasm`); additive-only against `storeSchema`, recorded only by `--store`; **a second `--store` build cannot rewrite the recorded schema with a non-additive one, `--rebaseline` lets it through with a warning, and `--store` reports what it recorded**; **`--store` warns when a channel points below the seq it just wrote**; **`requires.bridge` rising above the shipped store build warns, and `--requires-bridge` silences it**; new names need `since` above the shipped version; reserved and colliding names; SvelteKit co-located files aren't routes; `web.declaredRoutes` is validated, feeds the manifest and the baseline, and silences the inactive-check warning a project with no scannable routes gets; atomic and validated seed, with a warning for unseeded buckets; the CLI runs through a link; **a wrong `verify --files` level says the directory is wrong rather than naming the first file as missing**; generated Dart passes `analyze --fatal-infos` and the dispatch cases; `client.ts` behaviour, including that `on()`'s unsubscribe returns void so it is a valid React effect cleanup |
| updater (dart test) | each check 1–7 rejects; `pointer.seq` below `pending` drops `pending`; the rollout gate is deterministic; size cap; **a bundle requiring exactly `hostBridgeVersion` is accepted**; **check 5 refuses a `requires.data` key that is malformed or writable** (the mirror of "a newer bridge is refused": without it a host can under-report its version and brick itself on first launch after a schema bump); **check 5 compares against the generated constant, not a second literal**; an update isn't pending until its data pairs are synced; **a bundle requiring a pair the device lacks becomes pending only after step 7 pulls that pair, and never on an offline device**; **a device holding v1 and v2 of one bucket satisfies a requirement for either** |
| state machine | trial then ready → committed and floor raised; `ready()` from a `current` page after a timeout never commits the trial; a timeout counts exactly one failure; trial fails once → retried at the next UI start → fails again → marked bad; **a UI start with no trial counts no failure and adds nothing to `bad`** (both `serving` and `trial` are null); **a ready timeout on a `current` page counts no failure**; **a late `ready()` after a trial was given up commits nothing**; **a `pending` below `current` or below `state.floor` is dropped rather than promoted**; **the UI start after two strikes serves `current`, not the bad bundle** (a `pending` in `bad` is dropped, never promoted); **an update check while a seq is on trial does not re-pend it**; **a commit clears a `pending` holding the committed seq**; a crash while `serving == trial` counts one failure; a newer built-in bundle wins and drops older pending and trial; **a built-in bundle that fails its checks promotes nothing, leaves the state untouched, is not added to `bad`, and with no `current` is surfaced rather than served**; GC keeps current, previous, pending, trial and built-in; **GC after a commit leaves writable buckets untouched**; **a built-in supersede collects the read-only pairs only the old built-in bundle required**; no transition runs from a background isolate; the ready timer pauses in the background |
| server | the same port across launches; a bind failure means a new port, a new nonce, a reload and never serving from the old port; rebinding the same port on resume keeps the nonce and the page keeps working; the nonce is in the entry page only; **the back gesture goes back through webview history and closes the app only when there is none left**; CSP header on the entry page; GET and HEAD only, any other method 405; a path with an empty, `.` or `..` segment is 400, so `//_host/<id>` never reaches the fallback; the SPA fallback answers an extensionless path; **a `/_host/` route is matched before the manifest lookup, an unknown id under it is 404 rather than the entry page, and neither a web-supplied path nor a malformed id escapes the host's directory; **a `/_host/` response carries `nosniff` and `default-src 'none'; sandbox`, refuses a scriptable `Content-Type`, and is refused as a main-frame navigation** |
| store and sync | paged pull is atomic per page; tombstones; outbox rows aren't clobbered by a pull **or by a push echo**; push ack clears only acknowledged ids; seed import per `(bucket, schema)` only moves forward; writable buckets use schema 1; the sync lease blocks concurrent syncs, is renewed per page, and treats a future timestamp as expired; **step 7's pull takes the same lease, stops and logs rather than failing when it cannot, and resumes from the pair's own `max_usn` rather than from 0** |
| bridge | missing or wrong nonce → `E_DENIED`; unknown method → `E_UNKNOWN`; bad params → `E_PARAMS`; a write to a read-only bucket → `E_DENIED`; `prefs.*` on an `valence.` key → `E_DENIED`; `open.external` rejects `javascript:` and `file:`; reply escaping round-trips U+2028 and quotes; **an inbound message over `MAX_MESSAGE_BYTES` of UTF-8 is rejected by `client.ts` before `postMessage`, with `E_TOO_LARGE`, rather than killing the webview** (a multi-byte string that is under the cap in UTF-16 code units and over it in bytes is refused); **an over-cap *reply* is replaced by `E_TOO_LARGE` rather than sent**; **`data.list` clamps `limit` to 500 and defaults it to 100** |
| integration (`integration_test`, device or emulator) | **first launch opens the database and paints** — the store and sync rows above run on `sqflite_common_ffi`, which is more permissive than Android's `SQLiteDatabase` (it accepts `execute` for pragmas), so a green unit suite is not evidence the store opens on a phone; cold start in airplane mode renders the built-in bundle with seed data; a corrupt CAS file is detected the first time the server serves it, deleted, and re-downloaded by the next update check; a background sync followed by a UI bridge call (the database must still be open); background then resume after 10 minutes, the server is rebound and the page still works; **each §6 item the app ships actually works on the device** — a biometric prompt appears rather than throwing `no_fragment_activity`, and a reminder scheduled N seconds out really posts and reports `exact` or `inexact` rather than `ok` |
