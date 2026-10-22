# R5 queue refresh validation - 2026-10-22

R5 is refreshed on `codex/r5` in both designated worktrees, merged from
package base `c55446f3d73afec7672c2615b0ffe70f1a6a074d` and site base
`5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390`. Remote push uses reserved
schema **12**. Device acceptance remains **blocked: needs Firebase project**.
No live delivery, image display, or OS background execution is claimed.
iOS/APNs and its Notification Service Extension remain experimental and untested.

## What changed and why

- Merged the shared database adoption, locked-open retry, paging, lifecycle,
  connectivity and update-status fixes. They remain identical to the package base.
- Template and example schema versions are 12; every push method and event has
  `since: 12`. Generated Dart and TypeScript, recorded example store baseline,
  contracts, skill, guides, READMEs, changelogs and site all agree.
- Preserved app-owned `push.*` shapes and handlers declared before 12. Only
  since-12-or-later declarations opt into the runtime. This additive compatibility
  decision protects existing apps from having their custom methods reinterpreted.
  A regression verifies schema numbers, method availability tables, custom method
  preservation and built-in shape validation.
- Regenerated and re-signed the combined example from source, at seq 1792652121,
  requiring bridge 12. Signature and per-file checks pass; codegen reports no drift.
- Retained exact data-only sync hints, compiled configuration/native token use,
  nonce and strict decoding, bounded escaped replies/events, and canonical OTA
  verification. Foreground hints call `syncNow()`, retaining `sync.done`.
  Background hints never close SQLite or consume an OTA trial.

Security comes first, then stored data and developer compatibility. Accordingly,
this refresh retains the shared fixes and custom handlers rather than overriding
an older app's declarations. No release versions changed.

## Gates

| Check | Result |
|---|---|
| Root `npm test` | 61 passed, zero failed/skipped; real generated Dart and strict generated TS ran |
| Runtime `flutter test` | 396 passed, including push wire/Firebase and background sync cases |
| Runtime `dart analyze --fatal-infos .` | No issues, includes example |
| Example `flutter test` | 18 passed |
| Bridge `node --test test/*.test.ts` | 18 passed |
| Bridge `npx -y -p typescript tsc --strict -p tsconfig.json` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Site `npm run build` | 27 pages; SEO/link checks passed |
| Example `codegen --check` and `verify --manifest ... --files ...` | Passed; no generated drift |
| Runtime `flutter pub publish --dry-run` | Zero warnings |
| Example `flutter build apk --debug` | Passed; 695.3 seconds, existing Firebase Core Kotlin warning |
| Both `git diff --check refs/heads/packages` | Passed |

The first CLI run exposed a fixture that assumed schema 9 was invalid. It now
checks `since > schema.version`, keeping the validation meaningful as versions
grow. The full suite passed after that correction.

## Security review

Read-only review used the repository's full `valence-reviewer` checklist.
No confirmed security findings remain. It checked generated nonce/strict dispatch,
disabled-host behavior, legacy custom declarations, exact sync hints, native
configuration and authentication, tap startup races, disposal, payload caps,
Unicode escaping, image metadata, unchanged OTA/state/data paths and site docs.
Two focused CLI regressions and codegen/whitespace checks passed independently.
The sole documentation finding (the old schema number in this note) is corrected.

## Intake and limits

Read both apps' `VALENCE_FINDINGS.md` and newest reports:
Kundalini `ITERATION_10_REPORT.md` and app-a `ITERATION_8_REPORT.md`.
Kundalini's database/paging migration failures reinforce preserving the merged
upstream fixes; app-a's authenticated rejection and queued-write evidence remains
app-owned historical evidence, not a new device test of this branch.

No emulator was acquired: without a Firebase project there is no end-to-end push
check to run. The maintainer must supply matching Firebase configuration before
delivery, tap/image and OS background acceptance can run. The normal example
remains usable with push disabled. Firebase dependencies still require iOS 15+;
iOS and its service extension are untested. The existing Firebase Core Kotlin
Gradle Plugin compatibility warning is a future-toolchain limitation.

Implementation merge: `c15fcd7`; site tip: `e679e86`, both `codex/r5`.
The earlier queued branches must merge first. No test app or other builder's
worktree was written. Nothing was pushed, published or merged into a shared branch.
