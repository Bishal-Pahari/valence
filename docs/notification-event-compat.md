# Notification event compatibility - 2026-10-30

## In plain terms

An app can keep the notification event it already shipped while moving scheduling into Valence.
The package no longer assumes that a notification event with a familiar name accepts its integer
ID. Regenerated config names the compatible events and fields; a native adapter converts a legacy
event using the original ID carried inside the app's own payload. Warm and cold taps use the same
conversion without changing the shipped schema or erasing its baseline.

## App-c iteration-10 acceptance refresh - 2026-10-31

### In plain terms

App-c has now adopted the supported adapter without changing its shipped schema.
Its real warm tap preserves the string ID, and the cold reminder opens the intended
inspection with its retained photo. This closes F-30 for that app and snapshot.
A separate foreground sync transaction error, F-33, remains open; a successful
retry and this branch's package tests do not close it.

Both apps' findings and newest reports were read read-only: Kundalini 16 and
app-c 10. The earlier iteration-9 failure below is historical. Independently
checked app-c's iteration-10 captures:

- `warm-tap-events.json` contains string ID `iteration-10-warm` and the page on
  Flat 1; `event-contract-check.json` has one tap, no violations and passed=true.
  The host passes `notificationEventAdapter`, generated config supplies
  `hostNotificationEventFields`, and cold startup consumes `notifications.initial()`.
- `reconnect.json` returns E_INTERNAL with "no current transaction" for COMMIT.
  `database-error-logcat.txt` places the error at 08:26:46.529 between worker begin
  at 08:26:46.380 and completion at 08:26:48.415 in PID 4518. This establishes
  overlap and a failed call, not its cause, data loss or permanent damage.
  `reconnect-retry.json` succeeds with reason=ok and pending=0: recovery only.
- Independently hashed both raw background activation files: SHA256
  `b8c751e9fc92c5cde6947e0f38244666801bca381fa40ea8e572c40c8c1f56af`.
  The eligible **forced** periodic run preserves current 1793414964, pending
  1793415091 and trial=null. Both pulls return zero rows; two outgoing objects
  are acknowledged. This proves neither natural cadence nor new inbound data.
- `final-state.json` records current 1793415091, previous 1793414964,
  pending/trial=null and bad 1793414884. The report excludes an interrupted
  build-2-to-3 retained upgrade; later build-3 reinstalls do not replace that test.

Decision, security and users' data first: keep the reviewed runtime and additive
event declarations. Do not swallow COMMIT errors, classify them as busy, change
transaction/lease budgets or clear app data on temporal overlap alone. The next
F-33 investigation needs a retained-database Android UI/worker reproduction and
transaction ownership evidence. No eligible new must-have exists; S1 remains
parked, S2 needs a Play account and the post-beta Playground is not started.
F-27's host-file lifecycle documentation gap remains open. F-31 is corrected in
the refreshed app docs. Real remote push and iOS remain unverified.

Bases remain code packages `d771105ad666e84b29c1545ed7b6db403f79d46a` and site
packages `53d3a919b999fe62fee3d3928bbaf3a235068c58`; merging each into
`codex/notify-event-compat` reports already up to date. All numbered feature tips,
link-compat and sync-fixes are ancestors of packages in both repos. Schema 16,
R4 since 11 and pendingIds since 16 remain unchanged. Only reports change; the
existing security checklist still applies. No new runtime review or emulator run,
test-app write, protected-branch merge, version bump, push or publication.

Fresh logs: `%TEMP%/valence-oct31-app10-*.log`.

| Gate | Result |
| --- | --- |
| npm test | 106 passed, zero skips; generated Dart and strict/verbatim TS ran |
| Core / push / example Flutter tests | 548 / 2 / 27 passed |
| Core / push fatal-info Dart analysis | No issues in either package |
| Core / push pub publish --dry-run | Zero warnings; push retains one override hint |
| Bridge tests / strict-verbatim TS | 29 passed / passed |
| Root / bridge npm pack --dry-run | Passed / passed |
| Site build / SEO | 43 pages passed |
| Example codegen / signature verification | written: []; seq 1793209750, two files verified |
| Debug APK / standalone Windows py Firebase audit | Passed, assembleDebug 41.5s / PASS: graph, manifest, all 19 DEX files |

The APK used process-scoped 2 GiB heap, 1 GiB metaspace, two Gradle workers and
ActiveProcessorCount=2. The existing app_badge_plus Kotlin migration warning
remains. No installation or F-33 device acceptance is inferred.

## Final retirement-review R4 refresh - 2026-10-31

### In plain terms

The notification compatibility branch now includes the last upstream retirement-review
fixes. App-c's latest warm-tap audit still fails on its unadapted host; this refresh does
not close F-30 or change its shipped event. No runtime implementation changes were needed.

Merged newest refs/heads/packages without conflicts in both worktrees:
code d771105ad666e84b29c1545ed7b6db403f79d46a (merge dd25718), site
53d3a919b999fe62fee3d3928bbaf3a235068c58 (merge d5d4cf3).
These supersede the bases in the preceding refresh below. All 27 earlier numbered-feature,
link-compat and sync-fixes tips remain ancestors of packages in both repositories.
Only this report branch remains unmerged; a second ready feature does not require integration.

