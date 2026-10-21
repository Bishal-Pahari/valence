// node --test scripts/valence.test.mjs   (Node >= 22.18: the bridge test imports .ts through type stripping)
import {
  cpSync,
  rmSync,
  mkdirSync,
  existsSync,
  symlinkSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import test from 'node:test';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { sign } from 'node:crypto';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { execSync } from 'node:child_process';

import {
  seed,
  bundle,
  keygen,
  codegen,
  diagnose,
  pointer,
  loadConfig,
  parseSchema,
  verifyBundle,
  loadSigningKey,
  VALENCE_VERSION,
} from './valence.mjs';

const TEMPLATES = join(import.meta.dirname, '..', 'templates');
const NOW = Date.UTC(2026, 9, 15);

function fixture({ data = { calendar: 1 }, latest = false } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'mr-'));
  mkdirSync(join(root, 'valence'));
  cpSync(join(TEMPLATES, 'bridge.schema.json'), join(root, 'valence', 'bridge.schema.json'));
  // Field evolution cases omit the optional batch/status additions.
  if (!latest) {
    const p = join(root, 'valence', 'bridge.schema.json');
    const s = JSON.parse(readFileSync(p, 'utf8'));
    s.version = 4;
    for (const kind of ['methods', 'events']) {
      for (const [name, def] of Object.entries(s[kind])) if (def.since > 4) delete s[kind][name];
    }
    delete s.methods['data.getMany'];
    delete s.methods['sync.status'];
    delete s.types.SyncStatus;
    delete s.types.SyncResult.pending;
    writeFileSync(p, JSON.stringify(s));
  }
  const cfg = JSON.parse(readFileSync(join(TEMPLATES, 'valence.config.json'), 'utf8'));
  cfg.data = data;
  cfg.writable = ['user'];
  writeFileSync(join(root, 'valence', 'valence.config.json'), JSON.stringify(cfg));
  mkdirSync(join(root, 'web', 'build', '_app'), { recursive: true });
  writeFileSync(join(root, 'web', 'build', 'index.html'), '<!doctype html><head><script>window.boot=1</script><script type="module" src="/_app/a.js"></script></head>');
  writeFileSync(join(root, 'web', 'build', '_app', 'a.js'), 'console.log(1)');
  mkdirSync(join(root, 'web', 'src', 'routes', 'calendar'), { recursive: true });
  mkdirSync(join(root, 'web', 'src', 'routes', '(app)', 'settings'), { recursive: true });
  writeFileSync(join(root, 'web', 'src', 'routes', '+page.svelte'), '');
  const keyDir = mkdtempSync(join(tmpdir(), 'mr-keys-'));
  const c = loadConfig(root);
  keygen({ root, cfg: c, keyDir });
  const keyring = JSON.parse(readFileSync(join(root, 'valence', 'keyring.json'), 'utf8'));
  const key = loadSigningKey(c, keyring, join(keyDir, `${c.appId}.${c.keyId}.pem`));
  return { root, cfg: c, key, keyring, keyDir };
}

const schemaFile = (root) => join(root, 'valence', 'bridge.schema.json');
const editSchema = (root, fn) => {
  const s = JSON.parse(readFileSync(schemaFile(root), 'utf8'));
  fn(s);
  writeFileSync(schemaFile(root), JSON.stringify(s));
};

// ---------- keys ----------

test('keygen refuses a key dir inside git, including through a link', () => {
  const { root, cfg } = fixture();
  mkdirSync(join(root, '.git'));
  mkdirSync(join(root, 'keys'));
  assert.throws(() => keygen({ root, cfg, keyDir: join(root, 'keys') }), /inside a git work tree/);
  const link = join(mkdtempSync(join(tmpdir(), 'mr-link-')), 'ln');
  symlinkSync(join(root, 'keys'), link, 'junction');
  assert.throws(() => keygen({ root, cfg, keyDir: join(link, 'not', 'yet') }), /inside a git work tree/);
});

test('keygen never overwrites a key or a committed keyring entry', () => {
  const { root, cfg } = fixture();
  assert.throws(() => keygen({ root, cfg, keyDir: mkdtempSync(join(tmpdir(), 'mr-k2-')) }), /already in keyring/);
});

test('loadSigningKey rejects a key that does not match the keyring', () => {
  const { cfg, keyring, keyDir } = fixture();
  const other = fixture();
  assert.throws(() => loadSigningKey(cfg, keyring, join(other.keyDir, `${cfg.appId}.${cfg.keyId}.pem`)), /does not match/);
  assert.ok(loadSigningKey(cfg, keyring, join(keyDir, `${cfg.appId}.${cfg.keyId}.pem`)));
});

// ---------- bundle / verify / pointer ----------

test('store build signs, verifies and records the store baseline', () => {
  const { root, cfg, key, keyring } = fixture();
  const r = bundle({ root, cfg, key, store: true, now: NOW });
  const m = verifyBundle({ manifestPath: r.manifestPath, filesDir: r.filesDir, keyring, appId: cfg.appId });
  assert.equal(m.seq, NOW / 1000);
  assert.deepEqual(m.routes, ['/', '/calendar', '/settings']);
  // The template schema is at version 4 since §4.5 added http.request, and requires.bridge
  // defaults to it.
  assert.deepEqual(m.requires, { bridge: 4, data: { calendar: 1 } });
  assert.equal(Object.keys(m.files).length, 2);
  assert.ok(!readFileSync(r.manifestPath + '.sig', 'utf8').includes('\n'), 'sig has no trailing newline');
  const b = JSON.parse(readFileSync(join(root, '.valence', 'baseline.json'), 'utf8'));
  assert.deepEqual(b.storeRoutes, m.routes);
  assert.equal(b.storeSchema.version, 4);
  assert.equal(b.lastSeq, m.seq);
});

test('CSP hashes inline scripts and allows the sync origin', () => {
  const { root, cfg, key } = fixture();
  const { manifest } = bundle({ root, cfg, key, now: NOW });
  assert.match(manifest.csp, /script-src 'self' 'sha256-[A-Za-z0-9+/=]+'/);
  assert.match(manifest.csp, /connect-src 'self' https:\/\/api\.example\.com/);
  assert.match(manifest.csp, /frame-src 'none'/);
});

test('CSP hashes match what browsers compute for CRLF scripts, and allow wasm when present', () => {
  const { root, cfg, key } = fixture();
  writeFileSync(join(root, 'web', 'build', 'index.html'), '<head><script>\r\nwindow.a=1\r\n</script></head>');
  const crlf = bundle({ root, cfg, key, now: NOW }).manifest.csp;
  writeFileSync(join(root, 'web', 'build', 'index.html'), '<head><script>\nwindow.a=1\n</script></head>');
  const lf = bundle({ root, cfg, key, now: NOW }).manifest.csp;
  assert.equal(crlf, lf);
  assert.ok(!lf.includes('wasm-unsafe-eval'));
  writeFileSync(join(root, 'web', 'build', '_app', 'm.WASM'), '\0asm');
  assert.match(bundle({ root, cfg, key, now: NOW }).manifest.csp, /script-src 'self' 'wasm-unsafe-eval'/);
});

test('seq is monotonic (same clock, slow clock) and new routes warn', () => {
  const { root, cfg, key } = fixture();
  const a = bundle({ root, cfg, key, store: true, now: NOW });
  mkdirSync(join(root, 'web', 'src', 'routes', '[[lang]]', 'shop'), { recursive: true });
  // SvelteKit with its only +page/+layout files inside a (group): still directory-routed.
  rmSync(join(root, 'web', 'src', 'routes', '+page.svelte'));
  writeFileSync(join(root, 'web', 'src', 'routes', '(app)', '+layout.svelte'), '');
  writeFileSync(join(root, 'web', 'src', 'routes', 'Counter.svelte'), '');
  writeFileSync(join(root, 'web', 'src', 'routes', 'helpers.ts'), '');
  const b = bundle({ root, cfg, key, now: NOW });
  const c = bundle({ root, cfg, key, now: NOW - 3_600_000 });
  assert.equal(b.manifest.seq, a.manifest.seq + 1);
  assert.equal(c.manifest.seq, b.manifest.seq + 1);
  assert.ok(b.warnings.some((w) => w.includes('/shop')));
  assert.ok(!b.warnings.some((w) => w.includes('/Counter') || w.includes('/helpers')), 'SvelteKit co-located files are not routes');
});

