# R8 queue refresh - 2026-10-26

## In plain terms

R8 now includes packages at e879260366282c9f504057423d54f682dcb10c81
(merge 6a60782). Site packages remains f59fbc1568c895d4cd35d385733175397beeef6a,
already included in the site branch. Both worktrees are on codex/r8. This is
one queue item; no other branch or roadmap status was changed.

Decision: preserve upstream account security and the reserved appearance number.
The combined template/example schema stays at version 13, auth.account stays
since 13 and app.appearance stays since 7. Lowering the combined version to 7
would invalidate the upstream since-13 method; removing or renumbering it would
misrepresent account-switch support. This is an explicit deviation from the
queue's requested combined schema 7, carried forward from the previous refresh.
Do not publish this intermediate host before all reserved surfaces are integrated,
or advertise appearance to an older internal schema-13 host that lacks it.
The recorded example store baseline and signed built-in were not changed today.
Package versions were not changed.

Read both apps' VALENCE_FINDINGS.md and newest reports: Kundalini iteration 11
(2026-10-23), app-a iteration 9 (2026-10-26). The newest app-a report adds F-32:
the supplied generator emits an event table argument that the supplied bridge
snapshot cannot accept. Both accessibility guides now explain that tooling and
bridge must be updated together before regeneration (code 053d250, site 2959842).
This documents the compatibility requirement; it does not repair the harness's
snapshot artifacts or claim to close the app finding. Neither app was modified.
The reported database-lock warnings have no established cause and are not
attributed to R8. App nav clipping still requires actual page inset padding.

## Fresh gates

- Root npm test: 67 passed, zero failed/skipped. Generated Dart analyzed and ran
  against Flutter; generated TypeScript passed strict/verbatimModuleSyntax checks.
- Runtime flutter test: 404 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 22 passed; strict TypeScript, build and npm pack --dry-run passed.
- Example: 17 passed; codegen --check wrote nothing; built-in verification passed
  at seq 1792706013, one file; debug APK built successfully.
- Final site npm run build: 29 pages; SEO/link/anchor checks passed.
- Flutter pub publish --dry-run: zero warnings.
- Independent security review: no confirmed R8 findings. Checked contracts
  sections 3, 4.2, 4.6 and 4.7, owning-view metrics, strict decoding/delegations,
  JSON-only publication, nonce/navigation/CSP retention, additive fontScale,
  non-compounding iOS fallback and status-before-updateReady ordering. Focused
  CLI fontScale regression passed; reviewer codegen check wrote nothing.
  The reviewer's overlapping Flutter attempt failed before tests on a locked
  sqlite3.dll; its crash log was removed. The main full runtime gate passed.

No new emulator run was attempted for this queue refresh. Earlier Android evidence
below is historical; TalkBack and true split-screen remain unverified. iOS remains
experimental and untested. No pushes, publications, test-app writes or merges into
packages/main. Shared ROADMAP edits are restricted to R8's Status cell; this file
carries the requested plain-language note.

---

# R8 account-switch security refresh - 2026-10-23

## In plain terms

R8 now includes packages at 2716d462aaa2187150b31fcd70daeaff52813a05 and
site packages at f59fbc1568c895d4cd35d385733175397beeef6a. Both worktrees
remain on codex/r8. The account-switch clear and token write stay under the
same sync lease, failed account reads refuse the change, empty-string token
refreshes preserve rows, and sync observations reset with the writable rows.
R8's owning-view appearance and text scaling remain intact.

Decision: security and users' data take precedence over lowering the combined
schema to the queue's reserved 7. Keep upstream schema version 13 and
auth.account since 13; keep R8 app.appearance since 7. A version-7 schema
cannot contain a since-13 method. Do not remove or renumber that upstream
surface. This explicitly departs from the queue's requested schema number.
As before, these are integration candidates: do not publish a schema-13 host
until all reserved surfaces are integrated, and do not send appearance
metadata to an older internal schema-13 host that lacks it.