Read both VALENCE_FINDINGS.md files and newest reports, Kundalini 16 and app-c 9.
Independently read app-c's event-contract-check.json (passed=false, integer 1997876972
against string), background-state-comparison.json (identical activation hashes), and
final-state.json (1793383609 committed, pending/trial null, bad 1793383520 retained).
Its current mobile/lib still contains neither notificationEventAdapter nor
notificationEventFields. Routing success and a natural background worker run do not
establish event-shape compatibility or acceptance of the adapter.
Kundalini reports warm/cold/repeated links, unsafe-path rejection, pinned OTA commitment
and seven alarms restored after reboot; the newest base also addresses F-64 retirement.

Decision, security and data first: retain the reviewed notification adapter and original
application IDs; do not coerce an integer hash or rewrite a shipped event. Retain the
upstream conservative servable-bundle calculation: no floor subtraction, warn when a
recorded release manifest is missing, and refuse retirement on events. A minimum bridge
number alone does not prove an old method has no callers. This refresh retires no app
method and touches no test app. Combined schema stays 16 in both template and example;
notification/badge since 11 and pendingIds since 16 are unchanged. No package version changes.
The prior security checklist remains applicable; no signature order, nonce, strict decoding,
navigation/CSP, atomic activation, data or sync paths changed. No new independent review
or device run is claimed. S1 stays deferred during the freeze; S2 needs a Play account.

Fresh logs: %TEMP%/valence-oct31-r4-final-*.log.

| Gate | Result |
| --- | --- |
| npm test | 106 passed, zero failures/skips; real generated Dart and strict/verbatim generated TS executed |
| Core Flutter tests | 548 passed |
| Core / push fatal-info Dart analysis | No issues in either package |
| Push adapter / example Flutter tests | 2 / 27 passed |
| Core / push pub publish --dry-run | Zero warnings; push retains its local-override hint |
| Bridge tests / strict/verbatim TypeScript | 29 passed / passed |
| Root / bridge npm pack --dry-run | Passed / passed |
| Site build / SEO | 43 pages passed |
| Example codegen --check / built-in signature verification | written: []; seq 1793209750, two files verified |
| Debug APK / Windows py Firebase audit | Passed, assembleDebug 104.3 seconds / PASS: graph, manifest and all 19 DEX files contain no Firebase SDK references |

The APK used process-scoped 2 GiB Gradle heap, 1 GiB metaspace, two workers and
ActiveProcessorCount=2. The existing app_badge_plus Kotlin migration warning remains.
The Windows py audit ran standalone after the build and printed PASS; no installation
or device acceptance is inferred.

Only the validation report differs from packages in either repo. No shared-branch
commits/merges, pushes or publication. App-c F-30 needs tooling/runtime adoption,
regeneration, native adapter wiring and warm/cold acceptance. F-27's remaining host-file
lifecycle documentation gap is still open; F-31 is corrected upstream but its captured
preview remains older. Real remote push and iOS remain unverified; iOS is experimental
and untested. Only R4's Status cell is edited in the shared roadmap.

## Retirement-base R4 queue refresh - 2026-10-31

### In plain terms

The notification compatibility fix remains included on the newest shared candidate.
This refresh also carries the upstream method-retirement feature and its follow-up tests
and Doctor wording. No new runtime behavior is introduced on this branch. App-c still
needs updated tooling, regeneration, its native adapter and fresh warm/cold tap acceptance;
its iteration-9 event audit remains a failure rather than a closed finding.

### Bases, evidence and decision

Merged packages into codex/notify-event-compat in both worktrees without conflicts:
code 118448095efa8527009b08a1f9331eb40e0ab73a and site
f5ffebebcb588c375370e8a5a88df59d1bff7e0e (merge commits 1e9b6ce / e7594eb).
Then incorporated code dec951dac80c7da20ae52d8f87339f2caedadad7 (merge 6c06ea3)
and 3f21e11c5f2d62e516a1e15c7db6fb8a21b1799b (merge de526e5) as packages moved.
Finally merged the reviewer and troubleshooting follow-ups: code
b645179f459a247513a1f05927dde92285f65e7b and site
6a219188edc5d5ccdb962cdb1b0d7b8611803bde (merge commits a40271c / 87b34d3).
Those are the final packages bases.

Read both apps' findings and newest reports, Kundalini 16 and app-c 9, read-only.
App-c's actual event-contract-check.json reports one tap, numeric ID 1997876972,
expected string and passed=false. Its current host has neither notificationEventAdapter
nor notificationEventFields, so this capture does not validate the merged correction.
The raw background-state comparison confirms equal activation hashes with 1793383609
pending; final-state.json confirms that sequence later committed, with pending/trial null
and bad 1793383520 retained. Preserve the distinction between successful routing,
background execution, OTA commitment and typed-event compatibility.

Kundalini confirms warm/cold/repeated links, rejected unsafe paths, pinned OTA commitment
and restoration of seven alarms after reboot. F-63/F-65 fixes remain in the shared base.
The earlier sections' statement that F-64/S4 is deferred is historical: packages now
includes retirement and the site documents it. Retirement keeps the wire declaration and
has() entry but returns E_UNSUPPORTED. A minimum bridge requirement alone does not prove
that a bundle never calls an old method; retain the documented developer responsibility
to inspect every still-servable caller. Do not retire any app method in this refresh.

