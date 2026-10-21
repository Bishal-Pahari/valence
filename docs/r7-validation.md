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
