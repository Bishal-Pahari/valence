# Integration review correction - 2026-11-06

## November 8: queued lease regression and refreshed integration

In plain terms: K F-83 was reproducible against the previous candidate: a queued
lease read compared a sibling renewal with a pre-wait clock and took a live lease.
The transaction-queue regression failed with written -11000ms ago and a second
successful acquisition. Current packages moved during validation and independently
corrected F-83 plus cleanup, startup-routing diagnostics and F-84 wording. Merged
those changes, preserved their bounded same-process future-row policy, and kept
one clock sample after the lease query, with two additional queue regressions.
Security checklist review found no correctness/security blocker. Clarified the
exact TTL boundary in the spec and guides without changing the predicate.

Assembly order on both codex/integration branches:

1. Newest packages: code 74ea9bf88f34aabb23361501578a3869fd8bb1a6;
   site b877d979d4d3fa70972eec71576bfef0e67f0be7.
2. codex/lease-clock-read: code cdecefbfe6bb18481fcdc19d08ff0c6b2e6c02b7;
   site f311337cee94f56db94c5adc2456ffd9c3be8b6f.

Both steps fast-forwarded. The original 39 exact tips below were independently
checked as ancestors in both trees and are already in packages; their historical
order and schema numbers remain intact. The new follow-up is source 40. Conflicts
had been resolved on the item branch: retained upstream spec/policy and public
README links, retained the queued-read requirement and tests, and removed the
automatically duplicated pre-query clock sample. No package/schema version change.

Fresh gates after the packages merge passed November 8: root 121, zero skips,
generated Dart executed; core 664 serially, clean fatal-info analysis and pub dry
run zero warnings; push 2, clean analysis, pub dry run zero warnings/one local
override hint; bridge 37 plus strict TS and pack dry run; example codegen check
(no writes), 29 tests, debug APK (Gradle 198.7s), standalone Windows py Firebase
PASS over 19 DEX files/manifest/core graph; site 50 pages with SEO/link checks.
The combined runtime and tests were gated before fast-forward assembly; assembly
retained those exact sources. Only validation/integration notes followed.
Nonfatal app_badge_plus KGP build warning remains. Initial uncommitted-README pub
warning was corrected by committing it and rerunning; the final dry run counts.

Reviewed both findings inventories and newest reports, Kundalini 23 / App C 144.
Kundalini reports F-81 fixed and cold link/reminder restoration correct; F-83
requires a native rebuild and device recheck. Clean-install offline and haptics
acceptance remain qualified. Independently counted its doctor 21 PASS/6 WARN.
App C remains acceptance-incomplete: checked 22 report links, both APK hashes and
five embedded files per manifest (builtin1794082626); doctor16PASS/10WARN/1FAIL
is a key-scan timeout without assertions. Its R29 open completion is not paint;
nonstreamed install success does not erase readiness failures. No new framework
startup cause, native/offline/OTA/worker or retention acceptance established.
Its iteration143 release archive was overwritten before the runner corrected the
iteration144 destination, so the older receipt does not preserve that older binary.

Decision: security and users' data first; retain upstream recovery and cleanup,
add deterministic queue coverage and preserve incomplete evidence. S1 stays parked,
S2 needs Play, S10/P1 stay deferred. Only S9's follow-up Status cell changes.
No fresh emulator or iOS acceptance. Test-app repos remained read-only; no protected
branch writes, version changes, pushes or releases. Full commands, outcomes and
scope: [queued lease validation](lease-clock-read.md).


## November 7-8: iteration 143 incomplete startup regression

In plain terms: every must-have and original queue item remains done. No eligible
queue refresh or new item remains. Packages bases are unchanged: code d037f23,
site d14ece8. Independently verified all 39 recorded exact tips and each packages
base as ancestors of the corresponding integration. Reviewed both findings
inventories and newest reports: Kundalini 22 / App C 143. Kundalini still lacks
complete release acceptance and dedicated post-fix F-81/F-82/cold-tap acceptance.
App C began November 7 and ended November 8; its current regression is incomplete.

Independently checked all 22 report evidence links. Counted the mechanical doctor
stream: 14 PASS, 11 WARN, 2 FAIL. The signing-key scan timed out at 187484ms and
Flutter dependency child at 191265ms; neither ran an assertion. The dependency
check overlapped an APK build, a runner limitation, not an isolated package defect.
Independent successful checks do not erase those failed checks or explain F-54.
The twelve-test Flutter result is a manual console-outcome receipt, explicitly
without a saved standalone raw console; preserve that weaker evidence boundary.

Independently rehashed archived release and debug APKs and extracted both embedded
manifests: seq1794075529, five files each. Release SHA256
6832f30b95311840ffb2cd3082a43010c65efe8415ee062b2a489ceacf916e57;
debug SHA256
12b7f14914af884632a4cf5d1058d77fa3c33cfe750645c18fa830c76a04eb57.
Saved signature verification was reviewed, not rerun. The interrupted R27 phase
supplies no current binary Firebase exclusion pass.

Startup capture names were reused: continuation captures cannot diagnose the
initial absent PID/CDP failures. Harness recovery timed out; direct recovery
records boot=1, then readiness status1 and adb screencap ETIMEDOUT. Crucially,
postdirect-initial-exit-info.txt is empty: its existence supplies no exit cause or
PID proof. No current meaningful paint, native/offline/OTA/isolated-worker or
retention acceptance follows. No crash, leak or Valence root cause is established.
Saved cleanup records airplane0/App C absent; the first mock-stop timeout remains
separate from corrected identity-scoped stop and bindable-port receipts. No current
outbox-zero, queue-empty or activation-byte comparison is supplied.

Decision: security first, then users' data. Keep the frozen runtime, rollback
checks, transaction ownership and lease policy intact; preserve failures and
missing evidence instead of treating APK completion as device acceptance. S1
stays parked, S2 needs Play, S10/P1 stay deferred. Item Status cells are unchanged.
Only mirrored integration evidence notes and the roadmap top note change. Earlier
November 7 full gates retain their implementation scope; no fresh full gates,
emulator session or iOS acceptance in this evidence-only review. Verified ancestry,
report links, APK hashes/manifests, doctor counts, mirrored text and whitespace.
Both test-app repositories stayed read-only; no versions, protected branches,
pushes or releases changed.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_22_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_143_REPORT.md}; App C
evidence/iteration-143/{doctor-mechanical.txt,doctor-current-summary.json,
archived-release.json,archived-debug.json,embedded-both-manifests.json,
verify-builtin.txt,flutter-console-outcome.json,runner-notes.md,
postdirect-initial-boot.txt,postdirect-initial-wait-execution.json,
postdirect-initial-screenshot-execution.json,postdirect-initial-exit-info.txt,
scoped-cleanup.json,mock-stop-corrected.json,final-mock-ports.json,
final-forward-inventory.json}.

## November 7: iteration 142 qualified regression evidence

In plain terms: every must-have and original queue item is marked done; no
eligible feature or queue refresh remains. Packages bases remain code
d037f233f8ffbdd0a72d22a42715974deb50287c and site
d14ece8ea97e17f9b753b31e52d15843db40abdd. Independently checked all 39 recorded
exact code/site tips and both packages bases as ancestors of the integrations.
Reviewed both findings inventories and newest reports: Kundalini 22 / App C 142.
Kundalini's release acceptance remains incomplete; dedicated post-fix acceptance
of F-81/F-82 and cold notification routing is not supplied by that report.

App C's saved audit has 93 passing receipt-consistency checks, acceptance=false.
Independently checked all 36 evidence links in its report and counted doctor's
17 PASS, 10 WARN and zero FAIL. That successful invocation does not explain or
erase iteration 141's mapped-test failure or key-scan timeouts; F-54 stays open.
The report preserves Pixel Launcher/System UI startup ANRs, failed initial CDP
discovery, incorrect resized-image taps and later UI-label recovery separately.
Raw startup logcat corroborates both external packages' ANRs.

Independently matched five renderer-loss lines against full raw logcat and
correlated exit-info: renderer6516 LOW_MEMORY at 22:54:04, followed by Chromium's
unhandled-loss termination of host6110, SIGNALED/status9. Initial Settings
continuity failed (6110 to 7550, no painted page); recovered same-PID7550 paint
is a separate successful attempt. This is the Android limitation already stated
in contracts section 3, not evidence of a package memory leak or a new cause.
Initial unequal passive snapshots and later stable capture remain separate;
neither establishes database corruption.

Independently rehashed both archived APKs and extracted their embedded manifests:
builtin seq1794070804, five files each. Release SHA256
5d9e929d4ef110fd58e49536dbcfdd5c47af17f746d3f7eb17ba9ad8a456f407;
debug SHA256
688b20169676c1307849859d0412a37133b7d9514cc2d966d7557fdf21fd3eb9.
Saved CLI signature verification and native/offline/notification/link/widget/
two-strike rollback receipts were reviewed, not rerun in this worktree.

The worker baseline records two queued objects and no inbound fixture; its
stable before-resume SQLite receipt records bidirectional effects and outbox0.
Independently matched seven raw PID10658 callback, lease and WorkManager SUCCESS
lines. Compared exact before/after activation bytes: SHA256
d99b7db0de8d9f9ec15e2d8d87dde999996dca28f826e32d4d69d3eee672d003,
pending1794072019/no trial. Readiness and elapsed-earliest-time receipts precede
an explicit registered-job trigger. One execution proves neither sustained natural
cadence nor cancellation/expiry correctness. Final OTA commit, original inspection/
photo retention and stopped-resource cleanup have saved receipts. Retained-history
metadata (860024 KiB, 8454 files) establishes no leak or per-session growth rate.

Decision: security first, then users' data. Preserve rollback checks, transaction
ownership, lease policy and the frozen runtime; keep failed reliability acceptance
separate from recovered feature success. No eligible item is claimed or reassigned.
S1 stays parked, S2 requires a Play account, S10 and the post-beta P1 stay deferred.
Only mirrored integration evidence notes and the roadmap top note change; item
Status cells remain unchanged. Earlier November 7 gates retain their original
implementation scope. This evidence-only review ran no fresh full gates,
emulator session or iOS acceptance. Both test-app repositories stayed read-only;
no package-version changes, protected-branch writes, pushes or releases.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_22_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_142_REPORT.md}; App C
evidence/iteration-142/{evidence-audit.json,doctor.txt,archived-release.json,
archived-debug.json,embedded-both-manifests.json,initial-settings-outcome.json,
initial-settings-return-full-logcat.txt,initial-settings-return-exit-info.txt,
renderer-loss-correlated.txt,settings-outcome.json,startup-logcat.txt,
worker-full-logcat.txt,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-execution.json,background-force-qualification.json,
background-sqlite-before-worker.json,background-sqlite-before-resume.json,
background-state-before-raw.json,background-state-after-raw.json,
background-state-comparison.json,final-native-retention.json,cleanup.json,
snapshot-end-check.json,storage-metadata.json}.

## November 7: iteration 141 incomplete regression evidence

In plain terms: every must-have and original queue item is marked done; no
eligible new feature or queue refresh remains. Packages bases remain code
d037f233f8ffbdd0a72d22a42715974deb50287c and site
d14ece8ea97e17f9b753b31e52d15843db40abdd. Independently checked all 39 recorded
exact code/site tips and both packages bases as ancestors of the integrations.
Read both findings inventories and newest reports: Kundalini 22 / App C 141.
Kundalini's release acceptance remains incomplete; the upstream F-81/F-82 and
cold-launch routing fixes do not replace dedicated post-fix app acceptance.

App C's saved audit has 46 passing receipt-consistency checks, acceptance=false.
Independently checked all 21 evidence links in its latest report. Official offline
CLI refresh, bridge integrity, web build, three Node tests, twelve Flutter tests
and Dart analysis have successful saved receipts. Builtin verification records
seq1794068533/five files; this review did not rerun signature verification.
Release build timed out after 900009ms; debug build was not reached. Neither is
a completed APK delivery. No current native/offline/OTA/isolated-worker acceptance.

Doctor records 15 PASS, 10 WARN, 2 FAIL. The signing-key scan timed out at
180366ms; the separate extended scan also timed out at 901741ms. Its zero
matchingFiles field is not a clean scan. The mapped bridge test failed after
3052ms with only a generic diagnostic. Independently matched both failures in
the doctor output and the separate full Flutter run's twelve-test success.
The latter does not explain or erase the earlier failure. New minor finding
F-54 requests bounded child-test diagnostics, with credentials excluded; no
speculative runtime change or historical finding closure follows from it.

Independently matched two activity-service 10000ms dump timeouts and widespread
system-app ANRs in raw startup logs. F-53 records this external startup/service
failure, not an established App C crash or Valence cause. The saved direct boot
probe reports booted=false, ending at 295126ms with device offline. Harness
recovery and direct-launch observations remain separate from build results.
Initial CLI timeout and overlapping pub-get failure remain separate from the
successful offline retry and later pub-get. Copied unexecuted device runners
are inputs, not execution evidence.

Source/cleanup receipts record unchanged app-owned source, no device data clear
or restore, owned mock stopped and emulator absent. Original data retention was
not reverified, and final airplane-setting read was unavailable; no retention
or final device-setting success is inferred. No APK archive, worker execution,
activation-byte comparison or natural-cadence proof exists for this iteration.

Decision: security first, then users' data. Keep the frozen runtime, transaction
ownership and failed/incomplete evidence intact. S1 stays parked, S2 requires a
Play account and S10 stays deferred. No eligible item is claimed or reassigned.
Only mirrored integration evidence notes and the roadmap top note change; item
Status cells remain unchanged. Earlier November 7 full gates retain their original
implementation scope. This evidence-only review checked ancestry, saved receipts,
raw diagnostics, report links, mirrored text and whitespace; it ran no fresh full
gates, emulator session or iOS acceptance. Both test-app repositories stayed
read-only; no package-version changes, protected-branch writes, pushes or releases.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_22_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_141_REPORT.md}; App C
evidence/iteration-141/{evidence-audit.json,runner-notes.md,doctor-current.txt,
doctor-rows.json,extended-key-scan.json,flutter-tests.txt,iteration-outcome.json,
build-release-execution.json,verify-builtin.txt,startup-full-logcat.txt,
startup-exit-info.txt,direct-boot-observation.json,bridge-integrity.json,
snapshot-end-check.json,application-review.json,device-cleanup.json,mock-stopped.json}.

## November 7: refreshed integration with cold-launch route precedence

In plain terms: every must-have and original queue item is marked done, including
R34; there is no eligible new item. Refreshed both integrations on code packages
d037f233f8ffbdd0a72d22a42715974deb50287c and site packages
d14ece8ea97e17f9b753b31e52d15843db40abdd. Implementation merge heads are code
922d4ced61ed9d5fa8014a7459236d82877e8f18 and site
fe087394a836249436acf59bad32822613e8f408.

Assembly: retained all 39 exact code/site tips in the ordered table below,
beginning R8, R7, R6, R3, R4, R5, R9, R10, R14 and ending background-lock-result,
then merged the newest packages into each integration. Checked every recorded
tip and both packages bases as ancestors. Only the two code changelogs conflicted;
kept both entries, with the new launch-routing entry first. Runtime, tests, spec
and site docs merged automatically. Schema reservations, example schema 20,
built-in revision 20 and package versions remain unchanged.

Decision, security first, then users' data: honor an undrained launch destination
before restoring a stale route, while retaining the saved draft. Account and
bundle checks still run first; mailbox peeks do not consume delivery. Opaque
notification payloads also pre-empt the route, even if the page cannot route them;
a route-specific draft must record and check its own route. Those tradeoffs are
already stated in the spec and both restoration guides. Keep the existing
committed-sync-progress handling, acquisition-based lease age and stale bridge
import diagnostics. No lease pre-emption, expiry, transaction-cancellation or
schema change is introduced.

Security-path checklist: inspected the combined changes against signature/appId/
sequence/floor/requires/file verification order, nonce and strict decoding,
navigation/subframe locks, atomic activation writes, key isolation, account and
outbox ownership, and release-build dev exclusion. These protections remain in
place. This is a local integration review, not an independent security review.

Fresh gates on those implementation merge heads, 2026-11-07:
- npm test: 120 passed, zero failures/skips; generated Dart analyzed and executed.
- Core flutter test --concurrency=1: 655 passed on the first run; fatal-info
  analysis clean; publish dry run: zero warnings.
- Push: 2 tests passed; fatal-info analysis clean; publish dry run: zero warnings,
  one local pubspec_overrides dependency hint.
- Bridge: 37 tests passed, zero skips; strict/verbatim TypeScript clean;
  npm pack --dry-run passed.
- Site: 50-page build and SEO checks passed.
- Example: 29 tests passed; debug APK built (assembleDebug 272.1 seconds).
  Standalone Windows py audit printed PASS for the resolved core graph, manifest
  and all 19 DEX files. The existing plugin Kotlin migration advisory remains;
  it did not fail the build.
No assertions, timeouts or gates were weakened. Package tests and these build
checks do not establish test-app acceptance or natural worker cadence.

Read both findings inventories and newest reports: Kundalini 22 / App C 140.
Kundalini's release acceptance remains incomplete: cold notification routing was
unresolved, widget/share/haptics were not rerun and F-81 lacks dedicated post-fix
renewal-age device acceptance. R34's upstream example-device check covers the
link mailbox; it does not establish notification or push device acceptance.
Its doctor artifact records 21 PASS, 6 WARN, zero FAIL. Preserve F-81/F-82's
historical evidence despite their upstream fixes.

App C's saved audit has 84 passing artifact checks and scoped acceptance=false.
Independently matched the system_server728 fatal NullPointerException at
20:00:06 in AppCompatCameraDisplayRotationPolicy. The report also retains
post-reboot App C2323 startup ANR and external photo-picker5923 ANR; no Valence
cause is established. Restored-ready initially failed after extraction; the
successful same-launch continuation is separate. Settings later returned painted
in PID3667 and explicit postrestore sync is ok/pending0. Doctor records 16 PASS,
10 WARN and 1 FAIL: its 180-second Git scan timed out. A separate equivalent
extended scan passed; it does not replace that FAIL or the initial 300-second
outer-wrapper timeout. Historical startup/process/storage findings stay open.

Independently rehashed the archived App C release APK (54777012 bytes,
52eb23e7a4c24e2d8d8f62396c0a2a7fd97954d1468f96e2eb8685d0a61a7d5d) and debug
APK (193198547 bytes,
e60ea6e7bf2dbbc164dfb1c749807660e1f58bbf1f094c90977ed41191a36af6).
Both embedded manifests name builtin1794059919. These are archive/receipt checks,
not fresh App C builds or signature verification. Saved rollback has
current1794062590/no trial/broken1794062600 in bad.

Matched all seven PID8026 callback/lease/SUCCESS lines against raw worker logs
and their absence from the before capture. Raw activation bytes are identical,
SHA256 5be18ff1015fc07b074af386b7404936c9904a31ad612680110d9e43f149afbc,
current1794062661/pending1794062671/no trial. Native SQLite receipts record
bidirectional effects and outbox0 before foreground. Execution explicitly records
forced=true: one scheduler trigger after Ready/earliest-time checks proves
neither sustained natural cadence nor cancellation/expiry correctness.

S1 stays parked, S2 needs a Play account, S10 stays deferred. Item Status cells
unchanged. Both test-app repos stayed read-only. No protected-branch commits or
merges, package-version changes, pushes or publications. No fresh emulator or
iOS acceptance; iOS remains experimental and untested.

Evidence: both VALENCE_FINDINGS.md files and newest iteration reports;
Kundalini test-evidence/it22/doctor.json; App C evidence/iteration-140/
{evidence-audit.json,runner-notes.md,archived-release.json,archived-debug.json,
native-failure-logcat.txt,settings-outcome.json,postrestore-outcome.json,
rollback-confirmed.json,worker-execution.json,worker-completion-proof.json,
worker-lease-diagnostics.json,worker-full-logcat.txt,background-full-log-before.txt,
background-state-before-raw.json,background-state-after-raw.json,
background-sqlite-before-resume.json,doctor-warnings.md}.

## November 7: refreshed integration on the lease-age and bridge-diagnostic fixes

In plain terms: every must-have and original rebase-queue item is marked done;
there is no eligible new item. Refreshed both integrations on code packages
0857097fef8556d8152a2f4de6169b6078aeea54 and site packages
768eacff586478f656253b6b4bb28633f63dffd5. The tested merge heads are code
020d7555ca52edc096ead8e43a3c0a5292edb892 and site
e49896199a76ee622c74ab14102aa927d5b19d47. This note adds documentation only.

Assembly: retained the 39 exact tips in the ordered table below, beginning R8,
R7, R6, R3, R4, R5, R9, R10, R14 and ending background-lock-result, then merged
the newest packages into each integration. Independently checked all 39 exact
code/site tips and both new packages heads as ancestors. The only conflicts
were the two code changelogs: kept both the partial-progress entry and the new
lease-age entry. Runtime and site-guide merges were automatic; inspected their
combined behavior rather than replacing either side. Reserved schema/since
numbers, example schema 20, built-in revision 20 and package versions stay put.

Decision, security first, then users' data: preserve the pending branch's
committed-page/chunk accounting, auth/offline precedence and primary-error stack
handling. Preserve upstream's additive fourth lease-row field for acquisition
time: renewal still moves the original timestamp that controls the TTL.
The acquisition-age test reads through another driver and checks renewal,
continued liveness and agreement with the release diagnostic. No lease
pre-emption, transaction cancellation or expiry change is introduced.
The new wizard warning compares generated import names with installed published
declarations; it does not install dependencies or establish shape compatibility.
Spec, runtime, generated delegation and the matching site docs remain consistent.

Security-path checklist: the combined diff leaves signature/appId/sequence/
floor/requires/file verification order, nonce, strict decoding, navigation and
subframe locks, atomic activation writes, key isolation, account/outbox ownership
and release-build dev exclusion intact. This was a local integration review,
not an independent security review or a WorkManager cancellation reproduction.

Fresh gates on those implementation heads, 2026-11-07:
- npm test: 120 passed, zero failures/skips; generated Dart executed.
- Core flutter test: 650 passed on the first run; fatal-info analysis clean;
  publish dry run: zero warnings.
- Push: 2 tests passed; fatal-info analysis clean; publish dry run: zero
  warnings, one local pubspec_overrides dependency hint.
- Bridge: 37 tests passed, zero skips; strict/verbatim TypeScript clean;
  npm pack --dry-run passed.
- Site: 50-page build and SEO checks passed.
- Example: 29 tests passed; debug APK built (assembleDebug 30.3 seconds).
  Standalone Windows py audit printed PASS for the resolved core graph,
  manifest and all 19 DEX files. Build emits the existing plugin Kotlin
  migration advisory; no build failure.
No assertions, timeouts or gates were weakened. No fresh emulator session,
remote-push acceptance, sustained worker-cadence test or iOS acceptance.

Read both findings inventories and newest reports: Kundalini 22 / App C 139.
Kundalini reports F-79 adoption, signed store/OTA/rollback and offline seed
checks; cold notification routing remains unresolved and widget/share/haptics
were not rerun. Its doctor artifact totals 21 PASS, 6 WARN, zero FAIL.
F-81/F-82 now have upstream fixes and passing package regressions; the app has
not yet supplied dedicated post-fix renewal-age device acceptance. Do not close
its findings on the strength of App C's unrelated successful worker.

App C's saved audit records 82 checks and scoped acceptance=true. Independently
rehashed release APK (54777012 bytes,
78eb224a60070702ad6c00045fc428a0772a45056bb59746c70d0fec62fc4163) and debug
APK (193194989 bytes,
39a9a9e1f1a917a32edd309443cda8a16c3629144cebade01c3d5cca2721358f);
both embedded manifests name builtin1794056348. These are archive/receipt
checks, not fresh App C builds or signature verification. Settings returned
painted in PID5575; explicit postrestore sync is ok/pending0, separately from
the earlier offline/pending0 receipt. Saved rollback has current1794057279,
no trial and broken1794057289 in bad.

Independently matched all seven new PID9121 worker callback/lease/SUCCESS
lines against raw logs and their absence from the before capture. Raw activation
bytes are identical, SHA256
e92693acce3f70bef95e08b5c10d6f3ae876bf27b775f6d60e4719348f33205d,
current1794057347/pending1794057357/no trial. Native SQLite receipts record
bidirectional effects/outbox0 before foreground; those effects were read,
not replayed. Execution records forced=true after Ready/earliest-time checks:
one explicit scheduler trigger proves neither natural cadence nor cancellation.
Initial cleanup failed on a stale forward belonging to Settings PID5575;
cleanup-only continuation removed it without replaying worker/OTA/data actions.
Historical startup/process/storage findings remain open.

S1 stays parked, S2 needs a Play account, S10 stays deferred; R34 is already
marked done and is not available to this builder. Item Status cells unchanged.
Both test-app repos stayed read-only. No protected-branch commits/merges,
version changes, pushes or publications.

Evidence: both apps' VALENCE_FINDINGS.md and ITERATION reports; Kundalini
test-evidence/it22/doctor.json; App C evidence/iteration-139/{evidence-audit.json,
archived-release.json,archived-debug.json,settings-outcome.json,
postrestore-outcome.json,rollback-confirmed.json,worker-execution.json,
worker-completion-proof.json,worker-lease-diagnostics.json,worker-full-logcat.txt,
background-full-log-before.txt,background-state-before-raw.json,
background-state-after-raw.json,background-sqlite-before-resume.json,
initial-cleanup.json,cleanup.json,runner-notes.md}.

## November 7: Kundalini 22 and App C 138 evidence review

In plain terms: all must-haves and the original rebase queue remain done. No
eligible item is available. Code packages remains
0fe3391faf2ba25e69ccae3079382be2179be4be; site packages remains
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Independently verified all 39 recorded
exact feature tips and the packages bases as ancestors of both integrations.
Read both findings inventories and newest reports, Kundalini 22 and App C 138.
S1 remains deliberately parked, S2 requires a Play account, S10 is deferred.
No shared roadmap cells or top-line gate date changed.

Kundalini reports successful F-79 adoption: the onLink initial flag replaces its
handwritten link subscription/mailbox wrapper. It reports a fresh store build,
offline seed launch, good OTA commitment and two-strike rollback, but its final
release check remains incomplete: cold notification routing is unresolved,
widget/share/haptics were not rerun, and F-81 is major. Its reminder-window bug
was app wiring and is reported fixed there. The wrong-day cold tap remains an
unreproduced observation, not an established framework defect. Saved doctor
rows independently total 21 PASS, 6 WARN, zero FAIL.

F-81 is a concrete diagnostic mismatch in the current source, not evidence for
lease pre-emption. In packages/valence/lib/src/sync.dart, renewLease rewrites
the row timestamp after applied pages; _heldLease computes ageMs from that
renewable timestamp. releaseLease instead computes heldForMs from the driver's
acquisition-time _leaseTakenAt. Thus status and refusal ages can drop after a
renewal while the release duration continues from acquisition. The app's report
of 28/58 ms during an approximately 100-second hold is consistent with this
source behavior; no raw lease trace is archived in its it22 evidence directory,
so those timings were not independently replayed or verified. Contracts 4.3/5.6
call this the holder's age; an eventual correction needs an acquisition timestamp
visible across isolates, separate from the TTL renewal timestamp, with a test
covering renewal inside one hold. Do not stop renewal, infer a leak from these
numbers, or weaken acquisition/expiry to make diagnostics look correct.
F-82 separately reports a stale bridge package after CLI refresh; reinstalling
the bridge resolved the generated ReceivedLink type error in the app. No new
dependency check or runtime fix is claimed by this review.

App C's saved audit has 82 passing artifact checks, acceptancePassed=false.
The initial retained-release observation exhausted its polls under Android
service dialogs; the initial mixed-link CDP read timed out. Later recovered
checks remain separate. Settings returned painted in the same PID5937.
Postrestore sync initially returned busy/pending0; that receipt is not ok.
No new Valence cause, lease-expiry violation or historical finding closure is
established.

Independently rehashed both archived APKs against their delivery receipts:
release 54777012 bytes, SHA256
5638d9397aae55f889406346f79f353621e027c02738eee001977fe872d7ddce;
debug 193194989 bytes, SHA256
e6c016e5facfbc4ca54ce3852be5413de7f2a0a54ceca4b9b5b0aea44c3e48ad.
These checks establish archive/receipt agreement, not a fresh build, signature
verification or device installation. Saved rollback state now really records
current1794054650, trial=null and broken1794054661 in bad; the second-start
ownership receipt identifies App C. This is current evidence, not retroactive
acceptance of iteration137's interrupted rollback.

Independently matched all seven callback/lease/SUCCESS lines for PID9401 in raw
worker logs and their absence from the pre-worker capture: begin18:12:54.843,
background entry18:12:55.003, lease take.052, release18:12:56.021, background
exit/callback complete.025, WorkManager SUCCESS.035. Saved execution records
forced=false: one scheduler-started execution without an explicit trigger,
not sustained cadence or cancellation/expiry acceptance. Saved native SQLite
receipt records outbox0 and incoming/outgoing fixture rows before foreground;
those database effects were read, not replayed. Independently compared raw
activation bytes: equal, SHA256
1cfb20b14a25a585d01f49f5c4fb85e5be1ebe3ed0e6d03c3db670248bff3a42,
current1794054721/pending1794054731/no trial. Cleanup records stopped App C and
owned mocks, airplane0 and scoped forwards removed.