Decision: preserve users' data, original application IDs, additive declarations and the
upstream adapter checks. Keep combined schema 16, notification/badge since 11 and
notify.pendingIds since 16; both template and example were checked. Do not rewrite a
shipped event or convert an integer hash to a supposed original string ID.
No security code changed: the prior checklist remains applicable, including strict
response decoding, compiled action checks, bounded buffering, structural script checking,
and payload-free exception logs. Signature order, nonce, navigation/CSP, atomic activation
and sync/data paths are untouched. No new independent runtime review is claimed.

All 27 preceding numbered-feature/link/sync-fixes tips are ancestors of packages in both
repos. Only this report refresh remains unmerged and ready; no second unmerged ready
feature requires rebuilding integration. This run handles one queued branch. S1 remains
deferred and S2 still needs a Play account; no new must-have is available.

### Validation and limits

Final logs use %TEMP%/valence-oct31-r4-handoff-*.log; earlier attempts under
valence-oct31-retirement-* and valence-oct31-r4-current-* cover earlier bases.
All gates were rerun after the final documentation-base merges.

| Gate | Final result |
| --- | --- |
| npm test | 106 passed, zero failures/skips; generated Dart and strict/verbatim generated TS, including retirement, executed |
| Core Flutter tests, --no-pub --concurrency=2 | 548 passed |
| Core / push fatal-info Dart analysis | No issues in either package |
| Push adapter / example Flutter tests | 2 / 27 passed |
| Core / push pub publish --dry-run | Zero warnings; push retains one existing local-override hint |
| Bridge tests / strict/verbatim TypeScript | 29 passed / passed |
| Root / bridge npm pack --dry-run | Passed / passed |
| Site build and SEO | 43 pages passed |
| Example codegen --check / signed built-in verify | written: []; seq 1793209750 and 2 files verified |
| Example debug APK | Passed; final cached assembleDebug 5.1 seconds, earlier build 236.7 seconds |
| Windows py Firebase audit after final APK | PASS: resolved graph, manifest and all 19 DEX files contain no Firebase SDK references |

The APK commands used a process-scoped 2 GiB Gradle heap, 1 GiB metaspace,
ActiveProcessorCount=2 and two workers. The existing app_badge_plus Kotlin migration
warning remains. No APK install, emulator session or new device acceptance is inferred.
App-c F-30, real remote-push delivery and iOS remain unverified by these gates;
iOS is experimental and untested. App-c F-27's remaining lifecycle documentation
gap is still open; F-31 is corrected upstream but its captured preview remains old.

The only delta beyond packages is this validation report in each repo. Versions,
schemas, baselines and signed assets are unchanged. No test-app writes, commits or
merges to shared branches, pushes or publication. Only R4's Status cell is changed
in the shared roadmap; the existing integration entry and other owners' rows are retained.

## Post-review R4 queue refresh - 2026-10-31

### In plain terms

The shared candidate now includes the review fixes for notification-event migration.
This branch retains those fixes and the original application IDs. App-c's failing
tap audit still needs a refreshed runtime/CLI, regenerated config and the documented
adapter before a new warm/cold device run can accept it.

### Bases and decision

Merged newest packages into codex/notify-event-compat in both worktrees, without
conflicts: code bc577b1e88665f3f58636215a7103109793d2b6b, site
2467eb1f430ee8fe6554b813ceaa7288c3bc9392. The merge commits are code 0bcf8a7 and
site c3c7bff. All preceding numbered-feature/link tips and sync-fixes are
ancestors of packages in both repositories. This branch differs from packages
only in this validation report; there are no two unmerged ready feature branches
requiring a fresh integration. This run handles the queued R4 refresh only.

The upstream correction makes incompatible notification events app-owned with a
warning instead of refusing an already-shipped declaration. It reports a missing
adapter once per event name, validates returned scripts structurally, and logs
adapter exception types without private messages. Retain these changes: preserving
shipped contracts and preventing script injection come before convenience.
Do not coerce a native integer hash into the application's original string ID,
erase the baseline or change notification behavior again before adoption.

Read both findings files and newest reports, Kundalini iteration 16 and app-c
iteration 9, read-only. Spot-checked app-c's actual event-contract-check.json:
one observed tap, numeric 1997876972, expected string, passed false. Current app
main/config still contain neither notificationEventAdapter nor
notificationEventFields. This does not exercise the merged adapter correction.
Keep F-30 open for adoption and warm/cold acceptance. F-31's permissions floor is
already corrected upstream; F-27's remaining host-file lifecycle docs stay open.

App-c's worker-full-logcat.txt records background begin, complete and WorkManager
SUCCESS; worker-mock.log records the two-operation push. Its raw activation
comparison has equal SHA256 values with 1793383609 pending; final-state.json
then records that sequence committed with pending/trial null and bad 1793383520.
This supports one observed natural due-time worker, not a cadence guarantee.
Kundalini's before/after reboot captures contain the same seven 06:00 origWhen
values. F-63/F-65 diagnostics remain included. F-64 retirement stays deferred:
a bundle's minimum bridge version alone does not prove it never calls an older
method, so keep shipped handlers and truthful capability reporting.

Combined schema stays 16, R4 since 11 and pendingIds since 16. Package versions,
shipped baselines, signed assets, data and activation behavior are unchanged.
Keep S1 deferred during acceptance; S2 still needs a Play account.

### Fresh validation