test('a project with no detectable routes is told the store route check is off', () => {
  const { root, cfg, key } = fixture();
  // A client-side-routed SPA: nothing to scan, so every bundle would report just ["/"].
  rmSync(join(root, 'web', 'src'), { recursive: true });
  const spa = loadConfig(root);
  const a = bundle({ root, cfg: spa, key, store: true, now: NOW });
  assert.deepEqual(a.manifest.routes, ['/']);
  assert.ok(a.warnings.some((w) => w.includes('INACTIVE')), 'a store build with no routes warns that the check is off');
  assert.ok(bundle({ root, cfg: spa, key, now: NOW }).warnings.some((w) => w.includes('INACTIVE')), 'and so does an OTA build');

  // declaredRoutes turns it back on: it feeds the manifest and the baseline, and the diff warns again.
  const decl = { ...spa, web: { ...spa.web, declaredRoutes: ['/shelf', '/'] } };
  const b = bundle({ root, cfg: decl, key, store: true, now: NOW });
  assert.deepEqual(b.manifest.routes, ['/', '/shelf']);
  assert.ok(!b.warnings.some((w) => w.includes('INACTIVE')));
  const c = bundle({ root, cfg: { ...decl, web: { ...decl.web, declaredRoutes: ['/shelf', '/about'] } }, key, now: NOW });
  assert.ok(c.warnings.some((w) => w.includes('/about')), 'a declared route the store build never had still warns');

  // ["/"] is a deliberate single-route claim and does not warn. [] claims nothing, so it is rejected rather than
  // silently silencing the warning it was added to raise.
  const one = bundle({ root, cfg: { ...spa, web: { ...spa.web, declaredRoutes: ['/'] } }, key, now: NOW });
  assert.deepEqual(one.manifest.routes, ['/']);
  assert.ok(!one.warnings.some((w) => w.includes('INACTIVE')));
  for (const bad of ['/shelf', [], ['shelf'], [1], ['/a/b']]) {
    assert.throws(() => bundle({ root, cfg: { ...spa, web: { ...spa.web, declaredRoutes: bad } }, key, now: NOW }), /declaredRoutes/);
  }
  // A trailing slash is the same route, so editing one in must not look like a new feature area.
  assert.deepEqual(bundle({ root, cfg: { ...decl, web: { ...decl.web, declaredRoutes: ['/shelf/'] } }, key, now: NOW }).manifest.routes, ['/', '/shelf']);
});

test('declared routes are unioned with a scan, and a scan that finds one route says so differently', () => {
  const { root, cfg, key } = fixture();
  // Scanning works here (the fixture has web/src/routes with calendar and (app)/settings), so declaring a route adds
  // to it rather than switching it off: a project that declares routes still gets warned about a new directory.
  const both = bundle({ root, cfg: { ...cfg, web: { ...cfg.web, declaredRoutes: ['/shelf'] } }, key, store: true, now: NOW });
  assert.deepEqual(both.manifest.routes, ['/', '/calendar', '/settings', '/shelf']);
  mkdirSync(join(root, 'web', 'src', 'routes', 'admin'));
  const after = bundle({ root, cfg: { ...cfg, web: { ...cfg.web, declaredRoutes: ['/shelf'] } }, key, now: NOW });
  assert.ok(after.warnings.some((w) => w.includes('/admin')), 'declaring routes must not turn the scan off');

  // A scannable app with exactly one route is not "INACTIVE": the check runs, it just has one route to report.
  rmSync(join(root, 'web', 'src', 'routes'), { recursive: true });
  mkdirSync(join(root, 'web', 'src', 'routes'));
  writeFileSync(join(root, 'web', 'src', 'routes', '+page.svelte'), '');
  const single = bundle({ root, cfg: loadConfig(root), key, now: NOW });
  assert.deepEqual(single.manifest.routes, ['/']);
  assert.ok(!single.warnings.some((w) => w.includes('INACTIVE')), 'a working scan is never reported as inactive');
  assert.ok(single.warnings.some((w) => w.includes('found only "/"')));
});

test('_host/ is reserved for the host, and a relative asset base in the entry page warns', () => {
  const { root, cfg, key } = fixture();
  const html = (head) => writeFileSync(join(root, 'web', 'build', 'index.html'), `<!doctype html><head>${head}</head>`);

  // `base: './'` is what you reach for when you hear "static files, no server". §3's fallback serves the entry page at
  // any depth, so the webview resolves these against the request path: a nested route reloads to a blank screen.
  html('<script type="module" src="./_app/a.js"></script><link rel="icon" href="favicon.png">');
  const w = bundle({ root, cfg, key, now: NOW }).warnings;
  assert.ok(w.some((x) => x.includes('relative URL') && x.includes('./_app/a.js') && x.includes('favicon.png')));

  // Root-relative, scheme-relative, scheme and fragment refs all resolve the same at any depth, so none of them warn.
  html('<script type="module" src="/_app/a.js"></script><link rel="icon" href="data:,"><img src="//cdn/x.png"><a href="#x">');
  assert.ok(!bundle({ root, cfg, key, now: NOW }).warnings.some((x) => x.includes('relative URL')));

  // The server answers /_host/ before the manifest lookup, so a bundle file under it could never be reached.
  mkdirSync(join(root, 'web', 'build', '_host'));
  writeFileSync(join(root, 'web', 'build', '_host', 'x.js'), '');
  assert.throws(() => bundle({ root, cfg, key, now: NOW }), /_host\/ is reserved/);
});

test('OTA defaults to the store bridge while explicit and built-in builds can require the newer host', () => {
  const { root, cfg, key } = fixture();
  bundle({ root, cfg, key, store: true, now: NOW }); // ships bridge 4 to the stores
  const bridgeWarn = (r) => r.warnings.filter((w) => w.includes('requires.bridge'));

  // A guarded method added at since: 5 bumps the schema version, and the default silently inherits it.
  editSchema(root, (s) => {
    s.version = 5;
    s.methods['share.image'] = { since: 5, params: { png: 'string' }, returns: 'bool' };
  });
  const bumped = bundle({ root, cfg, key, now: NOW });
  assert.equal(bumped.manifest.requires.bridge, 4);
  assert.match(bridgeWarn(bumped).join('\n'), /pinned to 4.*share\.image.*has\(\)/s);
  const explicit = bundle({ root, cfg, key, requiresBridge: 5, now: NOW });
  assert.match(bridgeWarn(explicit).join('\n'), /--requires-bridge 4/);
  assert.equal(bundle({ root, cfg, key, builtin: true, now: NOW }).manifest.requires.bridge, 5);

  // Pinning to the oldest host in the field is the lever, and it is the right move — but it is not silent: an
  // unguarded call to a since: 5 method would then be dead in the field with no build-time or store signal.
  const pinned = bundle({ root, cfg, key, requiresBridge: 4, now: NOW });
  assert.equal(pinned.manifest.requires.bridge, 4);
  assert.ok(!bridgeWarn(pinned).some((w) => w.includes('above the bridge version')));
  assert.match(bridgeWarn(pinned).join('\n'), /pinned to 4.*share\.image.*has\(\)/s);

  // A store build is allowed to raise it — that build *is* the new floor — and so a fresh project has nothing to say.
  assert.deepEqual(bridgeWarn(bundle({ root, cfg, key, store: true, now: NOW })), []);
  assert.deepEqual(bridgeWarn(bundle({ root, cfg, key, now: NOW })), []);
});