Decision: security first, then users' data. Preserve transaction ownership and
the frozen runtime; record F-81 for a focused corrective item rather than taking
a parked feature or assigning a new shared roadmap item outside this queue.
This change contains mirrored integration evidence notes only. No behavior,
schema, version or migration change; no fresh full gates, emulator session,
independent runtime review or iOS acceptance. Earlier gate results retain their
original scope. Both test-app repositories stayed read-only.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_22_REPORT.md,
test-evidence/it22/doctor.json}; valence-test-app-c/{VALENCE_FINDINGS.md,
ITERATION_138_REPORT.md}; App C evidence/iteration-138/{evidence-audit.json,
archived-release.json,archived-debug.json,settings-outcome.json,
postrestore-outcome.json,rollback-confirmed.json,
rollback-second-start-ownership.json,worker-execution.json,
worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt,
background-sqlite-before-resume.json,background-state-before-raw.json,
background-state-after-raw.json,cleanup.json}.

## November 7: iteration 137 incomplete evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Verified all 39 recorded exact feature
tips as ancestors of both integrations. Read both findings inventories and newest
reports, Kundalini 21 and App C 137. App C's session began November 6 and ended
November 7; preserve those evidence dates. S1 stays parked, S2 requires a Play
account and S10 stays deferred.

The saved audit records 41 passing artifact checks, acceptance=false and
regressionComplete=false. Corrected native/media/reminder/link/widget results
are recovery results, not a completed regression. Independently matched raw
system_server PID684 Invalid IntRange exceptions at November 6 07:21:05.933,
App C ANR at November 7 16:00:38.161, renderer PID5623 LOW_MEMORY exit at
16:04:03.134, Chromium's host PID4204 termination diagnostic at .212 and
host SIGNALED/status9 exit at .858. Keep the system-service loss, startup ANR,
renderer loss, SystemUI overlay, orphan permission task and runner sequencing
failures separate. No Valence cause, leak or blocking frame is established.
The first raw-log extraction assumed UTF-8 and failed; BOM-aware UTF-16 decoding
then matched the native lines and exit records. This was an evidence-reader
failure, not an app failure.

Settings later returned painted in the same PID8040. The saved stopped-native
receipt records original inspection fields and photo retained, matching photo
SHA256 and outbox0; these database/media checks were read, not replayed.
Neither recovery nor the current checks close historical F-33/F-35/F-36 or
Kundalini F-79/F-80. In particular, a replayed job holding a database lease does
not justify pre-empting its transaction without ownership evidence.

Independently rehashed both archived APKs and extracted their embedded builtin
manifests: both name seq1793928368. Release: 54777012 bytes, SHA256
bf7f28a2eb7a6007fbb8ca25801c5eca8018573eeb9753e4370215a96189807e.
Debug: 193194989 bytes, SHA256
af405ac42bd1e8ce29042ceaa42832fc9d03d7cf767d830a9a90cde051a194d8.
These checks establish archive/receipt agreement and embedded seq, not a fresh
signature verification, APK build or device installation.

Saved final activation state has current1794047614, trial1794047625,
trialFails1, pending=null. Despite its filename, rollback-confirmed.json still
contains that one-strike trial; it is not rollback proof. Another app became
foreground during the second-strike observation, so the test is inconclusive.
Recovery offer1794047841 is locally verified in a saved receipt only; device
download/apply remains false. Isolated worker regression was not begun, and no
new worker execution or cadence claim is available. Final notification queue
reads failed. Cleanup receipts record only App C/owned mocks stopped, its two
recorded forwards removed and airplane mode observed off without mutation.

Decision: security first, then users' data. Preserve the frozen runtime,
transaction ownership, signed activation state and failed/incomplete acceptance
evidence. No speculative runtime fix, schema, version or migration change.
Only mirrored integration evidence notes and the roadmap top note change;
item Status cells remain untouched. Earlier November 6 full gates retain their
scope. This evidence-only review ran ancestry, archive hashes, embedded-seq,
saved-audit and diff checks; no fresh full gates, emulator session, independent
runtime review or iOS acceptance. Both test-app repositories stayed read-only.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_137_REPORT.md}; App C
evidence/iteration-137/{evidence-audit.json,runner-notes.md,
system-service-interruption.json,second-basic-logcat.txt,
f35-current-anr.json,after-systemui-full-logcat.txt,after-systemui-exit-info.txt,
settings-outcome.json,final-native-retention.json,archived-release.json,
archived-debug.json,embedded-both-manifests.json,partial-final-state.json,
rollback-confirmed.json,recovery-good-offer.json,partial-cleanup.json,
partial-owned-forward-cleanup.json}.

## November 6: iteration 136 evidence review

In plain terms: every must-have and rebase-queue item remains done; no eligible
feature or queue refresh remains. Packages bases remain code
0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Verified all 39 recorded exact feature
tips as ancestors of both integrations. Reviewed both findings inventories and
newest reports, Kundalini 21 and App C 136. S1 stays parked, S2 requires a Play
account and S10 stays deferred.

App C's saved audit records 98 passing artifact checks but scoped
acceptance=false. The initial bounded CDP paint probe failed with null
document.body; its raw error survives only in session output, not a persisted
receipt. Later readiness passed without restart or data clear. Separately, a
retained-release accessibility observation failed; install-release.txt preserves
the exit137/null-root diagnostic. The same-launch continuation succeeded.
No app crash, database lock or Valence cause is established by these observations.
Retained paint at 4606ms is measured from that continuation, excluding the failed
observation. First fresh paint at 15057ms and fresh open completion at 647ms
have separate boundaries; none establishes exact first-paint latency.

Settings records painted return in PID5419, and explicit postrestore sync is
ok/pending0. These successes do not close historical F-33/F-36, or Kundalini
F-79/F-80. Kundalini's replayed background job, database wait and skipped update
remain observations requiring diagnosis; pre-empting a lease without identifying
transaction ownership would put users' data at risk.

Independently rehashed the archived APKs against delivery receipts:
release 54777012 bytes, SHA256
e186d34cb907a715af6aa221b43701516d4217721d6eb54b63da1fe2372ae765;
debug 193194989 bytes, SHA256
e6eb58f7d5668437a12910abc3556bb583ae28102eb48613b22a4e7ab12138a0.
The report records signed builtin 1793926534 in both APKs; embedded manifests
were not independently extracted. Worker-phase activation bytes independently
compare identical, SHA256
915e41076a1958e2d357d187cf1e5e93480afe4e086d43e9df3e6cdf03d4c3f8,
pending 1793927380, no trial. All seven PID8772 callback/lease/native SUCCESS
lines match raw worker logs and are absent from the pre-worker capture:
begin 07:01:00.103, background entry .224, lease take .259, release
07:01:01.253, background exit/callback complete .256, SUCCESS .263.
Execution records forced=true. One explicitly triggered execution proves neither
natural cadence nor cancellation/expiry correctness. SQLite, retention and
cleanup receipts were read, not independently replayed.

Decision: security first, then users' data. Preserve the frozen runtime and
failed acceptance evidence. No behavior, schema, package version or migration
changes. Only mirrored integration evidence notes and the roadmap top note
change; item Status cells remain untouched. Earlier November 6 full gates retain
their scope; this evidence review ran no fresh full gates, emulator session,
independent runtime review or iOS acceptance. Test apps stayed read-only.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_136_REPORT.md}; App C
evidence/iteration-136/{evidence-audit.json,runner-notes.md,
initial-startup-probe-qualification.json,install-release.txt,
retained-observation-continuation-execution.json,settings-outcome.json,
postrestore-outcome.json,binary-delivery-state.json,
background-state-before-raw.json,background-state-after-raw.json,
worker-execution.json,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt}.

## November 6: iteration 135 evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Verified all 39 current recorded exact
feature tips as ancestors of both integrations. Read both findings inventories
and newest reports: Kundalini 21 and App C 135. S1 stays deliberately parked,
S2 requires a Play account, and S10 stays deferred.

App C's saved audit records 98 passing artifact checks but scoped
acceptance=false. Independently matched the preserved Camera ANR in lastanr and
raw logcat: com.android.camera2/CaptureActivity, PID6612, input-dispatch timeout
at 06:18:33 after waiting 5003ms for MotionEvent. The earlier null-root UI dump,
whose lastanr reported none, is a separate failed observation. Successful
camera/gallery decoding after closing the Camera dialog is recovery, not a fix;
no Valence cause is established. Settings records painted return in the same
PID5224; explicit postrestore sync is ok/pending0 and restore execution status 0.
Current recovery does not close F-33/F-36 or Kundalini F-79/F-80.

Retained paint was observed at 38598ms after four unsuccessful observations;
first fresh paint at 15527ms is separate from fresh open completion at 961ms.
These are observation boundaries, not exact first-paint latency or causal proof.
The inherited fresh-retry filename names the first current bounded observation.

Independently rehashed archived iteration135 APKs against delivery receipts:
release 54777012 bytes, SHA256
a3a59cfee4a2fc47561f04f45684da890686e5e0f381e53c05fbb2713ce3f5f1;
debug 193194989 bytes, SHA256
d2f5c853398d09d1a60718e8a70884c21246ec89e4487cace03f3f164143a0b5.
The report records signed builtin 1793924850 in both APKs; embedded-manifest
comparison was not independently rerun. Independently compared identical
worker-phase activation bytes, SHA256
66bac31633ee9c3baf3dcc3b50abc1045f3b4286234c6cd1913ca01b5c1d4e8c,
pending 1793925705, no trial. All seven PID8926 callback/lease/native SUCCESS
lines match raw worker logs and are absent from the pre-worker capture:
begin 06:31:14.609, background entry .720, lease take .757, release
06:31:15.826, background exit/callback complete .829, SUCCESS .837.
Execution records forced=true. Reported scheduler readiness and elapsed earliest
time preceded the explicit trigger; one execution proves neither natural cadence
nor cancellation/expiry correctness. SQLite effects, retention and final cleanup
receipts were read, not independently replayed.

Runner notes preserve an initial nonexistent-test invocation, raw whitespace
capture ENOBUFS and the streamed status-2 retry separately from the passing
application/tooling/docs whitespace check. Doctor records 17 PASS / 10 WARN /
0 FAIL; timeout paths remain unexercised. Findings record 812096 KiB / 7988
retained files; that footprint alone proves neither a leak nor a growth rate.

Decision: security first, then users' data. Preserve the frozen runtime and the
failed acceptance evidence; these observations do not justify lease pre-emption
or a transaction-ownership change. No behavior, schema, package version or host
migration changes. Only mirrored integration evidence notes and the roadmap top
note change; item Status cells remain untouched. Earlier November 6 full gates
retain their scope; no fresh full gates, emulator acceptance, independent runtime
review or iOS acceptance is claimed. Test apps stayed read-only.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_135_REPORT.md}; App C
evidence/iteration-135/{evidence-audit.json,runner-notes.md,
camera-retry-lastanr.txt,camera-retry-full-logcat.txt,settings-outcome.json,
postrestore-outcome.json,restore-execution.json,binary-delivery-state.json,
background-state-before-raw.json,background-state-after-raw.json,
worker-execution.json,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt,cleanup.json}.


## November 6: iteration 134 evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Verified all 39 current recorded exact
feature tips as ancestors of both integrations. Reviewed both findings inventories
and newest reports: Kundalini 21 and App C 134. S1 stays deliberately parked,
S2 requires a Play account, and S10 stays deferred.

App C's saved audit passes 97 artifact checks with scoped acceptance=true.
Settings records same PID 5082 and painted return; explicit postrestore sync is
ok/pending0. Restore execution records status 0. The initial retained probe ran
before the startup page installed the bridge and returned TypeError reading r;
the preserved failure and successful bounded meaningful-paint retry are separate
attempts. No Valence defect or crash is established by that probe. Retained paint
observed at 16797ms and first fresh paint observed at 15465ms are separate from
fresh open completion at 1042ms. No exact first-paint latency or cause is proven;
the inherited fresh-retry filename names the first current bounded observation.
Current success does not close iteration 129's F-33 or iteration 130's F-36.
Kundalini F-79/F-80 and historical reliability findings remain open.

Independently rehashed both archived iteration134 APKs: release 54777012 bytes,
SHA256 4d89bc3946148b61106c0a123406768a0e76b44d301855233e2211b1416b2b9e;
debug 193194989 bytes,
SHA256 9659240c5255fc9e052520a59cc962397cb096816372b8e0a35d8fc4f451c372.
Both match saved delivery receipts. The report records signed builtin 1793922986
in both APKs; embedded-manifest comparison was not independently rerun.
Independently compared identical worker-phase activation bytes, SHA256
e2e8a7c2df32fb1e67ba90f4410e88abd596bd5f13b3c638b3c64dd63fef7f6c,
pending 1793923732, no trial. All seven exact PID8664 callback/lease/native
SUCCESS lines match raw worker logs and are absent from the pre-worker capture:
callback begin 06:00:13.293, background entry .411, lease take .449,
release 06:00:14.469, background exit .471, callback complete .472, SUCCESS .480.
The execution receipt records forced=true. Reported scheduler readiness and
elapsed earliest time preceded the explicit trigger; one execution proves
neither natural cadence nor cancellation/expiry correctness. Saved SQLite
effects, retention and final cleanup were read, not independently replayed.

Runner notes preserve raw-log whitespace status 2 separately from the passing
application/tooling/docs check. Doctor records 17 PASS / 10 WARN / 0 FAIL;
timeout paths remain unexercised. Findings record 808836 KiB / 7954 retained
files; a history footprint is not evidence of a leak or per-session growth rate.

Decision: security first, then users' data. A passing scoped regression does not
justify pre-empting a lease, changing transaction ownership or closing historical
failures. Preserve the frozen runtime. No behavior, schema, package version or
host migration changes. Only mirrored integration evidence notes and the roadmap
top note change; item Status cells remain untouched. Earlier November 6 full
gates retain their recorded scope; no fresh full gates, emulator acceptance or
independent runtime review is claimed. iOS stays experimental and untested.
Test apps stayed read-only; no protected-branch commit/merge, push or publication.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_134_REPORT.md}; App C
evidence/iteration-134/{evidence-audit.json,settings-outcome.json,
postrestore-outcome.json,restore-execution.json,binary-delivery-state.json,
background-state-before-raw.json,background-state-after-raw.json,
worker-execution.json,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt,runner-notes.md}.

## November 6: iteration 133 evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Verified all 39 current recorded exact
feature tips as ancestors of both integrations. Reviewed both findings inventories
and newest reports: Kundalini 21 and App C 133. S1 stays deliberately parked,
S2 requires a Play account, and S10 stays deferred.

App C's saved audit passes 97 artifact checks with scoped acceptance=true.
Settings records same PID 5233 and painted return; explicit postrestore sync is
ok/pending0. Restore execution records status 0. Initial retained baseline failed
with UND_ERR_SOCKET during startup; the preserved failure and later successful
probe are separate attempts, and no Valence cause is established. Retained paint
observed at 16310ms and first fresh paint observed at 14945ms are separate from
fresh open completion at 651ms. No exact first-paint latency or cause is proven;
the inherited fresh-retry filename names the first current bounded observation.
Current success does not close iteration 129's F-33 or iteration 130's F-36.
Kundalini F-79/F-80 and historical reliability findings remain open.

Independently rehashed both archived iteration133 APKs: release 54777012 bytes,
SHA256 995919c40a914cbd0ac14347af09534910757f067d044916e7b594b1068bf830;
debug 193194989 bytes,
SHA256 955848d0caf98cc7134c652fd8f88af93ef418d410555edec8c6b3df7cf4bcdf.
Both match saved delivery receipts. The report records signed builtin 1793921186
in both APKs; embedded-manifest comparison was not independently rerun.
Independently compared identical worker-phase activation bytes, SHA256
f6ca34dd7d1bd676b0dfb9bf21aee5b3660bdb53fa42e0bbb87e5c49fe2a5d9b,
pending 1793921949, no trial. All seven exact PID8459 callback/lease/native
SUCCESS lines match raw worker logs and are absent from the pre-worker capture:
callback begin 05:30:15.880, background entry 05:30:16.008, lease take .046,
release 05:30:17.043, background exit/callback complete .046, SUCCESS .056.
The execution receipt records forced=true. Reported scheduler readiness and
elapsed earliest time preceded the explicit trigger; one execution proves
neither natural cadence nor cancellation/expiry correctness. Saved SQLite
effects, retention and final cleanup were read, not independently replayed.

Runner notes preserve an initial preparation-script whitespace failure and its
corrected rerun, and raw-log whitespace status 2 separately from the passing
application/tooling/docs check. Doctor records 17 PASS / 10 WARN / 0 FAIL;
timeout paths remain unexercised. Findings record 800796 KiB / 7872 retained
files; a history footprint is not evidence of a leak or per-session growth rate.

Decision: security first, then users' data. A passing scoped regression does not
justify pre-empting a lease, changing transaction ownership or closing historical
failures. Preserve the frozen runtime. No behavior, schema, package version or
host migration changes. Only mirrored integration evidence notes and the roadmap
top note change; item Status cells remain untouched. Earlier November 6 full
gates retain their recorded scope; no fresh full gates, emulator acceptance or
independent runtime review is claimed. iOS stays experimental and untested.
Test apps stayed read-only; no protected-branch commit/merge, push or publication.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_133_REPORT.md}; App C
evidence/iteration-133/{evidence-audit.json,settings-outcome.json,
postrestore-outcome.json,restore-execution.json,binary-delivery-state.json,
background-state-before-raw.json,background-state-after-raw.json,
worker-execution.json,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt,runner-notes.md}.

## November 6: iteration 132 evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Verified all 39 current recorded exact
feature tips as ancestors of both integrations. Read both findings inventories
and newest reports: Kundalini 21 and App C 132. S1 stays deliberately parked,
S2 requires a Play account, and S10 stays deferred.

App C's saved artifact audit passes 96 checks with scoped acceptance=true.
Settings records same PID 6480 and painted return; explicit postrestore sync is
ok/pending0. The current restore command completed successfully. These current
successes do not reverse iteration 129's F-33 COMMIT failure or iteration 130's
F-36 renderer loss. Kundalini F-79/F-80 and historical reliability findings remain
open. Retained paint observed at 17360ms and fresh paint observed at 20395ms are
separate from fresh open completion at 849ms; no exact first-paint latency or
cause is established. The inherited fresh-retry filename names the first current
bounded observation, not a second clear or retry.

Independently rehashed both archived iteration132 APKs: release 54777012 bytes,
SHA256 7fab12b6b7d48b85979d7f51ae56fa0de293914ab180560dd25a4e28a39302c2;
debug 193194989 bytes,
SHA256 3b34b9701f1cac1f42e1e01f713142b675ae14773aa562037c9f08b740d6a816.
Both match saved delivery receipts. The report records signed builtin 1793919338
in both APKs; embedded-manifest comparison was not independently rerun.
Independently compared identical worker-phase activation bytes, SHA256
23859597edee86c9f9da096dd6a39b3751c40ac7da317fcbf14cfe5b8bc2b5c5,
pending 1793920157, no trial. All seven exact PID9795 callback/lease/native
SUCCESS lines match raw worker logs and are absent from the pre-worker capture:
callback begin 05:00:27.283, background entry .405, lease take .441,
release 05:00:28.496, background exit/callback complete .499, SUCCESS .508.
The execution receipt records forced=true. Reported scheduler readiness and
elapsed earliest time preceded the explicit trigger; one execution proves
neither natural cadence nor cancellation/expiry correctness. Saved SQLite
effects, retention and final cleanup were read, not independently replayed.

Runner notes preserve raw-log whitespace status 2 separately from the passing
application/tooling/docs check. Doctor records 17 PASS / 10 WARN / 0 FAIL;
timeout paths remain unexercised. Findings record 794400 KiB / 7812 retained
files; a history footprint is not evidence of a leak or per-session growth rate.

Decision: security first, then users' data. A passing scoped regression does not
justify changing transaction ownership, pre-empting a lease or closing historical
failures. Preserve the frozen runtime. No behavior, schema, package version or
host migration changes. Only mirrored integration evidence notes and the roadmap
top note change; item Status cells remain untouched. Earlier November 6 full
gates retain their recorded scope; no fresh full gates, emulator acceptance or
independent runtime review is claimed. iOS stays experimental and untested.
Test apps stayed read-only; no protected-branch commit/merge, push or publication.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_132_REPORT.md}; App C
evidence/iteration-132/{evidence-audit.json,settings-outcome.json,
postrestore-outcome.json,binary-delivery-state.json,
background-state-before-raw.json,background-state-after-raw.json,
background-state-comparison.json,worker-execution.json,worker-completion-proof.json,
worker-lease-diagnostics.json,worker-full-logcat.txt,background-full-log-before.txt,
runner-notes.md}.

## November 6: iteration 131 evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Checked all 39 current recorded exact
feature tips as ancestors of both integrations. Read both findings inventories
and newest reports: Kundalini 21 and App C 131. S1 remains deliberately parked,
S2 requires a Play account, and S10 is deferred.

App C's saved artifact audit passes 96 checks with scoped acceptance=true.
The saved Settings receipt records PID 6397 before and after, samePid=true and
pagePainted=true. This current success does not reverse iteration 130's F-36
renderer loss or iteration 129's F-33 COMMIT failure. Kundalini's F-80 contention
and historical reliability findings remain open. Startup observations of retained
paint at 23090ms and first fresh paint at 15009ms are separate from fresh open
completion at 427ms; they establish neither exact first-paint latency nor cause.

The restore command exited 1 after extraction when airplane-disable could not
connect to ADB TCP5037. Read the original failure and its execution receipt.
The first postrestore reply was offline/pending0; a later explicit reply was
ok/pending0. Preserve these as distinct attempts. The report records recovery
without another data clear or archive extraction; daemon cause is unknown.
This orchestration interruption is not evidence of a Valence transaction defect.

Independently rehashed both archived iteration131 APKs:
release 54777012 bytes, SHA256
38e684ef3a9195582a52122c194a3546923412a13e002e8c45f8ea4ea0c90e18;
debug 193194989 bytes, SHA256
7f60b4e8450524fbf6fe7eaf3d28a2bc8613ae42eebf5610ffe35c39a72606d3.
Both match saved delivery receipts. Embedded-manifest receipts record signed
builtin 1793917610 in both APKs; that comparison was read, not independently rerun.
Independently compared worker-phase activation bytes: identical SHA256
e10a7691fa7118459fdc55bb0b12cf3fad766586d168f9a0cc71107d10ac8032,
pending 1793918406, no trial. Matched all seven raw PID 10448 proof lines:
callback begin 04:31:58.502, background entry .635, lease take .674,
release 04:31:59.784, background exit and callback complete .789, native SUCCESS
.796. Exact callback begin/complete/SUCCESS lines are absent from the pre-worker
capture. The receipt records forced=true; the report qualifies readiness and
elapsed earliest time before the explicit trigger. One successful execution
proves neither natural cadence nor cancellation/expiry correctness. Saved SQLite
effects, final retention and cleanup were read, not independently replayed.

Runner notes retain raw-log whitespace status 2 separately from the passing
application/tooling/docs check. Doctor records 17 PASS / 10 WARN / 0 FAIL;
timeout paths remain unexercised. The first local ancestry reader mistakenly
included historical tables and refused its expected count; the corrected reader
selected the current 39-row table and verified every tip. A Windows wildcard
search also failed before directory-scoped discovery; neither attempt is counted
as successful verification.

Decision: security first, then users' data. One passing scoped run and an ADB
interruption provide no safe basis to change transaction ownership or lease
policy. Preserve the frozen implementation and the unresolved failures. No
behavior, schema, package version or host migration changes. Only mirrored
integration evidence notes and the roadmap top note change; item Status cells
remain untouched. Existing November 6 full gates retain their recorded scope;
no fresh full gates, emulator acceptance or independent runtime review is claimed.
iOS remains experimental and untested. Test apps stayed read-only; no protected
branch commit/merge, push or publication.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_131_REPORT.md}; App C
evidence/iteration-131/{evidence-audit.json,settings-outcome.json,restore.txt,
restore-execution.json,initial-postrestore-outcome.json,postrestore-outcome.json,
binary-delivery-state.json,embedded-both-manifests.json,
background-state-before-raw.json,background-state-after-raw.json,
worker-execution.json,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt,runner-notes.md}.

## November 6: iteration 130 evidence review

In plain terms: no eligible must-have or queue refresh remains. Packages bases
remain code 0fe3391faf2ba25e69ccae3079382be2179be4be and site
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Independently checked all 39 recorded
exact feature tips as ancestors of the current integration in both repositories.
Read both findings inventories and newest reports: Kundalini 21 and App C 130.
S1 remains deliberately parked, S2 requires a Play account, and S10 is deferred.

App C's saved audit has 95 passing artifact checks but scoped acceptance=false.
Independently matched raw Settings logs: lowmemorykiller kills renderer 5557 at
03:45:50.232; Chromium in host 5482 reports the unhandled renderer termination at
03:45:50.287; ActivityManager records host death at 03:45:50.369. Exit-info names
renderer LOW_MEMORY and host SIGNALED/status9. Saved Settings outcome records
replacement PID 7415, samePid=false and pagePainted=false before explicit recovery.
This is the F-36 signature, not evidence that Android directly killed the host for
low memory (F-50). No Valence leak or trial-loss cause is established. Later
native successes are recovery evidence. The current postrestore reply is
ok/pending0, which does not explain or close iteration 129's F-33 COMMIT failure.
Kundalini's F-80 contention and historical reliability findings remain open.

Independently rehashed both archived iteration130 APKs:
release 54777012 bytes, SHA256
be3020231cab0cd6ed154b763cbe2afe963ba033081acf2a0d4978a3d372955b;
debug 193194989 bytes, SHA256
f1251436bd9ecf35ad123c1a3ebf02fc6bb729741833da0b263e0016d962700d.
Both match saved delivery receipts. Embedded-manifest receipts record signed
builtin 1793915757 in both APKs; that comparison was read, not independently rerun.
Independently compared worker-phase activation bytes: identical SHA256
3e4e48185a6d45b626fbaeedfb9c0d23ddd4eff175907b4e9e747d19596c36b1,
pending 1793916569, no trial. Matched raw PID 10035 callback begin 04:00:20.531,
background entry .630, lease take .667, lease release 04:00:21.960,
background exit .963, callback complete .964 and native SUCCESS .974. The exact
callback begin/complete/SUCCESS lines are absent from the pre-worker capture.
The receipt explicitly records forced=true after readiness and elapsed earliest
time. One successful explicit execution proves neither natural cadence nor
cancellation/expiry correctness. Saved SQLite effects and final retention/cleanup
were read, not independently replayed.

Runner notes preserve an initial missing-input ENOENT qualification failure before
the ordered retry, a receipt rename rather than a second uninstall, and raw-log
whitespace failures separately from the application/tooling/docs check. Doctor
records 17 PASS / 10 WARN / 0 FAIL with progress/durations; timeout paths remain
unexercised. An initial local reader requested nonexistent binary-hashes.json;
the actual binary-delivery-state.json and both APKs were then read and verified.
No failed read is counted as successful verification.

Decision: preserve security, then users' data. A correlated renderer-loss signature
and one recovered sync do not justify changing transaction ownership, lease policy
or the frozen runtime. No behavior, schema, package version or host migration
changes. Only mirrored integration evidence notes and the roadmap top note change;
item Status cells remain untouched. Existing November 6 full gates retain their
recorded scope; no fresh full gates, emulator acceptance or independent runtime
review is claimed. iOS remains experimental and untested. Test apps stayed
read-only; no protected-branch commit/merge, push or publication.

Evidence: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_21_REPORT.md};
valence-test-app-c/{VALENCE_FINDINGS.md,ITERATION_130_REPORT.md}; App C
evidence/iteration-130/{evidence-audit.json,settings-outcome.json,
settings-return-full-logcat.txt,settings-return-exit-info.txt,
postrestore-outcome.json,binary-delivery-state.json,embedded-both-manifests.json,
background-state-before-raw.json,background-state-after-raw.json,
worker-execution.json,worker-completion-proof.json,worker-lease-diagnostics.json,
worker-full-logcat.txt,background-full-log-before.txt,runner-notes.md}.

## November 6: iteration 129 evidence review

In plain terms: the must-have list and rebase queue are done; there is no eligible
new item. Both integrations still include all 39 recorded exact feature tips and
current packages bases 0fe3391faf2ba25e69ccae3079382be2179be4be /
0c468908a7ed412ce13c6b2899efdc50dbd37d6b. Ancestry was checked this run.
Kundalini's newest report remains iteration 21. App C iteration 129 changes the
current reliability verdict: its saved audit passes all 95 artifact checks but
scoped acceptance is false because F-33 recurred after a retained-data restore.
This evidence does not invalidate the earlier package gates; it does prevent
reading those passing gates as unqualified device or beta acceptance.