Logs use %TEMP%/valence-oct31-r4-*.log. Root tests pass 103 with zero failures/skips,
including generated Dart and strict/verbatim generated TS. Core tests pass 548,
push adapter 2, example 27 and bridge 29. Both fatal-info Dart analyzers and
strict/verbatim bridge TypeScript pass. Both pub dry runs have zero warnings
(push retains its existing local-override hint), and both npm pack dry runs pass.
Site build/SEO passes 43 pages. Example codegen writes nothing; built-in signature
and files verification accepts seq 1793209750, two files.

The debug APK passes (assembleDebug 109.7 seconds). Its process-scoped Gradle
settings use a 2 GiB heap, 1 GiB metaspace, ActiveProcessorCount=2 and two workers;
the daemon command confirms those memory/processor settings. The existing
app_badge_plus KGP migration warning remains. Standalone Windows
py example/tool/check_no_firebase.py prints PASS for the resolved core graph,
manifest and all 19 DEX files. No APK installation or device acceptance is inferred.

The delta beyond packages is this report only. No new independent runtime review
or emulator session is claimed; the upstream review retains its original scope.
No test-app writes, shared-branch changes, version/schema changes, pushes or
publications occurred. Only R4's Status cell is updated in the shared roadmap.

## Merged R4 queue refresh - 2026-10-31

### In plain terms

The notification event correction is already merged into packages. Refreshed this branch
onto the newest shared candidate and kept the existing adapter, shipped event meanings and
application IDs intact. App-c still needs to adopt that correction before its failing tap
contract can be closed. No new feature is part of this queue run.

### Bases, queue and decisions

Code packages: 27f134b6401d78c1919eaa9839d96609590c11c5.
Site packages: f37747861f4723d504183a6346e6ce2df34763e9.
Both codex/notify-event-compat branches fast-forwarded first through the notification merge
(58db7ac / 9772ba5), then through the concurrent deep-link diagnostics changes. All 27 pre-refresh
numbered-feature/link/notification tips are ancestors of packages in both repositories.
Before these report commits, only historical backup branches remained outside packages; no two unmerged ready features
require a new integration. This run handles the one queued R4 refresh only.

Read both apps' VALENCE_FINDINGS.md and newest reports read-only: Kundalini iteration 16
and app-c iteration 9. The initial full test/build checks began on 58db7ac / 9772ba5;
packages moved during validation, so the full set was repeated on the final bases above.
Earlier passes do not substitute for the final-base gates below.

Kundalini reports installed schema 17, warm/cold/repeated deep links and a pinned
requires.bridge=16 OTA commit. Its before/after reboot captures contain the identical seven
06:00 alarm times from October 31 through November 6; the post-reboot capture records an
initially empty queue and later recovery without manual launch. This is inspected app
capture evidence, not a new emulator session here. Upstream now addresses F-63 with the
scheme/host Doctor comparison and F-65 with an explicit refusal before overwriting an
association file. That static comparison is not proof of installed OS routing. F-64's
retirement proposal remains a separate compatibility question; do not remove a shipped
handler or make has() promise an implementation that merely refuses old calls.

App-c's actual warm-tap audit remains failed: one tap, integer ID 1997876972 where its
frozen event requires a string. Current app main/config still contain neither
notificationEventAdapter nor notificationEventFields. This is unadapted runtime evidence,
not acceptance or failure of the merged correction. Preserve the event and original
application ID; keep F-30 open for refreshed CLI/runtime adoption, regeneration, native
adapter wiring and warm/cold device acceptance. F-31's schema floor is already corrected
in the merged site; its stale docs snapshot does not exercise that correction. F-27's
remaining host-file lifecycle guidance stays open. The latest successful camera attempt
does not establish a cause or correction for F-32.

Decision order: preserve trust boundaries, then users' data and shipped contracts. Retain
upstream diagnostics and the reviewed adapter rather than adding notification behavior
before adoption. Starter/example stay at schema 16, R4 methods/events at since 11 and
pendingIds at since 16. Kundalini's app-specific schema 17 does not allocate a new framework
schema number. Keep S1 deferred during candidate acceptance and S2 behind its Play-account
blocker. Real Firebase delivery and iOS remain untested.

### Fresh validation

Final logs: %TEMP%/valence-refresh-oct31-final-*.log.

| Gate | Result |
| --- | --- |
| npm test | 103 passed, zero failures/skips; generated Dart and strict/verbatim generated TS ran |
| Core Flutter tests | 546 passed, concurrency 2 |
| Core fatal-info analysis / pub dry run | No issues / zero warnings |
| Push adapter tests / fatal-info analysis / pub dry run | 2 passed / no issues / zero warnings, one existing local-override hint |
| Example Flutter tests | 27 passed |
| Bridge tests / strict/verbatim TypeScript | 29 passed, zero failures/skips / passed |
| Root and bridge npm pack --dry-run | Passed |
| Site build / SEO | 43 pages passed |
| Example codegen --check | written: [] |
| Built-in signature and files | seq 1793209750, two files verified |

Final debug APK passes (assembleDebug 10.8 seconds; the earlier-base build passed in
200.2 seconds). Both builds used command-local 2 GiB heap, 1 GiB metaspace,
ActiveProcessorCount=2 and two Gradle workers. The existing app_badge_plus KGP warning remains.
Standalone Windows py example/tool/check_no_firebase.py prints PASS for the resolved graph,
manifest and all 19 DEX files. No APK installation or new device acceptance is inferred.

