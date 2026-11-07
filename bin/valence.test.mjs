// node --test bin/valence.test.mjs
import {
  mkdirSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
  rmSync,
} from 'node:fs';
import test from 'node:test';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execSync, spawnSync } from 'node:child_process';

import { VALENCE_VERSION } from '../.claude/skills/valence/scripts/valence.mjs';
import { run, doctor, detectWeb, detectHost, detectAppId, staleBridgeExports } from './valence.mjs';

const PKG = join(import.meta.dirname, '..');
// Real line endings, because the check reads a .d.ts line by line.
const EOL = String.fromCharCode(10);
const write = (file, text = '') => {
  mkdirSync(join(file, '..'), { recursive: true });
  writeFileSync(file, text);
};

// A pnpm SvelteKit app in web/ and an existing Flutter project in mobile/.
function project({ flutter = true } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'mrw-'));
  write(join(root, 'web', 'package.json'), JSON.stringify({ name: '@acme/trail-log', devDependencies: { '@sveltejs/kit': '^3.1.0', vite: '^8.0.0' } }));
  write(join(root, 'web', 'pnpm-lock.yaml'));
  write(join(root, 'web', 'src', 'routes', '+page.svelte'));
  write(join(root, 'web', 'node_modules', 'next', 'package.json'), JSON.stringify({ name: 'next', dependencies: { next: '1' } }));
  if (flutter) {
    write(join(root, 'mobile', 'pubspec.yaml'), 'name: trail\nflutter:\n  sdk: flutter\n');
    write(join(root, 'mobile', 'lib', 'main.dart'), 'void main() {}\n');
    // A Flutter plugin (no lib/main.dart) must not be taken for the app.
    write(join(root, 'packages', 'plugin', 'pubspec.yaml'), 'name: plugin\nflutter:\n  plugin: {}\n');
    write(join(root, 'mobile', 'android', 'app', 'build.gradle.kts'), 'android {\n  defaultConfig {\n    applicationId = "com.acme.trail"\n  }\n}\n');
  }
  return { root, keyDir: mkdtempSync(join(tmpdir(), 'mrw-keys-')) };
}

const quiet = async (fn) => {
  const log = console.log;
  console.log = () => {};
  try {
    return await fn();
  } finally {
    console.log = log;
  }
};

/** Like `quiet`, but hands back what was printed. */
const captured = async (fn) => {
  const log = console.log;
  const lines = [];
  console.log = (...a) => lines.push(a.join(' '));
  try {
    await fn();
  } finally {
    console.log = log;
  }
  return lines.join('\n');
};

test('dev options before the command pass through to the CLI', async () => {
  await assert.doesNotReject(() => quiet(() => run(['--web-dir', 'web', '--port', '5173', '--device-host', 'localhost', 'dev', '--help'])));
});

test('detects the web app, package manager, Flutter host and app id', () => {
  const { root } = project();
  const [web, ...rest] = detectWeb(root);
  assert.equal(rest.length, 0, 'node_modules is skipped');
  assert.deepEqual(
    { dir: web.dir, framework: web.framework, pm: web.pm, out: web.out, lib: web.lib, routes: web.routes },
    { dir: 'web', framework: 'SvelteKit', pm: 'pnpm', out: 'web/build', lib: 'web/src/lib/valence', routes: 'web/src/routes' },
  );
  assert.equal(detectHost(root), 'mobile');
  assert.equal(detectAppId(root, 'mobile', web.name), 'com.acme.trail');
  assert.equal(detectAppId(root, undefined, '@acme/trail-log'), 'com.traillog.app');
  assert.equal(detectAppId(root, undefined, '9lives'), 'com.app9lives.app');
});