test('a service worker in the output warns, because it answers before the host server does', () => {
  // The host makes bundle files revalidate against their hash (§3). A service worker serving from Cache
  // Storage is never asked, so a precaching build reopens the whole stale-bundle hole: the new release
  // activates, the old page renders, and the trial commits on that old page's ready().
  const { root, cfg, key } = fixture();
  const clean = bundle({ root, cfg, key, now: NOW }).warnings;
  assert.ok(!clean.some((x) => x.includes('service worker')));

  writeFileSync(join(root, 'web', 'build', 'registerSW.js'), "navigator.serviceWorker.register('/sw.js', { scope: '/' });\n");
  const w = bundle({ root, cfg, key, now: NOW + 1000 }).warnings;
  assert.ok(w.some((x) => x.includes('service worker') && x.includes('inHost()')), w.join('\n'));
});

test('the relative-asset warning ignores script bodies and an absolute base href, and reads srcset', () => {
  const { root, cfg, key } = fixture();
  const html = (head) => writeFileSync(join(root, 'web', 'build', 'index.html'), `<!doctype html><head>${head}</head>`);
  const relWarn = (r) => r.warnings.filter((w) => w.includes('relative URL'));

  // A URL inside a template literal is not a reference a browser resolves, so it must not warn.
  html('<script type="module" src="/_app/a.js"></script><script>const r = "x.html";</script><style>/* y.css */</style>');
  assert.deepEqual(relWarn(bundle({ root, cfg, key, now: NOW })), []);

  // An absolute <base href> re-roots every relative reference in the document, so there is nothing to report.
  html('<base href="/"><script type="module" src="./_app/a.js"></script>');
  assert.deepEqual(relWarn(bundle({ root, cfg, key, now: NOW })), []);

  // srcset candidate lists and unquoted attributes are references too.
  html('<script type="module" src="/_app/a.js"></script><img srcset="a.png 1x, ./b.png 2x"><link rel=icon href=c.png>');
  const w = relWarn(bundle({ root, cfg, key, now: NOW }))[0];
  assert.match(w, /a\.png/);
  assert.match(w, /\.\/b\.png/);
  assert.match(w, /c\.png/);
});

test('floor only goes up and never exceeds seq', () => {
  const { root, cfg, key } = fixture();
  bundle({ root, cfg, key, floor: 5, now: NOW });
  assert.throws(() => bundle({ root, cfg, key, floor: 0, now: NOW }), /only goes up/);
  assert.throws(() => bundle({ root, cfg, key, floor: Number.MAX_SAFE_INTEGER, now: NOW }), /above this bundle/);
});

test('bundle rejects native code anywhere in the path', () => {
  const { root, cfg, key } = fixture();
  mkdirSync(join(root, 'web', 'build', 'x.framework'));
  writeFileSync(join(root, 'web', 'build', 'x.framework', 'bin'), 'x');
  assert.throws(() => bundle({ root, cfg, key }), /native code/);
});

test('verify rejects tampering, bad signatures, unknown keys, other apps and unsafe paths', () => {
  const { root, cfg, key, keyring } = fixture();
  const r = bundle({ root, cfg, key, now: NOW });
  const args = { manifestPath: r.manifestPath, filesDir: r.filesDir, keyring, appId: cfg.appId };
  const [h] = Object.values(r.manifest.files).map((f) => f.h);
  const blob = join(r.filesDir, h);
  const original = readFileSync(blob);
  writeFileSync(blob, Buffer.concat([original, Buffer.from(' ')]));
  assert.throws(() => verifyBundle(args), /hash mismatch/);
  writeFileSync(blob, original);

  const bytes = readFileSync(r.manifestPath, 'utf8');
  writeFileSync(r.manifestPath, bytes.replace('"urgent": false', '"urgent": true'));
  assert.throws(() => verifyBundle(args), /bad manifest signature/);
  writeFileSync(r.manifestPath, bytes);

  assert.throws(() => verifyBundle({ ...args, keyring: {} }), /unknown keyId/);
  assert.throws(() => verifyBundle({ ...args, appId: 'com.other.app' }), /not com\.other\.app/);
  assert.equal(verifyBundle(args).seq, r.manifest.seq);

  // A validly signed manifest with a path that escapes the bundle is still refused.
  const parsed = JSON.parse(bytes);
  const evil = { ...parsed, files: { ...parsed.files, '../state.json': { h, n: original.length } } };
  const evilBytes = Buffer.from(JSON.stringify(evil));
  writeFileSync(r.manifestPath, evilBytes);
  writeFileSync(r.manifestPath + '.sig', sign(null, evilBytes, key).toString('base64'));
  assert.throws(() => verifyBundle(args), /unsafe path/);

  // A validly signed manifest claiming the host's own prefix is refused too: §3 serves /_host/ before the manifest,
  // so such a file would be shadowed by host content on an origin the page trusts.
  const reserved = { ...parsed, files: { ...parsed.files, '_host/app.js': { h, n: original.length } } };
  const reservedBytes = Buffer.from(JSON.stringify(reserved));
  writeFileSync(r.manifestPath, reservedBytes);
  writeFileSync(r.manifestPath + '.sig', sign(null, reservedBytes, key).toString('base64'));
  assert.throws(() => verifyBundle(args), /unsafe path in manifest: _host\/app\.js/);

  // A malformed entry is still named as malformed, even when --files is wrong: the entry checks run first.
  const malformed = { ...parsed, files: { ...parsed.files, 'bad.js': { h: 'nothex', n: 1 } } };
  const malformedBytes = Buffer.from(JSON.stringify(malformed));
  writeFileSync(r.manifestPath, malformedBytes);
  writeFileSync(r.manifestPath + '.sig', sign(null, malformedBytes, key).toString('base64'));
  assert.throws(() => verifyBundle({ ...args, filesDir: root }), /bad file entry for bad\.js/);

});

test('a wrong --files level is reported as a wrong directory, not a corrupted bundle', () => {
  const { root, cfg, key, keyring } = fixture();
  const { manifestPath, filesDir } = bundle({ root, cfg, key, builtin: true, now: NOW });
  const bundleDir = join(filesDir, '..'); // the built-in bundle directory: manifest.json plus files/
  verifyBundle({ manifestPath, filesDir, keyring, appId: cfg.appId });

  // Pointing --files one level up is the common slip, and it used to name the first entry as "missing" — which is
  // exactly what a corrupted bundle looks like, the one thing verify is reached for to tell apart.
  assert.throws(
    () => verifyBundle({ manifestPath, filesDir: bundleDir, keyring, appId: cfg.appId }),
    (e) => /no manifest files found under/.test(e.message) && /files/.test(e.message),
  );
  // A genuinely partial bundle still reports the file that is gone.
  rmSync(join(filesDir, JSON.parse(readFileSync(manifestPath, 'utf8')).files['_app/a.js'].h));
  assert.throws(() => verifyBundle({ manifestPath, filesDir, keyring, appId: cfg.appId }), /missing file _app\/a\.js/);
});

test('pointer defaults to the newest manifest', () => {
  const { root, cfg, key } = fixture();
  const r = bundle({ root, cfg, key, now: NOW });
  const p = pointer({ root, cfg, channel: 'production', rollout: 10 });
  assert.equal(p.seq, r.manifest.seq);
  assert.deepEqual(JSON.parse(readFileSync(p.file, 'utf8')), { seq: r.manifest.seq, rollout: 10 });
});

// ---------- codegen ----------

