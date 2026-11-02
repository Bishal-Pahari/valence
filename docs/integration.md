# Integration with current packages - 2026-11-02

## November 2: iteration-52 acceptance follow-up

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 52,
read-only. All must-haves are done; no rebase-queue item is eligible. Packages
bases remain code 90af361 / site 6eb2bd6. Both bases and all 32 exact current
feature tips in the merge-order table are ancestors of both integrations.

Independently compared app-c's saved iteration-52 receipts:

- F-40 recurred. The earlier Camera diagnostic says no ANR since boot; after the
  bounded shutter retry, Android identifies an input-dispatch ANR at 06:17:36 in
  com.android.camera2/com.android.camera.CaptureActivity. Later media success is
  a separate retry, not a repair of that failed attempt or proof of Valence causation.
- Settings returned painted in original PID 4814. This successful attempt does
  not close historical F-36 or establish renderer-loss recovery.
- The artifact audit records 54 passing consistency checks and explicitly retains
  F-40 as an observed failure. These are saved artifact checks, not another device
  run or unconditional acceptance.
- The app added DartPluginRegistrant.ensureInitialized() before backgroundSync,
  matching the current host recipe. Earlier successful workers do not establish
  a defect caused by its prior omission; this is app-owned wiring.
- One registered worker was explicitly triggered after captured readiness and
  earliest-time eligibility; observation lasted 376.668 seconds. Full-log callback
  begin 06:30:19.570, completion 06:30:20.828 and SUCCESS 06:30:20.843 share PID
  7530; those exact lines are absent from the before capture. One forced execution
  proves no recurring cadence.
- Stable supplied native receipts show outbox 2/incoming absent before the worker,
  then incoming origin 1230000/usn 1230002 and outbox 0 before foreground.
  Both outgoing inspection objects independently match their saved write params.
- Independently hashed raw activation files are byte-identical, SHA256
  5cdbdda7fc2bd2075e5ecf338f9161bb0809de24fc1ffa7c6f3642a61eab8fa4:
  current 1793579930, pending 1793579940, trial null. The report records final
  commit and cleanup after observation.

Decision: preserve security, user data and the candidate freeze. An external
Camera ANR and successful isolated retries do not justify speculative changes
to rollback strikes, account isolation or sync leases. Historical reliability
findings remain open or qualified; Kundalini has not yet accepted S6/S7/S8.
S1 stays parked; S2 needs a Play account.

This follow-up changes integration ledgers only. Ancestry, matching sections,
unchanged implementation trees and diff hygiene were checked. Earlier November 2
full gates retain their recorded scope; no fresh full-gate, device or runtime-review
pass is claimed. No test-app writes, protected-branch changes, version/schema
changes, push or publication. The first independent receipt-check attempt read
a UTF-16LE PowerShell diagnostic as UTF-8 and failed its no-ANR assertion; the
unchanged receipt passed after BOM-aware decoding. This was a reader error,
not an application or runtime gate failure.

## November 2: iteration-51 acceptance follow-up

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 51,
read-only. All must-haves are marked done; no rebase-queue item is eligible.
Packages bases remain code 90af361 / site 6eb2bd6. Both bases and all 32 exact
feature tips in the current merge-order table are ancestors of both integrations.

Independently compared app-c's saved iteration-51 receipts:

- Settings returned painted in original PID 4734. This successful attempt does
  not close historical F-36 or establish renderer-loss recovery.
- The artifact audit records 54 passing consistency checks. These are saved
  artifact checks, not an additional device run or unconditional acceptance.
- One registered worker was explicitly triggered after captured readiness and
  earliest-time eligibility; observation lasted 499.286 seconds. Full-log callback
  begin 05:58:39.003, completion 05:58:40.316 and SUCCESS 05:58:40.335 share
  PID 7443, and those exact lines are absent from the before capture. One forced
  execution proves no recurring cadence.
- Stable supplied native receipts show outbox 2/incoming absent before the worker,
  then incoming origin 1200000/usn 1200002 and outbox 0 before foreground.
  Both outgoing inspection objects independently match their saved write params.
- Independently hashed raw activation files are byte-identical, SHA256
  0bca80c274e84de6ae5fb34999fcb2ef95059aed698bb8d10661482455eb1422:
  current 1793577891, pending 1793577901, trial null. The app report records
  final commit and cleanup after observation.

Decision: preserve security, user data and the candidate freeze. Successful
isolated attempts do not justify changing rollback strikes, account isolation or
sync leases. Historical reliability findings remain open or qualified; Kundalini
has not yet accepted S6/S7/S8. S1 stays parked; S2 needs a Play account.

This follow-up changes integration ledgers only. Ancestry, matching sections,
unchanged implementation trees and diff hygiene were checked. Earlier November 2
full gates retain their recorded scope; no fresh full-gate, device or runtime-review
pass is claimed. No test-app writes, protected-branch changes, version/schema
changes, push or publication.

## November 2: iteration-50 acceptance follow-up

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 50,
read-only. No eligible must-have or rebase item remains. Current packages bases
remain code 90af361 / site 6eb2bd6; ancestry checks confirm both bases and all
32 feature tips in the merge-order table are included in both integrations.

App-c's saved receipts were compared independently:

- Settings returned painted in the original PID 4793. This successful attempt
  does not close historical F-36 or establish renderer-loss recovery.
- The artifact audit contains 56 passing consistency checks, not 56 independent
  device reruns. The strengthened R29 fixture is app-side validation, not a
  shipped runtime change or exhaustive privacy/concurrency proof.
- An early forced registered job was refused before schedule and is excluded.
  The later observed execution has forced=false, after 364.945 seconds of
  observation. Full-log callback begin 05:29:03.588, completion 05:29:04.845 and
  SUCCESS 05:29:04.855 share PID 7535. One execution proves no recurring cadence.
- Stable native receipts show outbox 2/incoming absent before the worker, then
  incoming origin 1170000/usn 1170002, exact outgoing inspection objects and
  outbox 0 before foreground. Both outgoing objects match the saved write params.
- Independently hashed raw activation files are byte-identical, SHA256
  f32e1a9c8cfcb82567c318939776aa905ada97591032a1dd5bb86095803db04c:
  current 1793576113, pending 1793576122, trial null. The report records the
  final commit after observation. The excluded notification-receiver start
  is preserved separately from the accepted post-delivery cold-tap attempt.

Decision: preserve security, user data and the candidate freeze. Successful
retries do not justify weakening rollback strikes, account isolation or leases.
S1 remains deliberately parked; S2 needs a Play account. Historical findings
remain open or qualified; Kundalini has not yet accepted S6/S7/S8.

This is an evidence-ledger change only. Ancestry and diff hygiene were checked;
implementation trees are unchanged. Earlier November 2 full gates retain their
recorded scope; no fresh full-gate, device or runtime-review pass is claimed.
No test-app writes, protected-branch changes, version/schema changes, push or
publication.

## November 2: iteration-49 acceptance follow-up

Read both apps' VALENCE_FINDINGS.md and newest completed reports, Kundalini 18 /
app-c 49, read-only. No eligible must-have or queue refresh remains. Current packages
bases are still code 90af361 / site 6eb2bd6; all 32 recorded branch tips and both
packages bases are ancestors of the existing integration heads.

Independently compared app-c's saved iteration-49 receipts:

- The full Settings-return log records lmkd killing renderer 4684 at 04:44:25.351
  and host 4589 at 04:44:25.373. Saved return PID is 5444 and pagePainted is false.
  This is a failed survival attempt; later recovery does not repair it. This attempt
  does not establish Chromium explicitly terminating the host or a memory leak.
- The saved artifact audit has 53 passing consistency checks and explicitly records
  the Settings failure. These checks are not unconditional reliability acceptance.
- Worker execution is explicitly forced. Full-log callback begin 04:59:08.732,
  completion 04:59:10.093 and SUCCESS 04:59:10.106 share PID 7371.
- Stable pre-worker native receipt has outbox 2 and incoming absent. Before-resume
  receipt has incoming origin 1140000/usn 1140002, outbox 0 and both outgoing
  inspection objects matching their saved write parameters exactly.
- Independently hashed raw activation files are byte-identical, SHA256
  d9b9a4a942ffc8332078b9c6d13af03f767d955e004b3516024ee57485b93bb7:
  current 1793574349, pending 1793574358, trial null. The app reports final commit
  to 1793574358 after the observation. One forced execution proves no cadence.

Decision: preserve security, user data and the candidate freeze. A direct OS eviction
is not evidence that changing the renderer callback or rollback strikes would repair
this attempt; a successful isolated worker does not resolve historical concurrency.
No runtime, lease, retry, schema or package-version change is justified by these
receipts. F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-40 remain open or qualified.
Kundalini has not yet accepted S6/S7/S8; F-72/F-73 remain recorded adoption/DX issues.
S1 stays parked and S2 needs a Play account.

This follow-up changes the integration ledgers only. Ancestry, matching new sections,
unchanged implementation trees and diff hygiene were checked. The full gates below
retain their original November 2 scope; no fresh gate, device or independent runtime
review pass is claimed. No test-app writes, protected-branch changes, push or publication.

## In plain terms

The previous integration omitted the final cookie-jar device-validation and review fixes.
This fresh codex/integration starts from packages code 90af3619bb23c88e1a74527b06edfa3489c2c3a6
and site 6eb2bd628b278cb0582a058f2bceaca77e8549ce. It retains those fixes and S8.
Pre-ledger merge heads: code e292535f3f339abadd6c9758f681d33612512f1e,
site a02bd8e192ab201cda724dc90edb981840eac0ea. All gates below ran on this combined tree.

Decision: preserve security and stored data before convenience or additional features.
The reviewed cookie-clearing order remains before token writes, runtime jar configuration
is validated, and explicit update checks still use the attached native policy path.
No must-have remains. S1 stays parked under the recorded candidate freeze; S2 needs
a Play account. No package version changed. Schema 19 and earlier reservations remain.

## Merge order and exact tips

The required queue order was replayed first, followed by the remaining numbered tips
in ascending order, compatibility/cache tips and S8. The first 31 merges were already
included in packages; S8 merged last in both repositories, without conflicts.
All 32 exact tips below are ancestors of both resulting integration heads.

| Branch | Code tip | Site tip |
| --- | --- | --- |
| codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |
| codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |

## Gates on this combined tree

Logs: %TEMP%/valence-integration-s6review-{root,core,push,example,dev,bridge,pack,site}.log.
Every command completed with exit 0; Flutter tests were not counted as skips.

| Gate | Result |
| --- | --- |
| Root npm test | 114 passed, zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core flutter test / dart analyze --fatal-infos . | 609 passed / no issues |
| Core flutter pub publish --dry-run | 0 warnings |
| Push flutter test / dart analyze --fatal-infos . | 2 passed / no issues |
| Push flutter pub publish --dry-run | 0 warnings, existing local-override hint |
| Bridge node tests / strict-verbatim TypeScript | 29 passed / passed |
| Root and bridge npm pack --dry-run | passed; bridge prepack rebuilt dist |
| Example codegen --check / flutter test / fatal-info analysis | passed / 29 passed / no issues |
| Separately defined debug dev-mode regression | 1 passed; explicit checks leave OTA evidence unchanged |
| Example flutter build apk --debug | passed; assembleDebug 32.2s |
| Standalone Windows py tool/check_no_firebase.py | PASS: core graph, manifest and all 19 DEX files exclude Firebase |
| Site npm run build and check-seo | 46 pages passed |

The APK build retains the existing app_badge_plus Kotlin migration warning.
After these gates, only this validation ledger was edited in either repository.

## Test-app evidence, read-only

Read both VALENCE_FINDINGS.md files and newest completed reports: Kundalini 18 /
app-c 47. Kundalini has not yet accepted S6/S7/S8; its iteration 18 snapshot predates
those features. F-72/F-73 remain recorded adoption/DX issues rather than closed findings.

Independently checked saved app-c iteration-47 receipts:

- All 51 saved artifact checks pass. Settings before/return PID is 4830 and the
  saved page-painted result is true; this does not close historical renderer loss.
- Worker callback begin 03:29:20.981, complete 03:29:22.327 and WorkManager SUCCESS
  03:29:22.336 share PID 7224, occur in the full log and are absent from the
  pre-worker full log. worker-execution.json records forced=false and 443.718s.
- The stable pre-worker native receipt has outbox 2/incoming absent. The before-resume
  receipt has incoming origin 1080000/usn 1080002, outbox 0 and both exact outgoing
  inspection objects, independently compared with the saved write parameters.
- Raw before/after activation bytes match SHA256
  c8da743593919be7367fad744af15fef1f7ef9a7db780b3f8fd3bcf3604eda32:
  current 1793569002, pending 1793569013, trial null. The app report records final
  commit to 1793569013.

This supports one execution without an explicit trigger, not recurring cadence.
The report and current runner/review notes say camera/gallery completed directly;
an older checkpoint in VALENCE_FINDINGS.md says it followed an ANR. That stale
checkpoint is not used to infer a new recurrence or close historical F-40.
F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-40 remain open or qualified.
These are saved-receipt comparisons, not a new device run, screenshot inspection
or database extraction. No emulator acceptance or unconditional beta acceptance.

## Security-path checklist

Reviewed the combined delta against packages and the reviewer checklist. S8 changes
no signature ordering, nonce/strict decoding, navigation lock, atomic state writes,
key storage or account isolation. Its check delegates to the attached coalesced
host path and retains signed minHost enforcement; updateReady remains pending-only.
Missing/pre-19 event declarations remain silent and legacy status projection stays.
The merged S6 clearing-before-token fix and runtime jar validation remain present.
The combined root/core regressions and separate dev-mode regression passed.
This refresh adds no executable changes beyond the merged branch; no new independent
reviewer pass is claimed.

No test-app writes, protected-branch changes, pushes or publication. iOS remains
experimental and untested. The historical receipts below retain their original scope.

## Superseded integration receipts

## In plain terms

Fresh codex/integration starts on newest packages code 81e55b933e6a1429462f8c0c75c2f10c09c65ce6
and site 42bde4188c4ceb74b5f9d84807165ef4690419a4, includes all 31 prior feature/compatibility tips,
and merges S8 last. All prior tips were already included in packages; their
ordered merges would be no-ops. Actual new merges are S8, followed by its
legacy-status adoption clarification. Pre-ledger merge heads: code 9d358419b501979742f86c8f9732e0aedeef9468,
site 60c10c10afb90f56f2b4235bee23716c05ac8c05. No conflicts. Combined schema is 19; earlier reservations
retain their numbers. The initial November 2 integration below was superseded
when S6 landed; its gate claims retain their original scope.

S8 is ready on code 3f44455 / site 05943aa. It adds bundle.check and
bundle.checked while preserving pending-only bundle.updateReady. Explicit checks
use the attached host's coalesced discovery and native policy transitions, never
apply a bundle automatically, and cannot bypass signed minHost enforcement.
Completion is schema-opted and unbuffered; mount reads recover current state.
For a completion-driven status read, declare nullable requiredBridge in the
bundle.status return type; the legacy rejected projection is preserved otherwise.
The event independently reports the authenticated incompatible-offer reason.

Decision: preserve security, stored data and shipped meanings before developer
convenience. S6's cookie jar and the improver's prior fixes remain intact. No
package version changed. No must-have item remains; S1 stays deliberately parked
and S2 needs a Play account. The stale 17+ allocation row was not edited; S8's
own Status cell records 19, following R31 at 17 and S7 at 18.

Read both findings and newest completed reports read-only: Kundalini 18 / app-c
46. App-c's F-37 busy/pending-1 failed assertion and later same-PID recovery do
not identify a lock owner or close the finding. F-40 names external Camera;
a separate successful retry does not repair it. Earlier renderer-loss failures
remain open. Saved worker evidence supports one explicitly triggered execution,
not natural cadence. The immediately preceding refresh below records the exact
saved-receipt comparisons. No new screenshot inspection or database extraction.

## Merge order and exact tips

Fixed queue first, remaining numbered tips next, compatibility and cache tips
last, then S8. Each of these 32 current exact tips is an ancestor in both repos.

| Branch | Code tip | Site tip |
| --- | --- | --- |
| codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |
| codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |

## Gates and review

Fresh combined required gates rerun on this integration. Logs:
%TEMP%/valence-integration-s8-*.log. Executable/package inputs equal the fully
gated S8 branch; after this ledger edit only docs/integration.md differs.

| Gate | Result |
| --- | --- |
| Root npm test | 112 passed, zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core flutter test / fatal-info analysis | 599 passed / no issues |
| Bridge tests / strict-verbatim TypeScript | 29 passed / passed |
| Site build and SEO | 46 pages passed, including the adoption clarification |

The same-day S8 gates additionally passed: 1 separately defined debug dev-mode
regression, 2 push and 29 example tests; clean push analysis; warning-free core
and push pub dry runs (push retains its existing local-override hint); root and
bridge pack dry runs; example codegen --check; debug APK (71.4s) and standalone
Windows py audit of the core graph, manifest and all 19 DEX files. These artifact
claims apply to identical executable inputs, not a second APK build. Existing
app_badge_plus Kotlin compatibility warning retained. Full details and excluded
initial failures: docs/s8-validation.md in both repositories.

Independent read-only security review found no confirmed S8 defects before or
after merging S6, and confirmed the final docs and legacy-status clarification.
Six schema probes and diff checks passed. The new regressions verify signed and
invalid incompatible offers, one completion per coalesced check, native mid-session
blocking without trial strikes, schema qualification and old custom shapes,
unloaded event drops, detached/custom host refusals, and dev-mode suppression.
No signature-order, nonce, navigation, credential, atomic-write, account-isolation
or release-dev-guard simplification. The integration adds no new executable delta
beyond the reviewed S8 branch.

No emulator/device acceptance, test-app writes, protected-branch changes, package
version changes, push or publication. iOS remains experimental and untested.
Gates and saved-receipt checks do not establish unconditional beta acceptance.

---

# Integration refresh - 2026-11-02

## In plain terms

Fresh integration starts at packages code ce46b0e387bd2f0c46754466347675e94cf6b2ad
and site 0978e5ecdb86fecae01f4a933f7469286eefb4ca. All 31 current feature and
compatibility tips below are already ancestors of these bases. Their ordered
merges would all say already up to date; no new merge, conflict resolution or
runtime change is needed. The previous integrations are preserved as
codex/integration-before-20261102-refresh in both repositories. Their six
unmerged evidence-only commits remain reachable there; their ledger follows.

Decision: preserve signed verification, store-block enforcement, shipped schema
meanings and users' data. Validate the improver's combined fixes rather than
reimplement them. The new base includes blocked-resume/check coalescing,
notification field-type qualification, app.openStore since guidance, failed-trial
cache disposal and floor-aware retirement diagnostics. Combined schema stays 18;
R8/R7/R6/R3/R4/R5 stay 7/8/9/10/11/12, share.image 14, pendingIds 16,
app.openStore 17 and data.cache 18. The roadmap's stale 17+ free row is not an
allocation source for a new capability. No must-have todo or rebase queue item
remains. S8 is the next available feature; S6 remains named by the other builder.

## App evidence and limits

Read both VALENCE_FINDINGS.md files and newest completed reports read-only:
Kundalini 18 and app-c 46. Kundalini reports adoption of HTTP error distinctions,
retirement diagnostics and signed store policy; F-72/F-73 have subsequent upstream
fixes but app adoption of those fixes is not established. F-74's missing status
notification remains S8. S7's REST cache has not been accepted by Kundalini.

App-c's failed bounded offline probe reports busy/pending 1, with saved native
lease 1793565023565:4956. Eight bounded retries later it drains in the same PID
4956. This does not identify the owner or close F-37. External Camera ANR at
02:20:15 names com.android.camera2/CaptureActivity; the later successful media
retry does not close F-40. Settings retained PID 4956 in this attempt; that does
not repair the earlier renderer-loss failure or close F-36.

Independently checked the saved 51-check audit (all passed with F-37/F-40 kept
explicit), same-PID recovery and Settings receipts, external Camera ANR text,
pre-worker outbox 2/incoming absent and before-resume outbox 0 receipts. Both
outgoing row values equal the exact request objects. Raw before/after activation
bytes match SHA256 977f07a98cf6ec49e184a920f1b30abe0208cb33cb6f5360adcd9f6fd2f79bcf:
current 1793565677, pending 1793565686, trial null; final current 1793565686.
Callback begin 02:31:19.262, complete 02:31:20.399 and WorkManager SUCCESS
02:31:20.408 share PID 8327, appear in the full log and are absent from the
pre-worker full log. Worker forced=true, observed 253.381 seconds. One explicitly
triggered execution proves neither natural cadence nor recurrence. These are
saved-receipt checks, not a fresh device run, database extraction or screenshot
inspection. Historical intermittent findings remain open.

## Ordered ancestry check

Fixed queue order first, remaining numbered tips next, compatibility and cache
tips last. Every exact tip is included in both packages bases and fresh integration.

| Branch | Code tip | Site tip |
| --- | --- | --- |
| codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |
| codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |

## Fresh gates

Validation logs: %TEMP%/valence-integration-nov2-*.log.

| Gate | Result |
| --- | --- |
| Root npm test | 110 passed; zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core flutter test / fatal-info Dart | 576 passed / no issues |
| Core pub dry run | 0 warnings |
| Push flutter test / fatal-info Dart | 2 passed / no issues |
| Push pub dry run | 0 warnings; existing local-override hint; override excluded from upload |
| Bridge tests / strict-verbatim TS / pack dry run | 29 passed / passed / passed |
| Root pack dry run | Passed |
| Example flutter test / codegen --check | 29 passed / written: [] |
| Site build and SEO | 45 pages passed |
| Example debug APK / standalone Windows py Firebase audit | Passed (142.1s) / PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |

APK build used a 2 GiB Gradle heap, two workers and ActiveProcessorCount=2.
The existing app_badge_plus Kotlin compatibility warning remains.

Security review scope: no local executable/spec/schema change. All runtime,
codegen and website inputs equal the recorded packages bases. The full gates
exercise the upstream regressions; no independent runtime-security review is
claimed in this refresh. No emulator lock/device run, test-app writes, protected
branch change, version change, push or publication. iOS remains experimental and
untested. Gates are build/test evidence, not unconditional beta acceptance.

---

# Integration acceptance refresh ? 2026-11-01

## App-c iteration 44 completed evidence - 2026-11-02

### In plain terms

Read both findings and newest completed reports: Kundalini 17 and app-c 44.
App-c began November 1 and completed after Kathmandu midnight on November 2;
its UTC and device receipt timestamps remain unchanged. No eligible must-have
or missing integration merge remains. All 31 recorded exact branch tips and
packages bases 778b20c / 9ed2ee9 are included in both integrations. Pre-refresh
heads are code 61d8206 / site 74ba739.

Decision: preserve security and users' data. Successful scoped probes supply
no cause for changing leases, rollback or navigation policy. S1 remains parked,
S2 needs a Play account, and the other builder's explicit next-item note
reserves S6. Kundalini has not yet accepted S7. Avoid overlapping the credential
store or treating successful retries as historical repairs.

### Independently checked saved evidence

- Supplied artifact audit records 51 passing consistency checks and four
  harness exclusions. Runner notes also disclose the inherited text-share
  payload label. These receipts are not another device execution or beta
  acceptance; no historical reliability finding is closed.
- Full-log subtraction against the complete pre-worker baseline confirms one
  new begin at 23:59:36.196, completion at 23:59:37.246 and WorkManager SUCCESS
  at 23:59:37.257, all PID 7586. The supplied execution receipt records
  forced=true and 498.696 seconds observed: one explicitly triggered eligible
  execution, not natural cadence or production durability.
- Supplied stable native baseline records outbox 2/incoming absent. Before-
  resume SQLite receipt records incoming origin 990000 at USN 990002 and
  outbox 0. Independently compared both outgoing inspection values with their
  saved write parameters: both match exactly. This does not independently
  extract SQLite or establish server operation-ID deduplication. Paired
  snapshot stability is reported by the supplied capture receipt.
- Raw activation files independently compare byte-for-byte equal, SHA256
  f7591efe191ad7df8c983aef10646829fc81c7d86ae38a00f280db84def5d9b3:
  current 1793556335, pending 1793556344, trial null. Final saved state commits
  1793556344 after cleanup.
- Settings PID receipts both name 4509. Native widget preferences read left
  6-to-7-to-6; the proof records capture before HOME. Cleanup records stopped
  app/mocks, airplane off and no forwards at 18:15:29.160 UTC. No independent
  screenshot inspection is claimed here.
- Report and receipt review limit release-binary evidence to retained/fresh
  airplane startup; native SQLite/bridge/worker probes used restored debug.
  Archive identity with iteration 43 is reported, not a complete Flutter
  source fingerprint. Historical findings remain open or qualified.

### Integration and validation scope

Fresh ancestry, saved-artifact assertions, unchanged-input and diff checks pass.
Only matching integration ledgers change. Implementation and site build inputs
remain identical to fully gated code 27b4cd8 / site 16e3fd6. Full package/build
gates were not rerun; the earlier November 1 gate results retain their original
scope. No roadmap status changes: no item or integration assembly was needed.

No emulator run, test-app write, runtime fix, version change, protected-branch
change, push or publication. iOS remains experimental and untested. This update
closes no historical reliability finding.

## App-c iteration 43 completed evidence - 2026-11-01

### In plain terms

Read both findings and newest completed reports: Kundalini 17 and app-c 43.
No eligible must-have or missing integration merge remains. All 31 recorded
exact branch tips are included in both integrations; packages bases remain
778b20c / 9ed2ee9. Pre-refresh heads are code 64989cf / site 9220495.

Decision: preserve security and users' data. A successful retry supplies no
cause for changing leases, rollback or navigation policy. S1 remains parked,
S2 needs a Play account, and the other builder's explicit next-item note
reserves S6. Kundalini has not yet accepted S7. Avoid overlapping that
credential store or treating a passing regression as a historical repair.

### Independently checked saved evidence

- Supplied artifact audit records 51 passing consistency checks and five
  harness exclusions. Failed idle/coordinate/cold-absence attempts remain
  excluded; the audit is not another device execution or beta acceptance.
- Full-log subtraction against the complete pre-worker baseline confirms one
  new begin at 23:28:11.282, completion at 23:28:12.567 and WorkManager SUCCESS
  at 23:28:12.576, all PID 7989. The supplied execution receipt records
  forced=false and 338.301 seconds observed: one unforced execution, not
  recurring cadence or production durability.
- Supplied stable native baseline records outbox 2/incoming absent. Before-
  resume SQLite receipt records incoming origin 960000 at USN 960002 and
  outbox 0. Independently compared both outgoing inspection values with
  their saved write parameters: both match exactly. This does not independently
  extract SQLite or establish server operation-ID deduplication.
- Raw activation files independently compare byte-for-byte equal, SHA256
  ab6e714b3db8b76e21c9ca55084f80e3a61904d75d8432a5511850aa34b6867a:
  current 1793554631, pending 1793554640, trial null. Final saved state commits
  1793554640 after cleanup.
- Settings PID receipts both name 4658. Native widget preferences read left
  6-to-7-to-6; the proof records capture before HOME. Cleanup records stopped
  app/mocks, airplane off and no forwards at 17:44:40.115 UTC. No independent
  screenshot inspection is claimed here.
- Report and receipt review limit release-binary evidence to retained/fresh
  airplane startup; native SQLite/bridge/worker probes used restored debug.
  Archive identity with iteration 42 is reported, not a complete Flutter
  source fingerprint. Historical findings remain open or qualified.

### Integration and validation scope

Fresh ancestry, saved-artifact assertions, unchanged-input and diff checks pass.
Only matching integration ledgers change. Implementation and site build inputs
remain identical to fully gated code 27b4cd8 / site 16e3fd6. Full package/build
gates were not rerun; the earlier November 1 gate results retain their original
scope. No roadmap status changes: no item or integration assembly was needed.

No emulator run, test-app write, runtime fix, version change, protected-branch
change, push or publication. iOS remains experimental and untested. This update
closes no historical reliability finding.

## App-c iteration 41 completed evidence - 2026-11-01

### In plain terms

Read both findings and newest completed reports: Kundalini 17 and app-c 41.
App-c reports no new framework defect in this scoped pass. Offline/reconnect,
original-PID Settings return and camera retry probes pass without closing the
historical reliability findings. Kundalini has not yet accepted S7.

Decision: preserve security and users' data. A passing retry supplies no cause
for changing leases, rollback or navigation policy. No eligible must-have or
missing queue/integration merge remains. S1 stays deliberately parked, S2 needs
a Play account, and the existing coordination note reserves S6 as the other
builder's next item. Do not overlap that credential store.

### Independently checked saved evidence

- All 50 entries in the supplied artifact audit report passed. This is receipt
  consistency, not another device run or unconditional acceptance. The initial
  unsupported positional verify invocation remains excluded; the report records
  a corrected invocation. Historical findings remain open or qualified.
- Exact full-log subtraction confirms one new callback begin at 22:28:34.155,
  complete at 22:28:35.318 and WorkManager SUCCESS at 22:28:35.328, all PID 7561.
  None of those exact lines occurs in the full pre-worker baseline. Execution
  was explicitly triggered; 498.703 seconds observed proves neither natural
  scheduling cadence nor production durability.
- Supplied stable native baseline records outbox 2/incoming absent. Before-resume
  SQLite receipt records incoming origin 900000 at USN 900002, both outgoing
  inspection objects at 900001/900002 and outbox 0. This review does not extract
  the database independently or establish server op-ID deduplication.
- Independently compared and hashed raw activation files are byte-identical,
  SHA256 `b1c4d91a91485b5491915787774f408483e512f8894d7a498f7ccde392416c66`:
  current 1793550903, pending 1793550912, trial null. The report records final
  commitment of 1793550912 after cleanup.
- Settings PID receipts both name 4848. Native widget preferences read left
  6-to-7-to-6; the supplied proof records capture before HOME and mock base
  890200. Cleanup records stopped app/mocks, airplane off and no forwards at
  16:45:06.006 UTC. No independent screenshot inspection is claimed here.
- Archive identity with iteration 40 is reported, not an entire Flutter source
  fingerprint. Release-binary acceptance remains limited to retained/fresh
  airplane startup; native SQLite, bridge and worker probes used debug.

### Integration and validation scope

Independently verified all 31 recorded exact feature tips against current
branches and ancestry in both integrations, plus unchanged packages bases
778b20c / 9ed2ee9. Pre-refresh heads are code ce03173 / site 2f194c3. No branch
needs refreshing or another merge.

Only matching integration ledgers change. Fresh saved-artifact assertions,
ancestry, unchanged-input and diff checks pass. Implementation and site build
inputs remain identical to fully gated code 27b4cd8 / site 16e3fd6. Full package
and build gates were not rerun; earlier November 1 results retain their original
scope. No roadmap status changed because no item or integration assembly was
undertaken.

No emulator run, test-app write, runtime fix, version change, protected-branch
change, push or publication. iOS remains experimental and untested. This update
does not establish beta acceptance or close historical reliability gaps.

## App-c iteration 40 completed evidence - 2026-11-01

### In plain terms

Read both findings and the newest completed reports: Kundalini 17 and app-c 40.
App-c's scoped offline/reconnect and original-PID Settings return pass this time;
neither observation repairs the historical sync, ANR, renderer or task-restoration
findings. Failed UIAutomator, warm-coordinate and grouped-summary attempts remain
excluded rather than counted as acceptance.

Decision: preserve security and users' data. Do not change leases, rollback or
navigation rules on a passing retry without an established cause. No eligible
must-have or missing integration merge remains. S1 stays deliberately parked,
S2 needs a Play account, and the other builder explicitly names S6 next. Avoid
overlapping that credential store. Kundalini has not yet accepted S7.

### Independently checked saved evidence

- The supplied artifact audit records 50/50 passing checks and four explicit
  harness exclusions. Its empty observedFailures array does not erase those
  attempts or the historical findings. This is saved-evidence review, not
  another device run.
- Full-log subtraction confirms one new callback begin at 21:59:05.374,
  complete at 21:59:06.413 and WorkManager SUCCESS at 21:59:06.427, all PID 7631.
  These exact lines are absent from the full pre-worker baseline. The execution
  receipt reports forced=false after 384.278 seconds observed. This supports one
  observed unforced execution, not periodic cadence or production durability.
- The supplied stable native baseline records outbox 2/incoming absent.
  Before-foreground receipts record incoming origin 870000 at USN 870002,
  both outgoing inspection objects at 870001/870002 and outbox 0.
  No independent database extraction or server op-ID deduplication check
  is claimed here.
- Independently hashed raw activation files are byte-identical, SHA256
  `2e11895b1fe9cb083759459f66f663c6905dc2d72ab070ee85e4c9b34ff2eff3`:
  current 1793549214, pending 1793549223, trial null. The later final-state
  receipt commits 1793549223.
- Saved Settings PID receipts both name 4888. Native widget preferences record
  left 6-to-7-to-6; the proof receipt records capture before HOME and mock base
  860200. Cleanup records stopped app/mocks, airplane off and no forwards at
  16:14:58.196 UTC. No independent screenshot inspection is claimed here.
- Both archive hashes match iteration 39. Archive identity does not fingerprint
  the Flutter source tree. The report limits release-binary evidence to retained
  and fresh airplane startup; bridge/native SQLite/worker probes used debug.

### Integration and validation scope

Verified all 31 recorded exact feature tips against current branches and ancestry
in both integrations, plus unchanged packages bases 778b20c / 9ed2ee9.
Pre-refresh heads are code 9b35d0b / site a514aa4. No branch needs refreshing or
another merge.

Only matching integration ledgers change. Fresh artifact assertions, ancestry,
unchanged-input and diff checks pass. Implementation and site build inputs remain
identical to fully gated code 27b4cd8 / site 16e3fd6. Full package/build gates were
not rerun; the earlier November 1 results retain their original scope. No roadmap
status changed because no item was taken and no integration assembly was needed.

No emulator run, test-app write, runtime fix, version change, protected-branch
change, push or publication. iOS remains experimental and untested. This evidence
refresh does not establish beta acceptance or close historical reliability gaps.

## App-c iteration 39 completed evidence - 2026-11-01

### In plain terms

Reviewed both findings and the newest completed reports: Kundalini 17 and app-c
39. This supersedes the unfinished checkpoint below for completion scope only.
App-c still records the busy-sync failure and direct renderer/host LOW_MEMORY
eviction before recovery. Completing the later probes does not repair those
failures or establish uninterrupted Settings return.

Decision: preserve security and users' data; do not change leases, rollback or
navigation rules without an established cause. No eligible must-have or missing
integration merge remains. S1 stays deliberately parked, S2 needs a Play account,
and the other builder explicitly names S6 next. Avoid overlapping that credential
store. Kundalini has not yet accepted S7.

### Independently checked saved evidence

- All 51 entries in the supplied artifact audit report passed; its two observed
  failures remain explicit. This checks saved receipts, not another device run.
- Full-log subtraction finds exactly one new callback begin at 21:24:21.316,
  complete at 21:24:22.441 and native WorkManager SUCCESS at 21:24:22.451, all
  PID 3875. These exact lines are absent from the full pre-worker baseline.
  The execution receipt records forced=true after 803.585 seconds observed;
  this proves one explicitly triggered execution, not natural periodic cadence.
- The supplied stable native baseline records outbox 2/incoming absent. The
  before-foreground receipt records incoming origin 840000 at USN 840002, both
  outgoing inspection objects at 840001/840002 and outbox 0. No independent
  database extraction or server op-ID deduplication check is claimed here.
- Independently hashed raw activation files are byte-identical, SHA256
  `0e1feead208cf49a6ba022ec878f6699646359a238839729f93763ec6e662276`:
  current 1793546738, pending 1793546747, trial null. Final saved state commits
  1793546747 and clears pending/trial.
- Native widget preferences record left 6-to-7-to-6. The proof receipt names
  corrected mock base 830200 and capture before HOME. Saved cleanup records
  stopped app/mocks, airplane off and no forwards at 15:40:59.769 UTC.
  No independent screenshot inspection is claimed here.
- Both archive hashes still match iteration 38. This does not fingerprint the
  Flutter source tree. The report limits release-binary evidence to retained
  and fresh airplane startup; bridge/native SQLite/worker probes used debug.

### Integration and validation scope

Verified all 31 recorded exact feature tips against current branches and ancestry
in both integrations, plus packages bases 778b20c / 9ed2ee9. Pre-refresh heads are
code 12e8ba8 / site dd64d7f. No branch needs refreshing or another merge.

Only matching integration ledgers change. Fresh artifact assertions, ancestry,
unchanged-input and diff checks pass. Implementation and site build inputs remain
identical to fully gated code 27b4cd8 / site 16e3fd6. Full package/build gates were
not rerun; the earlier November 1 results retain their original scope. No roadmap
status changed because no item was taken and no integration assembly was needed.

No emulator run, test-app write, runtime fix, version change, protected-branch
change, push or publication. iOS remains experimental and untested. This evidence
refresh does not establish beta acceptance or close historical reliability gaps.

## App-c iteration 39 in-progress checkpoint - 2026-11-01

### In plain terms

Reviewed both apps' findings, Kundalini's completed iteration 17, app-c's completed
iteration 38 and its newest, explicitly unfinished iteration 39 report. Iteration
39's later findings record busy-sync and Settings-return failures; the short
report has not yet incorporated those checkpoints. Neither recovery nor later
successful feature probes closes the historical reliability findings.

Decision: preserve security and users' data. Do not weaken lease ownership,
rollback or navigation rules on these observations. No eligible must-have or
missing integration merge remains. S1 stays deliberately parked, S2 needs a Play
account, and the other builder's roadmap note explicitly names S6 next. Avoid
overlapping that credential-store work. Kundalini has not yet accepted S7.

### Independently checked saved evidence

- `settings-return-full-logcat.txt` explicitly names lowmemorykiller targets:
  renderer 5329 at 20:46:34.291 and host 5225 at 20:46:34.376, 85 ms apart.
  Exit-info records LOW_MEMORY for both at .406 and .458 respectively. This
  supports direct host eviction; a renderer callback cannot prevent that kill.
- Saved Settings PID receipts change from 5225 to 6495. The pre-relaunch page
  inspection fails with a closed socket. A new process is not an uninterrupted
  return of the original host. No independent screenshot inspection claimed.
- The supplied stable native receipt records lease `1793545128518:5225` and
  outbox 1. Paired-clock bounds put the device 37,318-37,369 ms behind the host
  at capture. Host-minus-lease arithmetic does not establish an expired lease,
  blocked owner, deadlock or COMMIT failure.
- Recovery attempts record three busy/pending-1 replies followed by ok/pending-0
  at host 15:01:29.121 UTC. The restoration sync also records ok/pending-0.
  These saved receipts establish recovery, not a causal fix or owner timeline;
  no independent database extraction was performed here.
- Iteration 39's two archive hashes match iteration 38. Archive identity does
  not fingerprint the Flutter source tree. OTA, isolated-worker and final
  cleanup acceptance are not claimed for the unfinished iteration.

### Integration and validation scope

All 31 recorded exact feature tips and both packages bases are ancestors of the
current integrations: code `f82a4f6`, site `5f61842`, based on packages `778b20c`
and `9ed2ee9`. No queue branch needs refreshing on these unchanged bases.

Only matching integration ledgers change. Fresh ancestry, unchanged-input and
diff checks pass; implementation and site build inputs remain identical to fully
gated code `27b4cd8` / site `16e3fd6`. Full package/build gates were not rerun;
their earlier November 1 results retain their original scope. No roadmap status
changed because no item was taken and no new integration assembly was required.

No emulator run, test-app write, runtime fix, version change, protected-branch
change, push or publication. iOS remains experimental and untested. This
checkpoint does not establish beta acceptance.

## App-c iteration 38 evidence refresh - 2026-11-01

### In plain terms

Read both apps' findings and newest completed reports read-only: Kundalini 17 and
app-c 38. This app-c attempt retains Settings PID 4677 and reports painted return;
camera/gallery and mixed-picker links pass within the app report's scope. These
observations do not close historical intermittent findings or establish a repair.
F-38's documentation correction is already in this integration; the local preview
receipts remain identical to iteration 37, so app-side adoption is not established.

Decision: preserve security and users' data; do not change rollback, navigation,
credential storage or sync leases on a successful observation. No eligible
must-have or missing integration merge remains. S1 remains deliberately parked,
S2 needs a Play account, and the other builder explicitly names S6 next.
Kundalini has not yet accepted S7; its cookie-paired CSRF gap remains open.

### Independently checked saved evidence

- The exact callback begin (20:00:22.477), complete (20:00:23.902) and native
  WorkManager SUCCESS (20:00:23.921) lines share PID 7022, are absent from
  `background-full-log-before.txt`, and appear in `worker-full-logcat.txt`.
  `worker-execution.json` records forced=true and 497.988 seconds observed.
  This proves one explicitly triggered execution, not natural periodic cadence.
- The supplied stable native SQLite baseline records outbox 2/incoming absent.
  Before-resume receipt records incoming origin 810000/usn 810002, both outgoing
  inspection rows and outbox 0. These are saved native receipts, not a new
  database extraction by this reviewer.
- Raw before/after activation files are byte-identical, independently hashed
  SHA256 `0d8604fac3dbae73dd5033f0f3d49ca1f0a1c37adfe268240f03f26591d456ff`:
  current 1793541967, pending 1793541977, trial null. Final state commits 1793541977.
- Settings PID receipts both say 4677. Native widget preferences record left
  6-to-7-to-6; the runner receipt names corrected mock base 800200 and capture
  before HOME. No independent screenshot inspection is claimed here.
- Final original-inspection receipt preserves note/checks/done/photo identity;
  native and legacy reminder queues are empty and final sync pending is 0.
  Renewed cleanup receipt is timestamped 14:16:20.320 UTC after the cold-link
  recheck and records stopped app/mocks, airplane off and no forwards.
- All 50 saved artifact-audit entries report passed. The two archive-hash
  receipts and eleven local documentation receipts match iteration 37 exactly;
  this comparison does not fingerprint the Flutter source tree.

### Integration and validation scope

Verified all 31 recorded exact branch tips, including renderer diagnostics, and
both packages bases are ancestors of current integration in both repositories.
Bases remain code `778b20c` / site `9ed2ee9`; pre-refresh integration heads are
code `43c7da1` / site `7456b33`. No branch needs rebasing or another merge.

Only matching `docs/integration.md` ledgers change. Implementation, spec, schema
and website build inputs are identical to fully gated code `27b4cd8` / site
`16e3fd6` documented below. Fresh checks in this run are saved-artifact assertions,
tip/ancestry checks, unchanged-input checks and diff hygiene. Full package/build
gates were not rerun; their earlier November 1 results retain their original scope.

No new runtime work, emulator/device run, independent runtime review, app write,
protected-branch change, version bump, push or publication. iOS and Firebase
delivery remain unverified; the app report does not establish beta acceptance.