test('init sets up config, CLI, skill, agents, keys and generated code, and is idempotent', async () => {
  const { root, keyDir } = project();
  const args = ['--root', root, '--yes', '--no-launch', '--key-dir', keyDir];
  await quiet(() => run(args));

  const cfg = JSON.parse(readFileSync(join(root, 'valence', 'valence.config.json'), 'utf8'));
  assert.equal(cfg.appId, 'com.acme.trail');
  assert.deepEqual(cfg.web, { out: 'web/build', lib: 'web/src/lib/valence', routes: 'web/src/routes', entry: 'index.html', connect: [] });
  assert.equal(cfg.host.dir, 'mobile');
  assert.ok(readFileSync(join(root, 'valence', 'valence.mjs')).equals(readFileSync(join(PKG, '.claude', 'skills', 'valence', 'scripts', 'valence.mjs'))));
  for (const f of [
    '.claude/skills/valence/SKILL.md',
    '.claude/skills/valence/references/contracts.md',
    '.claude/agents/valence-reviewer.md',
    'valence/bridge.schema.json',
    'valence/keyring.json',
    'web/src/lib/valence/bridge.g.ts',
    'mobile/lib/valence/bridge.g.dart',
    'mobile/lib/valence/config.g.dart',
  ]) assert.ok(existsSync(join(root, f)), f);
  // The runtimes are packages now, so init declares the web one rather than copying a client in.
  assert.ok(!existsSync(join(root, 'web', 'src', 'lib', 'valence', 'client.ts')), 'no client is copied');
  const webPkg = JSON.parse(readFileSync(join(root, 'web', 'package.json'), 'utf8'));
  assert.match(webPkg.dependencies['@getvalence/bridge'], /^\^\d+\.\d+\.\d+/);
  assert.equal(webPkg.devDependencies['@sveltejs/kit'], '^3.1.0', 'their own dependencies are left alone');
  assert.ok(!existsSync(join(root, '.claude', 'skills', 'valence', 'scripts', 'valence.test.mjs')), 'tests are not installed');
  assert.ok(existsSync(join(keyDir, 'com.acme.trail.k1.pem')));

  await quiet(() => run(args)); // second run: no keygen error, no duplicate lines
  const attrs = readFileSync(join(root, '.gitattributes'), 'utf8');
  assert.equal(attrs.split('mobile/assets/valence/** -text').length, 2);
  assert.equal(readFileSync(join(root, '.gitignore'), 'utf8').split('.valence/dist-ota/').length, 2);
});

test('locally edited skill files are kept by init and replaced by update', async () => {
  const { root, keyDir } = project();
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  const skill = join(root, '.claude', 'skills', 'valence', 'SKILL.md');
  writeFileSync(skill, 'edited');
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  assert.equal(readFileSync(skill, 'utf8'), 'edited');
  await quiet(() => run(['update', '--root', root]));
  assert.notEqual(readFileSync(skill, 'utf8'), 'edited');
});

test('init without a Flutter project derives the app id and defaults the host to mobile/', async () => {
  const { root, keyDir } = project({ flutter: false });
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  const cfg = JSON.parse(readFileSync(join(root, 'valence', 'valence.config.json'), 'utf8'));
  assert.equal(cfg.appId, 'com.traillog.app');
  assert.equal(cfg.host.dir, 'mobile');
});

test('init refuses a folder with no web app', async () => {
  const root = mkdtempSync(join(tmpdir(), 'mrw-empty-'));
  await assert.rejects(quiet(() => run(['--root', root, '--yes', '--no-launch'])), /no web app found/);
});

test('doctor passes on a fresh setup (only warnings for not-yet-built things)', async () => {
  const { root, keyDir } = project();
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  const rows = await quiet(() => doctor({ root, keyDir }));
  assert.deepEqual(rows.filter(([s]) => s === 'FAIL'), []);
  assert.ok(rows.some(([s, name]) => s === 'WARN' && name === 'built-in bundle'));
  process.exitCode = 0;
});

test('CLI commands pass through to valence.mjs, and versions agree', () => {
  assert.equal(execSync(`node "${join(PKG, 'bin', 'valence.mjs')}" version`, { encoding: 'utf8' }).trim(), VALENCE_VERSION);
  assert.equal(JSON.parse(readFileSync(join(PKG, 'package.json'), 'utf8')).version, VALENCE_VERSION);
});

