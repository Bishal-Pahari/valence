# R4 local reminders: validation

## Queue refresh - 2026-10-22

**In plain terms.** The reminder branch now includes `packages` at
`c55446f3d73afec7672c2615b0ffe70f1a6a074d` and uses reserved bridge schema 11.
The site branch includes `packages` at `5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390`.
Merge commits: package `87aa4ee`, site `81d81a2`, both on `codex/r4`.

Security and data decisions: retain the shared database adoption, busy-open retry, cursor paging,
lifecycle and update-status behavior; combine both example demos and regenerate/re-sign their
artifacts. Preserve app-owned notification and badge signatures with `since < 11`, because taking
over those names would break existing apps. Only schema-11+ declarations delegate to the runtime.
Package versions remain unchanged. R8, R7, R6 and R3 must merge before R4 in the fixed queue.

The template and example schemas, generated Dart/TypeScript, example store baseline and signed
built-in now agree. The built-in is seq `1792648556`, bridge 11. Source and website docs use schema 11.
An old schema-validation test used literal `since: 9`; it now tests `version + 1`. Compatibility tests
cover app-owned handlers at both schema 1 and schema 10, and the bridge-10 host denial boundary.

Fresh gates: root `npm test` 62 passed, zero failed/skipped (including real generated-Dart analysis
and dispatch); runtime `flutter test` 389 passed; `dart analyze --fatal-infos .` clean; bridge tests
19 passed, strict TypeScript, build and pack dry run passed; example tests 17 passed; site build and
SEO checks passed for 27 pages. Independent read-only security review found no remaining confirmed
findings after the schema fixture and stale documentation fixes; its targeted CLI rerun passed 16 tests.
The example debug APK built successfully. The build still reports the known `app_badge_plus`
future Kotlin-plugin compatibility warning. `flutter pub publish --dry-run` passed with zero warnings
after committing the merge; the earlier dirty-tree warning was resolved by that commit.

No new emulator run was attempted for this queue refresh. The Android results below are historical
evidence from the original implementation, not a fresh device verification. iOS remains experimental
and untested. Neither test app was edited. Both apps' current findings and newest reports were read:
Kundalini iteration 10 and app-a/Fernwise iteration 7. Fernwise's report now records its 0.4 migration,
safe-area workaround, anonymous-401 observation, and refused unsafe identity switching; the original
note below about its missing iteration report describes the earlier checkout only.

## Original implementation and Android evidence (historical)

2026-10-22. Branch `codex/r4` in the package and site worktrees. Started from package
`4080862` and the then-current site `packages` branch. Versions are unchanged.

## In plain terms

The signed page can schedule local reminders, inspect and cancel the native queue, create Android
channels, display bounded pictures and action buttons, and receive a tap after a cold start.
Timing reports exact, inexact, system-controlled or blocked rather than promising delivery.
Badges report platform acceptance honestly. Existing pre-schema-5 notification handlers keep their
shipped signatures. Native setup and adoption are documented in both repositories.

## Implementation and review

- Contracts §6.5 defines schema-5 `notify.*` and `badge.*`. The runtime owns validation, permissions,
  the serial queue cap, callbacks and native adapters; codegen owns strict marshalling only.
- Native opt-in and drawable names are compiled from config. Disabled hosts return `E_UNSUPPORTED`.
  Initialization never prompts or activates a bundle. Actions open the UI; there is no background
  Dart callback that could spend a trial.
- IDs, text, images, actions and resource names are bounded. Images have no URL/path input. Header
  checks precede a bounded pixel decode. iOS sources are pruned to pending IDs and removed on cancel.
- Exact-access revocation downgrades to inexact; a denied notification permission enqueues nothing.
  Pending requests come from the OS plugin, and concurrent mutations cannot overrun the cap.
- Security review found attachment retention and an older-host documentation guard issue; both were
  fixed and rechecked. The legacy-method selector and pixel-validation change were also reviewed.
  No unresolved review findings remain.

Feature commits: `d37b1cc`, `59b331d`, `588a855`, `c2f301e`. See
[the adoption guide](local-notifications.md) for API shapes, native setup and limits.

## Gates on the final implementation