## Renderer diagnostic correction and app-c iteration 37 - 2026-11-01

### In plain terms

Corrected F-38: the website now names `serving` as the marker cleared at the
renderer recovery cap; `trial` and its failure count remain for retry. Below the
cap the page reloads, while the cap shows the native error view. Spec and both
diagnostic guides now require PID/time-correlated full logs before attributing a
host exit, rather than treating exit-info alone as conclusive.

Read both findings and latest reports read-only: Kundalini 17 / app-c 37.
Independently checked Settings PID receipts (4829 before and after), the external
camera ANR record (com.android.camera2/CaptureActivity, 18:45:58), and the saved
three-image decoded-dimension result. The camera retry is a separate success,
not a repair. F-40's request for diagnostic guidance is addressed without adding
automatic media recovery. F-29/F-33/F-35/F-36/F-37 remain open or qualified.

Decision: correct the documented transition and attribution; preserve rollback,
navigation policy, credential storage, leases and users' data. No eligible
must-have remains. S1 stays parked, S2 needs a Play account and the other builder
explicitly names S6 next. Kundalini has not accepted S7 and its cookie-paired CSRF
gap remains open.

### Integration and review

Packages bases remain code 778b20c / site 9ed2ee9. Verified all 30 previously
recorded exact branch tips and both bases are ancestors of integration in both
repos. With unchanged packages, appended this documentation-only branch to the
existing recorded merge order, after S7:

| Branch | Code tip | Site tip |
| --- | --- | --- |
| codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |

Pre-ledger merged heads: code 27b4cd8 / site 16e3fd6. Existing feature schema
numbers, including S7 revision 18, are unchanged. Compared the wording with
`_onRendererLoss` and the persisted-state assertions in `app_widget_test.dart`.
No executable change or new security path; no separate security review is claimed.
Details: `docs/renderer-diagnostics-clarity.md` in the code repo.

### Fresh combined gates

| Gate | Result on code 27b4cd8 / site 16e3fd6 |
| --- | --- |
| Root `npm test` | 109 passed, zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core `flutter test` / fatal-info analysis | 573 passed / no issues |
| Core pub dry run | 0 warnings |
| Push `flutter test` / fatal-info analysis | 2 passed / no issues |
| Push pub dry run | 0 warnings; 1 local-path override hint, override excluded from uploads |
| Example `flutter test` | 29 passed |
| Example debug APK | Built; existing app_badge_plus Kotlin Gradle Plugin compatibility warning |
| Windows `py tool/check_no_firebase.py` | PASS: core graph and 19 DEX files / manifest contain no Firebase SDK references |
| Bridge tests / strict-verbatim TypeScript | 29 passed / passed |
| Root and bridge `npm pack --dry-run` | Passed |
| Site build and SEO | 45 pages OK |
| `git diff --check` | Passed |

Logs: `%TEMP%/valence-diagnostics-*.log`. These are fresh package/build gates,
not device acceptance.

No test-app writes, emulator run, screenshot inspection, iOS acceptance,
protected-branch change, version bump, push or publication. App-runner results
retain their original scope; they are not package gates. Final ledger commits
change only evidence.


## App-c iteration 35 evidence refresh - 2026-11-01

### In plain terms

Settings return again loses the renderer, followed by Chromium terminating the
host for unhandled renderer loss. Recovery closes no intermittent finding.
Read both findings and newest reports read-only: Kundalini 17 and app-c 35.

Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 exact
feature/compatibility tips against their current branches and integration
ancestry in both repos; both packages bases are also included. No eligible
must-have or missing integration merge remains. S1 remains deliberately parked,
S2 needs a Play account, and the other builder explicitly names S6 next in the
roadmap. Decision: preserve security and users' data; avoid overlapping credential
storage or speculative changes to leases, rollback strikes and navigation policy.
Kundalini has not accepted S7; its cookie-paired CSRF gap remains open.

Saved-result checks, without operating either app:

- Full Settings log names renderer 5083 as a lowmemorykiller target at
  17:43:15.556, then Chromium in host 5004 explicitly terminating the application
  at 17:43:15.622 for unhandled renderer loss. Exit-info records renderer
  LOW_MEMORY at .577 and host SIGNALED/status 9 at .725. These receipts differ
  from the log event times. Unlike iteration 34, no direct host lmkd kill is
  established. Neither a Valence leak diagnosis nor a runtime repair follows.
- Mixed-picker warm/cold links pass in the supplied report without closing
  intermittent F-29. No screenshot inspection is claimed here.
- Compared full before/after worker logs: exact new begin 17:57:50.093,
  complete 17:57:51.489 and WorkManager SUCCESS 17:57:51.499 share PID 8407 and
  are absent from the baseline. Execution receipt records forced=true and
  497.556 seconds observed; this establishes one execution, not natural cadence.
- Supplied stable pre-worker SQLite receipt records outbox 2/incoming absent;
  pre-resume receipt records incoming origin 720000 at USN 720002, both outgoing
  rows at 720001/720002 and outbox 0. These are saved native receipts, not a fresh
  database extraction. Callback/SUCCESS alone would not establish transfer.
- Independently hashed raw activation files: both SHA256
  69d7edd7daa457407fb7e681d86b265a1d924b8c3ba9c3522bbd30205427173d.
  Current 1793534673, pending 1793534683 and trial/serving=null remain unchanged.
  Final commitment of 1793534683 is reported by the app runner.
- Native widget preference receipts read fieldnote.left 6 -> 7 -> 6 and next
  Flat 2 -> Flat 1 -> Flat 2. Saved cleanup records stopped app/mocks, airplane
  off and no forwards. Runner notes disclose corrected unsupported CLI/build
  arguments and a current share fixture retaining iteration-33 text; these do
  not establish additional runtime defects.

F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or qualified.
Only matching integration ledgers change. Implementation/build inputs remain
identical to fully gated code 8d800f6 / site 6276993; prior gate results retain
their original scope/date. No fresh full gates, runtime repair, emulator run,
app writes, package/schema bump, protected-branch change, push or publication
is claimed. iOS remains experimental and untested.

## App-c iteration 34 evidence refresh - 2026-11-01

### In plain terms

Settings return again loses the renderer and host, this time with direct
lowmemorykiller records for both. A renderer callback cannot promise survival
of a direct host eviction. Recovery closes no intermittent finding. Read both
findings and newest reports read-only: Kundalini 17 and app-c 34.

Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 exact
feature/compatibility tips against their current branches and integration
ancestry in both repos; both packages bases are also included. No eligible
must-have or missing integration merge remains. S1 remains deliberately parked,
S2 needs a Play account, and the other builder explicitly names S6 next in the
roadmap. Decision: preserve security and users' data; avoid overlapping credential
storage or speculative changes to leases, rollback strikes and navigation policy.
Kundalini has not accepted S7; its cookie-paired CSRF gap remains open.

Saved-result checks, without operating either app:

- Full Settings log directly names renderer 4836 as a lowmemorykiller target at
  17:13:27.928, then host 4761 at 17:13:27.960, with host RSS 538704 kB. Both
  exit-info records report LOW_MEMORY. The report's .973/28.060 timestamps are
  exit-info receipts, distinct from the kill log events. Unlike iteration 33,
  this does not establish Chromium termination of the host. Neither a Valence
  leak diagnosis nor a runtime repair follows from these records.
- Warm mixed-picker link launch names App C MainActivity in this observation;
  this success does not close intermittent F-29. No screenshot inspection is
  claimed here.
- Compared full before/after worker logs: exact new begin 17:28:03.254,
  complete 17:28:04.483 and WorkManager SUCCESS 17:28:04.491 share PID 7545 and
  are absent from the baseline. Execution receipt records forced=true and
  466.953 seconds observed; this establishes one execution, not natural cadence.
- Supplied stable pre-worker SQLite receipt records outbox 2/incoming absent;
  pre-resume receipt records incoming origin 690000 at USN 690002, both outgoing
  rows at 690001/690002 and outbox 0. These are saved native receipts, not a fresh
  database extraction. Callback/SUCCESS alone would not establish transfer.
- Independently hashed raw activation files: both SHA256
  96a54f7e9415e1b11e6d8378053efc7e688241534fd22c1585e537fabd5f96d5.
  Current 1793532906, pending 1793532915 and trial/serving=null remain unchanged.
  Saved final state subsequently commits 1793532915 with pending/trial=null.
- Native widget preference receipts read fieldnote.left 6 -> 7 -> 6 and next
  Flat 2 -> Flat 1 -> Flat 2. Saved cleanup records stopped app/mocks, airplane
  off and no forwards. The initial unstable sync snapshot is excluded; the
  default npm audit and subsequent offline reinstall remain disclosed by the
  runner. These qualifications are not additional Valence defects.

F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or qualified.
Only matching integration ledgers change. Implementation/build inputs remain
identical to fully gated code 8d800f6 / site 6276993; prior gate results retain
their original scope/date. No fresh full gates, runtime repair, emulator run,
app writes, package/schema bump, protected-branch change, push or publication
is claimed. iOS remains experimental and untested.

## App-c iteration 33 evidence refresh - 2026-11-01

### In plain terms

Settings return again loses the renderer and then the host; a mixed-picker link
again reaches the picker instead of the requested page. Recovery closes neither
F-36 nor F-29. Read both findings and newest reports read-only: Kundalini 17 and
app-c 33. No eligible must-have or missing integration merge remains.

Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 current
feature/compatibility tips and both packages bases are ancestors of integration
in both repos. S1 remains deliberately parked, S2 needs a Play account, and the
other builder explicitly names S6 next in the roadmap. Decision: preserve security
and users' data; avoid overlapping credential-store work or speculative changes
to leases, rollback strikes and navigation policy. Kundalini has not accepted S7.

Saved-result checks, without operating either app:

- Full Settings log directly names renderer 4902 as a lowmemorykiller target at
  16:45:29.101 and Chromium in host 4824 explicitly terminating the application
  at 16:45:29.175 for unhandled renderer loss. The report's .134/.263 timestamps
  are exit-info receipts, distinct from those log events. This supports F-36's
  recurrence, not a Valence leak diagnosis or a repair.
- The failed warm launch receipt names the system photo picker; the saved activity
  dump independently names it as top resumed activity. Explicit-link recovery is
  a separate result. No screenshot inspection is claimed here.
- Compared full before/after worker logs: the exact new begin 16:59:54.267,
  complete 16:59:55.347 and WorkManager SUCCESS 16:59:55.360 share PID 7737 and
  are absent from the baseline. Execution receipt records forced=true and
  345.433 seconds observed; this establishes one execution, not natural cadence.
- Supplied stable pre-worker SQLite receipt records outbox 2/incoming absent;
  pre-resume receipt records incoming origin 660000 at USN 660002, both outgoing
  rows at 660001/660002 and outbox 0. These are saved native receipts, not a fresh
  database extraction. Callback/SUCCESS alone would not establish transfer.
- Independently hashed raw activation files: both SHA256
  0aca339906b5b1d4eb85fba6a6cda35df89408811aaa08af493f08c45592ecff.
  Current 1793531295, pending 1793531304 and trial/serving=null remain unchanged.
  Saved final state subsequently commits 1793531304 with pending/trial=null.
- Native widget preference receipts read fieldnote.left 6 -> 7 -> 6 and next
  Flat 2 -> Flat 1 -> Flat 2. The initial widget attempt refused background
  lifecycle before mutation; its result is excluded from acceptance.
- Supplied audit records 49 passing consistency checks, not another device run.
  Saved cleanup records stopped app/mocks, airplane off and no forwards. The
  runner's corrected verify invocation and other exclusions remain explicit.

F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or qualified.
Only matching integration ledgers change. Implementation/build inputs remain
identical to fully gated code 8d800f6 / site 6276993; prior gate results retain
their original scope/date. No fresh full gates, runtime repair, emulator run,
app writes, package/schema bump, protected-branch change, push or publication
is claimed. iOS remains experimental and untested.

## App-c iteration 32 evidence refresh - 2026-11-01

### In plain terms

An unforced isolated worker transfers the queued rows, but ordinary launch still
restores an orphan photo picker. Recovery through the existing link does not
repair F-29. Read both findings and newest reports read-only: Kundalini 17 and
app-c 32. No eligible must-have or missing integration merge remains.

Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 exact
feature/compatibility tips against their current branches and integration ancestry
in both repos, plus both packages bases. S1 remains deliberately parked, S2 needs
a Play account, and the other builder explicitly names S6 next. Decision: preserve
security and users' data; avoid overlapping credential-store work or changing
leases, rollback strikes or navigation policy without causal evidence. Kundalini
has not accepted S7 yet; its cookie-paired CSRF gap remains S6.

Saved-result checks, without operating either app:

- Settings before/after PID receipts both name 6681 and the pre-relaunch DOM
  contains the painted unit list. This supports this return only; F-35/F-36
  remain open. The earlier adb PID timeout remains an excluded failed attempt.
- Independently compared full before/after worker logs: exactly one fresh begin
  15:58:17.197, complete 15:58:18.424 and WorkManager SUCCESS 15:58:18.432, all
  PID 8686. Every exact line is absent from the full baseline. Saved execution
  receipt records forced=false and 280.478 seconds observed; this establishes
  one execution, not reliable periodic cadence.
- Supplied stable pre-worker SQLite receipt records outbox 2/incoming absent;
  pre-resume receipt records incoming origin 630000 at USN 630002, both outgoing
  rows at 630001/630002 and outbox 0. These are saved native receipts, not a fresh
  database extraction; callback/SUCCESS alone would not establish transfer.
- Independently compared raw activation bytes and recomputed matching SHA256
  bc1d1822529064a0f173b04eb5b34caf1ac4b6a204895091b145c810312119b5.
  Current 1793527719, pending 1793527728, trial/serving=null remain unchanged.
  Saved final state subsequently commits 1793527728 with pending/trial=null.
- Native widget preferences independently read fieldnote.left 6 -> 7 -> 6,
  total 7, next Flat 2 -> Flat 1 -> Flat 2. The first local assertion guessed
  the field name as incomplete and failed; inspecting the XML and rerunning
  against fieldnote.left passes. This was a checker mistake, not a product bug.
- Saved failure activities directly show the photo picker as top resumed
  activity. Reported process absence and explicit-link recovery remain scoped
  F-29 evidence; successful earlier launches do not erase this recurrence.
  Overlapping retained-release screenshots are excluded; the sequential repeat
  supplies the retained-data receipt. No screenshot inspection is claimed here.
- Supplied audit has 47 passing consistency checks. Its detailed independent
  review covered 46; the primary runner's addendum records the final cold-link
  check and repeated cleanup. Saved cleanup records stopped app/mocks, airplane
  off and no forwards. Consistency checks are not another device execution.

F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or qualified.
Only matching integration ledgers change. Implementation/build inputs remain
identical to fully gated code 8d800f6 / site 6276993; the combined gate table below
retains its original scope and date. No fresh full gates, runtime review,
emulator execution, app writes, package/schema bump, protected-branch change,
push or publication is claimed. iOS remains experimental and untested.

## App-c iteration 31 evidence refresh - 2026-11-01

### In plain terms

Settings return again loses both renderer and host to direct Android memory
pressure. Explicit relaunch recovers the app; it does not repair F-36 or prove
uninterrupted return. No eligible must-have or missing integration merge remains.
Read both findings and newest reports read-only: Kundalini 17 and app-c 31.

Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 exact
feature/compatibility tips against current branches and integration ancestry in
both repos, together with both packages bases. S1 remains deliberately parked,
S2 needs a Play account, and the other builder explicitly names S6 next.
Decision: preserve security and users' data; avoid overlapping credential-store
work or changing leases, rollback strikes or navigation policy without causal
evidence. Kundalini has not yet accepted S7; cookie-paired CSRF remains S6.

Saved-result checks, without operating either app:

- Settings full-log lines 57090 and 57096 directly name renderer 5384 and host
  5308 as lowmemorykiller targets at 15:14:28.151 and 15:14:28.192 (41 ms apart).
  Exit-info records LOW_MEMORY at 15:14:28.195 and 15:14:28.268 respectively.
  Kill-request timestamps and exit timestamps are distinct receipts. This does
  not establish a package leak or a callback-only cause; F-36 remains open.
- Four earlier foreground probes returned ok/pending 0 after force requests;
  actual worker overlap was not established and F-33 stays open. A separate
  isolated run has exactly one new begin 15:29:24.477, complete 15:29:25.906 and
  WorkManager SUCCESS 15:29:25.915, all PID 8266. Each exact line was independently
  checked absent from the full before log and present in the full after log.
- Saved stable pre-worker SQLite receipt records outbox 2 and incoming absent.
  Pre-resume receipt records incoming origin 600000 at USN 600002, outgoing rows
  at USNs 600001/600002 and outbox 0. These are supplied native receipts, not a
  fresh extraction. Execution was explicitly forced after eligibility, with
  529.592 seconds observed; no natural cadence or production durability claim.
- Independently compared raw activation bytes and recomputed matching SHA256
  4603dccdc27597fa132313ee9cffce78389140ad81d0439ed4e83975683e628e.
  Current 1793525726, pending 1793525735 and trial/serving=null remain unchanged.
  Saved final state subsequently commits 1793525735 with pending/trial=null.
- Native widget preferences independently read 6 -> 7 -> 6, total 7, next
  Flat 2 -> Flat 1 -> Flat 2. Initial wrong-page screenshots are excluded. Cleanup
  records stopped app/mocks, airplane mode off and no forwards. The supplied
  audit records 44 passing artifact checks, not a stability guarantee.

F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or qualified.
Runner notes retain the corrected verify invocation, stale share-fixture label,
failed pre-relaunch socket capture and excluded mixed-task probe overlap.

Only matching integration ledgers change. Implementation/build inputs remain
identical to fully gated code 8d800f6 / site 6276993; the combined gate table below
retains its original scope and date. No fresh full gates, runtime review,
emulator execution, app writes, package/schema bump, protected-branch change,
push or publication is claimed. iOS remains experimental and untested.

## App-c iteration 30 evidence refresh - 2026-11-01

### In plain terms

The latest Settings return survives in the same process, but that does not
repair the historical memory-pressure kills or permission ANR. No eligible
must-have or missing integration merge remains. Read both findings and newest
reports read-only: Kundalini 17 and app-c 30.

Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 exact
feature/compatibility tips against their current branches and integration
ancestry in both repos, plus both packages bases. S1 remains deliberately
parked, S2 needs a Play account, and the other builder explicitly names S6 next.
Decision: preserve security and users' data; avoid overlapping credential-store
work or changing leases, rollback strikes or navigation policy without causal
evidence. Kundalini has not yet accepted S7; its cookie-paired CSRF gap remains.

Saved-result checks, without operating either app:

- Settings PID receipts both name 5074, and the pre-relaunch DOM contains the
  painted unit list. This supports this return only; F-35/F-36 remain open.
- Independently matched the exact new worker lines against the full baseline
  and after log: begin 14:30:28.449, complete 14:30:29.719 and WorkManager
  SUCCESS 14:30:29.728 share PID 7907. The saved pre-resume SQLite receipt has
  incoming origin 570000 at USN 570002, outgoing objects at 570001/570002 and
  outboxCount=0. This checks saved receipts, not a fresh database extraction.
- Execution was explicitly forced after eligibility, with 498.815 seconds of
  observation. No natural cadence or production durability is established.
- Independently compared raw activation bytes and recomputed their SHA256:
  f69f1930df398741186c56eeaa4d21e6ea298b2d8496f2c447f01ff0cc90a2ae.
  Current remains 1793522222, pending 1793522232, trial/serving=null. The saved
  final state subsequently commits 1793522232 with pending/trial=null.
- Native widget preferences independently read 6 -> 7 -> 6, total 7, with next
  Flat 2 -> Flat 1 -> Flat 2. Wrong-page screenshots remain excluded. Saved
  cleanup records stopped app/mocks, airplane mode off and no forwards. The
  supplied audit records 43 passing artifact checks, not a stability guarantee.

F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or qualified.
Copied fallback scripts were not executed evidence. Initial invocation errors
and the APK commands' combined PowerShell exit 1 remain qualified in the app's
runner notes; explicit build completions are not a clean combined-shell result.

Only matching integration ledgers change. Implementation/build inputs remain
identical to fully gated code 8d800f6 / site 6276993; the combined gate table
below retains its original scope and date. No fresh full gates, runtime review,
emulator execution, app writes, package/schema bump, protected-branch change,
push or publication is claimed. iOS remains experimental and untested.

## App-c iteration 29 evidence refresh - 2026-11-01

### In plain terms

Settings return still loses the app under memory pressure. This run directly
records Android killing both the renderer and the host; a later restart and
successful feature checks do not establish a stability fix. All must-have work
is done or ready, and the integration queue remains current.

Read both findings and newest reports read-only: Kundalini 17 and app-c 29.
Packages remains code 778b20c / site 9ed2ee9. Independently checked all 30 exact
feature/compatibility tips in the table below against their current branches
and integration ancestry in both repos, including S7 at schema 18. No missing
merge or eligible must-have remains. S1 stays deliberately parked, S2 requires
a Play account, and the other builder explicitly names S6 as its next task.
Do not overlap that credential-store work while ownership remains unresolved.

Saved-result checks, without operating either app:

- Full Settings log lines 60711 and 60734 name renderer 5553 at
  13:22:56.967 and host 5471 at 13:22:56.996 as lowmemorykiller targets.
  Exit-info records LOW_MEMORY for both. This differs from a renderer kill
  followed only by Chromium terminating the host; a callback would not by
  itself prevent a direct OS host kill. No package leak or root cause of
  memory pressure is established. F-36 remains open.