test('both doctor entry points exit nonzero with a fix for a broken mechanical setup', async () => {
  const { root, keyDir } = project();
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  const configPath = join(root, 'valence', 'valence.config.json');
  const cfg = JSON.parse(readFileSync(configPath, 'utf8'));
  cfg.host.database = '../wrong.db';
  writeFileSync(configPath, JSON.stringify(cfg));
  for (const cli of [join(PKG, 'bin', 'valence.mjs'), join(root, 'valence', 'valence.mjs')]) {
    const result = spawnSync(process.execPath, [cli, 'doctor', '--root', root], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert.match(result.stdout, /database directory/);
    assert.match(result.stdout, /Fix:/);
    // C F-43: both entry points narrate themselves on stderr while they run, so a doctor killed by a
    // CI timeout still names the check it was on — and stdout stays the document/table it already was.
    assert.match(result.stderr, /doctor: running database directory/);
    assert.ok(result.stderr.split('\n').some((l) => l.startsWith('doctor: FAIL database directory (') && l.includes(' ms) host.database must be a plain file name')), result.stderr);
    assert.doesNotMatch(result.stdout, /doctor: running /);
  }
  // Both entry points take the child budget too, and both refuse one that bounds nothing: `0` is
  // `spawnSync`'s "no timeout", which is the unattributable hang the bound exists to prevent (C F-43).
  for (const cli of [join(PKG, 'bin', 'valence.mjs'), join(root, 'valence', 'valence.mjs')]) {
    const bad = spawnSync(process.execPath, [cli, 'doctor', '--root', root, '--timeout', '0'], { encoding: 'utf8' });
    assert.equal(bad.status, 1);
    assert.ok(`${bad.stdout}${bad.stderr}`.includes('--timeout must be an integer in [1, 3600], got 0'), bad.stderr);
    // And refused before the first check, not after a table's worth of them: this entry point runs its
    // own fast checks ahead of the shared ones, so nothing may stream before the flag is rejected.
    assert.doesNotMatch(bad.stderr, /doctor: running /);
    assert.equal(bad.stdout, '');
    // And an *accepted* budget has to be seen to reach the shared checks. Without this, dropping the
    // forward from this entry point leaves a run that validates 600 and then bounds every child at 180:
    // consistent, silent, and the row reports the wrong number.
    const ok = spawnSync(process.execPath, [cli, 'doctor', '--root', root, '--timeout', '600'], { encoding: 'utf8' });
    assert.match(ok.stderr, /doctor: child budget 600s/);
  }
});

test('the runtime version the wizard declares matches all runtime packages in this repo', () => {
  // The wizard writes "@getvalence/bridge": "^<RUNTIME_VERSION>" into an app's package.json, and the
  // skill tells the builder to run "flutter pub add valence". Both have to name a version that exists.
  const declared = readFileSync(join(PKG, 'bin', 'valence.mjs'), 'utf8').match(/RUNTIME_VERSION = '([^']+)'/)[1];
  const bridge = JSON.parse(readFileSync(join(PKG, 'packages', 'bridge', 'package.json'), 'utf8')).version;
  assert.equal(bridge, declared, 'packages/bridge');
  const pubspec = readFileSync(join(PKG, 'packages', 'valence', 'pubspec.yaml'), 'utf8');
  assert.equal(pubspec.match(/^version: (.+)$/m)[1].trim(), declared, 'packages/valence');
  const push = readFileSync(join(PKG, 'packages', 'valence_push', 'pubspec.yaml'), 'utf8');
  assert.equal(push.match(/^version: (.+)$/m)[1].trim(), declared, 'packages/valence_push');
});

test('the example vendors the skill’s CLI byte for byte, so the reference app cannot run a different generator', () => {
  // `packages/valence/example` is the repo's own Valence app, and like every app it vendors
  // `valence/valence.mjs`. Nothing compared the two copies, and `VALENCE_VERSION` is equal in both
  // whatever they contain — so the skill's copy gained a line in one merge and the example's did not,
  // which is exactly the stale-vendored-CLI state K F-62 reports from the other side. Inert while the
  // drift is a comment; the next one generates different Dart in the app the gates are run against.
  const skill = readFileSync(join(PKG, '.claude', 'skills', 'valence', 'scripts', 'valence.mjs'), 'utf8');
  const vendored = readFileSync(join(PKG, 'packages', 'valence', 'example', 'valence', 'valence.mjs'), 'utf8');
  assert.equal(
    vendored,
    skill,
    'packages/valence/example/valence/valence.mjs has drifted; re-copy .claude/skills/valence/scripts/valence.mjs over it',
  );
});