Security checklist: the final delta from packages is this report only. Signature ordering,
nonce/navigation/CSP checks, strict decoding, atomic state writes, key handling, notification
validation and data/sync behavior remain in their existing paths. The initial implementation's
review retains its original scope; this refresh adds no independent runtime security review.
No test-app writes, shared-branch commits/merges, package/schema version changes, pushes or
publications occurred. Only R4's Status cell is updated in the shared roadmap; no integration
top line or other item is changed.

## Queue refresh after app-c iteration 9 - 2026-10-31

Reviewed both findings files and newest reports: Kundalini iteration 15 and app-c iteration 9
(started October 30, completed October 31). Both merges of newest packages report already up to
date: code `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`, site
`ce19151baa1fdac40ac3208e70bb69388a8b538a`. All 26 earlier numbered-feature/link-compat
tips are ancestors of packages in both repositories. This remains the only unmerged implementation
branch, so a fresh integration is not required. No other must-have is eligible.

App-c's real warm-tap capture contains integer ID `1997876972`, application payload
`{"id":"iteration-9-warm","p":"unit-0101"}` and `action: null`. Its contract audit records one
string-ID violation and exit 1. Flat 2 to Flat 1 routing does not close F-30. Both supplied npm
hashes match iteration 8. The app's current main/config still contain neither
`notificationEventAdapter` nor `notificationEventFields`; this capture does not exercise this
branch's correction. Keep F-30 open until refreshed CLI/runtime adoption, regeneration, adapter
wiring and warm/cold acceptance. F-31's schema-10 correction is already on this site branch;
F-27's remaining host-file limits/lifecycle guidance stays open. F-32 did not recur in the latest
app attempt, which does not establish its cause or a runtime fix.

Inspected iteration-9 worker logs and raw activation comparison: one natural due-time run reports
background begin, complete and WorkManager SUCCESS; the mock records acknowledgements for two
scalar writes. Before/after activation SHA256 values match
`1c5973fdb45c442cdca2227e64ddbc8543fe7e8434c88e9f2dd82881a6b959db`, with good
OTA `1793383609` pending and trial null. Final activation commits that seq, previous
`1793383580`, pending/trial null, bad [`1793383520`], floor 0. This is inspected app evidence,
not a new device run here or proof of periodic cadence. Kundalini's latest report remains
schema-16 device/OTA acceptance and observed reminder delivery, without a new package finding.

Decision: preserve users' data, application IDs and shipped event meanings. Retain the existing
adapter correction until adoption rather than changing notification behavior again on an unadopted
fix. Combined schema remains 16, R4 since 11 and pendingIds since 16. S1 remains deferred during
the candidate freeze; S2 requires a Play account. This refresh changes evidence only; the existing
security checklist and review retain their original scope. Real Firebase delivery and iOS remain
untested.

Fresh gates use `%TEMP%/valence-notify-i9-*.log`. Root tests pass 102/102 with zero skips,
including real generated Dart and strict/verbatim generated TS. Core tests pass 546, push adapter 2,
example 27 and bridge 29. Both fatal-info Dart analyzers and strict/verbatim bridge TypeScript pass.
Both pub dry runs have zero warnings (push retains its local-override hint); both npm pack dry runs
pass. Site build/SEO passes 43 pages. Example codegen writes nothing; signed builtin verification
accepts seq `1793209750`, two files.
Debug APK passes (assembleDebug 121.9 seconds, existing app_badge_plus KGP warning), using a
command-local 2 GiB heap, 1 GiB metaspace, two workers and ActiveProcessorCount=2. Standalone
Windows `py example/tool/check_no_firebase.py` prints PASS for the graph, manifest and all 19 DEX
files. Implementation trees are unchanged from iteration-8 validation; only this report changes
in either repository. No APK installation, new device acceptance, test-app writes, shared-branch
changes, package/schema version changes, pushes or publications occurred.

## Queue refresh after app-c iteration 8 - 2026-10-30

Reviewed both findings files and newest reports: Kundalini iteration 15 and app-c iteration 8.
Both branches already contain newest packages: code `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`
and site `ce19151baa1fdac40ac3208e70bb69388a8b538a`. All 26 earlier numbered-feature/link-compat
tips remain ancestors of packages in both repositories. This is the only unmerged implementation
branch, so the two-branch integration rule does not require a fresh integration. No other must-have
is eligible; S1 remains deferred during the candidate freeze and S2 needs a Play account.

App-c's real warm-tap capture now contains integer ID `578327257`, application payload
`{"id":"iteration-8-warm","p":"unit-0101"}` and `action: null`. Its contract audit reports
one string-ID violation. Routing to Flat 1 succeeds but does not close F-30. Supplied npm hashes
match iteration 7, and the app's current main/config still contain neither
`notificationEventAdapter` nor `notificationEventFields`. This is further evidence against the
unadapted runtime, not device acceptance of this branch. Keep the finding open until refreshed
CLI/runtime adoption, regeneration, adapter wiring and warm/cold acceptance. F-31's correction
is already on this site branch; its stale documentation capture does not exercise that correction.
F-27's remaining host-file limits/lifecycle guidance stays open.

Spot-checked the eligible forced-worker comparison: exact raw activation SHA256 values match
`3d9de373251ea0fe9d9ebe46a2b95483a72afb9008ab5dd90d471f0587116030`, with good OTA
`1793380006` pending. Final activation commits that seq, previous `1793379875`, pending/trial
null, bad [`1793379749`], floor 0. The report excludes an earlier contaminated foreground receipt.
These are inspected app captures, not a new device run here. New F-32's ANR capture names
`com.android.camera2` with a 5003ms input timeout, followed by a reported successful retry;
it establishes no Valence cause. Kundalini's latest report remains schema-16 device/OTA
acceptance and observed reminder delivery, with no new package finding.

