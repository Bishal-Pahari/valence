# R10 validation — 2026-10-21

Branch: `codex/r10` in both worktrees, based on package `46f4f35` and the site's
then-current `packages` branch. Package implementation commits: `b1e7c70`,
`5240971`, `62c06ab`. Site commit: `0d36402`. No versions changed, no push,
publication or merge into `packages`/`main` occurred.

## In plain terms

A native feature can now live in its own Dart package instead of being copied
into each app. Its schema fragment joins the app's typed bridge, with conflict
errors and the same compatibility checks as handwritten schema entries. The
built-in open group uses the API, and the example's haptic handler is a separate
package with matching npm types and setup notes. Native additions still need a
store release.

## Gates

| Check | Result |
|---|---|
| `npm test` | 53 passed, zero skipped; generated Dart exercised with Flutter |
| `packages/valence`: `flutter test` | 309 passed |
| `packages/valence`: `dart analyze --fatal-infos .` | No issues, including example/plugin |
| `packages/bridge`: `node --test test/*.test.ts` | 19 passed |
| `packages/bridge`: `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed; config enables verbatimModuleSyntax |
| `packages/bridge`: `npm pack --dry-run` | Passed |
| Example `flutter test` | 12 passed; haptics now invokes the real plugin and mocked platform channel |
| Example `flutter build apk --debug` | Passed |
| Example `codegen --check` | Fresh |
| `flutter pub publish --dry-run` | Passed, zero warnings after commits |
| Site `npm run build` | 24 pages, SEO/link/anchor checks passed |
| `git diff --check` | Clean |

Local gate logs were moved out of both worktrees to
`C:/Users/Lenovo/AppData/Local/Temp/valence-r10-20261021-4c7a2ffc43be47bdaab7b2d3aabd5367`.
They are transient local evidence, not required source files.

## Security review

An independent read-only review followed `.claude/agents/valence-reviewer.md` and
contracts §4.7. It reported no confirmed findings. It independently ran four
fragment tests, two generated TypeScript/Dart exercises (zero skips), three
runtime plugin tests, twelve example tests, example codegen freshness and fatal-info
Dart analysis. The later absolute-fragment-path rejection has its own regression.

Checked: reserved/duplicate owners and cross-namespace methods; fragment and
generated-name collisions; store-baseline removal/change refusal through codegen
and bundle; generated nonce and strict parameter checks before plugin calls;
no dispatch for registered-but-undeclared methods; typed result decoding and
nullable results; missing handlers; preservation of `open.external` scheme rules.
Plugins remain trusted native dependencies, not a sandbox or downloadable code.
Unchanged OTA verification, navigation, updater and SQLite policies were covered
by the full suites and were outside the focused independent review.

## Device limits

The optional emulator check was skipped. A `lock codex-builder 20` attempt found
the shared emulator held by `viewer`; the waiting attempt was cancelled before
the twenty-minute deadline when the implementation/gates were complete, and
`unlock codex-builder` left `viewer`'s lock intact. No device was accessed.
The APK build and mocked haptic invocation passed; felt vibration and this
branch's device execution are not claimed. iOS is experimental and untested.

## Test-app evidence considered

Read-only inputs were Kundalini's `VALENCE_FINDINGS.md` and newest
`ITERATION_9_REPORT.md`, plus app-b's `VALENCE_FINDINGS.md` and newest
`ITERATION_2_REPORT.md`. Their native setup failures informed the requirement for
plugin setup notes and platform-channel tests. New reports also describe stable
asset-name caching (Kundalini F-39), packaged paging/head-cursor behavior (app-b
F-29), and sync/update lease collisions (app-b F-30). R10 does not claim to fix
those separate runtime concerns. Neither test-app repository was modified.