Conflicts: retain the appearance-test imports alongside incoming tests;
remove dart:typed_data after analysis identifies it as redundant with the
new flutter/services.dart import. Rebuild the signed example from the merged
web page, preserving the shared storeSchema version 1, storeSeq 1792215625,
storeRoutes and floor. Only lastSeq advances to 1792706013. No store baseline
or package version was changed. The example includes the corrected auth
pane's has() gate and R8's layout probe.

Input evidence: both apps' VALENCE_FINDINGS.md; Kundalini iteration 11
(2026-10-23) and app-a iteration 8 (2026-10-22). Findings about paging,
capability gates, update notifications, insets and retained auth warnings
inform review; app reports are not fresh framework device verification.
Both test-app repositories were read only.

## Fresh gates

- Root npm test: 67 passed, zero failed/skipped; generated Dart was analyzed
  and exercised against Flutter, and generated TypeScript passed strict
  checking with verbatimModuleSyntax.
- Runtime flutter test: 404 passed; final dart analyze --fatal-infos .:
  no issues. The initial analyzer run caught the redundant import above.
- Bridge: 22 passed; strict TypeScript, build and npm pack --dry-run passed.
- Example: 17 passed; codegen --check wrote nothing; built-in verification
  passed at seq 1792706013, one file; debug APK built successfully.
- Flutter pub publish --dry-run: zero warnings.
- Site npm run build: 29 pages; SEO/link/anchor checks passed.
- Independent security review: no remaining confirmed findings after the
  import correction; 167 focused appearance/runtime/updater tests and 10
  CLI shape/additive/account/fontScale tests passed, plus clean analysis,
  zero-write codegen, signed verification and git diff --check.

Implementation commits: 84b9fc6 (merge and rebuilt signed example), ab16280
(import correction); site merge dfc65a6. Earlier records below are historical.
No new emulator run; TalkBack and true split-screen remain unverified, and
iOS remains experimental and untested. Exactly one queue item refreshed.
No test-app writes, package-version changes, pushes, publications or merges
into shared branches.

---

# R8 account-switch queue refresh - 2026-10-23

## In plain terms

R8 includes packages at 3ddd92e56c853cfa06c313b0a7ad64e74ca4e031 and site
packages at 7766e850917ba5004321ea6f03759f8c8ffd9121. Both branches are codex/r8.
The merges preserve account switching, queued-write refusal, all data/security
safeguards, adaptive UI and status-before-updateReady publication.

Schema decision: keep the upstream template/example version 13, auth.account
since 13 and R8 app.appearance since 7. The queue's literal version-7 instruction
is now incompatible with the incoming since-13 method: validation rejects it.
Renumbering or removing the account method would violate additive evolution or
lose user-data protection. This refresh therefore departs from the requested
schema-7 status, explicitly, without changing package versions or other items.
The template-version claims in both accessibility guides and example README
now distinguish combined version 13 from appearance's reserved since 7.

Preserve the shared upstream example's recorded storeSchema version 1,
storeSeq 1792215625 and storeRoutes; only lastSeq advances to 1792704210.
The signed combined built-in requires 13 and the generated host reports 13.
An initial rebuild used --store; its unshipped baseline advance was removed
in favor of the actual shared recorded baseline. No rebaseline flag was used.
This keeps queued since-8 through since-12 additions valid against that record.
Do not publish an intermediate version-13 host before those reserved features
are integrated, or later additions fail against that shipped baseline. An older
internal version-13 host without R8 must not receive OTA metadata advertising
appearance since 7: its numeric capability comparison could overstate support.
These branch snapshots are integration candidates, not releasable store builds.

Read both apps' VALENCE_FINDINGS.md and newest reports: Kundalini iteration 11
(2026-10-23), app-a iteration 8 (2026-10-22). Their paging, capability-gate,
update-notification and retained-auth-warning observations are app evidence,
not new device verification. Both test app repositories were read only.

## Fresh gates

- Root npm test: 67 passed, zero failed/skipped; generated Dart and strict
  generated TypeScript were exercised.
