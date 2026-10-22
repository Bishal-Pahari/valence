// node --test bin/valence.test.mjs
import {
  mkdirSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import test from 'node:test';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execSync, spawnSync } from 'node:child_process';

import { VALENCE_VERSION } from '../.claude/skills/valence/scripts/valence.mjs';
import { run, doctor, detectWeb, detectHost, detectAppId } from './valence.mjs';

const PKG = join(import.meta.dirname, '..');
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
  }
});

test('the runtime version the wizard declares matches the two packages in this repo', () => {
  // The wizard writes "@getvalence/bridge": "^<RUNTIME_VERSION>" into an app's package.json, and the
  // skill tells the builder to run "flutter pub add valence". Both have to name a version that exists.
  const declared = readFileSync(join(PKG, 'bin', 'valence.mjs'), 'utf8').match(/RUNTIME_VERSION = '([^']+)'/)[1];
  const bridge = JSON.parse(readFileSync(join(PKG, 'packages', 'bridge', 'package.json'), 'utf8')).version;
  assert.equal(bridge, declared, 'packages/bridge');
  const pubspec = readFileSync(join(PKG, 'packages', 'valence', 'pubspec.yaml'), 'utf8');
  assert.equal(pubspec.match(/^version: (.+)$/m)[1].trim(), declared, 'packages/valence');
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

  await quiet(() => run(['update', '--root', root]));
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