Matched the current F-33 proof against the raw native log, PID 5037:
background callback begin 03:14:46.615; bridge E_INTERNAL / no current transaction
on COMMIT 03:14:46.762; callback complete 03:14:47.310. The foreground lease was
released at 03:14:46.759; the background-isolate entered diagnostic arrived at
03:14:46.797 and its lease was taken at 03:14:46.918. Callback overlap is observed;
these lines do not identify a transaction owner or establish why COMMIT failed.
Later offline/pending1 and reconnect/ok/pending0 results are recovery evidence,
not a fix. No lost writes, root cause or safe transaction-handling change is
established. F-33 stays major/open; F-80 contention and historical reliability
findings are not closed by this iteration.

Independently rehashed archived iteration129 APKs: release 54777012 bytes,
SHA256 5cb94d6da3ff4ffaa4b158bfd3332a20625a0bc9c77a57334279eff0a5a0fcc0;
debug 193194989 bytes,
SHA256 fb4735391461a724f3d40ca8ecff207245027b4cb4e2d9ebff7aa72b4b51d05d.
The saved embedded-manifest comparison records builtin 1793913969 in both.
Independently compared raw worker-phase activation bytes: identical SHA256
5e5c5c875d55258f974ed1326af7397237a62ce8bb210ab94d8dcaf8c83ab433,
pending 1793914746 and no trial. Matched PID 8240 callback begin 03:30:00.481,
background entry .633, lease take .681, release 03:30:01.995, exit .998,
callback complete .999 and native SUCCESS 03:30:02.008 in the full worker log.
The begin/complete/SUCCESS lines are absent from the pre-worker full-log capture.
The worker receipt records forced=true after readiness and elapsed earliest time;
one explicit execution proves neither natural cadence nor cancellation/expiry
correctness. Saved SQLite receipts report bidirectional effects and outbox0;
these were read, not independently replayed. Settings returned painted in the
same PID 5037 according to its saved receipt; this does not erase F-33 or earlier
process-loss failures.

Doctor progress proof records all 27 running/completed duration pairs; the saved
report records 17 PASS / 10 WARN / 0 FAIL. Forced termination and child-timeout
paths were not exercised. Runner notes preserve the initial missing-checkpoint
preparation failure before a corrected retry, singular test-label normalization,
and raw-log whitespace failures separately from successful checks. The first
local evidence reader assumed UTF-8 for a UTF-16 raw log and stopped; rerunning
with BOM-aware decoding verified all three F-33 lines and both ancestry checks.
No failed read is counted as a successful verification.

Decision: security, then users' data. Preserve the frozen candidate and the real
failure instead of suppressing a non-lock transaction error or weakening lease
ownership on temporal evidence. No new runtime/spec/schema/version change or
host migration follows. S1 stays parked, S2 needs a Play account, S10 stays
explicitly deferred. Item Status cells are unchanged. Only integration evidence
notes change in the code and site worktrees; public behavior documentation stays
consistent because behavior is unchanged. Earlier November 6 full gates retain
their recorded scope; no fresh full gates, emulator or iOS acceptance is claimed.
iOS remains experimental and untested. Test-app repositories stayed read-only;
no protected-branch commit/merge, push or publication.

Evidence: read-only valence-test-app-c/ITERATION_129_REPORT.md and
VALENCE_FINDINGS.md; evidence/iteration-129/{f33-current-proof.json,
postrestore-transaction-logcat.txt,evidence-audit.json,settings-outcome.json,
embedded-both-manifests.json,background-state-before-raw.json,
background-state-after-raw.json,worker-execution.json,worker-completion-proof.json,
worker-full-logcat.txt,background-full-log-before.txt,doctor-progress-proof.json,
runner-notes.md}; valence-test-kundalini/VALENCE_FINDINGS.md and
ITERATION_21_REPORT.md. Saved receipts were inspected, not re-executed.

In plain terms: the two requested improvements are rebuilt on current packages.
Lease-acquisition locks remain busy; committed pages remain visible after a later
lock, and cleanup preserves a primary non-lock error and its original stack.
All must-have and original queue items are done. No new feature is claimed.

## Bases and merge order

Code packages: 0fe3391faf2ba25e69ccae3079382be2179be4be. Site packages: 0c468908a7ed412ce13c6b2899efdc50dbd37d6b.
Validated implementation heads: code 85380149a583a57cb0e331f62ead70184068ba73, site b5e2bc1cd43f4a2d95ffd2546827367262c7d534. Later commits
only correct documentation and record these gates; implementation trees remain
identical. The rejected integration b643466 / a3647eb remains preserved at
codex/integration-before-20261106-review in both repositories.

Fresh integrations start from those packages heads. Original queue order is R8,
R7, R6, R3, R4, R5, R9, R10, R14, followed by the already merged later tips and
then the corrected background-lock-result branch. All first 38 tips are already
ancestors of packages, so only the final branch introduces a merge. The assembly
initially repeated historical table rows; those commands were no-ops. The final
assembly deduplicates the list below. The already merged example-revision branch
is excluded, as requested. All 39 exact tips are ancestors in both integrations.
There were no conflicts or competing sync implementations to reconcile.

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
| 10 | codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| 11 | codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| 12 | codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| 13 | codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| 14 | codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| 15 | codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| 16 | codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| 17 | codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| 18 | codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| 19 | codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| 20 | codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| 21 | codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| 22 | codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| 23 | codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| 24 | codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| 25 | codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| 26 | codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| 27 | codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| 28 | codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| 29 | codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| 30 | codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| 31 | codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| 32 | codex/r32 | 3d1fa7f53ed9f61ff12295cb53e7bb4d991813de | cc7831bcbee4f3c63972bcaa8e9a904313eba53f |
| 33 | codex/r33 | ea9e63cf96f1b459672b2e58cf986567f7996c8c | 0e23509e1d98efba98feae7a126ded919cd88daf |
| 34 | codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |
| 35 | codex/pendingids-adoption | 886a9f92a21228c14e33c290796f522accb5f6c3 | 99a8bf76b3d1d32f4080782b0fd8b58f696cd90e |
| 36 | codex/permissions-adoption | 3e7231a3e8d6d842f61ce876ceede20fd69e4d66 | ee4292ce5d60a907457d696abbf318f1c81738cf |
| 37 | codex/dependency-baseline | 700da56f6362ababdbca2f2f65a2a222a9cb8be3 | 6a7bfd5ffb00e476345b2dd9c0c230ea2874072b |
| 38 | codex/cache-adoption | 77853b3964f88d471036bd61340f7c9172057f5f | 04edf8276501f9ec02531aff326389fb6ffc44b7 |
| 39 | codex/background-lock-result | 47c862e350cde63afb305fe558100c78e1722185 | f37c05a6922b3cf0a473ee77ff0422fc4093c5c6 |
| 40 | codex/lease-clock-read | cdecefbfe6bb18481fcdc19d08ff0c6b2e6c02b7 | f311337cee94f56db94c5adc2456ffd9c3be8b6f |

## Decision and review

Security, then users' data: retain packages' acquisition-busy classifier, lease
ownership, renewal, expiry and takeover rules, transaction boundaries, account
and outbox behavior, verification order, atomic activation state, nonce, strict
decoding, navigation locks and release-build dev exclusion. Built-in revision 20,
reserved schemas and package versions do not change. The public pullPair API
stays unchanged; private callbacks account for each committed HTTP page or static
chunk before renewal. Generated code and templates continue to delegate to the
runtime. No host migration is required.

Cleanup preserves the primary non-lock error and its stack. A non-lock cleanup
failure after a primary lock surfaces. Release-only locks retain the completed
outcome, as upstream specifies, and diagnostics cannot throw into recovery.
Earlier authentication/offline outcomes retain their normal precedence. The
existing runtime final-read lock backstop is retained: unreadable progress and
pending counts cannot be recovered by that fallback. This explicitly drops the
rejected candidate's broader final-read propagation policy.

The scoped checklist reviewed changed sync paths and callers, commits before
callbacks, error classification/precedence, account/outbox isolation and the
unchanged security files. No unresolved defect was established in this scoped
self-review; it is not independent improver approval or a fresh security audit.
[Correction and regression details](background-lock-result.md).

## Gates

| Gate | Result | Wall time |
| --- | --- | --- |
| root | Passed | 44.55s |
| core | Passed | 138.86s |
| core-analysis | Passed | 4.47s |
| core-pub | Passed | 5.42s |
| push | Passed | 3.62s |
| push-analysis | Passed | 2.54s |
| push-pub | Passed | 4.57s |
| example | Passed | 4.95s |
| codegen | Passed | 0.08s |
| apk | Passed | 34.77s |
| firebase | Passed | 0.95s |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 37 passed, zero skipped / passed / passed | separate logs |
| Site build and SEO | 50 pages passed | separate log |

Root: 119 passed, zero skips, including generated Dart analysis/execution and
generated strict TypeScript. Core: 647 passed. Push: 2 passed. Example: 29 passed.
Both Dart analyzers report no issues; both pub dry runs report zero warnings
(the push adapter retains its documented local-dependency-override hint).
Example codegen --check passes; the regenerated example TypeScript also passes
strict/verbatim checking against the bridge source through an isolated TEMP config. Debug APK builds, and the standalone Windows py
Firebase audit reports no references in the core graph, manifest and all 19 DEX
files. Native gates run serially; bridge/site gates run independently. The APK
uses only command-local bounded Gradle heap/workers, without changing config.
Bridge and site source trees match their passing earlier gate inputs; subsequent
site changes are notes outside the built content tree.

The first focused command used the wrong working directory, a second found no
matched tests, and the actual baseline regression then failed expected=1 /
actual=0 for an interrupted pair. The first full core pass was followed by one
fatal-info test-style issue; braces were added, and the full native gate chain
was rerun. That run then found inherited example codegen staleness: two link
type re-exports were absent. Regenerated only those exports and repeated the
entire native gate chain. Earlier final-gate logs/results retain that failure
separately from the complete-gate successes. The incomplete fake and unrelated outbox fixture corrections are
recorded in the correction note. No failed attempt is counted as a pass, and no
assertion or timeout was weakened. Logs: TEMP/valence-nov6-review-*.log and
TEMP/valence-nov6-review-complete-gate-*.log. Timings and exits are retained in
TEMP/valence-nov6-review-complete-gate-results.json. Bridge/site logs retain their
separate TEMP/valence-nov6-review-bridge*.log and site.log paths.

## App evidence and limits

Read both VALENCE_FINDINGS.md inventories and latest completed reports:
Kundalini 21 and App C 128. Kundalini reports F-79 source ambiguity and F-80 launch
contention; the current packages contains upstream corrections, while this branch
improves reporting without claiming to solve contention. App C reports scoped
acceptance=true, Settings painted in PID 5500, and one explicitly triggered ready
worker in PID 9090 with native data effects and unchanged activation bytes.
These are app-reported receipts, not a fresh device run of this integration.
Neither one worker nor deterministic fault injection proves natural cadence,
competing-isolate cancellation/expiry correctness or production durability.
Historical reliability findings remain open. S1 stays parked, S2 needs a Play
account, S10 stays deferred. No fresh emulator or iOS acceptance; iOS remains
experimental and untested. Test-app repos stayed read-only. No packages/main
commit or merge, version change, push or publication.

## Historical integration evidence

Earlier sections below retain their original dates and limits; they are not
fresh acceptance of the current candidate.

# Integration with current packages - 2026-11-04

## November 4: iteration 102 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 102, plus the intervening App C 101 report. No eligible must-have or
queue refresh remains. Both integrations contain all 37 current feature tips and
unchanged packages bases 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved iteration-102 audit records 74 passing artifact checks, zero failed
checks and scoped acceptancePassed=true; read, not replayed. Settings returned
painted in the same PID 4982, ordinary launcher after unfinished picker passed,
and Camera/gallery passed this attempt. These successes do not close historical
F-29/F-36/F-40/F-44 or establish a reliability fix. No new Valence defect is
established by this iteration.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
e67d8f43830060149dfd72c1e38ecd164817adbd54baa7b1b36d6fd07dd59a10;
debug 168852021 bytes, SHA256
dd54f5cbb90c70048109aa722c5b917e8b364afa8bdf33ff7cb377f8a0726eb7.
Saved embedded-manifest comparison records builtin seq 1793782671 in both
sequential builds. The stopped backup passed its saved transfer-hash check.
Initial stale preparation/report destinations were corrected before checkpoints;
a PowerShell JSON quoting failure occurred before bridge invocation. Three
initial null-root retained-release captures preceded the successful 42019ms paint
observation; that is neither precise first-paint latency nor a diagnosed cause.
Iteration 101's stale labels/test invocation and initial null-root qualifications
remain separate in its saved runner notes. No runtime fix follows from these.

Matched raw worker log to PID 8287 begin 15:01:13.036, complete 15:01:13.419
and native SUCCESS 15:01:13.431. Saved worker execution records forced=true:
one explicit trigger after timing readiness proves neither natural scheduling nor
cadence. Independently hashed both raw activation files: identical SHA256
a8a5e7277ee7fefa8125ceac72713f8f64aea529f2b4c021c1eff8376606f6fb.
Current 1793783433, pending 1793783446, no trial before foreground. Stable native
SQLite effects, final commit and original-data/photo retention remain saved
receipts, not replayed here. Eleven docs pages and npm tarballs match iteration
101, so F-45 correction adoption remains unverified. Kundalini F-72/F-73/F-74
adoption limits remain open. Retained footprint 581824 KiB / 5733 regular files
is an observation, not evidence of a leak or per-iteration growth.

Decision: preserve security, users' data and the frozen implementation; no runtime
change without a diagnosed fix. S1 remains deliberately parked; S2 needs a Play
account. Existing combined gates retain their recorded scope and date; no fresh
full gates, security review or emulator acceptance claimed. Only matching
integration notes changed. iOS remains experimental and untested. Sources:
read-only app findings, ITERATION_18_REPORT.md, ITERATION_101_REPORT.md,
ITERATION_102_REPORT.md and app-c/evidence/iteration-102/. No test-app writes,
protected-branch changes, schema/version changes, push or publication. Roadmap
status cells are unchanged.

## November 4: iteration 100 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 100. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved audit records 74 passing artifact checks, zero failed checks and
scoped acceptancePassed=true; read, not replayed. Settings returned painted in
PID 4767, ordinary launch after unfinished picker passed, and Camera/gallery
passed this attempt. These successes do not close historical F-29/F-36/F-40/F-44
or establish a fix. No new Valence defect is established by this iteration.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
aee39212b248a2c1a98670e8a5759967909ce5ebc0bc931de1e83f56b3002c53;
debug 168852021 bytes, SHA256
dd5e041ae4a0264da469163e12758aa4d044a9c24a6f03590b28082ce15d4ddd.
Saved manifest comparison records built-in seq 1793778988 in both sequential
builds. The stopped backup completed within its configured bound and passed
transfer-hash verification. Unsupported CLI upgrade was corrected to documented
update; omitted backup/verifier helpers were supplied before use. Independent
app-integration review found a stale widget cursor and report title in the runner;
both were corrected before the audit. Initial null-root UI capture was excluded
from the later bounded paint observation. These establish no Valence defect.

Matched raw worker log to PID 7459 begin 13:59:34.240, complete 13:59:35.548
and native SUCCESS 13:59:35.556. The saved observer records forced=true: one
explicitly triggered execution proves neither natural scheduling nor cadence.
Independently hashed both raw activation files: identical SHA256
b3368864e9a22e020d1d1e063dd694de56abb7c4320b9ccff30c9dee7b61b3d3.
Current 1793779663, pending 1793779672, no trial before foreground. Stable native
SQLite effects, final commit and original-data/photo retention remain saved
receipts, not replayed here. Eleven docs pages and npm tarballs match iteration
99, so F-45 correction adoption remains unverified. Kundalini F-72/F-73/F-74
adoption limits remain open. Retained footprint (570236 KiB / 5618 files) does
not establish a leak or per-iteration growth.

Decision: preserve security, users' data and the frozen implementation; no runtime
change without a diagnosed fix. S1 stays deliberately parked; S2 needs a Play
account. Existing combined gates retain their recorded scope and date; no fresh
full gates, security review or emulator acceptance claimed. Only matching
integration notes changed. iOS remains experimental and untested. Sources:
read-only app findings, ITERATION_18_REPORT.md, ITERATION_100_REPORT.md and
app-c/evidence/iteration-100/. No test-app writes, protected-branch changes,
schema/version changes, push or publication. Roadmap status cells are unchanged.

## November 4: iteration 99 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 99. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved audit records 74 passing artifact checks, zero failed checks and
scoped acceptancePassed=true; read, not replayed. Settings returned painted in
PID 5248, ordinary launch after unfinished picker passed, and Camera/gallery
passed this attempt. These successes do not close historical F-29/F-36/F-40/F-44
or establish a fix. No new Valence defect is established by this iteration.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
519afb3b0d5c79e58b776815a16bc7d85b45a94be6a5c5cd99e11fba7a3ba443;
debug 168852021 bytes, SHA256
c863cc1e566a47c66be94685cdf280ea979de42c01d196317e586e0f78bb19c5.
Saved manifest comparison records built-in seq 1793777185 in both sequential
builds. The initial stopped-backup transfer timed out; its partial archive was
excluded and a longer bounded retry was accepted before fresh-install testing.
The missing optional preparation script reference was corrected before device
phases. These runner qualifications establish no Valence defect.

Matched raw worker log to PID 8114 begin 13:29:44.692, complete 13:29:46.183
and native SUCCESS 13:29:46.191. The saved observer records forced=true: one
explicitly triggered execution proves neither natural scheduling nor cadence.
Independently hashed both raw activation files: identical SHA256
27fd305075ffae9e12387c2b2a564ea2ec04f733460d8dca73f87f64cad31239.
Current 1793777888, pending 1793777897, no trial before foreground. Stable native
SQLite effects, final commit and original-data/photo retention remain saved
receipts, not replayed here. Eleven docs pages and npm tarballs match iteration
98, so F-45 correction adoption remains unverified. Kundalini F-72/F-73/F-74
adoption limits remain open. Retained storage metadata (562572 KiB / 5546 files)
is an observation, not proof of a leak or per-iteration growth.

Decision: preserve security, users' data and the frozen implementation; no runtime
change without a diagnosed fix. S1 stays deliberately parked; S2 needs a Play
account. Existing combined gates retain their recorded scope and date; no fresh
full gates, security review or emulator acceptance claimed. Only matching
integration notes changed. iOS remains experimental and untested. Sources:
read-only app findings, ITERATION_18_REPORT.md, ITERATION_99_REPORT.md and
app-c/evidence/iteration-99/. No test-app writes, protected-branch changes,
schema/version changes, push or publication. Roadmap status cells are unchanged.

## November 4: iteration 98 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 98. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved audit records 74 passing artifact checks, zero failed checks and
scoped acceptancePassed=true; read, not replayed. Settings returned painted in
PID 5008, and ordinary launch after unfinished picker passed this attempt.
Camera/gallery passed this attempt. These successes do not reverse iteration
97 or close historical F-29/F-36/F-40/F-44. No new Valence defect or runtime
cause is established by this iteration.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
fcc51a5ccea82affaaab010facb5b10d6f7ad7db5ab56f414075941db9683dd2;
debug 168852021 bytes, SHA256
8d61de8ecd9b4f69add048134a696f7df4d7846ff57970579b736bd3d7d26af4.
Saved manifest comparison records built-in seq 1793775475 in both final builds.
The initial release build overlapped signed-builtin staging and is excluded;
the sequential rebuild and manifest verification are separate receipts.

Matched raw worker log to PID 7854 begin 13:00:51.354, complete 13:00:52.553
and native SUCCESS 13:00:52.563. Trigger qualification explicitly records
jobscheduler -f and timingBypassed=true: one forced registered execution proves
neither natural scheduling nor cadence. Independently hashed both raw activation
files: identical SHA256
1e02b71d213746a301e3762452338c66943cc40138eebaeb5875f15ec029fdcf.
Current 1793776163, pending 1793776172, no trial before foreground. Stable native
SQLite effects, final commit and original-data/photo retention remain saved
receipts, not replayed here. Stale archive/verifier inputs were corrected before
execution; the offline probe's older label is qualified by its current replies.
Eleven docs pages and tarballs match iteration 97, so F-45 correction adoption
remains unverified. Kundalini F-72/F-73/F-74 adoption limits remain open.

Decision: preserve security, users' data and the frozen implementation; do not
alter runtime behavior without a diagnosed fix. S1 stays deliberately parked;
S2 needs a Play account. Existing combined gates retain their recorded scope and
date; no fresh full gates, security review or emulator acceptance claimed. This
change updates only matching integration notes. iOS remains experimental and
untested. Sources: read-only app findings, ITERATION_18_REPORT.md,
ITERATION_98_REPORT.md and app-c/evidence/iteration-98/. No test-app writes,
protected-branch changes, schema/version changes, push or publication. Roadmap
status cells are unchanged.

## November 4: iteration 97 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 97. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved audit records 78 passing artifact checks, zero failed checks and
scoped acceptancePassed=false: external Camera ANR F-40 recurred. Raw lastanr
names com.android.camera2 CaptureActivity and a 5001ms input dispatch timeout.
Separate successful recovery does not erase the failed attempt or establish a
Valence cause. Initial retained-release accessibility observations were blocked
by a System UI dialog; Wait and relaunch recovery remain separate. These
observations do not establish a host ANR or exact first-paint timing. Settings
returned painted in the same PID 5232 and ordinary picker launch passed this
attempt; historical F-29/F-36/F-44 remain open.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
f58af9375d8567872605e2e44ad0b09271293aa89d83ab1ddaccd31a18657b76;
debug 168852021 bytes, SHA256
95ffb559b7a3fa1655604ab7edbb7f1859325bda9a7be14fc7e1c56a0ce50829.
Saved manifest comparison records built-in seq 1793771934 in both sequential
builds. Matched raw worker log to PID 8446 begin 12:04:35.643, complete
12:04:36.913 and native SUCCESS 12:04:36.922. The saved observer records
forced=true: one explicitly triggered execution proves no natural scheduling
or cadence.

Independently hashed both raw activation files: identical SHA256
0fc8beb2c961d216d110292a1acaf03bb70e209b68e5327ec99f656d08a43845.
Current 1793772927, pending 1793772937, no trial before foreground. Initial
worker verification opened iteration 96's database and failed; corrected
capture before foreground records stable native SQLite, exact outgoing objects,
incoming rows and outbox 0. The initial failure and resumed cleanup remain
separate. Final commit and original-data/photo retention remain saved receipts,
not replayed here. Eleven docs pages and tarballs match iteration 96; F-45
correction adoption remains unverified. Kundalini F-72/F-73/F-74 adoption limits
remain open.

Decision: preserve security, users' data and the frozen implementation; do not
alter runtime behavior without a diagnosed fix. S1 stays deliberately parked;
S2 needs a Play account. Existing combined gates retain their recorded scope and
date; no fresh full gates, security review or emulator acceptance claimed. This
change updates only matching integration notes. iOS remains experimental and
untested. Sources: read-only app findings, ITERATION_18_REPORT.md,
ITERATION_97_REPORT.md and app-c/evidence/iteration-97/. No test-app writes,
protected-branch changes, schema/version changes, push or publication. Roadmap
status cells are unchanged.

## November 4: iteration 96 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 96. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved audit records 74 passing artifact checks, zero failed checks and
scoped acceptancePassed=true; read, not replayed. Settings returned painted in
the same PID 5661, and ordinary launch after unfinished picker passed this
attempt. These successes do not reverse iteration 95 or close historical
F-29/F-36/F-44. No Valence leak or database-lock owner is established.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
33e517c00e28fe20a11bcdb9b00b234b60f4aa8ab8135c507d459c4df639e311;
debug 168852021 bytes, SHA256
91abc68558f09714452248a7bc3935a3e2307a63a8d1d6ad833f9a30b2dc83ca.
Saved manifest comparison records built-in seq 1793770100 in both sequential
builds. Matched raw worker log to PID 8626 begin 11:31:30.099, complete
11:31:31.675 and native SUCCESS 11:31:31.688. Trigger qualification records
explicitlyTriggered=true and timingBypassed=true: one forced registered job
execution proves neither natural scheduling nor cadence.

Independently hashed both raw activation files: identical SHA256
25c335f8fc59df9d20e1dc4f4cebf0629adf5896eb659760c43e48fd56bccb87.
Current 1793770879, pending 1793770888, no trial before foreground. Stable native
SQLite effects, final commit and original-data/photo retention remain saved
receipts, not replayed here. Initial cold-link/widget runner overlap is retained
and excluded from sequential acceptance; serial repeats are recorded separately.
The first post-restore busy/pending0 reply is not a transfer-completion receipt.
Eleven docs pages and tarballs match iteration 95; F-45 correction adoption
remains unverified. Kundalini F-72/F-73/F-74 adoption limits remain open.

Decision: preserve security, users' data and the frozen implementation; do not
alter runtime behavior without a diagnosed fix. S1 stays deliberately parked;
S2 needs a Play account. Existing combined gates retain their recorded scope and
date; no fresh full gates, security review or emulator acceptance claimed. This
change updates only matching integration notes. iOS remains experimental and
untested. Sources: read-only app findings, ITERATION_18_REPORT.md,
ITERATION_96_REPORT.md and app-c/evidence/iteration-96/. No test-app writes,
protected-branch changes, schema/version changes, push or publication. Roadmap
status cells are unchanged.

## November 4: iteration 95 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 95. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved audit records 74 passing artifact checks, zero failed checks and
acceptancePassed=false. Raw Settings log records renderer 5635 killed for the
low-memory watermark at 09:15:26.784; Chromium host 5558 terminates itself at
09:15:26.845. Exit-info corroborates renderer LOW_MEMORY and host SIGNALED/status
9. Replacement PID 6589 was blank before ordinary relaunch recovery. F-36 remains
open; no Valence leak, database-lock owner or healthy-trial-loss cause is
established. Ordinary launch after unfinished picker passed this attempt.

Initial OTA automation exited 1 after 585320 ms amid a host-clock discontinuity.
Saved activation retained trial 1793763413 with one failure and current
1793763404. State, logs and paired clocks were captured before resuming that
trial. The resumed two-strike rollback is separate from the interrupted attempt;
neither the timeout cause nor suspension duration is established.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
57ceafd3f595ba652685ffc46f51d2bc44979893cccb7aef27f5208bf90da9c7;
debug 168852021 bytes, SHA256
bb1e3a62c48e3006644b157570b5b36efdb7e104e7357c5f4e12ffff1026dcca.
Saved manifest comparison records built-in seq 1793762741 in both sequential
builds. Matched raw worker log to PID 8757 begin 10:35:26.041, complete
10:35:27.563 and native SUCCESS 10:35:27.571. One registered job explicitly
triggered after timing readiness establishes no natural cadence.

Independently hashed both raw activation files: 1158 bytes, identical SHA256
d7e6af3ed092c5441d494cbf1ce11556123b08edc9741dc3a73bffa5a2cb6451.
Current 1793766940, pending 1793766950, no trial before foreground. Stable native
SQLite effects, final commit and original-data/photo retention remain saved
receipts, not replayed here. Eleven docs pages and tarballs match iteration 94;
F-45 correction adoption remains unverified. Historical findings, including
F-29/F-36/F-44 and Kundalini F-72/F-73/F-74 adoption limits, remain open.

Decision: preserve security, users' data and the frozen implementation; do not
alter runtime behavior without a diagnosed fix. S1 stays deliberately parked;
S2 needs a Play account. Existing combined gates retain their recorded scope and
date; no fresh full gates, security review or emulator acceptance claimed. iOS
remains experimental and untested. Sources: read-only app findings,
ITERATION_18_REPORT.md, ITERATION_95_REPORT.md and app-c/evidence/iteration-95/.
No test-app writes, protected-branch changes, schema/version changes, push or
publication. Roadmap status cells are unchanged.

## November 4: iteration 94 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 94. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved artifact audit records 72 passing checks, zero failed checks and
acceptancePassed=false. F-36 recurred: raw Settings log records renderer 7004
killed for the low-memory watermark at 08:16:37.212, followed by Chromium host
6930 terminating itself at 08:16:37.259. Exit-info records host SIGNALED/status 9
at 08:16:37.347. Replacement PID 7715 was blank; the pre-relaunch CDP socket
closed. Ordinary relaunch recovery does not erase that failure. No Valence leak,
database-lock owner or healthy-trial-loss cause is established. No native SQLite
snapshot or paired-clock receipt was captured before recovery for this specific
interruption; preinstall backup and final retention receipts are separate.
Ordinary launch after the unfinished picker passed this attempt; historical
F-29/F-36/F-44 and other findings remain open.