- Runtime flutter test: 401 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 22 passed; strict TypeScript, build and npm pack --dry-run passed.
- Example: 17 passed, including a rerun after baseline correction; codegen
  --check wrote nothing, signed built-in verification passed (seq 1792704210,
  one file), and debug APK built successfully.
- Flutter pub publish --dry-run: zero warnings.
- Site npm run build: 29 pages; SEO/link/anchor checks passed after doc correction.
- Independent security review: no remaining confirmed findings; focused CLI
  shape/additive tests 10 passed, appearance/runtime/updater tests 164 passed,
  clean Dart analysis, zero-write codegen and signed verification passed.

The review covered both incoming account/data protections and R8's owning-view
metrics, optional fontScale, strict generated delegations, JSON-only publication,
nonce/navigation/CSP retention, update notification ordering and matching docs.
It caught the stale template-version claim; that claim is corrected.

No new emulator run; prior Android evidence below remains historical. TalkBack
and true split-screen remain unverified; iOS is experimental and untested.
No test-app writes, package-version changes, pushes, publications or merges into
shared branches. Exactly one queue item was refreshed in this run.

---

# R8 capability/codegen queue refresh - 2026-10-23

## In plain terms

R8 now includes packages at 637edcda14fd7ebb279d06f8cf4eac1cda634411 and site
packages at f77979aa2bead2aca2b14af08c00768ac482e8e9. Both worktrees remain on
codex/r8. Code merge: 985a8b9. Site merge: d0b18cd; README correction: e10f193.
Template/example schema remains 7 and app.appearance remains since 7.

Read both apps' VALENCE_FINDINGS.md and newest iteration reports: Kundalini
iteration 11 (2026-10-23) and app-a iteration 8 (2026-10-22). App observations
remain historical evidence; test-app repositories were read only.

Decision: retain required EVENT_SINCE regeneration, method/event collision
refusal and data.list-after sibling enforcement, because a false capability
gate can silently strand a feature even on capable hosts. Preserve all incoming
data/security safeguards and R8's status-before-updateReady ordering. The sole
merge conflict was agent guidance: retain both the upstream lifecycle/codegen
requirements and the adaptive UI setup. Correct the site's stale README mention
of schema 5 to schema 7. No runtime redesign or package version changes.

## Fresh gates

- Root npm test: 66 passed, zero failed/skipped; generated Dart and strict
  generated TypeScript were exercised.
- Runtime flutter test: 397 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 22 tests passed; strict TypeScript, build and npm pack --dry-run passed.
- Example: 17 tests passed; codegen --check returned written: []; signed built-in
  verification passed (seq 1792638425, one file); debug APK build passed.
- Flutter pub publish --dry-run: zero warnings.
- Site npm run build: 28 pages; SEO/link/anchor checks passed.
- Independent security review: no confirmed findings. Targeted CLI additive-field
  and parameter tests passed 3/3; bridge tests 22/22, strict TypeScript, example
  codegen check, diff check and shared-base ancestry also passed in review.

Review covered schema 7/since 7, optional fontScale, owning-view metrics, generated
capability gating, JSON-only appearance publication, nonce/navigation/CSP retention,
status publication after lease release and before updateReady, and site consistency.

No new emulator run. Earlier Android evidence below is historical; TalkBack and
true split-screen remain unverified. iOS remains experimental and untested.
No pushes, publications, shared-branch merges or test-app writes.

---

# R8 queue refresh after doctor and widget-harness merges - 2026-10-23

## In plain terms

R8 now includes packages at e3ec37d8c340ab83d834d63b5eab5d17fa445d51 and the
site packages at f5ed69395766afe9a958a1876943838b4a14493d. Both worktrees are
on codex/r8. The code merge is ee63bfd; the site merge is f9bdf72.
Template/example schema remains 7 and app.appearance remains since 7.

Read both apps findings and latest reports: Kundalini iteration 11 (2026-10-23)
and app-a iteration 8 (2026-10-22). Their device observations remain historical
app evidence; this refresh does not claim a new app or emulator run.

