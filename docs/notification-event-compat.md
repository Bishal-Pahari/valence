# Notification event compatibility - 2026-10-30

## In plain terms

An app can keep the notification event it already shipped while moving scheduling into Valence.
The package no longer assumes that a notification event with a familiar name accepts its integer
ID. Regenerated config names the compatible events and fields; a native adapter converts a legacy
event using the original ID carried inside the app's own payload. Warm and cold taps use the same
conversion without changing the shipped schema or erasing its baseline.

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