Independently rehashed the archived APKs: release 54711308 bytes, SHA256
1a6b12fb7c3637af866fbb25485c3c575a4dc04b58a300377a1d83a079f5e642;
debug 168852021 bytes, SHA256
4e1056faf3e7e1aabf00ac1c457918639c8692fa7e5587ab2568afe3641ac4fc.
Saved manifest comparison records both embedding built-in seq 1793759159 after
sequential builds. Initial fresh-offline screenshot overlapped restore and is
excluded; repeated sequential checks remain separate. Preserve the failed
Python Store-alias invocation and subsequent explicit-interpreter verification.

Matched raw worker-full-logcat.txt against the completion receipt: PID 9701 begin
08:31:34.258, complete 08:31:35.724, native SUCCESS 08:31:35.731. One registered
job explicitly triggered after timing readiness proves no natural cadence.
Stable native SQLite effects remain saved receipts, not replayed here.
Independently hashed both raw activation files: 1147 bytes, identical SHA256
8e7f1427cc0b1a227e8d4f4b325dff5010e1d850aca2a05dda17a1d38c028478.
Current 1793759950, pending 1793759959, no trial before foreground. Final commit
and original-data/photo retention remain saved receipts. Eleven local docs pages
and tarballs still match iteration 93, so F-45 correction adoption remains
unverified. Saved doctor is 14 PASS / 10 WARN / 0 FAIL. Retained-history footprint
530196 KiB / 5228 files establishes no leak or growth rate. Kundalini
F-72/F-73/F-74 adoption limits remain.

Decision: preserve security, users' data and the frozen implementation; retain
failed automatic recovery separately from successful explicit relaunch rather
than changing runtime behavior without a diagnosed fix. S1 stays deliberately
parked and S2 needs a Play account. This evidence-only update retains existing
combined gates' recorded scope and date; no fresh full gates, security review or
emulator acceptance claimed. iOS remains experimental and untested. Sources:
read-only app findings, ITERATION_18_REPORT.md, ITERATION_94_REPORT.md and
app-c/evidence/iteration-94/. No test-app writes, protected-branch changes,
schema/version changes, push or publication. Roadmap status cells are unchanged.

## November 4: iteration 93 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 93. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved artifact audit records 74 passing checks, zero failed checks and
acceptancePassed=false: F-29 recurred in the final refreshed-debug offline smoke.
The initial ordinary launch reported Activity not started; readiness found no
App C PID. Preserved activities show PhotoPicker MainActivity in task 1222 rooted
in Fieldnote, with resultTo a removed Fieldnote activity. The activity capture
followed cleanup, so postfailure process absence alone is not precleanup proof;
the original nested readiness errors are the separate evidence. Explicit Android
BACK dismissal followed by a painted offline retry does not erase the launch
failure or establish a Valence runtime cause. Settings returned painted in PID
4879. Historical F-36/F-44 and the other findings remain open.

Preserve the runner's packaging qualification: detailed native tests used the
archived debug host with prior built-in seq 1793755526. Sequential debug refresh
aligned its built-in with release seq 1793757403; the saved ZIP comparison reports
only manifest/signature changes. The original tested artifact remains archived,
and the recovered final smoke is distinct from those detailed tests.

Independently rehashed the final archived APKs: release 54711308 bytes, SHA256
80005e3fa15cade066f504f658daaffa7de3b91b18beffe4b5dac6167a1af513;
debug 168852021 bytes, SHA256
ba05a7ff41b6175913499228a743d367aa0d3220bbb119c401df471e0afdf30e.
Matched raw worker-full-logcat.txt against the completion receipt: PID 7260 begin
07:59:20.453, complete 07:59:21.763, native SUCCESS 07:59:21.771. The report records
one explicit trigger after timing readiness; one execution does not prove cadence.
Stable SQLite effects remain saved receipts, not replayed here.

Independently hashed both raw activation files: 1136 bytes, identical SHA256
9144460f5130fee3b5600513ee0f67a0c4ac188f7ef2b02c653e686fc8e07d1f.
Current 1793757977, pending 1793757987, no trial before foreground. Final
commitment and original-data/photo retention remain saved receipts. Eleven local
docs pages and tarballs still match iteration 92, so F-45 correction adoption
remains unverified. Saved doctor is 14 PASS / 10 WARN / 0 FAIL. Retained-history
footprint 522304 KiB / 5154 files establishes no leak or growth rate. Kundalini
F-72/F-73/F-74 adoption limits remain.

Decision: preserve security, users' data and the frozen implementation; retain
the failed launch and recovery separately rather than changing runtime behavior
without a diagnosed cause. S1 stays deliberately parked and S2 needs a Play
account. This evidence-only update retains existing combined gates' recorded
scope and date; no fresh full gates, security review or emulator acceptance
claimed. iOS remains experimental and untested. Sources: read-only app findings,
ITERATION_18_REPORT.md, ITERATION_93_REPORT.md and app-c/evidence/iteration-93/.
No test-app writes, protected-branch changes, schema/version changes, push or
publication. Roadmap status cells are unchanged.

## November 4: iteration 92 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 92. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.

The saved artifact audit records 71 passing checks, zero failed checks and
acceptancePassed=false: F-40 recurred in the external Android Camera. Native
lastanr identifies com.android.camera2/com.android.camera.CaptureActivity and
an input-dispatch timeout. Settings returned painted in the same host PID 4732;
the saved report records that this host survived the camera interruption too.
Recovered media checks do not erase the initial failure or establish a Valence
cause. Historical F-36/F-44 and other findings remain open. Preserve the initial
rootless camera UI dump separately from the later ANR and recovery. Preparation
Python-alias and readiness-environment mistakes remain runner qualifications.

Independently rehashed the archived APKs: release 54711308 bytes, SHA256
cfee8d210aad9edfe800f410c6cff83887ecda0acb8679b645b9586afa63c2cc;
debug 168852021 bytes, SHA256
c1401931a17cbde1ee46d35b99756dc88cfb605bcd7538f3a8f0d7e882e5f8cb.
Matched worker receipt lines against raw worker-full-logcat.txt: PID 7482 begin
07:29:12.978, complete 07:29:14.129, native SUCCESS 07:29:14.138. The observer
records forced=false and no explicit trigger: one naturally observed registered
execution, with no cadence claim. Stable SQLite effects remain saved receipts.

Independently hashed both raw activation files: 1125 bytes, identical SHA256
4e0a8025274a1ea204a4dea1b77d52dd2a2b7ec67f2624072843b6e24065373c.
Current 1793756288, pending 1793756297, no trial before foreground. Final
commitment and retained original data/photo are saved receipts, not rerun here.
Eleven fetched docs pages and tarballs still match iteration 91; adoption of the
integrated F-45 correction remains unverified. Saved doctor is 14 PASS / 10 WARN /
0 FAIL. Retained-history footprint 517516 KiB / 5104 files establishes no leak or
growth rate. Kundalini F-72/F-73/F-74 adoption limits remain.

Decision: preserve security, users' data and the frozen implementation; an
external-camera failure without a Valence cause does not justify a runtime
patch. S1 stays deliberately parked and S2 needs a Play account. This is an
evidence-only update: existing combined gates retain their recorded scope and
date; no fresh full gates, security review or emulator acceptance claimed.
iOS remains experimental and untested. Sources: read-only app findings,
ITERATION_18_REPORT.md, ITERATION_92_REPORT.md and app-c/evidence/iteration-92/.
No test-app writes, protected-branch changes, schema/version changes, push or
publication. Roadmap status cells are unchanged.

## November 4: iteration 91 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 91. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.
Existing combined implementation gates retain their recorded scope and date.

App C's saved artifact audit records 70 passing checks, zero failures and scoped
acceptancePassed=true; read, not replayed. Retained/rebuilt offline and reconnect
passed. Settings receipt records same PID 4801, painted=true. This does not close
historical F-36/F-44 or establish their cause. Current runner qualifications
preserve the corrected setup import, unsupported upgrade invocation followed by
documented update, early WebView read and initially rootless UI dump. Later
bounded observations are separate. The preparation helper was corrected after
setup and not rerun over current evidence; inherited iteration-90 fixture labels
do not override current IDs, timestamps and receipts.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
c59f1b1f4e61eb4f55b87aa5e5df9aeafb909d0992812c1c016f9218a96c5df8;
debug 168852021 bytes, SHA256
fec94ee988356f201920071802754a399c408c6e89a4ebb5934b35cf9dcc4cfb.
Matched all three receipt lines against raw worker-full-logcat.txt: PID 7302
callback begin 06:59:43.669, complete 06:59:44.859, native SUCCESS 06:59:44.868.
Runner records an explicit jobscheduler -f trigger after Ready:true and elapsed
earliest timing. This supports one registered execution, not natural cadence.
Saved stable SQLite receipts show outbox 2/incoming absent before isolation and
matching outgoing/incoming effects/outbox 0 before foreground.

Independently hashed both raw activation files: 1114 bytes, identical SHA256
5c34c24af8c79df8c4e059f1b5278751935ff20bbfdf1b6337ad82739a0642f8.
Current 1793754408, pending 1793754418, no trial. Final commitment, original
data/photo retention and cleanup remain saved receipts. Saved doctor reports
14 PASS / 10 WARN / 0 FAIL; not rerun here. Eleven fetched docs pages and npm
tarballs still match iteration 90, so adoption of the integrated F-45 correction
remains unverified. Retained-history footprint 509880 KiB / 5031 files is not
evidence of a leak or growth rate. Kundalini F-72/F-73/F-74 adoption limits remain.

Decision: preserve security, users' data and the frozen implementation; no
speculative lease weakening, discarded writes or late native shim. S1 stays
deliberately parked; S2 needs a Play account. No fresh full gates, runtime
security review or emulator acceptance claimed for this evidence-only update.
iOS remains experimental and untested. Sources: read-only app findings,
ITERATION_18_REPORT.md, ITERATION_91_REPORT.md and app-c/evidence/iteration-91/.
No test-app writes, protected-branch changes, schema/version changes, push or
publication. Roadmap status cells are unchanged.

## November 4: iteration 90 evidence review

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 90. No eligible must-have or queue refresh remains. Both integrations
contain all 37 current feature tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Ancestry was checked this run.
Implementation and existing gate results retain their recorded scope and date.

App C's saved audit records 70 passing artifact checks and scoped
acceptancePassed=true; read, not replayed. Retained/rebuilt offline and reconnect
passed. Settings receipt records same PID 4746, painted=true. This does not close
historical F-36/F-44 or establish their cause. Current runner notes explicitly
exclude inherited backup-basename and black-permission-image qualifications:
the current restore uses iteration90, and current permission images were inspected
by the app runner. No live device verification was performed here.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
8842bf62b5aa27472a66849fe6ea12fba0670a759a3e45d7d27300d01d66ba96;
debug 168852021 bytes, SHA256
f53f99fcdedca9f98afad8d3d49bca17934e98b837570d1abe5487b12f7958ab.
Matched all three receipt lines in raw worker-full-logcat.txt: PID 7313 callback
begin 06:29:03.575, complete 06:29:04.747, native SUCCESS 06:29:04.756.
Runner records an explicit jobscheduler -f trigger after Ready:true and elapsed
earliest timing. This supports one registered execution, not natural cadence.
Saved stable SQLite receipts show outbox 2/incoming absent before isolation and
matching outgoing/incoming effects/outbox 0 before foreground.

Independently hashed both raw activation files: 1103 bytes, identical SHA256
d5f969b1477900b582b3f4610574a21097785a77c29c751e7b00275840a3862f.
Current 1793752572, pending 1793752581, no trial. Final commitment, original
data/photo retention and cleanup remain saved receipts. Saved doctor reports
14 PASS / 10 WARN / 0 FAIL; not rerun here. Eleven fetched docs pages and npm
tarballs still match iteration 89; adoption of the integrated F-45 correction
remains unverified. Retained-history footprint 503316 KiB / 4967 files is not
evidence of a leak or growth rate. Kundalini F-72/F-73/F-74 adoption limits remain.

Decision: preserve security, users' data and the frozen implementation; no
speculative lease weakening, discarded writes or late native shim. S1 stays
deliberately parked; S2 needs a Play account. No fresh full gates, runtime
security review or emulator acceptance claimed for this evidence-only update.
iOS remains experimental and untested. Sources: read-only app findings,
ITERATION_18_REPORT.md, ITERATION_90_REPORT.md and app-c/evidence/iteration-90/.
No test-app writes, protected-branch changes, schema/version changes, push or
publication. Roadmap status cells are unchanged.

## November 4: iteration 89 proves one scheduled-ready worker execution

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 89. No eligible must-have or queue refresh remains. Verified that
both integrations include all 37 current recorded branch tips and packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Existing integration gates retain
their recorded scope and date; this update changes evidence notes only.

The saved artifact audit has 70 passing checks and scoped acceptancePassed=true;
it was read, not replayed. Retained/rebuilt offline and reconnect passed. Saved
Settings outcome records same PID 5231 and painted=true. This successful attempt
does not reverse iteration 87's failure or close historical F-36/F-44 findings.
Initial runner backup-basename errors remain preserved separately: the initial
restore stopped before extraction, and corrected restore receipts are the basis
for the current result. Black permission-grant PNG is excluded; native XML and
typed result carry that assertion.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
8f5a08475c06c1e4976c4f5506440e1783c1ecaa973e6f1603828305c8db40c7;
debug 168852021 bytes, SHA256
904fe733777ac42023cf48b6c8e3e2256869132eae32b4b28b675ac810baa6c7.
Matched all three worker receipt lines against the raw log: PID 7814 callback
begin 06:01:47.896, complete 06:01:49.244, native SUCCESS 06:01:49.256.
The early forced request was explicitly deferred by WorkManager, with no callback.
A later scheduler snapshot reported Ready:true and elapsed earliest timing, then
a second explicit jobscheduler -f request preceded success. That supports one
explicitly triggered registered execution after timing readiness, not natural
execution or periodic cadence. Saved stable SQLite receipts report outbox 2 and
incoming fixture absent before isolation, exact outgoing/incoming effects and
outbox 0 before foreground. Independently hashed both raw activation files:
1092 bytes, SHA256
11518da1547fd58a54d4029527da894cf2a76f4489b97f216c7b90afc02d34c5.
They are byte-identical: current 1793750802, pending 1793750811, no trial.
Final commitment of 1793750811, retained original data/photo and cleanup are saved
receipts, not live device verification here. Saved doctor reports 14 PASS /
10 WARN / 0 FAIL; not rerun here.

Eleven fetched docs pages and npm tarballs still match iteration 88, so adoption
of the integrated F-45 correction remains unverified. Retain F-41/F-43/F-45
qualifications and Kundalini F-72/F-73/F-74 adoption limits. Read-only retained
footprint 497200 KiB / 4907 files measures history, not a leak or growth rate.

Decision: preserve security, users' data and the frozen implementation; no lease
weakening, discarded writes or late native recovery shim on unproven causation.
S1 stays deliberately parked; S2 needs a Play account. No fresh full gates,
emulator acceptance or runtime security review claimed. iOS remains experimental
and untested. Sources: read-only app findings, ITERATION_18_REPORT.md,
ITERATION_89_REPORT.md and app-c/evidence/iteration-89/. No test-app writes,
protected-branch changes, schema/version changes, push or publication. Roadmap
status cells are unchanged.

## November 4: iteration 88 distinguishes transport interruption from app survival

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / App C 88. No eligible must-have or queue refresh remains. Both integrations
contain all 37 exact current recorded branch tips and unchanged packages bases
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Verified ancestry again this run.
Existing integration gates below retain their recorded scope and date.

The saved artifact audit has 71 passing checks and scoped acceptancePassed=true;
it was read, not replayed. Initial Settings capture failed to connect to the local
ADB daemon (10060). Missing image/page evidence makes that attempt inconclusive,
not proof of F-36 recurrence. The initial classifier's failed-survival label is
preserved and excluded; the separate Settings-only retry records same PID 4722
and painted=true. The basic-native continuation must be read together with the
original permission/offline receipts and separate Settings retry. No account or
database reset or emulator restart was used for that recovery. A successful
retry does not reverse iteration 87's failure or close historical findings.
Retained/rebuilt offline and reconnect passed; F-44 remains open.

Independently rehashed archived APKs: release 54711308 bytes, SHA256
54bf5e370af6bb1e8c13cae91edb2e10bd03f9a7d77d45a57367a6fa3b83f67b;
debug 168852021 bytes, SHA256
4f16eb126fa7f941a451a2bb6562444a47a5866a12dd0fecbda51e7fb8f8a9ff.
Matched raw worker log to PID 7345: callback begin 05:28:49.051, complete
05:28:50.335, native SUCCESS 05:28:50.346. Observation receipt records
forced=false. This supports one naturally observed registered execution, not a
cadence guarantee. Saved stable SQLite receipts report outbox 2/incoming absent
before isolation, exact outgoing/incoming effects and outbox 0 before foreground.
Independently hashed both raw activation files: 1081 bytes, SHA256
6e9a96e6c5334c80c6b340945d5ed2d697967fabb3256e9ff5a10ec589c69d8e.
They are byte-identical: current 1793749104, pending 1793749113, no trial.
Final commitment of 1793749113, original-data/photo retention and cleanup remain
saved receipts, not live device verification here. Saved doctor reports
14 PASS / 10 WARN / 0 FAIL with exit 0; not rerun here.

The eleven locally fetched docs pages and npm tarballs still match iteration 87;
F-45's correction is integrated but its adoption is not yet established. Retain
F-41/F-43/F-45 qualifications, historical reliability findings and Kundalini's
F-72/F-73/F-74 adoption limits. Read-only footprint 491076 KiB / 4848 files measures
retained history, not a leak or per-iteration growth. The exploratory widget-seven
image shows the first launcher page; the separate widget-sync receipts carry the
placed-count proof. No broader device acceptance or iOS verification inferred.

Decision: preserve security, users' data and the frozen implementation candidate;
no speculative lease weakening, data deletion or late native recovery shim.
S1 stays deliberately parked; S2 needs a Play account. Implementation and schema
are unchanged. No fresh full gates were necessary for this evidence-only note;
no new runtime security review or emulator acceptance claimed. Sources: read-only
app findings, ITERATION_18_REPORT.md, ITERATION_88_REPORT.md and
app-c/evidence/iteration-88/. No test-app writes, protected-branch changes,
schema/version changes, push or publication. Roadmap status cells are unchanged.

## November 4: F-45 dependency guidance corrected; iteration 87 acceptance failed

In plain terms: read both findings inventories and newest reports, Kundalini 18
and App C 87. No eligible must-have or queue refresh remains. App C's new F-45
is a documentation defect: two competing section-6 dependency rows and a blank
line splitting the copied skill's table. Removed the stale duplicate, retained
the existing compatibility guidance and clarified the site's notification guide.
The scoped docs-scout evidence and branch gates are in dependency-baseline.md.
No new dependency recommendation, package pin or runtime behavior was introduced.
The app must refresh tooling before it can verify this correction.

### Assembly and decision

Packages bases remain code 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 and site
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Verified both bases and all 37 current
exact branch tips as integration ancestors. The existing 36-tip assembly and its
recorded merge order are retained; appended the documentation-only follow-up:

| Merge order | Code | Site |
| --- | --- | --- |
| Existing integration predecessor | ae2b55bd6d705d59b89492cd592d0f7dfeea3101 | f9de30456cdf431a24517501c6897dfa297aac25 |
| codex/dependency-baseline | 700da56f6362ababdbca2f2f65a2a222a9cb8be3 | 6a7bfd5ffb00e476345b2dd9c0c230ea2874072b |
| Gated integration merge | 19b179effe6d729e80f17b913bc94e6ff98786b0 | 0c32543d081088605485d882be2a5d874e9e6f11 |

Decision: correct contradictory instructions without disturbing working pins,
security boundaries, users' data or shipped schemas. Runtime, spec, codegen and
templates still match candidate 7385f4e / 1539b66. Only documentation differs.
S1 stays deliberately parked; S2 needs a Play account. No security path changed,
so no new runtime security review is claimed. iOS remains experimental/untested.

### Fresh combined gates - 2026-11-04

| Gate | Result on the integration merge above |
| --- | --- |
| Root npm test | 115 passed, no failures/skips; generated Dart and strict/verbatim TS ran |
| Core tests / fatal-info analysis / pub dry run | 617 passed / no issues / zero warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / no issues / zero warnings, one local-override hint |
| Example tests / debug APK | 29 passed / built in 30.0 seconds; existing Kotlin plugin warning |
| Standalone Windows py Firebase audit | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |
| Bridge tests / strict-verbatim TypeScript / npm pack dry run | 36 passed / passed / passed |
| Root npm pack dry run | Passed |
| Site build and SEO | 50 pages OK |
| Baseline and diff inspection | One section-6 row, continuous Markdown table; diff hygiene passed |

Logs: %TEMP%/valence-baseline-integration-*.log. Branch-only gates in
[dependency-baseline.md](dependency-baseline.md) have their own counts and scope.
No assertions or timeouts were weakened. Final ledger commits change only notes.

### Saved app evidence and limits

App C's saved audit records 69 passing artifact checks but acceptancePassed=false.
Raw Settings log corroborates lowmemorykiller killing renderer 6475 at
04:15:52.239 and host 6188 at 04:15:52.274. The saved outcome records replacement
7962 blank before explicit relaunch recovery. This is a survival failure despite
later recovered checks; no package-level memory cause is established. F-36 stays
open. Retained/rebuilt offline and reconnect passed without process recovery;
absence of a current F-44 recurrence does not close the historical failure or
identify its owner/cancellation cause. No speculative lease or data-reset fix.

Independently rehashed both archived APKs: release 54711308 bytes, SHA256
54bf5e370af6bb1e8c13cae91edb2e10bd03f9a7d77d45a57367a6fa3b83f67b;
debug 168852021 bytes, SHA256
4f16eb126fa7f941a451a2bb6562444a47a5866a12dd0fecbda51e7fb8f8a9ff.
Matched raw worker log to PID 10019: callback begin 04:30:24.001, complete
04:30:25.040, native SUCCESS 04:30:25.050. Receipt records forced=true;
runner says readiness/earliest time were observed before the explicit -f trigger.
This proves one execution, not natural cadence. Independently hashed activation
bytes remain equal, SHA256
659632bf72a611644ac2e536e000f8cc6b6833b9056e3f0b1474515a11f3e5da:
current 1793745454, pending 1793745463, no trial before foreground. Saved native
SQLite receipts report outbox 2/incoming absent before isolation and matching
transfers/outbox 0 before foreground. Final commitment, retention and cleanup are
saved receipts, not live device verification here. Saved doctor: 14 PASS, 10 WARN,
0 FAIL; not rerun here. Read-only footprint 484960 KiB / 4788 files measures
retained history, not a leak or per-iteration growth; F-27 remains open.

Preserve runner qualifications: premature CDP/accessibility reads, rejected
missing evidence-dir attempt, reused share-text label, direct restore provenance,
corrected prior-report filename with exact restoration, and the final permission
image inspection that superseded a copied black-image exclusion. The app audit
was read, not replayed. Historical findings and Kundalini F-72/F-73/F-74 adoption
limits remain open. Sources: read-only app findings, ITERATION_18_REPORT.md,
ITERATION_87_REPORT.md and app-c/evidence/iteration-87/.

No test-app writes, emulator acceptance, protected-branch changes, schema/version
changes, push or publication. Roadmap status cells are unchanged.

## November 4: iteration 86 adds a naturally observed worker execution

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / app-c 86. The saved app-c artifact audit records 62 passing checks and scoped
acceptancePassed=true; it was read, not replayed. Retained and rebuilt offline /
reconnect probes passed without process recovery. Rebuilt receipts report
reason=offline/pending=1 followed by reason=ok/changed=1/pending=0. No current F-44
recurrence is reported; this neither reverses iteration 84's failure nor identifies
the owning operation or establishes a package-level cause. Historical findings
remain open.

The worker observer records forced=false after 453.256 seconds of observation.
Its script permits an explicit trigger only in a branch that writes a qualification
and sets forced=true; this run's saved receipt reports no such trigger. Matched raw
worker-full-logcat.txt to PID 7319: callback begin 03:59:46.143, complete
03:59:47.430 and native BackgroundWorker SUCCESS 03:59:47.439. This supports one
naturally observed registered execution, not a natural cadence or a reliability
rate. Stable native SQLite receipts show outbox 2 / incoming absent before
isolation, then matching outgoing objects / incoming row / outbox 0 before
foreground. Independently hashed raw activation bytes are identical, SHA256
43653770aff07cb4e8deff9f91715d01b775ec0c611a7571d62d3287662fa796:
current 1793743579, pending 1793743589, no trial before foreground.

Independently rehashed both archived APKs: release 54711308 bytes, SHA256
54bf5e370af6bb1e8c13cae91edb2e10bd03f9a7d77d45a57367a6fa3b83f67b;
debug 168852021 bytes, SHA256
4f16eb126fa7f941a451a2bb6562444a47a5866a12dd0fecbda51e7fb8f8a9ff.
Saved Settings receipt records painted return in the same PID 4811. First-attempt
media success closes no historical finding. The black grant PNG remains excluded;
native Allow-card XML and granted reply are separate receipts. Preserve runner
qualifications: incomplete listener inventories; initial owned mock at the previous
USN base stopped and replaced before rebuilt tests; initial null accessibility
dumps followed by bounded polling without restart; direct restored-startup command
provenance. Saved doctor reports 14 PASS / 10 WARN / 0 FAIL. Read-only metadata
reports 478612 KiB / 4726 regular publication files across retained history, not a
leak or per-iteration growth measurement. Final commitment, retention and cleanup
are saved report/receipt evidence; no live visual or device verification here.

Verified all 36 current exact recorded branch tips and packages bases 0302556 /
62f950b as ancestors of both integrations. Only integration notes differ from
frozen implementation candidate 7385f4e / 1539b66. No eligible must-have, queue
refresh or missing integration merge remains. Decision: preserve security, users'
data and the candidate; do not weaken leases or discard writes on an unproven
cause. F-44 needs targeted ownership/cancellation evidence. S1 stays deliberately
parked; S2 needs a Play account. Kundalini F-72/F-73/F-74 still need adoption and
verification. iOS remains experimental and untested.

Sources: read-only app findings, ITERATION_18_REPORT.md, ITERATION_86_REPORT.md and
app-c/evidence/iteration-86/. Earlier full gates retain their recorded scope; no
fresh full gates, runtime security review or emulator acceptance. Roadmap status
cells and integration candidate/gate date are unchanged. No test-app writes,
protected-branch changes, schema/version changes, push or publication.

## November 4: iteration 85 passes its scope; F-44 remains open

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / app-c 85. The saved app-c artifact audit records 62 passing checks and
acceptancePassed=true within its stated Android scope. Retained and rebuilt
offline/reconnect probes passed without process recovery; the rebuilt receipt
records offline/pending=1, then ok/changed=1/pending=0. No current F-44 recurrence
was observed. This does not reverse iteration 84's failure, identify its owning
operation or establish a package-level cause. Historical findings remain open.

Saved Settings receipt records painted return in the same PID 4882. First-attempt
camera/gallery success does not close historical reliability findings. The black
permission-grant PNG remains excluded; native Allow-card XML and granted reply
remain separate receipts. Preserved runner qualifications: preparation briefly
wrote the prior report before restoring its exact HEAD bytes; initial listener
inventories did not establish configured-port absence; a cold-card image lookup
preceded capture and was later inspected before the tap. These are saved runner
receipts, not fresh visual or device verification here. The audit was read, not
replayed.

Independently rehashed archived APKs against iteration-85 receipts: release
54711308 bytes, SHA256
54bf5e370af6bb1e8c13cae91edb2e10bd03f9a7d77d45a57367a6fa3b83f67b;
debug 168852021 bytes, SHA256
4f16eb126fa7f941a451a2bb6562444a47a5866a12dd0fecbda51e7fb8f8a9ff.
Matched raw worker log lines to PID 7339: callback begin 03:28:58.604, complete
03:28:59.875 and native SUCCESS 03:28:59.885. The registered job was explicitly
triggered with jobscheduler -f; its qualification says timing was bypassed. One
execution proves no natural scheduling readiness or cadence. Independently hashed
raw activation bytes match, SHA256
5254359e81dbdf1f9036ace967a3599d1d2b7cee7ed5dee21804a8b2c86af84e:
current 1793741766, pending 1793741776, no trial before foreground. Saved stable
SQLite receipts show outbox 2/incoming absent before isolation and matching
outgoing objects/incoming row/outbox 0 before foreground. Final commitment,
original data/photo retention and cleanup remain saved report/receipt evidence.
Saved doctor reports 14 PASS / 10 WARN / 0 FAIL, not re-run here. Read-only native
metadata reports 472048 KiB / 4661 regular publication files across retained
stress history, not a leak or per-iteration growth rate; F-27 stays open.

