# R3 permissions validation - 2026-10-22

Branch: `codex/r3` in the package and website worktrees. No version bump, push,
publication or merge into `packages` was performed. Test-app repositories were read only.

## Queue refresh - 2026-10-22

**In plain terms.** Permissions now include the newest shared runtime and use the
reserved schema 10. The merge retains lifecycle/startup guards, runtime-owned sync
events and update-status reporting. Permissions have contract section 4.7, avoiding
the existing lifecycle section 4.6. The example's local CLI was synchronized with
the canonical CLI so regeneration retains permission delegations and config.

Package base: `c55446f3d73afec7672c2615b0ffe70f1a6a074d`. Site base: `5a23a4e`.
Package merge: `222230c`; site merge: `38915af`. Both branches: `codex/r3`.

Decision: preserve compiled permission allowlists and foreground checks, strict
decoding, nonce/navigation controls and shared data/migration behavior. Renumber
only the unmerged permission additions; preserve existing method meanings. Schema
10 is reserved for this branch; R8, R7 and R6 must merge first to provide contiguous
capabilities. No package version changed.

Independent valence-reviewer pass found no confirmed runtime/security defects.
Its stale example CLI and documentation references were corrected; example-local
`codegen --check` now reports no writes. Focused permission tests: 19 passed.

Fresh gates: 60 CLI tests (zero skipped, generated Dart and strict generated TS
ran), 399 runtime tests, clean Dart analysis, 18 bridge tests and strict TypeScript,
bridge pack dry run, 17 example tests, signed built-in verification (seq 1792646661,
bridge 10), final 27-page website/SEO build, Android x64 debug APK, and a clean-tree
pub dry run with zero warnings. The first pub dry run warned about uncommitted
merge files; after committing, its rerun passed warning-free. All required gates
passed. The shared package base was rechecked unchanged before marking ready.

No new emulator run: this refresh merges shared behavior and renumbers the schema;
the original Android evidence below remains historical. iOS remains experimental
and untested. Test-app repositories were read only. No pushes, publications or
merges into shared branches occurred. Only R3's shared roadmap status cell changed;
this note lives here to honor the roadmap editing boundary.

The following initial-build record is historical and predates this refresh.

## In plain terms

The signed page can check or ask for camera, foreground location, notifications,
contacts, Bluetooth, microphone and photo-library permissions, and open app settings.
The store build chooses which kinds are enabled. An OTA cannot add another kind.
Requests wait their turn and recheck foreground state before native dispatch. On
resume the page hears only about configured permissions whose status changed.

## Source context

- Read the shared roadmap and both test apps' `VALENCE_FINDINGS.md`.
- Kundalini's newest report is `ITERATION_10_REPORT.md` (2026-10-22): native setup,
  migration correctness and honest device evidence remain essential.
- App-a now has `ITERATION_7_REPORT.md` (2026-10-22): the packaged migration retained
  the shelf, a fresh 54.3 MB seed was exercised, safe-area overlap was reported,
  account switching remained refused, and anonymous 401 reporting needs follow-up.
  These reports describe their snapshots, not a new test of this branch.
- Started both branches from their local `refs/heads/packages`. Schema 9 was reserved
  in R3's own roadmap status cell before implementation; merge-order numbering
  remains the improver's responsibility.

## Gates

| Check | Result |
|---|---|
| `npm test` | 59 passed, zero skipped; generated Dart ran against Flutter and generated TS checked strictly |
| `flutter test` in the package | 376 passed |
| `dart analyze --fatal-infos .` in the package | No issues |
| Bridge `node --test test/*.test.ts` | 18 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Example `flutter test` | 15 passed |
| Example signed bundle verification | Passed; seq 1792620197, bridge requirement 9 |
| Example `codegen --check` | No files stale |
| `flutter pub publish --dry-run` | Passed with zero warnings; nothing published |
| Example `flutter build apk --debug --target-platform android-x64` | Passed |
| Website `npm run build` | 26 pages and SEO/link checks passed |

## Android device evidence

Shared `valence_test` emulator, API 36. The `codex-builder` lock was acquired before
device work and released afterwards. The installed signed example reported bridge
9 and bundle 1792620197.

| Interaction | Observed result |
|---|---|
| Check every kind before requesting | All seven returned `denied`; no startup prompt |
| Unknown `storage` kind | `E_PARAMS` |
| Camera OS dialog, Don't allow | Request and subsequent check returned `denied` |
| Camera OS dialog, While using the app | Request and subsequent check returned `granted` |
| Location OS dialog | Asked for approximate location only; foreground grant and subsequent check returned `granted` |
| Open app settings through the bridge | Returned `true` |
| Request microphone while settings were in front | `E_DENIED`, no permission prompt |
| Grant microphone with Android test controls while backgrounded, then return | Same PID 2423; `permissions.changed` contained only microphone/granted |
| Request and check all seven after granting remaining permissions with Android test controls | Every path returned `granted` |

Camera and location dialogs were actually driven. The other grants were set using
Android test controls; no claim is made that their first-request dialogs, selected
photo UI, parental restrictions or permanent-denial dialog behavior were exercised.
Those status and mapping paths have unit coverage.

The example was force-stopped, all test grants were revoked and user-set/fixed
permission flags cleared. The temporary debugger forwarding and device hierarchy
file were removed. No test-app source or data was modified. Airplane mode
was not changed. The emulator remains running and the lock is released.

## Security review

Independent review has no remaining confirmed findings. Checks covered the copied
store allowlist, unknown kinds, foreground and detached-host denials, queued dialogs,
SDK-preparation races, native failure recovery, per-kind resume failures, all five
status strings, provisional notification normalization, generated strict decoding
and nonce checks, additive schema changes, native declarations and website setup.
The existing OTA verification order, navigation lock and atomic state paths were
not changed.

Review corrections have regression coverage where they change runtime behavior:
foreground is checked again after Android SDK preparation, and Android status
checks never infer permanent denial from request history. Native permission groups
can grant broader access than the bridge kind's everyday name; the guides explain
contacts, photo-library scope and the fine-location aggregation limitation. The
example declares fine location only through API 30 for legacy Bluetooth scanning.

## Compatibility

The tested dependency is `permission_handler` 12.0.3, constrained to compatible 12.x
releases. The 13.x line resolved an Android plugin requiring SDK 37, and the APK
build failed resolving `android-37` even after the SDK manager installed the
`android-37.0` platform. No package-cache patch or SDK alias was used. The dependency
ceiling and its upgrade condition are documented. Apple still resolves 9.6.3 and
the SPM setup is reviewed statically. `device_info_plus` 13.3.0 supplies only the
Android SDK number to this adapter; no device identifiers cross the bridge.

## Limits

iOS is experimental and untested. Android behavior below API 36 is covered by
mapping tests, not device runs. The API reports permission status; it does not
implement camera capture, location reads, contact reads, scanning or media access.