test('packing the bridge rebuilds dist, so a tarball can never ship stale compiled types', () => {
  // K F-52: packages/bridge ships `files: ["dist"]`, and dist/ is gitignored build output. From
  // 2026-10-17 to 2026-10-27 nobody ran `npm run build` there, so every `npm pack` — the release
  // recipe's and the test harness's — tarballed a ten-day-old dist under the current version. An app
  // generated against the new codegen got `createBridge(METHOD_SINCE, EVENT_SINCE)` and a package
  // declaring one parameter: a TS2554 in generated code, and silently `has(<any event>) === false`
  // at runtime if it was suppressed. A `prepack` hook is what makes the build un-skippable; this
  // test is what stops the hook being dropped again.
  const bridge = join(PKG, 'packages', 'bridge');
  const dts = join(bridge, 'dist', 'index.d.ts');
  write(dts, 'export declare const STALE: true;\n');
  const dest = mkdtempSync(join(tmpdir(), 'mrw-pack-'));
  execSync('npm pack --pack-destination ' + JSON.stringify(dest), { cwd: bridge, stdio: 'pipe' });
  const version = JSON.parse(readFileSync(join(bridge, 'package.json'), 'utf8')).version;
  // The basename, not the full path: tar reads "C:" in an absolute Windows path as a remote host.
  execSync(`tar -xzf getvalence-bridge-${version}.tgz`, { cwd: dest, stdio: 'pipe' });
  const packed = readFileSync(join(dest, 'package', 'dist', 'index.d.ts'), 'utf8');
  assert.doesNotMatch(packed, /STALE/, 'npm pack shipped the stale dist it found instead of rebuilding it');
  assert.match(packed, /export declare function createBridge/, 'packed types are not the bridge');
  // The surface the generated bridge.g.ts actually calls, which is what F-52 was missing.
  assert.match(packed, /eventSince/, 'packed types predate event gating');
  assert.doesNotMatch(readFileSync(dts, 'utf8'), /STALE/, 'prepack left the working dist stale');
});

test('the npm package ships the wizard, skill and agents, and no tests', () => {
  const [{ files }] = JSON.parse(execSync('npm pack --dry-run --json', { cwd: PKG, encoding: 'utf8' }));
  const paths = files.map((f) => f.path);
  for (const p of ['bin/valence.mjs', '.claude/skills/valence/SKILL.md', '.claude/skills/valence/scripts/valence.mjs', '.claude/agents/valence-builder.md', 'package.json']) {
    assert.ok(paths.includes(p), `missing ${p}`);
  }
  assert.ok(!paths.some((p) => p.endsWith('.test.mjs')), `tests packed: ${paths.filter((p) => p.endsWith('.test.mjs'))}`);
  const agents = paths.filter((p) => p.startsWith('.claude/agents/'));
  assert.ok(agents.length && agents.every((p) => p.startsWith('.claude/agents/valence-')), `only valence agents ship: ${agents}`);
});

test('a root-level Flutter host gets a .gitattributes rule git actually applies', async () => {
  const { root, keyDir } = project({ flutter: false });
  execSync('git init -q', { cwd: root });
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir, '--host', '.']));
  const attrs = readFileSync(join(root, '.gitattributes'), 'utf8');
  assert.match(attrs, /^assets\/valence\/\*\* -text$/m);
  assert.ok(!attrs.includes('./'), attrs);
  const out = execSync('git check-attr text -- assets/valence/builtin/manifest.json', { cwd: root, encoding: 'utf8' });
  assert.match(out, /text: unset/);
});

test('--web and --host are normalised to project-relative POSIX paths', async () => {
  const { root, keyDir } = project();
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir, '--web', join(root, 'web') + '\\', '--host', './mobile/']));
  const cfg = JSON.parse(readFileSync(join(root, 'valence', 'valence.config.json'), 'utf8'));
  assert.equal(cfg.web.out, 'web/build');
  assert.equal(cfg.host.dir, 'mobile');
  const other = project();
  await assert.rejects(quiet(() => run(['--root', other.root, '--yes', '--no-launch', '--host', '..'])), /outside the project root/);
});

test('monorepos: Vite needs an index.html, candidates sort by framework, and several apps need --web without a prompt', async () => {
  const { root } = project();
  write(join(root, 'package.json'), JSON.stringify({ name: 'mono', devDependencies: { vite: '^8' } }));
  write(join(root, 'apps', 'rr', 'package.json'), JSON.stringify({ name: 'rr', dependencies: { vite: '^8', 'react-router': '^7' } }));
  assert.deepEqual(detectWeb(root).map((w) => w.dir), ['web'], 'vite without index.html (monorepo root, React Router) is not a candidate');
  write(join(root, 'index.html'), '<!doctype html>');
  assert.deepEqual(detectWeb(root).map((w) => w.dir), ['web', '.'], 'SvelteKit sorts before plain Vite');
  await assert.rejects(quiet(() => run(['--root', root, '--yes', '--no-launch'])), /found 2 web apps; pass --web/);
});