Verified all 36 current exact recorded tips and packages bases 0302556 / 62f950b
as ancestors of both integrations. Only integration notes differ from frozen
implementation candidate 7385f4e / 1539b66. No queue refresh, new assembly or
eligible must-have remains. Decision: preserve security, users' data and the
candidate; a successful pass cannot justify weakening leases or discarding queued
writes. F-44 still needs targeted cancellation/ownership evidence. S1 stays
parked; S2 needs a Play account. Kundalini F-72/F-73/F-74 still need adoption and
verification. iOS remains experimental and untested.

Sources: read-only app findings, ITERATION_18_REPORT.md, ITERATION_85_REPORT.md and
app-c/evidence/iteration-85/. Earlier full gates retain their recorded scope; no
fresh full gates, runtime review or emulator acceptance. Roadmap status cells and
integration candidate/gate date are unchanged. No test-app writes, protected-branch
changes, schema or package-version changes, push or publication.

## November 4: iteration 84 preserves the busy-sync failure after recovery

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / app-c 84. App-c's saved artifact audit has 63 passing checks but
acceptancePassed=false because new F-44 interrupted the rebuilt offline probe.
Twenty bounded calls returned busy/pending=1; the saved native SQLite capture has
one outbox object and lease 1793739542500:4893. Paired device/host clocks qualify
that observation. Raw logs record a background callback at 02:44:01.756 followed
by WorkManager cancellation at 02:44:02.918; a later callback completed with a busy
skip. Temporal overlap does not identify the owning operation or establish a
lease-expiry violation. After restoring the original fields locally, HOME/am kill
and a new process, sync returned ok/changed=1/pending=0; the mock acknowledged two
operations. Recovery and the settled retry do not erase the original failure.
No account reset, runtime-file deletion or package-level cause is inferred.

Saved Settings receipt records painted return in the same PID 5499. First-attempt
Camera/gallery success does not reverse iteration 83 or close historical findings.
The black permission-grant PNG remains excluded; native XML and the granted result
are separate receipts. No live visual or device verification was performed here,
and the app audit was read, not replayed.

Independently rehashed archived APKs against iteration-84 receipts: release
54711308 bytes, SHA256
d39767d390504481fb845911b351d55973b3c59073406a12e10b24ee675f2bb1;
debug 168852021 bytes, SHA256
55c91396594e9ffda73a7085bcb7201928f840d82bfb526acd9f736ad7da723b.
Matched raw worker log lines to PID 7711: callback begin 02:59:39.325, complete
02:59:40.656 and native SUCCESS 02:59:40.664. The saved execution is explicitly
triggered (forced=true), not natural scheduling or cadence. Independently hashed
raw activation bytes match, SHA256
91e0b737eb690bc8b353fd0ed8fb161602ecc6ad96d2f1a36fbc5f8c0370de2f:
current 1793740162, pending 1793740172, no trial before foreground. Saved stable
SQLite receipts show outbox 2/incoming absent before isolation and matching
outgoing objects/incoming row/outbox 0 before foreground. Final commitment,
original data/photo retention and cleanup remain saved report/receipt evidence.
Saved doctor reports 14 PASS / 10 WARN / 0 FAIL, not re-run here. Native metadata
reports 465932 KiB / 4601 regular publication files across retained stress history,
not a leak or per-session growth rate; F-27 stays open.

Verified all 36 exact recorded tips and packages bases 0302556 / 62f950b as
ancestors of both integrations. Only integration notes differ from implementation
candidate 7385f4e / 1539b66. No queue refresh, new assembly or eligible must-have
remains. Decision: preserve security, users' data and the frozen candidate; do not
weaken the sync lease or discard queued writes on an unproven ownership cause.
F-44 needs targeted cancellation/ownership investigation rather than a claimed
fix from a successful retry. S1 stays deliberately parked; S2 needs a Play account.
Kundalini F-72/F-73/F-74 still need adoption and verification. iOS remains
experimental and untested.

Sources: read-only app findings, ITERATION_18_REPORT.md, ITERATION_84_REPORT.md and
app-c/evidence/iteration-84/. Earlier full gates retain their recorded scope; no
fresh full gates, runtime review or emulator acceptance. Roadmap status cells stay
unchanged. No test-app writes, protected-branch, schema or version changes, push
or publication.

## November 4: iteration 83 preserves the Camera failure after recovery

In plain terms: reviewed both findings inventories and newest reports, Kundalini
18 / app-c 83, including the iteration-82 continuation handoff. App-c's saved
artifact audit has 63 passing checks but acceptancePassed=false: Android Camera
ANR interrupted capture at 02:15:50. The native last-ANR receipt names
com.android.camera2 CaptureActivity and a 5001ms input-dispatch wait. Recovery
through its native dialog and a successful retry do not erase that failure or
establish a Valence cause. Saved Settings receipt records painted return in the
same PID 4872; historical reliability findings remain open. No live visual or
device verification was performed here, and the app audit was read, not replayed.

Independently rehashed the archived APKs against iteration-83 receipts: release
54711308 bytes, SHA256
62e653668f431d13d8df007bdb38e73bf3f06bf4294bbb29861d2b72707c5655;
debug 168852021 bytes, SHA256
b4c93056c1a862d34569c291ef73674a26f287591dc34f05c3f4075a2a5b004f.
Matched raw worker log lines to PID 7676: callback begin 02:28:34.597, complete
02:28:35.731 and native SUCCESS 02:28:35.741. The report records one naturally
observed registered execution without an explicit jobscheduler trigger; this
does not establish cadence. Independently hashed raw activation bytes match,
SHA256 5d3110b728f93b83bec8fab3d31c1ca01776611f8aff89041f53cd401efb6da8:
current 1793738301, pending 1793738311, no trial before foreground. SQLite effects,
final commitment, original data/photo retention and cleanup remain saved receipt
evidence. Saved doctor reports 14 PASS / 10 WARN / 0 FAIL, not re-run here.

Preserve the excluded empty accessibility sample and black grant PNG, corrected
checkpoint filename and initial audit refusal. The preinstall restore-sync reply
is busy/pending=0, not proof that this call completed a transfer. Native metadata
reports 459612 KiB under files/valence and 4541 regular publication files across
retained stress history, not a leak or per-session growth rate; F-27 stays open.

Verified all 36 exact recorded tips and packages bases 0302556 / 62f950b as
ancestors of both integrations. Only integration notes differ from implementation
candidate 7385f4e / 1539b66. No queue refresh, new assembly or eligible must-have
remains. Decision: preserve security, users' data and the frozen candidate rather
than change runtime behavior on an external Camera failure. S1 stays deliberately
parked; S2 needs a Play account. Kundalini F-72/F-73/F-74 still need adoption and
verification. iOS remains experimental and untested.

Sources: read-only app findings, ITERATION_18_REPORT.md, ITERATION_82_REPORT.md,
ITERATION_83_REPORT.md and app-c/evidence/iteration-83/. Earlier full gates retain
their recorded scope; no fresh full gates, runtime review or emulator acceptance.
Roadmap status cells stay unchanged. No test-app writes, protected-branch, schema
or version changes, push or publication.

## November 4: iteration 82 hands off the completed iteration 81 run

Reviewed both findings inventories, Kundalini iteration 18 and app-c iteration 82,
plus the completed iteration-81 report and saved receipts. Iteration 82 is a
continuation handoff, not a second fresh install or independent regression. This
entry supersedes the unfinished checkpoint below. Saved artifact audit records
62 passing checks and scoped acceptancePassed=true; neither the app audit nor the
emulator regression was re-executed here. Same-PID 4944 painted Settings return
does not close historical reliability findings or reverse earlier failures.

Independently rehashed both archived APKs: release 54711308 bytes, SHA256
62e653668f431d13d8df007bdb38e73bf3f06bf4294bbb29861d2b72707c5655;
debug 168852021 bytes, SHA256
b4c93056c1a862d34569c291ef73674a26f287591dc34f05c3f4075a2a5b004f.
Saved doctor remains 14 PASS / 10 WARN / 0 FAIL, not re-run here.

Matched raw worker log lines to PID 4837: callback begin 01:54:33.518, complete
01:54:34.932 and native SUCCESS 01:54:34.941. The saved trigger qualification
explicitly records timingBypassed=true with jobscheduler -f, even though readiness
and earliest time were reported. This establishes one execution and its reported
SQLite effects, not natural scheduling, timing readiness or cadence. Independently
hashed raw activation bytes are identical, SHA256
faff377d7376b187006fbb711db88796b2c650fadeae10a678dab91fa6f0d3ba:
current 1793735955, pending 1793735964, no trial before foreground. Final commitment
of 1793735964, original data/photo retention and cleanup remain saved report/receipt
evidence; no live device or visual verification claimed.

Retained host-publication measurements report 453688 KiB and 4468 regular files
across stress history. This is neither a leak attribution nor a per-session growth
rate; F-27 remains open. Preserve initial missing evidence-directory invocation,
empty accessibility dump, corrected preparation filename and duplicate-mock launch
as runner qualifications. The resume identified the original owned mock and
recovered earlier log bytes; no new Valence defect was established by that mistake.

Packages bases remain 0302556 / 62f950b. Independently verified both bases and all
36 exact recorded inclusion tips as ancestors of the two integration HEADs. Only
integration notes differ from implementation candidate 7385f4e / 1539b66; no queue
refresh, new assembly or eligible must-have remains. Decision: preserve security,
users' data and the frozen candidate. S1 stays deliberately parked; S2 needs a Play
account. Kundalini F-72/F-73/F-74 still need adoption and verification. iOS remains
experimental and untested.

Sources: read-only app findings, ITERATION_18_REPORT.md, ITERATION_81_REPORT.md,
ITERATION_82_REPORT.md and app-c/evidence/iteration-81/. Earlier full gates retain
their recorded scope; no fresh full gates, runtime review or emulator acceptance.
This evidence-only update leaves roadmap status cells unchanged. No test-app
writes, protected-branch, schema or version changes, push or publication.

## November 4: iteration 81 remains an unfinished checkpoint

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 81.
App-c's report is a native checkpoint, not a completed acceptance run: it records
painted Settings return in the same PID 4944 and permission/plugin/queue/share
checks, while media, routes, widget sync, OTA and worker checks remain pending.
The saved Settings outcome agrees on PID and paint; no live visual or device
verification is claimed. Earlier reliability findings remain open.

Independently rehashed the archived APKs against iteration-81 receipts: release
54711308 bytes, SHA256
62e653668f431d13d8df007bdb38e73bf3f06bf4294bbb29861d2b72707c5655;
debug 168852021 bytes, SHA256
b4c93056c1a862d34569c291ef73674a26f287591dc34f05c3f4075a2a5b004f.
Saved doctor counts are 14 PASS / 10 WARN / 0 FAIL, not re-run here. Preserve the
initial missing evidence-directory invocation, empty retained accessibility dump,
and corrected preparation filename separately, as the runner notes require.
No final iteration-81 audit or worker outcome is inferred from iteration 80.

Packages bases remain 0302556 / 62f950b. Verified both bases and all 36 exact
recorded inclusion tips as ancestors of the integration HEADs. Only integration
notes differ from implementation candidate 7385f4e / 1539b66. No eligible must-have
or rebase-queue item remains; no new assembly is needed on unchanged bases.
Decision: preserve security, users' data and the frozen candidate while the app
run finishes. S1 stays parked; S2 needs a Play account. Kundalini F-72/F-73/F-74
still need adoption and verification; iOS remains experimental and untested.

Sources: read-only app findings, ITERATION_18_REPORT.md / ITERATION_81_REPORT.md,
and app-c/evidence/iteration-81/. Earlier full gates retain their recorded scope;
no fresh full gates, emulator acceptance or runtime review. No test-app writes,
protected-branch, schema or version changes, push or publication.

## November 4: iteration 80 scoped success; publication footprint measured

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 80,
including Kundalini's latest handoff. No eligible must-have or rebase-queue item
remains. Packages bases remain 0302556 (code) / 62f950b (site). Independently
verified both bases and all 36 exact recorded inclusion tips as ancestors of the
integration HEADs. Only integration notes differ from implementation candidate
7385f4e / 1539b66; no new integration assembly is needed on unchanged bases.

Read the saved 62-check artifact audit, scoped acceptancePassed=true, self-review
and runner qualifications; did not re-execute the app audit or emulator regression.
Saved receipts report fresh offline and restored startup without runtime recovery,
and painted Settings return in the same PID 4862. This successful attempt does
not reverse iteration 79's failure or close historical reliability findings.
Preserve the initial retained CDP socket closure separately: it preceded readiness,
and establishes no process-death or startup cause. The initial preparation used an
unavailable Python alias and was retried with Node. The denial PNG captured a dimmed
transition; the report relies on native XML for the actual permission card.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 2b9d34ee93c14d9100bd9b6930520961c43812d9cb7e5b851dadfc36e0015f67;
debug 168852021 bytes, SHA256
56dece93df4a6235035964dac76c872f29f61e10a9909fcacafbfb7682dd2360.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL; not re-run here.

Matched worker-full-logcat.txt lines 80069/80073/80074: PID 7729 callback begin
00:59:36.065, complete 00:59:37.163 and native SUCCESS 00:59:37.178. Trigger
qualification records an explicit jobscheduler -f request after Ready:true and
passed earliest time, while captured job text still lists TIMING_DELAY unsatisfied.
Actual callback and data receipts establish one execution, not natural scheduling
or cadence. Saved stable native SQLite receipts report exact outgoing objects,
incoming USN 2070002 and outbox zero before foreground; not a fresh database
inspection by this evidence intake.

Independently hashed raw activation files are byte-identical, SHA256
cf26c20d441752a35ef5ef9a27f47988760e9c7ea8a69076b02d2f20ed6d9399,
current 1793732769, pending 1793732778, no trial before foreground. The report
records final commitment of 1793732778. Retention, painted screens and cleanup
remain report/receipt evidence; no live device-state, visual inspection or cleanup
verification claimed here.

Read-only native storage receipts record 447564 KiB and 4408 regular files under
files/valence/host across the retained stress history. F-27's publication lifetime
and caps gap remains open. A footprint measurement establishes neither a Valence
leak nor a per-session growth rate; deleting runtime publications would sacrifice
retained evidence without establishing a fix.

Decision: preserve security, users' data and the frozen candidate. A scoped pass
does not justify closing earlier failures, weakening rollback strikes or speculative
runtime changes. S1 stays parked; S2 needs a Play account. Kundalini F-72/F-73/F-74
still need adoption and verification. iOS remains experimental and untested.
Sources: read-only app findings, reports and app-c/evidence/iteration-80/.
Earlier full gates retain their recorded scope; no fresh full gates, emulator
acceptance or runtime review claimed. No test-app writes, protected-branch,
schema or version changes, push or publication.

## November 4: iteration 79 Settings failure; deferred worker attempt kept separate

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 79,
including Kundalini's latest handoff. No eligible must-have or rebase-queue item
remains. Packages bases remain 0302556 (code) / 62f950b (site). Independently
verified both bases and all 36 exact recorded inclusion tips as ancestors of the
integration HEADs. Only integration notes differ from implementation candidate
7385f4e / 1539b66; no new integration assembly is needed on unchanged bases.

Read the saved 62-check artifact audit, self-review and runner qualifications;
all artifact checks pass but scoped acceptancePassed=false. Did not re-execute
the app audit or emulator regression. Saved receipts report fresh offline and
restored startup without runtime recovery. Settings survival failed: raw full
log lines 57174/57179/57201 record renderer 5118 killed at 00:15:41.065, host
5040 directly killed by lowmemorykiller at 00:15:41.094, and host death at
00:15:41.184. The saved outcome records replacement PID 6198, pagePainted=false
and a closed CDP connection before recovery. Later recovered feature checks do
not repair this failed attempt. These logs establish neither a Valence memory
leak nor Chromium's historical unhandled-renderer-loss path killing the host.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 59c2274979ae875c4993b0200e8bab3a89dd846aa7e4194fc0219554788d7b5c;
debug 168852021 bytes, SHA256
1d42844543a6ed7473ed19f74151dde0bef384bfb367609201249c772ac5d2d1.
Saved doctor reports 14 PASS / 10 WARN / 0 FAIL; not re-run here.

Preserve both worker attempts. Raw worker-full-logcat.txt lines 79889/79890
show the early accepted -f request deferred by WorkManager before callback at
00:23:14.878/.881. It proves no transfer. A separate explicit registered-job
trigger followed reported timing readiness. Lines 81869/81887/81888 match PID
8113 callback begin 00:30:07.776, complete 00:30:09.261 and native SUCCESS
00:30:09.269. One execution proves no natural scheduling cadence. Saved stable
native SQLite receipts report exact outgoing objects, incoming row and outbox
zero before foreground; these are saved receipts, not a fresh database inspection.

Independently hashed raw activation files are byte-identical, SHA256
54257656ff95da129863bb7c5fdba2d8a0cad767eda925ae991d36fc87ef53a2,
current 1793731068, pending 1793731078, no trial before foreground. The report
records final commitment of 1793731078. Retention, painted screens and cleanup
remain report/receipt evidence; no live device-state, visual inspection or cleanup
verification claimed here. The initial unsupported --offline release-build
invocation exited before building; the report records a successful --no-pub retry.

Decision: preserve security, users' data and the frozen candidate. Retain the
failed acceptance outcome; direct OS termination does not justify speculative
runtime changes or weakening rollback strikes. Historical reliability findings
remain open. S1 stays parked; S2 needs a Play account. Kundalini F-72/F-73/F-74
still need adoption and verification. iOS remains experimental and untested.
Sources: read-only app findings, reports and app-c/evidence/iteration-79/.
Earlier full gates retain their recorded scope; no fresh full gates, emulator
acceptance or runtime review claimed. No test-app writes, protected-branch,
schema or version changes, push or publication.

## November 3: iteration 78 scoped success; restore isolation retry preserved

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 78.
No eligible must-have or rebase-queue item remains. Packages bases remain
0302556 (code) / 62f950b (site). Independently verified both bases and all 36
exact recorded inclusion tips as ancestors of both integration HEADs. Only
integration notes differ from implementation candidate 7385f4e / 1539b66;
no new integration assembly is needed on these unchanged bases.

Read the saved 62-check artifact audit, scoped acceptancePassed=true, self-review
and runner qualifications; did not re-execute the app audit or emulator regression.
Saved receipts report fresh offline and restored startup without runtime recovery,
and painted Settings return in the same PID 5397. That successful attempt does
not reverse iteration 76's failure or close historical reliability findings.

Preserve the initial restore refusal separately: the app restarted during archive
transfer, before extraction. Saved interruption evidence identifies PID 5240 in
BOOT_COMPLETED / WM-RescheduleReceiver. The retry verified process absence after
transfer, extracted a hash-matching archive and reached readiness. This is a
process-isolation interruption, not an established Valence startup failure.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 141a19c963110420330d08a80a376a9677a3d45d842544e55c108375a363c5f4;
debug 168852021 bytes, SHA256
451f1e869ded9ab6fe09083970c2ef5026d76a6ffc470908e5fd7a0b86f5a985.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL and exit 0; not re-run here.

Matched worker-full-logcat.txt lines 88815/88835/88836: PID 7703 callback begin
23:53:32.381, complete 23:53:33.410 and native SUCCESS 23:53:33.420. Trigger
qualification records one explicitly triggered registered job after scheduler
readiness, not natural scheduling or cadence. Saved stable native SQLite receipts
report exact outgoing objects, incoming USN 2010002 and outbox 0 before foreground.
These remain saved database receipts, not a fresh database inspection here.

Independently compared raw activation files: byte-identical SHA256
c611a79a1edba570e8407db4492c5f51e190e895fbccee05ebec138047a712fb,
current 1793728901, pending 1793728911, no trial before foreground. The report
records final commitment of 1793728911. Retention, painted screens and cleanup
remain report/receipt evidence; no live device-state, visual inspection or cleanup
verification claimed by this evidence intake.

Decision: preserve security, users' data and the frozen candidate. A scoped pass
does not justify closing prior failures, weakening rollback strikes or speculative
runtime changes. S1 stays parked; S2 needs a Play account. Kundalini F-72/F-73/F-74
still need adoption and verification. iOS remains experimental and untested.
Sources: read-only app findings, reports and app-c/evidence/iteration-78/.
Earlier full gates retain their recorded scope; no fresh full gates, emulator
acceptance or runtime review claimed. No test-app writes, protected-branch,
schema or version changes, push or publication.

## November 3: iteration 77 scoped success; prior Settings failure remains open

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 77,
including Kundalini's latest handoff. No eligible must-have or rebase-queue item
remains. Packages bases remain 0302556 (code) / 62f950b (site). Independently
verified both bases and all 36 exact recorded inclusion tips as ancestors of the
integration HEADs. Only integration notes differ from implementation candidate
7385f4e / 1539b66; no new integration assembly is needed on these unchanged bases.

Read the saved 60-check artifact audit, scoped acceptancePassed=true, runner
qualifications and self-review. All saved artifact checks pass; did not re-execute
the app audit or emulator regression. Saved receipts report fresh offline and
restored startup without recovery, plus painted Settings return in the same PID
5058. This successful attempt does not reverse iteration 76's direct low-memory
host/renderer kills or close historical reliability findings.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 cb0ccdc07a3ec2900311ecd27969e34ac298adc84a39ff493ebf95413186b521;
debug 168852021 bytes, SHA256
ccd846df467150ad76b97a2204310c1c6c6387589037a85b34d013e7b24db505.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL and exit 0; not re-run here.

Matched worker-full-logcat.txt lines 88343/88346/88347: PID 7528 callback begin
17:00:23.117, complete 17:00:24.698 and native SUCCESS 17:00:24.713. Saved trigger
qualification records explicitlyTriggered=false and execution records forced=false:
one registered execution observed without the observer issuing a force command,
not a scheduling-cadence guarantee. Saved stable native SQLite receipts report
outbox 2 and incoming fixture absent before isolation, exact outgoing objects,
incoming USN 1980002 and outbox 0 before foreground. These remain saved database
receipts, not a fresh database inspection here.

Independently compared raw activation files: byte-identical SHA256
eca21387c24df8e3b78497a9febf87b6f2be78dc1519916b5fbcc1f669e93d85,
current 1793704119, pending 1793704129, no trial before foreground. Saved final
state records current 1793704129 with no pending or trial. Retention, painted
screens and cleanup remain report/receipt evidence; no live device-state,
visual inspection or cleanup verification claimed by this evidence intake.

Preserve both runner interruptions: a 20-second Windows mock-ownership query
timeout before fixture creation, then a 30-second full-logcat timeout after a
stable isolation baseline. The report records recovery with the same ownership
guard and existing baseline. Neither establishes a Valence failure.

Decision: preserve security, users' data and the frozen candidate. A scoped pass
does not justify closing earlier failures or weakening rollback strikes. S1 stays
parked; S2 needs a Play account. Kundalini F-72/F-73/F-74 still need adoption and
verification. iOS remains experimental and untested. Sources: read-only findings,
reports and valence-test-app-c/evidence/iteration-77/. Matching notes, ancestry,
unchanged implementation trees and diff hygiene checked. Earlier full gates
retain their recorded scope; no fresh full gates, emulator acceptance or runtime
review claimed. No test-app writes, protected-branch, schema or version changes,
push or publication.

## November 3: iteration 76 Settings survival failed; recovered checks stay separate

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 76.
No eligible must-have or rebase-queue item remains. Packages bases remain
0302556 (code) / 62f950b (site). Verified both bases and all 36 exact recorded
inclusion tips as ancestors of the integration HEADs. Only integration notes
differ from implementation candidate 7385f4e / 1539b66.

Read the saved 60-check artifact audit, runner qualifications and self-review;
all artifact checks pass but scoped acceptancePassed=false. Did not re-execute
the app audit or emulator regression. Saved receipts report fresh offline and
restored startup without recovery. Settings survival failed: raw full log lines
60009/60016 record renderer 4981 killed at 16:15:48.149 and host 4902 killed at
16:15:48.167 directly by lowmemorykiller. Exit-info independently records
LOW_MEMORY for both. Saved return receipt records replacement PID 5962,
pagePainted=false and a failed pre-relaunch CDP read. Later recovered feature
checks do not repair this failed attempt. These logs establish neither a Valence
memory leak nor the historical unhandled-renderer-loss path killing the host.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 169080ffbda85eb51da5a1e9a5655ec9c9bade50292655f54dadd2a54cf74a6e;
debug 168852021 bytes, SHA256
14be018be55da325592dcb7ff9af73f2dff74cf8c53e320d5df7be0eea7a44a6.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL and exit 0; not re-run here.

Matched worker-full-logcat.txt lines 84603/84625/84626: PID 7884 callback begin
16:30:33.747, complete 16:30:35.026 and native SUCCESS 16:30:35.035. Trigger
qualification records one explicitly triggered registered job, not natural
eligibility or cadence. Saved stable native SQLite receipts report outbox 2 and
incoming fixture absent before isolation, exact outgoing objects, incoming USN
1950002 and outbox 0 before foreground. These are saved database receipts,
not a fresh database inspection here.

Independently compared raw activation files: byte-identical SHA256
11288eda9e85063264596044f4a80fd6283571823b2d7cc2eb807a461af05145,
current 1793702292, pending 1793702301, no trial before foreground. Saved final
state records current 1793702301 with no pending or trial. Retention, painted
screens and cleanup remain report/receipt evidence; no live device-state,
visual inspection or cleanup verification claimed by this evidence intake.

Decision: preserve security, users' data and the frozen candidate. Retain the
failed acceptance outcome; direct OS termination does not justify speculative
runtime changes or weakening rollback strikes. Historical reliability findings
remain open. S1 stays parked; S2 needs a Play account. Kundalini F-72/F-73/F-74
still need adoption/verification. iOS remains experimental and untested. Sources:
read-only app findings, reports and valence-test-app-c/evidence/iteration-76/.
Matching notes, ancestry, unchanged implementation trees and diff hygiene
checked. Earlier full gates retain their recorded scope; no fresh full gates,
emulator acceptance or runtime review claimed. No test-app writes, protected-
branch, schema or version changes, push or publication.

## November 3: iteration 75 scoped success; historical failures remain open

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 75.
No eligible must-have or rebase-queue item remains. Packages bases remain
0302556 (code) / 62f950b (site). Independently verified both bases and all 36
exact recorded inclusion tips as ancestors of the integration HEADs. Only
integration notes differ from implementation candidate 7385f4e / 1539b66.

Read app-c's saved 60-check artifact audit, scoped acceptancePassed=true,
runner qualifications and self-review; did not re-execute its audit or emulator
regression. Saved receipts report fresh offline and restored startup without
recovery, and painted Settings return in the same PID 5072. This successful
attempt does not reverse iteration 74's startup failure or close historical
renderer, startup, busy-sync, background or doctor findings. Initial permission
screenshot preceded card paint; subsequent native XML carries the denial card.
File-share screenshot captures the rising sheet; no recipient delivery claimed.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 1858b59d0fd5eeb9c3876cad40f8d321cd674aa7930c6d5721b325ceb96e9e89;
debug 168852021 bytes, SHA256
273f2c664d1dc27775431d67a2f72103fd74d299310362f761962d081126caaf.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL and exit 0; not re-run here.

Matched worker-full-logcat.txt lines 79790-79792: PID 7360 callback begins
16:00:11.398, completes 16:00:12.619 and reports native SUCCESS 16:00:12.629.
worker-execution.json records forced=true; the trigger qualification explicitly
excludes natural eligibility and cadence claims. One triggered execution is
all this establishes. Saved stable native SQLite receipts report outbox 2 and
incoming fixture absent before isolation, exact outgoing objects, incoming USN
1920002 and outbox 0 before foreground. These are saved database receipts,
not a fresh database inspection here.

Independently compared raw activation files: byte-identical SHA256
78e0047a12d0702a3fd37c03a057b3067255befc55760aa65f767f76a99365fa,
current 1793700460, pending 1793700469, no trial before foreground. Saved final
state records current 1793700469 with no pending or trial. Retention, painted
screens and cleanup remain report/receipt evidence; no live device-state,
visual inspection or cleanup verification claimed by this evidence intake.

Decision: preserve security, users' data and the frozen candidate. A successful
attempt warrants updating the evidence ledger, not changing runtime behavior
or dismissing prior failures. S1 stays parked; S2 needs a Play account.
Kundalini F-72/F-73/F-74 still need adoption/verification. iOS remains experimental
and untested. Sources: read-only app findings, reports and
valence-test-app-c/evidence/iteration-75/. Matching notes, ancestry, unchanged
implementation trees and diff hygiene checked. Earlier full gates retain their
recorded scope; no fresh full gates, emulator acceptance or runtime review
claimed. No test-app writes, protected-branch, schema or version changes,
push or publication.

## November 3: iteration 74 startup failed; recovered worker observed naturally

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 74.
No eligible must-have or rebase-queue item remains. Packages bases remain
0302556 (code) / 62f950b (site). Verified both bases and all 36 current exact
inclusion tips as ancestors of their integration HEADs. Only integration notes
differ from implementation candidate 7385f4e / 1539b66.

