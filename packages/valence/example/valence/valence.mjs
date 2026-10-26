#!/usr/bin/env node
// Valence CLI. Zero dependencies, Node >= 22.13. Spec: ../references/contracts.md
import {
  rmSync,
  mkdirSync,
  existsSync,
  renameSync,
  readdirSync,
  readFileSync,
  realpathSync,
  writeFileSync,
} from 'node:fs';
import {
  sign,
  verify,
  createHash,
  createPublicKey,
  createPrivateKey,
  generateKeyPairSync,
} from 'node:crypto';
import { homedir } from 'node:os';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';

export const VALENCE_VERSION = '0.3.0'; // keep equal to package.json "version" (tested)
const NATIVE = new Set(['.so', '.dex', '.jar', '.apk', '.aab', '.ipa', '.dylib', '.framework', '.a', '.o', '.class', '.exe', '.dll']);
const PRIMS = new Set(['string', 'int', 'num', 'bool', 'json', 'void']);
const CORE_METHODS = ['app.ready', 'app.info'];
const SPKI_ED25519 = Buffer.from('302a300506032b6570032100', 'hex');
const HASH_RE = /^[0-9a-f]{64}$/;
// A service worker can only take over the page by being registered from it, and every framework's helper
// ends up calling this. Matching the registration rather than a file name covers Workbox, vite-plugin-pwa
// and a hand-written one alike.
const SERVICE_WORKER_RE = /serviceWorker\s*\.\s*register\s*\(/;
// Names that break the generated Dart (reserved words, built-in identifiers, Object members, generated members).
const DART_RESERVED = new Set(`abstract as assert await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for Function get if implements import in interface is late library mixin new null operator part required rethrow return set static super switch this throw true try typedef var void while with yield hashCode runtimeType toString noSuchMethod toJson fromJson`.split(' '));
// Type names that collide with Dart/TS builtins or with names the generator emits.
const RESERVED_TYPES = new Set('Json Methods Events Object String Number Boolean Array Record Promise Map Set List Future Function Iterable Never Null Symbol BigInt Error Date Type Enum BridgeError BridgeHandlers BridgeHandlersDefaults BridgeEvents'.split(' '));
// The methods the `valence` pub package implements. codegen emits a `ValenceBuiltins` base class whose
// bodies delegate to the runtime, so the logic ships in the package and only the schema-shaped
// marshalling is generated. A schema may leave any of them out; it may not redefine one with a different
// shape, because the delegation would then be wrong in a way nothing else would catch.
//
// `params` is compared literally against the IDL. `returns` is either an IDL type string or
// {fields, list}, meaning "a named type with exactly these fields" — the app picks the type's name.
//
// `returns.optional` holds fields a later runtime added, which rule 5 (the IDL is additive only) requires
// be possible without breaking every app already on the older shape. An app's type may carry any subset of
// them, including none, and `call` is handed the names it actually declared so the delegation only passes
// what exists. A field never moves from `fields` to `optional` or back: `fields` is the shape every host
// has always returned.
const BUILTINS = {
  'app.ready': { params: {}, returns: 'void', call: () => 'await valence.appReady();' },
  'app.info': {
    params: {},
    returns: { fields: { platform: 'string', host: 'int', bridge: 'int', bundle: 'int', locale: 'string' } },
    call: (t) =>
      `final i = valence.appInfo();\n        return ${t}(platform: i.platform, host: i.host, bridge: i.bridge, bundle: i.bundle, locale: i.locale);`,
  },
  // §4.6. Both read state the host already keeps, so neither starts a request and a page may poll them.
  'app.state': {
    params: {},
    returns: { fields: { lifecycle: 'string', online: 'bool' } },
    call: (t) => `final s = valence.appState();
        return ${t}(lifecycle: s.lifecycle.name, online: s.online);`,
  },
  'bundle.status': {
    params: {},
    returns: {
      fields: { serving: 'int', pending: 'int?', trial: 'int?', reason: 'string', offered: 'int?', checkedAt: 'int?' },
    },
    call: (t) =>
      `final s = valence.bundleStatus();
        return ${t}(serving: s.serving, pending: s.pending, trial: s.trial, reason: s.reason.name, offered: s.offered, checkedAt: s.checkedAt);`,
  },
  'data.get': {
    params: { bucket: 'string', key: 'string' },
    returns: 'json?',
    call: () => 'return valence.dataGet(p.bucket, p.key);',
  },
  'data.list': {
    params: { bucket: 'string', prefix: 'string?', limit: 'int?' },
    // `after` is the key cursor that makes a bucket past `maxListLimit` readable at all. Optional, because
    // the returns are a plain `Row[]` and an app on the older shape must keep compiling (rule 5).
    optionalParams: { after: 'string?' },
    // A param has no `since`, so the only gate a page can read is a sibling *name* that shipped with it
    // (§4.2). `data.count` is `after`'s. Declaring `after` without it leaves the documented gate —
    // `has('data.count')` — false on every host the app will ever ship, including the ones that accept
    // the cursor, so a page following the docs never pages and the bucket still has no complete read.
    paramSiblings: { after: 'data.count' },
    returns: { list: true, fields: { key: 'string', value: 'json', usn: 'int' } },
    call: (t, _has, hasParam) =>
      `final rows = await valence.dataList(p.bucket, prefix: p.prefix, limit: p.limit${hasParam('after') ? ', after: p.after' : ''});\n        return [for (final r in rows) ${t}(key: r.key, value: r.value, usn: r.usn)];`,
  },
  'data.count': {
    params: { bucket: 'string', prefix: 'string?' },
    returns: 'int',
    call: () => 'return valence.dataCount(p.bucket, prefix: p.prefix);',
  },
  'data.getMany': {
    params: { bucket: 'string', keys: 'string[]' },
    returns: { list: true, fields: { key: 'string', value: 'json', usn: 'int' } },
    call: (t) =>
      `final rows = await valence.dataGetMany(p.bucket, p.keys);\n        return [for (final r in rows) ${t}(key: r.key, value: r.value, usn: r.usn)];`,
  },
  'sync.status': {
    params: {},
    returns: { fields: { pending: 'int', lastSyncedAt: 'int?', offline: 'bool' } },
    call: (t) =>
      `final r = await valence.syncStatus();\n        return ${t}(pending: r.pending, lastSyncedAt: r.lastSyncedAt, offline: r.offline);`,
  },
  'data.put': {
    params: { bucket: 'string', key: 'string', value: 'json?' },
    returns: 'void',
    call: () => 'await valence.dataPut(p.bucket, p.key, p.value);',
  },
  'sync.now': {
    params: { buckets: 'string[]?' },
    returns: {
      fields: { buckets: 'string[]', changed: 'int', offline: 'bool' },
      // "nothing was attempted" and "nothing changed" are otherwise the same answer, so an app that shows
      // freshness reports confident freshness over stale data. `"ok"`, `"busy"` or `"offline"`.
      optional: { reason: 'string?', pending: 'int?' },
    },
    call: (t, has) =>
      `final r = await valence.syncNow(buckets: p.buckets);\n        return ${t}(buckets: r.buckets, changed: r.changed, offline: r.offline${has('reason') ? ', reason: r.reason.name' : ''}${has('pending') ? ', pending: r.pending' : ''});`,
  },
  'prefs.get': { params: { key: 'string' }, returns: 'string?', call: () => 'return valence.prefsGet(p.key);' },
  'prefs.set': {
    params: { key: 'string', value: 'string?' },
    returns: 'void',
    call: () => 'await valence.prefsSet(p.key, p.value);',
  },
  'open.external': {
    params: { url: 'string' },
    returns: 'void',
    call: () => 'await valence.openExternal(p.url);',
  },
  'bundle.applyUpdate': {
    params: {},
    returns: 'void',
    call: () => 'await valence.applyUpdate();',
  },
  // §4.4. secure.set takes a non-null value on purpose: prefs.set(k, null) and data.put(b, k, null) both
  // delete, so this is the odd one out and secure.delete is the only delete, which says so at the call site.
  'secure.get': { params: { key: 'string' }, returns: 'string?', call: () => 'return valence.secureGet(p.key);' },
  'secure.set': {
    params: { key: 'string', value: 'string' },
    returns: 'void',
    call: () => 'await valence.secureSet(p.key, p.value);',
  },
  'secure.delete': { params: { key: 'string' }, returns: 'void', call: () => 'await valence.secureDelete(p.key);' },
  'auth.setToken': {
    params: { token: 'string?' },
    // §4.4. The opaque account id is what tells a refresh from a different person, and `discardPending`
    // is the only way past the refusal to drop one account's queued writes. Optional, because every app
    // on the older shape must keep compiling (rule 5).
    optionalParams: { account: 'string?', discardPending: 'bool?' },
    // Neither param has a `since`, so the only gate is the sibling name that shipped with them. Without
    // `auth.account` declared, a page following the docs reads a false gate on every host — including
    // the ones that enforce the switch — and therefore never passes the id at all, which is the silent
    // half of this feature: no error, no switch, user B looking at user A's rows.
    paramSiblings: { account: 'auth.account', discardPending: 'auth.account' },
    returns: 'void',
    call: (_t, _has, hasParam) =>
      `await valence.authSetToken(p.token${hasParam('account') ? ', account: p.account' : ''}${hasParam('discardPending') ? ', discardPending: p.discardPending ?? false' : ''});`,
  },
  // There is deliberately no auth.getToken: the token lives under the reserved `valence.` prefix, so the
  // page can set and clear it and ask whether one is there, and can never read it back (§4.4).
  'auth.hasToken': { params: {}, returns: 'bool', call: () => 'return valence.authHasToken();' },
  // The account id *is* readable back: the page chose it, so it learns nothing new, and it is what makes
  // "is the host still holding the user I signed in?" answerable after a cold start.
  'auth.account': { params: {}, returns: 'string?', call: () => 'return valence.authAccount();' },
  'link.initial': {
    params: {},
    returns: { fields: { url: 'string', path: 'string' }, nullable: true },
    call: (t) => `final r = valence.linkInitial();\n        return r == null ? null : ${t}(url: r.url, path: r.path);`,
  },
  'http.request': {
    params: { url: 'string', method: 'string?', headers: 'json?', body: 'string?' },
    returns: { fields: { status: 'int', headers: 'json', body: 'string' } },
    call: (t) =>
      `final r = await valence.httpRequest(url: p.url, method: p.method, headers: p.headers, body: p.body);\n        return ${t}(status: r.status, headers: r.headers, body: r.body);`,
  },
};

const SEED_SQL = `
CREATE TABLE kv (bucket TEXT NOT NULL, schema INTEGER NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, usn INTEGER NOT NULL,
                 deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (bucket, schema, key)) WITHOUT ROWID;
CREATE INDEX kv_bucket_usn ON kv (bucket, schema, usn);
CREATE TABLE bucket (name TEXT NOT NULL, schema INTEGER NOT NULL, max_usn INTEGER NOT NULL, synced_at INTEGER,
                     PRIMARY KEY (name, schema));
CREATE TABLE outbox (ordinal INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE, bucket TEXT NOT NULL, key TEXT NOT NULL, value TEXT,
                     deleted INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL);
PRAGMA user_version = 2;`;

// ---------- small helpers ----------

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const writeJson = (p, v) => writeFile(p, JSON.stringify(v, null, 2) + '\n');
const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
const camel = (s) => s.replace(/[._](\w)/g, (_, c) => c.toUpperCase());
const pascal = (s) => camel(s).replace(/^\w/, (c) => c.toUpperCase());
const canonical = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort()) : x));

function writeFile(p, data) {
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, data);
}