- The initial worker callback completed offline after its parent-owned mock
  disappeared. WorkManager SUCCESS alone is not sync evidence. The replacement
  mock's host healthcheck is also excluded. Original queued-data/activation
  baselines were retained; the full-log baseline was renewed after that failed
  callback. An unconfirmed one-off request and early refused force are excluded.
- Independently compared the final worker's exact lines against the renewed
  before log and full after log: begin 13:52:15.924, complete 13:52:17.220 and
  SUCCESS 13:52:17.227 are new, with host PID 8433. The saved pre-resume SQLite
  receipt contains incoming origin 540000 at USN 540002, two outgoing objects
  at USNs 540001/540002 and outboxCount=0. This checks retained receipts, not a
  fresh extraction. Execution is explicitly forced after eligibility; no
  natural cadence is claimed.
- Independently hashed and compared raw before/after activation bytes:
  SHA256 9fc77d17d6ba3aa2c0c1ab3b599b37a177a769482fc2f46eb953d89c1e903809.
  Current stays 1793519202, pending 1793519211, trial=null. Saved final state
  subsequently commits 1793519211 with pending/trial=null.
- Native widget preferences independently read 6 -> 7 -> 6 remaining, total 7,
  with next Flat 2 -> Flat 1 -> Flat 2. Wrong-page screenshots remain excluded.
  Saved cleanup records stopped app/mocks, airplane mode off and no forwards.
  The supplied audit reports 43 passing consistency assertions; this includes
  qualified failures and is not an unconditional stability pass.

App-c F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and pagination remain open or
qualified. Kundalini has not accepted S7; its cookie-paired CSRF gap remains S6.
Decision: preserve security and user data. Do not change leases, rollback
strikes or navigation policy on the strength of successful retries or an OS
memory-pressure observation; those changes need evidence identifying their
actual failure path.

Only the matching integration ledgers change. Implementation/build inputs
remain identical to fully gated code 8d800f6 / site 6276993; the combined gate
table below retains its original scope and date. No fresh full gates, runtime
review, emulator execution, test-app writes, package/schema bump, protected
branch changes, push or publication are claimed. Fresh verification covers
ancestry, exact saved log lines, independent hashes, preferences and diff
hygiene. iOS remains experimental and untested.

## App-c iteration 28 evidence refresh - 2026-11-01

### In plain terms

The newest app run fixes its own missing widget refresh after remote sync.
Its saved native preferences move 6 -> 7 -> 6 before HOME, with the original
inspection restored. This needs no runtime change. The ordinary launcher still
returns to an orphan picker, and successful retries do not close the intermittent
concurrency, permission ANR or renderer-loss findings.

Read both apps' findings and newest reports read-only: Kundalini 17 and app-c
28. Current packages remains code 778b20c / site 9ed2ee9. Independently checked
all 30 exact tips in the merge table below: every branch still names that tip,
and every tip plus packages is an ancestor of integration in both repos. The
rebase queue is current; no missing integration merge or eligible must-have
remains. S1 stays deliberately parked and S2 requires a Play account. S6 remains
unclaimed here because the other builder's November 1 entry explicitly names it
as its next task; its status still says todo, so ownership needs coordination
before either builder starts the credential store. S7 remains ready at schema 18.

Saved-result checks, without operating either app:

- The widget retry records base 500200 and passed=true. Independently read the
  three native preference files: left 6/7/6, total 7 throughout, next Flat 2 /
  Flat 1 / Flat 2. The corresponding row receipts change done=false then restore
  done=true while retaining the original note/photo id. The first restoration
  returned busy and remains excluded from full-pass acceptance.
- The worker is explicitly forced after eligibility: background-force.txt says
  Running job [FORCED], worker-execution.json says forced=true and 142.039s.
  That observation interval does not establish natural scheduler cadence.
- Checked all three exact timestamped worker lines against the full baseline
  and after log. Begin 05:40:22.207, completion 05:40:24.191 and WorkManager
  SUCCESS 05:40:24.208 share PID 31112; each is absent before and present after.
- The supplied pre-resume native SQLite receipt contains the incoming unit at
  origin 510000 / USN 510002, both outgoing objects at USNs 510001/510002 and
  outboxCount=0. This checks supplied results, not a fresh database extraction.
- Independently compared and hashed both raw activation files: byte-identical,
  SHA256 81a1a79ace5ea30da847d5589355e5d80500a3847d280d2ef37d65affd8ff49d.
  Current stays 1793490621, pending 1793490634, trial=null. Final saved state
  subsequently commits 1793490634 with pending/trial=null.
- The supplied audit has 43 passing assertions. Final sync reports ok/pending0,
  modern pending IDs are empty, and cleanup records stopped app/owned mocks,
  airplane mode off, unreachable owned services and no forwards.

Ordinary-launch F-29 recurs before clear-task recovery. Early bridge access and
an adb pidof timeout fail in the harness before meaningful native replies;
concurrent APK builds limit attribution, and failed UIAutomator idle captures
precede the actual taps. Preserve those exclusions. Four successful foreground
probes, a null lease after settling and a same-PID Settings return do not locate
a blocked owner or fix F-33/F-35/F-36/F-37. F-27, F-34, F-38 and pagination remain
open or qualified. Kundalini's cookie gap remains S6; S7 has no app acceptance yet.

Decision: preserve security boundaries and users' data. Keep transaction/lease
semantics until contemporaneous request, acquisition, renewal, release and
paired-clock evidence identifies the blocker; avoid overlapping credential-store
work while its ownership is ambiguous.

This change updates only the two integration ledgers. Their implementation and
build inputs are unchanged from fully gated code 8d800f6 / site 6276993. The S7
combined gate table below retains its original scope and date; no fresh npm,
Flutter, analyzer, packaging, APK, site-build, runtime-review or emulator pass is
claimed. Fresh checks cover branch-tip ancestry, saved receipts, exact worker
lines, independent raw hashes, matching ledger text and diff hygiene. No test-app
writes, protected-branch changes, package/schema version changes, push or
publication occurred. iOS remains experimental and untested.

## S7 and ready R4 integration ? 2026-11-01

### In plain terms

Existing REST APIs can now supply disposable offline data without pretending to
speak the sync protocol. Revision 18 adds `data.cache` behind a compiled bucket
grant; pulls remain authoritative, recorded account changes clear cache and
revoked grants remove retained overlays before native reads. User edits and
server history remain separate. See [S7 acceptance](s7-validation.md).

Fresh `codex/integration` starts from newest packages code
`778b20cdc33f2014ec0ebf72323acd2bdf5e52be` / site
`9ed2ee99a4f4c4742da4e1c015e3d654ba6b666c`. Previous integration is preserved on
`codex/integration-before-s7-20261101` in both repos. Replayed the fixed legacy
queue, then later tips, with the ready R4 refresh before S7. All 30 tips below
are ancestors in both histories. No conflicts occurred. Combined merge heads:
code `09c351321601c351143461c1cfa865daa5318f19`; site
`f352d0c28b8caefdfc9075e69c10479799e3b834`.

The only difference from the accepted S7 trees is R4's notification acceptance
ledger; implementation, tests, generator and templates are identical. Revision
18 preserves every earlier since value, including notifications 11, pendingIds
16 and store-update policy 17. The roadmap's stale 17+ free row was not edited;
S7 reserves 18 in its own status cell.

Decision: security first, then data preservation. Default-deny compiled grants
and startup revocation protect read-only buckets; a separate cache table avoids
forging server USNs, outbox operations, sync freshness or OTA readiness. Old
schema overlays remain available for rollback until ordinary pair GC. Review
findings and fixes are recorded in S7 acceptance.

Both test-app findings and newest reports were read-only: Kundalini 17 / app-c
27. No app writes, emulator acceptance or intermittent-runtime repair is claimed.
App-c F-27/F-29/F-33/F-34/F-35/F-36/F-37/F-38 and its limited pagination remain
open or qualified. S6 is separate. Package/release versions are unchanged. No
protected branch commit/merge, push or publication occurred. iOS remains
experimental and untested.

### Merge order and exact tips

| Branch | Code tip | Site tip |
| --- | --- | --- |
| codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| codex/notify-event-compat | 8f8a582b43ad13e60f7c6fbcf6a2b2d16e1d214c | b273ee7c7a46574592ec3f5b91fe25d465d6d665 |
| codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |
| codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |

### Combined gates

Passed 2026-11-01 on the combined merge heads above. Final ledger commits
change only this evidence, not the implementation or build inputs.

| Gate | Combined result |
| --- | --- |
| Root npm test | 109 passed, zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core Flutter tests | 573 passed with `--concurrency=1`, isolated from other Flutter commands |
| Core fatal-info Dart / pub dry-run | No issues; 0 warnings |
| Push tests / fatal-info Dart / pub dry-run | 2 passed; no issues; 0 warnings, one local-override hint |
| Bridge tests / strict-verbatim TS / pack dry-run | 29 passed; clean; passed |
| Example Flutter tests / codegen check | 29 passed; written: [] |
| Builtin signature and hashes | seq 1793431100, two files verified |
| Root pack dry-run | Passed |
| Site build and SEO | 45 pages OK |
| Debug APK | Passed, 34.0 seconds |
| Standalone Windows py Firebase audit | PASS: core graph and 19 DEX files / manifest contain no Firebase SDK references |

The first combined core attempt overlapped other Flutter commands and later
suites failed to load the native SQLite test asset (`sqlite3_initialize`, no
native assets available). It is excluded. With no source changes and no other
Flutter command running, the full isolated suite passed all 573 tests, then
analysis and a warning-free dry-run passed. This does not establish the artifact
failure's cause. An initial optional verify invocation with an unsupported flag
is also excluded; the corrected CLI verify command passed. Existing plugin
Kotlin migration warnings remain in the APK build. No fresh emulator acceptance
or runtime repair of an app finding is claimed.

Logs: `%TEMP%/valence-s7-integration-*.log`; accepted core/analysis/pub are the
`integration-isolated-*` logs, and signature evidence is
`valence-s7-integration-verify-final.log`. The two worktrees' implementation and
site build sources match accepted S7 byte-for-byte. All 30 branch tips and both
packages bases were independently checked as ancestors. Packages remained
778b20c / 9ed2ee9 throughout this run.



## App-c iteration 24 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 24.
Packages remains code d771105 / site 53d3a91. All 29 feature and compatibility
tips, plus packages, are ancestors of integration in both repos. No missing
merge or eligible must-have remains. S1 stays parked; S2 needs a Play account.

F-37 has stronger diagnostics, not an established lease-expiry defect:

- Retained/no-reset offline sync returned offline/pending1, then reconnect
  ok/changed1/pending0 before any clear/private restoration. The first bounded
  post-restoration reconnect returned busy even though the outbox drained.
- Stable lease 1793468452235:8566 matches observed PID 8566. Extended retries
  complete ok/changed1/pending0 without restart, another explicit clear/private
  restoration or account switch. A subsequent snapshot has lease=null/outbox0
  and the same PID. Sync itself changes data; this is not an inert observation.
- Last busy call starts at host-minus-original-lease delta 140210ms; the
  successful call starts at 150602ms. Later paired samples put the host clock
  28757-28850ms ahead of the device. Historical alignment, renewals and actual
  owner-isolate lifetime were not captured. Those deltas are not owner ages;
  the post-success snapshot cannot establish the row at the busy calls.
- Exclude stale copied restore outputs from the failed-attempt acceptance.
  Actual later original-object restoration and settled retries pass. The new
  app-scoped capture helper improves future diagnosis; debuggerd/SIGQUIT still
  yield no accessible blocking-thread trace. Keep F-37 minor/diagnostic.

Ordinary launch again delivers to the orphaned picker without an App C PID
(F-29). Supplied Settings evidence records same PID 8566, painted return before
explicit relaunch and no current ANR. Four foreground ok/pending0 replies and
one startup callback do not repair major/open F-33/F-35/F-36 or prove four
worker overlaps. F-27 host-file lifecycle, F-34 stale banner and pagination
remain open or limited. Kundalini F-63/F-65 and F-64 adoption are unchanged.

Separately verified saved isolated-worker acceptance without operating apps:

- Exact new callback begin 23:41:05.130, complete 23:41:06.767 and WorkManager
  SUCCESS 23:41:06.807 share PID 11072. Each is present in the after log and
  absent from the full Flutter/WorkManager baseline. First worker receipts pull
  units above cursor 380002 and acknowledge two outgoing inspection objects.
  USN 390002 updates the inbound fixture to origin 390000, rather than proving
  insertion of a new key.
- Supplied pre-resume SQLite results contain that incoming update, both outgoing
  objects at USNs 390001/390002 and outboxCount=0. This is validation of supplied
  results, not an independent database extraction. One forced execution observed
  after 201.631 seconds does not prove natural scheduling cadence.
- Independently compared both raw activation files: byte-identical, SHA256
  7624aaa83313f0c168c0dbdf071729cfe84e7f81fb9b8ae1a22a6065c1ab70e4,
  current 1793469142 / pending 1793469154 / trial=null. Final saved state commits
  1793469154 with pending/trial=null. All 44 supplied final audit checks pass;
  cleanup records airplane off, stopped app/owned mocks, unreachable owned
  services and no forwards. Earlier failed/rejected runner attempts remain
  excluded from acceptance.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. Require contemporaneous paired clocks, native
lease snapshots at request boundaries and owner/acquisition/renewal/release
traces before assigning a cause or changing contention handling. Security and
data safety take precedence over a speculative timing fix.

Validation: saved-result assertions, exact callback lines and full baseline,
independent raw hashes, all 29 branch-tip ancestry checks in both repos and
unchanged implementation trees against gated R31 code 38a7714 / site fb7bc44.

Fresh required gates on the unchanged combined implementation (October 31):
107 root tests passed with zero failures/skips (generated Dart and strict/verbatim
TS ran); 556 core, 2 push, 28 example and 29 bridge tests passed. Core/push
fatal-info Dart analysis and bridge strict/verbatim TypeScript passed. Core/push
pub dry-runs have zero warnings (push retains one local-override hint); root and
bridge packaging dry-runs passed. Site build/SEO passed all 44 pages.
Debug APK passed (assembleDebug 218.4s), followed by the standalone Windows py
Firebase audit: PASS for the resolved core graph, manifest and all 19 DEX files.
The existing app_badge_plus Kotlin migration warning remains. The build used
process-scoped 2 GiB Gradle heap, 1 GiB metaspace and two workers/processors.
Logs: `%TEMP%/valence-oct31-app24-*.log`.

Integration readiness is not beta acceptance. No emulator run, independent
runtime review, app writes, protected-branch changes, package/schema changes,
pushes or publications occurred. iOS and real remote push remain unverified.


## App-c iteration 23 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 23.
Packages remains code d771105 / site 53d3a91. All 29 feature and compatibility
tips, plus packages, are ancestors of integration in both repos. No missing merge
or eligible must-have remains. S1 stays parked; S2 needs a Play account.

New minor F-37 qualifies the sync evidence:

- Initial reconnect and repeated offline probes remain busy in bounded windows.
  A later historical sync.status of ok/pending0 is not a fresh sync.now result.
  The saved tests do not establish that the documented two-minute lease expired.
- Explicit private-backup restoration precedes the failures. The initial script
  omitted a post-install stop/check, leaving concurrent startup as an unmeasured
  setup confound. The accepted replacement backup records no PID before/after.
  Process recovery and a later retained/no-reset offline/reconnect pass establish
  recovery, without identifying a lease owner or repairing F-33.
- Rootless debuggerd refusal and a tombstoned SIGQUIT receipt do not provide an
  accessible blocking-thread trace. Require retained/no-reset reproduction,
  native lease row/owner/start age and request/worker timelines before changing
  transaction ownership, cancellation or deadlines.

Ordinary launch again delivers to the orphaned picker with no App C PID (F-29).
Saved App info XML, matching PID 4243 and the viewed pre-relaunch screenshot
establish one painted Settings return; current lastanr says no ANR since boot.
Neither that observation nor four foreground ok/pending0 responses close major
F-33/F-35/F-36 or establish four worker overlaps.

Separately checked saved isolated background acceptance without operating apps:

- New exact callback begin 22:41:14.083, complete 22:41:15.498 and WorkManager
  SUCCESS 22:41:15.513 share PID 6297. First worker receipts pull units above
  cursor 350002 and acknowledge two outgoing inspection objects. The inbound
  key already existed; USN 360002 updates it to origin 360000.
- Supplied pre-resume SQLite results contain that incoming update, outgoing
  objects at USNs 360001/360002 and outboxCount=0. These are supplied results,
  not an independent database extraction. The forced observation after 262.709
  seconds proves one execution, not long-term scheduling cadence.
- Independently compared both raw activation files: byte-identical, SHA256
  82eb72a00f3ff342493327b6eac8a4b1b02164cf5201286380f0f7a8eaa23f36,
  current 1793465494 / pending 1793465506 / trial=null. Final saved state commits
  1793465506 with pending/trial=null. Cleanup records airplane off, stopped app
  and owned mocks, unreachable owned services and no forwards. All 39 supplied
  final audit checks pass; earlier failed probes and missing-artifact audit are
  excluded from acceptance.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. F-37 supports better diagnosis and test setup,
not a causal runtime fix on this evidence. F-27 host-file lifecycle, F-29 ordinary
launch and F-34 stale banner remain open or limited; pagination remains deferred.
Kundalini F-63/F-65 and F-64 adoption status are unchanged.

Evidence validation: saved-result assertions, exact callback lines and baseline
comparison, independent raw hashes, all 29 branch-tip ancestry checks in both
repos, matching acceptance sections and unchanged implementation trees against
gated R31 code 38a7714 / site fb7bc44.

Fresh required gates on the unchanged combined implementation (October 31):
107 root tests passed with zero failures/skips (generated Dart and strict/verbatim
TS ran); 556 core, 2 push, 28 example and 29 bridge tests passed. Core/push
fatal-info Dart analysis and bridge strict/verbatim TypeScript passed. Core/push
pub dry-runs have zero warnings (push retains one local-override hint); root and
bridge packaging dry-runs passed. Site build/SEO passed all 44 pages.
Logs: `%TEMP%/valence-oct31-app23-*.log`.
Debug APK passed (assembleDebug 214.9s), followed by the standalone Windows py
Firebase audit: PASS for the resolved core graph, manifest and all 19 DEX files.
The existing app_badge_plus Kotlin migration warning remains. The build used
process-scoped 2 GiB Gradle heap, 1 GiB metaspace and two workers/processors.

Integration readiness is not beta acceptance. No emulator run, independent
runtime review, app writes, protected-branch changes, package/schema changes,
pushes or publications occurred. iOS and real remote push remain unverified.


## App-c iteration 22 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 22.
Packages remains code d771105 / site 53d3a91. All 29 feature and compatibility
tips, including sync-fixes, plus packages are ancestors of integration in both
repos. No missing merge or eligible must-have remains. S1 stays parked; S2 needs
a Play account.

The current Settings return improves the evidence without closing old failures:

- Loaded App info XML, saved PID 29459 and the viewed painted app screenshot
  before explicit relaunch establish one same-process Settings return. Current
  lastanr says no ANR since boot. This does not establish memory-pressure
  resilience or repair major F-35/F-36; their earlier observations remain valid.
- Ordinary launch again brings up the orphaned picker without an App C PID
  (F-29); explicit fresh-task recovery is a separate result. Four foreground
  sync replies report ok/pending0, without establishing four worker overlaps
  or repairing major/open F-33. Settled offline/pending1 and reconnect/ok/pending0
  are accepted separately. Startup open completion is not first-paint timing.

Separately checked saved background acceptance without operating either app:

- Exact new callback begin 21:31:09.711, complete 21:31:12.430 and WorkManager
  SUCCESS 21:31:12.450 share PID 32285 and are absent from the before log.
  First worker receipts pull units above cursor 320002 and acknowledge two
  outgoing inspection objects. The inbound fixture already existed: USN 330002
  updates it to origin 330000, rather than proving insertion of a new key.
- Supplied pre-resume native SQLite results contain that incoming row, outgoing
  objects at USNs 330001/330002 and outboxCount=0. This run checked supplied
  results, not an independent database extraction. The forced execution observed
  after 483.355 seconds proves one run, not long-term scheduling cadence.
- Independently compared both raw activation files: byte-identical, SHA256
  baec7203e81bf6121b17ba031f81200e38b2bbb39f010f0e61d63ff9dec002c0,
  current 1793461074 / pending 1793461086 / trial=null. Final saved state commits
  1793461086 with pending/trial=null after resume. Cleanup records airplane off,
  stopped app/mocks, unreachable owned services and no forwards. All 39 supplied
  final audit checks pass; their preliminary missing-file failures are excluded.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. A successful Settings return is useful regression
evidence, not a reason to dismiss the earlier ANR or process/renderer loss.
Require blocking-thread/transaction-owner evidence and recovery coverage before
a causal runtime change. F-27 host-file lifecycle, F-29 ordinary launch and F-34
stale banner remain open or limited; app pagination remains deferred. Kundalini
F-63/F-65 and F-64 adoption status are unchanged.

Evidence validation: BOM-aware saved-result assertions, exact new callback lines,
raw hashes, all 29 branch-tip ancestry checks in both repos and unchanged
implementation trees against gated R31 code 38a7714 / site fb7bc44. The first
local lastanr assertion used uppercase No; it passed after matching the actual
lowercase saved text. No runtime assertion or test was changed.

Fresh package/site gates on the unchanged combined implementation (October 31).
Logs: `%TEMP%/valence-oct31-app22-*.log`.