App-c's saved audit has 59 passing artifact checks but acceptancePassed=false.
Read the audit, startup qualification, runner notes and self-review; did not
re-execute the app audit or emulator regression. Raw logs confirm restored PID
6834 store.open completed in 66895 ms, system_server 690's null reference in
AppCompatCameraDisplayRotationPolicy.dump, and Watchdog killing system_server
5794 for a blocked I/O handler. Reported startup and BOOT_COMPLETED receiver
ANRs and the initial blank fresh-launch image remain qualified separately from
later recovery. No Valence blocking frame, lock owner or causal diagnosis is
established. Saved Settings receipt reports painted return in the same PID 2619;
this recovered success does not erase startup failures or close historical findings.

Independently rehashed archived APKs against receipts: release 54711308 bytes,
SHA256 e04b77ae0ead82bf4d7bfaff2b8eeaa357ee97ad7f0c964684168f3cfdb62016;
debug 168852021 bytes, SHA256
cbc890e233188fd88fc391a1bdec7bac3a664c883f3e07fe08493bbd10b94382.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL; not re-run here.

Matched worker-full-logcat.txt lines 72853/72888/72889: PID 7024 callback begin
15:01:44.395, complete 15:01:45.334 and native SUCCESS 15:01:45.347. Unlike the
previous iteration, worker-execution.json records forced=false; the observation
script can force an eligible job but records that branch, and this receipt says
it was not taken. One naturally observed execution establishes no cadence.
Saved stable native SQLite receipts report outbox 2/incoming absent before the
worker, exact outgoing objects, incoming USN 1890002 and outbox 0 before foreground.
These are saved app database receipts, not a fresh database inspection here.
Independently hashed the two raw activation files: identical SHA256
998feccb4ea504535cd97ffa9d2dc894e6d448156f2b8ff0553d3b9239e33ea7,
current 1793697254, pending 1793697264, no trial before foreground. Saved final
state records current 1793697264 with no pending or trial. Retention and cleanup
remain report/audit evidence; no live device-state or cleanup verification claimed.

Decision: preserve security, users' data and the frozen candidate. These platform
interruptions justify retaining the failed acceptance result, not a speculative
runtime change. S1 stays parked; S2 needs a Play account. Kundalini F-72/F-73/F-74
still need adoption/verification. iOS remains experimental and untested. Sources:
read-only app findings, reports and valence-test-app-c/evidence/iteration-74/.
Matching integration notes, ancestry, unchanged implementation trees and diff
hygiene checked. Earlier full gates retain their recorded scope; no fresh full
gates, emulator acceptance or runtime security review claimed. No test-app writes,
protected-branch, schema or version changes, push or publication.

## November 3: iteration 73 scoped success; historical failures remain open

Read both findings inventories and newest reports, Kundalini 18 / app-c 73.
No eligible must-have or queue refresh remains. Packages bases remain 0302556
(code) / 62f950b (site). Independently verified both bases and all 36 exact
recorded inclusion tips as ancestors. Only integration notes differ from
implementation candidate 7385f4e / 1539b66.

App-c's completed report records scoped acceptancePassed=true. Read its saved
59-check artifact audit, runner qualifications and self-review; did not re-run
the app audit or emulator regression. Inspected the saved painted Settings
return screenshot and same-PID 5082 receipt. This successful attempt does not
close historical renderer loss, startup, busy-sync, background or doctor
findings, or reverse iteration 72's failed Settings acceptance. The initial
pre-readiness CDP fetch and null-root accessibility sample remain qualified;
Flutter analysis overlapped the tail of its test process, with both reported
successful before APK builds and doctor. No cause or latency inferred.

Independently rehashed both archived APKs against receipts: release 54711308
bytes, SHA256 b9cd72ef1dc125d8d2e603e479a51a342302ddc9ac36b4d65cbcfc49ea4afcfe;
debug 168851839 bytes, SHA256
921f12d459b7060758b98928f22dc7c3d25a7744f8e0d4114d922b3f5d0183ff.
Saved doctor records 14 PASS / 10 WARN / 0 FAIL and child exit 0; not re-run.

Matched raw worker-full-logcat.txt lines in PID 8070: begin 13:44:54.775,
complete 13:44:56.114 and native SUCCESS 13:44:56.124. This was one explicitly
triggered registered execution after reported ready/elapsed timing; it proves
no natural scheduling cadence. Saved native SQLite receipts report outbox 2
and incoming fixture absent before isolation, then exact outgoing objects,
incoming USN 1860002 and outbox 0 before foreground. These are saved app
receipts, not a fresh database inspection by this builder.

Independently compared raw activation files: byte-identical, SHA256
2e8917e8eee93b373dad205e0518c200c556186346c62aca6401fe0efac6f380;
current 1793692340, pending 1793692351, no trial before foreground. Saved final
state records current 1793692351, no pending or trial. Saved retention/cleanup
receipts report original inspection fields and photo bytes retained, fixtures
and queues cleaned, airplane mode off and owned app/mocks stopped. No live
cleanup or device-state verification claimed.

Decision: preserve security, users' data and the frozen candidate; no runtime
change is justified by this evidence intake. S1 stays parked, S2 needs a Play
account, and Kundalini F-72/F-73/F-74 still need adoption/verification. iOS
remains experimental and untested. Sources: read-only app findings, reports
and valence-test-app-c/evidence/iteration-73/. Mirrored notes, ancestry,
unchanged implementation trees and diff hygiene checked. Existing gates retain
their recorded scope; no fresh full gates, emulator acceptance or runtime
security review claimed. No test-app writes, protected-branch, schema or
version changes, push or publication.

## November 3: iteration 72 completed; Settings acceptance still failed

Read both findings inventories and newest reports, Kundalini 18 / app-c 72.
The completed app-c report supersedes the worker-pending checkpoint below.
No eligible must-have or queue refresh remains. Packages bases remain 0302556
(code) / 62f950b (site); independently verified both bases and all 36 recorded
inclusion tips as ancestors. Only integration notes differ from implementation
candidate 7385f4e / 1539b66.

Settings survival remains failed: the recorded direct Android low-memory kill
of host 5730 and blank replacement 6827 are not repaired by later recovered
checks. The app's saved artifact audit has 59 passing consistency checks and
explicitly reports acceptancePassed=false. Read that audit, runner qualifications
and self-review; did not re-execute the app's audit or emulator regression.
No historical renderer, startup, busy-sync, background or doctor finding closes.

Matched the accepted worker's raw log lines in worker-full-logcat.txt: PID 3745
begin 08:26:12.539, complete 08:26:13.594 and native SUCCESS 08:26:13.608.
The earlier force-stopped attempt and before-schedule trigger remain excluded.
The accepted run was explicitly triggered after reported ready/elapsed timing;
it establishes no natural scheduling cadence. Native SQLite receipts report
outbox 2/incoming absent before isolation, then exact outgoing objects, incoming
row USN 1830002 and outbox 0 before foreground. Those database effects are saved
app evidence, not a fresh database inspection by this builder.

Independently compared raw activation files: byte-identical, SHA256
3e47ebcd418f65fb0b5eaaada71b4fde8dc8d60d4c99bd07755d5d465e08b02c,
current 1793670248, pending 1793672808, no trial before foreground. Saved final
state subsequently records current 1793672808 with no pending or trial. Final
retention and cleanup receipts report original inspection/photo preservation,
matching photo bytes, fixtures/queues cleaned, airplane mode off, and owned app
and mocks stopped. No live cleanup or device-state verification claimed.

Independently rehashed both archived APKs against receipts: release 54711308
bytes, SHA256 d5f7e43c85feb3c7b9af888e07e77359b335897638a9126b9cc72ac3a988baf0;
debug 168851835 bytes, SHA256
54a3ecfa1138e2a4f3f5508e7f0fddc76fc534a1e952fcbf1fa1da662be076ff.
Saved sequential doctor remains 14 PASS / 10 WARN / 0 FAIL; not re-run here.

Decision: preserve security, users' data and the frozen candidate. No runtime
change is justified by this evidence intake. S1 stays parked, S2 needs a Play
account, and Kundalini F-72/F-73/F-74 still need adoption/verification. iOS remains
experimental and untested. Sources are read-only app findings, reports and
valence-test-app-c/evidence/iteration-72/. Mirrored notes, ancestry, unchanged
implementation trees and diff hygiene checked. Existing gates retain their
recorded scope; no fresh full gates, emulator acceptance or runtime security
review claimed. No test-app writes, protected-branch, schema or version changes,
push or publication.

## November 3: iteration 72 checkpoint; Settings survival failed

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 72.
App-c 72 is a worker checkpoint, not a completed acceptance run. No eligible
must-have or queue refresh remains. Packages bases are unchanged at 0302556
(code) / 62f950b (site). Both integrations contain their base and all 36 exact
recorded inclusion tips; only integration notes differ from implementation candidate
7385f4e / 1539b66.

Directly checked settings-return-full-logcat.txt and settings-return-exit-info.txt:
lmkd killed renderer 5836 at 07:21:44.371 and directly killed host 5730 at
07:21:44.403; ActivityManager records host death at 07:21:44.693. Both exit
records say LOW_MEMORY. The app records blank replacement 6827 before recovery.
Settings survival failed. This establishes neither the historical unhandled
renderer callback path nor a Valence leak, ANR, database lock or lost trial.
Recovery results do not turn that failure into an acceptance pass.

Independently rehashed both build outputs and their archived APKs against current
receipts: release 54711308 bytes, SHA256
d5f7e43c85feb3c7b9af888e07e77359b335897638a9126b9cc72ac3a988baf0;
debug 168851835 bytes, SHA256
54a3ecfa1138e2a4f3f5508e7f0fddc76fc534a1e952fcbf1fa1da662be076ff.
Saved doctor rows count 14 PASS / 10 WARN / 0 FAIL, with doctor exit 0. This is
app evidence and does not close historical doctor failures.

At the report checkpoint, raw activation has pending 1793670248, no trial,
current 1793670239. The saved stable native SQLite receipt reports outbox 2,
incoming fixture absent, no foreground resume. The app's registered job 9 has
unsatisfied TIMING_DELAY in background-jobs-near-due.txt. No completed worker,
background transfer, final activation, natural cadence or cleanup is claimed.

Decision: preserve security, users' data and the frozen candidate. S1 stays
parked; S2 requires a Play account. Keep Settings reliability open and await
completed worker evidence rather than infer a runtime fix from OS eviction.
Kundalini F-72/F-73/F-74 still need app adoption and verification. iOS remains
experimental and untested.

Sources: read-only valence-test-app-c/evidence/iteration-72/ and both apps'
findings/reports. Mirrored notes, ancestry, unchanged implementation trees and
diff hygiene checked. Existing November 3 gates retain their recorded scope;
no fresh full gates, emulator acceptance or runtime security review claimed.
No test-app writes, protected-branch, schema or version changes, push or publication.

## November 3: iteration 71 evidence intake; implementation unchanged

Reviewed both findings inventories and newest reports, Kundalini 18 / app-c 71.
No eligible must-have or queue refresh remains. Packages bases remain 0302556
(code) / 62f950b (site); both integrations contain their base and all 36 exact
recorded inclusion tips. Only this note differs from the gated implementation
candidate 7385f4e / 1539b66.

Decision: preserve security, users' data and the frozen candidate. S1 remains
parked and S2 requires a Play account. App-c reports no new Valence defect;
success here does not close historical renderer, startup, background, busy-sync,
media or doctor findings. Kundalini F-72/F-73/F-74 still need app adoption and
verification. iOS remains experimental and untested.

Independently rehashed archived iteration-71 APKs against their saved receipts:
release 54711084 bytes, SHA256
f224ad89cf89b6c8c69a607a032cb5a666990d6b3f1127e47143143c8a110be6;
debug 168851587 bytes, SHA256
8f13b787b21f0ff7b39a8d34dd95d1e4e2cf9ec9bfdafeb9b87ce6d54dfe83a5.
The saved audit records 59 passing artifact checks; read, not re-executed.
Read the runner qualifications and scoped review, including the corrected gate
for preserved preinstall offline/reconnect/restored-sync receipts. Those three
current receipts show queue 1 offline, then queue 0 after reconnect and restore.
Runner PATH/test-file errors and the initial missed widget capture remain
separate from accepted retries. Sequential doctor reports 14 PASS / 10 WARN /
0 FAIL; this does not erase iteration 70's failed invocation or close F-43.
Settings receipt reports painted return in the same PID 5257.

Matched PID 7989 begin 06:38:37.069, complete 06:38:38.527 and native SUCCESS
06:38:38.534 directly in worker-full-logcat.txt. Independently compared raw
activation files: byte-identical, SHA256
12582698f3519167b62b651ab06e7c95c8f9145b0cad667756e34c082fd278bf,
pending 1793666816, no trial. One explicitly triggered registered run establishes
no natural cadence; the 398.638-second observer wait is not callback duration.
Native SQLite effects and final foreground commitment are app-reported evidence.

Sources: read-only valence-test-app-c/evidence/iteration-71/ and both apps'
findings/reports. No test-app writes. Mirrored notes, ancestry, unchanged
implementation trees and diff hygiene checked. Earlier November 3 gates retain
their scope; no fresh full gates, emulator acceptance or runtime security review
claimed. No protected-branch, schema or version changes, push or publication.

## November 3: iteration 70 evidence intake; implementation unchanged

Read both apps' VALENCE_FINDINGS.md inventories and newest completed reports:
Kundalini 18 and app-c 70. No eligible must-have, changes-requested item or queue
refresh remains. Packages bases remain 0302556 (code) and 62f950b (site).
Verified both bases and all 36 exact tips in the current inclusion table are
ancestors of their integrations. Only docs/integration.md differs from the
previously gated implementation candidate 7385f4e / 1539b66.

Decision: preserve security, users' data and the candidate. S1 stays deliberately
parked; S2 needs a Play account. App-c 70 establishes no new runtime defect.
Successful retries do not justify weakening trial accounting, resetting accounts,
deleting durable publications or closing historical reliability findings.

Independently hashed both archived APKs against iteration-70 receipts:
release 54711084 bytes, SHA256
d94ceb528a4f4747623f4d8184eb0e652eaa94de7a3e126f1e41c965522dab79;
debug 168851587 bytes, SHA256
96cca21feaa10f712b56a35333bb0f2090e42731aa83c20b2067a90fe7432003.
The saved artifact audit records 56 passing consistency checks; it was read,
not re-executed. No test-app file changed.

Settings receipt records painted return in the same PID 5235. Fresh release
Valence.open completed in 1655 ms, separately from paint. Initial unsettled
widget and early denial captures remain excluded. Retention receipts report
preserved inspection fields and photo identity, and matching original-photo
archive/native hashes; strict cleanup receipt records absent PID with exit 1,
empty stdout/stderr and no execution error.

Compared saved native baseline (outbox 2, incoming absent) with pre-foreground
effects (outbox 0, incoming row and outgoing objects reported matching).
Independently matched raw worker-full-logcat.txt: PID 8371 begins 05:39:10.504,
completes 05:39:11.870 and reports native BackgroundWorker SUCCESS at
05:39:11.879. Raw activation files are byte-identical, SHA256
45b12583b57448ae7623dcadd15751086c7af7710836e1c3976e85af3a709156,
pending 1793663146, no trial. One explicitly triggered registered execution
proves no natural cadence; the 463.841-second observation wait is not callback
duration. Final foreground commitment is later evidence.

Preserve F-43's initial doctor --tests result: 13 PASS / 10 WARN / 1 FAIL,
child exit 1, with overlapping Flutter commands but no established cause.
The sequential retry reports 14 PASS / 10 WARN / 0 FAIL, child exit 0.
The retry does not erase the failure or close F-43. Historical renderer,
startup, background, busy-sync and media findings remain open or qualified.
Kundalini F-72/F-73/F-74 remain app-reported pending adoption and verification.
iOS remains experimental and untested.

Sources: read-only valence-test-app-c/evidence/iteration-70/ and both apps'
findings/reports. Only mirrored integration notes change. Earlier November 3
gates retain their scope; no fresh full-gate run, emulator acceptance or runtime
security review is claimed. Ancestry, unchanged implementation trees, mirrored
notes and diff hygiene checked. No protected-branch changes, schema/version
changes, push or publication.

## November 3: iteration 69 evidence intake; implementation unchanged

Read both apps' VALENCE_FINDINGS.md inventories and newest completed reports:
Kundalini 18 and app-c 69. No eligible must-have, changes-requested item or queue
refresh remains. Packages refs remain 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29
(code) and 62f950ba1d52632b47fdd0e170bc41e18d467ae1 (site). Both refs and all
36 exact tips in the current merge-order table are ancestors of their respective
integrations. Implementation remains the tested candidate 7385f4e / 1539b66.

Decision: preserve security, users' data and the candidate while validation
continues. S1 stays deliberately parked; S2 needs a Play account. Successful
retries do not justify weaker trial accounting, account resets or deleting runtime
publications. App-c 69 establishes no new Valence defect requiring a code change.

Replayed the saved app-c 69 artifact audit in an isolated context with its sole
write intercepted in memory: all 38 checks pass. The initial replay encountered
the script's UTF-8 BOM before any audit execution; stripping that BOM in memory
allowed the read-only replay. Independently hashed archived APKs:
release 54711084 bytes, SHA256
b3e90807ac72dd9423f8091f713a57056c469aebb82d59bd57e60d70b3a83ad9;
debug 168851587 bytes, SHA256
6015b99b667587e82e0ca12a15ac55f6ab08ca77d544936597090b9a7eb23819.
No test-app file changed. Artifact consistency is separate from device execution.

Settings receipt records return in the same PID 5769. Inspected the saved return
image: painted list, completed inspection, original photo count and one installed
widget. Memory-pressure kills of other processes do not establish loss of this
host; historical F-36 remains open. Fresh release open completes in 622 ms,
separately from paint. Preserve the initial unsettled widget screenshot and
early denial image as excluded attempts; subsequent confirmation is separate.

Independently compared saved preinstall, restored and final inspection fields
(note, checks, done, unitKey) and photo IDs: identical. This addresses the app-local
evidence gap recorded in this iteration; it is not a runtime retention fix.
The app's saved native/archive photo-hash receipt also reports equality.

Compared saved native baseline (outbox 2, incoming absent) with pre-foreground
effects (outbox 0, incoming row and exact outgoing objects). Independently matched
raw worker-full-logcat.txt: PID 8052 begins 04:37:41.347, completes 04:37:42.574
and reports native BackgroundWorker SUCCESS at 04:37:42.585. Raw activation
files are byte-identical, SHA256
19b5f47e09b7fb6a1ca88b43c87fd6ceecd898905e669fd651019e217bfe9b10,
pending 1793659499, no trial. One explicitly triggered registered execution
proves no natural cadence; the 462.717-second observer wait is not callback
duration. Final foreground commitment is later evidence.

The app reports doctor 14 PASS / 10 WARN / 0 FAIL. Preserve structured child-command
receipts separately from PowerShell stderr/wrapper status, and retain release
offline/R27 scope separately from debug bridge/SQLite/OTA scope. Historical
renderer/startup/background/busy-sync/media/doctor findings remain open or
qualified. Kundalini F-72/F-73/F-74 remain app-reported pending adoption and
verification. iOS remains experimental and untested.

Sources are read-only valence-test-app-c/evidence/iteration-69/ and both apps'
findings/reports. Only mirrored integration notes change. Earlier November 3 gates
retain their scope; no fresh full-gate run, device acceptance or runtime security
review is claimed. Exact-tip ancestry, unchanged implementation trees, mirrored
notes and diff hygiene checked. No test-app writes, protected-branch changes,
version/schema changes, push, publication or deployment.

## November 3: iteration 68 evidence intake; implementation unchanged

Reviewed both apps' VALENCE_FINDINGS.md inventories and latest completed reports:
Kundalini 18 and app-c 68. No eligible must-have, changes-requested item or queue
refresh remains. Packages refs remain 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29
(code) and 62f950ba1d52632b47fdd0e170bc41e18d467ae1 (site). Verified all 36
exact recorded tips and both packages refs are ancestors of their integrations.
The tested implementation candidate remains 7385f4e / 1539b66.

Decision: preserve security, users' data and the candidate while app validation
continues. S1 stays deliberately parked; S2 needs a Play account. Successful
retries justify neither weaker trial accounting nor deleting publications or
resetting accounts. No feature, schema or package-version change is warranted.

Replayed app-c 68's saved artifact audit in an isolated context, intercepting its
only write in memory: all 38 checks pass. Independently rehashed archived APKs:
release 54711084 bytes, SHA256
edf89243ca704b08cf6cbb2041c669715c7a90b746c94d19253a32337663e9c1;
debug 168851587 bytes, SHA256
e5d12d3b5d5d2117fb8db25ae00954ccf804ad01be9a7dc7d69c727b00ae7fb1.
No app file changed. Artifact consistency is separate from new device execution.

Settings receipt records return in the same PID 5066. Inspected its saved return
screenshot: painted list, completed inspection, one photo and one installed widget.
Other-process memory-pressure kills do not establish loss of this host; historical
F-36 remains open. Fresh release open completed in 1778 ms. A runner HOME race
invalidated its first screenshot; later foreground paint is separate evidence,
not uninterrupted first-cold paint. Retained accessibility sampling at 32954 ms
includes polling/dump overhead and does not measure exact first paint.

Compared worker baseline (outbox 2, incoming absent) with pre-foreground effects
(outbox 0, incoming row and exact outgoing objects). Independently matched raw
worker-full-logcat.txt: PID 7528 begins 03:36:25.129, completes 03:36:26.297 and
reports native BackgroundWorker SUCCESS at 03:36:26.306. Raw activation bytes
are identical, SHA256
f6f868cebcb6a1ac55a6689c9044ddcf734dd5c5825fcdb306fa1ecbf511c1f4,
pending 1793655882, no trial. One explicitly triggered registered execution proves
no natural cadence; the 397.253-second observer wait is not callback duration.
Final foreground commitment follows the isolated observation.

Serial doctor reports 14 PASS / 10 WARN / 0 FAIL. Preserve runner timing mistakes,
native stderr/build-output qualifications and release/debug scope boundaries.
Captured preview-doc F-34/F-41 wording remains distinct from adoption fixes already
included here. Kundalini F-72/F-73/F-74 remain app-reported pending adoption and
verification. Historical startup/background/busy-sync/media/doctor findings stay
open or qualified; iOS remains experimental and untested.

Sources are read-only valence-test-app-c/evidence/iteration-68/ and both apps'
findings/reports. Only mirrored integration notes change. Earlier November 3 gates
retain their original scope; no fresh full-gate run, device acceptance or runtime
security-review pass is claimed. No test-app writes, protected-branch changes,
version/schema changes, push, publication or deployment.

## November 3: iteration 67 evidence intake; implementation unchanged

Reviewed both apps' VALENCE_FINDINGS.md and newest completed reports: Kundalini 18
and app-c 67. No eligible must-have, changes-requested item or queue refresh
remains. Packages refs remain 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 (code)
and 62f950ba1d52632b47fdd0e170bc41e18d467ae1 (site). Verified all 36 exact
recorded tips and both newest packages refs are ancestors of the integrations.
The tested implementation candidate remains 7385f4e / 1539b66.

Decision: preserve security, users' data and the candidate while the apps exercise
it. S1 stays deliberately parked; S2 needs a Play account. Do not weaken trial
accounting, delete runtime publications, reset accounts or infer a lock owner from
successful retries. No new feature, schema or package version is claimed here.

Replayed app-c 67's saved artifact audit in an isolated context, intercepting its
only write in memory: all 38 checks pass. Independently rehashed both archived
APKs: release 54711088 bytes, SHA256
1ede080888847bb2d18b4172da3c0b0c53ae307baa8dd0532c9e29fc9b24f874;
debug 168851587 bytes, SHA256
7e3317ab7c0ef706655e2963df81cb34e5eff2e3241484d5aaa46c9caa1c9344.
No app file was changed. Artifact consistency is separate from device execution.

Settings receipt records return in the same PID 5008. Inspected its saved return
screenshot: painted list, completed inspection, one photo and one installed widget
are visible. Other processes killed under memory pressure in the saved inventory
are not this host. This success closes no historical F-36 renderer-loss finding.

Compared native worker baseline (outbox 2, incoming absent) with pre-foreground
effects (outbox 0, incoming row and matching outgoing objects). Independently
matched raw worker-full-logcat.txt: PID 7682 begins 02:35:41.500, completes
02:35:42.797 and reports native BackgroundWorker SUCCESS at 02:35:42.810.
Raw activation files are byte-identical, SHA256
e87ab43984e79b8e88801cc41eaaf43c586c7e411285e8f70c6f9bde57893c78,
pending 1793652234, no trial. One explicitly triggered registered execution proves
no natural cadence. The 397.292-second observer wait is separate from callback
execution and cross-clock timing; final foreground commitment is later evidence.

Fresh release open completes in 1648 ms. Retained positive accessibility sampling
at 22223 ms includes polling/dump overhead; fresh accessibility yielded no app text
and was excluded in favor of inspected image evidence in the app's report. Neither
establishes exact first paint. Serial doctor reports 14 PASS / 10 WARN / 0 FAIL.
Preserve copied-input, quoting and unsupported Flutter invocation corrections,
raw native stderr/build warnings and failed attempts as qualified by runner notes.
Captured preview-doc F-34/F-41 observations remain distinct from adoption docs
already included here. Kundalini F-72/F-73/F-74 remain app-reported observations
pending adoption and verification. Historical startup, background, busy-sync,
media lifetime and doctor findings stay open.

Sources are read-only valence-test-app-c/evidence/iteration-67/ and both apps'
findings/reports. Only mirrored integration notes change. Earlier November 3 gates
retain their original scope; no fresh full-gate run, emulator acceptance or runtime
security-review pass is claimed. No test-app writes, protected-branch changes,
version/schema changes, push, publication or deployment.

## November 3: iteration 66 evidence intake; implementation unchanged

Read both apps' VALENCE_FINDINGS.md and newest completed reports: Kundalini 18
and app-c 66. No eligible must-have, changes-requested item or queue refresh
remains. Packages refs remain 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 (code)
and 62f950ba1d52632b47fdd0e170bc41e18d467ae1 (site). All 36 exact recorded tips
and both newest packages refs are ancestors of their respective integration HEADs.
The tested implementation candidate remains 7385f4e / 1539b66.

Decision: preserve security, users' data and the candidate while the apps exercise
it. S1 remains deliberately parked; S2 needs a Play account. A successful retry is
not a reason to weaken trial accounting, delete runtime publications, reset an
account, infer a lock owner or close a historical reliability finding.

App-c 66 records a painted Settings return in the same PID 5285. Inspected the
saved screenshot: the retained list, completed inspection, original photo count
and installed widget count are visible. This attempt succeeds; iteration 65's
renderer/host termination and historical F-36 remain failures. The saved Settings
log inventory includes other processes killed for memory pressure; those lines
must not be mistaken for termination of this attempt's host.

Replayed the saved artifact audit in an isolated context, intercepting its only
write in memory: all 40 checks pass, including independent rehashing of both
archived APKs. No app file was changed. This checks saved artifact consistency,
not new device execution or unconditional reliability acceptance.

Compared native worker baseline (outbox 2, incoming absent) with pre-foreground
effects (outbox 0, incoming row and matching outgoing objects). Independently
matched raw worker-full-logcat.txt: PID 8053 begins 01:36:59.444, completes
01:37:00.990 and reports native BackgroundWorker SUCCESS at 01:37:00.999.
Raw activation files are byte-identical, SHA256
93c0b5a9c0bfd823f2cc4bafeae26fa09ea99ce239dd68d08f083ba1c24d4335,
pending 1793648772, no trial. One explicitly triggered registered job establishes
no natural eligibility or cadence. The later final commit is separate.

The initial ADB forward timeout precedes the second permission request; actual
denial and resumed grant remain separate evidence. Immediate post-restore offline
sync during a connectivity transition is separate from settled reconnect success.
Serial doctor reports 14 PASS / 10 WARN / 0 FAIL. Fresh release open completes in
668 ms; retained positive accessibility sampling at 39050 ms includes polling and
dump overhead, and is not exact first paint. Historical startup, busy-sync,
background, media lifetime and doctor qualifications remain open. Kundalini's
F-72/F-73/F-74 remain app-reported observations pending adoption and verification.

Sources are read-only valence-test-app-c/evidence/iteration-66/ and both apps'
findings/reports. This intake changes only mirrored integration notes. Earlier
November 3 gates retain their original scope; no fresh full-gate, emulator
acceptance or runtime security-review pass is claimed. No test-app write,
protected-branch change, schema/version change, push, publication or deployment.

## November 3: iteration 65 evidence intake; implementation unchanged

Read both apps' VALENCE_FINDINGS.md, including the historical finding inventories,
and newest completed reports: Kundalini 18 and app-c 65. No eligible must-have,
changes-requested item or queue refresh remains. Both packages refs are still
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 (code) and
62f950ba1d52632b47fdd0e170bc41e18d467ae1 (site). Verified all 36 exact tips in
the inclusion table, and each current packages ref, are ancestors of the respective
integration HEAD. The tested implementation candidate remains 7385f4e / 1539b66.