test('Next.js without output: export is flagged', () => {
  const root = mkdtempSync(join(tmpdir(), 'mrw-next-'));
  write(join(root, 'package.json'), JSON.stringify({ name: 'n', dependencies: { next: '^16' } }));
  write(join(root, 'next.config.mjs'), 'export default {};');
  assert.equal(detectWeb(root)[0].staticExport, false);
  write(join(root, 'next.config.mjs'), "export default { output: 'export' };");
  assert.equal(detectWeb(root)[0].staticExport, true);
});

test('update: hash-tracked installs, safe pruning, backups only for files the user edited', async () => {
  const { root, keyDir } = project();
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  const claude = join(root, '.claude');
  const skillDir = join(claude, 'skills', 'valence');
  const manifestPath = join(skillDir, '.installed.json');
  const m = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const hash = (s) => createHash('sha256').update(s).digest('hex');

  // An older version shipped two files this version drops: one untouched, one the user edited.
  write(join(skillDir, 'old-untouched.md'), 'v1');
  write(join(skillDir, 'old-edited.md'), 'v1 plus my notes');
  // An untouched copy of an older SKILL.md (hash matches its record) and an edited reviewer agent.
  writeFileSync(join(skillDir, 'SKILL.md'), 'old skill');
  writeFileSync(join(claude, 'agents', 'valence-reviewer.md'), 'my reviewer');
  // The user's own files (never recorded) and crafted entries that try to escape .claude.
  const mine = [join(skillDir, 'references', 'our-notes.md'), join(claude, 'agents', 'valence-ourhelper.md'), join(claude, 'agents', 'team', 'valence-x.md')];
  for (const f of mine) write(f, 'ours');
  const victims = [join(root, 'victim.txt'), join(root, 'escape.md')];
  for (const f of victims) write(f, 'outside');
  writeFileSync(manifestPath, JSON.stringify({
    ...m,
    files: {
      ...m.files,
      'skills/valence/SKILL.md': hash('old skill'),
      'skills/valence/old-untouched.md': hash('v1'),
      'skills/valence/old-edited.md': hash('v1'),
      'skills/valence/..\\..\\..\\victim.txt': hash('outside'),
      'agents/../../escape.md': hash('outside'),
    },
  }));
  writeFileSync(join(root, '.gitattributes'), '');

  const said = await captured(() => run(['update', '--root', root]));
  // The count alone let an unchanged `version --build` digest and a rewritten spec land in one update
  // (K F-84), so every refreshed file is named and the normative two are marked.
  assert.match(said, /updated\s+\S*\/skills\/valence\/SKILL\.md — this is the spec; read what changed/);
  assert.ok(!existsSync(join(skillDir, 'old-untouched.md')), 'untouched dropped file is removed');
  assert.equal(readFileSync(join(skillDir, 'old-edited.md.bak'), 'utf8'), 'v1 plus my notes', 'edited dropped file is kept as .bak');
  assert.ok(!existsSync(join(skillDir, 'SKILL.md.bak')), 'untouched older file is updated without a backup');
  assert.notEqual(readFileSync(join(skillDir, 'SKILL.md'), 'utf8'), 'old skill');
  assert.equal(readFileSync(join(claude, 'agents', 'valence-reviewer.md.bak'), 'utf8'), 'my reviewer', 'edited file is backed up when replaced');
  for (const f of [...mine, ...victims]) assert.ok(existsSync(f), `kept ${f}`);
  assert.match(readFileSync(join(root, '.gitattributes'), 'utf8'), /mobile\/assets\/valence\/\*\* -text/);
  await run(['--root', root, 'codegen', '--check']); // passthrough with options before the command
});

test('CRLF checkouts are not mistaken for edits, and a broken manifest is recovered', async () => {
  const { root, keyDir } = project();
  const args = ['--root', root, '--yes', '--no-launch', '--key-dir', keyDir];
  await quiet(() => run(args));
  const crlf = (f) => writeFileSync(f, readFileSync(f, 'utf8').replace(/\n/g, '\r\n'));
  const skill = join(root, '.claude', 'skills', 'valence', 'SKILL.md');
  const valencePath = join(root, 'valence', 'valence.mjs');
  crlf(skill);
  crlf(valencePath);
  writeFileSync(join(root, '.claude', 'skills', 'valence', '.installed.json'), '<<<<<<< HEAD\n{}\n=======\n');
  const ts = join(root, 'web', 'src', 'lib', 'valence', 'bridge.g.ts');
  writeFileSync(ts, 'stale');
  await quiet(() => run(args)); // must not throw on the broken manifest
  assert.equal(readFileSync(ts, 'utf8').startsWith('// GENERATED'), true, 'CRLF valence.mjs is "same", so codegen runs');
  await quiet(() => run(['update', '--root', root]));
  assert.ok(!existsSync(`${skill}.bak`), 'a CRLF copy is not treated as a user edit');
  assert.match(readFileSync(join(root, '.gitattributes'), 'utf8'), /^\.claude\/skills\/valence\/\*\* text eol=lf$/m);
});