test('multi-schema seeds require declarations, retain both versions and fail atomically on duplicates', async () => {
  const { root, cfg } = fixture({ data: { calendar: 2 } });
  cfg.seedSchemas = { calendar: [1] };
  const from = mkdtempSync(join(tmpdir(), 'mr-multi-seed-'));
  const doc = (schema, v) => JSON.stringify({ schema, rows: [{ k: 'day', v, u: 1 }] });
  writeFileSync(join(from, 'calendar.v1.json'), doc(1, 'old'));
  const old = await seed({ root, cfg, from });
  assert.equal(old.warnings.length, 1, 'old seed does not satisfy current offline coverage');
  writeFileSync(join(from, 'calendar.v2.json'), doc(2, 'new'));
  const r = await seed({ root, cfg, from });
  assert.equal(r.warnings.length, 0);
  const { DatabaseSync } = await import('node:sqlite');
  const db = new DatabaseSync(r.out, { readOnly: true });
  assert.deepEqual(db.prepare('SELECT schema, value FROM kv ORDER BY schema').all().map((r) => [r.schema, JSON.parse(r.value)]), [[1, 'old'], [2, 'new']]);
  db.close();
  const before = readFileSync(r.out);
  writeFileSync(join(from, 'calendar.json'), doc(1, 'duplicate'));
  await assert.rejects(seed({ root, cfg, from }), /duplicate seed pair/);
  assert.deepEqual(readFileSync(r.out), before);
  rmSync(join(from, 'calendar.json'));
  cfg.seedSchemas = {};
  await assert.rejects(seed({ root, cfg, from }), /declared schema/);
  cfg.seedSchemas = { calendar: [1] };
  writeFileSync(join(from, 'calendar.v1.json'), doc(2, 'wrong filename'));
  await assert.rejects(seed({ root, cfg, from }), /filename schema/);
});

test('ota.channel validates and codegen emits a named constant wired to the host', () => {
  const { root, cfg } = fixture({ latest: true });
  cfg.ota.channel = 'beta';
  writeFileSync(join(root, 'valence', 'valence.config.json'), JSON.stringify(cfg));
  codegen({ root, cfg: loadConfig(root) });
  const generated = readFileSync(join(root, cfg.host.dir, 'lib', 'valence', 'config.g.dart'), 'utf8');
  assert.match(generated, /const valenceOtaChannel = 'beta';/);
  assert.match(generated, /channel: valenceOtaChannel/);
  cfg.ota.channel = '../production';
  writeFileSync(join(root, 'valence', 'valence.config.json'), JSON.stringify(cfg));
  assert.throws(() => loadConfig(root), /ota.channel/);
});

test('doctor reports absent evidence as warnings, compatibility errors as failures and mapped execution honestly', async () => {
  const { root, cfg, key } = fixture({ latest: true });
  codegen({ root, cfg });
  const first = await diagnose({ root, cfg });
  assert.equal(first.filter(([s]) => s === 'FAIL').length, 0);
  for (const id of ['bridge', 'loopback', 'updater', 'store-sync', 'integration']) {
    assert.ok(first.some(([s, name]) => s === 'WARN' && name === `§8 ${id}`));
  }
  mkdirSync(join(root, '.valence'), { recursive: true });
  mkdirSync(join(root, cfg.host.dir, 'test'), { recursive: true });
  writeFileSync(join(root, cfg.host.dir, 'test', 'wiring_test.dart'), 'void main() {}');
  writeFileSync(join(root, '.valence', 'test-matrix.json'), JSON.stringify({ bridge: ['test/wiring_test.dart'] }));
  const unrun = await diagnose({ root, cfg });
  assert.ok(unrun.some(([s, n, msg]) => s === 'WARN' && n === '§8 bridge' && msg.includes('not executed')));
  const ran = await diagnose({ root, cfg, tests: true, run: () => ({ status: 0 }) });
  assert.ok(ran.some(([s, n]) => s === 'PASS' && n === '§8 bridge'));
  const failed = await diagnose({ root, cfg, tests: true, run: () => ({ status: 1 }) });
  assert.ok(failed.some(([s, n]) => s === 'FAIL' && n === '§8 bridge'));
  writeFileSync(join(root, '.valence', 'test-matrix.json'), JSON.stringify({ bridge: ['test/../../outside_test.dart'] }));
  assert.ok((await diagnose({ root, cfg })).some(([s, n]) => s === 'FAIL' && n === '§8 bridge'));
  cfg.nativeValue = ['offline', 'offline'];
  assert.ok((await diagnose({ root, cfg })).some(([s, n]) => s === 'FAIL' && n === 'native value'));
  bundle({ root, cfg, key, builtin: true, now: NOW });
  const dart = join(root, cfg.host.dir, 'lib', 'valence', 'bridge.g.dart');
  writeFileSync(dart, readFileSync(dart, 'utf8').replace(/const hostBridgeVersion = \d+;/, 'const hostBridgeVersion = 1;'));
  assert.ok((await diagnose({ root, cfg })).some(([s, n]) => s === 'FAIL' && n === 'built-in compatibility'));
});

test('codegen writes once, is stable, survives formatters, and --check detects real staleness', () => {
  const { root, cfg } = fixture();
  assert.equal(codegen({ root, cfg }).written.length, 3);
  assert.equal(codegen({ root, cfg }).written.length, 0);
  const dart = join(root, cfg.host.dir, 'lib', 'valence', 'bridge.g.dart');
  writeFileSync(dart, readFileSync(dart, 'utf8').replace(/\n/g, '\r\n').replace(/\);/g, ',\n);'));
  codegen({ root, cfg, check: true });
  editSchema(root, (s) => {
    s.version = 5;
    s.methods['share.text'] = { since: 2, params: { text: 'string' }, returns: 'void' };
  });
  assert.throws(() => codegen({ root, cfg, check: true }), /stale/);
});

test('a schema shipped in a store build is additive only', () => {
  const { root, cfg, key } = fixture();
  // The additive rules are exercised on a method the app owns: a built-in's shape is frozen by
  // assertBuiltinShapes before assertAdditive ever runs, so it cannot be used to probe this.
  editSchema(root, (s) => (s.methods['haptics.tap'] = { since: 1, params: { heavy: 'bool?' }, returns: 'void' }));
  codegen({ root, cfg });
  bundle({ root, cfg, key, builtin: true, now: NOW });
  editSchema(root, (s) => (s.methods['haptics.tap'].params.heavy = 'bool'));
  codegen({ root, cfg }); // a plain --builtin build (init, local testing) does not freeze the schema
  editSchema(root, (s) => (s.methods['haptics.tap'].params.heavy = 'bool?'));
  bundle({ root, cfg, key, store: true, now: NOW });
  editSchema(root, (s) => (s.methods['share.early'] = { since: 2, params: {}, returns: 'void' }));
  assert.throws(() => codegen({ root, cfg }), /needs since > 4/);
  editSchema(root, (s) => {
    delete s.methods['share.early'];
    s.version = 5;
    s.methods['share.text'] = { since: 5, params: { text: 'string' }, returns: 'void' };
  });
  codegen({ root, cfg });
  editSchema(root, (s) => (s.methods['haptics.tap'].returns = 'string'));
  assert.throws(() => codegen({ root, cfg }), /cannot change/);
  editSchema(root, (s) => delete s.methods['haptics.tap']);
  assert.throws(() => codegen({ root, cfg }), /cannot be removed/);
});