Decision: preserve security boundaries, users' data and the candidate while the apps
exercise it. Keep S1 parked and S2 blocked on a Play account. Do not weaken trial
accounting, delete runtime publications, reset an account or infer a lock owner from
a successful retry. No feature or schema number is newly claimed in this intake.

App-c 65 adds another confirmed F-36 Settings failure. Independently matched raw
settings-return-full-logcat.txt: renderer 5577 killed for minimum watermark at
00:24:20.634, host 5499 reports unhandled renderer loss/killing application at
00:24:20.726, and host death at 00:24:20.847. Exit-info identifies renderer LOW_MEMORY
and host SIGNALED/status 9. Inspected settings-return-before-recovery.png: blank
content. The recorded replacement is PID 6443. Later native successes are recovery
evidence; no framework leak, blocked owner or trial-loss cause is established.

Replayed the app's saved artifact audit in an isolated context with every write
intercepted in memory: 40 checks pass, explicitly including preservation of the
failed Settings result. This verifies saved artifact consistency, not new device
execution. The first replay stopped before checks because of a UTF-8 BOM in the
script; stripping the BOM in memory allowed the replay. No app file was changed.
The replay independently rehashed the archived APKs against their saved receipts.

Compared native worker baseline (outbox 2, incoming absent) with pre-foreground
effects (outbox 0, incoming row and matching outgoing objects). Saved worker logs
record PID 8551 begin 00:38:27.498, complete 00:38:28.892 and BackgroundWorker
SUCCESS 00:38:28.904. Independently compared raw activation bytes: identical,
SHA256 cd94971284383ded4f286a5e54705f22ce6eb4f151153a2c515d8c784d6941c7,
pending 1793645361, no trial. One explicitly triggered worker establishes no cadence.

Accepted current offline probes report offline/pending 1 and reconnect drains to 0;
they do not close iteration 64's busy-sync finding or reproduce the original COMMIT
exception. Serial doctor reports 14 PASS / 10 WARN / 0 FAIL; its initial concurrent
mapped-test failure remains separate. Fresh release open completed in 1922 ms;
retained positive accessibility sampling at 47350 ms includes dump overhead and
does not establish exact first paint. Preserve historical startup, background and
doctor qualifications. Reminder retry listener duplication establishes no event
cardinality. Kundalini's F-72/F-73/F-74 remain app-reported evidence; existing
integration work must be adopted before claiming those app observations resolved.

Sources are read-only valence-test-app-c/evidence/iteration-65/ and the two apps'
findings/reports. This intake changes only mirrored integration notes. Earlier
November 3 gates below retain their original scope; no fresh full-gate, emulator
acceptance or runtime security-review pass is claimed. No test-app write, protected
branch change, package-version change, push, publication or deployment.

## R32: larger compiled HTTP responses, with the bridge cap preserved

This supersedes the previous ready candidate. Implementation bases are packages
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 (code) and
62f950ba1d52632b47fdd0e170bc41e18d467ae1 (site); both remained unchanged.
Implementation checkpoints before the final documentation commit: 7eeb9ad943df656ba8dd7448df12c1dd6834a580 / f7a8aa7f87793bc7b4572bbf3ed3bad0b60ef992.
The final ready tips are recorded in the shared roadmap.

Rebuilt codex/integration from packages in both worktrees. Revisited the original
31 recorded tips (already upstream), fast-forwarded R32, then merged R33, S8,
pending-ID adoption and permissions adoption, in that order. All 36 exact tips
below are verified ancestors in both repositories. R32 precedes R33; all reserved
schema numbers, since values, package versions and the schema-19 template remain
unchanged. Previous candidates are retained in codex/integration-before-r32-20261102.

Decision: security first, keep the escaped 262144-byte bridge envelope and fixed
65536-byte request cap; grant larger decompressed responses only in native compiled
config. This serves the real 133712-byte REST response without giving a page or OTA
a way to increase a native limit. Runtime code/tests for R32 and R33 remain identical
to their reviewed feature branches. Config loading/codegen/doctor preserve both
validators; runtime forwards the grant beside the existing jar. Security review
found no confirmed issue in the combined intersections; four focused CLI tests and
example codegen --check passed. Documentation merges preserve every feature addition.

Manual conflicts were confined to README/changelog/sidebar/llms documentation.
An initial text resolution dropped README sections; comparison with exact branch
sources caught it before gates, and the files were reconstructed with R32, R33 and
S8 plus all previous sections. Final comparison with the previous integration confirms
only the intended additions; its R33 wording correction and historical ledger are
preserved. The REST FAQ now describes the existing compiled cookie grant accurately.

Read both findings and newest completed reports at intake, Kundalini 18 / app-c 64,
read-only. App-c's current busy-sync failure remains distinct from later recovery;
no original COMMIT recurrence, lock holder or root cause is inferred. Historical
renderer/startup/background/doctor findings remain qualified. R32's native Android
example probe passes with durable screenshot/log receipts in docs/evidence/r32/;
its scope is synthetic HTTP and reply encoding, not full WebView or release-device
acceptance. iOS remains experimental and untested.

## Fresh combined gates (overnight November 2-3)

| Gate | Result |
|---|---|
| npm test | 115 pass, zero failures/skips; generated Dart and TS checks executed |
| Core flutter test --concurrency=1 | 617 pass |
| Core dart analyze --fatal-infos . | No issues |
| Core pub publish --dry-run | 0 warnings |
| Push tests / fatal-info analysis / pub dry run | 2 pass / no issues / 0 warnings, 1 existing override hint |
| Bridge tests / strict-verbatim TS / pack dry run | 36 pass / pass / pass |
| Example tests | 29 pass |
| Example debug APK | Pass, assembleDebug 17.7 seconds |
| Standalone Windows py Firebase audit | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |
| Separate dev diagnostics regression | 1 pass, serial rerun |
| Root pack dry run | Pass |
| Site build and SEO | 50 pages pass |
| Example codegen --check | Pass, no written files |

The first extra dev-regression invocation collided with the running core suite's
Windows sqlite3.dll and failed with PathAccessException. It is not a passing result;
after core completed, the identical command passed serially. Feature-branch initial
failures and corrections remain in docs/r32-validation.md. Raw gate logs are retained
locally in %TEMP%/valence-r32/integration/. Final documentation/receipt encoding cleanup
does not change executable code; package dry runs are checked again after committing.
No protected branch change, test-app write, push, publication or deployment.

## Actual later merge commits

| Branch | Code | Site |
|---|---|---|
| codex/r32 | fast-forward 3d1fa7f | fast-forward cc7831b |
| codex/r33 | 00c11a3 | 4f512d2 |
| codex/s8 | 14a1a7f | b8d08fd |
| codex/pendingids-adoption | 669541a | 5ea9f19 |
| codex/permissions-adoption | 8d11ae0 | 001ec10 |

## Current exact inclusion order

| Order | Branch | Code tip | Site tip |
|---|---|---|---|
| 1 | codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| 2 | codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| 3 | codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| 4 | codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| 5 | codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| 6 | codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| 7 | codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| 8 | codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| 9 | codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |
| 10 | codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| 11 | codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| 12 | codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| 13 | codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| 14 | codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| 15 | codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| 16 | codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| 17 | codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| 18 | codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| 19 | codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| 20 | codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| 21 | codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| 22 | codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| 23 | codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| 24 | codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| 25 | codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| 26 | codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| 27 | codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| 28 | codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| 29 | codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| 30 | codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| 31 | codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| 32 | codex/r32 | 3d1fa7f53ed9f61ff12295cb53e7bb4d991813de | cc7831bcbee4f3c63972bcaa8e9a904313eba53f |
| 33 | codex/r33 | ea9e63cf96f1b459672b2e58cf986567f7996c8c | 0e23509e1d98efba98feae7a126ded919cd88daf |
| 34 | codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |
| 35 | codex/pendingids-adoption | 886a9f92a21228c14e33c290796f522accb5f6c3 | 99a8bf76b3d1d32f4080782b0fd8b58f696cd90e |
| 36 | codex/permissions-adoption | 3e7231a3e8d6d842f61ce876ceede20fd69e4d66 | ee4292ce5d60a907457d696abbf318f1c81738cf |

## Previous integration records (historical)

# Integration with current packages - 2026-11-02

## November 2: R33 integrated on the current packages bases

Current candidate: implementation code aecd17d / site 91ca9ef, based on packages
03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 /
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Bases remained unchanged through the gates.
This supersedes the earlier ready candidate; older sections below are historical.

All original queue items are done. Fresh integration revisited the first 31 exact
recorded tips below (already upstream), then R33, S8 and the two adoption-doc
branches. R33 fast-forwarded to ea9e63c / 0e23509. Actual later merge commits:

| Branch | Code merge | Site merge |
|---|---|---|
| codex/s8 | 947c5c2 | c007df6 |
| codex/pendingids-adoption | 0680cce | 0afe3d8 |
| codex/permissions-adoption | 2222e75 | b0edea5 |

Changelog, README and llms conflicts preserve every addition; no runtime conflict
required a behavior choice. Decision: security first, bounded native session grants,
fixed receipt deadlines and revocation, preserving users' data, schema 19 and all
reserved since values. Package versions are unchanged. The R33 runtime and tests
remain identical to the independently reviewed feature branch. Both CLI copies
match. All 35 exact tips below are independently verified ancestors in both repos.

Read both findings and newest completed reports at intake, Kundalini 18 / app-c 63,
read-only. Raw saved evidence confirms app-c renderer 5193 low-memory kill, Chromium
terminating host 5113, and replacement 7249 BIND APPLICATION ANR after exact-alarm
revocation. Recovered checks do not close F-36/F-35, establish a leak/lock cause or
prove trial loss. Historical doctor F-43 is not erased by current success. No new
emulator acceptance is claimed; iOS remains experimental and untested.

## Fresh combined gates

| Gate | Result |
|---|---|
| Root npm test | 114 passed, zero failures/skips; generated Dart and strict/verbatim TS included |
| Runtime flutter test --concurrency=1 | 615 passed |
| Runtime dart analyze --fatal-infos . | No issues |
| Core pub dry run | 0 warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / no issues / 0 warnings, 1 local-override hint |
| Bridge tests / strict TS / pack dry run | 36 passed / passed / passed |
| Example tests | 29 passed |
| Example debug APK | Passed, 13.7 seconds |
| Standalone Windows py Firebase audit | PASS: core graph and all 19 DEX files / manifest contain no Firebase SDK references |
| Root pack dry run | Passed |
| Site build and SEO | 49 pages passed |

Independent security review of R33, its failed-storage hardening and the combined
S8/debugging interaction found no confirmed unresolved implementation defect.
The restored ledger's old header and an extra EOF blank line were identified and
corrected before handoff. Initial R33 brace-analysis failure and dirty-package pub
warning are recorded separately in docs/r33-validation.md, with clean reruns; neither
is counted as a pass. No protected branch changes, version bump, test-app writes,
push or publication. R32 remains todo for a separate branch/run.

## Current exact inclusion order

| Order | Branch | Code tip | Site tip |
|---|---|---|---|
| 1 | codex/r8 | 91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e | 072552f08d626d2915e63e7fda2c4c183c4380e3 |
| 2 | codex/r7 | 969b1a4fb03d76d2af85c69987c4ed5eeb0eb840 | 965b8eb83a7412a9ec601919f227c2c0005a9252 |
| 3 | codex/r6 | 5b64e06051fab10e0a01d8b3215c17f45d81c980 | 388cd9d3c0fd6043cfa21b0a6440916232847742 |
| 4 | codex/r3 | db669ddd75ffeb97588fd62304122a58c242f3b0 | f45ccf28d741a2c6e05c766eeb6bff059900bcc5 |
| 5 | codex/r4 | 588f8761807b1893933303533a04fa14c9975a6f | d8e5dd775dfaf902e206bc2f195c30537f797ba4 |
| 6 | codex/r5 | 3cc1c0f4d062d13919adcfe5343434e00098fdea | 57a44b50dfd82800f151823ff1563d8a73340678 |
| 7 | codex/r9 | 0c1b0fb01a48494991cdae4ab32369fb6a2af7b2 | 2913b4d0a743188808a66bd5b7db416ca870c52f |
| 8 | codex/r10 | f3fcd0dac875fc30af226c7f1bf70750942c0550 | b905b742ab9d90984d513cdf7b99977eabd929f2 |
| 9 | codex/r14 | fa6e16c55d84bb9a3162514a9c09b65cb634fd54 | fa5e8164a968bd74d943b8a50590dfbd010e08ca |
| 10 | codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| 11 | codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| 12 | codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| 13 | codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| 14 | codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| 15 | codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| 16 | codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| 17 | codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| 18 | codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| 19 | codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| 20 | codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| 21 | codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| 22 | codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| 23 | codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| 24 | codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| 25 | codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| 26 | codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| 27 | codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| 28 | codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| 29 | codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| 30 | codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| 31 | codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| 32 | codex/r33 | ea9e63cf96f1b459672b2e58cf986567f7996c8c | 0e23509e1d98efba98feae7a126ded919cd88daf |
| 33 | codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |
| 34 | codex/pendingids-adoption | 886a9f92a21228c14e33c290796f522accb5f6c3 | 99a8bf76b3d1d32f4080782b0fd8b58f696cd90e |
| 35 | codex/permissions-adoption | 3e7231a3e8d6d842f61ce876ceede20fd69e4d66 | ee4292ce5d60a907457d696abbf318f1c81738cf |


## November 2: refresh on the debugging/checklist packages bases

Fresh integration starts at code 03025560651d9df41fe4a7d6d0cc3ff4a12d3b29 / site
62f950ba1d52632b47fdd0e170bc41e18d467ae1. Revisited all 34 recorded tips in the
merge-order table below, in that order. The first 31 are already ancestors of
packages; the three remaining merges are:

| Order | Branch | Code tip | Site tip | Code merge | Site merge |
|---|---|---|---|---|---|
| 32 | codex/s8 | 3f44455 | 05943aa | 5ebd247 | a446966 |
| 33 | codex/pendingids-adoption | 886a9f9 | 99a8bf7 | 685e6df | d415a00 |
| 34 | codex/permissions-adoption | 3e7231a | ee4292c | 196b333 | b8a879e |

Changelog conflicts retain both features; llms.txt retains both upstream debug
inspection/traceBridge guidance and S8 completion semantics. Restored the previous
integration ledger intact as historical evidence. Decision: preserve security,
data and the reserved schema numbers; no behavioral shortcut resolves a conflict.
Schema 19 and every feature's since remain intact; package versions are unchanged.

Read both findings ledgers and newest completed reports at intake: Kundalini 18 /
app-c 63, read-only. Raw saved logs independently confirm renderer 5193 low-memory
kill followed by Chromium terminating host 5113, and replacement 7249 BIND
APPLICATION ANR after exact-alarm revocation. Recovered successes do not close
F-36/F-35, establish a leak/lock cause or prove trial loss. Current doctor success
does not erase historical F-43. No new emulator acceptance is claimed.

Fresh gates on this integration:

| Gate | Result |
|---|---|
| npm test | 114 passed, zero failures/skips; generated Dart and TS included |
| Runtime flutter test --concurrency=1 | 610 passed |
| Runtime dart analyze --fatal-infos . | No issues |
| Core pub dry run | 0 warnings on committed package; initial dirty-changelog warning retained separately |
| Push tests / fatal-info analysis / pub dry run | 2 passed / no issues / 0 warnings, 1 local-override hint |
| Bridge tests / strict TS / pack dry run | 36 passed / passed / passed |
| Example flutter test | 29 passed |
| Example debug APK | Passed, 909.3 seconds |
| Standalone Windows py Firebase audit | PASS: core graph and all 19 DEX files / manifest contain no Firebase SDK references |
| Root pack dry run | Passed |
| Site build and SEO | 48 pages passed |

Independent valence-reviewer pass found no confirmed defects in the combined
S8/adoption delta and its interaction with upstream debugging tools. It traced
canonical verification, authenticated completion, coalescing, detach, native policy
and dev guards; independently ran bridge tests and example codegen --check.
No protected branch writes, pushes, publication or test-app writes occurred.


## November 2: iteration-62 doctor timeout, startup and artifact qualifications

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 62,
read-only. No must-have or original queue refresh is eligible. Packages bases
remain code 90af361 / site 6eb2bd6; both bases and all 34 exact tips in the current
merge-order table are ancestors of both integrations. Compared implementation
trees against pre-ledger merge heads 809aae1 / bdbb727: unchanged outside this
ledger. No integration rebuild is needed on unchanged bases and branch tips.

Failure first: new F-43 retains two distinct doctor attempts. Initial --tests
execution exits 1 and reports the mapped bridge Flutter test failed. The serial
retry is terminated at its wrapper's 300-second limit with status null, SIGTERM,
ETIMEDOUT and a zero-byte stdout file. Plain doctor's saved result subsequently
contains 13 PASS / 11 WARN / 0 FAIL, including "mapped but not executed; pass
--tests". It neither replaces those failures nor proves mapped-test acceptance.
The app reports twelve standalone Flutter tests passing separately. There is no
phase evidence assigning the timeout to key scanning, Flutter, or assertions;
do not bypass the signing-key scan or silently raise a timeout as a fix.

Startup remains qualified: saved PID 5005 trace completes open at 39037 ms,
store phase at 37774 ms and store.configure at 21448 ms. Named waits establish
where time was observed, not the lock holder or cause. The initial 30-second
splash is excluded. Retained PID 4698 open completes at 396 ms; a later retained
paint observation cannot be treated as exact first-paint latency.

Raw restore logs independently confirm system_server 5633 watchdog termination
at 19:22:11.122 after main-thread blockage for 76 seconds, then 6203 at
19:27:42.509 after 61 seconds. The restore hash receipt matches local and remote
archives. This is Android system-service interruption with subsequent recovery,
not proof that Valence caused it. The stable busy-sync receipt retains lease
1793627227806:9334 and outbox 2; later same-PID completion is separate evidence.
Elapsed time alone establishes no lease violation or blocked owner.

Successful receipts retain their narrower scope:

- The saved artifact audit lists 80 passing consistency checks, explicitly
  excluding unconditional acceptance and retaining failed/obscured attempts.
- Settings returned painted in PID 9334 on this attempt. It closes no historical
  renderer-loss finding; the initial SystemUI overlay is excluded.
- Raw logcat confirms new worker PID 13302 begin 19:48:34.203, complete
  19:48:35.555 and matching BackgroundWorker SUCCESS at 19:48:35.566. The saved
  stable SQLite receipt records exact outgoing objects, incoming row and outbox
  0 before foreground. One registered execution establishes no recurring cadence.
- Independently hashed raw activation files are byte-identical, SHA256
  9d5fdbf805a8e3d69682ae340b7fe11c8c3132a2c2d52401a89cb85c0f2122d9:
  current 1793628042, pending 1793628053, trial null before foreground.
- Build/install/scan receipts survive, but the final mobile/build directory
  disappeared for an unknown reason. Independently hashed recovered installed
  debug APK is 168857631 bytes, SHA256
  14579332e0b6b32343a8226f37c96b0e3ef9b90c71b120ed9fdca417123e983c,
  matching the build receipt. No final persisted release APK is claimed.

Evidence: valence-test-app-c/evidence/iteration-62, especially
doctor-initial-{execution.json,failed.txt}, doctor-serial-timeout-{execution.json,txt},
doctor-mechanical-summary.json, r29-startup.json, restore-os-full-log.txt,
restore-archive-integrity.json, sync-diagnostics-result.json, settings-outcome.json,
worker-{completion-proof.json,full-logcat.txt}, background-sqlite-before-resume.json,
background-state-{before-raw.json,after-raw.json,comparison.json}, evidence-audit.json,
binary-{hashes.json,delivery-state.json}; recovered APK under
.valence/preupgrade/iteration62-installed-debug.apk.

Decision: preserve security checks, users' data, durable URL semantics and the
candidate freeze. F-43 deserves progressive phase/child-command diagnostics,
but current evidence establishes no runtime fix or permission to weaken checks.
F-42/F-36/F-27 and startup qualifications remain for the improver's release
assessment. Kundalini 18 has not accepted S6/S7/S8; S1 remains deliberately parked
and S2 needs a Play account.

Only mirrored integration notes change. Exact-tip ancestry, unchanged
implementation trees, raw activation/APK hashes and diff hygiene were checked.
Earlier November 2 gates retain their scope; no fresh full-gate, device or
runtime-review pass is claimed. No test-app writes, protected-branch changes,
version/schema changes, push or publication.

## November 2: iteration-61 worker process loss and Settings recurrence

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 61,
read-only. All must-haves remain done; no original queue refresh is eligible.
Packages bases remain code 90af361 / site 6eb2bd6. Both bases and all 34 exact
recorded branch tips are independently confirmed ancestors of both integrations.
No integration rebuild is needed on these unchanged bases.

Failure first: F-42 is a failed post-emulator-restart background attempt. Raw
logcat records callback begin in PID 3115 at 16:14:35.159, lowmemorykiller killing
that process at 16:14:37.212 and host death at 16:14:37.734. Decoded native
exit-info independently records LOW_MEMORY at 16:14:37.736. The 340.996-second
result-observation window is not live worker execution or evidence of a hang.
The separate DiagnosticsWorker SUCCESS in that PID is not BackgroundWorker
success. Supplied stable native SQLite receipts retain outbox 2/incoming absent
before foreground; no mock transfers, callback completion or matching worker
SUCCESS were recorded. PID 4760's later foreground sync is recovery only.

Earlier post-boot PID 2150 failed startup: raw ActivityManager logs at
16:09:26.828 match exit-info ANR/BIND APPLICATION ANR at 16:09:26.832. SystemUI
also had a service ANR at 16:08:34.644. This records environment pressure and
process loss, not a proven Valence leak, initialization defect or recurring cadence.

F-36 also recurred. Raw Settings logs show renderer 5095 killed at
15:53:37.406, Chromium in host 4983 explicitly terminating the application at
15:53:37.498 and host death at 15:53:37.816. Exit-info matches renderer LOW_MEMORY
and host SIGNALED/status 9. Replacement PID 6548 and the failed page/CDP receipt
establish no same-process Settings survival; later successes do not erase it.
No trial loss is established in this attempt.

Other independently compared saved receipts:

- The artifact audit contains 64 passing consistency checks and explicitly retains
  F-42/F-36. Its pass is not unconditional device acceptance.
- Raw activation files are byte-identical, independently hashed SHA256
  793d87b0cb4570652eea5bd505c7f26e2054453dc91b893cea4b1fd949c71013:
  current 1793614837, pending 1793614847, trial null before recovery.
- Four resolves produce four distinct URLs and matching-original hash receipts.
  Decoded native listings grow from 1624 to 1628 payloads; the exact eight new
  names match those URLs and their sidecars. Native du reports 329892 KiB of
  host publications versus 224 KiB original media. This repeats app-path
  republication, not an unexplained package leak or generalized growth rate.
- Retained startup PID 4270 logs store phase 4368 ms/open completion 4530 ms.
  The initial 9550 ms accessibility positive used stale XML and is excluded.
  The fresh-dump confirmation is after an explicit link; neither pre-link paint,
  exact first paint nor startup cause is established.

Evidence: valence-test-app-c/evidence/iteration-61, particularly
background-observation-failure.json, background-sqlite-{before-worker,after-bounded-observation}.json,
bounded-worker-full-log.txt, postboot-app-exit-info.txt, bounded-worker-native-files.json,
both background-state raw files, settings-outcome.json, settings-return-full-logcat.txt,
settings-return-exit-info.txt, evidence-audit.json, host-retention-{experiment.json,before.txt,after.txt,size.txt},
r29-retained-startup.json and release-retained-confirmation.json. The original
paint-observation receipt is superseded by the report's explicit stale-XML exclusion.

Decision: preserve security, users' data, durable URL semantics and the candidate
freeze. Do not weaken trial attribution or sync leases to mask process death;
do not delete publications without a supported lifetime contract. F-42, F-36
and F-27 remain major release qualifications for the improver. A cold-worker
reproduction with phase/owner evidence is needed before assigning a runtime fix.
Pending-ID and permission adoption corrections already exist in integration;
older app captures establish no adoption. Kundalini has not accepted S6/S7/S8.
S1 remains deliberately parked; S2 needs a Play account.

Only matching integration ledgers change. Ancestry, mirrored notes, unchanged
implementation trees and diff hygiene were checked. Earlier November 2 gates
retain their scope; no fresh full-gate, emulator acceptance or runtime-review pass
is claimed. No test-app writes, protected-branch changes, version/schema changes,
push or publication.


## November 2: iteration-60 Settings renderer loss and retained publication evidence

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 60,
read-only. All must-haves remain done; no original rebase-queue refresh is eligible.
Packages bases remain code 90af361 / site 6eb2bd6. Independently checked both bases
and all 34 exact recorded branch tips as ancestors of the current integrations.
No feature branch or integration rebuild is needed on these unchanged bases.

Current failure first: the raw Settings log records Android killing renderer 5029
for low watermark at 14:47:34.330, Chromium in host 4952 explicitly terminating
the application at 14:47:34.412, and ActivityManager recording host death at
14:47:34.529. Exit-info independently matches renderer LOW_MEMORY and host
SIGNALED/status 9 at those timestamps. The returned PID is 6015, not 4952;
the saved outcome records no painted page and a closed CDP connection before
recovery. Later feature successes do not establish Settings survival. This is
a current F-36 recurrence of the Android limitation already specified in S5,
not evidence of a framework memory leak or a trial loss in this attempt.

Other independently compared saved receipts:

- The artifact audit lists 62 passing consistency checks and explicitly retains
  the F-36 failure. Its pass is not unconditional device acceptance.
- Four resolves return four distinct URLs. Native listings grow from 1583 to
  1587 payloads and sidecars; the exact eight added names match those URLs.
  All four recorded hashes match the original. Native du reports 321316 KiB
  of host publications versus 224 KiB of original media. This repeats app-path
  republication, not an unexplained package leak or a generalized growth rate.
- Retained startup PID 4322 logs store phase 4688 ms and open completion 4906 ms.
  First positive sampled accessibility observation is 29426 ms before the
  explicit link; this establishes neither exact first paint nor startup cause.
- One registered worker was explicitly triggered after captured Ready:true and
  elapsed earliest time. Begin 15:02:37.425, complete 15:02:38.818 and native
  SUCCESS 15:02:38.831 share PID 7890. Exact full-log lines are absent from the
  before capture. One forced execution proves no natural eligibility or cadence.
- Supplied stable native SQLite receipts show outbox 2 / incoming absent before
  the worker, then incoming origin 1470000 / usn 1470002 and outbox 0 before
  foreground. Both outgoing objects match their exact saved write parameters.
- Raw activation files are byte-identical, independently hashed SHA256
  d6e32e08a9121d2cc2be11b039c5125e8b0d04cdfb52d22463a55703b4581e3f:
  current 1793610605, pending 1793610615, trial null. The report records the final
  commit and cleanup after this observation.

Evidence: valence-test-app-c/evidence/iteration-60, especially settings-outcome.json,
settings-return-full-logcat.txt, settings-return-exit-info.txt, evidence-audit.json,
host-retention-{experiment.json,before.txt,after.txt,size.txt}, r29-retained-startup.json,
release-retained-paint-observation.json, worker-completion-proof.json,
worker-full-logcat.txt, background-full-log-before.txt, background-force-qualification.json,
both native SQLite receipts, worker-write-{a,b}-params.json and both raw activation files.

Decision: preserve security, users' data, durable URL semantics and the candidate
freeze. Do not weaken trial crash detection to hide Android renderer termination;
S5 already prices the native recovery change separately. Do not delete retained
publications without a supported lifetime contract. F-36 and F-27 remain major
release qualifications for the improver; successful recovery closes neither.
Pending-ID and permission adoption corrections already exist in integration;
older app captures establish no adoption. Kundalini has not yet accepted S6/S7/S8.
S1 remains deliberately parked; S2 needs a Play account.

Only matching integration ledgers change. Ancestry, mirrored notes, unchanged
implementation trees and diff hygiene were checked. Earlier November 2 gates
retain their scope; no fresh full-gate, emulator acceptance or runtime-review pass
is claimed. An initial audit command incorrectly used git rev-parse --short with
two revisions; separate full-revision output corrected it and all checks passed.
No test-app writes, protected-branch changes, version/schema changes, push or publication.


## November 2: iteration-59 retained startup and controlled publication evidence

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 59,
read-only. Every must-have remains marked done; no original rebase-queue item is
eligible. Packages bases remain code 90af361 / site 6eb2bd6. Independently checked
both bases and all 34 exact recorded tips as ancestors of the integrations.
No new feature branch or integration rebuild is needed on these unchanged bases.

Independently compared the saved iteration-59 receipts:

- The artifact audit lists 63 passing consistency checks. This is saved artifact
  consistency, not another device execution or an unconditional acceptance pass.
