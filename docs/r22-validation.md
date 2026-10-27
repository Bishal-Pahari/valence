# R22: plugin diagnostics and development proxy cleanup

Date: 2026-10-27. Branch: `codex/r22` in both worktrees.
Code implementation: `0c02ce3`; site implementation: `152a6e2`.
Bases: code `ebb0793`, site `afe2366`. The queue and integration were already
merged, so the bottommost unclaimed must-have was R22.

## In plain terms

A broken native plugin result now reports a host error instead of blaming the
page's arguments. The CLI and runtime namespace lists are checked together.
The plugin guide explains which native APIs bypass page checks, and which web
types are actually verified. Invalid dev URLs allocate no HTTP client, and a
failed downstream WebSocket upgrade closes its upstream connection. The example
checks haptic capability before calling it.

## Decisions and why

1. Keep invocation outside the result-decoding catch. A plugin's deliberate
   `BridgeError`, including a parameter or permission error, keeps its code.
   Only malformed returned data becomes `E_INTERNAL`, with a fixed message that
   does not echo plugin data. A non-null result for a void method is also invalid.
   Parameter decoding and nonce validation still precede invocation.
2. Export the CLI's existing `PLUGIN_RESERVED` set and compare it with the actual
   Dart `ValencePluginRegistry.reservedNamespaces` in the generated-Dart exercise.
   This catches repository drift; it cannot repair an adopter's stale vendored
   CLI. The docs require refreshing tooling and regenerating with runtime upgrades.
3. Document hand-maintained npm plugin types instead of adding a second generator.
   Only the generated `bridge.g.ts` is checked against the merged schema.
   Plugin authors still own verification of their separate types package.
4. Describe native privileges precisely. `Valence.dataPut` checks writable
   buckets and dot keys; direct `store.put` bypasses those checks. Ordinary
   pref/secure methods and `openExternal` retain prefix/scheme restrictions.
   Explicit host-pref/token APIs and the database handle are privileged escape
   hatches. No native-plugin sandbox is promised or introduced.
5. Validate a dev origin before allocating the HTTP client; close the upstream
   WebSocket when downstream upgrade fails, then rethrow the original error.
   The regression uses a real upstream socket and a downstream detach failure
   adapter, without changing production APIs. Existing compile-time release
   guards, proxy credentials policy and navigation rules remain intact.

No package or schema version changed. The signed example's sequence advanced to
`1793078870`; its schema remains 14, store baseline schema remains 1, and floor
remains 0. Source/vendored CLI, generated adapter, signed HTML blob and manifest
were refreshed together. No test app or other worktree was modified.

## Regression evidence

Before the fix, generated Dart expected `E_INTERNAL` for an invalid typed plugin
result but received `E_PARAMS`. The dev allocation regression observed an HTTP
client allocation for an invalid URL, and the failed-upgrade test timed out
waiting for the real upstream socket to close. All three pass after the fix.

Generated-Dart coverage also verifies null/valid results, invalid void results,
preserved plugin error codes, strict parameters, nonce denial, missing plugins,
undeclared methods and actual CLI/runtime namespace equality.

## Gates

| Check | Result |
|---|---|
| `npm test` | 88 passed, zero skips; generated Dart and TypeScript ran |
| Runtime `flutter test` | 496 passed |
| Runtime `dart analyze --fatal-infos .` | No issues |
| Example `flutter test` | 24 passed |
| Dev suite with explicit `VALENCE_DEV_URL` | 10 passed |
| Bridge tests | 29 passed, zero skips |
| Bridge `tsc -p tsconfig.json --strict` | Passed; verbatim module syntax enabled |
| Bridge `npm pack --dry-run` | Passed |
| Source and vendored example `codegen --check` | Both wrote nothing |
| Built-in manifest signature and CAS verification | Passed, two files |
| `flutter pub publish --dry-run` | Zero warnings after implementation commit |
| Example debug APK | Built; embedded manifest matches signed source |
| Example release APK with sentinel dev URL | Built; embedded manifest matches signed source |
| Release dev-code exclusion | Passed across all three AOT libraries |
| Site `npm run build` | 37 pages; SEO/link checks passed |
| Both worktrees `git diff --check` | Clean |

The release sentinel was `http://r22-release-sentinel.invalid:5173`; the checker
also rejects the dev origin-validation and WebSocket-handshake strings in AOT.
Android builds reported existing Kotlin plugin compatibility notices, without
failing either build. The first pub dry run warned about uncommitted files and
the removed CAS path still in the index; the clean-commit rerun had zero warnings.

## Required security review and limits

The independent read-only review followed `.claude/agents/valence-reviewer.md`
and contracts §3.1, §4.2 and §4.10 and reported no confirmed findings. It checked
the invocation/decoding boundary, namespace equality, privilege documentation,
proxy resource cleanup, example guard, generated output and paired docs. Its
independent codegen, whitespace, signature and CAS checks passed. Its attempted
Flutter test executed zero tests because the concurrent full suite held the
SQLite native DLL; the temporary crash log was removed. The completed parent
gates above supply the test evidence.

No new emulator check was attempted for R22. Haptic platform-channel invocation
is covered by example tests; felt vibration and device execution of this branch
are not claimed. iOS remains experimental and untested.

Read-only app inputs: both complete `VALENCE_FINDINGS.md` files, Kundalini's
`ITERATION_12_REPORT.md` and App A's `ITERATION_10_REPORT.md`. Both describe a
mismatched supplied CLI/bridge snapshot pair. This branch retains the matching
source pair and does not claim to repair harness snapshot distribution. Sync,
retention and seed findings remain separate roadmap work.

Transient gate logs are under the system temporary directory as
`valence-r22-*.log`. Nothing was pushed or published.
