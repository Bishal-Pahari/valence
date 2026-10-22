# R7 queue refresh - 2026-10-22

In plain terms: the state-restoration branch now includes the current shared runtime
and advertises its two methods at reserved bridge schema 8. Package merge commit
`d089b3a`, site merge commit `00df785`, both on `codex/r7`.

## Base and decisions

- Package base: `c55446f3d73afec7672c2615b0ffe70f1a6a074d`.
- Site base: `5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390`.
- The shared queue requires R8 before R7. Schema 8 is reserved here; this branch
  does not import the still-unmerged R8 feature or change its schema reservation.
- Kept the newer runtime-owned `sync.changed` then `sync.done` emission,
  startup resume-work guard, lifecycle state recording and bounded one-shot buffer.
  Reintroducing the old widget-level sync emitter would duplicate events and miss
  native writes. The restoration model remains task-local and tied to the signed
  serving bundle seq; a new bundle clears it before navigation. User records stay
  in SQLite. No security verification or nonce/navigation check was weakened.
- Both schemas and generated example bindings use version 8 and `since: 8` for
  `state.save`/`state.restore`. The old-app fixture still excludes these methods.
  The regression checks the schema and emitted method gates together.
- Lifecycle retains contract section 4.6; restoration moves to 4.7 to remove the
  duplicate heading. Updated the skill, builder reference, package docs and site.
- Regenerated the merged example from source and signed built-in seq `1792639455`
  at bridge 8. Signature/file verification and codegen freshness passed.

## Current verification

All current gates passed:

| Gate | Result |
|---|---|
| `npm test` | 60 passed, zero skipped; generated Dart compiled with Flutter |
| Package `flutter test` | 385 passed |
| Package `dart analyze --fatal-infos .` | No issues |
| Bridge tests / `tsc -p tsconfig.json --strict` | 18 passed / clean |
| Generated example TS strict + verbatimModuleSyntax | Clean |
| Example `flutter test --no-pub` | 17 passed |
| Example `flutter build apk --debug --no-pub` | Passed |
| Codegen freshness / signed built-in verification | Current / valid seq 1792639455, bridge 8 |
| Site `npm run build` | 27 pages; SEO checks passed |
| `flutter pub publish --dry-run` | 0 warnings |
| Bridge `npm pack --dry-run` | Passed |
| Package and site `git diff --check` | Clean |

Earlier device results below remain historical: no new emulator check was performed
for this merge.
iOS remains experimental and untested.

The read-only security review followed `.claude/agents/valence-reviewer.md` and
found stale docs, now corrected; no confirmed findings remain. It checked route
validation and size limits, blob bounds, signed-bundle isolation, startup sequencing,
R2 lifecycle and sync ordering, schema mapping, generated delegations and site docs.
Its targeted restoration tests (5) and lifecycle/runtime tests (10) passed.

## Current app context

Read both apps' `VALENCE_FINDINGS.md`, Kundalini's `ITERATION_10_REPORT.md` and
Fernwise's `ITERATION_7_REPORT.md`. These reports describe migration, retained data,
read limits, sync status, startup and layout findings. They provide context for the
merge; this refresh claims no test-app fixes or fresh reproduction of their results.
Neither app repository was changed.

---

## Historical implementation validation

# R7 validation — 2026-10-21

In plain terms: Android can reclaim a background process without losing the page's
place or a small draft. Explicitly removing the task starts fresh. This is a task
snapshot, not a backup of durable records.

Package branch `codex/r7`, based on `packages` at `406d153`. Core `9fc80bb`, signed
example `8f1d38f`, setup/docs `f9b4756`. Site branch `codex/r7`, commit `2631634`.
No version numbers changed; no push or publication.

## Gates

| Check | Result |
|---|---|
| `npm test` | 56 passed, zero skipped; generated Dart compiled with Flutter |
| `packages/valence`: `flutter test --no-pub` | 344 passed |
| `packages/valence`: `dart analyze --fatal-infos .` | No issues |
| `packages/bridge`: `npm test` | 18 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Generated example TS, strict/verbatimModuleSyntax/NodeNext | Passed, mapping the package import to bridge source |
| Example `flutter test --no-pub` | 15 passed |
| Example `flutter build apk --debug --no-pub` | Passed |
| Example `codegen --check`, signature/file verification | Current, valid built-in 1792605556 at schema 5 |
| Site `npm run build` | 26 pages, SEO check passed |
| `flutter pub publish --dry-run` | Zero warnings |
| Bridge `npm pack --dry-run` | Passed |
| Package and site `git diff --check` | Clean |

## Android

The shared emulator lock was acquired as `codex-builder` and released. The example
was force-stopped at handoff; no emulator settings, reverse tunnels or other apps
were changed. Android package id is `com.getvalence.valence_example`; the signed
Valence appId is `com.getvalence.example`.

1. Installed the signed example, saved the demo draft and History API route
   `/shelf/fern?mode=draft#edit`, then pressed Home.
2. `am kill com.getvalence.valence_example` after backgrounding removed the process;
   an initial immediate attempt did not kill it, so it was retried after Android
   made the process eligible. PID disappearance was checked before reopening.
3. Reopening the retained task created PID 13482 after PID 13229 and loaded the
   complete route plus `{"draft":"fern draft"}`. The earlier build independently
   did the same across PID 12523 → 12791.
4. Force-stop and relaunch showed `/` and `state.restore: null`.
5. After another saved task, `am stack list` identified the example's root task as
   282. `am stack remove 282` removed it; reopening created task 283 and showed `/`
   and null. Recents swipe attempts did not remove the task, so no swipe result is
   claimed. The explicit task-removal API is the evidence.

Screenshots: [process reclamation](evidence/r7/after-process-reclamation.png),
[force-stop](evidence/r7/after-force-stop.png),
[task removal](evidence/r7/after-task-removal.png).

## Security review and limits

The independent reviewer followed `.claude/agents/valence-reviewer.md`: no remaining
confirmed findings after final review. Route capture now checks its original bundle,
controller and origin after awaiting. Route decoding rejects host files, authority,
traversal and decoded controls/backslashes, including query/fragment controls.
The 64 KiB UTF-8 limit is tested through both the model and generated dispatcher;
invalid nonce and unexpected params preserve the previous blob.

Widget tests verify native restoration serialization, fresh-task reset, corrupt
snapshots, port rotation and bundle isolation. The first test caught the need to
flush restoration data explicitly when WebView changes do not schedule a Flutter
frame; the package now does so. OTA signatures, nonce, navigation lock, readiness
and activation order were not replaced or bypassed.

iOS has its storyboard restoration identifier and the shared Flutter path, but is
experimental and untested. OS snapshots remain best effort. Only the current URL,
not the full browser Back stack, is restored. A different signed bundle seq clears
the snapshot. No separate physical-device, iOS or Back-to-exit check was performed.

## Test-app context

Read both apps' VALENCE_FINDINGS.md and their latest available summaries: Kundalini
ITERATION_9_REPORT.md, and app-a NEXT.md/cycle-5 summary plus its day-6 findings.
App-a has no separate iteration-report file. Neither app was modified. Kundalini's
F-39 immutable-asset cache defect is outside R7; this change does not claim to fix it.