test('a built-in may be omitted but not redefined, because the package implements it', () => {
  const { root, cfg } = fixture();
  // The generated ValenceBuiltins delegates these to the valence package. A schema that keeps the name
  // and changes the shape would compile and then pass the wrong arguments to the runtime, so codegen
  // refuses it rather than leaving a wrong host to find on a device.
  const pristine = readFileSync(schemaFile(root), 'utf8');
  const bad = (mutate, re) => {
    writeFileSync(schemaFile(root), pristine);
    editSchema(root, mutate);
    assert.throws(() => codegen({ root, cfg }), re);
  };
  bad((s) => (s.methods['data.list'].params.limit = 'int'), /must stay/);
  bad((s) => (s.methods['data.list'].params.after = 'string?'), /must stay/);
  bad((s) => (s.methods['prefs.get'].returns = 'string'), /must return string\?/);
  bad((s) => (s.types.SyncResult.changed = 'num'), /fields are not/);
  bad((s) => (s.methods['data.list'].returns = 'Row'), /a type with \{key, value, usn\}\[\]/);
  // A field the runtime added is still refused at the wrong type.
  bad((s) => (s.types.SyncResult.reason = 'int'), /fields are not/);
  // §4.4's methods are built-ins like the rest. A nullable `value` would make secure.set a second delete,
  // silently, on a method whose whole point is that clearing a credential is explicit.
  bad((s) => (s.methods['secure.set'].params.value = 'string?'), /must stay/);
  bad((s) => (s.methods['auth.hasToken'].returns = 'string?'), /must return bool/);
  bad((s) => (s.methods['auth.setToken'].params.token = 'string'), /must stay/);
  // Omitting one is fine: an app that never syncs simply has no sync.now, and ValenceBuiltins drops it.
  writeFileSync(schemaFile(root), pristine);
  editSchema(root, (s) => delete s.methods['sync.now']);
  assert.ok(codegen({ root, cfg }).written.length);
  // And an app with no login drops the whole of §4.4 the same way.
  writeFileSync(schemaFile(root), pristine);
  editSchema(root, (s) => {
    for (const m of ['secure.get', 'secure.set', 'secure.delete', 'auth.setToken', 'auth.hasToken']) {
      delete s.methods[m];
    }
    delete s.events['auth.expired'];
  });
  assert.ok(codegen({ root, cfg }).written.length);
});

test('a built-in grows a field without breaking an app that has not taken it', () => {
  // Rule 5: the IDL is additive only. Before this, every built-in's shape was compared literally, so a
  // runtime could never add a field to one — the next codegen in every existing app would fail. The two
  // directions that matter: an app that declares the new field gets it passed through, and an app still
  // on the old shape keeps generating code that compiles.
  const { root, cfg } = fixture();
  codegen({ root, cfg });
  const withReason = readFileSync(join(root, 'mobile', 'lib', 'valence', 'bridge.g.dart'), 'utf8');
  assert.match(withReason, /reason: r\.reason\.name/, 'the template schema takes reason, so the delegation passes it');

  editSchema(root, (s) => delete s.types.SyncResult.reason);
  assert.ok(codegen({ root, cfg }).written.length, 'an app on the old three-field shape still generates');
  const without = readFileSync(join(root, 'mobile', 'lib', 'valence', 'bridge.g.dart'), 'utf8');
  assert.doesNotMatch(without, /reason:/, 'and the delegation does not pass a field its type does not have');
  assert.match(without, /offline: r\.offline/);
});

test('an app that already shipped a store build can take a built-in\'s new field', () => {
  // The case that matters and the one a fresh fixture misses: `bundle --store` records the schema the
  // stores reviewed, and §4.1 refuses any later change to a type in it. Relaxing only assertBuiltinShapes
  // would leave every real adopter — anyone who has ever cut a store build — unable to take the field the
  // docs tell them to take, with --rebaseline (which overwrites that reviewed record) as the only way out.
  const { root, cfg, key } = fixture();
  editSchema(root, (s) => {
    delete s.types.SyncResult.reason;
    // An app-owned type in the same store build, to prove the relaxation does not leak to one.
    s.types.Mine = { a: 'string' };
    s.methods['mine.get'] = { since: 1, params: {}, returns: 'Mine' };
  });
  codegen({ root, cfg });
  bundle({ root, cfg, key, store: true, now: NOW });
  const shipped = JSON.parse(readFileSync(join(root, '.valence', 'baseline.json'), 'utf8')).storeSchema;
  assert.deepEqual(Object.keys(shipped.types.SyncResult), ['buckets', 'changed', 'offline']);

  editSchema(root, (s) => (s.types.SyncResult.reason = 'string?'));
  assert.ok(codegen({ root, cfg }).written.length, 'the runtime field is additive against the recorded schema');
  assert.match(readFileSync(join(root, 'mobile', 'lib', 'valence', 'bridge.g.dart'), 'utf8'), /reason: r\.reason\.name/);

  // The relaxation is exactly that field at exactly that type, and nothing else.
  const pristine = readFileSync(schemaFile(root), 'utf8');
  const bad = (mutate, re) => {
    writeFileSync(schemaFile(root), pristine);
    editSchema(root, mutate);
    assert.throws(() => codegen({ root, cfg }), re);
  };
  bad((s) => (s.types.SyncResult.reason = 'string'), /fields are not/); // the runtime declares it nullable
  bad((s) => (s.types.SyncResult.other = 'string?'), /fields are not/); // not a field the runtime added
  bad((s) => delete s.types.SyncResult.offline, /fields are not/);
  // An app's own type gets no such latitude: §4.1 still refuses any change to a shipped one, even to a
  // field a built-in happens to have grown.
  bad((s) => (s.types.Mine.reason = 'string?'), /"Mine" shipped in a store build and cannot change/);
  bad((s) => (s.types.Mine.a = 'int'), /"Mine" shipped in a store build and cannot change/);
});

test('a second --store build cannot quietly rewrite the schema the stores reviewed', () => {
  const { root, cfg, key } = fixture();
  codegen({ root, cfg });
  const first = bundle({ root, cfg, key, store: true, now: NOW });
  assert.equal(first.recorded.bridge, 4);
  assert.deepEqual(first.recorded.routes, ['/', '/calendar', '/settings']);
  assert.ok(first.recorded.added.includes('+ method app.ready'), 'the first baseline records the whole schema as new');
  // The exact hole: codegen refuses a method added at the shipped `since`, and re-running --store used to erase
  // the baseline that refusal was made against.
  editSchema(root, (s) => (s.methods['share.early'] = { since: 2, params: {}, returns: 'void' }));
  assert.throws(() => codegen({ root, cfg }), /needs since > 4/);
  assert.throws(() => bundle({ root, cfg, key, store: true, now: NOW + 1000 }), /needs since > 4/);
  const b = JSON.parse(readFileSync(join(root, '.valence', 'baseline.json'), 'utf8'));
  assert.ok(!Object.hasOwn(b.storeSchema.methods, 'share.early'), 'the refused build left the baseline alone');
  // --rebaseline is the deliberate way out, and it says so.
  const forced = bundle({ root, cfg, key, store: true, rebaseline: true, now: NOW + 1000 });
  assert.match(forced.warnings.join('\n'), /--rebaseline overwrote the recorded store schema/);
  assert.deepEqual(forced.recorded.added, ['+ method share.early']);
  // An additive bump still goes through untouched, and reports what it added.
  editSchema(root, (s) => {
    s.version = 5;
    s.methods['share.text'] = { since: 5, params: { text: 'string' }, returns: 'void' };
  });
  codegen({ root, cfg });
  const bumped = bundle({ root, cfg, key, store: true, now: NOW + 2000 });
  assert.deepEqual(bumped.recorded.added, ['+ method share.text']);
  // A bump is also the moment the OTA pin stops being warned about, so the build names the number while it still can.
  assert.match(bumped.warnings.join('\n'), /takes the bridge from 4 to 5[\s\S]*--requires-bridge 4/);
});

test('a built-in build cannot require a bridge its own host does not have', () => {
  const { root, cfg, key } = fixture();
  assert.throws(
    () => bundle({ root, cfg, key, store: true, requiresBridge: 5, now: NOW }),
    /refuses its own built-in bundle at check 5/,
  );
  // The common way to get here is a schema bumped without a codegen run, so compare against the generated constant.
  codegen({ root, cfg });
  editSchema(root, (s) => {
    s.version = 5;
    s.methods['share.text'] = { since: 5, params: { text: 'string' }, returns: 'void' };
  });
  assert.throws(() => bundle({ root, cfg, key, store: true, now: NOW }), /the generated constant is behind the schema/);
  codegen({ root, cfg });
  assert.equal(bundle({ root, cfg, key, store: true, now: NOW }).manifest.requires.bridge, 5);
  // Pinning an OTA release down is the legitimate use of the flag and stays allowed.
  assert.equal(bundle({ root, cfg, key, requiresBridge: 1, now: NOW }).manifest.requires.bridge, 1);
});