Decision: preserve all incoming doctor failures, data protections and host-widget
coverage. The sole conflict was in the generated app instructions: retain both
the release-time doctor rule and R8 accessibility guidance, because they protect
different adopter obligations. No runtime redesign, package version change or
schema renumbering was needed. Preserve the earlier R8 fix that publishes completed
update status after releasing the lease and before notifying the page.

## Fresh final gates

- Root npm test: 64 passed, zero failed/skipped; generated Dart and strict
  generated TypeScript were exercised.
- Runtime flutter test: 396 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 21 tests passed; strict TypeScript and npm pack --dry-run passed.
- Example: 17 tests passed; codegen --check wrote nothing; signature/file
  verification passed (seq 1792638425, one file); debug APK build passed.
- Flutter pub publish --dry-run: zero warnings.
- Site npm run build: 28 pages; SEO, links and anchor checks passed.
- Independent read-only security review: no confirmed findings. Its targeted
  additive/fontScale tests (2), bridge appearance/capability tests (6), example
  codegen check and signed built-in verification all passed.

Review covered schema/delegations, optional fontScale, appearance publication,
native zoom, navigation/nonce retention, completed update status ordering, both
merged features and website consistency. Both worktrees were clean after merges.

No new emulator run. TalkBack and true split-screen remain unverified; iOS remains
experimental and untested. Test-app repositories were read only. No pushes,
publications or merges into shared branches occurred.

---
# R8 queue refresh - 2026-10-23

## In plain terms

R8 now includes packages at `6b2eebd009af682d47da48eb079e3db65595fa5d` and the site's
packages at `f0db1cd518bc6dd2af8663097845da980f8b3580`. Both worktrees remain on
`codex/r8`. The template and example retain schema 7 and app.appearance since 7;
all earlier method/event versions remain unchanged. No package versions changed.

Read both test apps' VALENCE_FINDINGS.md and their newest iteration reports:
Kundalini iteration 11 (2026-10-23) and app-a iteration 8 (2026-10-22). Shared
updates now address the reported paging, event capability and update-ready gaps.
The appearance guides use has('app.appearance'), with browser/older-host fallbacks,
rather than comparing an app's own bridge number with the default template's 7.
The example README now names its actual schema.

Decision: preserve the shared data fixes and nonce/navigation/signature checks,
keep R8's reserved number, and publish a completed update status before notifying
the page. Review found that the incoming update-ready callback ran before lease
release and status publication. A new regression failed with idle instead of ready
inside that callback; moving notification after the completed status made it pass.
The regression also checks pending/offered sequence, timestamp and one notification.
The strict bridge gate caught a missing appearance entry in the test event-version
table; it now records 7. Spec and site lifecycle guidance describe the ordering.

## Final gates

- npm test: 60 passed, zero failed/skipped; generated Dart analyzed and executed
  with Flutter, and generated TypeScript passed strict checking.
- Runtime flutter test: 387 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 21 tests passed; npx -y -p typescript tsc --strict -p tsconfig.json and
  npm pack --dry-run passed.
- Example: 17 tests passed; codegen --check wrote nothing; signed built-in
  verification passed (seq 1792638425, bridge requirement 7); debug APK passed.
- Site npm run build: 27 pages; SEO, link and anchor checks passed.
- Flutter pub publish --dry-run: zero warnings.

Final independent security review has no remaining confirmed findings. It also
checked both shared-head ancestors, generated EVENT_SINCE wiring, schema 7,
appearance publication, optional fontScale, retained trust boundaries and docs.

No new emulator check ran. Historical Android evidence below is not fresh device
validation of this combined build. TalkBack and true split-screen remain unverified;
iOS remains experimental and untested. Test-app repos were read only. No pushes,
publications, package-version changes or merges into shared branches occurred.

---

# R8 merge refresh - 2026-10-22

## In plain terms