Decision: preserve users' data and shipped event meanings. Do not coerce a native hash to a
string, rewrite the frozen event, change database behavior on recovered latency, or change
notification behavior again before the reviewed adapter is adopted. Combined schema remains
16, R4 since 11 and pendingIds since 16. This refresh changes evidence only; the existing
security checklist and review retain their original scope. Real Firebase delivery and iOS
remain untested. No test-app writes, emulator run, shared-branch changes, pushes, publication
or package/schema version changes occurred.

Fresh gates use `%TEMP%/valence-notify-i8-*.log`. Root tests pass 102/102 with zero skips,
including real generated Dart and strict/verbatim generated TS. Core tests pass 546, push
adapter 2, example 27 and bridge 29. Both fatal-info Dart analyzers and strict/verbatim bridge
TypeScript pass. Both pub dry runs have zero warnings (push retains its local-override hint);
both npm pack dry runs pass. Site build/SEO passes 43 pages. Example codegen writes nothing
and built-in signature verification accepts seq `1793209750`, two files. Debug APK passes
(assembleDebug 106.6 seconds, existing app_badge_plus KGP warning), with a command-local
2 GiB heap, 1 GiB metaspace, two workers and ActiveProcessorCount=2. Standalone Windows
`py example/tool/check_no_firebase.py` prints PASS for the graph, manifest and all 19 DEX files.
Implementation trees are unchanged from the preceding iteration-7 validation; only this report
changed in either repository. No APK installation or device acceptance is inferred.

## Queue refresh after app-c iteration 7 - 2026-10-30

Read both findings files and the newest reports: Kundalini iteration 15 and app-c iteration 7.
Newest packages remains code `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`, site
`ce19151baa1fdac40ac3208e70bb69388a8b538a`; both merges report already up to date.
All 26 earlier numbered-feature/link-compat tips remain ancestors of packages in both repos.
This remains the only unmerged implementation branch; the two-branch integration rule does not
require a fresh integration. No other must-have implementation is eligible.

App-c's iteration-7 `event-contract-check.json` reports one string-ID violation for actual integer
ID `1923145494`; its warm tap routes successfully, which does not repair the wire contract.
The supplied npm hashes remain unchanged from iteration 6. Read-only inspection of the app's
current main/config finds neither `notificationEventAdapter` nor `notificationEventFields`.
The captured failure does not exercise this branch's adapter. Keep F-30 open until refreshed
CLI/runtime adoption, regeneration, adapter wiring and warm/cold device acceptance. Preserve the
shipped event and original application ID rather than coercing the native hash to a string.

F-31 is confirmed against this site branch: both the bridge guide and homepage FAQ incorrectly
dated permissions to schema 9. Corrected both to 10 in site commit `2d6afa6`, matching contracts
section 4.9, the dedicated guide and starter schema. Searched site source/public files for other
schema-9 permissions references; none remain. This is a documentation correction, without a
schema, runtime or package version change. F-27's remaining host-file lifecycle guidance stays open.

App-c's supplied background comparison records equal raw activation SHA256 values before/after
its due-time forced periodic worker. Its final state commits `1793376496`, previous `1793376385`,
pending/trial null, bad [`1793376329`], floor 0. These are inspected app captures, not a new
device run here. Kundalini's latest report remains schema-16 device/OTA acceptance and observed
reminder delivery, without a new package finding. Real Firebase delivery remains untested.

Decision: preserve users' data and shipped event meanings; retain the existing correction until
it is adopted instead of changing notification behavior again on unadopted evidence. Combined
schema stays 16; R4 since 11 and pendingIds since 16 stay fixed. S1 remains deferred during the
candidate freeze and S2 still requires a Play account. The existing security checklist/review
retains its scope; this run adds no runtime change or new independent review.

Fresh gates use `%TEMP%/valence-notify-i7-*.log`. Root tests pass 102/102 with zero skips,
including real generated Dart and strict/verbatim generated TS. Core tests pass 546, push
adapter 2, example 27 and bridge 29. Both fatal-info Dart analyzers and strict/verbatim bridge
TypeScript pass. Both pub dry runs have zero warnings (push retains its local-override hint);
both npm pack dry runs pass. Site build/SEO passes 43 pages. Example codegen writes nothing
and built-in signature verification accepts seq `1793209750`, two files. Debug APK passes
(assembleDebug 122.1 seconds, existing app_badge_plus KGP warning), using a command-local
2 GiB heap, 1 GiB metaspace, two workers and ActiveProcessorCount=2. Standalone Windows
`py example/tool/check_no_firebase.py` prints PASS for graph, manifest and all 19 DEX files.

No new emulator run or device acceptance is claimed. No test-app writes, shared-branch
commits/merges, schema/package version changes, pushes or publications were performed.

## Queue refresh after app-c iteration 6 - 2026-10-30

Read both findings files and the newest reports: Kundalini iteration 15 and app-c iteration 6.
Newest packages remains code `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`, site
`ce19151baa1fdac40ac3208e70bb69388a8b538a`; both branch merges report already up to date.
All 26 numbered-feature/link-compat tips remain ancestors of packages in both repositories.
This is the only unmerged implementation branch; integration history/backup branches do not
constitute a second ready feature. No integration rebuild or new must-have item is due.