test('a store build warns when a channel still points below it', () => {
  const { root, cfg, key } = fixture();
  // A project with no channel yet has nothing to be stale.
  assert.equal(bundle({ root, cfg, key, store: true, now: NOW }).warnings.length, 0);
  const ota = bundle({ root, cfg, key, now: NOW + 1000 });
  pointer({ root, cfg, channel: 'production', rollout: 100 });
  const store = bundle({ root, cfg, key, store: true, now: NOW + 2000 });
  assert.ok(store.manifest.seq > ota.manifest.seq, 'a store build outranks the release staged before it');
  assert.match(store.warnings.join('\n'), /channel "production" points at \d+, below this store build's seq/);
});

test('schema validation catches names that would break the generated code', () => {
  const base = JSON.parse(readFileSync(join(TEMPLATES, 'bridge.schema.json'), 'utf8'));
  const bad = (mutate, re) => {
    const s = structuredClone(base);
    mutate(s);
    assert.throws(() => parseSchema(s), re);
  };
  bad((s) => (s.methods['data.get'].returns = 'Nope'), /unknown type/);
  bad((s) => (s.methods['data.get'].since = 9), /since/);
  bad((s) => delete s.methods['app.info'], /must define app.info/);
  bad((s) => (s.methods['data.get'].params.key = 'void'), /void/);
  bad((s) => (s.methods['data.get'].params.default = 'string'), /reserved field/);
  bad((s) => (s.types.Json = {}), /reserved type/);
  bad((s) => (s.methods['to.string'] = { since: 1, params: {}, returns: 'void' }), /reserved Dart name/);
  bad((s) => {
    s.methods['dataX.get'] = { since: 1, params: {}, returns: 'void' };
    s.methods['data.xGet'] = { since: 1, params: {}, returns: 'void' };
  }, /both become/);
});

// ---------- seed ----------

test('seed is atomic, validated, and records per-bucket schema and max usn', async () => {
  const { root, cfg } = fixture();
  const from = mkdtempSync(join(tmpdir(), 'mr-seed-'));
  writeFileSync(join(from, 'calendar.json'), JSON.stringify({ schema: 1, rows: [{ k: '2026-01', v: { d: 31 }, u: 5 }, { k: '2026-02', v: null, u: 9, d: 1 }] }));
  const r = await seed({ root, cfg, from });
  assert.deepEqual(r.counts, { calendar: 2 });
  const { DatabaseSync } = await import('node:sqlite');
  const read = () => {
    const db = new DatabaseSync(r.out);
    const row = { ...db.prepare('SELECT schema, max_usn FROM bucket WHERE name = ?').get('calendar') };
    const del = db.prepare('SELECT deleted FROM kv WHERE key = ?').get('2026-02').deleted;
    db.close();
    return { row, del };
  };
  assert.deepEqual(read(), { row: { schema: 1, max_usn: 9 }, del: 1 });

  const bad = async (doc, re) => {
    writeFileSync(join(from, 'calendar.json'), JSON.stringify(doc));
    await assert.rejects(seed({ root, cfg, from }), re);
    assert.deepEqual(read().row, { schema: 1, max_usn: 9 }, 'previous seed.db kept');
  };
  await bad({ schema: 2, rows: [] }, /does not match/);
  await bad({ schema: 1, rows: [{ key: 'x', value: 1, u: 1 }] }, /string "k"/);
  await bad({ schema: 1, rows: [{ k: 'x', v: 1, u: '0x10' }] }, /usn/);
  await bad({ schema: 1, rows: [{ k: 'x', v: 1, u: 1 }, { k: 'x', v: 2, u: 2 }] }, /UNIQUE/);

  const empty = mkdtempSync(join(tmpdir(), 'mr-seed-empty-'));
  const e = await seed({ root, cfg, from: empty });
  assert.deepEqual(e.counts, {});
  assert.match(e.warnings[0], /"calendar" has no seed file/);
});

// ---------- CLI entry ----------

test('the CLI runs through a linked path (npm bin links, junctions)', () => {
  const link = join(mkdtempSync(join(tmpdir(), 'mr-bin-')), 'scripts');
  symlinkSync(import.meta.dirname, link, 'junction');
  assert.equal(execSync(`node "${join(link, 'valence.mjs')}" version`, { encoding: 'utf8' }).trim(), VALENCE_VERSION);
});

// ---------- web client ----------

// The runtime is @getvalence/bridge now, and it has its own tests. What is under test here is the
// generated binding: that bridge.g.ts wires METHOD_SINCE into createBridge and re-exports the pieces an
// app imports. The temp project has no node_modules, so the bare import is pointed at the package's
// source — which Node runs directly through type stripping, same as the generated .ts itself.
const BRIDGE_SRC = join(import.meta.dirname, '..', '..', '..', '..', 'packages', 'bridge', 'src', 'index.ts');

test('the generated bridge binds the package: nonce, errors, events, the cap and the web shim', async () => {
  const { root, cfg } = fixture();
  editSchema(root, (s) => {
    s.version = 5;
    s.methods['later.method'] = { since: 2, params: {}, returns: 'void' };
  });
  codegen({ root, cfg });
  const lib = join(root, cfg.web.lib);
  const gen = join(lib, 'bridge.g.ts');
  writeFileSync(gen, readFileSync(gen, 'utf8').replaceAll("'@getvalence/bridge'", JSON.stringify(pathToFileURL(BRIDGE_SRC).href)));
  const sent = [];
  globalThis.document = { querySelector: () => ({ content: 'nonce-1' }) };
  globalThis.window = { Valence: { postMessage: (s) => sent.push(JSON.parse(s)) } };
  const c = await import(pathToFileURL(gen).href);

  // connect() is what makes has() answerable: it asks the host which bridge version it implements.
  const connected = c.connect();
  assert.equal(sent[0].m, 'app.info');
  assert.equal(sent[0].n, 'nonce-1');
  window.__valence.r({ id: sent[0].id, ok: true, v: { bridge: 1 } });
  await connected;
  assert.equal(c.has('data.get'), true);
  // METHOD_SINCE is generated, and this is what it is for: a method added in a later release is refused
  // against an older host without a round trip, instead of coming back as E_UNKNOWN.
  assert.equal(c.has('later.method'), false);
  await assert.rejects(c.call('later.method'), (e) => e.code === 'E_UNSUPPORTED');

  const get = c.call('data.get', { bucket: 'b', key: 'k' });
  assert.deepEqual(sent[1], { id: sent[1].id, n: 'nonce-1', m: 'data.get', p: { bucket: 'b', key: 'k' } });
  window.__valence.r({ id: sent[1].id, ok: false, e: { code: 'E_DENIED', message: 'no' } });
  await assert.rejects(get, (e) => e instanceof c.BridgeError && e.code === 'E_DENIED');

  const seen = [];
  const off = c.on('sync.changed', (p) => seen.push(p.buckets));
  window.__valence.e('sync.changed', { buckets: ['a'] });
  // void, not Set.delete's boolean: a React useEffect cleanup must return void or a destructor.
  assert.equal(off(), undefined, "on()'s unsubscribe must return void");
  window.__valence.e('sync.changed', { buckets: ['b'] });
  assert.deepEqual(seen, [['a']]);

  // Over the cap, the client rejects before postMessage: Binder would otherwise kill the webview with no reply and
  // no error either side can catch, so there has to be a promise left to reject (§4.2).
  const before = sent.length;
  await assert.rejects(
    c.call('prefs.set', { key: 'big', value: 'x'.repeat(c.MAX_MESSAGE_BYTES) }),
    (e) => e instanceof c.BridgeError && e.code === 'E_TOO_LARGE',
  );
  assert.equal(sent.length, before, 'nothing was posted');

  // The cap is bytes, not UTF-16 code units: this string is well under the cap by length and well over it by size,
  // and a host rejecting it before decoding has no id to reply with, so the client has to be the one that refuses.
  const multibyte = 'ゆ'.repeat(Math.floor(c.MAX_MESSAGE_BYTES / 2));
  assert.ok(multibyte.length < c.MAX_MESSAGE_BYTES, 'under the cap measured in code units');
  await assert.rejects(
    c.call('prefs.set', { key: 'big', value: multibyte }),
    (e) => e instanceof c.BridgeError && e.code === 'E_TOO_LARGE',
  );
  assert.equal(sent.length, before, 'still nothing posted');


  delete window.Valence;
  c.installShim({ 'prefs.get': async ({ key }) => `web:${key}` });
  assert.equal(await c.call('prefs.get', { key: 'theme' }), 'web:theme');
  await assert.rejects(c.call('sync.now'), (e) => e.code === 'E_UNSUPPORTED');
  assert.equal(c.has('prefs.get'), true);
  delete globalThis.window;
  delete globalThis.document;
});

// The other half of AGENTS.md rule 4: the generated TS has to type-check under the settings an app's own
// CI will use, not merely run. The import test above proves the binding works; this proves the types do.
//
// ponytail: mapped to the package's source rather than its built dist/, which is gitignored and would make
// this gate depend on a build step. If a .d.ts emit ever diverges from the source, add the dist path here.
const TSC = join(import.meta.dirname, '..', '..', '..', '..', 'packages', 'bridge', 'node_modules', '.bin', 'tsc');

test(
  'the generated TS type-checks under --strict --verbatimModuleSyntax',
  { skip: !existsSync(TSC) && 'run "npm install" in packages/bridge first', timeout: 300_000 },
  () => {
    const { root, cfg } = fixture({ latest: true });
    codegen({ root, cfg });
    const lib = join(root, cfg.web.lib);
    // An app's web project is ESM; without this the compiler reads the file as CommonJS and every import
    // in it is an error, which says nothing about the generated code.
    writeFileSync(join(lib, 'package.json'), JSON.stringify({ name: 'gen', private: true, type: 'module' }));
    writeFileSync(
      join(lib, 'tsconfig.json'),
      JSON.stringify({
        compilerOptions: {
          target: 'ES2022',
          lib: ['ES2022', 'DOM'],
          module: 'nodenext',
          moduleResolution: 'nodenext',
          strict: true,
          verbatimModuleSyntax: true,
          noEmit: true,
          skipLibCheck: true,
          paths: { '@getvalence/bridge': [BRIDGE_SRC.replaceAll('\\', '/')] },
        },
        include: ['bridge.g.ts'],
      }),
    );
    execSync(`"${TSC}" -p tsconfig.json`, { cwd: lib, stdio: 'pipe' });
  },
);

// ---------- generated Dart ----------

const hasFlutter = (() => {
  try {
    execSync('flutter --version', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
})();

const PKG = join(import.meta.dirname, '..', '..', '..', '..', 'packages', 'valence').replaceAll('\\', '/');

// The generated Dart imports package:valence, and ValenceConfig and Valence are Flutter types, so the
// compile gate is a throwaway Flutter project with a path dependency on the package in this repo, not
// `dart run` on a loose file. `--offline` keeps it off the network; the package's own pub get fills the
// cache. The behaviour below is the same §4.2 matrix the generated dispatcher has always had to satisfy.
test(
  'generated Dart analyzes cleanly against the package, and dispatch behaves per contracts §4.2',
  { skip: !hasFlutter && 'flutter is not on PATH', timeout: 600_000 },
  () => {
    const { root, cfg } = fixture({ latest: true });
    editSchema(root, (s) => {
      s.types.Empty = {};
      s.methods['x.edge'] = { since: 1, params: { blobs: 'json[]?', rows: 'Row[]?', type: 'string', empty: 'Empty?' }, returns: 'Row[]?' };
      s.events['x.rowAdded'] = { since: 1, payload: { row: 'Row', more: 'Row[]?' } };
    });
    codegen({ root, cfg });
    const app = join(root, cfg.host.dir);
    writeFileSync(join(app, 'pubspec.yaml'), PROBE_PUBSPEC);
    writeFileSync(join(app, 'analysis_options.yaml'), 'include: package:flutter_lints/flutter.yaml\n');
    mkdirSync(join(app, 'test'), { recursive: true });
    writeFileSync(join(app, 'test', 'dispatch_test.dart'), DART_TEST);
    execSync('flutter pub get --offline', { cwd: app, stdio: 'pipe' });
    // The generated code is held to the analyzer's strictest setting, because an app's CI will be.
    execSync(`dart analyze --fatal-infos "${join(app, 'lib')}"`, { stdio: 'pipe' });
    assert.match(execSync('flutter test', { cwd: app, encoding: 'utf8' }), /All tests passed/);
  },
);

const PROBE_PUBSPEC = `name: valence_probe
publish_to: none
environment:
  sdk: ^3.6.0
dependencies:
  flutter:
    sdk: flutter
  valence:
    path: ${PKG}
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
`;

// Implements BridgeHandlers directly rather than extending the generated ValenceBuiltins: what is under
// test here is the generated marshalling, and ValenceBuiltins would need a live runtime behind it. The
// example app covers the other direction — the built-ins reaching the package for real.
const DART_TEST = `
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';
import 'package:valence_probe/valence/bridge.g.dart';
import 'package:valence_probe/valence/config.g.dart';

final class H with BridgeHandlersDefaults {
  @override
  Future<void> appReady() async {}
  @override
  Future<AppInfo> appInfo() async => const AppInfo(platform: 'test', host: 1, bridge: hostBridgeVersion, bundle: 1, locale: 'ne');
  @override
  Future<Object?> dataGet(DataGetParams p) async => {'bucket': p.bucket, 'key': p.key, 'line': '\\u2028"'};
  @override
  Future<List<Row>> dataList(DataListParams p) async => [Row(key: p.prefix ?? '-', value: p.limit, usn: 1)];
  @override
  Future<void> dataPut(DataPutParams p) async {
    if (!valenceConfig.writableBuckets.contains(p.bucket)) {
      throw const BridgeError(BridgeErrorCode.denied, 'read-only bucket');
    }
  }
  @override
  Future<SyncResult> syncNow(SyncNowParams p) async => SyncResult(buckets: p.buckets ?? const [], changed: 0, offline: true, reason: 'offline');
  @override
  Future<String?> prefsGet(PrefsGetParams p) async => null;
  @override
  Future<void> prefsSet(PrefsSetParams p) async {}
  @override
  Future<void> openExternal(OpenExternalParams p) async {}
  @override
  Future<void> bundleApplyUpdate() async {}
  @override
  Future<String?> secureGet(SecureGetParams p) async => null;
  @override
  Future<void> secureSet(SecureSetParams p) async {}
  @override
  Future<void> secureDelete(SecureDeleteParams p) async {}
  @override
  Future<void> authSetToken(AuthSetTokenParams p) async {}
  @override
  Future<bool> authHasToken() async => true;
  @override
  Future<HttpResponse> httpRequest(HttpRequestParams p) async => const HttpResponse(status: 200, headers: {}, body: 'ok');
  @override
  Future<List<Row>?> xEdge(XEdgeParams p) async => p.blobs == null ? null : [Row(key: p.type, value: p.blobs, usn: p.rows?.length ?? 0)];
}

Future<Map<String, Object?>> call(String raw) async =>
    jsonDecode(await bridgeDispatch(H(), raw, nonce: 'n1')) as Map<String, Object?>;
String code(Map<String, Object?> r) => (r['e']! as Map)['code'] as String;

void main() {
  test('new methods default to E_UNSUPPORTED through strict dispatch', () async {
    expect(code(await call('{"id":1,"n":"n1","m":"sync.status","p":{}}')), 'E_UNSUPPORTED');
    expect(code(await call('{"id":1,"n":"n1","m":"data.getMany","p":{"bucket":"calendar","keys":[3]}}')), 'E_PARAMS');
  });
  test('the generated config is wired to the generated bridge version', () {
    expect(valenceConfig.bridgeVersion, hostBridgeVersion);
  });

  test('a reply round-trips, escaping U+2028 and quotes', () async {
    final r = await call('{"id":1,"n":"n1","m":"data.get","p":{"bucket":"calendar","key":"2026-01"}}');
    expect(r['ok'], isTrue, reason: '\${r['e']}');
    expect((r['v']! as Map)['line'], '\\u2028"');
  });

  test('a missing or wrong nonce is denied', () async {
    expect(code(await call('{"id":1,"m":"data.get","p":{"bucket":"calendar","key":"x"}}')), BridgeErrorCode.denied);
    expect(code(await call('{"id":1,"n":"guess","m":"app.info"}')), BridgeErrorCode.denied);
  });

  test('an unknown method is E_UNKNOWN', () async {
    expect(code(await call('{"id":2,"n":"n1","m":"nope.nope","p":{}}')), BridgeErrorCode.unknown);
  });

  test('bad params are E_PARAMS, and so is an unknown field', () async {
    expect(code(await call('{"id":3,"n":"n1","m":"data.get","p":{"bucket":1,"key":"x"}}')), BridgeErrorCode.params);
    expect(code(await call('{"id":4,"n":"n1","m":"data.get","p":{"bucket":"a","key":"b","evil":1}}')), BridgeErrorCode.params);
    expect(code(await call('{"id":8,"n":"n1","m":"app.ready","p":{"x":1}}')), BridgeErrorCode.params);
    expect(code(await call('not json')), BridgeErrorCode.params);
    expect((await call('not json'))['id'], isNull);
  });

  test('a handler may deny, and a typed list comes back typed', () async {
    expect(code(await call('{"id":5,"n":"n1","m":"data.put","p":{"bucket":"calendar","key":"k","value":1}}')), BridgeErrorCode.denied);
    final r = await call('{"id":6,"n":"n1","m":"data.list","p":{"bucket":"b","limit":2}}');
    expect(((r['v']! as List).first as Map)['value'], 2);
  });

  test('a missing p means empty params', () async {
    final r = await call('{"id":7,"n":"n1","m":"sync.now"}');
    expect((r['v']! as Map)['offline'], isTrue);
  });

  test('the §4.4 built-ins are marshalled like any other', () async {
    // The delegation itself is the example app's test; here it is the generated params and reply.
    final has = await call('{"id":11,"n":"n1","m":"auth.hasToken"}');
    expect(has['v'], isTrue);
    final cleared = await call('{"id":12,"n":"n1","m":"auth.setToken","p":{"token":null}}');
    expect(cleared['ok'], isTrue, reason: '\${cleared['e']}');
    // secure.set takes a non-null value: secure.delete is the only delete (§4.4).
    expect(code(await call('{"id":13,"n":"n1","m":"secure.set","p":{"key":"k","value":null}}')), BridgeErrorCode.params);
  });

  test('nullable lists, nullable list returns and an empty type decode', () async {
    final none = await call('{"id":9,"n":"n1","m":"x.edge","p":{"type":"t","blobs":null}}');
    expect(none['ok'], isTrue, reason: '\${none['e']}');
    expect(none['v'], isNull);
    final some = await call('{"id":10,"n":"n1","m":"x.edge","p":{"type":"t","blobs":[1,{"a":null}],"rows":[{"key":"k","value":1,"usn":1}],"empty":{}}}');
    expect(((some['v']! as List).first as Map)['usn'], 1);
  });

  test('event scripts are built by the package', () {
    expect(
      BridgeEvents.syncChanged(buckets: ['a']),
      'window.__valence&&window.__valence.e("sync.changed",{"buckets":["a"]})',
    );
    expect(BridgeEvents.xRowAdded(row: const Row(key: 'k', value: null, usn: 1), more: null), contains('"more":null'));
  });
}
`;

// Native HTTP policy is compiled into the host, not inferred from an OTA CSP.
test('codegen freezes native HTTP shape and compiles only exact http.origins', () => {
  const { root, cfg } = fixture();
  cfg.http = { origins: [] };
  cfg.http.origins = ['https://API.example.com:443', 'http://127.0.0.1:8787'];
  codegen({ root, cfg });
  const config = readFileSync(join(root, cfg.host.dir, 'lib', 'valence', 'config.g.dart'), 'utf8');
  assert.match(config, /httpOrigins: \{'https:\/\/api.example.com', 'http:\/\/127.0.0.1:8787'\}/);
  for (const origin of ['https://api.test/path', 'https://user@api.test', 'https://*.test', 'file:///tmp', 'https://api.test?x=1', 'https://api.test/#', 'https://api.test/..']) {
    cfg.http.origins = [origin];
    assert.throws(() => codegen({ root, cfg }), /exact HTTP/);
  }
  cfg.http.origins = [];
  editSchema(root, (s) => (s.methods['http.request'].params.body = 'json?'));
  assert.throws(() => codegen({ root, cfg }), /must stay/);
});


test('legacy CSP origins do not grant native credentials or break codegen', () => {
  const { root, cfg } = fixture();
  cfg.web.connect = ['https://analytics.example.test/collect', 'https://maps.example.test'];
  codegen({ root, cfg });
  const config = readFileSync(join(root, cfg.host.dir, 'lib', 'valence', 'config.g.dart'), 'utf8');
  assert.match(config, /httpOrigins: \{\}/);
  assert.ok(!config.includes('analytics.example.test'));
  assert.ok(!config.includes('maps.example.test'));
});


test('notification builtins are frozen and compiled opt-in validates drawable names', () => {
  const { root, cfg } = fixture({ latest: true });
  cfg.notifications = { enabled: true, icon: 'ic_stat_demo' };
  const result = codegen({ root, cfg });
  const config = readFileSync(join(root, cfg.host.dir, 'lib', 'valence', 'config.g.dart'), 'utf8');
  assert.match(config, /notificationsEnabled: true/);
  assert.match(config, /notificationIcon: 'ic_stat_demo'/);
  cfg.notifications.icon = '../secret';
  assert.throws(() => codegen({ root, cfg }), /notifications accepts/);
  cfg.notifications.icon = 'ic_stat_demo';
  editSchema(root, (s) => { s.methods['notify.schedule'].params.at = 'string'; });
  assert.throws(() => codegen({ root, cfg }), /params must stay/);
});


test('pre-schema-5 custom notification names retain app-owned shapes', () => {
  const { root, cfg, key } = fixture();
  editSchema(root, (s) => { s.methods['notify.schedule'] = { since: 1, params: { hour: 'int' }, returns: 'void' }; });
  codegen({ root, cfg });
  const source = readFileSync(join(root, cfg.host.dir, 'lib', 'valence', 'bridge.g.dart'), 'utf8');
  assert.match(source, /Future<void> notifySchedule/);
  assert.doesNotMatch(source, /valence.notifications.schedule/);
  // Freezing that old signature remains enforced by the additive baseline.
  bundle({ root, cfg, key, store: true, now: NOW });
  editSchema(root, (s) => { s.methods['notify.schedule'].params.hour = 'string'; });
  assert.throws(() => codegen({ root, cfg }), /changed|additive|shipped/);
});
