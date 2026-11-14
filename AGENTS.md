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
| `.claude/skills/valence/scripts/valence.test.mjs` | CLI tests. Two of them compile what codegen emits: the generated Dart is analyzed and exercised inside a throwaway Flutter project with a path dependency on `packages/valence`, and the generated TS is imported against `packages/bridge`'s source. |
| `.claude/skills/valence/templates/` | Files the skill copies into apps |
| `.claude/agents/valence-*.md` | The docs-scout, builder and reviewer subagents the skill orchestrates |
| `packages/valence/` | **The Flutter host runtime**, published on pub.dev as `valence`. The whole of contracts §2, §3, §4.2 and §5: loopback server, updater and state machine, verification, SQLite store, sync, bridge dispatcher, WebView. Its `test/` is the §8 matrix; its `example/` is a real app whose `main.dart` is about twenty lines. |
| `packages/valence_push/` | Opt-in Firebase Messaging transport. Core-only hosts do not depend on Firebase. |
| `packages/bridge/` | **The web bridge client**, published on npm as `@getvalence/bridge`. The whole of §4.3, zero runtime dependencies, ESM with `.d.ts`. |
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
   - The tests need Node ≥ 22.18, because the bridge test imports TypeScript through type stripping.
   - The generated-Dart test needs `flutter` on PATH, because the generated code imports `package:valence`. If it skips, say so, and don't count it as passed.
   - `packages/valence` has its own gates, and `npm test` does **not** run them: `flutter test`, `dart analyze --fatal-infos .`, `flutter pub publish --dry-run` (warning-free), and `flutter build apk --debug` in `example/`.
     - After that APK build, `python3 example/tool/check_no_firebase.py` is what backs the claim in §7 and the §8 R27 rows that a core-only host ships no Firebase: it reads the resolved package graph, the manifest and every DEX file in the artifact. Stdlib only, but it is the one gate here that needs Python at all. **On Windows run it as `py`,** not `python3` or `python`: both of those resolve to the Microsoft Store's App Execution Alias stub, which prints an install advert instead of running the script. It exits 49 on its own, but `python3 … | tail` — which is how a gate chain reads it — reports the pipeline's 0 and looks like a pass with the advert as its output. A passing run says `PASS: core graph and <n> DEX files / manifest contain no Firebase SDK references`; anything else did not run. If Python really is unavailable, say the Firebase audit did not run rather than counting the APK build as the evidence.
   - `packages/valence_push` also requires `flutter test`, `dart analyze --fatal-infos .` and a warning-free `flutter pub publish --dry-run`. Its local `pubspec_overrides.yaml` resolves the unpublished core during development; uploads exclude that override.
   - `packages/bridge` likewise: `node --test test/*.test.ts`, `npx -y -p typescript tsc -p tsconfig.json`, and `npm pack --dry-run`.
3. **The CLI stays zero-dependency** (Node ≥ 22.13: `node:crypto`, `node:sqlite`, `node:util`). Bump `VALENCE_VERSION` in `valence.mjs` when its behaviour changes.
4. **Generated Dart must pass `dart analyze --fatal-infos`**, and generated TS must type-check under `--strict --verbatimModuleSyntax`. The tests enforce both.
   - **codegen emits only the app-specific half.** The typed method and event tables, the payload types, `bridgeDispatch`, `BridgeEvents`, the `ValenceBuiltins` delegations and `valenceConfig`. Everything else is imported from the two packages. A fix that belongs in a runtime goes in `packages/`, never into the generator's output, or every app carries its own copy again.
   - **The built-in methods are frozen by shape.** `app.*`, `data.*`, `prefs.*`, `sync.*`, `open.external` and `bundle.applyUpdate` are delegated to the package, so a schema may omit one but not redefine it. `assertBuiltinShapes` enforces that; changing a built-in's signature means changing the package's API and the delegation together.
5. **The bridge IDL and the manifest `format` are additive only.** Never change a field's meaning; add a new field or a new `format` number.
6. **Security paths are never simplified:**
   - the canonical check order (signature → `appId` → `seq == pointer.seq` → floor → `requires` → path, hash and size fields → per-file hash and size);
   - the bridge nonce, the navigation lock with no off-origin subframes, and strict decoding;
   - atomic state writes;
   - keys outside git and matched against the keyring.

   Every security fix gets a regression test in `valence.test.mjs`, or a row in the contracts §8 matrix. A fix in the runtime gets its test in `packages/valence/test/` or `packages/bridge/test/` — the layer that holds the code.
7. **Update the "Stack baseline" table in SKILL.md only with evidence** from the `valence-docs-scout` agent or a primary source, and record the date.
8. **Keep it lazy:** the smallest correct change, no speculative abstractions, and stdlib before dependencies. Mark deliberate shortcuts with a `ponytail:` comment that names the ceiling.
9. **Import order** (JS and TS): framework builtins (`node:*`), then third party, then local, then CSS, with groups separated by a blank line. Within a group, multiline imports come first, then single-line ones, each sorted ascending by the length of the statement's last line. Members inside a multiline `{ }` are sorted by length.

## Releasing

Runtime release versions stay aligned: `create-valence`, `@getvalence/bridge`, `valence` and the optional `valence_push` pub package share a runtime version number, and `VALENCE_VERSION` in `valence.mjs` equals it (a test enforces that). `RUNTIME_VERSION` in `bin/valence.mjs` is the range the wizard writes into an app's `package.json`, and a test keeps it equal to all three runtime packages' versions — so the release bump updates: `package.json`, `VALENCE_VERSION`, `RUNTIME_VERSION`, and all three runtime package manifests.

The four are published separately and in this order, because the later ones depend on the earlier:

```
cd packages/bridge && npm publish --access public                    # @getvalence/bridge (prepack builds dist/)
cd packages/valence && flutter pub publish                           # valence
cd packages/valence_push && flutter pub publish                      # optional Firebase transport, after valence
npm publish --otp=<code>                                             # create-valence
```

Every release gets:

1. **A `CHANGELOG.md` section**, newest first, written in plain language for adopters — including anything they must change in their own host.
2. **One annotated git tag** `vX.Y.Z` (for example `v0.4.0-beta.0`) on the release commit of this repo, plus the same tag on the `valence-site` repo.
3. **A GitHub Release** for that tag with the changelog section as its notes, marked **pre-release** for any `-beta` or `-rc` version.

```
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --notes-file <notes> [--prerelease]
```

The maintainer runs the release: the merge, the version bump, `npm publish --otp=<code>`, the tags and pushing the site. Never publish or push from an agent session.

**Platform support, wherever it is stated:** Android is tested; **iOS is experimental and untested**, because there is no Apple hardware here. Keep the iOS parts of the spec; don't claim they are verified.

## Roadmap (this order)

1. Prove it in one real app (a reference app) through `/valence init`.
2. ~~Extract the host runtime that the builder writes into a `valence` pub package, and `client.ts` into an `@getvalence/bridge` npm package.~~ **Done.** `packages/valence` and `packages/bridge` hold the two runtimes, codegen emits only the app-specific half and imports them, and the wizard, the skill and the builder add packages instead of generating code. 0.3 adopters follow [docs/migrating-from-0.3.md](docs/migrating-from-0.3.md). What is left is device validation, which happens when the test apps migrate.
3. Add a reference sync server (static chunks plus a minimal push endpoint) and a crash/`app.ready` telemetry hook for staged rollouts.
