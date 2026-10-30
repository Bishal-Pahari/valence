# R10 validation

## Queue refresh - 2026-10-27

**In plain terms.** Native plugins now include current account, event-capability,
doctor and host-widget work. Fixed two merge defects: the plugin bridge fixture
omitted the event table, and doctor falsely rejected shipped plugin methods by
comparing the merged baseline with the unmerged app schema. A regression failed
before the doctor fix and now accepts valid plugins and rejects edits/removal.

**Bases and commits.** Package base e879260366282c9f504057423d54f682dcb10c81;
site base f59fbc1. Integration commits: package 84fc029, site b905b74.
Both worktrees remain on codex/r10. Exactly one queue item refreshed.

**Decisions and why.** Preserve upstream schema 13/auth.account since 13. R10 adds
no base schema methods, parameters or since values; lowering the whole schema to
6 would invalidate upstream account protections. Haptics keeps since 1. Preserve
the genuine schema-1 example store baseline, regenerate and verify the signed
built-in without rebaselining. Integrate earlier reserved surfaces before
publishing this intermediate host. Preserve both conflicting runtime-test helpers
and both README links. Doctor must use the effective plugin schema, like codegen
and bundle, rather than weakening shipped-definition checks. No release versions
changed, as explicitly required for this run.

**Security review.** Independent read-only review checked contracts 4.7, ownership,
reserved/duplicate namespaces, fragment collisions, baseline edits/removal,
nonce/strict parameter decoding, typed result decoding, missing handlers,
restricted open.external, example wiring and docs. Review confirmed the doctor
defect and rechecked its fix: nine doctor/plugin tests, strict bridge TypeScript,
mirrored CLI byte equality, codegen freshness and diff checks passed. No remaining
confirmed R10-specific finding. **Inherited HIGH:** upstream can store a new token
before its account identity if secure storage fails. Merge R7 first; preserve its
serialized fail-closed auth writes and rerun combined account regressions/gates.
R10 does not modify the auth implementation.

**App inputs.** Both complete VALENCE_FINDINGS.md files and newest reports were
reviewed read-only: Kundalini iteration 11 and app-a iteration 9. App-a F-32 and
Kundalini event-gating findings informed the two-table fixture and upgrade docs.
Strict compilation uses this branch's matching source; no harness snapshots were
replaced or claimed compatible. App-a F-33's database-lock cause remains unproven.

| Gate | Result |
|---|---|
| Root npm test | 71 passed, zero skips; generated Dart and strict TypeScript ran |
| Runtime flutter test | 402 passed |
| dart analyze --fatal-infos . | No issues, including example/plugin |
| Bridge tests / strict TypeScript | 22 passed / clean |
| Bridge build / pack dry run | Passed |
| Example flutter test | 16 passed |
| Generated TypeScript and plugin types | Strict/verbatimModuleSyntax clean against current bridge source |
| Example codegen --check | Fresh, zero writes |
| Built-in signature/files | Verified, seq 1793039932, requires.bridge 13 |
| Example debug APK | Built; embedded manifest matches signed source bytes |
| flutter pub publish --dry-run | Zero warnings |
| Site build / SEO | 29 pages, passed |
| git diff --check | Clean in both worktrees |

Logs: %TEMP%/valence-r10-20261027-*.log. The first direct example TypeScript
check could not resolve the locally uninstalled bridge. A temporary TypeScript
config mapped it to this branch's source and passed; no dependency files changed.

**Limits.** No new emulator run; device plugin execution and felt vibration remain
unverified. Android build and mocked native-channel invocation passed. iOS remains
experimental and untested. No test-app writes, pushes, publications, version bumps
or merges into shared branches occurred.

## Queue refresh — 2026-10-22

Both worktrees are on `codex/r10`. Merged package base
`c55446f3d73afec7672c2615b0ffe70f1a6a074d` and site base
`5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390` without changing package versions.
The package merge is `e61b0bb`; the site reference correction is `48987f7`.

**In plain terms.** Reusable native features now include the shared runtime's
latest fixes. R10 adds no base bridge methods or parameters: template and example
stay at schema 6, existing `since` values are preserved, and the already-shipped
`haptics.tap` method still has `since: 1` while its implementation moves into a
plugin. Reserved schemas 7–12 belong to the preceding feature branches.

**Decisions and why.** Preserve the shared database adoption, paging, sync and
lifecycle changes because protecting user data takes precedence over extension
convenience. Keep core namespace ownership, generated nonce/strict decoding and
typed result validation ahead of plugin invocation. Preserve optional builtin
parameter delegation so both older schemas and `data.list(after)` compile. Merge
the example's native HTTP setup with its haptics plugin, regenerate the bridge and
re-sign the built-in bundle with the existing key outside git. HTTP already owns
contract section 4.5 and lifecycle owns 4.6; plugins move to 4.7, with matching
website and builder/reviewer links.

**Review.** The independent read-only security pass found a stale schema-2 test
expectation against the now-schema-4 compatibility fixture and stale contract
links. The test now derives its shipped version from the fixture, and references
point to section 4.7. Recheck: four plugin CLI tests pass, zero skipped, no
remaining confirmed findings. Ownership, baseline compatibility, nonce checks,
strict decoding and restricted `open.external` behavior were reviewed.

**Current app inputs.** Read Kundalini's findings and `ITERATION_10_REPORT.md`,
and app-a's findings and `ITERATION_8_REPORT.md`, without modifying either repo.
Their database, paging, native setup and authentication observations inform the
merge decisions above; R10 does not claim to fix their unrelated findings.

**Final gates, all passed.**

| Check | Result |
|---|---|
| `npm test` | 63 passed, zero skipped; generated Dart and strict generated TypeScript ran |
| Runtime `flutter test` | 383 passed |
| `dart analyze --fatal-infos .` | No issues, including example and plugin |
| Bridge tests / strict TypeScript | 19 passed / clean |
| Bridge `npm pack --dry-run` | Passed |
| Example `flutter test` | 16 passed |
| Example `flutter build apk --debug` | Passed |
| Example `codegen --check` | Fresh |
| Signed example verification | Passed, seq 1792655809, bridge requirement 6 |
| `flutter pub publish --dry-run` | Passed, zero warnings |
| Site `npm run build` | 27 pages; SEO/link/anchor checks passed |
| `git diff --check` | Clean |

Transient gate logs: `%TEMP%/valence-r10-refresh-{npm,flutter,analyze,example,apk,pub,site}.log`.

**Limits.** No emulator check this refresh. No device plugin execution or felt
vibration is claimed; iOS remains experimental and untested. No publication,
push, merge into `packages`/`main`, or release version bump occurred.

## Original validation — 2026-10-21

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
