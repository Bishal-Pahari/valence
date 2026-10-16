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
    lib/valence/                   server.dart  updater.dart  store.dart  sync.dart  bridge.dart  host.dart
                              bridge.g.dart  config.g.dart   (generated, never edited)
    assets/valence/builtin/        built-in bundle: manifest.json, manifest.json.sig, files/<sha256>  (written by `valence bundle --builtin`)
    assets/valence/seed.db         bundled SQLite seed (written by `valence seed`)
  valence/
    valence.config.json            appId, keyId, web/host paths, OTA and sync base URLs, data schemas, writable buckets
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
- `floor`: the lowest `seq` a device may run after it commits this bundle.
  - Devices keep `state.floor` as a high-water mark that never goes down.
  - `valence bundle` refuses a floor below the previous one.
  - Raise it when a release fixes a security bug.
- `requires.bridge` is the minimum host bridge version. `requires.data` lists the bucket schema versions this UI reads (§5.4).
- `csp` is computed by `valence bundle`: the hashes of the entry page's inline scripts, plus `connect-src` from `sync.base` and `web.connect`. The host sends it as the entry page's `Content-Security-Policy` header (§3).
- `routes` lists the top-level routes. They are compared with the store-reviewed baseline (§7).
- Each `files` path is a relative POSIX path with no empty, `.` or `..` segments, no leading `/`, no `\`, and no NUL. `h` must match `^[0-9a-f]{64}$`.
- **The `.sig` file is the base64 Ed25519 signature over the exact manifest bytes, with no trailing newline.** Hosts trim whitespace anyway.
- The host embeds a keyring, `{keyId: publicKey}`. It picks the key by `keyId` with an own-property lookup. To rotate keys, ship a host that has both keys, then switch signing.

### 2.3 Host update algorithm

Run it on UI start, on resume, and every 30 minutes while in the foreground. **Never block the first paint on it.**

1. **Fetch the pointer** (5 s timeout) and decode it strictly.
   - If `pointer.seq < state.pending`, drop `pending`. The team pulled that release.
   - If `pointer.seq <= current`, or `pointer.seq` is in `bad`, or `pointer.seq <= state.pending`, or `pointer.seq == state.trial`, stop.
   - **`trial` belongs in that list.** A trial is above `current` and leaves `pending` null, so without this guard the 30-minute check re-downloads the bundle that is on screen right now and sets `pending` to it. That stale `pending` then either survives the commit and re-trials a bundle already running, or survives the two-strike `bad` marking and resurrects a bundle this install has already rejected. §2.4 guards the same loop from the other end.
2. **Rollout gate:** `fnv1a32(installId + ":" + seq) % 100 < rollout`. If it fails, stop. `installId` is a random UUID made on first launch; never use a device ID.
3. **Fetch `manifests/<pointer.seq>.json`** (size cap 1 MB) and its `.sig`.
4. **Run checks 1–6** from the canonical order. Any failure means stop and log; never retry the same seq within this run.
5. **Check the total size.** If the sum of `n` for files not already in CAS is over the app's cap (default 50 MB), stop.
6. **Download each missing file** to `<appSupport>/valence/cas/tmp-*`. Verify its sha256 and size (check 7), then rename it to `cas/<h>`.
7. **Data requirements (§5.4).** Make sure every `requires.data` `(bucket, schema)` pair has been synced at least once. If the device is offline, stop: the bundle is not pending until its data is there.
8. **Make it pending.** Write the manifest bytes to `<appSupport>/valence/manifests/<signed seq>.json`, plus the `.sig`, and set `state.pending = seq`.
   - If `urgent` is set, emit `bundle.updateReady`; the web app may then call `bundle.applyUpdate`, which reloads the UI.
   - Otherwise the bundle applies at the next UI start (the WeChat model).

### 2.4 Activation state machine

The state lives in `<appSupport>/valence/state.json`. Write it atomically: write a temp file, flush, then rename.

```json
{ "installId": "…", "port": 23817, "current": 42, "previous": 41, "pending": 43, "trial": null, "trialFails": 0, "serving": null, "bad": [39], "floor": 40 }
```

`serving` is the trial seq while a trial is on screen and still unconfirmed. Otherwise it is null.

**When transitions run.** They run when the host widget is about to load a bundle (UI start), **never in `main()` or in a background isolate.** iOS background launches and workmanager runs must not consume a trial.

At UI start:

1. **A newer built-in bundle wins.** If the built-in bundle's seq is above `current` (a store update shipped it):
   - first install it into CAS through the same checks as an OTA bundle, skipping check 3 because a built-in bundle has no pointer;
   - set `previous = current` and `current = builtin`;
   - drop `pending` and `trial` if they are at or below it, and clear `serving` if its trial was dropped.
2. **A crashed trial.** If `serving == trial`, the last UI start showed the trial and the process died before the trial was confirmed or timed out. Count it as a failure (see below).
3. **No trial but a pending bundle:** **if `pending` is in `bad`, drop it and promote nothing** — a seq this install has judged bad is never tried again. Otherwise set `trial = pending`, clear `pending` and reset `trialFails` to 0.
4. **Serve.** If there's a trial, serve it and set `serving = trial`. Otherwise serve `current`, or the built-in bundle if there's no `current`.

**Counting a failure** happens in exactly one place. It runs from step 2 or on a ready timeout:

- increment `trialFails` and set `serving = null`;
- if `trialFails` reaches **2**, add the trial to `bad`, clear `trial` and `trialFails`, and **drop `pending` if it holds the same seq**;
- otherwise keep the trial: the next UI start tries it once more, since one failure can be a user who opened and closed the app at once.

**`bad` is final for this install.** Nothing promotes, re-downloads or serves a seq in `bad`: not §2.3 step 1, not step 3 above, not step 4. The two-strike rule is the whole safety story, and it only holds if every one of those paths checks the list. A bad bundle is replaced by a higher seq, never retried.

**The ready timer.**

- It counts **15 s of foreground time**, starting at the entry page's `onPageStarted` and paused while the app is in the background.
- **It commits only if `app.ready()` comes from the page that is serving the trial** (`serving == trial`). A `ready()` from a `current` page never commits anything. On commit:
  - `previous = current`, `current = trial`, `trial = null`, `trialFails = 0`, `serving = null`;
  - drop `pending` if it holds the seq just committed, so the next UI start doesn't re-trial the live bundle;
  - `state.floor = max(state.floor, manifest.floor)`;
  - then run garbage collection.
- **On timeout,** count a failure, then reload `current` right away.

**Garbage collection** runs only after a commit.

- **Keep** the manifests for `current`, `previous`, `pending`, `trial` and the built-in bundle, plus every CAS file they reference.
- **Delete** every other manifest and CAS file.
- **Delete** each `(bucket, schema)` pair that no kept manifest requires (§5.4). Writable buckets are never deleted this way.

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
- **If the persisted port can't be bound, never load or keep a page from it.** Pick a random free port in the range, persist it and load from that. Web storage for that origin is lost, which is acceptable: durable data lives in SQLite (§5).

### Nonce

- A 128-bit random nonce is generated whenever the server binds a **new** port, including the first bind of a launch.
- **Rebinding the same port on resume keeps the nonce,** because the loaded page still holds it. The nonce rotates only together with a port change, and every port change reloads the page.
- When serving the entry page, the server inserts `<meta name="valence-nonce" content="<nonce>">` right after `<head>`.
- `bridgeDispatch(…, nonce:)` rejects any message without it (`E_DENIED`).
- So a page served by anything other than our own server, such as another app that grabbed the port, gets no bridge access.

### Serving

- Handle GET and HEAD only. Map the path to a hash through the active manifest, then serve `cas/<h>`.
- Unknown paths with no file extension get the `entry` file (SPA fallback). Anything else returns 404.
- Headers:
  - the entry file: `Cache-Control: no-store` and `Content-Security-Policy: <manifest.csp>`;
  - other files: `Cache-Control: public, max-age=31536000, immutable`;
  - `Content-Type` from a small extension map;
  - `X-Content-Type-Options: nosniff`.

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

### 4.2 Wire protocol

| Direction | Mechanism | Payload |
|---|---|---|
| JS → host | `window.Valence.postMessage(str)` (webview_flutter `JavaScriptChannel` named `Valence`) | `{"id": n, "n": "<nonce>", "m": "data.get", "p": {…}}` |
| host → JS (reply) | `runJavaScript(bridgeReplyScript(reply))`, which produces `window.__valence&&window.__valence.r(<json>)` | `{"id": n, "ok": true, "v": …}` or `{"id": n, "ok": false, "e": {"code", "message"}}` |
| host → JS (event) | `runJavaScript(BridgeEvents.<name>(…))`, which produces `window.__valence&&window.__valence.e("<name>",<json>)` | the event payload |

Error codes:

- `E_UNKNOWN`: the method isn't in the generated table.
- `E_PARAMS`: the params failed decoding.
- `E_UNSUPPORTED`: the host bridge is older than the method's `since`.
- `E_DENIED`: a bad nonce, a write to a non-writable bucket, or a disallowed URL scheme.
- `E_INTERNAL`.

**The host is a trust boundary.**

- Every message goes through the generated `bridgeDispatch` with the current nonce and strict decoders: unknown fields, wrong types and non-JSON input are all rejected.
- Scripts are built only by the generated helpers, which use `jsonEncode`. Raw strings are never concatenated into a script.
- `open.external` accepts only `https:`, `mailto:` and `tel:` URLs.
- **The `valence.` prefix is reserved for the host.** `prefs.get` and `prefs.set` reject `valence.*` keys with `E_DENIED`, so the web can't tamper with internal state such as the sync lease.

### 4.3 Codegen (`node valence/valence.mjs codegen`)

It emits three files:

- **`mobile/lib/valence/config.g.dart`**, from `valence.config.json` and `keyring.json`: `valenceAppId`, `valenceOtaBase`, `valenceSyncBase`, `valenceKeyring` and `valenceWritableBuckets`.
- **`mobile/lib/valence/bridge.g.dart`**:
  - `const hostBridgeVersion`;
  - one strict `fromJson` per type and per params class;
  - the abstract `BridgeHandlers` interface;
  - `bridgeDispatch(h, raw, nonce:)`, which never throws;
  - the `BridgeEvents` script builders and `bridgeReplyScript`.
- **`<web>/src/lib/valence/bridge.g.ts`**:
  - `Methods` and `Events` type maps;
  - `METHOD_SINCE` and `EVENT_SINCE`;
  - `BRIDGE_VERSION`.

The hand-written `client.ts` provides:

- `call(m, params)`, where params are required whenever any field is required;
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
- Open the database with `PRAGMA journal_mode = WAL` and `busy_timeout = 5000`.

### 5.2 Seed

`assets/valence/seed.db` has the same schema and is built by `valence seed`:

- The build is atomic, so a failure keeps the previous seed.
- Every bucket must be in `valence.config.json` `data` with a matching schema.
- Every row is `{k: string, v, u: integer ≥ 1, d}`.

On first launch, and after a host upgrade, the host attaches the seed and, for each `(bucket, schema)` pair, copies the seed rows whose `usn` is above the local `max_usn` for that pair. It then updates the `bucket` row.

The app must be fully usable offline from the seed plus the built-in bundle. That is required by Apple guideline 4.2.3(ii).

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

- **Before an update can become pending** (§2.3 step 7), the updater pulls every `requires.data` pair the device doesn't have yet (from `since = 0`).
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
- Push is idempotent by op `id`. The server assigns the `usn` and echoes the rows back.
- Delete the acknowledged outbox rows, then apply the echoed rows, **except for keys that still have outbox entries**. A newer local edit waits for its own ack.
- Conflict rule: the server applies last-writer-wins per key, in arrival order. Push is only for user-scoped buckets. **There are no CRDTs.** If an app needs collaborative editing, that's a different product.

### 5.6 When sync runs, and concurrency

- **Triggers:**
  - on UI start, on resume and when connectivity comes back (connectivity_plus);
  - when the web app calls `sync.now`;
  - periodically in the background via `workmanager`: on Android at least every 15 minutes; on iOS it's best effort through BGTaskScheduler.
- **One sync at a time,** across the UI and background isolates.
  - Take a lease row in `prefs` (`valence.sync.lease` = epoch ms, written in `BEGIN IMMEDIATE`).
  - The lease is held only if `now - 2 min < lease <= now`. A lease time in the future, from clock skew or tampering, counts as expired.
  - Renew the lease after every applied page, so a long `since = 0` pull doesn't let a second sync start.
  - Release it when the sync finishes.
- **On resume,** compare each bucket's `max_usn` with the last value sent to the UI, and emit `sync.changed` for the ones that moved. Background runs can't reach the WebView.
- **iOS home widget:** write a small JSON snapshot into the App Group container. **Never put the SQLite file in a shared container**: iOS kills an app that suspends while holding a lock on a shared file (0xdead10cc).

---

## 6. Native value (Apple guideline 4.2, "repackaged website")

Ship at least **two** of these in the host before the first store submission:

- offline-first cold start;
- local notifications driven by synced data;
- a home-screen widget (`home_widget`) fed by a JSON snapshot (§5.6);
- native share and haptics;
- biometric lock.

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
| `valence.mjs` (the skill's `valence.test.mjs`) | key directory inside git, including through a link; keyring entry never overwritten; signing key must match the keyring; sign/verify round trip; tampering, bad signature, unknown key, other `appId` and unsafe paths rejected; native extensions rejected; `seq` monotonic with the same clock and a slow clock; floor only rises; CSP hashes (CRLF-safe, `wasm-unsafe-eval` only with `.wasm`); additive-only against `storeSchema`, recorded only by `--store`; new names need `since` above the shipped version; reserved and colliding names; SvelteKit co-located files aren't routes; atomic and validated seed, with a warning for unseeded buckets; the CLI runs through a link; generated Dart passes `analyze --fatal-infos` and the dispatch cases; `client.ts` behaviour |
| updater (dart test) | each check 1–7 rejects; `pointer.seq` below `pending` drops `pending`; the rollout gate is deterministic; size cap; an update isn't pending until its data pairs are synced |
| state machine | trial then ready → committed and floor raised; `ready()` from a `current` page after a timeout never commits the trial; a timeout counts exactly one failure; trial fails once → retried at the next UI start → fails again → marked bad; **the UI start after that serves `current`, not the bad bundle** (a `pending` in `bad` is dropped, never promoted); **an update check while a seq is on trial does not re-pend it**; **a commit clears a `pending` holding the committed seq**; a crash while `serving == trial` counts one failure; a newer built-in bundle wins and drops older pending and trial; GC keeps current, previous, pending, trial and built-in; **GC after a commit leaves writable buckets untouched**; no transition runs from a background isolate; the ready timer pauses in the background |
| server | the same port across launches; a bind failure means a new port, a new nonce, a reload and never serving from the old port; rebinding the same port on resume keeps the nonce and the page keeps working; the nonce is in the entry page only; CSP header on the entry page; GET and HEAD only; SPA fallback |
| store and sync | paged pull is atomic per page; tombstones; outbox rows aren't clobbered by a pull **or by a push echo**; push ack clears only acknowledged ids; seed import per `(bucket, schema)` only moves forward; writable buckets use schema 1; the sync lease blocks concurrent syncs, is renewed per page, and treats a future timestamp as expired |
| bridge | missing or wrong nonce → `E_DENIED`; unknown method → `E_UNKNOWN`; bad params → `E_PARAMS`; a write to a read-only bucket → `E_DENIED`; `prefs.*` on an `valence.` key → `E_DENIED`; `open.external` rejects `javascript:` and `file:`; reply escaping round-trips U+2028 and quotes |
| integration (`integration_test`, device or emulator) | cold start in airplane mode renders the built-in bundle with seed data; a corrupt CAS file is re-downloaded; background then resume after 10 minutes, the server is rebound and the page still works |