App-c now independently audits the observed ID against its frozen event. Its iteration-6
`warm-tap-events.json` records integer ID `1536160051`, the application's encoded payload and
`action: null`; `event-contract-check.json` reports one string-ID violation and the report
records exit 1. Routing to Flat 1 does not repair the wire contract. Its npm snapshot hashes match
iteration 5. Read-only inspection of its current `mobile/lib/main.dart` finds no
`notificationEventAdapter`, and generated `config.g.dart` has no `notificationEventFields`.
This still does not exercise this branch's correction. Keep F-30 open until refreshed CLI/runtime
adoption, regeneration, native adapter wiring and warm/cold device acceptance. Do not ask the
app to rewrite its shipped event or infer the original application ID from a hash.

Spot-checked iteration-6 background activation comparison: before/after SHA256 are equal while
the worker runs. Final activation records current `1793340382`, previous `1793340295`, null
pending/trial, bad `1793340198` and floor 0. These are app-provided captures, not an independent
device run here. Its retained media, notification delivery and rollback claims keep the scope
and exclusions in its report. F-27's remaining host-file lifecycle documentation gap stays open.
Kundalini's latest report is unchanged: schema-16 device/OTA acceptance and observed delivery,
with no new platform finding. Real Firebase delivery remains outside both apps' coverage.

Decision: preserve users' data and the shipped event's meaning. Retain this reviewed correction
and its migration adapter rather than adding another runtime change against an unadopted fix.
Combined schema remains 16, R4's reserved since remains 11 and pendingIds remains since 16.
S1 remains deferred during the candidate freeze; S2 still needs a Play account. No package or
schema version, shipped baseline, signed asset, activation or data behavior changed in this run.

Fresh logs use `%TEMP%/valence-notify-i6-*.log`. Root tests pass 102/102 with zero skips
(real generated Dart and strict/verbatim generated TS included); core 546, push adapter 2,
example 27 and bridge 29 pass. Both fatal-info analyzers, strict/verbatim bridge TypeScript,
both zero-warning pub dry runs (push retains its override hint), both npm pack dry runs and
43-page site/SEO build pass. Example codegen writes nothing; signed builtin verification accepts
seq `1793209750`, two files. The first manual verification used the builtin parent for --files
and was correctly refused; the corrected content-addressed files/ invocation passes.
Debug APK build passes (assembleDebug 125.7 seconds, existing app_badge_plus KGP warning).
Standalone Windows py audit prints PASS for the resolved graph, manifest and all 19 DEX files.
The build uses a 2 GiB Gradle heap, two workers and ActiveProcessorCount=2 in its command
environment. No APK installation or device acceptance of this correction is inferred.

This report-only refresh adds no implementation change or new independent security review;
the existing checklist/review retains its original scope. No test-app write, emulator session,
shared-branch commit/merge, push or publication was performed.

## Queue refresh after app-c iteration 5 - 2026-10-30

Read both findings files and the newest reports: Kundalini iteration 15 and app-c iteration 5.
Rechecked all 26 previous feature/link-compat tips in both repositories; they are ancestors of
packages. This R4 follow-up is the only unmerged implementation branch. Both merges of newest
packages reported already up to date: code `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`, site
`ce19151baa1fdac40ac3208e70bb69388a8b538a`. No integration rebuild is required for a single branch.

App-c's `evidence/iteration-5/warm-tap-events.json` still records integer ID `142341840`, the app's
encoded payload and `action: null` over its frozen string-ID event. Correct routing does not close
F-30. Its supplied npm hashes match iteration 4, and this correction is still outside packages;
that device result does not test this branch or its adapter. Keep F-30 open until adoption,
regeneration, adapter wiring and warm/cold device acceptance. Its background comparison records
unchanged activation bytes; final state commits `1793336948` with pending/trial null. These are
read-only app captures, not a new device run here. F-27's host-file lifecycle guidance remains open.

Decision: preserve users' data and shipped event meanings. Keep R4's reserved `since: 11`, and
`notify.pendingIds` at `since: 16`. The combined schema stays 16: lowering it to R4's original 11
would invalidate the later merged capabilities. This is the explicit reason the ready status
names combined schema 16 rather than renumbering the branch to 11. No schema or package version
changes are made. The existing security checklist and independent review below retain their
original scope; this report-only refresh adds no runtime change or new independent review.

Fresh logs use `%TEMP%/valence-notify-refresh-*.log`. Root tests pass 102/102 with zero skips,
including generated Dart and strict/verbatim generated TS; core tests pass 546, push adapter 2,
example 27 and bridge 29. Both fatal-info analyzers and strict/verbatim bridge TypeScript pass.
Both pub dry runs have zero warnings (the push adapter retains its local-override hint); both npm
pack dry runs pass. The site build and SEO check pass all 43 pages. Example codegen writes nothing;
signed builtin verification accepts seq `1793209750`, two files. The debug APK builds successfully
(assembleDebug 134.6 seconds, existing app_badge_plus KGP warning). Standalone `py` Firebase audit
prints PASS for the resolved graph, manifest and all 19 DEX files. No implementation changed after
these checks. Device acceptance of this correction, real Firebase delivery and iOS remain untested.

## Inputs, ownership and decision (initial implementation)