- Four sequential resolves return four distinct publication URLs. Decoded native
  listings grow from 1546 payloads and sidecars to 1550 of each; the exact eight
  added filenames match the four URLs and their sidecars. All four saved payload
  hashes match the original. Native du reports 313620 KiB of host publications
  versus 224 KiB of original media. The app's mediaResolve republishes every call;
  the runtime creates a random publication id and persists its payload and type.
  This repeats controlled app-path duplication, not an unexplained package leak
  or a generalized growth rate. No historical publication was removed.
- Raw retained-release logs show PID 4227 completing the store phase in 6383 ms;
  the startup receipt reports open completion at 6478 ms. Native accessibility
  first samples list text at 20823 ms before the explicit link. These observations
  establish neither exact first paint nor the delayed operation's owner or cause.
- Mixed-picker invocation exits successfully. Android reports WARM / TotalTime
  3240 ms, and the separate settled page receipt shows Flat 2. Settings returns
  painted in original PID 4969. These successes close no intermittent finding.
- One registered worker was explicitly triggered after captured Ready:true and
  elapsed earliest time. The receipt retains the forced-execution qualification;
  it proves no natural eligibility or cadence. Callback begin 14:03:57.117,
  completion 14:03:58.620 and native SUCCESS 14:03:58.630 share PID 7376. Each
  exact timestamped line is in the full log and absent from the before capture.
- Supplied stable native SQLite receipts show outbox 2 / incoming absent before
  the worker, then incoming origin 1440000 / usn 1440002 and outbox 0 before
  foreground. Both outgoing row values independently match their saved params.
- Raw activation files are independently byte-identical, SHA256
  862f4639be9780f93700f381310b02c08d0f494b5e0d4639fd9d3aa0f540e92b:
  current 1793607051, pending 1793607061, trial null. The app report records the
  final commit and cleanup after this observation.

Evidence: valence-test-app-c/evidence/iteration-59, particularly evidence-audit.json,
host-retention-{experiment.json,before.txt,after.txt,size.txt}, release-retained-
logcat.txt, r29-retained-startup.json, release-retained-paint-observation.json,
mixed-invocation.json, host4-mixed-warm-{launch.txt,ready.json}, settings-outcome.json,
worker-completion-proof.json, worker-full-logcat.txt, background-full-log-before.txt,
worker-execution.json, background-force-qualification.json, both native SQLite
receipts, worker-write-{a,b}-params.json and both background-state raw files.

Decision: preserve security, users' data, durable relative URL semantics and the
candidate freeze. F-27 remains a major product-readiness qualification for the
improver's release assessment. Cleanup or revocation needs a supported lifecycle
contract; deleting publications can break persisted URLs. Bounded app reuse still
needs rebuilt-host restart/rebind/removal validation and cannot reclaim historical
publications. No speculative socket, SQLite or media-lifetime change is justified
by this successful attempt. Historical reliability findings remain open or
qualified. Pending-ID and permission adoption corrections already exist in the
integration; older live app captures establish no adoption. Kundalini has not yet
accepted S6/S7/S8. S1 remains deliberately parked; S2 needs a Play account.

Only matching integration ledgers change. Ancestry, mirrored notes, unchanged
implementation trees and diff hygiene were checked. Earlier November 2 gates
retain their scope; no fresh full-gate, emulator acceptance or runtime-review pass
is claimed. No test-app writes, protected-branch changes, version/schema changes,
push or publication.


## November 2: iteration-58 controlled retention and mixed-picker evidence

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 58,
read-only. All must-haves remain done; no original queue refresh is eligible.
Packages bases remain code 90af361 / site 6eb2bd6. Independently checked both
bases and all 34 exact tips in the current merge-order table as ancestors of the
current integrations. No feature branch or integration rebuild is needed.

Independently compared the saved iteration-58 receipts:

- All 59 artifact consistency checks pass. The audit explicitly retains the
  mixed-picker invocation failure; its pass is not an unqualified device pass.
- Four sequential resolves of one retained immutable photo return four distinct
  publication URLs. Raw native listings grow from 1517 payloads and 1517 sidecars
  to 1521 of each; the exact eight added filenames match the experiment receipt.
  All four published payload hashes match the original. Native du reports
  307728 KiB of publications versus 224 KiB of original media. App mediaResolve
  republishes on every call; the runtime persists a random publication id and
  type sidecar for each call. This establishes repeated-publication duplication
  in this app workflow, not an unexplained package leak or a generalized rate.
- Retained release PID 4435 logs store.open completion at 13467 ms and overall
  open completion at 14013 ms. Native accessibility first observes list text at
  40906 ms before the explicit deep link. That sampled observation is neither
  exact first paint nor evidence of the delayed operation's owner or cause.
- Mixed-picker am start -W exceeded the runner's 30-second deadline. Saved logs
  show two startup completions in PID 7140, initial serving on port 29351,
  a later bind conflict on that port and serving on 29129. The settled page
  reports Flat 2 before recovery. Eventual routing does not erase the failed
  invocation or establish its cause; no new ANR or host death is established.
- Settings returned painted in original PID 5031. This successful attempt closes
  no historical renderer/process-loss finding.
- One registered worker was explicitly triggered, with captured Ready:true and
  elapsed earliest time; the timing-delay constraint remains qualified in the
  app report. Callback begin 13:03:15.101, completion 13:03:16.875 and native
  SUCCESS 13:03:16.885 share PID 7892. These exact full-log lines are absent from
  the before capture. One forced execution establishes no natural cadence.
- Stable supplied native receipts show outbox 2/incoming absent before the
  worker, then incoming origin 1410000/usn 1410002 and outbox 0 before foreground.
  Both outgoing inspection objects independently match their saved write params.
- Raw activation files are independently byte-identical, SHA256
  c5f8b0abc6377b50bee2f08119d88f4a0b1b9fbde8f8289f119e6103b8e3c3e5:
  current 1793603655, pending 1793603665, trial null. The app report records the
  final commit and cleanup after this observation.

Evidence: valence-test-app-c/evidence/iteration-58, especially evidence-audit.json,
host-retention-{experiment.json,before.txt,after.txt,size.txt}, r29-retained-
startup.json, release-retained-paint-observation.json, mixed-timeout.json,
mixed-failure-logcat.txt, mixed-settled-after-timeout.json, settings-outcome.json,
worker-completion-proof.json, worker-full-logcat.txt, background-full-log-before.txt,
worker-execution.json, background-force-qualification.json, both native SQLite
receipts, worker-write-{a,b}-params.json and both background-state raw files.

Decision: preserve security, users' data, durable relative URLs and the candidate
freeze. F-27 now has controlled evidence of repeated-publication duplication and
remains a major product-readiness qualification for the improver's release
assessment. Do not invent runtime deletion/revocation rules: persisted URLs may
still be referenced. Bounded app reuse needs rebuilt-host restart/rebind/removal
validation and would not reclaim historical publications. Mixed-picker ownership
needs investigation rather than a speculative socket or SQLite change. Historical
findings remain open or qualified. Pending-ID and permission adoption corrections
are already in integration; the app's older guide does not establish adoption.
Kundalini has not yet accepted S6/S7/S8. S1 stays parked; S2 needs a Play account.

Only matching integration ledgers change. Ancestry, mirrored notes, unchanged
implementation trees and diff hygiene were checked. Earlier November 2 full gates
retain their scope; no fresh full-gate, emulator acceptance or runtime-review pass
is claimed. No test-app writes, protected-branch changes, version/schema changes,
push or publication.


## November 2: iteration-57 startup and publication-retention evidence

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 57,
read-only. All must-haves remain done. No original queue refresh is eligible:
packages bases remain code 90af361 / site 6eb2bd6, and both integrations contain
all 34 exact branch tips in the current merge-order table. No integration rebuild
or new feature branch is needed.

Independently checked the saved iteration-57 evidence:

- The artifact audit has 57 passing consistency checks. It is an artifact audit,
  not an additional device run or an unconditional acceptance pass.
- Retained release PID 4505 logs store.open id 1 / isolate 4282862 waiting at
  10002 and 20002 ms, completing at 22365 ms; Valence.open completes at 23091 ms.
  The 35-second spinner capture is excluded by the app report. Later offline
  original-photo rendering followed an explicit Flat1 link. Fresh release PID
  4787 completes open at 1023 ms. Open completion is not meaningful paint;
  these timings identify delayed work, not the owner or cause of the delay.
- F-27's raw native listing, decoded as UTF-16LE, contains 1491 payloads and
  1491 sidecars. The native du receipt reports 301604 KiB of host publications
  versus 224 KiB of original media. Independently counted hashes: 28 of 32
  sampled payloads match the original photo. An initial UTF-8 listing reader
  counted zero; decoding the actual file encoding corrected that reader.
  App-owned mediaResolve calls publishHostFile on every resolution; mediaRemove
  deletes the original. The current runtime assigns a new random id per publish
  and persists its payload and type sidecar. This supports duplicate retention
  during cumulative use, not a measured single-call growth rate, original-file
  loss or an isolated framework leak. No runtime-managed file was deleted.
- Settings returned painted in original PID 5121 this attempt. That success
  closes no historical renderer/process-loss finding.
- One registered worker was observed without an explicit force trigger over
  374.529 seconds. Its begin at 12:02:53.006, completion at 12:02:54.191 and native
  SUCCESS at 12:02:54.201 share PID 7650 and occur in the saved full log.
  One observed execution establishes no recurring cadence.
- Supplied stable native SQLite receipts show preworker outbox 2/incoming absent,
  then incoming origin 1380000/usn 1380002 and outbox 0 before foreground.
  Both outgoing inspection objects independently match their saved write params.
- Raw activation files are independently byte-identical, SHA256
  83bc33a5424db35c35ff6d1b290d1c5688f535c192266912a7bc0a759771ae01:
  current 1793599874, pending 1793599884, trial null. The report records final
  commit and cleanup after this observation.

Evidence lives under valence-test-app-c/evidence/iteration-57: release-retained-
logcat.txt, r29-fresh-startup.json, host-data-size.txt, host-published-files.txt,
host-retention-hashes.txt, worker-completion-proof.json, worker-full-logcat.txt,
worker-execution.json, background-sqlite-before-worker.json, background-sqlite-
before-resume.json, both background-state raw files and evidence-audit.json.

Decision: security first, then users' data. Preserve the candidate freeze and
do not invent deletion/revocation semantics for durable URLs or change SQLite
locking from an operation timing alone. F-27 now has stronger major product-
readiness evidence and belongs in the improver's release assessment under the
roadmap's major-finding rule. A supported retention/revocation contract and a
controlled publication experiment are still needed before claiming durable
photo readiness. Historical reliability findings remain open or qualified;
successful attempts do not close them. The pending-ID and permission adoption
corrections are already in integration, without app adoption claimed. Kundalini
has not yet accepted S6/S7/S8. S1 stays parked; S2 needs a Play account.

Only matching integration ledgers change in this follow-up. Ancestry, exact
recorded tips, unchanged implementation trees, mirrored notes and diff hygiene
were checked. Earlier November 2 full gates retain their recorded scope; no
fresh full-gate, emulator acceptance or runtime-review pass is claimed. Security
checks, data, schemas, package versions, templates and build inputs are unchanged.
No test-app writes, protected-branch changes, push or publication.


## November 2: permissions adoption correction (app-c iteration 56)

All must-haves remain done and no original queue refresh was eligible. Read both
findings and newest completed reports, Kundalini 18 / app-c 56, read-only. The
permissions guide's instruction to copy since 10 regardless of app history
contradicted the additive-only rule for newly introduced names. Fieldnote's
already-shipped since-10 declarations need no change.

Decision: preserve shipped contracts and users' data. New permission names use
since >= max(10, shipped store schema version + 1), with app schema version at
least that high; shipped declarations remain unchanged. Ten is the template
introduction version, not a new runtime delegation floor. Both permission guides,
the general bridge guide, contract, package README and machine-readable site
summary agree; the subscription example gates the event with has(). No runtime,
generator, template, schema or package version change was needed. S1 stays parked
under the candidate freeze; S2 needs a Play account. Historical intermittent
findings remain open and Kundalini has not yet accepted S6/S7/S8.

Feature branch codex/permissions-adoption: code 3e7231a / site ee4292c. Independent
feature gates passed: 113 root tests with zero skips (both compile checks ran),
603 core, clean fatal-info Dart, 29 bridge, strict/verbatim TS and 45-page site/SEO.
See permissions-adoption.md. The mirrored permission guides match, and the rendered
page contains the baseline formula, 10-to-11 example and shipped-declaration rule.

### Fresh integration and merge order

Started fresh from packages code 90af3619bb23c88e1a74527b06edfa3489c2c3a6 and site 6eb2bd628b278cb0582a058f2bceaca77e8549ce.
Previous integrations are preserved at
codex/integration-before-permissions-20261102 in both repositories. Replayed the
fixed queue, remaining recorded branches and both adoption-docs branches in the
order below. All 34 exact tips and both bases are ancestors. No conflicts.
Pre-ledger merge heads: code 809aae16109665658fd3ab177511a56095b8c3dd / site bdbb727ab5ac8ae27474e3a91e4abda4713f87cc.
All previous ledger history is retained below with its original evidence scope.

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
| 10 | codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| 11 | codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| 12 | codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| 13 | codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| 14 | codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| 15 | codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| 16 | codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| 17 | codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| 18 | codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| 19 | codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| 20 | codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| 21 | codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| 22 | codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| 23 | codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| 24 | codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| 25 | codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| 26 | codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| 27 | codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| 28 | codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| 29 | codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| 30 | codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| 31 | codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| 32 | codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |
| 33 | codex/pendingids-adoption | 886a9f92a21228c14e33c290796f522accb5f6c3 | 99a8bf76b3d1d32f4080782b0fd8b58f696cd90e |
| 34 | codex/permissions-adoption | 3e7231a3e8d6d842f61ce876ceede20fd69e4d66 | ee4292ce5d60a907457d696abbf318f1c81738cf |

### Fresh gates on the combined tree

| Gate | Result |
| --- | --- |
| Root npm test | 114 passed, zero skips; generated Dart and strict/verbatim TS ran |
| Core Flutter / fatal-info analysis | 609 passed / no issues |
| Core pub publish dry run | Zero warnings |
| Push Flutter / fatal-info analysis | 2 passed / no issues |
| Push pub publish dry run | Zero warnings, existing local-override hint |
| Bridge tests / strict-verbatim TypeScript | 29 passed / passed |
| Root and bridge pack dry runs | Passed |
| Example codegen check / signed builtin verification | No generated changes / seq 1793567181, 2 files verified |
| Example Flutter / fatal-info analysis | 29 passed / no issues |
| Separate compile-time dev-mode regression | 1 passed |
| Example debug APK | Passed; assembleDebug 147.6s, existing app_badge_plus Kotlin migration warning |
| Standalone Windows py Firebase audit | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |
| Site build / SEO | 46 pages passed |
| Diff hygiene and exact-tip ancestry | Passed in both repositories |

Logs: %TEMP%/valence-permissions-integration-*.log. The initial pack wrapper treated
npm notice stderr as a PowerShell error; corrected invocations checked native exit
codes and passed. The first extra verify invocation used the wrong files directory;
the corrected explicit builtin/files path passed. Original logs are retained; no
product failure was hidden. The APK used process-scoped Gradle settings: 2 GiB heap,
1 GiB metaspace, two workers and ActiveProcessorCount=2.

### Saved app evidence and limits

Independently compared iteration-56 receipts: all 57 artifact consistency checks
pass; Settings returned painted in original PID 4635; exact outgoing objects match
their saved write params and stable pre-foreground native receipts report outbox 0.
New worker begin 10:59:37.024, complete 10:59:38.524 and native SUCCESS 10:59:38.533
share PID 7741; those exact full-log lines are absent from the before capture.
The worker was explicitly forced after eligibility; one execution proves no
recurring cadence. Independently hashed raw activation files are byte-identical,
SHA256 7f2577a5b6336371234aa184d09c24878a8c1ef08ae259f92c88191b4454ff29,
current 1793595991 / pending 1793596002 / trial null. Successful Settings/media
attempts close no intermittent finding. App-owned runner corrections establish no
new runtime defect. The existing pending-ID documentation correction remains in
integration; the report's old guide is not evidence of app adoption of that fix.

Security-path checklist: verification order, signatures, nonce and strict decoding,
navigation/subframe lock, atomic writes, keys, permission allowlist/foreground
checks, account isolation, cookie clearing and release-mode dev exclusion are
unchanged. Compared with the previous integration, only documentation differs;
runtime, templates, schemas and signed assets are byte-identical. No fresh emulator
acceptance or runtime security-review pass is claimed. No test-app writes,
protected-branch changes, push or publication.

## November 2: iteration-55 acceptance follow-up

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 55,
read-only. All must-haves remain done; no original rebase-queue refresh is eligible.
Packages bases remain code 90af361 / site 6eb2bd6. Both bases and all 33 exact
feature/compatibility tips in the current merge-order table are ancestors of the
current integrations. No integration rebuild or feature branch is needed.

Independently compared app-c's saved iteration-55 receipts:

- The artifact audit contains 57 passing consistency checks and no current observed
  failures. This is artifact consistency, not another device run.
- Settings returned painted in original PID 5116. Successful Settings and media
  attempts do not close historical F-36/F-40 or establish renderer-loss recovery.
- One registered worker was explicitly triggered after captured Ready:true and
  elapsed earliest time; observation lasted 561.913 seconds. Callback begin at
  10:28:30.214, completion at 10:28:31.482 and native SUCCESS at 10:28:31.494
  share PID 5321. The exact full-log lines are absent from the before capture.
  One forced execution proves no recurring cadence.
- Stable supplied native receipts show outbox 2/incoming absent before the worker,
  then incoming origin 1320000/usn 1320002 and outbox 0 before foreground. Both
  outgoing inspection objects independently match their saved write params.
- Independently hashed raw activation files are byte-identical, SHA256
  0d37fe251fd3b4d932c481acb6ba45b34850f25adb548911a5c9dc305c31e7e8:
  current 1793594039, pending 1793594051, trial null. Final commit and cleanup
  are recorded after observation; cleanup reports app/mocks stopped, airplane off
  and no forwards.
- App-owned runner errors, stale mock ownership and the iteration-54 fixture label
  remain separately qualified in runner-notes.md. F-41's previously empty heading
  was restored from iteration-54 evidence. The report still sees the old guide;
  the existing pendingids-adoption branch and this integration already contain
  the additive-baseline correction. This is not evidence of adoption by the app.

Decision: preserve security, users' data and the candidate freeze. These receipts
justify no speculative change to rollback strikes, sync leases, account isolation
or notification contracts. Historical findings remain open or qualified;
Kundalini has not yet accepted S6/S7/S8. S1 stays parked; S2 needs a Play account.

This follow-up changes matching integration ledgers only. Ancestry, matching
sections, unchanged implementation trees and diff hygiene were checked. Earlier
November 2 full gates retain their recorded scope; no fresh full-gate, device or
runtime-review pass is claimed. No test-app writes, protected-branch changes,
version/schema changes, push or publication. The initial ancestry reader included
historical merge tables and counted 44 rows instead of 33; narrowing it to the
current table passed. No application or runtime gate failed.

## November 2: pending-ID adoption correction (app-c F-41)

All must-haves remain done; no original rebase-queue refresh was eligible. Read
both findings and newest completed reports, Kundalini 18 / app-c 54, read-only.
App-c identifies a documentation contradiction, without reproducing a generator
or runtime failure: a new pendingIds declaration cannot universally use since 16
once the app has shipped schema 16 or higher. Fieldnote already shipped its
since-16 declaration and needs no change. Historical intermittent findings remain
open; successful isolated attempts do not close them.

Decision: preserve shipped contracts and users' data before convenience. Document
since >= max(16, shipped store schema version + 1), app schema version at least
that value, and preserve existing declarations. The guide explicitly covers an
app at 16 adding the method at 17 or higher. Package README copies, the unreleased
bridge changelog, the site README and llms.txt agree. The repository's stale
app.openStore guide now matches the site's existing additive-rule correction.
No implementation, generator, template, signed asset, package version or schema
value changed for this repair. No speculative runtime fix was introduced.

### Fresh assembly and merge order

Started fresh from packages code 90af3619bb23c88e1a74527b06edfa3489c2c3a6 and
site 6eb2bd628b278cb0582a058f2bceaca77e8549ce. The previous integration is preserved
as codex/integration-before-f41-20261102 in both repositories. Replayed the fixed
queue first, then the remaining recorded tips, S8 and this documentation branch.
The first 31 tips were already ancestors of packages; S8 and the docs branch
merged without conflicts. All 33 exact tips below were checked as ancestors.
Pre-ledger merge heads: code 3fd594c93c8eb444e4efad916fe893823bf55030 /
site 138a3649039a2cb56c99b2993f958f4b91cc9cd8. Previous evidence-ledger sections
are retained below; historical gates keep their original scope.

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
| 10 | codex/r11 | 4347872fd95b0a213b99774c3e758c7d60f047d5 | 797224cf3cab016866ecbb56213210ca4fe6556f |
| 11 | codex/r12 | de783ae9a9f04052cfc2eb7c07ae992c980ccc42 | a57ca8f05358b0bd6cd050c3a475e2aa51b1ecce |
| 12 | codex/r15 | 2951ac8b84ff2e0935dbb719b749ebbd8839f51f | 87695bbf61a1a647bec692416cacdb3a611a07ac |
| 13 | codex/r16 | dba50d483f95b724bc10869b460e7774e63cc8de | bb1775d3801e9bc6032523327ce502eb7c7383eb |
| 14 | codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 |
| 15 | codex/r19 | ebbd5e051f08661adbdc0e485cc5cf1bba32b352 | 7c31ed431453f1df73a494bb2b24d0a7a5603fb4 |
| 16 | codex/r20 | f8f3f1f9b79117e73d30917f65ed2a281b57a070 | 98cbad0d516db52225dd593fe72dea76b4800df0 |
| 17 | codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | d3d0e2b226196d871d53c47224bcf491bc44a444 |
| 18 | codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | e84efa7a38d0858491632e429bc659b8252ffb55 |
| 19 | codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 0bcc4407a44cc260677dce499efad0cbfe4a6690 |
| 20 | codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 |
| 21 | codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c |
| 22 | codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 14376728046b8ba6f6c062154d41fa1b41399176 |
| 23 | codex/r27 | 8296d4e68753185c132c39da3c94369989818f27 | c4a8fad9bc2dc04f9b8033080608e1250785e08e |
| 24 | codex/r28 | 8d42a82d96ad124c3cbe122280b64a00f43371bb | 0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65 |
| 25 | codex/r29 | 6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f | d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555 |
| 26 | codex/r31 | 44de344c92e0122f3361dacef1acc0788ff312c2 | 1dfdc0a50ed78b2103dfe3ce15b8461c588332cb |
| 27 | codex/link-compat | 48d1a8a0a71a5e0d06f3d1ecac2057514598e45c | f494813c716882cfab8161c1edfdbddaaaef85d9 |
| 28 | codex/notify-event-compat | 8a69b5da422eb403014d907f66154aea17469af9 | 094697cfb948d466c6d25dabfd7351ddac6664e2 |
| 29 | codex/sync-fixes | aa025cfdf795e6c3caa941d4dda2701e12d2c381 | dc223e8ec5d3e85e8d02cf9a99bfe547fc3e3e64 |
| 30 | codex/renderer-diagnostics | dc53ba05fcfc5108e88896ab9cd6218bdbcb0f25 | d3fd0d95cc232e26ae8e3e739da2e96d0db05887 |
| 31 | codex/s7 | f28a562c9f61b205b650de7dc11919ed13110667 | 5f774d8805a10251947435d3f1a58e5368d1876a |
| 32 | codex/s8 | 3f444554f0482046b4e09dbddf4da9d581e5ad87 | 05943aaf49d460554dd70105579bc3ee8f9f7d67 |
| 33 | codex/pendingids-adoption | 886a9f92a21228c14e33c290796f522accb5f6c3 | 99a8bf76b3d1d32f4080782b0fd8b58f696cd90e |

### Fresh gates on the combined tree

| Gate | Result |
| --- | --- |
| Root npm test | 114 passed, zero skips; generated Dart and strict/verbatim TS ran |
| Core flutter test / fatal-info analysis | 609 passed / no issues |
| Core pub publish dry run | Zero warnings |
| Push flutter test / fatal-info analysis | 2 passed / no issues |
| Push pub publish dry run | Zero warnings, existing local-override hint |
| Bridge tests / strict-verbatim TypeScript | 29 passed / passed |
| Root and bridge pack dry runs | Passed |
| Example codegen check / signed builtin verification | Passed / seq 1793567181, 2 files |
| Example Flutter tests / fatal-info analysis | 29 passed / no issues |
| Separate compile-time dev-mode regression | 1 passed |
| Example debug APK | Passed; assembleDebug 104.1s |
| Standalone Windows py Firebase audit | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |
| Site build / SEO | 46 pages passed |
| Both diff checks and 33-tip ancestry checks | Passed |

Logs: %TEMP%/valence-f41-integration-*.log. Required feature-branch gates also
passed independently: 113 root tests, zero skips; 603 core; 29 bridge; strict TS,
clean fatal-info Dart, zero-warning core pub dry run and 45-page site/SEO build.
The rendered final notification guide was checked for the formula, the 16-to-17
example and preservation of already-shipped declarations. No mirror test was
added for a prose-only correction.

One extra verify invocation omitted --manifest and --files and exited before
checking an artifact. Its original failure log is retained; verify-corrected.log
records the successful explicit manifest/content-addressed-files invocation.
No product failure or assertion was hidden. The APK retains the existing
app_badge_plus Kotlin migration warning. Gradle settings were process-scoped:
2 GiB heap, 1 GiB metaspace, two workers and ActiveProcessorCount=2.

### Review and acceptance limits

Compared with the previous integration, implementation, templates, codegen and
signed assets are byte-identical; only documentation and validation ledgers differ.
Security-path checklist: signature/check ordering, nonce/strict decoding, navigation
lock, atomic writes, keys, account isolation, cookie-clearing order and release
exclusion of dev mode remain unchanged. Inherited feature/security reviews retain
their recorded scope; no new independent runtime review is claimed for prose.
The improver still owns review and merging into packages.

No emulator was used; no new device acceptance is claimed. App-c's saved artifact
audit and single forced worker remain scoped app evidence, not recurring cadence
or a runtime repair. Kundalini has not accepted S6/S7/S8. S1 stays parked under
the candidate freeze and S2 needs a Play account. iOS remains experimental and
untested. No test-app writes, protected-branch changes, version/schema changes,
push or publication. See pendingids-adoption.md for the focused repair note.

## November 2: iteration-53 acceptance follow-up

Read both findings ledgers and newest completed reports, Kundalini 18 / app-c 53,
read-only. All must-haves are done; no rebase-queue item is eligible. Packages
bases remain code 90af361 / site 6eb2bd6. Both bases and all 32 recorded feature
tips in the current merge-order table are ancestors of both integrations.

Independently compared app-c's saved iteration-53 receipts:

- Settings returned painted in original PID 4887. Camera/gallery completed
  directly this attempt; neither success closes historical F-36 or F-40.
- The artifact audit records 54 passing consistency checks and no current
  observed failures. These are saved artifact checks, not another device run.
- One registered worker was explicitly triggered; observation lasted 469.791
  seconds. Full-log callback begin 06:59:31.392, completion 06:59:32.860 and
  SUCCESS 06:59:32.869 share PID 7250. Those exact lines are absent from the
  before capture. One forced execution proves no recurring cadence.
- Stable supplied native receipts show outbox 2/incoming absent before the worker,
  then incoming origin 1260000/usn 1260002 and outbox 0 before foreground.
  Both outgoing inspection objects independently match their saved write params.
- Independently hashed raw activation files are byte-identical, SHA256
  18f05ffec07404178cc9a2c3c619a972361673f96a7cfe857414130f5dccd8d8:
  current 1793581590, pending 1793581600, trial null. The report records final
  commit and cleanup after observation.
- The app's review found unexecuted copied report generators containing historical
  destinations and failure narratives. They were removed/excluded in favor of an
  explicit operational-script list and guarded current-receipt writer. These are
  app-owned evidence-integrity problems, not established Valence defects. The
  iteration-52 share-text fixture label remains explicitly disclosed.

Decision: preserve security, user data and the candidate freeze. Successful
isolated attempts and corrected reporting scripts do not justify speculative
changes to rollback strikes, account isolation or sync leases. Historical
reliability findings remain open or qualified; Kundalini has not yet accepted
S6/S7/S8. S1 stays parked; S2 needs a Play account.

This follow-up changes integration ledgers only. Ancestry, matching sections,
unchanged implementation trees and diff hygiene were checked. Earlier November 2
full gates retain their recorded scope; no fresh full-gate, device or runtime-review
pass is claimed. No test-app writes, protected-branch changes, version/schema
changes, push or publication. The first receipt-check command used a nonexistent
before-log filename and stopped; the corrected read of background-full-log-before.txt
passed. This was a reader error, not an application or runtime gate failure.

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