The R8 branch now includes the latest lifecycle, update-status, paging and database-safety
changes from packages at c55446f3d73afec7672c2615b0ffe70f1a6a074d. Appearance is reserved at
bridge schema 7 (event since 7); version-5 paging and version-6 lifecycle remain intact.
The site branch includes its packages base 5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390;
its refreshed docs commit is 75c3971. Package merge commit: 2b77b9c.

Decision: retain the startup guard before resume update/sync work while allowing a scheduled
appearance refresh. Security/state-transition ordering takes priority over appearance delivery.
Keep optional AppInfo.fontScale for source compatibility with old generated schemas. Preserve
example custom methods; regenerate both clients and sign a new built-in rather than resolving
conflicting generated output by choosing one side. The new built-in is seq 1792638425,
requires bridge 7, and signature/file verification passes. Adaptive layout now occupies
contracts section 4.7; lifecycle remains section 4.6.

Fresh input: both apps' VALENCE_FINDINGS.md, Kundalini ITERATION_10_REPORT.md and app-a
ITERATION_7_REPORT.md. App-a's system-bar overlap informs this feature; delayed label painting
is not established as an inset bug. Test-app repositories were read only.

## Fresh gates

- Root npm test: 60 passed, 0 failed, 0 skipped; generated Dart compiled/analyzed/executed
  against a real Flutter toolchain and generated TypeScript passed strict checking.
- Runtime flutter test: 384 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 19 tests passed, strict TypeScript passed, npm pack --dry-run passed.
- Example: 17 tests passed; codegen --check wrote nothing; built-in verification passed.
- Site final npm run build: 27 pages, SEO/link checks passed.
- Example flutter build apk --debug: passed (assembleDebug 249.4 seconds).
- Flutter pub publish --dry-run: 0 warnings.

Independent valence-reviewer pass found no confirmed security/specification defects. It checked
schema/delegations, owning-view metrics, JSON-only publication, nonce/navigation/CSP retention,
resume startup integration, example and docs. It independently passed the optional-field
regression and the example codegen check.

No new emulator run was attempted for this merge refresh (optional for the rebase queue).
The device observations below are historical 2026-10-21 evidence on bridge 5, not a claim
that the combined schema-7 build was device-tested. TalkBack and true split-screen remain
unverified; iOS remains experimental and untested. No package versions changed.

---

# R8 validation — 2026-10-21

## In plain terms

The web page can keep controls clear of system bars and cutouts, follow Android's system text size,
and respond to dark mode, high contrast and reduced motion. Rotation and settings changes update the
existing document. The host supplies CSS values and native text zoom; the page supplies padding and
accessible HTML. Existing pages need the content-padding change described in [the guide](accessibility.md).

Both worktrees use `codex/r8`, created from `packages` at `406d153`. Package implementation commits:
`f88df9c`, `a93e84e`, `11979b8`, `28b718e`. Site commit: `9795cd3`.
No package versions changed. Nothing was pushed or published.

## Required gates

| Command | Result |
|---|---|
| Root `npm test` | 56 passed, 0 failed, 0 skipped; generated Dart analyzed and ran in a real Flutter project |
| `packages/valence`: `flutter test --no-pub` | 343 passed |
| `packages/valence`: `dart analyze --fatal-infos .` | No issues |
| `packages/bridge`: `node --test test/*.test.ts` | 19 passed, 0 skipped |
| `packages/bridge`: `npx -y -p typescript tsc --strict -p tsconfig.json` | Passed |
| Site: `npm run build` | 26 pages, SEO check passed |

Additional gates: example `flutter test --no-pub` (15 passed), example debug APK build,
example `codegen --check` (zero writes), bridge `npm pack --dry-run`, and Flutter
`pub publish --dry-run` (zero warnings). No iOS build or execution was attempted.

The first npm run found a doctor test that replaced the literal schema-4 version to simulate a broken
host. The schema-5 template made that replacement a no-op. It now matches the generated version
declaration independent of its number; the targeted test and the final full suite pass. A pub dry run
before commits warned about modified/deleted tracked example files; the final clean-state run has no warnings.