Read both apps' VALENCE_FINDINGS.md and their newest completed reports: Kundalini iteration 15
and app-c iteration 4. Kundalini reports installed schema-16 acceptance, observed reminder delivery
and an app-owned day-loading fix. App-c's F-26 tooling issue is resolved in iteration 3; F-27 remains
open for host-file lifecycle guidance. F-28 does not establish a database defect; preserve data
and retry semantics. F-29's callback replacement is app-owned and its fix exposes distinct F-30.

App-c's `evidence/iteration-4/fixed-warm-tap-events.json` records a numeric ID 1885662976 plus
`action: null` over its frozen since-1 `{id: string, payload: string?}` event. Its schema and newest
report confirm the mismatch. This is current runtime behavior, unlike the older F-26 artifact.

All 26 previous numbered feature/link-compat branch tips are ancestors of packages in both repos.
The original rebase queue and R14 need no work. Only this corrective branch is newly ready and
unmerged, so the two-branch integration rule does not require a new integration branch.
S1 remains deferred during the candidate freeze; S2 still needs a Play account.

Branch: `codex/notify-event-compat` in both worktrees.
Code base: `d2e6970a983e8f1e1f030ea39b9861d487ea9db4`.
Site base: `ce19151baa1fdac40ac3208e70bb69388a8b538a`.
Implementation: code `626ca98`, site `961ff9c`.

Decision: preserve shipped event meanings and application IDs. Suppress automatic emission for
pre-11/absent declarations and project modern payloads onto declared fields. Provide a synchronous
native adapter returning a generated script or null. A hash cannot recover an app's original ID,
so automatic string coercion would change its meaning. Cold access stays explicit and consume-once;
do not reinitialize the shared plugin or parse its private envelope in app code. Manually constructed
configs and older generated configs retain their prior defaults; regeneration plus a store build
is required for schema-derived protection. The docs state that migration requirement.

## Regression and review

The minimal service test first failed with the reported mismatch: expected a string ID and two
fields; received an integer ID and an extra `action` field. The first test invocation had a test-only
script-parser error; after correcting that parser, the unchanged runtime failed the actual payload
assertion. The fixed regression passes for warm and explicit cold conversion.

Tests also cover modern field filtering, absent/legacy suppression, rejected responses before the
adapter, adapter failures without private logs, consume-once cold access without double emission,
and the newest-16 startup queue through Valence.open/attach. The existing generated-Dart gate now
compiles the exact documented adapter against real generated legacy string-ID code and checks its
script, malformed JSON and unsupported-action cases. Codegen/check preserve the recorded baseline;
changing the shipped event remains refused.

Independent read-only review found no confirmed defect in the implementation or final test/docs
delta. The reviewer ran the focused metadata test and example codegen check; full gates below are
separate evidence. No device run is claimed for this correction.

Security checklist: envelope/version decoding, integer ID range, UTF-8 limits, compiled action IDs,
generated JSON escaping, bounded startup buffering and host message caps remain in their existing
paths. Adapter input is unmodifiable and already validated; domain payload validation stays with
the app. No signature, nonce, navigation, CSP, activation, atomic state or data/sync logic changed.
Package versions, bridge schema/builtins 16, shipped baselines and signed assets are unchanged.

## Gates

Logs: `%TEMP%/valence-notify-*.log`.

| Gate | Result |
| --- | --- |
| Final npm test | 102 passed, zero failures/skips; real generated Dart and strict/verbatim generated TS included |
| Core flutter test --no-pub --concurrency=2 | 546 passed |
| Core dart analyze --fatal-infos . | No issues |
| Core flutter pub publish --dry-run after commit | Zero warnings |
| Push adapter tests / fatal-info analysis | 2 passed / no issues |
| Push adapter pub dry run | Zero warnings, one existing local-override hint |
| Bridge tests | 29 passed, zero failures/skips |
| Bridge strict/verbatim TypeScript / npm pack --dry-run | Passed / passed |
| Example flutter test --no-pub | 27 passed |
| Example codegen --check | written: [] |
| Signed built-in verify | seq 1793209750, 2 files verified |
| Root npm pack --dry-run | Passed |
| Site build / SEO | 43 pages passed |
| Debug example APK | Passed, assembleDebug 250.2 seconds; existing app_badge_plus KGP warning |
| py example/tool/check_no_firebase.py | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |

The APK build used a 2 GiB Gradle heap, two workers and ActiveProcessorCount=2 in its command environment. The Firebase audit ran standalone through py on Windows and printed PASS. No APK installation or device pass is inferred.

The first core pub dry run failed because changes were uncommitted; the clean rerun has zero
warnings. An initial manual verify command used an unsupported --signature flag; the corrected
standalone invocation with --root/--manifest/--files succeeded. Neither failed invocation counts
as a passing gate. A second full root run validated the final generated-legacy fixture addition.

## Limits and handoff

This fixes the package integration seam; app-c must adopt the refreshed CLI/runtime, regenerate,
install its native adapter and rebuild before its warm/cold device acceptance can close F-30.
Tests do not establish real Firebase delivery, positive biometrics, clock/reboot stress or natural
background timing. iOS remains experimental and untested. No emulator lock was acquired and no
test app was modified. No shared-branch commit/merge, push, publication or version/schema bump.

Only the R4 Status cell is updated in the shared roadmap for this follow-up; other rows and its
existing integration top line are left to their owners.