function int(v, name, min = 0, max = Number.MAX_SAFE_INTEGER) {
  const n = typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : v;
  if (!Number.isInteger(n) || n < min || n > max) throw new Error(`${name} must be an integer in [${min}, ${max}], got ${v}`);
  return n;
}

function walk(dir, base = dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(full, base));
    else if (e.isFile()) out.push(relative(base, full).split(sep).join('/'));
  }
  return out.sort();
}

// Resolves links on the nearest existing ancestor, so a symlinked ~/.valence inside a repo is caught.
function insideGit(dir) {
  let d = resolve(dir);
  const rest = [];
  while (!existsSync(d) && dirname(d) !== d) {
    rest.unshift(d.slice(dirname(d).length));
    d = dirname(d);
  }
  for (d = join(realpathSync(d), ...rest); ; d = dirname(d)) {
    if (existsSync(join(d, '.git'))) return true;
    if (dirname(d) === d) return false;
  }
}

export function loadConfig(root) {
  const cfg = readJson(join(root, 'valence', 'valence.config.json'));
  if (!/^[a-zA-Z]\w*(\.[a-zA-Z]\w*)+$/.test(cfg.appId ?? '')) throw new Error('valence.config.json: appId must look like com.example.app');
  if (!/^[\w-]+$/.test(cfg.keyId ?? '')) throw new Error('valence.config.json: keyId must match [\\w-]+');
  if (typeof cfg.web?.out !== 'string' || typeof cfg.web?.lib !== 'string') throw new Error('valence.config.json: web.out and web.lib are required');
  if (typeof cfg.host?.dir !== 'string') throw new Error('valence.config.json: host.dir is required');
  for (const [b, n] of Object.entries(cfg.data ?? {})) int(n, `valence.config.json: data.${b}`, 1);
  if (cfg.ota?.channel !== undefined && (typeof cfg.ota.channel !== 'string' || !/^[A-Za-z0-9_-]+$/.test(cfg.ota.channel))) {
    throw new Error('ota.channel must match [A-Za-z0-9_-]+');
  }
  for (const [b, schemas] of Object.entries(cfg.seedSchemas ?? {})) {
    if (!Array.isArray(schemas) || !schemas.length || cfg.data?.[b] === undefined) {
      throw new Error(`seedSchemas.${b} must be a nonempty array for a declared read-only bucket`);
    }
    for (const n of schemas) int(n, `seedSchemas.${b}`, 1);
  }
  for (const b of cfg.writable ?? []) {
    if (cfg.data?.[b] !== undefined) throw new Error(`valence.config.json: writable bucket "${b}" must not be in data (writable buckets never change schema, contracts §5.4)`);
  }
  return cfg;
}

const paths = (root, cfg) => ({
  schema: join(root, 'valence', 'bridge.schema.json'),
  keyring: join(root, 'valence', 'keyring.json'),
  baseline: join(root, '.valence', 'baseline.json'),
  ota: join(root, '.valence', 'dist-ota', cfg.appId),
  dart: join(root, cfg.host.dir, 'lib', 'valence', 'bridge.g.dart'),
  dartConfig: join(root, cfg.host.dir, 'lib', 'valence', 'config.g.dart'),
  builtin: join(root, cfg.host.dir, 'assets', 'valence', 'builtin'),
  seed: join(root, cfg.host.dir, 'assets', 'valence', 'seed.db'),
  ts: join(root, cfg.web.lib, 'bridge.g.ts'),
});

const readBaseline = (p) => (existsSync(p.baseline) ? readJson(p.baseline) : { storeSeq: 0, storeRoutes: null, storeSchema: null, lastSeq: 0, floor: 0 });

// ---------- keys ----------

const rawPublicKey = (key) => key.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');
const publicKeyFromRaw = (b64) => createPublicKey({ key: Buffer.concat([SPKI_ED25519, Buffer.from(b64, 'base64')]), format: 'der', type: 'spki' });

export function keygen({ root, cfg, keyDir = join(homedir(), '.valence', 'keys') }) {
  if (insideGit(keyDir)) throw new Error(`refusing to write a private key inside a git work tree: ${keyDir}`);
  const p = paths(root, cfg);
  const ring = existsSync(p.keyring) ? readJson(p.keyring) : {};
  if (Object.hasOwn(ring, cfg.keyId)) throw new Error(`keyId "${cfg.keyId}" is already in keyring.json. Get its private key from your secret store, or set a new keyId to rotate.`);
  const file = join(keyDir, `${cfg.appId}.${cfg.keyId}.pem`);
  if (existsSync(file)) throw new Error(`key already exists: ${file}. Set a new keyId to rotate.`);
  const { privateKey, publicKey } = generateKeyPairSync('ed25519');
  mkdirSync(keyDir, { recursive: true });
  writeFileSync(file, privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });
  ring[cfg.keyId] = rawPublicKey(publicKey);
  writeJson(p.keyring, ring);
  return { file, publicKey: ring[cfg.keyId] };
}

export function loadSigningKey(cfg, keyring, keyPath) {
  if (process.env.VALENCE_SIGNING_KEY && keyPath) throw new Error('both VALENCE_SIGNING_KEY and --key are set; pass one');
  let key;
  if (process.env.VALENCE_SIGNING_KEY) key = createPrivateKey(process.env.VALENCE_SIGNING_KEY);
  else {
    const file = keyPath ?? join(homedir(), '.valence', 'keys', `${cfg.appId}.${cfg.keyId}.pem`);
    if (!existsSync(file)) throw new Error(`signing key not found: ${file}. Run "valence keygen" or set VALENCE_SIGNING_KEY.`);
    key = createPrivateKey(readFileSync(file));
  }
  if (!Object.hasOwn(keyring, cfg.keyId)) throw new Error(`keyId "${cfg.keyId}" is not in keyring.json`);
  if (rawPublicKey(createPublicKey(key)) !== keyring[cfg.keyId]) throw new Error(`the signing key does not match keyring.json["${cfg.keyId}"]`);
  return key;
}

// ---------- bundle ----------

const PAGE_EXT = new Set(['.astro', '.md', '.mdx', '.html', '.tsx', '.jsx', '.ts', '.js']);

// Returns {routes, source}. source is how we got them: 'declared' (config only), 'both' (config plus a scan),
// 'scan' (a routes directory) or 'none'. A client-side-routed SPA has no routes directory, so without 'declared' the
// store route check has nothing to compare and would sit there looking active while warning about nothing (§7).
// Declared routes are unioned with a scan rather than replacing it, so adding them can never switch a working scan off.
function declaredRoutes(declared) {
  const bad = (why) => new Error(`web.declaredRoutes ${why}. It is a non-empty array of single-segment top-level paths, for example ["/", "/shelf"]`);
  if (!Array.isArray(declared)) throw bad('must be an array');
  if (declared.length === 0) throw bad('must not be empty; use ["/"] to claim the app has exactly one route');
  return declared.map((r) => {
    if (typeof r !== 'string' || !r.startsWith('/')) throw bad(`entries must be strings starting with "/", got ${JSON.stringify(r)}`);
    const t = r.replace(/\/+$/, '') || '/'; // "/shelf/" and "/shelf" are the same route; don't warn about the edit
    // Scanning only ever yields one segment, so a deeper path would diff against something that can never appear.
    if (t !== '/' && t.slice(1).includes('/')) throw bad(`entries are top-level routes with one segment, got "${r}"`);
    return t;
  });
}

function listRoutes(root, cfg) {
  const declared = cfg.web.declaredRoutes === undefined ? null : declaredRoutes(cfg.web.declaredRoutes);
  const dir = cfg.web.routes && resolve(root, cfg.web.routes);
  const out = new Set(['/', ...(declared ?? [])]);
  if (!dir || !existsSync(dir)) return { routes: [...out].sort(), source: declared ? 'declared' : 'none' };
  // SvelteKit (+page/+layout) and Next app router (page/layout) route by directory only; files beside them are components.
  const dirsOnly = readdirSync(dir, { recursive: true }).some((f) => /^\+?(page|layout)\./.test(String(f).split(/[\\/]/).pop()));
  const scan = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      if (/^[+_.]/.test(e.name)) continue; // +page.svelte, _app.tsx, .DS_Store
      if (e.isDirectory()) {
        // SvelteKit (group) and [[optional]] segments: the real top-level routes are inside.
        if (/^\(.*\)$|^\[\[.*\]\]$/.test(e.name)) scan(join(d, e.name));
        else out.add('/' + e.name);
      } else if (!dirsOnly && PAGE_EXT.has(extname(e.name).toLowerCase())) {
        const name = e.name.slice(0, e.name.length - extname(e.name).length);
        out.add(name === 'index' ? '/' : '/' + name); // Astro / Next pages-router route files
      }
    }
  };
  scan(dir);
  return { routes: [...out].sort(), source: declared ? 'both' : 'scan' };
}