## Android evidence

The emulator lock was acquired as `codex-builder` and released. The final debug APK runs signed
built-in bundle **1792604523**, bridge **5**. Its page has a main landmark, a labelled token input,
48px minimum buttons, flexible text and inset padding. These checks used only the framework's own
example; neither test app repository was modified.

- Portrait: viewport 411 × 914 CSS pixels, top inset 50.2857px, bottom 24px. The heading begins at
  74.2857px (24px content padding plus top inset).
- System font size 200%: the system's nonlinear scaler evaluates 16px at **1.75×**. Both the CSS
  value and a fresh `app.info` reply report 1.75. Heading height changes from 33.5952px to 58.8036px,
  a 1.75 ratio. Native Android text zoom supplies this change; CSS does not multiply it again.
- Landscape: viewport 914 × 411, cutout inset moves to the left (50.2857px), top becomes 28.1905px.
  The page's in-memory marker remains **0.5273480429414573** through rotation and theme changes.
- A temporary `wm size 900x1600` override resizes the owning viewport to 609 × 343 in landscape;
  left inset updates to 33.5238px. This is a viewport-resize test, not a true split-screen run.
- Dark mode and disabled transition animations deliver `app.appearance` changes and update root
  attributes. Resuming preserves the marker and emits `app.resumed` without losing native bridge calls.
- Final keyboard test: Android reports `mInputShown=true` and `mIsInputViewShown=true`; viewport height
  drops from **914 to 578**, while the system-bar bottom inset remains **24px**. The labelled input
  stays visible above the IME. The keyboard closes and the viewport returns to 914px.
- Final dark and light screenshots were inspected: status icons follow the system appearance and
  the bottom navigation icon brightness is explicitly selected for both modes.

Snapshots and screenshots are in [r8-evidence](r8-evidence/). Landscape, resize and resume snapshots
come from the first signed probe (1792603719); final dark, keyboard and restored-light snapshots use
1792604523, which adds the semantic landmark/label and the final system-bar treatment.

The example was force-stopped; its existing data was retained. Device size, rotation, font size,
night mode and animation settings were restored to their prior values. Only this run's adb forward
(19388) and screenshot file were removed. No local server was started for this item.

## Review and limits

Independent review covered contracts §4.6, the JSON-only script publication, lifecycle timing,
optional AppInfo growth, generated delegations, nonce/navigation/CSP preservation, example and docs.
It found and resolved: a missing explicit edge-to-edge request, raw versus nonlinear AppInfo scaling,
and Flutter's default light navigation icons in its nominally dark overlay style. No confirmed findings
remain. A screenshot separately exposed the need to rebuild system-bar icon styling on theme changes.

The nonlinear regression supplies raw scale 2 with a 16px evaluated scale of 1.75 through an attached
test view. Other regressions cover logical insets excluding the keyboard, rotation, OS accessibility
snapshots, repeated script execution without compounded iOS scaling, typed subscriptions/unsubscribe,
and old/new generated AppInfo shapes. Overlay rendering has device evidence, rather than a fake-widget
assertion about platform behavior.

iOS is experimental and untested. Its fallback scales rem/em text from the document's original root
font size; fixed pixel fonts do not follow it. Android uses one zoom percentage, rather than a full
nonlinear size mapping. High-contrast payloads are unit-tested; the Android run reported false, so
no device high-contrast behavior is claimed. TalkBack spoken output and true split-screen were not
exercised. The accessibility guide documents semantic HTML, contrast, focus and touch-target checks
for adopters. These signals do not certify an arbitrary page as accessible.

Input context: both apps' `VALENCE_FINDINGS.md`, Kundalini's newest `ITERATION_9_REPORT.md`, and app-a's
latest standalone handoff `NEXT.md` (cycle 5), with its later F-21–F-25 findings in the findings file.
Their update/cache, sync and identity reports were read as context, without widening R8 into those fixes.