| Check | Result |
|---|---|
| Root `npm test` | 57 passed, zero failed, zero skipped; generated Dart ran against Flutter |
| Runtime `flutter test` | 359 passed, including 8 notification tests |
| Runtime `dart analyze --fatal-infos .` | No issues found; includes the example |
| Bridge `node --test test/*.test.ts` | 19 passed |
| Bridge strict TypeScript | `npx -y -p typescript tsc -p tsconfig.json --strict` passed |
| Generated TypeScript | Strict/verbatim-module compile passed inside the CLI suite |
| Bridge build / pack dry run | Passed |
| Example `flutter test` | 15 passed |
| Example codegen / signed built-in verification | Passed; built-in seq `1792616756`, bridge 5 |
| Example debug APK | Built successfully |
| Site `npm run build` | 26 pages; SEO/link/anchor checks passed |
| `flutter pub publish --dry-run` | Zero warnings |

The Android build reports app_badge_plus's future Kotlin-plugin compatibility warning; it currently
builds successfully. The first full-suite refresh exposed a stale bridge-version test fixture, which
was corrected. One later unchanged REST-adapter run returned 502 under load; subsequent full runs
passed, including the 601-operation backlog. A Flutter compiler attempt lost its temporary output
directory while the host had about 300 MiB free RAM; the isolated-temp rerun and final suites passed.
None of these failed attempts is counted as a passing gate.

## Android evidence

Shared `valence_test` emulator, API 36, with the emulator lock held throughout. The final APK served
the signed bridge-5 built-in above. Probes went through the running page's real bridge.

| Scenario | Observation |
|---|---|
| Permission denied | `timing: blocked`, native pending queue empty |
| Explicit request | Android permission prompt appeared; granted state checked separately |
| Exact access absent | Requested exact; returned inexact with a native pending request |
| Exact access granted | Returned exact; notification actually posted |
| Corrupt image | Real Android returned `E_PARAMS` before scheduling |
| Valid image / actions | Launcher PNG visibly displayed in expanded notification; Done and Snooze visible |
| Channel policy | `R4 care`, importance 4, silent sound and `r4_group` retained after scheduling |
| Warm action | Done delivered `notify.action` with ID 46 and payload `r4-warm` |
| Cold body tap | UI process 2957 was killed; tap started process 5099; initial response had ID 47 and `r4-cold` |
| Consume initial twice | Example consumed the response; subsequent call returned null |
| Cancellation | Cancelled ID disappeared from native pending without clearing unrelated ID 45 |
| Clock and timezone | +60-second clock shift and Europe/London retained epoch `1792702926000`; settings restored |
| Reboot | ID 45 persisted. Android queued BOOT_COMPLETED as PENDING OFFLOAD; after UI startup the receiver rearmed the same epoch |
| Badge set / clear | Both returned false on the default emulator launcher, rather than claiming a visible badge |

Unattended post-reboot rearming **before** app startup is not claimed: the real boot broadcast stayed
queued during that observation window. The test did not manually inject a boot broadcast.
Warm body taps and Snooze were not separately exercised; unit tests cover the shared response path.
Vendor-specific badge launchers and power-management behavior remain device-dependent.
**iOS is experimental and untested.**

Test reminder IDs were cancelled and the native pending queue was empty afterwards. Notification
permission, exact-alarm access, timezone and automatic clock settings were restored. The example was
stopped, its debug forward removed and the emulator lock released. The example's R4 test channel remains.

The original demo PNG had an IDAT CRC error: the OS posted the notification without its picture.
That device finding led to the pixel-decode regression and the valid replacement fixture, verified
again visually. Logs and screenshots are retained locally under `_package/r4-*`.

## Test-app evidence read

Read the two apps without editing them. Kundalini's `VALENCE_FINDINGS.md` and `ITERATION_10_REPORT.md`
describe its 0.4 migration, missing receivers, timezone traps, stale alarms and reminder UI races.
The app-a checkout's `VALENCE_FINDINGS.md` still identifies 0.3 and its `NEXT.md` is cycle 5; no
separate iteration-report file was present, including hidden-file search. Its available summary and
later findings were treated as historical evidence, not as a verified 0.4 run.

Only package/site branches were committed. The maintainer/improver owns merging and publication.
