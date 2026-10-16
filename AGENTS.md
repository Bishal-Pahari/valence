# AGENTS.md: Valence

Valence is an open-source architecture for shipping a web UI inside a Flutter app as signed over-the-air bundles, on top of an offline-first native SQLite data layer. Read [README.md](README.md) for the why and the big picture.

## Repo layout

| Path | What it is |
|---|---|
| `package.json`, `bin/valence.mjs` | The npm package and the `npm create valence@latest` wizard. It detects the project, writes config, keys and codegen, installs the skill, and hands off to Claude Code. It also passes CLI commands through to `valence.mjs`. |
| `bin/valence.test.mjs` | Wizard tests: detection, init/update/doctor, idempotency, package contents |
| `.claude/skills/valence/SKILL.md` | The `/valence` skill: `init`, `release` and `doctor` workflows |
| `.claude/skills/valence/references/contracts.md` | **The spec.** Bundle format, update state machine, loopback server, bridge IDL and wire protocol, data and sync protocol, store-policy rules, test matrix |
| `.claude/skills/valence/scripts/valence.mjs` | Zero-dependency Node CLI (`keygen`, `codegen`, `bundle`, `verify`, `pointer`, `seed`) |
| `.claude/skills/valence/scripts/valence.test.mjs` | CLI tests, including compiling and running the generated Dart and the TS client |
| `.claude/skills/valence/templates/` | Files the skill copies into apps |
| `.claude/agents/valence-*.md` | The docs-scout, builder and reviewer subagents the skill orchestrates |
| `docs/research.md` | Landscape research (2026-10-14): store policies quoted, OTA, SDUI and hybrid options, and the gap Valence fills. Not shipped in the npm package. |
| *(separate repo)* `valence-site` | The website and the developer docs (Astro + Starlight), kept in their own repo next to this one. Its release console models contracts §2.3, §2.4 and §5.3, and its docs pages restate this spec: when behaviour changes here, update them there. |
| `LICENSE` | MIT |
| `.gitattributes` | Keeps every file LF on every OS. The CLI and its tests compare bytes and hashes, so a CRLF checkout must not change them. |

## Rules

1. **contracts.md is the source of truth.** A change to behaviour updates the spec, `valence.mjs`, the templates and the tests **in the same change**. If code and spec disagree, that's a bug.
2. **Run the tests before claiming anything works:** `npm test` (both suites).
   - All of them must pass.
   - `VALENCE_VERSION` in `valence.mjs` must equal the `package.json` version; a test enforces it.
   - Before publishing, run the real npx flow: `npm pack`, then in a scratch project `npx -y --package=<tarball> create-valence --yes --no-launch`.
   - The tests need Node ≥ 22.18, because the `client.ts` test imports TypeScript through type stripping.
   - The Dart test needs `dart` on PATH. If it skips, say so, and don't count it as passed.
3. **The CLI stays zero-dependency** (Node ≥ 22.13: `node:crypto`, `node:sqlite`, `node:util`). Bump `VALENCE_VERSION` in `valence.mjs` when its behaviour changes.
4. **Generated Dart must pass `dart analyze --fatal-infos`**, and generated TS must type-check under `--strict --verbatimModuleSyntax`. The tests enforce the Dart side.
5. **The bridge IDL and the manifest `format` are additive only.** Never change a field's meaning; add a new field or a new `format` number.
6. **Security paths are never simplified:**
   - the canonical check order (signature → `appId` → `seq == pointer.seq` → floor → `requires` → path, hash and size fields → per-file hash and size);
   - the bridge nonce, the navigation lock with no off-origin subframes, and strict decoding;
   - atomic state writes;
   - keys outside git and matched against the keyring.

   Every security fix gets a regression test in `valence.test.mjs`, or a row in the contracts §8 matrix.
7. **Update the "Stack baseline" table in SKILL.md only with evidence** from the `valence-docs-scout` agent or a primary source, and record the date.
8. **Keep it lazy:** the smallest correct change, no speculative abstractions, and stdlib before dependencies. Mark deliberate shortcuts with a `ponytail:` comment that names the ceiling.
9. **Import order** (JS and TS): framework builtins (`node:*`), then third party, then local, then CSS, with groups separated by a blank line. Within a group, multiline imports come first, then single-line ones, each sorted ascending by the length of the statement's last line. Members inside a multiline `{ }` are sorted by length.

## Roadmap (this order)

1. Prove it in one real app (a reference app) through `/valence init`.
2. Extract the host runtime that the builder writes into a `valence` pub package, and `client.ts` into an `@valence/bridge` npm package. Then the skill installs packages instead of generating code.
3. Add a reference sync server (static chunks plus a minimal push endpoint) and a crash/`app.ready` telemetry hook for staged rollouts.