// Inline <script> hashes for the entry page, so the host can send a strict CSP header (contracts §7).
function buildCsp(html, cfg, wasm) {
  // Browsers hash the parsed text, and the HTML parser turns CRLF and CR into LF first.
  const hashes = [...html.matchAll(/<script\b(?![^>]*\bsrc\s*=)[^>]*>([\s\S]*?)<\/script>/gi)]
    .map(([, body]) => `'sha256-${createHash('sha256').update(body.replace(/\r\n?/g, '\n')).digest('base64')}'`);
  const origins = [cfg.sync?.base, ...(cfg.web.connect ?? [])].filter(Boolean).map((u) => new URL(u).origin);
  return [
    "default-src 'self'",
    ["script-src 'self'", ...(wasm ? ["'wasm-unsafe-eval'"] : []), ...hashes].join(' '),
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob: https:",
    "font-src 'self' data:",
    ["connect-src 'self'", ...new Set(origins)].join(' '),
    "frame-src 'none'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join('; ');
}

// §3's SPA fallback answers the entry page at any depth, so a relative URL in it resolves against the request path
// instead of the origin root. Absolute, scheme-relative, root-relative, fragment and query refs are all fine, and an
// absolute <base href> re-roots everything so there is nothing to report. Script and style bodies are skipped: a URL
// inside a template literal is not a reference the browser resolves.
const relativeAssetRefs = (html) => {
  if (/<base\b[^>]*\bhref\s*=\s*["']?\/(?!\/)/i.test(html)) return [];
  // Keep the opening tag (its own src/href is a real reference) and drop only the body.
  const markup = html.replace(/(<(script|style)\b[^>]*>)[\s\S]*?<\/\2\s*>/gi, '$1');
  return [
    ...new Set(
      [...markup.matchAll(/\b(?:src|srcset|href)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s">]+))/gi)]
        .flatMap((m) => (m[1] ?? m[2] ?? m[3] ?? '').split(','))
        .map((u) => u.trim().split(/\s+/)[0])
        .filter((u) => u !== '' && !/^(?:[a-z][a-z0-9+.-]*:|\/\/|\/|#|\?)/i.test(u)),
    ),
  ];
};

// store: this built-in bundle goes to the stores, so its routes and bridge schema become the baseline (implies builtin).
export function bundle({ root, cfg, key, builtin = false, store = false, rebaseline = false, floor, requiresBridge, urgent = false, now = Date.now() }) {
  builtin ||= store;
  const p = paths(root, cfg);
  const src = resolve(root, cfg.web.out);
  if (!existsSync(src)) throw new Error(`web build output not found: ${src}. Build the web app first.`);
  const entry = cfg.web.entry ?? 'index.html';
  const baseline = readBaseline(p);
  const schema = readJson(p.schema);
  const keyring = readJson(p.keyring);
  const warnings = [];
  // `--store` is the only thing that writes `storeSchema`, and `storeSchema` is the only thing `codegen`'s
  // additive-only guard checks against. So a second `--store` run silently rewrites the record of what the stores
  // reviewed, and a change `codegen` had just refused then passes — with nothing left to show it was ever refused.
  // Check the new schema against the recorded one here too, with the same rules, and make losing the record explicit.
  if (store && baseline.storeSchema) {
    // The baseline is about to say this build is what the stores reviewed, which silences the OTA warning below for
    // every phone still on the build before it. Say that number out loud while it is still recorded.
    if (schema.version > baseline.storeSchema.version) {
      warnings.push(
        `this store build takes the bridge from ${baseline.storeSchema.version} to ${schema.version}. Until it is live for users, every OTA release has to be built with --requires-bridge ${baseline.storeSchema.version}: the phones in the field still run bridge ${baseline.storeSchema.version}, and the baseline is about to record ${schema.version}, so nothing will warn you again.`,
      );
    }
    if (rebaseline) {
      warnings.push(
        `--rebaseline overwrote the recorded store schema (version ${baseline.storeSchema.version} -> ${schema.version}). The additive-only guard now compares against this build, not against what the stores reviewed. Only correct if nothing from the old baseline is installed anywhere.`,
      );
    } else {
      assertAdditive(baseline.storeSchema, schema);
    }
  }
  const files = {};
  const blobs = new Map();
  for (const rel of walk(src)) {
    if (rel.split('/').some((seg) => NATIVE.has(extname(seg).toLowerCase()))) {
      throw new Error(`native code is not allowed in an OTA bundle: ${rel}`);
    }
    // §3: the loopback server answers /_host/ itself, before the manifest lookup, so a bundle file there is unreachable.
    if (RESERVED_PREFIX(rel)) {
      throw new Error(`_host/ is reserved for the host's own routes (contracts §3), so the server would never serve this file: ${rel}`);
    }
    if (rel.toLowerCase().endsWith('.wasm')) warnings.push(`${rel}: .wasm is allowed (runs in the webview) but reviewers should know it is there`);
    const buf = readFileSync(join(src, rel));
    const h = sha256(buf);
    files[rel] = { h, n: buf.length };
    blobs.set(h, buf);
  }
  if (!files[entry]) throw new Error(`entry ${entry} is missing from ${src}`);
  // §3: the SPA fallback serves this page at any depth, so a relative asset URL in it 404s on every nested route.
  const relRefs = relativeAssetRefs(blobs.get(files[entry].h).toString('utf8'));
  if (relRefs.length) {
    const shown = relRefs.slice(0, 3).join(', ') + (relRefs.length > 3 ? ', …' : '');
    warnings.push(
      `${entry} references ${relRefs.length} asset${relRefs.length > 1 ? 's' : ''} by a relative URL (${shown}). The SPA fallback serves the entry page at any depth (contracts §3), so the webview resolves those against the request path and 404s them: a reload or a back gesture on a nested route gives a blank screen with nothing in the log. Build so the output references assets from the origin root — base: '/' in Vite; in SvelteKit it is the setting that controls relative asset paths, not the deployment subpath, so check your version's docs. The host owns the whole origin, so a root-relative URL is always right.`,
    );
  }

  // §3: the host makes a bundle file's bytes revalidate by serving them no-cache with the hash as an
  // ETag. A service worker answering from Cache Storage is never asked, so a precache-first build puts
  // the stale-bundle hole straight back: the new bundle activates, the old page renders, and it calls
  // ready() so the trial commits. Only the registration is detectable from the output, so warn on it.
  const sw = [...blobs.keys()].some((h) => SERVICE_WORKER_RE.test(blobs.get(h).toString('latin1')));
  if (sw) {
    warnings.push(
      `this build registers a service worker. A service worker serves the page from Cache Storage without asking the host's server, which revalidates every bundle file against its hash (contracts §3) — so a precaching worker can answer a new release with the previous one's code, and the trial still commits because the old page calls ready(). Inside the app you do not need one: the bundle is already on the device and served locally. Register it only when inHost() is false, or drop it from the build the bundle is cut from.`,
    );
  }

  const { routes, source } = listRoutes(root, cfg);
  if (source === 'none') {
    const why = cfg.web.routes ? `web.routes is set to "${cfg.web.routes}", which does not exist` : 'web.routes is unset';
    warnings.push(`the new-top-level-route check is INACTIVE: ${why} and nothing is declared, so every bundle reports just ["/"] and an OTA could add a whole feature area unnoticed (DPLA 3.3.1(B)(a)). An app that routes in JavaScript has no routes directory to scan: list its top-level routes as "declaredRoutes" under "web" in valence.config.json.`);
  } else if (source === 'scan' && routes.length <= 1) {
    // Scanning worked and found one route. That is legitimate for a genuinely single-screen app, so this is a
    // confirmation prompt, not the INACTIVE warning: the check is running, it just has nothing to diff yet.
    warnings.push(`scanning "${cfg.web.routes}" found only "/". If the app really has one top-level route, nothing to do; if it routes in JavaScript, the new-route check cannot see those routes and you should list them as "declaredRoutes" under "web" in valence.config.json.`);
  }
  if (!builtin && baseline.storeRoutes) {
    for (const r of routes) {
      if (!baseline.storeRoutes.includes(r)) warnings.push(`new top-level route since the last store build: ${r}. OTA must not change the app's purpose (DPLA 3.3.1(B)(a)); consider shipping it with a store update.`);
    }
  }

  if (floor !== undefined && floor < (baseline.floor ?? 0)) throw new Error(`--floor ${floor} is below the current floor ${baseline.floor}; the floor only goes up`);
  // The floor applies to the built-in bundle too (§2.2), and the built-in bundle is the one artifact every
  // device is guaranteed to have — a wiped or offline phone's last resort, and the only code a store review
  // ever saw. A floor above it therefore retires it *from the client side*, with no store release: §2.4's
  // ladder is left with `current` and nothing underneath, so if the floor-raising bundle itself later fails
  // a check, recovery is a full store review — exactly what OTA exists to avoid. One unreviewed OTA should
  // not be able to do that silently, and `baseline.storeSeq` is in the file the CLI is already writing.
  // A `--store` build is its own fallback, so its own seq is the ceiling, which §2.3's check below enforces.
  const storeSeq = baseline.storeSeq ?? 0;
  const effectiveFloor = floor ?? baseline.floor ?? 0;
  // `--builtin` is exempt with `--store`: that bundle *is* the fallback being produced, and the
  // `floor > seq` check below already keeps it runnable. Only an OTA can retire a fallback it is not.
  if (!store && !builtin && storeSeq > 0 && effectiveFloor > storeSeq) {
    const how = `Raise it to at most ${storeSeq} to keep the store build runnable, or ship a store build above ${effectiveFloor} first and raise the floor after it is live.`;
    // Refuse only an actual *raise*. Restating a floor that is already above `storeSeq` — which a pipeline
    // passing `--floor $FLOOR` every time does — changes nothing, and refusing it deadlocked against the
    // "the floor only goes up" check above: every value at or below the carried floor was refused there,
    // and every value above it refused here, with no buildable number in between.
    if (floor !== undefined && floor > (baseline.floor ?? 0)) {
      throw new Error(
        `--floor ${floor} is above the store build's seq ${storeSeq}, so every device would refuse its own built-in bundle at check 4 and have no fallback below this release. ${how}`,
      );
    }
    // Carried forward from a project that raised the floor before this check existed. Not refused, because
    // that would make every later release unbuildable, but it is the same device state and must be said.
    warnings.push(
      `the floor carried forward (${effectiveFloor}) is above the store build's seq ${storeSeq}, so devices refuse their own built-in bundle and have no fallback below "current". ${how}`,
    );
  }
  // requires.bridge is a one-way door like floor: check 5 makes every host below it refuse this bundle *and* every
  // later release, because they inherit the same default. has() exists so one bundle can serve old and new hosts, so
  // say so when the default would undo it.
  const bridge = requiresBridge ?? (builtin ? schema.version : baseline.storeSchema?.version ?? schema.version);
  // A built-in bundle is the one bundle its own host cannot decline: check 5 refuses it on first launch and a fresh
  // install has no `current` to fall back to, so the app has nothing to paint (§2.4 step 1). Compare against the
  // *generated* constant, not the schema file: a schema bumped without a codegen run is the common way to get here.
  if (builtin) {
    const generated = existsSync(p.dart) ? /\bconst hostBridgeVersion = (\d+);/.exec(readFileSync(p.dart, 'utf8'))?.[1] : undefined;
    const hostBridge = generated === undefined ? schema.version : Number(generated);
    if (bridge > hostBridge) {
      throw new Error(
        `requires.bridge would be ${bridge}, above the ${generated === undefined ? `schema version ${hostBridge}` : `hostBridgeVersion ${hostBridge} in ${relative(root, p.dart)}`}, so this host refuses its own built-in bundle at check 5 and a fresh install has nothing to serve. ${generated !== undefined && hostBridge < schema.version ? 'Run codegen: the generated constant is behind the schema.' : 'Bump the schema, or drop --requires-bridge for a built-in build.'}`,
      );
    }
  }
  const storeBridge = baseline.storeSchema?.version;
  if (!builtin && storeBridge !== undefined && bridge > storeBridge) {
    warnings.push(
      `requires.bridge is ${bridge}, above the bridge version of the last store build (${storeBridge}). Check 5 means every host from that build refuses this bundle — and refuses every later OTA release too, including a copy fix or a security patch, because they inherit the same default until someone passes --requires-bridge on each build. If the newer calls are guarded with has(), build with --requires-bridge ${storeBridge}. The baseline records only the newest store build, so if an older one is still in the field, pin to that one instead.`,
    );
  }
  // Pinning down is the other half, and it is silent without this: check 5 passes on the older host, the bundle loads,
  // and an unguarded call to a newer method throws E_UNSUPPORTED in the field with no build-time or store signal.
  if (bridge < schema.version) {
    const above = Object.entries(schema.methods ?? {})
      .filter(([, d]) => (d?.since ?? 1) > bridge)
      .map(([n]) => n);
    if (above.length) {
      warnings.push(
        `requires.bridge is pinned to ${bridge}, below the schema version ${schema.version}, so ${above.length} method${above.length > 1 ? 's' : ''} need a newer host than this bundle asks for: ${above.join(', ')}. Every call to them must be behind has(), or it throws E_UNSUPPORTED on an older host and the feature is simply dead there.`,
      );
    }
  }
  const manifestsDir = join(p.ota, 'manifests');
  const localSeqs = existsSync(manifestsDir) ? readdirSync(manifestsDir).filter((f) => /^\d+\.json$/.test(f)).map((f) => parseInt(f, 10)) : [];
  // Monotonic even with a slow clock or two builds in one second (commit .valence/baseline.json after each release).
  const seq = Math.max(Math.floor(now / 1000), (baseline.lastSeq ?? 0) + 1, (baseline.storeSeq ?? 0) + 1, ...localSeqs.map((s) => s + 1));
  const manifest = {
    format: 1,
    appId: cfg.appId,
    seq,
    version: `${new Date(now).toISOString().slice(0, 10)}+${seq}`,
    floor: floor ?? baseline.floor ?? 0,
    requires: { bridge, data: cfg.data ?? {} },
    entry,
    csp: buildCsp(blobs.get(files[entry].h).toString('utf8'), cfg, Object.keys(files).some((f) => f.toLowerCase().endsWith('.wasm'))),
    urgent,
    routes,
    files,
    createdAt: new Date(now).toISOString(),
    keyId: cfg.keyId,
  };
  if (manifest.floor > seq) throw new Error(`floor ${manifest.floor} is above this bundle's seq ${seq}`);
  const bytes = Buffer.from(JSON.stringify(manifest, null, 2) + '\n');
  const sig = sign(null, bytes, key).toString('base64');

  let manifestPath;
  let filesDir;
  if (builtin) {
    rmSync(p.builtin, { recursive: true, force: true });
    manifestPath = join(p.builtin, 'manifest.json');
    filesDir = join(p.builtin, 'files');
  } else {
    manifestPath = join(manifestsDir, `${seq}.json`);
    filesDir = join(p.ota, 'files');
  }
  for (const [h, buf] of blobs) if (!existsSync(join(filesDir, h))) writeFile(join(filesDir, h), buf);
  writeFile(manifestPath, bytes);
  writeFile(manifestPath + '.sig', sig); // no trailing newline: hosts base64-decode the file as is
  verifyBundle({ manifestPath, filesDir, keyring, appId: cfg.appId });

  const next = { ...baseline, lastSeq: seq, floor: manifest.floor };
  let recorded;
  if (store) {
    Object.assign(next, { storeSeq: seq, storeRoutes: routes, storeSchema: schema });
    // Say what the baseline now claims the stores have reviewed. It is the one file nobody can reconstruct later.
    const added = [];
    for (const kind of ['methods', 'events', 'types']) {
      for (const name of Object.keys(schema[kind] ?? {})) {
        if (!Object.hasOwn(baseline.storeSchema?.[kind] ?? {}, name)) added.push(`+ ${kind.slice(0, -1)} ${name}`);
      }
    }
    recorded = { bridge: schema.version, routes, added };
    // A store build always outranks the OTA release staged on top of the previous one (§2.4 step 1), so the channel
    // now points at a seq no device will ever install again, and an update-path test becomes a test that there is no
    // update. Release again after the store build; never before it.
    const channelsDir = join(p.ota, 'channels');
    if (existsSync(channelsDir)) {
      for (const f of readdirSync(channelsDir).filter((f) => f.endsWith('.json'))) {
        const stale = readJson(join(channelsDir, f)).seq;
        if (typeof stale === 'number' && stale < seq) {
          warnings.push(
            `channel "${f.slice(0, -5)}" points at ${stale}, below this store build's seq ${seq}. A newer built-in bundle wins, so no device will take that release again: cut the OTA release after the store build, not before it.`,
          );
        }
      }
    }
  }
  writeJson(p.baseline, next);
  return { manifest, manifestPath, filesDir, warnings, recorded };
}

// §3 reserves /_host/ for the host's own routes, so a bundle file there is unreachable and would be shadowed by them.
// Enforced in bundle (at build) and in verifyBundle (so an older tool holding the key cannot smuggle one past check 6).
const RESERVED_PREFIX = (rel) => rel === '_host' || rel.startsWith('_host/');

const SAFE_PATH = (rel) => typeof rel === 'string' && rel !== '' && !rel.startsWith('/') && !/[\\\0]/.test(rel) && !rel.split('/').some((s) => s === '' || s === '.' || s === '..');

export function verifyBundle({ manifestPath, filesDir, keyring, appId }) {
  const bytes = readFileSync(manifestPath);
  const sig = Buffer.from(readFileSync(manifestPath + '.sig', 'utf8').trim(), 'base64');
  const keyId = JSON.parse(bytes).keyId; // read only to pick the key; trusted after verify()
  if (typeof keyId !== 'string' || !Object.hasOwn(keyring, keyId)) throw new Error(`unknown keyId ${keyId}`);
  if (!verify(null, bytes, publicKeyFromRaw(keyring[keyId]), sig)) throw new Error('bad manifest signature');
  const m = JSON.parse(bytes);
  if (m.format !== 1) throw new Error(`unsupported manifest format ${m.format}`);
  if (appId && m.appId !== appId) throw new Error(`manifest is for ${m.appId}, not ${appId}`);
  if (!Number.isInteger(m.seq) || !Number.isInteger(m.floor) || m.floor > m.seq) throw new Error('bad seq/floor');
  if (!Object.hasOwn(m.files, m.entry)) throw new Error(`entry ${m.entry} is not in files`);
  // Validate every entry before looking at the directory, so a malformed manifest is still named as malformed.
  for (const [rel, f] of Object.entries(m.files)) {
    if (!SAFE_PATH(rel) || RESERVED_PREFIX(rel)) throw new Error(`unsafe path in manifest: ${rel}`);
    if (!HASH_RE.test(f.h) || !Number.isInteger(f.n) || f.n < 0) throw new Error(`bad file entry for ${rel}`);
  }
  // A wrong --files level otherwise reports the first entry as "missing", which looks exactly like the corrupted
  // bundle verify exists to detect. If nothing resolves at all, the directory is the problem, not the bundle.
  const hashes = Object.values(m.files);
  if (hashes.length && !hashes.some((f) => existsSync(join(filesDir, f.h)))) {
    const nested = join(filesDir, 'files');
    throw new Error(`no manifest files found under ${filesDir}${existsSync(nested) ? `; --files wants the content-addressed files/ directory, so try ${nested}` : ''}`);
  }
  for (const [rel, f] of Object.entries(m.files)) {
    const file = join(filesDir, f.h);
    if (!existsSync(file)) throw new Error(`missing file ${rel} (${f.h})`);
    const buf = readFileSync(file);
    if (buf.length !== f.n || sha256(buf) !== f.h) throw new Error(`hash mismatch for ${rel}`);
  }
  return m;
}

export function pointer({ root, cfg, channel, seq, rollout }) {
  if (!/^[\w-]+$/.test(channel)) throw new Error(`bad channel name ${channel}`);
  const p = paths(root, cfg);
  if (seq === undefined) {
    const dir = join(p.ota, 'manifests');
    const seqs = existsSync(dir) ? readdirSync(dir).filter((f) => /^\d+\.json$/.test(f)).map((f) => parseInt(f, 10)) : [];
    if (!seqs.length) throw new Error('no manifests in dist-ota; pass --seq');
    seq = Math.max(...seqs);
  }
  const file = join(p.ota, 'channels', `${channel}.json`);
  writeJson(file, { seq, rollout });
  return { file, seq, rollout };
}

// ---------- seed ----------

export async function seed({ root, cfg, from }) {
  const { DatabaseSync } = await import('node:sqlite');
  const out = paths(root, cfg).seed;
  const tmp = `${out}.tmp-${process.pid}`;
  mkdirSync(dirname(out), { recursive: true });
  rmSync(tmp, { force: true });
  const db = new DatabaseSync(tmp);
  const counts = {};
  const seeded = new Set();
  let ok = false;
  try {
    db.exec(SEED_SQL);
    const insert = db.prepare('INSERT INTO kv (bucket, schema, key, value, usn, deleted) VALUES (?, ?, ?, ?, ?, ?)');
    const setBucket = db.prepare('INSERT INTO bucket (name, schema, max_usn) VALUES (?, ?, ?)');
    db.exec('BEGIN');
    for (const f of readdirSync(from).filter((f) => f.endsWith('.json')).sort()) {
      const versioned = /^(.*)\.v([1-9][0-9]*)\.json$/.exec(f);
      const bucket = versioned ? versioned[1] : f.slice(0, -5);
      const { schema, rows } = readJson(join(from, f));
      int(schema, `${f}: schema`, 1);
      if (versioned && Number(versioned[2]) !== schema) throw new Error(`${f}: filename schema does not match payload`);
      if (cfg.data?.[bucket] !== schema && !(cfg.seedSchemas?.[bucket] ?? []).includes(schema)) {
        throw new Error(`${f}: schema ${schema} does not match a declared schema for data.${bucket}`);
      }
      const pair = `${bucket}:${schema}`;
      if (seeded.has(pair)) throw new Error(`${f}: duplicate seed pair ${pair}`);
      seeded.add(pair);
      if (!Array.isArray(rows)) throw new Error(`${f}: rows must be an array`);
      let max = 0;
      for (const r of rows) {
        if (typeof r.k !== 'string') throw new Error(`${f}: every row needs a string "k" (rows look like {k, v, u, d})`);
        const u = int(r.u, `${f}: row ${r.k} usn`, 1);
        insert.run(bucket, schema, r.k, JSON.stringify(r.v ?? null), u, r.d ? 1 : 0);
        max = Math.max(max, u);
      }
      setBucket.run(bucket, schema, max);
      counts[bucket] = (counts[bucket] ?? 0) + rows.length;
    }
    db.exec('COMMIT');
    ok = true;
  } finally {
    db.close(); // closing discards an uncommitted transaction
    if (!ok) rmSync(tmp, { force: true }); // the previous seed.db stays untouched on failure
  }
  rmSync(out, { force: true });
  renameSync(tmp, out);
  const unseeded = Object.keys(cfg.data ?? {}).filter((b) => !seeded.has(`${b}:${cfg.data[b]}`));
  const warnings = unseeded.map((b) => `data bucket "${b}" has no seed file; it is empty until the first online sync (offline first launch, contracts §5.2)`);
  return { out, counts, warnings };
}

// ---------- codegen ----------

export function parseSchema(schema) {
  const version = int(schema.version, 'schema.version', 1);
  const types = schema.types ?? {};
  const parseType = (t, where, allowVoid = false) => {
    if (typeof t !== 'string') throw new Error(`${where}: type must be a string`);
    let base = t;
    let nullable = false;
    let list = false;
    if (base.endsWith('?')) [base, nullable] = [base.slice(0, -1), true];
    if (base.endsWith('[]')) [base, list] = [base.slice(0, -2), true];
    if (!PRIMS.has(base) && !Object.hasOwn(types, base)) throw new Error(`${where}: unknown type "${t}"`);
    if (base === 'void' && (!allowVoid || list || nullable)) throw new Error(`${where}: void is only allowed as a bare return type`);
    return { base, list, nullable };
  };
  const fields = (obj, where) =>
    Object.entries(obj ?? {}).map(([name, t]) => {
      if (!/^[a-z][a-zA-Z0-9]*$/.test(name) || DART_RESERVED.has(name)) throw new Error(`${where}: bad or reserved field name "${name}"`);
      return { name, type: parseType(t, `${where}.${name}`) };
    });
  const named = (name, kind) => {
    if (!/^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)+$/.test(name)) throw new Error(`bad ${kind} name "${name}" (use area.action)`);
    if (DART_RESERVED.has(camel(name))) throw new Error(`${kind} "${name}" becomes the reserved Dart name "${camel(name)}"`);
  };
  for (const name of Object.keys(types)) {
    if (!/^[A-Z][a-zA-Z0-9]*$/.test(name) || RESERVED_TYPES.has(name)) throw new Error(`bad or reserved type name "${name}"`);
  }
  const methods = Object.entries(schema.methods ?? {}).map(([name, m]) => {
    named(name, 'method');
    return { name, since: int(m.since, `${name}.since`, 1, version), params: fields(m.params, name), returns: parseType(m.returns, `${name}.returns`, true) };
  });
  const events = Object.entries(schema.events ?? {}).map(([name, e]) => {
    named(name, 'event');
    return { name, since: int(e.since, `${name}.since`, 1, version), payload: fields(e.payload, name) };
  });
  const typeList = Object.entries(types).map(([name, f]) => ({ name, fields: fields(f, name) }));
  for (const core of CORE_METHODS) if (!methods.some((m) => m.name === core)) throw new Error(`schema must define ${core}`);
  // Methods and events share one namespace, because `has()` takes either kind of name and resolves it
  // against one table (§4.3): a name declared as both would answer for whichever won, so `has()` could
  // say false for an event the host does emit. One pass therefore catches the cross-kind collision as
  // well as the two-names-one-identifier collision inside each kind.
  const seen = new Map();
  for (const x of [...methods.map((m) => ({ ...m, kind: 'method' })), ...events.map((e) => ({ ...e, kind: 'event' }))]) {
    const c = camel(x.name);
    const prev = seen.get(c);
    if (prev) {
      throw new Error(
        prev.name === x.name
          ? `"${x.name}" is declared as both a method and an event; has() resolves one name to one answer, so pick one`
          : `${x.kind} "${x.name}" and ${prev.kind} "${prev.name}" both become "${c}"`,
      );
    }
    seen.set(c, x);
  }
  const classNames = new Set(typeList.map((t) => t.name));
  for (const m of methods) if (classNames.has(pascal(m.name) + 'Params')) throw new Error(`${m.name}: params class name collides with a type`);
  return { version, types: typeList, methods, events };
}

// Which optional fields each built-in's returned type may gain, keyed by the type name this app gave it.
// The names and types come from BUILTINS, so this is not a general escape hatch: it is exactly the set of
// fields the runtime itself added, on exactly the type the built-in returns.
function builtinOptionalFields(schema) {
  const byType = {};
  for (const [name, want] of Object.entries(BUILTINS)) {
    const optional = typeof want.returns === 'string' ? null : want.returns.optional;
    const declared = schema.methods?.[name]?.returns;
    if (!optional || typeof declared !== 'string') continue;
    byType[declared.replace(/[[\]?]/g, '')] = { ...byType[declared.replace(/[[\]?]/g, '')], ...optional };
  }
  return byType;
}

// True when `now` is `was` plus nothing but fields from `allowed`, each at the type `allowed` names.
// Every shipped field must still be there, unchanged, at its old type.
function isBuiltinGrowth(was, now, allowed) {
  if (!allowed || !now || typeof now !== 'object') return false;
  for (const [f, t] of Object.entries(was)) if (now[f] !== t) return false;
  for (const [f, t] of Object.entries(now)) {
    if (Object.hasOwn(was, f)) continue;
    if (allowed[f] !== t) return false;
  }
  return true;
}

// True when a built-in method's definition is its shipped one plus nothing but optional params from
// `allowed`. Everything other than `params` must be identical — compared wholesale rather than by naming
// `since` and `returns`, so a method-level key the IDL gains later is not silently exempt from the guard.
function isBuiltinParamGrowth(was, now, allowed) {
  if (!allowed || !now || typeof now !== 'object') return false;
  const withoutParams = (d) => Object.fromEntries(Object.entries(d).filter(([k]) => k !== 'params'));
  if (canonical(withoutParams(was)) !== canonical(withoutParams(now))) return false;
  return isBuiltinGrowth(was.params ?? {}, now.params ?? {}, allowed);
}

// The schema is additive only once a store build has shipped it (contracts §4.1).
export function assertAdditive(shipped, current) {
  if (!shipped) return;
  if (current.version < shipped.version) throw new Error(`schema version went down: ${current.version} < shipped ${shipped.version}`);
  const grows = builtinOptionalFields(current);
  for (const kind of ['methods', 'events', 'types']) {
    for (const [name, def] of Object.entries(shipped[kind] ?? {})) {
      if (!Object.hasOwn(current[kind] ?? {}, name)) throw new Error(`${kind} "${name}" shipped in a store build and cannot be removed`);
      if (canonical(def) === canonical(current[kind][name])) continue;
      // A built-in's returned type may gain the fields the runtime added to it, and nothing else. Without
      // this the additive-only guard refuses the very upgrade §4.3 tells an adopter to make, and the only
      // way through would be --rebaseline, which overwrites the schema the stores reviewed.
      if (kind === 'types' && isBuiltinGrowth(def, current.types[name], grows[name])) continue;
      // The same allowance for a built-in's *params*. `since` and `returns` must be untouched; only the
      // optional params the runtime declared may appear. Without it the additive guard refuses the upgrade
      // §4.3 tells an adopter to make, and --rebaseline — which overwrites the schema the stores reviewed —
      // would be the only way through.
      // A grown param must come with a version bump, because a param has no `since` of its own: the only
      // signal a page can read is a *sibling* method or event that arrived in the same version, and a
      // sibling needs a version to arrive at. Without this, an app could add `data.list.after` at the
      // shipped version, leaving has() unable to distinguish this host from the store build that answers
      // `E_PARAMS`. Note app.info().bridge is no help: it is this app's own schema version (§4.2).
      if (kind === 'methods' && isBuiltinParamGrowth(def, current.methods[name], BUILTINS[name]?.optionalParams)) {
        if (current.version > shipped.version) continue;
        throw new Error(
          `"${name}" gained the param ${Object.keys(current.methods[name].params ?? {}).filter((p) => !Object.hasOwn(def.params ?? {}, p)).map((p) => `"${p}"`).join(', ')}, which needs "version" above the shipped ${shipped.version}. A param has no "since", so a page can only gate it on a sibling method or event at the new version — has("data.count") for data.list's "after".`,
        );
      }
      throw new Error(`${kind} "${name}" shipped in a store build and cannot change; add a new one (for example "${name}.v2" or "${name}V2")`);
    }
  }
  // New methods/events must be newer than every shipped host, or has() lies on old hosts and they get E_UNKNOWN.
  for (const kind of ['methods', 'events']) {
    for (const [name, def] of Object.entries(current[kind] ?? {})) {
      if (!Object.hasOwn(shipped[kind] ?? {}, name) && !(def.since > shipped.version)) {
        throw new Error(`${kind} "${name}" is new since the store build, so it needs since > ${shipped.version} (and version bumped to at least that)`);
      }
    }
  }
}

const TS_PRIM = { string: 'string', int: 'number', num: 'number', bool: 'boolean', json: 'Json', void: 'void' };
const DART_PRIM = { string: 'String', int: 'int', num: 'num', bool: 'bool', json: 'Object?', void: 'void' };

function tsType({ base, list, nullable }) {
  let t = TS_PRIM[base] ?? base;
  if (list) t += '[]';
  return nullable ? `${t} | null` : t;
}

function tsFields(fs, indent) {
  if (!fs.length) return 'Record<string, never>';
  const pad = ' '.repeat(indent);
  const lines = fs.map((f) => `${pad}  ${f.name}${f.type.nullable ? '?' : ''}: ${tsType(f.type)};`);
  return `{\n${lines.join('\n')}\n${pad}}`;
}

export function genTs(s) {
  const o = ['// GENERATED by valence codegen from valence/bridge.schema.json. Do not edit.', ''];
  // The runtime lives in @getvalence/bridge, so a fix to the message cap, the nonce or the shim routing
  // arrives with an npm update instead of being hand-applied to every app's copy.
  o.push("import { createBridge } from '@getvalence/bridge';", '');
  o.push("import type { Json, Shim } from '@getvalence/bridge';", '');
  o.push("export { BridgeError, MAX_MESSAGE_BYTES, inHost } from '@getvalence/bridge';", '');
  o.push('export type { Json };', '');
  o.push(`export const BRIDGE_VERSION = ${s.version};`, '');
  for (const t of s.types) o.push(t.fields.length ? `export interface ${t.name} ${tsFields(t.fields, 0)}` : `export type ${t.name} = Record<string, never>;`, '');
  o.push('export interface Methods {');
  for (const m of s.methods) o.push(`  '${m.name}': { params: ${tsFields(m.params, 2)}; returns: ${tsType(m.returns)} };`);
  o.push('}', '', 'export interface Events {');
  for (const e of s.events) o.push(`  '${e.name}': ${tsFields(e.payload, 2)};`);
  o.push('}', '');
  o.push('export const METHOD_SINCE: { readonly [M in keyof Methods]: number } = {');
  for (const m of s.methods) o.push(`  '${m.name}': ${m.since},`);
  o.push('};', '', 'export const EVENT_SINCE: { readonly [E in keyof Events]: number } = {');
  for (const e of s.events) o.push(`  '${e.name}': ${e.since},`);
  o.push('};', '');
  o.push('/** Browser fallbacks for this app, so the same build also runs as the website. */');
  o.push('export type AppShim = Shim<Methods>;', '');
  o.push('/**');
  o.push(' * This app\'s typed bridge.');
  o.push(' *');
  o.push(' * `connect()` once at startup, then `has()` tells you whether a method or event added in a later');
  o.push(' * release exists on *this* host. `ready()` after the first meaningful paint commits an OTA bundle.');
  o.push(' */');
  o.push('export const { call, has, on, onLink, ready, connect, installShim } = createBridge<Methods, Events>(');
  o.push('  METHOD_SINCE,');
  o.push('  EVENT_SINCE,');
  o.push(');', '');
  return o.join('\n');
}

function dartType({ base, list, nullable }) {
  let t = DART_PRIM[base] ?? base;
  if (list) t = `List<${t}>`;
  return nullable && !t.endsWith('?') ? `${t}?` : t;
}

const DART_DECODE = { string: 'decodeString', int: 'decodeInt', num: 'decodeNum', bool: 'decodeBool' };

function dartDecodeBase(base, v, f) {
  if (base === 'json') return v;
  if (PRIMS.has(base)) return `${DART_DECODE[base]}(${v}, ${f})`;
  return `${base}.fromJson(${v}, ${f})`;
}

function dartDecode(t, v, f) {
  const inner = t.list ? `decodeListOf(${v}, ${f}, (e, p) => ${dartDecodeBase(t.base, 'e', 'p')})` : dartDecodeBase(t.base, v, f);
  return t.nullable && (t.list || t.base !== 'json') ? `${v} == null ? null : ${inner}` : inner;
}

function dartEncode(t, x) {
  if (PRIMS.has(t.base)) return x;
  const q = t.nullable ? '?' : '';
  return t.list ? `${x}${q}.map((e) => e.toJson()).toList()` : `${x}${q}.toJson()`;
}

function dartClass(name, fs) {
  const o = [`final class ${name} {`];
  o.push(fs.length ? `  const ${name}({${fs.map((f) => `${f.type.nullable ? '' : 'required '}this.${f.name}`).join(', ')}});` : `  const ${name}();`, '');
  o.push(`  factory ${name}.fromJson(Object? j, [String f = '${name}']) {`);
  o.push(`    final m = decodeObject(j, f);`);
  o.push(`    decodeKeys(m, const {${fs.map((x) => `'${x.name}'`).join(', ')}}, f);`);
  o.push(`    return ${name}(${fs.map((x) => `${x.name}: ${dartDecode(x.type, `m['${x.name}']`, `'$f.${x.name}'`)}`).join(', ')});`);
  o.push('  }', '');
  for (const f of fs) o.push(`  final ${dartType(f.type)} ${f.name};`);
  if (fs.length) o.push('');
  o.push(`  Map<String, Object?> toJson() => {${fs.map((f) => `'${f.name}': ${dartEncode(f.type, f.name)}`).join(', ')}};`);
  o.push('}', '');
  return o;
}

// The decoders, the reply cap and the script builders used to be emitted into every app. They live in
// the `valence` package now, so a fix to any of them ships with `flutter pub upgrade`.
const DART_IMPORTS = `import 'dart:convert';

import 'package:valence/codegen.dart';
import 'package:valence/valence.dart';
`;

export function genDart(s) {
  const o = [
    '// GENERATED by valence codegen from valence/bridge.schema.json. Do not edit.',
    '// ignore_for_file: type=lint, unused_element',
    '',
    DART_IMPORTS,
    '/// The bridge version this host implements.',
    '///',
    '/// Canonical check 5 compares a manifest\'s `requires.bridge` against **this**, through',
    '/// `ValenceConfig.bridgeVersion`, and never against a second literal: a host that under-reports its',
    '/// version refuses its own built-in bundle on first launch, with nothing left to serve.',
    `const hostBridgeVersion = ${s.version};`,
    '',
  ];
  for (const t of s.types) o.push(...dartClass(t.name, t.fields));
  for (const m of s.methods) if (m.params.length) o.push(...dartClass(pascal(m.name) + 'Params', m.params));

  o.push('abstract interface class BridgeHandlers {');
  for (const m of s.methods) {
    const arg = m.params.length ? `${pascal(m.name)}Params p` : '';
    o.push(`  Future<${dartType(m.returns)}> ${camel(m.name)}(${arg});`);
  }
  o.push('}', '');

  o.push('/// Opt-in defaults for test doubles or partial hosts. Production hosts extend ValenceBuiltins.');
  o.push('mixin BridgeHandlersDefaults implements BridgeHandlers {');
  for (const m of s.methods) {
    const arg = m.params.length ? `${pascal(m.name)}Params p` : '';
    o.push('  @override');
    o.push(`  Future<${dartType(m.returns)}> ${camel(m.name)}(${arg}) async => throw const BridgeError('E_UNSUPPORTED', '${m.name} is not implemented');`);
  }
  o.push('}', '');

  o.push('/// Decodes one message from the JS channel, checks the per-launch [nonce] the host served in the entry page,');
  o.push('/// calls the handler and returns the reply JSON. Never throws.');
  o.push('Future<String> bridgeDispatch(BridgeHandlers h, String raw, {required String nonce}) async {');
  o.push('  Object? id;');
  o.push('  try {');
  o.push('    final Object? decoded;');
  o.push('    try {');
  o.push('      decoded = jsonDecode(raw);');
  o.push('    } on FormatException {');
  o.push("      throw const BridgeError('E_PARAMS', 'message is not JSON');");
  o.push('    }');
  o.push("    final msg = decodeObject(decoded, 'message');");
  o.push("    id = msg['id'];");
  o.push("    if (nonce.isEmpty || msg['n'] != nonce) throw const BridgeError('E_DENIED', 'bad nonce');");
  o.push("    final p = msg['p'] ?? const <String, Object?>{};");
  o.push("    switch (msg['m']) {");
  for (const m of s.methods) {
    o.push(`      case '${m.name}':`);
    const call = m.params.length ? `h.${camel(m.name)}(${pascal(m.name)}Params.fromJson(p, 'p'))` : `h.${camel(m.name)}()`;
    if (!m.params.length) o.push(`        decodeKeys(decodeObject(p, 'p'), const {}, 'p');`);
    if (m.returns.base === 'void') o.push(`        await ${call};`, '        return replyOk(id, null);');
    else o.push(`        final r = await ${call};`, `        return replyOk(id, ${dartEncode(m.returns, 'r')});`);
  }
  o.push('      default:');
  o.push("        throw BridgeError('E_UNKNOWN', 'unknown method ${msg['m']}');");
  o.push('    }');
  o.push('  } on BridgeError catch (e) {');
  o.push('    return replyError(id, e.code, e.message);');
  o.push('  } catch (e) {');
  o.push("    return replyError(id, BridgeErrorCode.internal, e.toString());");
  o.push('  }');
  o.push('}', '');

  o.push('/// Scripts that emit typed events into the web view. Pass the result to runJavaScript.');
  o.push('abstract final class BridgeEvents {');
  for (const e of s.events) {
    const args = e.payload.length ? `{${e.payload.map((f) => `required ${dartType(f.type)} ${f.name}`).join(', ')}}` : '';
    const body = `{${e.payload.map((f) => `'${f.name}': ${dartEncode(f.type, f.name)}`).join(', ')}}`;
    o.push(`  static String ${camel(e.name)}(${args}) => eventScript('${e.name}', ${e.payload.length ? body : 'const <String, Object?>{}'});`);
  }
  o.push('}', '');
  o.push(...dartBuiltins(s));
  return o.join('\n');
}

// The built-in half of BridgeHandlers, implemented by delegating to the package's runtime. An app extends
// this and overrides only its own methods, which is what keeps main.dart to about twenty lines.
function dartBuiltins(s) {
  const o = [
    '/// The built-in bridge methods, implemented against the `valence` runtime.',
    '///',
    '/// Extend it and implement your own methods; the built-ins are inherited. The bodies here are only',
    '/// marshalling — every decision they make lives in the package, so a fix ships with an upgrade:',
    '///',
    '/// ```dart',
    '/// class AppHandlers extends ValenceBuiltins implements BridgeHandlers {',
    '///   AppHandlers(super.valence);',
    '///',
    '///   @override',
    '///   Future<void> hapticsTap() async => HapticFeedback.lightImpact();',
    '/// }',
    '/// ```',
    'abstract class ValenceBuiltins {',
    '  /// Wraps an open runtime.',
    '  ValenceBuiltins(this.valence);',
    '',
    '  /// The runtime every built-in delegates to.',
    '  final Valence valence;',
    '',
  ];
  for (const m of s.methods) {
    const builtin = BUILTINS[m.name];
    if (!builtin) continue;
    const typeName = m.returns.base === 'void' || PRIMS.has(m.returns.base) ? '' : m.returns.base;
    const arg = m.params.length ? `${pascal(m.name)}Params p` : '';
    // Which of the built-in's optional fields this app actually declared, so the delegation passes those
    // and no others. An app that never regenerated against the newer runtime keeps compiling.
    const declared = new Set((s.types.find((t) => t.name === m.returns.base)?.fields ?? []).map((f) => f.name));
    // Same question for the optional *params*: an app that never regenerated against the newer runtime has
    // not declared them, so the delegation must not pass them.
    const declaredParams = new Set(m.params.map((f) => f.name));
    o.push(`  /// \`${m.name}\`, from the package.`);
    o.push(`  Future<${dartType(m.returns)}> ${camel(m.name)}(${arg}) async {`);
    for (const line of builtin.call(typeName, (f) => declared.has(f), (p) => declaredParams.has(p)).split('\n')) {
      o.push(line.startsWith('        ') ? `    ${line.trimStart()}` : `    ${line}`);
    }
    o.push('  }', '');
  }
  if (o[o.length - 1] === '') o.pop();
  o.push('}', '');
  return o;
}

// A schema may omit a built-in; it may not redefine one with a different shape, because the generated
// delegation would then pass the wrong arguments to the runtime and nothing else would catch it.
export function assertBuiltinShapes(s) {
  const show = (t) => (typeof t === 'string' ? t : `a type with {${Object.keys(t.fields).join(', ')}}${t.list ? '[]' : ''}`);
  for (const m of s.methods) {
    const want = BUILTINS[m.name];
    if (!want) continue;
    const got = Object.fromEntries(m.params.map((f) => [f.name, typeString(f.type)]));
    // Required params, exactly. Beyond them only this built-in's own optional params, each at its declared
    // type — the same rule as the return type's optional fields, and what lets the runtime add a param
    // (rule 5) without every app on the older shape failing codegen.
    const optionalParams = want.optionalParams ?? {};
    const requiredParams = Object.fromEntries(Object.entries(got).filter(([f]) => !(f in optionalParams)));
    const extraParams = Object.entries(got).filter(([f]) => f in optionalParams);
    if (canonical(requiredParams) !== canonical(want.params) || extraParams.some(([f, t]) => t !== optionalParams[f])) {
      const allowed = Object.keys(optionalParams).length
        ? ` It may also take ${Object.entries(optionalParams).map(([f, t]) => `"${f}": ${t}`).join(', ')}.`
        : '';
      throw new Error(
        `"${m.name}" is implemented by the valence package, so its params must stay ${JSON.stringify(want.params)}, not ${JSON.stringify(got)}. Add a new method under a different name instead.${allowed}`,
      );
    }
    // A grown param must arrive with the sibling name that gates it (§4.2). Checked here rather than in
    // assertAdditive, because the trap does not need a store baseline: an app that declares `after` and
    // never declares `data.count` has the documented gate answering false on every host it ships,
    // including the ones that accept the cursor — so a page that follows the docs never pages, and the
    // bucket it was added for still has no complete read.
    for (const [param, sibling] of Object.entries(want.paramSiblings ?? {})) {
      if (param in got && !s.methods.some((x) => x.name === sibling) && !s.events.some((x) => x.name === sibling)) {
        throw new Error(
          `"${m.name}" declares the param "${param}", which has no "since" of its own — so the only thing a page can gate it on is "${sibling}", shipped in the same version. Declare "${sibling}" too, or drop "${param}": has("${m.name}") is true on hosts that reject it with E_PARAMS.`,
        );
      }
    }
    if (typeof want.returns === 'string') {
      if (typeString(m.returns) !== want.returns) {
        throw new Error(`"${m.name}" is implemented by the valence package, so it must return ${want.returns}, not ${typeString(m.returns)}`);
      }
      continue;
    }
    const type = s.types.find((t) => t.name === m.returns.base);
    // The required fields must be there, exactly. Beyond them only this built-in's own optional fields are
    // allowed, each at its declared type — that is what makes a runtime able to add one (rule 5) without
    // every app on the older shape failing codegen.
    const optional = want.returns.optional ?? {};
    const fields = Object.fromEntries((type?.fields ?? []).map((f) => [f.name, typeString(f.type)]));
    const required = Object.fromEntries(Object.entries(fields).filter(([f]) => !(f in optional)));
    const extras = Object.entries(fields).filter(([f]) => f in optional);
    const bad =
      !!m.returns.nullable !== !!want.returns.nullable ||
      !!m.returns.list !== !!want.returns.list ||
      !type ||
      canonical(required) !== canonical(want.returns.fields) ||
      extras.some(([f, t]) => t !== optional[f]);
    if (bad) {
      const allowed = Object.keys(optional).length ? ` It may also carry ${Object.entries(optional).map(([f, t]) => `"${f}": ${t}`).join(', ')}.` : '';
      throw new Error(
        `"${m.name}" is implemented by the valence package, so it must return ${show(want.returns)}, not "${typeString(m.returns)}". The type's name is yours; its fields are not.${allowed}`,
      );
    }
  }
}

const typeString = (t) => `${t.base}${t.list ? '[]' : ''}${t.nullable ? '?' : ''}`;

const dartStr = (s) =>
  `'${String(s)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/[\x00-\x1f\x7f]/g, (c) => `\\u{${c.charCodeAt(0).toString(16)}}`)}'`;

export function genDartConfig(cfg, keyring) {
  const linkOrigins = validateLinkOrigins(cfg.links?.origins ?? []);
  const connect = cfg.http?.origins ?? [];
  if (!Array.isArray(connect)) throw new Error('http.origins must be an array of exact HTTP(S) origins');
  for (const origin of connect) {
    let u;
    try { u = new URL(origin); } catch { /* rejected below */ }
    if (typeof origin !== 'string' || !u || !['http:', 'https:'].includes(u.protocol) ||
        u.username || u.password || u.search || u.hash || (u.pathname !== '/' && u.pathname !== '') ||
        origin.includes('*') || !/^https?:\/\/[^/?#]+\/?$/.test(origin)) {
      throw new Error('http.origins entries must be exact HTTP(S) origins without credentials, paths, query or fragment');
    }
  }
  const ring = Object.entries(keyring).map(([k, v]) => `${dartStr(k)}: ${dartStr(v)}`).join(', ');
  const data = Object.entries(cfg.data ?? {}).map(([k, v]) => `${dartStr(k)}: ${v}`).join(', ');
  const writable = (cfg.writable ?? []).map(dartStr).join(', ');
  const lines = [
    `  appId: ${dartStr(cfg.appId)},`,
    `  keyring: {${ring}},`,
    // bridgeVersion is the generated constant, never a second literal: check 5 compares against it, and a
    // host that under-reports its version refuses its own built-in bundle on first launch.
    '  bridgeVersion: hostBridgeVersion,',
    '  channel: valenceOtaChannel,',
    `  otaBase: ${dartStr(cfg.ota?.base ?? '')},`,
    `  syncBase: ${dartStr(cfg.sync?.base ?? '')},`,
    `  writableBuckets: {${writable}},`,
    `  dataSchemas: {${data}},`,
    `  httpOrigins: {${connect.map((o) => dartStr(new URL(o).origin)).join(', ')}},`,
    `  linkOrigins: {${linkOrigins.map(dartStr).join(', ')}},`,
    `  seedSchemas: {${Object.entries(cfg.seedSchemas ?? {}).map(([b, ns]) => `${dartStr(b)}: [${ns.join(', ')}]`).join(', ')}},`,
  ];
  if (cfg.sync?.mode === 'static') lines.push('  syncMode: ValenceSyncMode.staticChunks,');
  // Only emitted when the project asks for it: a 0.3 app whose generated host chose its own SQLite file
  // name sets host.database so the package keeps reading the user's existing rows.
  if (cfg.host?.database) lines.push(`  databaseName: ${dartStr(cfg.host.database)},`);
  return [
    '// GENERATED by valence codegen from valence/valence.config.json and keyring.json. Do not edit.',
    '// ignore_for_file: type=lint',
    '',
    "import 'package:valence/valence.dart';",
    '',
    "import 'bridge.g.dart';",
    '',
    `const valenceOtaChannel = ${dartStr(cfg.ota?.channel ?? 'production')};`,
    '',
    '/// Everything the runtime needs about this app. Pass it to `Valence.open`.',
    'const valenceConfig = ValenceConfig(',
    ...lines,
    ');',
    '',
  ].join('\n');
}

// Formatters (dart format, prettier) only move whitespace and trailing commas; --check ignores both.
const normalize = (t) => t.replace(/\s+/g, '').replace(/,([)\]}])/g, '$1');

export function codegen({ root, cfg, check = false }) {
  const p = paths(root, cfg);
  const raw = readJson(p.schema);
  const s = parseSchema(raw);
  assertBuiltinShapes(s);
  assertAdditive(readBaseline(p).storeSchema, raw);
  const keyring = existsSync(p.keyring) ? readJson(p.keyring) : {};
  if (!Object.keys(keyring).length) throw new Error('keyring.json is empty. Run "valence keygen" first.');
  const outputs = [
    [p.ts, genTs(s)],
    [p.dart, genDart(s)],
    [p.dartConfig, genDartConfig(cfg, keyring)],
  ];
  const stale = outputs.filter(([f, text]) => !existsSync(f) || normalize(readFileSync(f, 'utf8')) !== normalize(text)).map(([f]) => f);
  if (check) {
    if (stale.length) throw new Error(`generated files are stale, run "valence codegen":\n  ${stale.join('\n  ')}`);
    return { written: [] };
  }
  for (const [f, text] of outputs) if (stale.includes(f)) writeFile(f, text);
  return { written: stale };
}

// ---------- CLI ----------

// Mechanical evidence only. A declaration or a passing unit test cannot establish device behavior.
function runFlutter(args, cwd) {
  // Windows Flutter is a .bat entry point. Only fixed flags and the validated relative test paths reach
  // this command string; reject shell syntax here too, so adding another caller cannot widen it.
  if (args.some((arg) => !/^[A-Za-z0-9_./-]+$/.test(arg))) throw new Error('unsafe Flutter argument');
  const options = { cwd, encoding: 'utf8', timeout: 180_000 };
  if (process.platform !== 'win32') return spawnSync('flutter', args, options);
  if (spawnSync('where.exe', ['flutter.bat'], { encoding: 'utf8' }).status !== 0) {
    return { error: { code: 'ENOENT' } };
  }
  return spawnSync('cmd.exe', ['/d', '/c', `flutter ${args.join(' ')}`], options);
}

export async function diagnose({ root, cfg, tests = false, run = runFlutter, keyDir = join(homedir(), '.valence', 'keys'), git = (args) => spawnSync('git', args, { cwd: root, encoding: 'utf8' }) }) {
  const rows = [];
  const fixes = {
    'generated code': 'run valence codegen; restore incompatible shipped schema changes before regenerating',
    'stack report': 'restore .valence/stack-check.md or rerun the docs-scout phase',
    'native value': 'declare two distinct supported nativeValue capabilities in valence.config.json',
    'built-in compatibility': 'run valence codegen and valence bundle --builtin, then rebuild the host',
    'seed coverage': 'regenerate seed.db with valence seed --from <seed-directory> for every current data pair',
    'Flutter dependencies': 'run flutter pub get in host.dir and correct dependency constraints',
    'test matrix': 'correct .valence/test-matrix.json using the documented IDs and host-relative test files',
  };
  const check = async (name, fn, fix = fixes[name] ?? 'correct the mapped test path or failing test, then rerun valence doctor --tests') => {
    try {
      const warning = await fn();
      rows.push([warning ? 'WARN' : 'PASS', name, warning ?? 'verified']);
    } catch (e) {
      rows.push(['FAIL', name, `${e.message.split('\n')[0]} | Fix: ${fix}`]);
    }
  };
  const p = paths(root, cfg);
  const host = resolve(root, cfg.host.dir);
  await check('generated code', () => { codegen({ root, cfg, check: true }); });
  await check('bridge version', () => {
    const schema = parseSchema(readJson(p.schema));
    const generated = /\bconst hostBridgeVersion = (\d+);/.exec(readFileSync(p.dart, 'utf8'));
    if (!generated || Number(generated[1]) !== schema.version) throw new Error('schema version differs from generated hostBridgeVersion');
  }, 'run valence codegen, rebuild the host and ship a store update for new native capabilities');
  await check('store baseline', () => {
    if (!existsSync(p.baseline)) return 'no recorded store build; additive guard has no shipped baseline';
    const baseline = readJson(p.baseline);
    if (!baseline.storeSchema) {
      if (baseline.storeSeq) throw new Error('storeSeq exists without storeSchema');
      return 'no recorded store schema';
    }
    int(baseline.storeSeq, 'baseline.storeSeq', 1);
    parseSchema(baseline.storeSchema);
    assertAdditive(baseline.storeSchema, readJson(p.schema));
  }, 'restore the committed baseline from the store release; do not rebaseline to silence a failure');
  await check('OTA bridge compatibility', () => {
    const dir = join(p.ota, 'manifests');
    if (!existsSync(dir)) return 'no local OTA manifests; release compatibility not checked';
    const files = readdirSync(dir).filter((f) => f.endsWith('.json'));
    if (!files.length) return 'no local OTA manifests; release compatibility not checked';
    const baseline = readBaseline(p);
    const storeBridge = baseline.storeSchema ? parseSchema(baseline.storeSchema).version : null;
    for (const file of files) {
      const m = verifyBundle({ manifestPath: join(dir, file), filesDir: join(p.ota, 'files'), keyring: readJson(p.keyring), appId: cfg.appId });
      if (!Number.isSafeInteger(m.requires?.bridge) || m.requires.bridge < 1) throw new Error('OTA requires.bridge must be a positive integer');
      if (storeBridge !== null && m.requires.bridge > storeBridge) throw new Error(`OTA ${m.seq} requires bridge ${m.requires.bridge}, store baseline is ${storeBridge}`);
    }
    if (storeBridge === null) return 'OTA signatures verified, but no recorded store bridge; compatibility unverified';
  }, 'rebuild OTA with --requires-bridge <store-version> and has() guards, or ship the new host first; archive obsolete local releases outside dist-ota');
  await check('database directory', () => {
    const name = cfg.host.database ?? 'valence.db';
    if (typeof name !== 'string' || !name || name === '.' || name === '..' || /[<>:"/\\|?*\x00-\x1f]/.test(name) || /[. ]$/.test(name) || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(name)) throw new Error('host.database must be a plain file name, never a directory or path');
    if (cfg.host.databaseDirectory !== undefined || cfg.host.databasePath !== undefined) throw new Error('host database directory/path overrides are unsupported');
    return `<appSupport>/${name}; installed location and legacy adoption need a device check`;
  }, 'set host.database to the existing database file name, run codegen; verify legacy adoption on a device before shipping');
  await check('signing keys in Git', () => {
    if (insideGit(keyDir)) throw new Error('configured signing-key directory resolves inside a Git work tree');
    const repo = git(['rev-parse', '--show-toplevel']);
    if (repo.error?.code === 'ENOENT') return 'Git unavailable; private-key scan not run';
    if (repo.error || repo.status !== 0) return 'not a Git work tree; private-key scan not run';
    // -l returns names only: never include matching lines or subprocess stderr in diagnostic output.
    const result = git(['-C', repo.stdout.trim(), 'grep', '--untracked', '-a', '-l', '-E', '-e', '-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----', '--', '.']);
    if (result.error || ![0, 1].includes(result.status)) throw new Error('Git private-key scan failed');
    if (result.status === 0) throw new Error('PEM private key found in tracked or non-ignored files (contents withheld)');
  }, 'move signing keys outside Git, remove exposed files from the index and rotate exposed keys; audit history separately');
  await check('connection origins', () => {
    if (!Array.isArray(cfg.web.connect ?? [])) throw new Error('web.connect must be an array of HTTP(S) URLs');
    for (const value of cfg.web.connect ?? []) {
      let url;
      try { url = new URL(value); } catch { /* rejected below */ }
      if (typeof value !== 'string' || !/^https?:\/\//.test(value) || /[\s*'";\\]/.test(value) || !url || !['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw new Error('web.connect contains an invalid HTTP(S) connection URL');
    }
    if (Array.isArray(cfg.http?.origins) && cfg.http.origins.some((value) => typeof value !== 'string' || /[\s\\]/.test(value))) throw new Error('http.origins contains whitespace or backslashes');
    genDartConfig(cfg, readJson(p.keyring)); // Native token origins have the stricter exact-origin rule.
  }, 'use HTTP(S) URLs in web.connect and exact trusted origins in http.origins; run codegen and ship a store build for native origin changes');
  await check('stack report', () => {
    if (!existsSync(join(root, '.valence', 'stack-check.md'))) return 'missing .valence/stack-check.md; run the docs-scout phase';
    return 'report present; freshness and policy wording require review';
  });
  await check('native value', () => {
    const allowed = new Set(['offline', 'notifications', 'widget', 'share', 'haptics', 'biometric']);
    if (cfg.nativeValue === undefined) return 'declare nativeValue using at least two §6 capabilities';
    if (!Array.isArray(cfg.nativeValue) || cfg.nativeValue.some((x) => !allowed.has(x))) throw new Error('invalid nativeValue capability');
    if (new Set(cfg.nativeValue).size < 2) throw new Error('nativeValue needs at least two distinct §6 capabilities');
    return `declared ${cfg.nativeValue.join(', ')}; native setup and device evidence still need review`;
  });
  await check('built-in compatibility', () => {
    const manifestPath = join(host, 'assets', 'valence', 'builtin', 'manifest.json');
    if (!existsSync(manifestPath)) return 'built-in not built';
    const m = verifyBundle({ manifestPath, filesDir: join(dirname(manifestPath), 'files'), keyring: readJson(p.keyring), appId: cfg.appId });
    const generated = /\bconst hostBridgeVersion = (\d+);/.exec(readFileSync(p.dart, 'utf8'));
    if (!generated || m.requires.bridge > Number(generated[1])) throw new Error('built-in requires a bridge newer than generated hostBridgeVersion');
    for (const [b, n] of Object.entries(m.requires.data)) {
      if (cfg.data?.[b] !== n) throw new Error(`built-in requires ${b} v${n}, config requires ${cfg.data?.[b]}`);
    }
  });
  await check('seed coverage', async () => {
    if (!Object.keys(cfg.data ?? {}).length) return;
    if (!existsSync(p.seed)) return 'seed missing; offline cold start is unverified';
    const { DatabaseSync } = await import('node:sqlite');
    const db = new DatabaseSync(p.seed, { readOnly: true });
    try {
      for (const [b, n] of Object.entries(cfg.data)) {
        if (!db.prepare('SELECT 1 FROM bucket WHERE name = ? AND schema = ?').get(b, n)) {
          throw new Error(`seed missing current pair ${b} v${n}`);
        }
      }
    } finally { db.close(); }
  });
  await check('Flutter dependencies', () => {
    if (!existsSync(join(host, 'pubspec.yaml'))) return 'host pubspec missing; dependency resolution not run';
    if (!existsSync(join(host, 'pubspec.lock'))) return 'pubspec.lock missing; run flutter pub get before checking resolved dependencies';
    const r = run(['pub', 'deps', '--json'], host);
    if (r.error?.code === 'ENOENT') return 'Flutter unavailable; dependency resolution not checked';
    if (r.error || r.status !== 0) throw new Error('flutter pub deps --json failed; run flutter pub get in the host');
    const deps = JSON.parse(r.stdout).packages;
    if (!Array.isArray(deps) || !deps.some((d) => d.name === 'valence')) throw new Error('resolved host does not depend on valence');
    const android = deps.find((d) => d.name === 'path_provider_android');
    if (android?.version !== '2.2.23') return `path_provider_android ${android?.version ?? 'absent'} differs from tested compatibility range >=2.2.17 <2.3.0 (expected 2.2.23) (U-7)`;
  });
  const matrixPath = join(root, '.valence', 'test-matrix.json');
  let matrix = {};
  await check('test matrix', () => {
    if (!existsSync(matrixPath)) return 'missing .valence/test-matrix.json; §8 coverage unverified';
    const candidate = readJson(matrixPath);
    if (!candidate || Array.isArray(candidate) || typeof candidate !== 'object') throw new Error('test matrix must be an object');
    if (Object.keys(candidate).some((id) => !['bridge', 'loopback', 'updater', 'store-sync', 'integration'].includes(id))) throw new Error('unknown test matrix ID');
    matrix = candidate;
  });
  for (const id of ['bridge', 'loopback', 'updater', 'store-sync', 'integration']) {
    await check(`§8 ${id}`, () => {
      const files = matrix[id];
      if (files === undefined) return 'no mapped app wiring/device evidence; package invariants belong to package tests';
      if (!Array.isArray(files) || !files.length) throw new Error('mapping must be a nonempty test-file array');
      for (const file of files) {
        if (typeof file !== 'string' || !/^(test|integration_test)\/[A-Za-z0-9_./-]+_test\.dart$/.test(file) || file.split('/').includes('..')) throw new Error('mapping must name host-relative test files');
        const target = realpathSync(join(host, file));
        const rel = relative(realpathSync(host), target);
        if (rel.startsWith('..') || resolve(host, rel) !== target) throw new Error('test mapping leaves host directory');
      }
      if (id === 'integration' || files.some((f) => f.startsWith('integration_test/'))) return 'mapped; requires a separate emulator/device run';
      if (!tests) return 'mapped but not executed; pass --tests';
      const r = run(['test', ...files], host);
      if (r.error?.code === 'ENOENT') return 'Flutter unavailable; tests not run';
      if (r.error || r.status !== 0) throw new Error(`flutter test failed for ${id}`);
    });
  }
  return rows;
}

export function validateLinkOrigins(origins) {
  if (!Array.isArray(origins)) throw new Error('links.origins must be an array');
  for (const origin of origins) {
    // Canonical ASCII origins only: no URL-parser repair, wildcard, credentials or path.
    const match = typeof origin === 'string' && /^([a-z][a-z0-9+.-]*):\/\/([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::([0-9]+))?$/.exec(origin);
    if (!match || ['http', 'javascript', 'data', 'file', 'content', 'intent', 'about', 'blob'].includes(match[1]) ||
        (match[3] && (match[1] !== 'https' || Number(match[3]) < 1 || Number(match[3]) > 65535 || String(Number(match[3])) !== match[3])) ||
        match[2].split('.').some((s) => !s || s.startsWith('-') || s.endsWith('-'))) {
      throw new Error('links.origins must contain exact lowercase HTTPS/custom origins without paths, credentials or wildcards');
    }
    if (match[1] === 'https' && new URL(origin).origin !== origin) throw new Error('links.origins must use canonical HTTPS origins (omit default ports)');
  }
  return origins;
}

/** Writes website association documents only; native intent filters/entitlements remain store setup. */
export function association({ kind, packageId, fingerprints, appId, out }) {
  let name, document;
  if (kind === 'assetlinks') {
    if (!/^[A-Za-z]\w*(?:\.[A-Za-z]\w*)+$/.test(packageId ?? '')) throw new Error('--package must be an Android applicationId');
    const certs = (fingerprints ?? '').split(',');
    if (!certs.length || certs.some((s) => !/^(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$/.test(s))) throw new Error('--fingerprints requires comma-separated SHA-256 certificate fingerprints');
    name = 'assetlinks.json';
    document = [{ relation: ['delegate_permission/common.handle_all_urls'], target: { namespace: 'android_app', package_name: packageId, sha256_cert_fingerprints: [...new Set(certs.map((s) => s.toUpperCase()))] } }];
  } else {
    if (!/^[A-Z0-9]{10}\.[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(appId ?? '')) throw new Error('--app-id must be TEAMID.bundle.id (10-character team ID; letters, digits and hyphens in bundle ID)');
    name = 'apple-app-site-association';
    document = { applinks: { apps: [], details: [{ appID: appId, paths: ['*'] }] } };
  }
  if (!out) throw new Error('--out is required (website public directory)');
  const dir = join(resolve(out), '.well-known');
  mkdirSync(dir, { recursive: true });
  const target = join(dir, name);
  writeFileSync(target, `${JSON.stringify(document, null, 2)}\n`, { flag: 'wx' });
  return { file: target };
}

const HELP = `Valence CLI ${VALENCE_VERSION} (spec: references/contracts.md)

  valence version                        print the CLI version (doctor compares it with the skill copy)
  valence keygen                         new Ed25519 key in ~/.valence/keys, public key into valence/keyring.json
  valence codegen [--check]              bridge.schema.json -> bridge.g.ts, bridge.g.dart, config.g.dart
  valence bundle [--builtin | --store [--rebaseline]] [--floor N] [--requires-bridge N] [--urgent] [--key file]
                                    sign the web build: --builtin into the host assets, else into .valence/dist-ota;
                                    --store = --builtin for a build you submit to the stores (records the baseline);
                                    --rebaseline lets --store overwrite a recorded store schema it would otherwise refuse
  valence pointer [--channel production] [--seq N] --rollout 0..100
  valence verify --manifest file --files dir
                                    --files is the content-addressed files/ directory inside the bundle, not the bundle directory
  valence seed --from dir                <bucket>.json files {schema, rows:[{k,v,u,d}]} -> host assets/valence/seed.db
  valence doctor [--tests]               mechanical diagnostics; execute mapped unit tests with --tests
  valence assetlinks --package id --fingerprints SHA256,... --out public-dir
  valence aasa --app-id TEAMID.bundle.id --out public-dir

Options: --root <project root> (default .)`;

export async function main(argv) {
  const { values: v, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      root: { type: 'string', default: '.' },
      check: { type: 'boolean', default: false },
      tests: { type: 'boolean', default: false },
      builtin: { type: 'boolean', default: false },
      store: { type: 'boolean', default: false },
      rebaseline: { type: 'boolean', default: false },
      urgent: { type: 'boolean', default: false },
      floor: { type: 'string' },
      'requires-bridge': { type: 'string' },
      channel: { type: 'string', default: 'production' },
      seq: { type: 'string' },
      rollout: { type: 'string' },
      from: { type: 'string' },
      manifest: { type: 'string' },
      files: { type: 'string' },
      key: { type: 'string' },
      package: { type: 'string' },
      fingerprints: { type: 'string' },
      'app-id': { type: 'string' },
      out: { type: 'string' },
      help: { type: 'boolean', short: 'h', default: false },
    },
  });
  const cmd = positionals[0];
  // Otherwise a release script that loses --store still takes --rebaseline and reports nothing.
  if (v.rebaseline && !(cmd === 'bundle' && v.store)) throw new Error('--rebaseline only means something with "bundle --store"');
  if (cmd === 'version') return console.log(VALENCE_VERSION);
  if (!cmd || v.help) return console.log(HELP);
  if (cmd === 'assetlinks' || cmd === 'aasa') {
    return console.log(JSON.stringify(association({ kind: cmd, packageId: v.package, fingerprints: v.fingerprints, appId: v['app-id'], out: v.out }), null, 2));
  }
  const root = resolve(v.root);
  const cfg = loadConfig(root);
  const p = paths(root, cfg);
  const log = (o) => console.log(JSON.stringify(o, null, 2));

  if (cmd === 'keygen') return log(keygen({ root, cfg }));
  if (cmd === 'codegen') return log(codegen({ root, cfg, check: v.check }));
  if (cmd === 'bundle') {
    const r = bundle({
      root,
      cfg,
      key: loadSigningKey(cfg, readJson(p.keyring), v.key),
      builtin: v.builtin,
      store: v.store,
      rebaseline: v.rebaseline,
      urgent: v.urgent,
      floor: v.floor === undefined ? undefined : int(v.floor, '--floor'),
      requiresBridge: v['requires-bridge'] === undefined ? undefined : int(v['requires-bridge'], '--requires-bridge', 1),
    });
    for (const w of r.warnings) console.warn(`warning: ${w}`);
    return log({ seq: r.manifest.seq, files: Object.keys(r.manifest.files).length, manifest: r.manifestPath, ...(r.recorded ? { recorded: r.recorded } : {}) });
  }
  if (cmd === 'pointer') {
    if (v.rollout === undefined) throw new Error('--rollout is required (0..100)');
    return log(pointer({ root, cfg, channel: v.channel, seq: v.seq === undefined ? undefined : int(v.seq, '--seq', 1), rollout: int(v.rollout, '--rollout', 0, 100) }));
  }
  if (cmd === 'verify') {
    if (!v.manifest || !v.files) throw new Error('--manifest and --files are required');
    const m = verifyBundle({ manifestPath: resolve(v.manifest), filesDir: resolve(v.files), keyring: readJson(p.keyring), appId: cfg.appId });
    return log({ ok: true, seq: m.seq, files: Object.keys(m.files).length });
  }
  if (cmd === 'seed') {
    if (!v.from) throw new Error('--from is required');
    const r = await seed({ root, cfg, from: resolve(v.from) });
    for (const w of r.warnings) console.warn(`warning: ${w}`);
    return log({ out: r.out, counts: r.counts });
  }
  if (cmd === 'doctor') {
    const rows = await diagnose({ root, cfg, tests: v.tests });
    log(rows);
    if (rows.some(([s]) => s === 'FAIL')) process.exitCode = 1;
    return rows;
  }
  throw new Error(`unknown command "${cmd}"\n\n${HELP}`);
}

// realpath on both sides: a symlinked or junctioned valence.mjs (or an npm bin link) must still run main().
const isMain = () => {
  try {
    return !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
};

if (isMain()) {
  main(process.argv.slice(2)).catch((e) => {
    console.error(`valence: ${e.message}`);
    process.exit(1);
  });
}
