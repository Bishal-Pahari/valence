#!/usr/bin/env node
// `npm create valence@latest`: sets up valence in this project, then hands off to Claude Code.
// Deterministic steps (detect, config, keys, codegen, skill install) run here; the AI steps run in `/valence init`.
import {
  rmSync,
  mkdirSync,
  existsSync,
  renameSync,
  readdirSync,
  readFileSync,
  realpathSync,
  writeFileSync,
  appendFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { parseArgs } from 'node:util';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';

import {
  keygen,
  codegen,
  diagnose,
  loadConfig,
  main as cli,
  verifyBundle,
  VALENCE_VERSION,
} from '../.claude/skills/valence/scripts/valence.mjs';

const PKG = join(dirname(fileURLToPath(import.meta.url)), '..');
// npm name from package.json, so renaming the package is a one-line change.
const NPM = JSON.parse(readFileSync(join(PKG, 'package.json'), 'utf8')).name;
const NPX = `npx ${NPM}@latest`;
const SKILL_SRC = join(PKG, '.claude', 'skills', 'valence');
const AGENTS_SRC = join(PKG, '.claude', 'agents');
const AGENT_PREFIX = 'valence-';
const CLI = new Set(['keygen', 'codegen', 'bundle', 'verify', 'pointer', 'seed', 'version', 'assetlinks', 'aasa']);
// The two published runtimes the generated code imports. Their version is deliberately independent of
// this CLI's: a fix to a runtime ships with "flutter pub upgrade" or "npm update", with no new wizard.
// A test keeps it equal to both packages/*/ versions in this repo.
const RUNTIME_VERSION = '0.4.0-beta.0';
const BRIDGE_PKG = '@getvalence/bridge';
const HOST_PKG = 'valence';
// pnpm, yarn and bun all take "add"; npm is the odd one.
const PM_ADD = { npm: 'install', pnpm: 'add', yarn: 'add', bun: 'add' };
// String options of both the wizard and valence.mjs, so the command word is found wherever it appears.
const STRING_OPTS = Object.fromEntries('root web host app-id ota sync key-dir channel seq rollout from manifest files key floor requires-bridge package fingerprints out'.split(' ').map((k) => [k, { type: 'string' }]));
// example/ and examples/ hold plugin demo apps, which must not be taken for the host.
const SKIP_DIRS = new Set(['node_modules', 'build', 'dist', 'out', 'android', 'ios', 'valence', 'vendor', 'target', 'example', 'examples']);
const APP_ID_RE = /^[a-zA-Z]\w*(\.[a-zA-Z]\w*)+$/;
const FRAMEWORKS = [
  { dep: '@sveltejs/kit', name: 'SvelteKit', out: 'build', routes: ['src/routes'], lib: 'src/lib/valence' },
  { dep: 'next', name: 'Next.js', out: 'out', routes: ['src/app', 'app', 'src/pages', 'pages'], lib: 'src/lib/valence' },
  { dep: 'astro', name: 'Astro', out: 'dist', routes: ['src/pages'], lib: 'src/lib/valence' },
  // Plain Vite SPA only: Vite-based frameworks (React Router, Remix, SolidStart) have no root index.html.
  { dep: 'vite', name: 'Vite', out: 'dist', routes: [], lib: 'src/valence', needs: 'index.html' },
];
const LOCKS = [['pnpm-lock.yaml', 'pnpm'], ['bun.lock', 'bun'], ['bun.lockb', 'bun'], ['yarn.lock', 'yarn'], ['package-lock.json', 'npm']];
// A root-level host must be written without "./": git ignores attribute patterns that start with it.
// The rest pins installed and generated text to LF, so Windows autocrlf checkouts don't look like local edits.
const gitattributes = (host) => [
  `${host === '.' ? '' : `${host}/`}assets/valence/** -text`,
  '*.g.dart text eol=lf',
  '*.g.ts text eol=lf',
  'valence/*.json text eol=lf',
  'valence/valence.mjs text eol=lf',
  '.claude/skills/valence/** text eol=lf',
  '.claude/agents/valence-*.md text eol=lf',
];

const color = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (code) => (s) => (color ? `\x1b[${code}m${s}\x1b[0m` : String(s));
const [bold, dim, green, yellow, red] = [paint(1), paint(2), paint(32), paint(33), paint(31)];
const say = (mark, label, text = '') => console.log(`  ${mark} ${label.padEnd(16)} ${text}`);
const ok = (label, text) => say(green('✓'), label, text);
const warn = (label, text) => say(yellow('!'), label, text);
const posix = (p) => p.split(sep).join('/');
const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const isUrl = (v) => {
  try {
    return ['https:', 'http:'].includes(new URL(v).protocol);
  } catch {
    return false;
  }
};

// A user-given directory as a POSIX path relative to the project root ("." for the root itself).
function projectPath(root, dir, flag) {
  const rel = posix(relative(root, resolve(root, dir))) || '.';
  if (rel === '..' || rel.startsWith('../') || isAbsolute(rel)) throw new Error(`${flag} ${dir} is outside the project root ${root}`);
  return rel;
}

// ---------- detection ----------

function dirsWith(root, file, depth = 2) {
  const out = [];
  const visit = (d, level) => {
    if (existsSync(join(d, file))) out.push(d);
    if (level === depth) return;
    let entries;
    try {
      entries = readdirSync(d, { withFileTypes: true });
    } catch {
      return; // unreadable (e.g. a root-owned Docker volume): skip it
    }
    for (const e of entries) {
      if (e.isDirectory() && !e.name.startsWith('.') && !SKIP_DIRS.has(e.name)) visit(join(d, e.name), level + 1);
    }
  };
  visit(root, 0);
  return out;
}

function inspectWeb(root, dir) {
  let pkg;
  try {
    pkg = readJson(join(dir, 'package.json'));
  } catch {
    return undefined;
  }
  const deps = { ...pkg.dependencies, ...pkg.devDependencies };
  const rank = FRAMEWORKS.findIndex((f) => deps[f.dep] && (!f.needs || existsSync(join(dir, f.needs))));
  if (rank < 0) return undefined;
  const fw = FRAMEWORKS[rank];
  const rel = posix(relative(root, dir)) || '.';
  const at = (p) => (rel === '.' ? p : `${rel}/${p}`);
  const routes = fw.routes.find((r) => existsSync(join(dir, r)));
  const pm = [dir, root].flatMap((d) => LOCKS.filter(([f]) => existsSync(join(d, f))).map(([, n]) => n))[0] ?? 'npm';
  const nextConfig = fw.dep === 'next' && readdirSync(dir).find((f) => /^next\.config\.(js|mjs|cjs|ts|mts)$/.test(f));
  const staticExport = fw.dep !== 'next' || (!!nextConfig && /output\s*:\s*["']export["']/.test(readFileSync(join(dir, nextConfig), 'utf8')));
  return { rank, dir: rel, framework: fw.name, version: String(deps[fw.dep]).replace(/^\D*/, ''), pm, name: pkg.name, out: at(fw.out), routes: routes && at(routes), lib: at(fw.lib), staticExport };
}

// Candidates ordered by framework specificity (SvelteKit before a monorepo root that merely lists vite), then path.
export function detectWeb(root) {
  return dirsWith(root, 'package.json')
    .map((d) => inspectWeb(root, d))
    .filter(Boolean)
    .sort((a, b) => a.rank - b.rank || a.dir.localeCompare(b.dir));
}

// A Flutter app, not a package or plugin: a flutter section without plugin:, plus an entry point
// (lib/main*.dart, which covers flavoured templates like main_development.dart) or a platform folder.
const isFlutterApp = (d) => {
  const pubspec = readFileSync(join(d, 'pubspec.yaml'), 'utf8');
  if (!/^flutter:/m.test(pubspec) || /^\s+plugin:/m.test(pubspec)) return false;
  const lib = join(d, 'lib');
  return (existsSync(lib) && readdirSync(lib).some((f) => /^main.*\.dart$/.test(f))) || existsSync(join(d, 'android')) || existsSync(join(d, 'ios'));
};

export function detectHost(root) {
  const dir = dirsWith(root, 'pubspec.yaml').find(isFlutterApp);
  return dir === undefined ? undefined : posix(relative(root, dir)) || '.';
}

export function detectAppId(root, host, webName) {
  if (host) {
    for (const f of ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
      const p = join(root, host, f);
      const m = existsSync(p) && readFileSync(p, 'utf8').match(/applicationId\s*=?\s*["']([\w.]+)["']/);
      if (m) return m[1];
    }
    const pbx = join(root, host, 'ios', 'Runner.xcodeproj', 'project.pbxproj');
    const ids = existsSync(pbx) ? [...readFileSync(pbx, 'utf8').matchAll(/PRODUCT_BUNDLE_IDENTIFIER = "?([\w.]+)"?;/g)].map((m) => m[1]) : [];
    const id = ids.find((i) => !i.endsWith('Tests'));
    if (id) return id;
  }
  const slug = String(webName ?? 'app').replace(/^@[^/]+\//, '').toLowerCase().replace(/[^a-z0-9]+/g, '');
  return `com.${/^[a-z]/.test(slug) ? slug : `app${slug}`}.app`;
}

// The web app's package.json, found by walking up from the directory the generated client goes in: the
// config records where generated files land, not where the web project root is.
function webPackageJson(root, cfg) {
  let dir = join(root, cfg.web.lib);
  for (;;) {
    if (existsSync(join(dir, 'package.json'))) return join(dir, 'package.json');
    const up = dirname(dir);
    if (up === dir || !up.startsWith(root)) return undefined;
    dir = up;
  }
}

/**
 * Declares @getvalence/bridge in the web app's package.json.
 *
 * The runtime used to be copied in as client.ts, which meant every app carried its own copy and a fix
 * reached nobody. Declaring it is what makes the generated bridge.g.ts importable.
 *
 * ponytail: the dependency is declared, not installed. Running a package manager from inside an npx
 * wizard is slow, needs the network, and fights whatever install the user is about to run anyway — so
 * the install command is printed instead, and codegen does not depend on it having happened.
 */
export function addBridgeDependency(root, cfg) {
  const file = webPackageJson(root, cfg);
  if (file === undefined) return { file };
  const raw = readFileSync(file, 'utf8');
  const pkg = JSON.parse(raw);
  const had = pkg.dependencies?.[BRIDGE_PKG] ?? pkg.devDependencies?.[BRIDGE_PKG];
  if (had !== undefined) return { file, had };
  const range = `^${RUNTIME_VERSION}`;
  pkg.dependencies = { ...pkg.dependencies, [BRIDGE_PKG]: range };
  // Their indentation, not ours: this is a file the project owns and reads in diffs.
  writeFileSync(file, JSON.stringify(pkg, null, raw.match(/^[ \t]+/m)?.[0] ?? 2) + '\n');
  return { file, added: range };
}

// The lockfile nearest the web app wins, then the repo root's, then npm.
function packageManager(root, pkgFile) {
  const dirs = [pkgFile === undefined ? root : dirname(pkgFile), root];
  return dirs.flatMap((d) => LOCKS.filter(([f]) => existsSync(join(d, f))).map(([, n]) => n))[0] ?? 'npm';
}

function tool(cmd, cwd) {
  const r = spawnSync(cmd, { cwd, shell: true, encoding: 'utf8', timeout: 60_000 });
  return r.status === 0 ? `${r.stdout || r.stderr}`.trim().split(/\r?\n/)[0] : undefined;
}

// ---------- file helpers ----------

const listFiles = (dir, { filter = () => true, recursive = true } = {}) =>
  readdirSync(dir, { recursive, withFileTypes: true })
    .filter((e) => e.isFile() && !e.name.endsWith('.test.mjs') && filter(e.name))
    .map((e) => posix(relative(dir, join(e.parentPath, e.name))));

// The vendored valence.mjs: identical = skip, missing = write, different = keep unless forced (it is tracked in the project's git).
const lf = (buf) => Buffer.from(buf.toString('utf8').replace(/\r\n/g, '\n'));

function syncFile(src, dst, force) {
  const bytes = readFileSync(src);
  if (existsSync(dst)) {
    if (lf(readFileSync(dst)).equals(lf(bytes))) return 'same';
    if (!force) return 'kept';
    writeFileSync(dst, bytes);
    return 'replaced';
  }
  mkdirSync(dirname(dst), { recursive: true });
  writeFileSync(dst, bytes);
  return 'written';
}

// Everything installed is text: compare and hash with CRLF folded to LF, so line-ending churn is not an "edit".
const sha = (buf) => createHash('sha256').update(lf(buf)).digest('hex');
const MANIFEST = 'skills/valence/.installed.json';
// Paths the installer may ever touch: plain names only (no \ : or dot segments), under its own directories.
const OWNED = /^(skills\/valence(\/[A-Za-z0-9_][\w.-]*)+|agents\/valence-[\w.-]+)$/;
const owned = (base, rel) => {
  if (typeof rel !== 'string' || !OWNED.test(rel) || rel.split('/').some((s) => s === '.' || s === '..')) return false;
  const r = relative(base, resolve(base, rel));
  return r !== '' && !r.startsWith('..') && !isAbsolute(r);
};

// Everything the package installs under a .claude base: base-relative POSIX path → source file.
const shippedFiles = () =>
  new Map([
    ...listFiles(SKILL_SRC).map((f) => [`skills/valence/${f}`, join(SKILL_SRC, f)]),
    ...listFiles(AGENTS_SRC, { recursive: false, filter: (n) => n.startsWith(AGENT_PREFIX) }).map((f) => [`agents/${f}`, join(AGENTS_SRC, f)]),
  ]);

// Installs the skill and agents. The manifest records the sha256 of every file as installed, so a file on disk
// whose hash differs from its record was edited by the user: it is kept (or, when forced, backed up to .bak).
// Untouched files are updated silently. With prune, files a previous install recorded that this version no longer
// ships are removed if untouched, or renamed to .bak if edited. Files the user added are never in the record.
function installSkill(base, force, prune) {
  const r = { written: 0, same: 0, updated: 0, replaced: [], kept: [], removed: [], backedUp: [] };
  const manifestPath = join(base, MANIFEST);
  let prevRaw;
  try {
    prevRaw = existsSync(manifestPath) ? readJson(manifestPath).files : undefined;
  } catch {
    r.manifestBroken = posix(manifestPath); // e.g. a merge conflict: treat every existing file as possibly edited
  }
  const prev = prevRaw && !Array.isArray(prevRaw) && typeof prevRaw === 'object' ? prevRaw : {};
  const files = {};
  for (const [rel, src] of shippedFiles()) {
    const bytes = readFileSync(src);
    const dst = join(base, rel);
    const shown = posix(dst);
    files[rel] = sha(bytes);
    if (!existsSync(dst)) {
      mkdirSync(dirname(dst), { recursive: true });
      writeFileSync(dst, bytes);
      r.written++;
      continue;
    }
    const disk = readFileSync(dst);
    if (lf(disk).equals(lf(bytes))) {
      r.same++;
      continue;
    }
    if (prev[rel] === sha(disk)) {
      writeFileSync(dst, bytes); // untouched copy of an older version
      r.updated++;
    } else if (force) {
      writeFileSync(`${dst}.bak`, disk);
      writeFileSync(dst, bytes);
      r.replaced.push(shown);
    } else {
      files[rel] = prev[rel] ?? files[rel]; // keep treating it as edited next time
      r.kept.push(shown);
    }
  }
  if (prune) {
    for (const [rel, hash] of Object.entries(prev)) {
      const dst = join(base, rel);
      if (Object.hasOwn(files, rel) || !owned(base, rel) || !existsSync(dst)) continue;
      if (sha(readFileSync(dst)) === hash) {
        rmSync(dst);
        r.removed.push(posix(dst));
      } else {
        renameSync(dst, `${dst}.bak`);
        r.backedUp.push(posix(dst));
      }
    }
  }
  mkdirSync(dirname(manifestPath), { recursive: true });
  writeFileSync(manifestPath, JSON.stringify({ version: VALENCE_VERSION, files }, null, 2) + '\n');
  return r;
}

// Where the skill lives now: project .claude, else ~/.claude, else wherever --global says.
const skillBase = (root, global) =>
  [join(root, '.claude'), join(homedir(), '.claude')].find((b) => existsSync(join(b, 'skills', 'valence', 'SKILL.md'))) ??
  (global ? join(homedir(), '.claude') : join(root, '.claude'));

function writeIfMissing(file, content) {
  if (existsSync(file)) return false;
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, content);
  return true;
}

function ensureLines(file, lines) {
  const have = existsSync(file) ? readFileSync(file, 'utf8') : '';
  const present = new Set(have.split(/\r?\n/).map((l) => l.trim()));
  const missing = lines.filter((l) => !present.has(l));
  if (missing.length) appendFileSync(file, (have && !have.endsWith('\n') ? '\n' : '') + missing.join('\n') + '\n');
  return missing.length;
}

const vendoredVersion = (file) => (existsSync(file) ? readFileSync(file, 'utf8').match(/VALENCE_VERSION = '([^']+)'/)?.[1] : undefined);
const interactive = () => !!process.stdin.isTTY;

// ---------- prompts ----------

function makeAsk(yes) {
  if (yes || !interactive()) return Object.assign(async (_q, def) => def, { close() {} });
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  let open = true;
  // Ctrl+C / Ctrl+D closes readline and would leave the pending question hanging; turn it into an error.
  const closed = new Promise((_, reject) => rl.once('close', () => reject(Object.assign(new Error('cancelled'), { code: 'ABORT' }))));
  closed.catch(() => {});
  const ask = async (q, def) => (await Promise.race([rl.question(`  ${bold('?')} ${q}${def ? dim(` (${def})`) : ''}: `), closed])).trim() || def;
  return Object.assign(ask, { close: () => open && !(open = false) && rl.close() });
}

async function askValid(ask, q, def, valid, hint) {
  for (let i = 0; i < 3; i++) {
    const v = await ask(q, def);
    if (valid(v)) return v;
    console.log(`    ${red(hint)}`);
  }
  throw new Error(`no valid answer for "${q}"`);
}

// ---------- commands ----------

async function chooseWeb(root, o, ask) {
  if (o.web) {
    const dir = projectPath(root, o.web, '--web');
    const web = inspectWeb(root, join(root, dir));
    if (!web) throw new Error(`no SvelteKit, Next.js, Astro or Vite app in ${dir}`);
    return web;
  }
  const webs = detectWeb(root);
  if (!webs.length) throw new Error('no web app found here or two levels down (SvelteKit, Next.js static export, Astro or Vite). Run this from your project root, or pass --web <dir>.');
  if (webs.length === 1) return webs[0];
  const list = webs.map((w, i) => `    ${i + 1}. ${w.dir}  ${dim(w.framework)}`).join('\n');
  if (o.yes || !interactive()) throw new Error(`found ${webs.length} web apps; pass --web <dir> to pick one:\n${list}`);
  console.log(list);
  return webs[Number(await ask(`Which web app? 1-${webs.length}`, '1')) - 1] ?? webs[0];
}

async function init(o) {
  const root = resolve(o.root);
  console.log(`\n${bold('Valence')} ${VALENCE_VERSION}  ${dim('Flutter host · signed OTA web UI · offline-first data')}\n`);

  const cfgPath = join(root, 'valence', 'valence.config.json');
  const ask = makeAsk(o.yes);
  try {
    let cfg;
    if (existsSync(cfgPath)) {
      cfg = loadConfig(root);
      ok('config', `using valence/valence.config.json (${cfg.appId})`);
    } else {
      const web = await chooseWeb(root, o, ask);
      const existingHost = detectHost(root);
      const host = o.host === undefined ? (existingHost ?? 'mobile') : projectPath(root, o.host, '--host');
      const git = tool('git status --porcelain', root) !== undefined;
      console.log(bold('  Detected'));
      ok('web app', `${web.dir}  ${web.framework} ${web.version} · ${web.pm} · builds to ${web.out}`);
      if (!web.staticExport) warn('next.js', `no output: 'export' in next.config; add it so the build writes ${web.out}/ (valence needs static files)`);
      say(existingHost ? green('✓') : dim('·'), 'flutter host', existingHost ? `${existingHost}/` : `${host}/ (Claude creates it)`);
      say(git ? green('✓') : yellow('!'), 'git', git ? 'repository found' : 'not a git repo (recommended before generating code)');
      if (!interactive() && !o.yes) warn('prompts', 'no terminal: using detected defaults (pass --app-id/--ota/--sync to set them)');
      console.log();

      const appId = await askValid(ask, 'App id', o.appId ?? detectAppId(root, existingHost, web.name), (v) => APP_ID_RE.test(v ?? ''), 'use reverse-domain form, e.g. com.company.app');
      const ota = await askValid(ask, 'OTA base URL (static host for signed bundles)', o.ota ?? 'https://ota.example.com', isUrl, 'must be an http(s) URL');
      const syncBase = await askValid(ask, 'Sync API base URL (empty if none yet)', o.sync ?? '', (v) => !v || isUrl(v), 'must be an http(s) URL or empty');
      const config = {
        appId,
        keyId: 'k1',
        web: { out: web.out, lib: web.lib, routes: web.routes, entry: 'index.html', connect: [] },
        host: { dir: host },
        ota: { base: ota },
        sync: syncBase ? { base: syncBase } : {},
        data: {},
        writable: [],
      };
      writeIfMissing(cfgPath, JSON.stringify(config, null, 2) + '\n');
      cfg = loadConfig(root);
      console.log();
    }

    console.log(bold('  Installing'));
    const valencePath = join(root, 'valence', 'valence.mjs');
    const valenceState = syncFile(join(SKILL_SRC, 'scripts', 'valence.mjs'), valencePath, o.force);
    if (valenceState === 'kept') warn('valence.mjs', `kept your copy (v${vendoredVersion(valencePath)}); run "${NPX} update" to replace it`);
    else ok('valence.mjs', `valence/valence.mjs v${VALENCE_VERSION}`);
    if (writeIfMissing(join(root, 'valence', 'bridge.schema.json'), readFileSync(join(SKILL_SRC, 'templates', 'bridge.schema.json')))) ok('bridge schema', 'valence/bridge.schema.json');
    const dep = addBridgeDependency(root, cfg);
    if (dep.file === undefined) warn('web bridge', `no package.json above ${cfg.web.lib}; add ${BRIDGE_PKG} yourself`);
    else if (dep.added) ok('web bridge', `${BRIDGE_PKG} ${dep.added} in ${posix(relative(root, dep.file))}`);
    else ok('web bridge', `${BRIDGE_PKG} ${dep.had} already in ${posix(relative(root, dep.file))}`);
    const attrs = ensureLines(join(root, '.gitattributes'), gitattributes(cfg.host.dir));
    const ignores = ensureLines(join(root, '.gitignore'), ['.valence/dist-ota/']);
    if (attrs || ignores) ok('git config', `.gitattributes +${attrs}, .gitignore +${ignores}`);

    const base = o.global ? join(homedir(), '.claude') : join(root, '.claude');
    const s = installSkill(base, o.force, false);
    ok('claude skill', `${base === join(homedir(), '.claude') ? '~/.claude' : '.claude'}/skills/valence + agents (${s.written + s.updated + s.replaced.length} written, ${s.same} unchanged)`);
    if (s.manifestBroken) warn('manifest', `${s.manifestBroken} was unreadable (merge conflict?); rewrote it`);
    for (const k of s.kept) warn('kept', `${k} (edited locally; --force replaces it and saves yours as .bak)`);
    for (const k of s.replaced) warn('replaced', `${k} (your version saved as ${k.split('/').pop()}.bak)`);

    const ringPath = join(root, 'valence', 'keyring.json');
    const ring = existsSync(ringPath) ? readJson(ringPath) : {};
    if (!Object.hasOwn(ring, cfg.keyId)) {
      const k = keygen({ root, cfg, keyDir: o.keyDir });
      ok('signing key', k.file);
      console.log(`    ${yellow('Back this key up now')} (password manager), and add it to CI as the VALENCE_SIGNING_KEY secret.`);
      console.log(`    ${dim('Losing it means a store release to rotate keys; the public half is compiled into the app.')}`);
    } else {
      const pem = join(o.keyDir ?? join(homedir(), '.valence', 'keys'), `${cfg.appId}.${cfg.keyId}.pem`);
      if (existsSync(pem) || process.env.VALENCE_SIGNING_KEY) ok('signing key', `${cfg.keyId} found`);
      else warn('signing key', `keyring has "${cfg.keyId}" but its private key is not on this machine; get it from your secret store (VALENCE_SIGNING_KEY)`);
    }
    if (valenceState === 'kept') {
      warn('codegen', 'skipped: your valence.mjs is a different version; run "node valence/valence.mjs codegen" or update first');
    } else {
      const gen = codegen({ root, cfg });
      ok('codegen', gen.written.length ? gen.written.map((f) => posix(relative(root, f))).join(', ') : 'up to date');
    }

    const pm = packageManager(root, dep.file);
    console.log(`\n${bold('  Install the two runtimes')}`);
    console.log(`    ${bold(`${pm} ${PM_ADD[pm]}`)} ${dim('(in ' + (dep.file ? posix(relative(root, dirname(dep.file))) || '.' : '.') + ', for the web bridge)')}`);
    console.log(`    ${bold(`flutter pub add ${HOST_PKG}`)} ${dim(`(in ${cfg.host.dir}/, once it exists — Claude does this)`)}`);
    console.log(`\n${bold('  Next')}  Claude Code adds the host package, writes the ~20-line setup, wires your own bridge methods, runs the tests and an independent review.`);
    const command = 'claude "/valence init"';
    // A skill installed during this run is not registered in a session that is already open, so /valence would
    // come back unknown there. Say so, and name the alternative for anyone not using Claude Code at all.
    const freshSession = [
      dim('  That starts a new session, which matters: the skill was installed during this run, so'),
      dim('  /valence is not registered in a session that is already open. Without Claude Code, add'),
      dim('  the two runtimes above and follow https://getvalence.pages.dev/docs/getting-started/quick-start/'),
      '',
    ].join('\n');
    const claude = tool('claude --version', root);
    if (!claude) {
      console.log(`  Install Claude Code (https://code.claude.com/docs), then run in this folder:\n\n    ${bold(command)}\n${freshSession}`);
      return;
    }
    // claude is interactive: never start it without a terminal (CI, pipes).
    if (!o.launch || !interactive() || /^n/i.test(await ask('Launch Claude Code now? (Y/n)', 'Y'))) {
      console.log(`  When you're ready, run in this folder:\n\n    ${bold(command)}\n${freshSession}`);
      return;
    }
    ask.close();
    spawnSync(command, { cwd: root, stdio: 'inherit', shell: true });
  } finally {
    ask.close();
  }
}

function update(o) {
  const root = resolve(o.root);
  if (!existsSync(join(root, 'valence', 'valence.config.json'))) throw new Error(`Valence is not set up here yet; run "${NPX}" first`);
  const cfg = loadConfig(root);
  const before = vendoredVersion(join(root, 'valence', 'valence.mjs')) ?? 'none';
  syncFile(join(SKILL_SRC, 'scripts', 'valence.mjs'), join(root, 'valence', 'valence.mjs'), true);
  const base = skillBase(root, o.global);
  const s = installSkill(base, true, true);
  const attrs = ensureLines(join(root, '.gitattributes'), gitattributes(cfg.host.dir));
  const gen = codegen({ root, cfg });
  console.log(`\n${bold('Valence update')}`);
  ok('valence.mjs', `${before} → ${VALENCE_VERSION}`);
  ok('claude skill', `${base === join(homedir(), '.claude') ? '~/.claude' : '.claude'}: ${s.written} added, ${s.updated} updated, ${s.replaced.length} replaced, ${s.removed.length + s.backedUp.length} removed`);
  if (s.manifestBroken) warn('manifest', `${s.manifestBroken} was unreadable (merge conflict?); nothing was pruned, and changed files were backed up`);
  for (const f of s.replaced) warn('replaced', `${f} (you had edited it; your version saved as ${f.split('/').pop()}.bak)`);
  for (const f of s.removed) warn('removed', `${f} (no longer shipped)`);
  for (const f of s.backedUp) warn('removed', `${f} (no longer shipped; you had edited it, so it was renamed to .bak)`);
  if (attrs) ok('git config', `.gitattributes +${attrs}`);
  ok('codegen', gen.written.length ? gen.written.map((f) => posix(relative(root, f))).join(', ') : 'up to date');
  console.log(`\n  Review the diff, run your tests, and commit. ${dim('Then: claude "/valence doctor"')}\n`);
}

export async function doctor(o) {
  const root = resolve(o.root);
  const rows = [];
  const check = (name, fn) => {
    try {
      const r = fn() ?? {};
      rows.push([r.warn ? 'WARN' : 'PASS', name, r.warn ?? r.msg ?? '']);
    } catch (e) {
      rows.push(['FAIL', name, e.message.split('\n')[0]]);
    }
  };
  let cfg;
  check('config', () => {
    cfg = loadConfig(root);
    return { msg: cfg.appId };
  });
  check('vendored CLI', () => {
    const v = vendoredVersion(join(root, 'valence', 'valence.mjs'));
    if (!v) throw new Error('valence/valence.mjs is missing');
    return v === VALENCE_VERSION ? { msg: v } : { warn: `${v}, latest ${VALENCE_VERSION}: ${NPX} update` };
  });
  check('claude skill', () => {
    const local = [join(root, '.claude'), join(homedir(), '.claude')].map((b) => join(b, 'skills', 'valence', 'SKILL.md')).find((f) => existsSync(f));
    if (!local) return { warn: `not installed: ${NPX}` };
    const where = local.startsWith(root) ? posix(relative(root, local)) : '~/.claude/skills/valence/SKILL.md';
    return lf(readFileSync(local)).equals(lf(readFileSync(join(SKILL_SRC, 'SKILL.md')))) ? { msg: where } : { warn: `${where} differs from this version: ${NPX} update` };
  });
  if (cfg) {
    check('generated code', () => (codegen({ root, cfg, check: true }), { msg: 'up to date' }));
    check('built-in bundle', () => {
      const dir = join(root, cfg.host.dir, 'assets', 'valence', 'builtin');
      if (!existsSync(join(dir, 'manifest.json'))) return { warn: 'not built yet (valence bundle --builtin)' };
      const m = verifyBundle({ manifestPath: join(dir, 'manifest.json'), filesDir: join(dir, 'files'), keyring: readJson(join(root, 'valence', 'keyring.json')), appId: cfg.appId });
      return { msg: `seq ${m.seq} verifies` };
    });
    check('signing key', () => {
      const pem = join(o.keyDir ?? join(homedir(), '.valence', 'keys'), `${cfg.appId}.${cfg.keyId}.pem`);
      return existsSync(pem) || process.env.VALENCE_SIGNING_KEY ? { msg: cfg.keyId } : { warn: 'private key not on this machine (needed only to sign releases)' };
    });
    check('.gitattributes', () => {
      const have = existsSync(join(root, '.gitattributes')) ? readFileSync(join(root, '.gitattributes'), 'utf8') : '';
      const missing = gitattributes(cfg.host.dir).filter((l) => !have.split(/\r?\n/).map((x) => x.trim()).includes(l));
      if (missing.length) throw new Error(`missing: ${missing.join(' | ')} (${NPX} update adds them)`);
    });
  }
  if (cfg) rows.push(...await diagnose({ root, cfg, tests: o.tests }));
  console.log(`\n${bold('Valence doctor')} ${dim('(mechanical checks; device evidence still needs review)')}`);
  for (const [s, name, msg] of rows) say(s === 'PASS' ? green('✓') : s === 'WARN' ? yellow('!') : red('✗'), name, msg);
  console.log();
  if (rows.some(([s]) => s === 'FAIL')) process.exitCode = 1;
  return rows;
}

const HELP = `${bold('Valence')} ${VALENCE_VERSION}

  ${NPX} [init]    detect your project, set up config, keys, bridge code and the Claude skill,
                                    then launch Claude Code to build the Flutter host
  ${NPX} update    update the vendored CLI, skill and agents to this version
  ${NPX} doctor    quick health check (full audit: claude "/valence doctor")
  ${NPX} <command> keygen | codegen | bundle | verify | pointer | seed | version | assetlinks | aasa

Options for init
  -y, --yes          accept detected defaults, no prompts
  --web <dir>        which web app to use (required when there are several and no prompt)
  --host <dir>       Flutter host directory (default: existing Flutter app, else mobile)
  --app-id <id>      e.g. com.company.app
  --ota <url>        static host for signed bundles
  --sync <url>       sync API base URL
  --global           install the Claude skill and agents into ~/.claude instead of ./.claude
  --force            replace locally edited skill, agent and valence.mjs files
  --no-launch        don't offer to start Claude Code
  --root <dir>       project root (default: current directory)`;

export async function run(argv) {
  const [major, minor] = process.versions.node.split('.').map(Number);
  if (major < 22 || (major === 22 && minor < 13)) throw new Error(`Node ${process.versions.node} is too old; valence needs Node 22.13 or later`);
  const first = parseArgs({ args: argv, strict: false, allowPositionals: true, options: STRING_OPTS }).positionals[0];
  if (CLI.has(first)) return cli(argv);
  const { values: v, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    allowNegative: true,
    options: {
      root: { type: 'string', default: '.' },
      yes: { type: 'boolean', short: 'y', default: false },
      web: { type: 'string' },
      host: { type: 'string' },
      'app-id': { type: 'string' },
      ota: { type: 'string' },
      sync: { type: 'string' },
      global: { type: 'boolean', default: false },
      force: { type: 'boolean', default: false },
      tests: { type: 'boolean', default: false },
      launch: { type: 'boolean', default: true },
      'key-dir': { type: 'string' },
      help: { type: 'boolean', short: 'h', default: false },
    },
  });
  const o = { ...v, appId: v['app-id'], keyDir: v['key-dir'] };
  const cmd = positionals[0] ?? 'init';
  if (v.help) return console.log(HELP);
  if (cmd === 'init') return init(o);
  if (cmd === 'update') return update(o);
  if (cmd === 'doctor') return doctor(o);
  throw new Error(`unknown command "${cmd}"\n\n${HELP}`);
}

const isMain = () => {
  try {
    return !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
};

if (isMain()) {
  run(process.argv.slice(2)).catch((e) => {
    if (e.code === 'ABORT') {
      console.error(`\n${dim('cancelled')}`);
      process.exit(130);
    }
    console.error(`\n${red('valence:')} ${e.message}`);
    process.exit(1);
  });
}