test('flavoured Flutter templates (lib/main_development.dart) are detected as the host', () => {
  const root = mkdtempSync(join(tmpdir(), 'mrw-vgv-'));
  write(join(root, 'app', 'pubspec.yaml'), 'name: app\nflutter:\n  uses-material-design: true\n');
  write(join(root, 'app', 'lib', 'main_development.dart'), 'void main() {}\n');
  write(join(root, 'plugin', 'pubspec.yaml'), 'name: p\nflutter:\n  plugin:\n    platforms: {}\n');
  write(join(root, 'plugin', 'lib', 'main.dart'), '');
  assert.equal(detectHost(root), 'app');
});

test('an edited vendored valence.mjs is kept and codegen is skipped rather than run with a different generator', async () => {
  const { root, keyDir } = project();
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  const valencePath = join(root, 'valence', 'valence.mjs');
  writeFileSync(valencePath, readFileSync(valencePath, 'utf8') + '\n// local patch\n');
  const ts = join(root, 'web', 'src', 'lib', 'valence', 'bridge.g.ts');
  writeFileSync(ts, 'stale');
  await quiet(() => run(['--root', root, '--yes', '--no-launch', '--key-dir', keyDir]));
  assert.ok(readFileSync(valencePath, 'utf8').endsWith('// local patch\n'));
  assert.equal(readFileSync(ts, 'utf8'), 'stale');
});

// K F-82: `update` refreshes the generator and regenerates against it, but it cannot install the npm
// half of the same snapshot — so a clean run could hand back a bridge.g.ts importing a name the
// installed build has never exported, and the first tsc blamed the generated file. Names, not
// versions: the mismatch that actually happens is a rebuilt package at an unchanged version.
test('update names what the installed bridge does not export, not what version it claims', () => {
  const root = mkdtempSync(join(tmpdir(), 'mrw-stale-'));
  const cfg = { web: { lib: 'web/src/lib' } };
  write(join(root, 'web', 'package.json'), JSON.stringify({ name: '@acme/trail-log' }));
  write(join(root, 'web', 'src', 'lib', 'bridge.g.ts'), [
    "import { createBridge } from '@getvalence/bridge';",
    "import type { Json, Shim } from '@getvalence/bridge';",
    "export { BridgeError, inHost } from '@getvalence/bridge';",
    "export type { AppLink, ReceivedLink } from '@getvalence/bridge';",
  ].join(EOL));
  const dts = join(root, 'web', 'node_modules', '@getvalence', 'bridge', 'dist', 'index.d.ts');

  // Not installed at all is silent: codegen does not depend on the install, and `update` already
  // prints the install command for that case.
  assert.deepEqual(staleBridgeExports(root, cfg), []);

  // The exact F-82 build: everything but the two link types the F-79 fix added.
  const base = [
    'export type Json = null | boolean;',
    'export type Shim<M> = { [K in keyof M]: unknown };',
    'export declare class BridgeError extends Error {}',
    'export declare const inHost: () => boolean;',
    'export declare function createBridge<M, E>(): void;',
  ];
  write(dts, base.join(EOL));
  assert.deepEqual(staleBridgeExports(root, cfg).sort(), ['AppLink', 'ReceivedLink']);

  // And the matching build is silent, including names published through an `export { }` list.
  write(dts, [...base, 'interface AppLink { url: string }', 'export type { AppLink };',
    'export interface ReceivedLink extends AppLink { initial: boolean }'].join(EOL));
  assert.deepEqual(staleBridgeExports(root, cfg), []);

  // A hoisted install at the repo root is found too, which is what a workspace gives you.
  rmSync(join(root, 'web', 'node_modules'), { recursive: true });
  write(join(root, 'node_modules', '@getvalence', 'bridge', 'dist', 'index.d.ts'), base.join(EOL));
  assert.deepEqual(staleBridgeExports(root, cfg).sort(), ['AppLink', 'ReceivedLink']);
});
