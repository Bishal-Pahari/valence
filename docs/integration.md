# Integration acceptance refresh - 2026-10-31

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
