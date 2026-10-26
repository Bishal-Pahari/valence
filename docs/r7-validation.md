# R7 queue refresh - 2026-10-26

In plain terms: task restoration now includes the current shared runtime and keeps
one user's saved draft out of the next user's session, even when Android restores
an older task snapshot. Implementation merge: `32dac43`; site: `965b8eb`, both
on `codex/r7`.

## Current bases and decisions

- Package base: `e879260366282c9f504057423d54f682dcb10c81`.
- Site base: `f59fbc1568c895d4cd35d385733175397beeef6a`.
- R8 is already refreshed against this package base; this run refreshes R7 only.
- Preserve upstream schema 13 and auth.account since 13, with state.save and
  state.restore at their reserved since 8. This explicitly departs from the queue's
  instruction to set the whole schema to 8: doing that would invalidate upstream
  account protections. The intermediate host must not be published until all
  reserved surfaces are integrated. The example's real store baseline remains
  schema 1; rebuilding a local built-in does not invent a shipped baseline.
- Regenerate example Dart/TypeScript from the merged schema and re-sign the built-in,
  seq 1793034531, rather than resolve generated or signed bytes manually.
- Security first: the inherited restoration snapshot was bound only to bundle seq.
  Bind it to a fingerprint of the secure native account as well. Successful switch
  or sign-out clears route/blob; same-account refresh and first-account adoption
  retain the live draft. A stale OS snapshot from another account is discarded.
  Failure to read the account discards the snapshot and opens the verified root
  page, preserving public/offline startup. A revision guard drops route captures
  begun before an account change; capture runs on background, not detached.
- Fault injection confirmed an inherited R13 failure: writing B's bearer before
  B's account could leave B credentials under A identity when the second write
  failed. Switches now delete the old token, persist the new identity, rebind the
  snapshot, then store the new token, all under the sync lease. Interrupted writes
  leave original credentials or no bearer. Retry sign-in repairs the state.
  Authentication operations are serialized, including their identity reads; a
  refusal does not poison the next attempt. Apps must still cancel stale refreshes
  without account ids and redraw their live DOM after switching.
- Extend R15's native WebView stub for URL changes/currentUrl and cover safe route
  observation plus a delayed pre-switch background capture through the real widget.
  Preserve upstream verification, sync, data, nonce/navigation and ready behavior.

## Current gates

| Gate | Result |
|---|---|
| npm test | 67 passed, zero skipped; generated Dart and strict TypeScript exercised |
| Package flutter test | 409 passed |
| dart analyze --fatal-infos . | No issues |
| Bridge tests / strict tsc / build | 21 passed / clean / passed |
| Bridge npm pack --dry-run | Passed |
| Generated example strict + verbatimModuleSyntax TypeScript | Clean, package import mapped to current bridge source |
| Example flutter test --no-pub | 17 passed on final runtime |
| Example flutter build apk --debug --no-pub | Passed on final runtime |
| Example codegen --check / signed built-in verification | No writes / valid seq 1793034531 |
| Site npm run build | 29 pages; SEO checks passed |
| flutter pub publish --dry-run | 0 warnings after implementation commit |
| Package and site git diff --check | Clean |

Independent security review has no remaining confirmed findings after the snapshot,
secure-write-order and overlapping-auth fixes. Permanent regressions cover account
adoption/refresh/refusal/switch/sign-out, stale snapshots, unreadable identity,
account/token write failures with retry and concurrent explicit account changes.

No new emulator run; the Android evidence below is historical. iOS remains
experimental and untested. No fresh process-reclamation device claim is made for
this merge or its account-failure paths.

Read both apps' VALENCE_FINDINGS.md and their newest reports: Kundalini iteration
11 (2026-10-23), Fernwise/app-a iteration 9 (2026-10-26). The latter reports a
mismatched supplied CLI/bridge snapshot pair (F-32) and unisolated lock warnings
(F-33). This branch's current generated code compiles against its matching bridge;
it does not replace the harness snapshots or claim to resolve the app's warnings.
Neither app was edited. Package versions are unchanged. No pushes, publications,
or merges into shared packages/main branches occurred.

---

## Historical queue refresh (2026-10-22)

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