| Gate | Result |
| --- | --- |
| Root npm test | 107 passed, zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core flutter test --no-pub --concurrency=2 | 556 passed |
| Core / push dart analyze --fatal-infos . | No issues in either package |
| Core / push flutter pub publish --dry-run | Zero warnings; push retains one local-override hint |
| Push / example flutter test --no-pub | 2 / 28 passed |
| Bridge node --test test/*.test.ts | 29 passed, zero failures/skips |
| Bridge strict/verbatim TypeScript | Passed with -p tsconfig.json --strict --verbatimModuleSyntax |
| Root / bridge npm pack --dry-run | Passed / passed |
| Site npm run build / SEO | 44 pages passed |
| Debug APK / standalone Windows py Firebase audit | Passed, assembleDebug 235.9s / PASS: graph, manifest and all 19 DEX files |

The APK used process-scoped 2 GiB Gradle heap, 1 GiB metaspace, two workers
and ActiveProcessorCount=2. The existing app_badge_plus Kotlin migration warning
remains. The Firebase audit ran standalone through Windows py after the build.
Full gates passed on their first completed runs; no test assertion was weakened.

Integration readiness is not beta acceptance. No emulator run, independent
runtime review, app writes, protected-branch changes, package/schema changes,
pushes or publications occurred. iOS and real remote push remain unverified.


## App-c iteration 21 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 21.
Packages remains code d771105 / site 53d3a91. All 29 feature and compatibility
tips, including sync-fixes, plus packages are ancestors of integration in both
repos. No missing merge or eligible must-have remains. S1 stays parked; S2 needs
a Play account.

F-36 recurs with a different immediate termination mechanism:

- Saved lowmemorykiller lines show renderer 24724 killed at 20:17:09.533, then
  host 24584 directly killed at 20:17:09.574 because the minimum memory watermark
  remains breached. Exit-info independently records both as LOW_MEMORY. This
  differs from iteration 20's Chromium-initiated host termination after eviction.
- Start proc 25623 at 20:17:13.337 follows the runner's explicit start. Retained
  paint establishes recovery, not uninterrupted Settings return. This identifies
  the immediate system kills, not the source of memory pressure or a Valence leak.
  No new F-35 ANR is established; its historical evidence remains open.
- Ordinary launch again opens an orphaned picker without an App C PID (F-29).
  Initial offline busy/pending1 after a network-constraint stop fails acceptance;
  the later offline/pending1 and reconnect/ok/pending0 belong to a recovered retry.
  Rootless debuggerd refusal and a SIGQUIT tombstoned receipt do not supply an
  actual blocking stack or identify a transaction owner. F-33 remains major/open;
  successful foreground probes do not prove worker overlap or repair.

Separately checked current background acceptance without operating either app:

- Exact callback begin 20:31:23.950, complete 20:31:26.135 and WorkManager SUCCESS
  20:31:26.150 share PID 27693 and are absent from the before log. First worker
  receipts pull two units above cursor 290001 and acknowledge two outgoing
  inspection objects. Later foreground traffic is excluded.
- Supplied pre-resume SQLite results record the incoming fixture at USN 300002,
  inspection objects at 300001/300002 and outboxCount=0. This run checked supplied
  results, not an independent database extraction. One forced execution does not
  establish cadence. Recomputed the corrected observation window as 396.3 seconds;
  the earlier 370 value counts polling iterations, not elapsed seconds.
- Independently compared and hashed both raw activation files: byte-identical,
  SHA256 87215eb1f2920d96bd0d19f83147b5a0153f1ca7c9890bf8bc40396b79d6d873,
  current 1793457564 / pending 1793457574 / trial=null. Final saved state commits
  1793457574 with pending/trial=null after resume. Cleanup records airplane off,
  stopped app/mocks, unreachable owned services and no forwards.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. Distinguish direct OS process loss from unhandled
renderer loss; require process/renderer recovery coverage and an accessible
blocking-thread trace before a causal runtime change. F-27 host-file guidance,
F-29 ordinary launch, F-34 stale banner and major F-33/F-35/F-36 remain open or
limited. Pagination remains deferred app scope. Kundalini F-63/F-65 and F-64
adoption status are unchanged.

Validation: BOM-aware saved-evidence assertions, raw hashes, corrected timing,
all 29 branch-tip ancestry checks in both repos, unchanged implementation trees
against fully gated R31 integration code 38a7714 / site fb7bc44, matching new
report sections and git diff --check. Earlier October 31 full gates retain their
original scope; no fresh package/site gate pass, emulator run or independent
runtime review is claimed for this report-only refresh. Integration readiness
is not beta acceptance. No app writes, protected-branch changes, package/schema
changes, pushes or publications. iOS and real remote push remain unverified.


## App-c iteration 20 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 20.
Packages remains code d771105 / site 53d3a91. All 29 feature and compatibility
tips, including sync-fixes, plus packages are ancestors of integration in both
repos. No missing merge or eligible must-have remains. S1 stays parked; S2 needs
a Play account.

New major F-36 has direct saved evidence of renderer eviction and host termination:

- At 19:18:43.137 lowmemorykiller kills renderer 19933 because the minimum memory
  watermark remains breached. Chromium in host PID 19805 logs renderer loss at
  19:18:43.347 and unhandled loss followed by application termination at
  19:18:43.415. Exit-info independently records renderer LOW_MEMORY at
  19:18:43.239 and host SIGNALED/status 9 at 19:18:43.685.
- This establishes the immediate eviction/termination sequence, not the source
  of memory pressure, a Valence leak or the cause of F-35. The saved lastanr
  remains the historical 18:14:22 permission-focus ANR. Loaded App info and
  explicit recovery do not establish uninterrupted Settings return.
- Initial ordinary launch again opens an orphaned picker without an App C PID.
  Fresh-task recovery and settled mixed-link retries do not close F-29.
  Startup completion and later successful sync do not repair major/open F-33.

Separately checked current background acceptance without operating either app:

- One isolated execution is observed after 274 seconds, forced=true. Exact new
  callback begin/complete lines and same-PID WorkManager SUCCESS at 19:32:37.626
  are present in the saved native log. First worker mock receipts pull two units
  above cursor 260001 and acknowledge two outgoing inspection objects.
  Later foreground traffic is excluded; one run does not establish cadence.
- Supplied pre-resume SQLite results record the incoming fixture at USN 270002,
  outgoing inspection objects at USNs 270001/270002 and outboxCount=0.
  This run checked supplied results, not an independent database extraction.
- Independently compared and hashed both raw activation files: byte-identical,
  SHA256 cf7e42b623cf2e743f56aa0f6257c7646bbfe091b3c589bba0642896e1cab0e2,
  current 1793454074 / pending 1793454142 / trial=null. Final saved state commits
  1793454142 with pending/trial=null after resume. Cleanup records airplane off,
  stopped app/mocks, unreachable owned services and no forwards.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. Record F-36 as a distinct major release qualification;
do not infer a causal runtime fix from renderer eviction or fold it into F-35.
Renderer-loss recovery coverage and actual blocking-thread evidence remain needed.
F-27 host-file guidance and F-34 stale banner remain open; pagination is deferred
app scope. Kundalini F-63/F-65 and F-64 adoption status remain unchanged.

Validation: BOM-aware saved-evidence assertions (the initial UTF-8-only assertion
failed on UTF-16 diagnostics and passed after encoding detection), raw hashes,
all 29 branch-tip ancestry checks in both repos, unchanged implementation trees
against fully gated R31 integration code 38a7714 / site fb7bc44, matching new
report sections and git diff --check. Earlier October 31 full gates retain their
original scope; no fresh package/site gate pass, emulator run or independent
runtime review is claimed for this report-only refresh. Integration readiness
is not beta acceptance. No app writes, protected-branch changes, package/schema
changes, pushes or publications. iOS and real remote push remain unverified.


## App-c iteration 19 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 19.
Packages remains code d771105 / site 53d3a91. All 29 feature and compatibility
tips, including sync-fixes, plus packages are ancestors of integration in both
repos. No missing merge or eligible must-have remains. S1 stays parked; S2 needs
a Play account.

The new major F-35 is a confirmed Fieldnote ANR with an unisolated cause:

- Visually inspected current-native.png: Android's "Fieldnote isn't responding"
  overlay covers the notification permission dialog. Saved lastanr and events
  identify PID 14128, a 5007ms lost-focus timeout and detection at 18:14:22.332.
  Detection precedes the denial audit at 18:14:22.851, the logged background
  callback at 18:14:25.217 and the second permission activity at 18:14:26.211.
  This chronology does not establish which operation blocked the thread.
- The saved lastanr contains task state and the reason, not the actual blocking
  thread trace. Missing ten-second R29 wait logs cannot exclude a five-second
  stall or platform/plugin work. The later worker callback is not established
  as the ANR's cause.
- Wait did not restore bridge replies. Explicit fresh-task recovery and the
  labeled settled denied/granted/background-refusal retry do not close F-35.
  Clear-data followed by private-backup restoration invalidates Keystore
  material; resulting unwrap errors do not establish a production storage
  defect or successful credential retention.

Separately checked retained worker/update artifacts without operating either app:

- One forced isolated execution is observed after 213 seconds. Exact new
  PID 17385 lines, absent from the before log, establish callback begin
  18:29:38.831, completion 18:29:40.437 and WorkManager SUCCESS 18:29:40.450.
  The first owned mock request block pulls two unit rows above cursor 230001
  and acknowledges two inspection objects. Later foreground receipts are
  excluded. Rejected total-count arithmetic is not execution evidence.
- Supplied pre-resume SQLite results record iteration-19-isolated-inbound at
  USN 240002, outgoing objects at 240001/240002 and outboxCount=0. This run
  checked supplied results and receipts; it did not independently query the
  native database. One execution does not establish long-term cadence.
- Independently compared and hashed both raw activation files: each is SHA256
  67415a3e9f561f2186ff74565bfdde9ee1e009f6be48b17e481c0a184c5342f3.
  Current 1793450413, pending 1793450449 and trial=null remain byte-identical.
  Final state commits 1793450449 with pending/trial=null after resume.
- Settled offline/reconnect results report pending 1 then 0. The supplied
  46-check audit explicitly preserves F-35 as major/open. Corrected cleanup
  records airplane off, stopped app/mocks and no forwards; the rejected first
  cleanup with an ANR-time stale forward is retained as a failed attempt.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. F-33 and F-35 remain major/open; successful retries
and isolated workers do not establish a repair. Actual blocking-thread evidence
is needed before attributing F-35 to runtime code. F-27 host-file guidance, F-29
historical launcher recovery and F-34's stale banner remain open; pagination is
deferred app scope. Kundalini F-63/F-65 and F-64 adoption status are unchanged.

Validation: BOM-aware saved-evidence assertions, raw hashes, all 29 branch-tip
ancestry checks in both repos, unchanged implementation trees against fully gated
R31 integration code 38a7714 / site fb7bc44, matching new report sections and
git diff --check. Earlier October 31 full gates retain their original scope;
no fresh package/site gate pass, emulator run or independent runtime review is
claimed for this report-only update. Integration readiness is not beta acceptance.
No app writes, protected-branch changes, package/schema changes, pushes or
publications. iOS and real remote push delivery remain unverified.


## App-c iteration 18 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 18.
Packages remains code d771105 / site 53d3a91. All 29 numbered feature and
compatibility tips, plus packages, are ancestors of integration in both repos.
No missing merge or eligible must-have remains. S1 stays parked; S2 needs a
Play account.

Checked retained iteration-18 artifacts without operating or modifying either app:

- One natural isolated callback is observed after 388 seconds, forced=false.
  Native begin/complete counts increase from three to four; WorkManager reports
  SUCCESS at 17:58:41.552, captured before foreground resume. The first owned
  mock request block pulls two units above cursor 200002 and acknowledges two
  outgoing inspection objects. Later foreground requests are excluded.
  One natural execution does not establish long-term cadence.
- Supplied pre-resume SQLite results record iteration-18-isolated-inbound at
  USN 210002, outgoing objects at USNs 210001/210002 and outboxCount=0. The report
  records stable DB/WAL snapshots. This run checked supplied results and receipts;
  it did not extract or independently query the device database. The mistakenly
  early inbound fixture is excluded; both inbound fixtures are cleaned up later.
- Independently hashed both raw activation files: each is SHA256
  a739c26f80056a32ae5b8b84791ec9c6b2ee9aa34339cde878c2567fdcdadd84.
  Current 1793448385, pending 1793448396 and trial=null stay byte-identical.
  Final state commits 1793448396 after foreground resume, pending/trial=null.
- Initial PID 9407 takes 8076ms to open, including 7364ms in store. Four later
  foreground sync replies are ok; accepted force requests do not establish four
  overlaps. Timings do not identify a lock owner or repair the COMMIT error.
  Major F-33 remains open.
- Recreated picker/warm-0102/process-death/cold-0402 routing passes on host4.
  Ordinary launcher later returns the unfinished picker with app.state background;
  BACK dismissal restores foreground before matched-sequence OTA acceptance.
  F-29 remains limited; original ghost-task recovery is not proven.
- Warm audit: one tap/zero violations. Final evidence audit: all 44 checks pass.
  Settled offline/reconnect results report pending 1 then 0. Cleanup records
  airplane off, stopped app/mocks and no forwards. Release installation followed
  by explicit backup restoration differs from uninterrupted release-to-debug adoption.
- The corrected canonical migration-guide comparison matches iteration 17.
  The initial alternate-filename 404 establishes no prior evidence gap.
  The stale v0.3 landing banner remains tracked under minor F-34.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. One natural callback strengthens background
acceptance without closing F-33. F-27 host-file lifecycle guidance, F-29 launcher
recovery and F-34 documentation remain open; pagination stays deferred app scope.
Kundalini F-63/F-65 and F-64 adoption status are unchanged; its app schema 17 is
separate from runtime R31 revision 17.

Validation: read-only evidence assertions including raw hashes, branch ancestry,
unchanged implementation trees against fully gated R31 integration code 38a7714 /
site fb7bc44, matching new report sections and git diff --check. Earlier October 31
full gates retain their original scope; no fresh package/site gate pass, emulator
run or independent runtime review is claimed for this report-only update.
Integration readiness is not beta acceptance. No app writes, protected-branch
changes, package/schema changes, pushes or publications. iOS and real remote push
delivery remain unverified.


## App-c iteration 17 completed follow-up

Reviewed both findings and newest reports read-only: Kundalini 16 and app-c 17.
Packages remains code d771105 / site 53d3a91. All 29 checked numbered feature
and compatibility tips, plus packages, are ancestors of integration in both
repositories. No missing merge or eligible must-have remains. S1 stays parked;
S2 needs a Play account.

Checked retained iteration-17 artifacts without operating or modifying either app:

- Fresh-task PID 5121 completes open in 1146ms and paints retained OTA 1793444775.
  Its log contains older callbacks from earlier PIDs; those are not evidence of
  a current startup/worker overlap. Four foreground sync replies are ok/pending=0;
  accepted force commands alone do not prove simultaneous callbacks. Major F-33
  remains open without an established recurrence or repair of the COMMIT error.
- Recreated unfinished-picker/warm-0102/cold-0402 explicit links pass on host4;
  the native initial accessor returns unit-0402. A later normal launcher brings
  the old picker forward while app.state remains background. Dismissing it
  restores foreground. The first OTA observer had a false foreground premise;
  this is not evidence of an updater failure or original ghost-task recovery.
- The initial OTA helper also accepted a stale pending sequence. Its corrected
  replacement requires the staged sequence and a settled commit. Accepted raw
  states record good 1793446774, broken trial 1793446785 with trialFails=1, then
  that sequence in bad with current still 1793446774; rollforward 1793446838
  commits. Excluded first attempts do not support rollback acceptance.
- Rebuilt host4's isolated worker is eligible forced execution, observed after
  93 seconds. Callback begin/complete counts increase from four to five. PID
  8836 begins at 17:29:49.195, completes at 17:29:50.105 and reports WorkManager
  SUCCESS at 17:29:50.124. The first owned mock request block pulls two unit rows
  above cursor 170001 and acknowledges two outgoing inspection objects. Later
  foreground requests are excluded; natural scheduling cadence is not proven.
- Supplied pre-resume SQLite results record iteration-17-inbound at USN 180002,
  outgoing objects at USNs 180001/180002 and outboxCount=0. The report records
  stable DB/WAL snapshots. This run checked supplied results and receipts; it
  did not extract or independently query the device database.
- Independently hashed both raw activation files: each is SHA256
  3c686aae61fcba84b408c44a25ac90a143cc0e6e36d3dbb02b5b343a0784b502.
  Current 1793446838, pending 1793446866 and trial=null stay byte-identical.
  Final state commits 1793446866 with pending/trial=null after foreground resume.
- The warm audit records one tap/zero violations; the supplied evidence audit
  passes all 45 checks. Cleanup records airplane off, stopped app/mocks,
  unreachable endpoints and no forwards. Retained release installation followed
  by explicit private-backup restoration is distinct from uninterrupted
  release-to-debug adoption. Cross-clock latency is not inferred.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. F-33 remains major/open; F-27's host-file lifecycle
guidance and F-29's normal-launch picker limitation remain open. New minor F-34
is confirmed in captured docs and site src/content/docs/docs/index.mdx: its
banner still says v0.3. Record that documentation correction as outstanding;
do not infer a runtime version from the banner or change package versions.
Pagination stays deferred app scope. Kundalini F-63/F-65 and F-64 adoption
status are unchanged; its app schema 17 is separate from runtime R31 revision 17.

Validation: read-only evidence assertions including raw hashes, branch ancestry,
unchanged implementation trees against fully gated R31 integration code 38a7714 /
site fb7bc44, matching new report sections and git diff --check. Earlier October 31
full gates retain their original scope; no fresh package/site gate pass, emulator
run or independent runtime review is claimed for this report-only update.
Integration readiness is not beta acceptance. No app writes, protected-branch
changes, package/schema changes, pushes or publications. iOS and real remote push
delivery remain unverified.


## App-c iteration 16 completed follow-up

Read both findings and newest reports read-only: Kundalini 16 and app-c 16.
Packages remains code d771105 / site 53d3a91. All 29 checked numbered feature
and compatibility tips, plus packages, are ancestors of integration in both
repositories. No missing merge or eligible must-have remains. S1 stays parked;
S2 needs a Play account.

Checked retained iteration-16 artifacts without operating or modifying either app:

- Current fresh-task PID 424 starts background sync at 16:40:31.807, before
  open completes at 16:40:31.995; the callback completes at 16:40:45.388.
  startup-logcat.txt is historical; fresh-task-logcat.txt supplies this overlap
  on the prior OTA, before the rebuilt install. No original COMMIT recurrence
  appears in this interval. Non-reproduction does not repair major/open F-33.
- The initial retained-task launch produces no app PID; explicit fresh-task
  recovery paints retained data. This does not establish a Valence cause or
  recovery of the original ghost task. The recreated unfinished-picker/link/
  process-kill sequence on rebuilt host4 reaches Carlow and returns native
  unit-0402. The combined app-owned latest-link/early-listener mitigation is
  preserved; no built-in link contract or package repair follows from it.
- Unlike iteration 15's host3-only isolated worker, this isolated run follows
  the host4 rebuild. The observer records forced execution after 484 seconds.
  Callback begin/complete counts each increase from four to five; PID 4424 begins
  at 16:59:36.159, completes at 16:59:37.661 and reports WorkManager SUCCESS at
  16:59:37.674. The first owned mock request block pulls two unit rows above
  cursor 140001 and acknowledges two outgoing inspection objects. Later
  foreground requests are excluded. This is not natural periodic cadence.
- The supplied pre-resume SQLite result records iteration-16-inbound at USN
  150002, outgoing objects at USNs 150001/150002 and outboxCount=0. Its companion
  review records stable private DB/WAL snapshots. This run checked supplied
  rows and receipts; it did not extract or independently query the device DB.
- Independently hashed both raw activation files: each is SHA256
  87399eea2140d060408894c700964feb9194bcbb5eb3062e19dc5eb1765a0809.
  Current 1793444756, pending 1793444775 and trial=null stay byte-identical.
  This extends pending-OTA preservation evidence to the rebuilt host4 interval.
- The warm tap preserves string ID iteration-16-rebuilt-warm; its audit records
  one tap/zero violations. Final state commits 1793444775 with pending/trial=null.
  The supplied 40-check audit passes; cleanup records airplane off, stopped app
  and mocks, unreachable mock endpoints and no forwards. Retained release
  validation followed by explicit backup restoration remains distinct from
  uninterrupted release-to-debug adoption. Cross-clock latency is not inferred.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. A successful overlap cannot close F-33. App-c
F-27's host-file lifecycle/limits guidance remains open; the existing 50-unit/
200-inspection pagination limit stays deferred app scope. Kundalini's F-63/F-65
and F-64 retirement-tooling adoption status are unchanged. Its app schema 17
for deep-link adoption is separate from the runtime's R31 revision 17.

Validation: read-only evidence assertions including raw hashes, branch ancestry,
unchanged implementation trees against fully gated R31 integration code 38a7714 /
site fb7bc44, matching new report sections and git diff --check. Earlier October 31
full gates retain their original scope; no fresh package/site gate pass, emulator
run or independent runtime review is claimed for this report-only update.
Integration readiness is not beta acceptance. No app writes, protected-branch
changes, package/schema changes, pushes or publications. iOS and real remote push
delivery remain unverified.


## App-c iteration 15 completed follow-up

Read both findings and newest reports read-only: Kundalini 16 and app-c 15.
Packages remains code d771105 / site 53d3a91. Ancestry checks find the original
rebase queue, R14, later numbered feature branches, R4 notification compatibility
and R31 already included in integration in both repositories. No missing merge
or eligible must-have remains. S1 stays parked; S2 needs a Play account.

Checked retained iteration-15 evidence without operating or modifying either app:

- F-29 recurs on corrected web-only OTA 1793441848: the settled page remains
  Flat 2 and the legacy initial accessor returns unit-0102 after the requested
  unit-0402 launch. Early subscription alone is not an accepted complete repair.
  Host4 combines early web subscription/replay with app-owned subscribe-first
  latest-link initialization. Both host4-mixed-pass files pass; their paired
  pages show Carlow and native accessors return unit-0402. These are two recreated
  unfinished-picker/link/process-kill stacks, not recovery of the original ghost
  task. No isolated Valence package cause or package repair is established.
- PID 24814 begins background sync at 15:39:18.126 and completes at 15:39:25.991;
  the report places open completion at 15:39:18.274. This successful startup
  overlap does not repair the earlier COMMIT error. Four later foreground
  successes do not prove four more overlapping callbacks. F-33 remains major/open.
- Isolated worker evidence belongs to host3, before the host4 native rebuild.
  The observer records eligible forced execution after 425 seconds; callback
  begin/complete counts each increase once and WorkManager reports SUCCESS.
  The first owned request block pulls two unit rows above cursor 110001 and
  acknowledges two outgoing inspection objects. Later foreground requests are
  excluded. This is not natural periodic cadence or host4 worker acceptance.
- The supplied pre-resume SQLite result records incoming iteration-15-inbound
  at USN 120002, outgoing objects at USNs 120001/120002 and outboxCount=0.
  This run checked that supplied result and receipts; it did not extract or
  independently query a device database.
- Independently hashed raw activation files both equal SHA256
  3554c1ea31bcdbd529b510737b037c14f0113ab22f094d501dad92a6f774f549.
  Current 1793441161, pending 1793441170 and trial=null remain byte-identical.
  This pending-OTA preservation proof stays scoped to host3.
- The final warm event preserves string ID iteration-15-rebuilt-warm; its
  contract audit records one tap and zero violations. Final state commits host4
  OTA 1793442939 over builtin 1793442054, with pending/trial=null. The supplied
  40-check audit passes; captured cleanup records airplane off, stopped app and
  mocks, unreachable mock endpoints and no forwards. Retained release validation
  plus explicit private backup restoration is distinct from uninterrupted
  release-to-debug adoption or original ghost-task recovery.

Decision: preserve users' data, shipped contracts, additive R31 revision 17 and
transaction/lease/retry rules. A passing overlap does not resolve F-33, and the
legacy app's routing mitigation does not justify changing built-in link semantics.
App-c F-27's host-file lifecycle/limits documentation gap remains open; the
50-unit/200-inspection pagination limit remains deferred app scope. Latest-versus-
initial legacy link migration guidance and mixed-task/notification precedence
remain follow-up needs identified by the app report. Kundalini's F-63/F-65 and
F-64 retirement-tooling adoption status are unchanged.

Validation: read-only evidence assertions (including raw hashes), branch ancestry,
unchanged implementation trees against fully gated R31 integration code 38a7714 /
site fb7bc44, matching new report sections and git diff --check. Earlier October 31
full gates retain their original scope; no fresh package/site gate pass, emulator
run or independent runtime review is claimed for this report-only update.
Integration readiness is not beta acceptance. No app writes, protected-branch
changes, package/schema changes, pushes or publications. iOS and real remote push
delivery remain unverified.


## App-c iteration 14 completed follow-up

Both findings and newest reports were read read-only: Kundalini 16 and app-c 14.
Packages remains code d771105 / site 53d3a91. The original rebase queue, R14,
R31 and the R4 notification-compatibility acceptance tip are already ancestors of
integration in both repositories. No missing merge or eligible must-have remains;
S1 stays parked and S2 needs a Play account.

Checked the retained iteration-14 captures without running or modifying either app:

- PID 20066 begins background sync at 14:39:14.440, before startup completes at
  14:39:14.582 (2432 ms); callback completion is 14:39:21.704 and WorkManager
  SUCCESS is 14:39:21.747. The mocks were stopped, so initial offline replies
  are expected. Later settled status is ok/pending=0. Four later foreground
  replies do not establish four worker overlaps. F-33 remains major/open.
- The actual warm tap carries string ID iteration-14-rebuilt-warm; the contract
  audit records one tap and zero violations. This preserves the supported legacy
  adapter and shipped event shape; the report separately records cold routing.
- The isolated worker begins at 15:07:00.151, completes at 15:07:01.527 and has
  WorkManager SUCCESS at 15:07:01.550. Its first owned mock request block pulls
  two units above cursor 80001 and acknowledges two outgoing inspection objects.
  Later requests follow foreground resume and are excluded. This is eligible
  forced execution, not natural periodic cadence or production durability.
- The supplied pre-resume SQLite result records inbound iteration-14-inbound at
  USN 90002, outgoing objects at USNs 90001/90002 and outboxCount=0. The report
  records matching DB/WAL snapshots. This run checked the supplied result and
  receipts; it did not extract or independently query the device database.
- Both raw activation files independently hash to SHA256
  313aac16dd04fe2de00dde2a4e1e4535e233a432c52ca46781d51f3eb6282817.
  Current 1793437904, pending 1793437991 and trial=null stay byte-identical.
  Final state records current 1793437991, previous 1793437904, pending/trial=null.
  The supplied 39-check audit passes; cleanup records airplane off, stopped app,
  stopped/unreachable mocks and no forwards. Release retention followed by private
  backup restoration is distinct from uninterrupted release-to-debug adoption.

Decision: preserve users' data, transaction scopes, lease/retry rules and additive
R31 revision 17. Non-reproduction does not repair the earlier COMMIT failure.
F-33 and app-c F-27's host-file lifecycle/limits documentation gap remain open.
The newly documented 50-unit/200-inspection pagination limit is an existing app
limit, explicitly deferred by its reviewer; it is not a new Valence regression.
Kundalini's findings and retirement-tooling adoption status are unchanged.

Validation: read-only evidence assertions, branch ancestry, unchanged implementation
trees against the fully gated R31 integration (code 38a7714 / site fb7bc44),
matching new report sections and git diff --check. The first evidence check could
not decode a UTF-16LE capture; BOM-aware reading passed without changing any
capture. Earlier October 31 full gates retain their original scope; no fresh
package/site gate pass, emulator run or independent runtime review is claimed.
No app writes, protected-branch changes, package/schema changes, push or
publication. Integration readiness is not beta acceptance; iOS and real remote
push delivery remain unverified.


## App-c iteration 13 completed follow-up

Both findings and newest reports were read read-only: Kundalini 16 and the now
completed app-c 13. Code packages remains d771105 / site packages 53d3a91. The
original rebase queue, R14 and every later numbered feature tip are included in
integration. Only R31 and the notification-compatibility report tip are not yet
ancestors of packages; both are already integrated in the recorded order above.
No changed base, missing merge or eligible must-have requires new feature work.
S1 stays parked and S2 needs a Play account.

Independently inspected app-c's retained iteration-13 captures, without running
the app or writing to either test repository:

- PID 14117 starts its worker at 12:40:31.602, before Valence.open completes at
  12:40:31.786 (4804 ms). The callback completes at 12:40:48.584 and WorkManager
  reports SUCCESS at 12:40:48.786. first-sync.json and first-status.json report
  ok/pending=0. This is one successful startup overlap; it neither reproduces
  nor repairs the earlier COMMIT error. Major F-33 remains open.
- warm-tap-events.json carries the original string ID iteration-13-rebuilt-warm.
  event-contract-check.json records one tap and no violations. The completed
  report separately records cold routing and scoped native regression. F-30
  stays resolved for the supported adapter; no shipped signature is changed.
- The isolated worker begins at 14:02:39.178, completes at 14:02:40.608 and has
  WorkManager SUCCESS at 14:02:40.625. worker-mock.log's first owned request block
  records two incoming unit rows above cursor 50001 and two outgoing inspection
  acknowledgements. Later requests follow foreground resume and are excluded.
  Host/mock and guest clocks differ. This is eligible forced execution, not
  natural periodic cadence or production server durability.
- background-sqlite-before-resume.json records inbound iteration-13-inbound at
  USN 60002, outgoing inspection objects at USNs 60001/60002 and outboxCount=0.
  Its companion snapshot report records stable database/WAL hashes. These are
  supplied snapshot evidence, not a fresh database extraction in this run.
- Independently hashed both raw activation files: each is SHA256
  62afdc05f02e7ee69e2b48245995c9839f4fa5fb9948985df187f2df707bf41a.
  Current 1793434187, pending 1793434205 and trial=null remain byte-identical.
  final-state.json records current 1793434205, previous 1793434187 and no
  pending/trial. cleanup.json records airplane off, stopped app, refused owned
  mock ports and no forwards. The report explicitly distinguishes retained
  release validation plus private backup restoration from uninterrupted
  release-to-debug adoption.

Decision: prioritize users' data and transaction-ownership evidence. Preserve
shipped contracts, R31's additive revision 17, lease semantics and retry budgets;
a successful overlap does not justify a speculative concurrency patch or closing
F-33. App-c F-27's host-file lifecycle/limits documentation gap also remains open.
Kundalini's F-63/F-65 reports and F-64 adoption status are unchanged; packages
already contains S4's retirement tooling. Integration readiness is not beta
acceptance.

Validation for this report-only follow-up: branch ancestry, unchanged code/site
implementation trees against the fully gated R31 integration, matching new report
sections and git diff --check. The earlier October 31 full gates retain their
original scope; no fresh gate pass, emulator run or independent runtime review is
claimed. No test-app writes, protected-branch changes, package/schema changes,
pushes or publications. iOS and real remote push delivery remain unverified.


## 2026-10-31: R31 store-host update integration

Fresh codex/integration starts from newest code packages d771105ad666e84b29c1545ed7b6db403f79d46a
and site packages 53d3a919b999fe62fee3d3928bbaf3a235068c58. The original queue and
R14 are already included there; their schema numbers are retained. Merge order:

| Order | Branch | Code tip | Site tip |
|---|---|---|---|
| 1 | codex/notify-event-compat (R4 acceptance report) | 73cd0390d21f281fa3a2fbdc38e460e65ff09b97 | 057ce527402ee6d78efb966fe5f341880822cacb |
| 2 | codex/r31 (revision 17) | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |

Merge results: code f8d76ef041fdd213c5dc8cd9cc68406e0a402012, site
ddb7268177287167e6c238ff1c1c9f10b8506876. No merge conflicts. Packages and .claude
implementation trees equal the tested R31 tip; site src equals its tested R31 tip.
Previous integration report history is retained below and its former branch tip
is preserved as codex/integration-before-r31-20261031 in each repository.

Decision: signed native policy before features; keep the unsigned pointer unable
to impose or withdraw a block, preserve users' data and trial attempts, retain
legacy status meanings, and use only compiled store destinations. No package
version changed. The new built-ins revision/schema is 17; older reservations stay.

Read both app findings and latest reports read-only: Kundalini 16 and app-c 13
(still in progress). One successful overlap is not resolution of major F-33.
F-27 remains open. R31 does not modify transactions, retry budgets or sync leases.

R31 branch gates and Android evidence are in [r31-validation.md](r31-validation.md).
The device probe injected a cached **signed** envelope, not a network OTA delivery:
offline cold native block, real Open store launch to Google Play, bad-signature
refusal then signed builtin recovery. Example stopped, fixtures removed, airplane
off and emulator lock released. Published store upgrade and iOS remain unverified.
Independent review found no confirmed remaining issue and ran eight focused R31
Flutter tests successfully. No protected branch merge/commit, test-app writes,
version bump, pushes or publications.

Integration gate rerun completed 2026-10-31 on the merged implementation:

| Gate | Result |
|---|---|
| npm test | 107 passed, zero skips; generated Dart ran |
| Core flutter test --concurrency=1 | 556 passed |
| Core fatal-info Dart analysis | No issues |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 29 passed / passed / passed |
| Example tests | 28 passed |
| Push tests / fatal-info analysis | 2 passed / no issues |
| Core / push pub publish --dry-run | Zero warnings / zero warnings, one existing override hint |
| Root npm pack --dry-run | Passed |
| Site build and SEO | 44 pages passed |
| Example codegen check / signed builtin | No stale output / seq 1793431100 verified |
| Debug APK | Passed in 26.7s |
| Windows py Firebase audit | PASS: package graph, manifest and all 19 DEX files free of Firebase SDK references |

APK SHA256 is 18123186a1fbfd5cdaf3071d733c0fb2bf43e485941b5992c664f8ddb84cb8b3,
identical to the device-tested R31 APK. Gate logs: %TEMP%/valence-r31-integration-*.log.
Implementation trees still match codex/r31, both worktrees are clean, and packages
heads remain d771105 / 53d3a91. The final changes below this validation are reports
only; the package/site source and signed artifacts are unchanged.

Earlier full gates below retain their original scope. R31 readiness does not close
app-c F-33/F-27, establish network policy delivery, or verify iOS or a public store
upgrade. No additional must-have is eligible; S1 stays parked and S2 needs a Play
account. All app repositories remained read-only and the shared emulator was released.



## App-c iteration 12 follow-up

Read both apps' findings and newest reports read-only: Kundalini 16 and app-c 12.
Packages remains code d771105 / site 53d3a91. Rechecked every numbered feature
branch, the original rebase queue, R14, link-compat and sync-fixes: all tips are
ancestors of packages in both repos. The report-only notify-event-compat tip is
already in integration. No eligible must-have, pending feature merge or changed
base requires a branch rebuild. S1 remains parked and S2 needs a Play account.

Checked app-c's iteration-12 captures independently, without running the app:

- F-33: PID 8306 begins a worker at 10:09:41.038 during Valence.open, which
  completes at 10:09:42.680. f33-before-restart-logcat.txt records the named
  store.prefSet lock at 10:10:06.073. before-restart-sync.json answers busy
  with pending=1; recovery-sync.json later answers ok with pending=0.
  The full worker-full-logcat.txt additionally records WorkManager FAILURE at
  10:10:06.200 for work 25728e3a-feed-4620-82e8-d338f90ed437 in the same PID.
  No successful callback completion is established for that run. This failure
  and the reported prolonged busy replies must not be described as a successful
  overlap. They do not identify the lock holder, reproduce the original COMMIT
  error, establish data loss or prove a concurrency repair. The report attributes
  the eventual restart to permission revocation, with DB/account preserved.
- Rebuilt startup completes after a named store.open wait of 10346 ms. Its worker
  begins at 10:25:05.938, after open completes at 10:24:44.368, and completes at
  10:25:07.686. This is settled-path recovery, not a concurrent-open test.
- The rebuilt warm event capture carries string ID iteration-12-rebuilt-warm;
  event-contract-check.json records one tap and zero violations. The report
  separately records cold routing and rebuilt native/OTA regression. F-30 stays
  resolved for the supported adapter; no shipped signature is changed.
- The final isolated worker begins at 10:40:34.538, completes at 10:40:36.298
  and reports WorkManager SUCCESS at 10:40:36.310. The first owned mock block
  records two incoming unit rows above cursor 107, an inspection pull and two
  outgoing object acknowledgements. Later receipts follow foreground resume and
  are excluded. Host and guest clocks differ. This is eligible forced execution,
  not natural periodic cadence or production server durability.
- background-sqlite-before-resume.json records the new inbound unit at USN
  20002, both outgoing inspection objects at USNs 20001/20002 and outboxCount=0.
  Its companion capture records stable DB/WAL hashes. These are supplied snapshot
  evidence, not a new database extraction here. worker-inbound.json also returns
  the new unit. This adds inbound application to the earlier outgoing-only proof.
- Independently hashed both raw activation files: SHA256
  1722bda336ba5405ea21230fae9806e6085215e9e4a3227797c674f1b0818799.
  Current 1793421974, pending 1793421996 and trial=null remain byte-identical.
  final-state.json records current 1793421996, previous 1793421974 and no
  pending/trial. Final reads return null for all three fixtures and pending=0.
  cleanup.json records airplane off, stopped app, refused owned mock ports and
  no forwards. Explicit backup restoration separates retained release validation
  from debug validation; uninterrupted release-to-debug adoption is not claimed.

Decision: prioritize users' data and evidence of transaction ownership. Preserve
the frozen schema 16, shipped contracts, lease rules and retry budgets. Neither a
worker failure nor recovery justifies guessing at a transaction patch. F-33 remains
major/open and F-27's host-file lifecycle/limits documentation gap remains open.
Package integration readiness does not establish beta acceptance.

Validation for this report-only follow-up: branch ancestry, unchanged implementation
trees, matching new report sections and git diff --check in both worktrees. Full
gates below retain their earlier October 31 scope; no fresh gate pass, emulator
run or independent runtime review is claimed. No test-app writes, protected-branch
changes, version/schema changes, pushes or publications. iOS remains experimental
and untested; real remote push delivery remains unverified.

## App-c iteration 11 follow-up

Read both apps' findings and newest reports read-only: Kundalini 16 and app-c 11.
No eligible must-have remains. The original queue, R14 and every later numbered
feature tip are ancestors of packages in both repositories. The only unmerged
compatibility tip, notify-event-compat, contains reports and is already included
in integration. Packages has not moved: code d771105 / site 53d3a91. Integration
differs from those bases only in this report and notification-event-compat.md.
No branch reconstruction or new feature merge is necessary.

Independently checked app-c's iteration-11 captures:

- startup-settled.txt records worker begin at 09:09:40.874, Valence.open completion
  at 09:09:40.948 and worker completion at 09:09:59.354, without the earlier COMMIT
  failure in this sample. Four successful foreground replies in f33-results.json
  do not prove four overlaps: the force attempts lack matching worker callbacks.
  F-33 remains major/open; non-reproduction is not resolution.
- warm-tap-events.json carries string ID iteration-11-warm; the event audit has
  one observed tap and zero violations. The supported adapter continues to
  preserve the shipped event. The report separately records cold routing.
- Independently hashed both raw background-state files: each is SHA256
  0311e11e21dabc351162085d5b23f8ca3bf9a0321abdff4ffa43a8f9091a5ccf.
  Current 1793417877, pending 1793417997 and trial=null stay unchanged across the
  isolated worker. The callback runs 09:36:43.933 through 09:36:46.038; its mock
  receives both zero-row pulls and acknowledges two outgoing inspection objects.
  This is an eligible forced run, not natural cadence, inbound row application
  or production durability. Host and guest timestamps use different clocks.
- final-state.json records current 1793417997, previous 1793417877, no pending
  or trial, and broken 1793417821 still bad. cleanup.json records airplane off,
  stopped app, refused owned mock ports and no forwards. Retention evidence
  includes explicit backup restoration; it does not prove an uninterrupted
  release-to-debug upgrade. F-27's host-file lifecycle documentation gap remains.

Decision: prioritize users' data and transaction ownership evidence over a
speculative fix. Preserve the database/account, shipped signatures, schema 16,
lease rules and retry budgets. Do not hide the COMMIT failure behind a busy
result. S1 remains parked and S2 needs a Play account. Package integration
readiness does not establish beta acceptance or close F-33.

Validation for this follow-up: checked branch ancestry, matching reports,
unchanged implementation trees and git diff --check in both worktrees. The full
package/site gates below remain earlier evidence on the unchanged implementation;
they were not rerun and no fresh gate pass is claimed. No new emulator run,
independent runtime review, app writes, protected-branch changes, version/schema
changes, push or publication. iOS remains experimental and untested; real remote
push delivery remains unverified.

## Earlier iteration-10 acceptance refresh

## In plain terms

App-c iteration 10 now passes the legacy notification event audit using the
supported adapter and unchanged shipped schema. A separate sync COMMIT failure,
F-33, remains open. Package gates do not turn its successful retry into a fix.
No new must-have is eligible and no runtime change is made in this refresh.

## Bases, inclusion and decision

Packages remains code `d771105ad666e84b29c1545ed7b6db403f79d46a` and site
`53d3a919b999fe62fee3d3928bbaf3a235068c58`. Checked the original queue in order:
R8, R7, R6, R3, R4, R5, R9, R10, R14. Each tip and every later numbered feature,
link-compat and sync-fixes is already an ancestor of packages in both repos.
The full tip table in the earlier validation below remains applicable.

The R4 acceptance-report tip is merged into the existing integration after those
already-included tips; code `73cd0390d21f281fa3a2fbdc38e460e65ff09b97`, site
`057ce527402ee6d78efb966fe5f341880822cacb`. Only reports differ
from packages. No conflicts or new implementation changes need integration.
Integration merge commits: code `1537f75da0d9844ada650ced18e4b9045c9c1c46`,
site `0b863965b4bb3d272941d3b995a790abd0cfc4e4`.
The previous integration already used these same packages bases; no base moved
and no pending feature tips require a fresh reconstruction.

Decision, security and users' data first: retain the frozen runtime, original
application IDs, shipped event meanings and combined schema 16 (R4 since 11,
pendingIds since 16). Do not suppress COMMIT errors, label them busy, change
transaction/lease budgets or clear data on temporal overlap alone. F-33 needs
a retained-database Android UI/worker reproduction with transaction ownership
evidence before a corrective change can be justified. S1 remains parked, S2
needs a Play account and the post-beta Playground is not started.

## App evidence and limits

Read both VALENCE_FINDINGS.md files and newest reports read-only: Kundalini 16,
app-c 10. Kundalini's link/reboot/pinned-OTA evidence and upstream F-63/F-64/F-65
fixes remain as recorded below; no newer app adoption of those fixes is inferred.

Independently checked app-c's current host wiring and iteration-10 captures:

- F-30: warm-tap-events.json contains string ID `iteration-10-warm` and Flat 1;
  event-contract-check.json reports one tap, zero violations and passed=true.
  The host passes notificationEventAdapter and generated config supplies the
  event-fields gate; cold startup consumes notifications.initial() through the
  same converter. The report captures cold routing and retained JPEG serving.
  This closes F-30 for that snapshot/app adaptation, preserving its frozen schema.
- F-33: reconnect.json returns E_INTERNAL, "no current transaction", SQL COMMIT.
  database-error-logcat.txt records worker begin 08:26:46.380, failed foreground
  call 08:26:46.529 and worker completion 08:26:48.415 in PID 4518. Overlap is
  observed; root cause, data loss and permanent damage are not established.
  reconnect-retry.json reports ok/pending=0: recovery, not resolution.
- Independently hashed both raw background activation files: SHA256
  `b8c751e9fc92c5cde6947e0f38244666801bca381fa40ea8e572c40c8c1f56af`.
  Current 1793414964, pending 1793415091 and trial=null remain identical through
  an eligible **forced** periodic run. Both pulls return zero rows and two fresh
  outgoing objects are acknowledged. No natural cadence, new inbound rows or
  production durability/monotonicity across the in-memory mock restart is proved.
- final-state.json records current 1793415091, previous 1793414964,
  pending/trial=null and bad 1793414884. An early build-2-to-3 upgrade was cleared
  before startup settled and is excluded; later retained build-3 reinstalls do
  not establish that upgrade. F-31 is corrected in the refreshed local guide.
  F-27's host-file lifecycle documentation gap remains open.

No new emulator run or independent runtime review is claimed. Real remote push,
iOS, positive biometrics, physical vibration and outbound share delivery remain
unverified; iOS is experimental and untested. Test-app repositories were not
written. No protected-branch merge/commit, version change, push or publication.

## Fresh gates

Logs: `%TEMP%/valence-oct31-app10-*.log`.

| Gate | Result |
| --- | --- |
| npm test | 106 passed, zero failures/skips; generated Dart and strict/verbatim generated TS ran |
| Core flutter test --no-pub --concurrency=2 | 548 passed |
| Core / push dart analyze --fatal-infos . | No issues in either package |
| Core / push flutter pub publish --dry-run | Zero warnings; push retains one local-override hint |
| Push / example flutter test --no-pub | 2 / 27 passed |
| Bridge node --test test/*.test.ts | 29 passed, zero failures/skips |
| Bridge strict/verbatim TypeScript | Passed with -p tsconfig.json --strict --verbatimModuleSyntax |
| Root / bridge npm pack --dry-run | Passed / passed |
| Example codegen --check / built-in signature verification | written: []; seq 1793209750, two files verified |
| Site npm run build / SEO | 43 pages passed |
| Debug APK / standalone Windows py Firebase audit | Passed, assembleDebug 41.5s / PASS: graph, manifest and all 19 DEX files |

The APK used process-scoped 2 GiB Gradle heap, 1 GiB metaspace, two workers
and ActiveProcessorCount=2. The existing app_badge_plus Kotlin migration warning
remains. The Firebase audit ran standalone through Windows py after the build.

Integration readiness covers source assembly and these package gates. F-33 keeps
app acceptance open. The historical iteration-9 F-30 failure below is superseded
by the iteration-10 evidence above.

## Earlier integration validation - 2026-10-31

## In plain terms

The latest shared candidate and the notification compatibility validation are now
together on `codex/integration` in both repositories. Every required gate passed.
No new feature or runtime change was needed. App-c's notification event audit still
fails on its unadapted host; these package gates do not close that device finding.

## Current bases, inclusion order and decision

Code packages base: `d771105ad666e84b29c1545ed7b6db403f79d46a`.
Site packages base: `53d3a919b999fe62fee3d3928bbaf3a235068c58`.

Both integration branches fast-forwarded from the previous acceptance report to
their newest packages base. Checked the required order below; every original tip
is already an ancestor of packages, so merging those tips introduces nothing.
All later numbered branches, link-compat and sync-fixes are also included in
packages in both repositories. There were no conflicts to resolve.

| Order | Branch | Code tip | Site tip |
| --- | --- | --- | --- |
| 1 | codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| 2 | codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| 3 | codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| 4 | codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| 5 | codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| 6 | codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| 7 | codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| 8 | codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| 9 | codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |

Finally fast-forwarded the ready R4 follow-up, `codex/notify-event-compat`, into
integration: code `02b2071beb7a4d1c34f839fbf56035bf0040ee75`, site
`7ba42aa7332a1ec5e57b03c08344d582ab0a7447`. Its only difference from packages
is `docs/notification-event-compat.md`; the compatibility implementation and its
review fixes are already merged upstream. The gates below cover the same source
bytes; the follow-up and this integration commit add validation reports only.

Decision, security and data first: preserve the frozen runtime, shipped event
meanings, application IDs and stored data. Keep combined schema 16, R4 since 11
and pendingIds since 16. No package versions or schema numbers change. A numeric
hash cannot recover an application's original string ID; retain the documented
native adapter instead of coercion or rewriting an existing event declaration.
Retain the upstream conservative retirement checks, including missing-release
warnings and no subtraction of the per-device floor. No new security code or
independent runtime review is part of this report-only refresh. S1 stays parked
during the candidate freeze; S2 needs a Play account. No new must-have is eligible.

## Latest app evidence and limits

Read both apps' `VALENCE_FINDINGS.md` and newest completed reports: Kundalini
iteration 16 and app-c iteration 9. Test-app repositories were read-only.

Kundalini reports schema-17 store adoption, warm/cold/repeated custom links,
unsafe-path rejection, pinned requires.bridge 16 OTA commitment and seven alarms
restored after reboot without a manual launch. Its observed boot delay is not a
delivery-time guarantee. Upstream packages now includes the F-63 link-manifest
diagnostic, F-65 association-file refusal and F-64 method-retirement work; this
does not establish adoption of those changes by the app. A bridge floor alone
does not prove that an old method has no callers.

App-c iteration 9 still reports F-30 FAIL. Independently read its
`event-contract-check.json`: one tap, numeric ID 1997876972, expected string,
passed=false. Its current mobile/lib contains neither notificationEventAdapter
nor notificationEventFields, so this is not acceptance of the merged correction.
It needs refreshed tooling/runtime, regeneration, native adapter wiring, a new
host build and real warm/cold acceptance while preserving its shipped schema.

Its `background-state-comparison.json` independently confirms identical before
and after activation hashes with 1793383609 pending. The report records one
natural due-time worker acknowledging two scalar writes; this is not a cadence
guarantee. `final-state.json` confirms 1793383609 committed, pending/trial null
and bad 1793383520 retained. Routing, background work and OTA success do not repair
the separately failing event contract. F-27's remaining host-file lifecycle
documentation gap stays open. F-31's permissions floor is corrected to schema 10
upstream; its captured local guide is older. F-32 did not recur and does not
establish a package cause. Real remote push and iOS remain unverified; iOS is
experimental and untested.

## Fresh gates on the current candidate

Logs: `%TEMP%/valence-oct31-integration-*.log`.

| Gate | Result |
| --- | --- |
| npm test | 106 passed, zero failures/skips; generated Dart and strict/verbatim generated TS ran |
| Core flutter test --no-pub --concurrency=2 | 548 passed |
| Core / push dart analyze --fatal-infos . | No issues in either package |
| Core flutter pub publish --dry-run | Zero warnings |
| Push flutter test --no-pub / pub publish --dry-run | 2 passed / zero warnings, one existing local-override hint |
| Bridge node --test test/*.test.ts | 29 passed, zero failures/skips |
| Bridge npx -y -p typescript tsc -p tsconfig.json --strict --verbatimModuleSyntax | Passed |
| Root / bridge npm pack --dry-run | Passed / passed |
| Example flutter test --no-pub | 27 passed |
| Example codegen --check / built-in signature verification | written: []; seq 1793209750, two files verified |
| Site npm run build / SEO | 43 pages passed |
| Example flutter build apk --debug | Passed; assembleDebug 137.0 seconds |
| Windows py example/tool/check_no_firebase.py | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |

APK settings were process-scoped: 2 GiB Gradle heap, 1 GiB metaspace, two workers
and ActiveProcessorCount=2. The existing app_badge_plus Kotlin migration warning
remains. The Firebase audit ran standalone through py after the successful build.
An initial manual verification used the wrong assets/builtin directory and failed
ENOENT; only the corrected assets/valence/builtin invocation establishes the
signature check above. No device installation, emulator session or new device
acceptance is claimed. No protected branch commit/merge, test-app write, push or
publication occurred. Integration readiness is conditional on the packages heads
above; refresh if either moves before merging.

## Historical validation - 2026-10-30

## Current decision and scope

No must-have item is eligible: R1-R29 and the R30 compatibility correction are
already done. Read both apps' VALENCE_FINDINGS.md and newest completed reports:
Kundalini iteration 15 and app-c iteration 2. These replace the earlier app-a
acceptance input for this period.

Decision: preserve the frozen runtime, users' data and shipped signatures. The new
reports establish adoption progress without isolating a new framework defect.
Do not change SQLite retry budgets or launch semantics on recovered latency alone.
S1 remains deliberately deferred during the freeze; S2 needs a Play account.
Do not start the post-beta Playground as part of this acceptance refresh.

## Bases and branch inclusion

Code packages base: `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`.
Site packages base: `ce19151baa1fdac40ac3208e70bb69388a8b538a`.

Checked the required queue in order: R8, R7, R6, R3, R4, R5, R9, R10, R14.
Every feature tip is already an ancestor of packages in both repositories.
All later numbered feature branches are also ancestors of packages in both repos.
There are no ready, unmerged feature branches to assemble and no conflict to
resolve. Code codex/integration fast-forwarded to packages; site
codex/integration was recreated from packages after preserving its previous
report-only tip as codex/integration-before-20261030-acceptance.
No merge into a protected branch occurred. Schema/builtins revision stays 16.

R30's legacy `link.initial` cutoff is already merged (code cdd39f0, site ead9e3b).
The API-signature part of app-c F-27 is documented by code d2e6970 and site ce19151.
This does not close the app's broader request for persistence, caps and cleanup
recipes, or establish that it has received these newer docs.

## App evidence and limits

Kundalini iteration 15 reports its first installed schema-16 release upgrade,
retaining 19,227 panchang rows, saved profiles and preferences; signed OTA
1793303605 reached pending, trial and commitment. Its former reminder-delivery
gap is now closed in the app findings. Checked
`test-evidence/iteration-15/F27-notification-record.txt` and visually inspected
`24-notification-fired.png`: package dev.lagna.panchang, id 2494,
daily_panchang channel, title "Friday in Kathmandu" and matching panchang body
are present. This establishes one observed delivery, not a universal timing,
reboot or device guarantee. The report describes recovery from an emulator
crash by rearming on launch. Its dayReady loading fix is app-owned; a slow first
read must not be treated as proof that a stored day is absent.

App-c iteration 2 reports retained release upgrade, fresh airplane seed launch,
offline edit/reconnect, camera/gallery/removal, share sheets, placed widget
updates, R3 denial/grant and a mixed task-history reminder tap. Checked its
rollback-second-logcat.txt and final-logcat.txt: broken 1793305716 failed twice
and was marked bad; final good 1793306236 committed. final-state.json confirms
pending/trial null and the bad sequence retained. r28-queue.json records
64 IDs in 674 bytes, replacement at cap and E_TOO_LARGE for overflow.
background-state-comparison.txt reports byte-identical activation state across
the worker; post-worker-sync-status.json records pending 0 and reason ok.
This was an eligible forced periodic run with an already-empty outbox, so it
does not prove natural scheduling or a fresh background push receipt.
The tested mixed F-29 sequence passed without clean-task recovery, but does not
reconstruct every historical intent flag/two-activity stack or isolate a package bug.

App-c's supplied create-valence artifact still required its local F-26 workaround.
snapshot-hashes.json records create-valence SHA256
43de7c06988a9e30516f848f960c056a86fec456bd5438c1c91ae3fc9c63102f and
bridge SHA256 0d77ac92993e130c7d9b6122ee1877d7d52ea26500689b038ed38296f02db820.
The report says both match iteration 1. Independently hashed the supplied CLI
tarball and read its CLI member without extracting files: the hash matches and
its link.initial entry lacks minSince: 9. Current packages includes that cutoff.
This confirms an older supplied artifact, not a fresh failure of current
packages' already-merged R30 correction.
Do not rewrite a shipped schema or baseline to accommodate that older tooling.
F-28 describes a recovered migration collision, not established data loss or deadlock.

## Fresh gates

Validation is against the packages bases above; subsequent commits change only
this report. Logs use the prefix `%TEMP%/valence-20261030-`.
| Gate | Result |
| --- | --- |
| Root npm test | 101 passed, zero failures/skips; generated Dart and strict/verbatim generated TS included |
| Core flutter test --no-pub --concurrency=2 | 542 passed |
| Core dart analyze --fatal-infos . | No issues |
| Core flutter pub publish --dry-run | Zero warnings |
| Push adapter tests / fatal-info analysis | 2 passed / no issues |
| Push adapter pub publish --dry-run | Zero warnings; one documented local-override hint |
| Bridge tests | 29 passed, zero failures/skips |
| Bridge strict/verbatim TypeScript / pack dry run | Passed / passed |
| Example flutter test --no-pub | 27 passed |
| Example codegen --check / signed built-in verification | written: [] / seq 1793209750 verified |
| Site build and SEO | 43 pages passed |
| Example flutter build apk --debug | Passed; 178.3 seconds command wall time (174.7 seconds Gradle) |
| py example/tool/check_no_firebase.py | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |
| Root npm pack --dry-run | Passed |
| Both repository diff checks | Passed |

The APK build used a 2 GiB Gradle heap, two workers and ActiveProcessorCount=2
only in its command environment. Its existing app_badge_plus Kotlin-plugin
migration warning remains. The Firebase audit ran through py on Windows and
printed PASS; the APK build alone is not counted as that audit.
All gates passed on their first completed run. No assertion or timeout was changed.
No new independent runtime review is claimed for this report-only change.

No emulator was acquired or operated in this run. App evidence was read only.
Positive biometrics, Firebase delivery and exact natural background timing remain
outside these checks; iOS remains experimental and untested. No package-version
change, test-app write, push or publication.

---

# Integration validation - 2026-10-29

## Iteration-17 acceptance update - 2026-10-29

Read both apps' VALENCE_FINDINGS.md and newest reports read-only: Kundalini 14
and app-a 17. All R1-R29 must-haves remain done. Rechecked all 23 feature tips
against packages in both repositories; every tip is included. Both integration
branches contain newest packages code `472bd2f13f71702cd4abb59ede590783ecd8104c`
and site `bb8d82fc509825f34d45cfd5ca06d72c7237030b`. Only this report differs
from packages in either tree; no feature merge or rebase remains.

App-a adds these bounded observations:

- During ordinary navigation, `store.get` id 36 waited at 10005ms and completed
  at 11262ms. Later `store.count` ids 39/40 waited at 10002ms, accompanied by
  sqflite's ten-second lock warning, and completed at 16336/16338ms. These are
  named operation boundaries, not a lock-holder trace or a cause for F-33/F-35.
  A native release build was running on the host; no causal link is established.
- The first Recents swipe did not establish task removal and its observer
  included old ready logs. A separate settled inspection after the second swipe
  no longer lists task 510. Explicit launch created task 511 / PID 6388, served
  normal OTA 1793277011 offline, loaded `/` and called ready. This agrees with
  the documented fresh-task reset. Retained-task recreation remains separate
  iteration-16 evidence; natural memory-pressure eviction, forced socket reclaim
  and `state.save` blobs remain untested.
- Healthy OTA 1793276873 committed. Missing-ready 1793276933 failed twice and
  was explicitly refused as bad. Final normal 1793277011 committed at unchanged
  floor 1792247440; its file comparison matches builtin 1793233551. After a
  retained-data reinstall, PID 6608 served it offline and called ready; the
  observer records 15.05 seconds to its page-finished/ready signal. This does not
  establish a startup fix or a latency guarantee.
- Foreground reconnect logged both sync and update connectivity triggers. The
  pointer equalled current and was declined; full sync reported `ok`, pending 0.
  The report records 15 plants / 36 records, retained identity and receipt,
  offline search/diagnosis/detail and a dismissed native text chooser. Its
  4972ms diagnosis sample remains latency evidence, not a performance promise.
- Wizard/bridge archive hashes match iteration 16. Native snapshot resolution
  was not source-fingerprinted. F-29/F-36 retain iteration-15 resolution rather
  than new coverage. The app reports 10 web, 15 native and 7 diagnostic tests,
  clean codegen/analysis/build, doctors without FAILs and a 343.3s release APK.
  Those checks were not rerun here. The app review retains its pre-open and
  fake-orchestration coverage limits; it is not a runtime security review.

Spot-checked the wait logs, task inspections, new-task/offline startup logs,
both failed trials, bad refusal, final commitment/file comparison, reconnect,
snapshot hashes and independent app review. Evidence is in read-only app-a:
ITERATION_17_REPORT.md, .valence/review-iteration17.md and
.shots/iteration17-{navigation-wait.log,recents-before.log,
recents-task-after-settled.txt,recents-task-new.txt,recents-new-task.log,
reinstalled-offline-1.log,reinstalled-offline-results.json,rollback-1.log,
rollback-2.log,rollback-3.log,final-commit-1.log,final-artifact.json,
reconnect.log,snapshot-hashes.txt}. Visible UI/count claims remain app-reported;
no new emulator session or screenshot review was performed here.

Kundalini's newest report remains iteration 14: its installed host is schema 11,
schema-16 adoption exists in source/tests only, seven inexact alarms are armed
and reminder delivery remains unobserved. Its schema-16 OTA is withheld. F-62's
tooling warning still needs adopter confirmation.

Decision: preserve the frozen candidate, users' data and signatures. The new
get/count evidence complements iteration 16's slow open, but still identifies
no holder or corrective change. Do not change database opening, retry budgets
or connection ownership on this evidence. Keep F-33/F-35 open and retain S1's
deferral, S2's Play-account blocker and the Playground's post-beta scope.

Fresh validation covers ancestry, matching reports, unchanged implementation
trees and diff hygiene. Full gates below retain their original run and scope;
this report-only update is not a fresh gate, device or runtime-review pass.
No test-app writes, shared-branch changes, schema/package-version changes,
pushes or publications occurred. iOS remains experimental and untested.

## Iteration-16 acceptance update - 2026-10-29

Read both apps' VALENCE_FINDINGS.md and their newest iteration reports read-only:
Kundalini 14 and app-a 16. No eligible must-have remains: R1-R29 are done.
Packages is still code `472bd2f13f71702cd4abb59ede590783ecd8104c` / site
`bb8d82fc509825f34d45cfd5ca06d72c7237030b`. Rechecked all 23 feature
tips against packages in both repositories; every tip is included and both
integration branches contain the latest packages base. Only this report differs
from packages in either implementation tree.

App-a iteration 16 adds evidence beyond the iteration-15 closeout below:

- On the first offline start after a retained-data reinstall, PID 6320 logged
  `store.open` waits at 10002ms and 20003ms, completion at 29274ms, and startup
  completion at 29492ms. Seed processing followed the store wait and skipped
  import because its completion marker matched. The app reports readiness at
  36.15s. This identifies the pending operation; it does not establish a SQLite
  lock, its holder, an ANR cause or a fix for F-33/F-35.
- An injected offline background kill replaced PID 7047 with PID 7240.
  Android exit-info identifies the former as USER REQUESTED / KILL BACKGROUND,
  with retained task state. The new PID served normal OTA 1793255712 at the same
  loopback port 24326, started and finished `/#/shelf`, and called ready. The app
  reports 15 visible plants and retained 36 records, identity and receipt.
  This is retained-task recreation after `am kill`; natural memory-pressure
  eviction, forced socket reclamation and `state.save` drafts remain untested.
  The observer attached late: its 0.43s is not a startup measurement.
- Missing-ready OTA 1793255686 fell back twice, was marked bad and was explicitly
  refused on a further launch. Final normal OTA 1793255712 committed on the
  rebuilt installation with floor 1792247440, then served offline after force-stop.
  The final artifact comparison reports the same files as the normal builtin.
  The force-stop path starts at root, separately from retained-task restoration.
- Wizard and bridge archive hashes match iteration 15. The app resolved the
  prescribed Flutter path without fingerprinting its source, so archive equality
  does not establish native runtime source identity. F-29/F-36 retain their
  earlier snapshot-specific resolution boundaries.
- The app reports 10 web, 15 native and 7 diagnostic tests, generated-code check,
  clean fatal-info analysis, doctors without FAILs and a 431.3s release build.
  These were not rerun here. Its independent app review records that fake
  orchestration tests do not prove dispatcher/nonce denials, and app-owned
  pre-open credential inspection is outside runtime wait instrumentation.

Spot-checked the live wait capture, reinstall log, process exit-info, restored
route log, snapshot hashes, independent app review, both failed-trial logs, bad
refusal, final commit/offline logs and artifact comparison. Evidence lives in
the read-only app-a repo: ITERATION_16_REPORT.md, .valence/review-iteration16.md
and .shots/iteration16-{reinstall-live.log,reinstalled-offline-1.log,
reclaim-exit.txt,reclaim.log,snapshot-hashes.txt,rollback-1.log,rollback-2.log,
rollback-3.log,final-commit-1.log,final-force-stop-1.log,final-artifact.json}.
The shelf counts and visible product behavior above remain app-reported; no
new emulator session or screenshot review was performed here.

Kundalini's latest evidence is unchanged: schema-16 source/tests exist, but its
installed host remains schema 11. Seven inexact OS alarms are armed; delivery
has not been observed, and the schema-16 OTA remains withheld. Its F-62 tooling
warning still needs adopter confirmation.

Decision: preserve the frozen candidate and users' data. The new trace narrows
the slow operation without identifying a corrective change; altering database
opening, retry budgets or connection ownership on that evidence would risk data
for an unproven fix. Keep F-33/F-35 open. The next useful diagnosis must identify
what delayed the open, while preserving the database and account. Do not reopen
S1 or the post-beta Playground; S2 still needs a Play account.

This update changes reports only. Fresh validation is ancestry, report agreement,
unchanged implementation trees and diff hygiene. The complete gate results in
the refresh below remain evidence from their original run, not a new pass.
No runtime/security-path review, full gates, emulator run, test-app writes,
shared-branch changes, package-version changes, pushes or publications occurred.

## Adoption closeout - 2026-10-29

All must-have items R1-R29 remain done. Both packages heads are unchanged:
code `472bd2f13f71702cd4abb59ede590783ecd8104c`, site
`bb8d82fc509825f34d45cfd5ca06d72c7237030b`. All 23 feature tips listed
in the refresh below are ancestors of packages in both repositories. Integration
differs from those bases only in this report; there is no outstanding feature
merge or rebase. The prior gate results below retain their original run and scope.

Read both apps' VALENCE_FINDINGS.md and newest reports read-only: Kundalini
iteration 14 and app-a iteration 15. App-a's new report supersedes the earlier
iteration-14 adoption limits recorded below:

- F-36 is resolved for the supplied snapshot pair: unmodified codegen accepts
  nullable SyncStatus.reason, and the app displays the last attempted scope
  separately from authenticated shelf receipts and full-sync freshness.
- F-29 is resolved for that snapshot. Its captured anonymous pull returned HTTP
  401, sync.now and sync.status both reported `failed`, auth.expired stayed
  zero, and same-account token repair retained 36 rows before authenticated
  recovery. This does not test account switching or queued-write recovery.
- Native release 1.8.3+13 installed over retained data. Offline upgrade preserved
  15 plants, 36 shelf records, identity and receipt. The 618.73-second offline
  background/resume observation kept PID 5674; it does not prove survival after
  OS process reclamation or forced socket reclaim.
- Foreground reconnect discovered the healthy update. Missing-ready seq
  1793234392 failed twice and was explicitly refused as bad. Final normal OTA
  1793234393 committed with floor 1792247440 and served again offline.
- Firebase disappeared from the app's resolved dependencies. This is adopter
  graph evidence; the separate all-DEX/manifest audit below covers the example
  APK, not app-a's release APK.
- Startup phase diagnostics are visible. F-33 database waits and F-35 ANRs still
  have no established root cause. The app's commit-suffix probe false negative
  was regression-fixed; its original 90.01-second timeout remains a failure.

App-a's report records 10 web, 15 native and 7 diagnostic tests, clean fatal-info
analysis, both doctors without FAILs, and a 335.7-second release build. These are
app-reported results, not tests rerun here. Spot-checked its captured codegen
warnings, snapshot hashes, anonymous-401 log, same-PID suspension JSON, final
commit/offline logs and two-strike/bad-refusal logs against the report.

Evidence is in the read-only app-a repo: ITERATION_15_REPORT.md and
.shots/iteration15-{snapshot-hashes.txt,reason-codegen.txt,anonymous.log,
suspension-result.json,rollback-3.log,rollback-4.log,final-2.log,
final-offline-1.log}. The supplied archives are identified by SHA-256:
wizard `43DE7C06988A9E30516F848F960C056A86FEC456BD5438C1C91AE3FC9C63102F`;
bridge `0D77AC92993E130C7D9B6122EE1877D7D52EA26500689B038ED38296F02DB820`.
Version labels alone do not establish snapshot identity.

Kundalini iteration 14 remains the latest report: schema-16 source adoption and
tests passed, but no schema-16 APK installed. Its seven armed alarms are observed
on the schema-11 host; reminder delivery remains unobserved, and the schema-16 OTA
was withheld. F-62's stale-tooling diagnostic still needs adoption confirmation
there. Current source already warns about unknown methods in built-in namespaces
and names `npx create-valence update`; app-a's captured codegen output exercises
that warning without rejecting its historical custom handlers. This does not
close Kundalini's finding on its behalf.

Decision: preserve the frozen candidate, users' data and shipped signatures.
There is no eligible must-have item to claim, no demonstrated new runtime defect
to patch, and the latest app evidence does not justify reopening S1 or starting
the post-beta Playground. S2 retains its Play-account blocker. Kundalini's native
adoption, reminder delivery, broader device acceptance, Firebase delivery and
iOS validation remain open; iOS is experimental and untested.

Only this report changes in each worktree. Fresh checks are branch ancestry,
unchanged implementation trees and diff hygiene. No full gates, emulator session
or independent runtime review reran for this report-only update. No test-app
writes, shared-branch changes, version changes, pushes or publications occurred.

## Current packages refresh - 2026-10-29

No must-have item is todo, in progress or awaiting changes. Refreshed
`codex/integration` in both worktrees by fast-forwarding to packages code
`472bd2f13f71702cd4abb59ede590783ecd8104c` and site
`bb8d82fc509825f34d45cfd5ca06d72c7237030b`. Both worktrees were clean before
the refresh. All 23 feature tips are ancestors of packages in both repositories:
the original queue R8, R7, R6, R3, R4, R5, R9, R10, R14, followed by
R15, R16, R17, R19, R20, R21, R22, R23, R24, R25, R26, R27, R28 and R29.
No additional feature merge or conflict resolution was necessary. The earlier
R27/R28/R29 merge order and full source SHAs remain recorded below; the older
queue was already included in their packages base.

The initial refresh reached code `52946e5`; packages then advanced to `d4424de`
while gates ran. That commit changes only the Windows Python audit instructions
in AGENTS.md. Integration fast-forwarded again and repeated the earlier gates.
During closeout, packages advanced to code `472bd2f` / site `bb8d82f` with S3's
plugin-directory documentation. Integration fast-forwarded once more and reran
the complete gate set on those final heads. Earlier successful runs remain
separate evidence below, not substitutes for that final verification.

The refresh includes upstream tooling-age warnings, structured-return matching
for custom notification handlers, required push-envelope metadata, labels for
sync-owned database contention, restored Gradle wiring and plugin distribution
documentation. The new directory distinguishes plugins from add-ons, requires
fragment paths already on disk and makes no claim that a listing is a review.
Schema/builtins 16,
reserved delegation floors and package versions are unchanged.

Decision: retain those upstream fixes and preserve data, shipped custom handlers,
wire signatures, leases, retry budgets and activation checks. A tooling warning
must not reject an existing app-owned method merely because its namespace also
contains built-ins. Explicit push-envelope metadata preserves the data-only sync
boundary. No speculative runtime change is justified by the app stall reports.

Both apps' VALENCE_FINDINGS.md and newest reports (iteration 14) were read
read-only. Kundalini's report is now complete: its installed schema-11 host has
seven OS alarms armed through the package receiver, with inexact timing, but a
reminder firing was not observed. The schema-16 adoption passes app tests but
neither release nor debug APK completed, so its new signed OTA was deliberately
withheld. Its swallowed reminder-read error was an app defect and is reported
fixed there. App-a likewise has no fresh native build or valid boot baseline in
iteration 14; its last proven installed OTA and retained shelf remain iteration
13 evidence. Neither report establishes a cause for the historical lock/ANR
observations. F-62/F-36 still require matched-snapshot adoption; current framework
tests alone cannot close either app's findings.

All gates passed on the final implementation, separately from the older evidence
below. The confirmation after the packages movement passed without changing any
assertion, timeout or source file:

| Gate | Result |
| --- | --- |
| Root npm test | 99 passed, zero skips; generated Dart analyzed/exercised and strict/verbatim generated TypeScript included; 50.8 seconds reported by Node |
| Core flutter test --no-pub --concurrency=1 | 542 passed; 113.7 seconds command wall time |
| Core dart analyze --fatal-infos . | No issues |
| Push-adapter tests / fatal-info analysis | 2 passed / no issues |
| Example flutter test --no-pub | 27 passed |
| Core / adapter pub publish --dry-run | Both zero warnings; adapter retains one documented local-override hint |
| Bridge tests | 29 passed, zero skips |
| Bridge strict/verbatim TypeScript / pack dry run | Passed / passed |
| Site build and SEO | 43 pages passed, including the new plugin directory |
| Example codegen / signed built-in verification | No stale files / seq 1793209750 verified, 2 files |
| Example debug APK | Passed; 135.1 seconds command wall time, 129.6 seconds reported by Gradle |
| Core graph / APK Firebase audit | Explicit PASS: no Firebase dependency, manifest component or SDK reference in all 19 DEX files |
| Both repo diff checks | Passed |

The initial root run also passed 99 tests with zero skips (454.5 seconds reported
by Node), and the initial native run passed 542 core, 2 adapter and 27 example
tests with clean analyzers. The d4424de confirmation passed 99 root tests with
zero skips (133.6 seconds reported by Node), 542 core tests, 2 adapter tests,
27 example tests and both analyzers. The earlier 42-page site build and 436.3-second
APK build/audit also passed. Those are separate successful runs, not substitutes
for the final-head verification in the table. Its logs and per-command exit
codes/timings are `%TEMP%/valence-integration-20261029-latest-*.log` and
`valence-integration-20261029-latest-results.json`. Earlier evidence remains under
the separate `valence-integration-20261029-current-*` and `-final-*` prefixes.

Native commands ran sequentially. The APK used only command-local Gradle settings:
2 GiB heap, 1 GiB metaspace, two workers and ActiveProcessorCount=2; the daemon
command line confirmed those limits. The existing app_badge_plus KGP migration
warning remains. The audit ran through the real Python 3.13 interpreter located
by `uv python find 3.13`, avoiding Windows Store aliases, and its exit code and
explicit PASS output were captured directly. No cancellation or failed gate
occurred in this refresh. A host-memory sample during the first root run showed
183,984 KiB free of 32,827,764 KiB; this is context, not a proven cause of delay.

Security checklist: the upstream delta preserves canonical OTA verification,
nonce/strict decoding, navigation and subframe locks, atomic state writes and
account/outbox isolation. Required push-envelope metadata keeps notification
messages outside the data-only sync-hint path. Database diagnostics retain fixed
operation labels without SQL, arguments or app data, and preserve transactions,
errors and retry budgets. Release-only development exclusion is unchanged; its
earlier AOT evidence retains its original date and scope. No new independent
review or emulator session is claimed. iOS remains experimental and untested;
Firebase delivery and test-app release acceptance remain open.

Only this integration report is changed in each worktree. No test-app writes,
shared-branch commits/merges, version changes, pushes or publications occurred.

## Adoption follow-up - 2026-10-29

Both apps' findings and newest iteration reports were read without writing to
either app: initially Kundalini iteration 13 and app-a iteration 14, then the new
Kundalini iteration-14 report created during this run. Its day-14 finding F-62
records that the vendored CLI did not recognize `notify.pendingIds`, generated
an abstract app-owned handler at the correct
`since: 16`, and gave no tooling-refresh diagnostic. The app reports that
`create-valence update` restored delegation. This is separate from F-57's
below-reservation declaration and does not demonstrate failure of the current
integrated generator. App-a F-36 still records supplied snapshot tooling rejecting
the live docs' nullable `SyncStatus.reason` addition. Matched artifact adoption
remains necessary; neither finding is closed by framework tests.

Kundalini iteration 14 adopts the guarded ID-only read with the older full-read
fallback and records a Gradle-daemon disappearance followed by a smaller heap
configuration. At read time its device and verification sections contained placeholders;
no completed iteration-14 build or device matrix is inferred from that draft.

No must-have row is `todo`, `codex: in progress` or `codex: changes requested`.
The code/site packages bases remain `41fed55` / `7bfe7bd`; every original queue
tip and R27/R28/R29 tip is an ancestor of the corresponding integration head.
Decision: retain this candidate, preserve data and shipped signatures, and record
the new adoption evidence. Keep this run scoped to integration validation while
there is no eligible must-have item. No branch reassembly is needed while both
bases and all ready tips remain unchanged.
A blanket rejection of unknown names under a built-in namespace would also reject
valid shipped custom methods such as Kundalini's `notify.daily`; any future
diagnostic must preserve that compatibility distinction.

Fresh verification on code `81c452a` / site `b55d0bf`:

| Gate | Result |
| --- | --- |
| Root npm test | 97 passed, zero skipped; generated Dart and strict/verbatim generated TS included; 380.1 seconds reported by Node |
| Core flutter test --no-pub --concurrency=1 | 541 passed; 1331.7 seconds command wall time |
| Core dart analyze --fatal-infos . | No issues; 214.9 seconds |
| Adapter tests / fatal-info analysis | 2 passed / no issues |
| Core / adapter pub publish --dry-run | Both zero warnings; adapter retains the documented local-override hint |
| Example flutter test --no-pub | 27 passed |
| Bridge tests / strict-verbatim TS / pack dry run | 29 passed, zero skipped / passed / passed |
| Site build and SEO | 42 pages passed |
| Example codegen / signed built-in verification | No stale files / seq 1793209750 verified |
| Example debug APK | Passed; 1458.2 seconds command wall time (Gradle reported 1450.6 seconds) |
| Core graph / APK Firebase audit | Passed: no Firebase package, manifest component or SDK reference in all 19 DEX files |

Test suites, analyzers, packaging and site gates passed on their first attempts,
with unchanged assertions and timeouts. Native commands ran serially after root tests. Logs are
`%TEMP%/valence-integration-20261029-refresh-*.log`; native command exit codes and
wall times are in `valence-integration-20261029-refresh-results.json`.
APK timing and its successful exit are in `valence-integration-20261029-refresh-apk-result.json`.

The APK used a command-local 2 GiB Gradle heap, 1 GiB metaspace, two workers and
ActiveProcessorCount=2 with a single-use daemon; no shared Gradle configuration
changed. The existing app_badge_plus KGP warning remains. A planned bounded
cancellation found the verified client had already exited: the original build
completed successfully, no process was stopped, and no smaller-heap retry ran.
The first post-build audit launcher exited 9009 because `python` resolved to the
Windows Store alias. The unchanged audit then passed through the installed
Python 3.13 interpreter located by `uv python find`; no Python installation or
source patch was needed. A thread snapshot was captured near daemon shutdown;
it does not establish a cause for the long build.

The first host-memory sample during generated-Dart analysis showed 261,216 KiB
free of 32,827,764 KiB; this is context, not a demonstrated cause of delay.
No new emulator run or independent review is claimed. Earlier release-AOT/device
evidence below retains its original scope and date.

## In plain terms

Firebase is now an optional native dependency through `valence_push`; hosts using
core alone keep local notifications and badges without Firebase. R28 retains
complete notification content while giving reconciliation a bounded ID read.
R29 names startup phases and pending database operations without changing retries,
transactions, leases or activation. The combined bridge/builtins revision stays
16, including the reserved `notify.pendingIds` delegation floor. No package
version or manifest format changed.

Decision: keep the security policy and lifecycle in core, extract only the
Firebase transport, and preserve users' data and shipped wire signatures. Moving
local notifications and badges too would enlarge the migration without being
needed for R27. Push adopters add the optional package, import its factory and
replace `ValencePush()` with `createFirebasePush()` after Firebase initialization.
The core example intentionally omits Firebase, including Google services setup.
The guide now tells push hosts to add that native setup themselves.

## Bases and merge order

Started fresh from code packages `41fed55615cbece1595766ccb83a31e47c1a0be5` and
site packages `7bfe7bd0a26ef734396537f2279685c329e47ff4`. Both worktrees are on
`codex/integration`. Original queue R8, R7, R6, R3, R4, R5, R9, R10, R14 was
checked in that order: every tip is already an ancestor of packages in both
repos. All later rows except R27/R28/R29 are marked done; those three ready,
unmerged branches were folded in numeric order:

| Item | Code feature tip | Code merge | Site feature tip | Site merge |
| --- | --- | --- | --- | --- |
| R27 | `8296d4e68753185c132c39da3c94369989818f27` | `3c72a8eae96e6e4a34315e262021ab857fc8c0ad` | `c4a8fad9bc2dc04f9b8033080608e1250785e08e` | `68a17e6d26d554420d8d4835ffbac4a9b8f04b3b` |
| R28 | `8d42a82d96ad124c3cbe122280b64a00f43371bb` | `c471abc7132550dd8e38e22bc1730daa71dd452f` | `0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65` | `b3d2da02b2959194c414165c9ceb3cf2483927ab` |
| R29 | `6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f` | `f59c202799da6a43ae94941f97ca7ca0dc40734c` | `d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555` | `7a6d32122aac3354495f2b423222e2e7a72c878b` |

Code changelogs conflicted at R29; site README conflicted at R28. Both sides'
entries were retained. Runtime code merged without conflict. No invented runtime
behavior or schema renumbering was used to resolve the merges. The earlier
integration candidate passed 97 root tests before the final setup-sentence
correction; a fresh assembly includes that correction on R27 and reruns every
gate. Earlier integration is retained at
`codex/integration-before-r27-20261029`; the pre-correction assembly is at
`codex/integration-r27-before-doc-fix-20261029`.

## Gates on the final combined implementation

Validated implementation heads: code `f59c202799da6a43ae94941f97ca7ca0dc40734c`,
site `7a6d32122aac3354495f2b423222e2e7a72c878b`. Only this report is committed
subsequently; runtime, generated code, signed assets and site content stay as tested.

| Gate | Result |
| --- | --- |
| Root npm test | 97 passed, zero skipped; generated Dart analyzed/exercised and generated strict TS included |
| Core flutter test --no-pub --concurrency=1 | 541 passed |
| Core dart analyze --fatal-infos . | No issues |
| Firebase adapter flutter test --no-pub | 2 passed |
| Adapter dart analyze --fatal-infos . | No issues |
| Example flutter test --no-pub | 27 passed |
| Core flutter pub publish --dry-run | 0 warnings |
| Adapter flutter pub publish --dry-run | 0 warnings, 1 documented local dependency-override hint; override excluded from upload |
| Bridge tests | 29 passed, zero skipped |
| Bridge strict/verbatim TypeScript / pack dry run | Passed / passed |
| Site build and SEO | 42 pages passed |
| Example debug APK | Passed, 68.4 seconds command wall time |
| Core graph / APK Firebase audit | Passed: no Firebase dependency, manifest component or SDK class reference in all 19 DEX files |
| Example codegen / signed built-in | No stale files / seq 1793209750 verified |
| Both repo diff checks | Passed |

Flutter gates ran sequentially after the root suite. Only the APK command used a
2 GiB Gradle heap, two workers and ActiveProcessorCount=2, without global Gradle
configuration changes. Its existing app_badge_plus KGP migration warning remains.
Adapter publication uses the development override for unpublished core; publish
core first and repeat resolution against that release before publishing the adapter.

Logs: `%TEMP%/valence-integration-r27-*.log`; command exit codes and timings are in
`valence-integration-r27-results.json`. The earlier pre-documentation-correction
97-test root pass is retained separately in `valence-integration-r27-root-before-doc-fix.log`.

The distinct initial R27 root failure (duplicate version-test declaration), its
correction and complete passing rerun are recorded in [R27 validation](r27-validation.md).
The audit first rejected the inherited Firebase-containing APK, then passed both
rebuilt candidates. Earlier separate attempts for [R28](r28-validation.md) and
[R29](r29-validation.md) remain recorded there; none is counted as a current pass.
No assertion or timeout was weakened. All current gates passed on their first
attempt after the final assembly. Beta acceptance remains open.

## Review and acceptance limits

The package checklist covers nonce/strict decoding, message caps and JSON escaping,
HTTPS-only image metadata, exact data-only sync hints including empty-notification
denial, passive startup and permission/APNs-gated registration, tap races and
subscription disposal. Runtime sync tests preserve the native token, lease, UI
store and activation state. R29's fixed labels omit SQL, paths, tokens and app
data, preserve transaction executors/original errors, and cancel observation
timers. Canonical OTA verification order, navigation lock, atomic state and
account/outbox boundaries remain unchanged. Independent improver review is still
required before merging into packages.

Read-only inputs: both apps' VALENCE_FINDINGS.md and newest reports, Kundalini 13
and app-a 14. Kundalini completed report 13 during this run: it now records startup
recovery after keep.xml and a queue readback, with 114 web tests and 35 native tests
rerun at iteration-14 startup. F-58 still records Firebase in its supplied binary.
Reminder firing, OTA, rollback and fresh install are explicitly unverified in that
iteration. This newer evidence supersedes the placeholder limitation recorded in
the earlier R27 validation note; no full device matrix is inferred.

App-a's last native build remains cancelled without a completed APK, its F-36
snapshot/docs mismatch still needs matched snapshots, and F-33/F-35 causes and
adoption acceptance remain open. R27 removes the framework dependency cause; it
does not close F-34's local-notification/desugaring cost or prove either app has
adopted this candidate. No new emulator session, app-data reset or test-app write
occurred. Android build/unit evidence is separate from delivery/device acceptance;
iOS remains experimental and untested. Firebase delivery still needs a maintainer
project. No shared-branch commit/merge, push, publication or package-version bump.
