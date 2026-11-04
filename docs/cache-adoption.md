# REST cache adoption follow-up - 2026-11-04

In plain terms: Kundalini iteration 19 found two adoption traps after successfully
using the cache offline. Revision 18 is a package minimum, while a method newly
added to a store-19 app must declare 20. Once shipped, that declaration is frozen.
The CLI now names the recorded built-in definition to restore instead of proposing
an alias that cannot delegate. A regression exercises codegen and store bundling,
checks the baseline stays byte-identical on refusal, and checks restored delegation.
The reference example vendors the updated CLI byte for byte.

The spec, repository guide, package README, public cache/data/config guides and
machine-readable summary now distinguish these numbers. The template stays at 18
for new apps with no store baseline; generated shapes are unchanged.
The repository guide also carries the existing trial-failure cache warning.

Decision: preserve the shipped contract, sync completeness and users' data before
convenience. A cache grant is not a sync exemption. Document valid empty server
pages/indexes for new empty overlay buckets, HTTP 404 as incomplete, retained
partial progress, and the no-sync-base case. Do not silently skip missing buckets
or add a per-bucket cache-only mode to the frozen candidate. F-75 is corrected in
source; F-76's documentation request is addressed. Neither correction is claimed
as adopted by the test apps.

Read both findings inventories and the newest completed reports read-only:
Kundalini 19 / App C 103. Kundalini records F-71 and F-72 as fixed and device
checks for cache grants, pull eviction and offline rollback disposal. Those are
saved app reports, not device checks replayed here. App C records artifact audit
success but scoped acceptance=false after an initial bounded CDP/startup failure;
later success does not erase it. Its first backup was rejected when a WorkManager
process appeared during transfer. Historical reliability findings remain open.

Feature started from code e36d2ae / site a3a3208. During final verification,
packages advanced to code 5a568454c46b4bb62b33193a6ca96ba1ba3c5842 / site
2f28a8fdd025c40c984e92c32bd9f636fa591803. Both were merged into this branch.
The incoming commit independently fixed F-75/F-76 as well as account-cookie
isolation, background ready timing, late rollback cache writes and prototype-name
notification fields. Kept that implementation intact, including its shape-aware
built-in classification, rather than the earlier name/revision-only diagnostic.
The follow-up now adds the store-19-to-20-to-refused-18 regression, explicit
baseline recovery location, concrete JSON declaration/page examples and scoped/
no-sync qualifications. Overlapping paragraphs were reconciled while preserving
the incoming runtime warnings. Merge commits: code c3b1e55 / site 7be91e6. A subsequent packages commit,
f47263d2d028ee5a2bb03d2627b9c3797320c024, aligns the CLI version with the
runtime release; merged as 65779cc and reran the root suite. No feature-specific
version change is introduced. Runtime and site sources are identical across
that version-only merge, so their gate results below retain the same scope.
All pre-existing feature tips were already ancestors of packages in both repos;
the original rebase queue is done. This is the only unmerged feature branch, so
the later-branch two-unmerged integration trigger is not met.

## Validation

Merged-tree validation on 2026-11-04:

- Root npm test: 116 passed, zero skips; generated Dart and strict/verbatim TS ran.

- Core: 620 Flutter tests passed; fatal-info analysis clean.
- Core publish dry-run: zero warnings after committing the README.
- Bridge: 36 tests passed, strict/verbatim TypeScript passed, npm pack dry-run passed.
- Optional push: 2 tests passed, fatal-info analysis clean, publish dry-run zero
  warnings (one existing local path-override hint).
- Site: npm run build plus SEO passed, 50 pages.
- Example debug APK: passed, assembleDebug 34.6 seconds; existing future Kotlin
  plugin compatibility warning remains. Windows py Firebase audit: PASS, core
  graph plus manifest and all 19 DEX files contain no Firebase SDK references.
- Diff hygiene passed. The initial root run caught an unsynchronized example CLI;
  it was copied before the final run. No failed check is counted as a pass. Root/generated Flutter checks and core
  Flutter tests ran sequentially for merged-tree verification.

Logs: %TEMP%/valence-cache-root-version-aligned.log,
valence-cache-root-merged.log, valence-cache-core-merged.log,
valence-cache-bridge.log, valence-cache-push-merged.log,
valence-cache-site-merged.log and valence-cache-apk-merged.log. The standalone
Windows py Firebase audit was run again against the rebuilt APK and printed PASS.

Security-path checklist (relative to current packages): the inherited diagnostic
still refuses the same edits;
normal additive growth remains ahead of the refusal, and legacy app-owned methods
retain their existing advice. Verification order, signatures, strict decoding,
nonce, navigation/subframe locks, atomic state writes, key handling, compiled
cache grants, account clearing and release-mode development exclusion are unchanged.
No fresh emulator or independent security-review acceptance is claimed. iOS remains
experimental and untested. No test-app writes, protected-branch changes, package
version changes relative to packages, pushes or publication.

## Build-digest packages refresh - 2026-11-04

Merged code packages `58c25e1747e6e25997756501854049b410290605` and site
packages `6381d682f23260569490a996aeab0a08501f95e4` without conflicts, producing
code `161743a` and site `116da4a`. The incoming CLI build digest and
cookie-generation ceiling comment are preserved. The CLI now reports
`0.4.0-beta.0+build.7b21f6d02660`; its example copy remains byte-identical.
No package version or app-schema declaration was changed by this refresh.

Decision: keep the candidate's security and data contracts, and refresh the
existing cache follow-up rather than start deferred runtime work. All current
feature branch tips except this branch are ancestors of packages in both repos;
there is only one unmerged feature branch, so the integration trigger is not met.
Every must-have and original queue item is done. S1 remains explicitly parked,
S2 needs a Play account, and S9 is explicitly assigned to 0.5 unless device
evidence establishes a leak. No lease cause is inferred from a busy result.

Read the findings inventories and latest completed reports read-only: Kundalini
19 and App C 104. Kundalini's F-75/F-76 adoption remains unverified after this
follow-up. App C's saved audit records 75 passing artifact checks and scoped
acceptance=true; its same-PID Settings continuation follows an initial null-root
UI dump, which remains qualified. The report confirms receipt of corrected
dependency guidance, while the historical F-45 entry remains open. The legacy-port
inventory and early share screenshot also remain qualified. Recomputed both
archived APK hashes against the delivery manifest; both match. Rehashed the raw
activation snapshots: both are `e99e6b635f1befa7c7c06bf310a4d33096ab28f6bd8f745df194ceef807fb6a5`,
with pending 1793798021 and no trial. The saved worker
proof correlates PID 8269 callback completion and native SUCCESS. One explicit
trigger after timing readiness proves execution, not natural scheduling or cadence.
Historical reliability findings remain open; retained file totals establish no
leak or per-iteration growth rate. These reports were read, not replayed.

Fresh merged-tree gates on the refreshed branch:

- Root: 117 tests passed, zero skips, including generated Dart and strict/verbatim TS.
- Core: 620 tests passed, fatal-info analysis clean, publish dry-run zero warnings.
- Bridge: 36 tests passed, strict/verbatim TS and pack dry-run passed.
- Optional push: 2 tests passed, fatal-info analysis clean, publish dry-run zero
  warnings and the existing local path-override hint.
- Site: 50 pages built; SEO checks passed.
- Example debug APK: passed, assembleDebug 166.1 seconds; the existing future
  Kotlin-plugin compatibility warning remains. Standalone Windows py Firebase
  audit: PASS for the core graph, manifest and all 19 DEX files.

Logs use the prefix `%TEMP%/valence-cache-refresh-` with suffixes `root.log`,
`core.log`, `bridge.log`, `push.log`, `site.log`, `apk.log` and `firebase.log`.
Flutter gates ran sequentially. No new emulator acceptance is claimed.
The security-path checklist above remains applicable: relative to packages, this
branch changes documentation and a regression test, with no runtime, generator,
template, package-version or schema delta. iOS remains experimental and untested.

## Reviewer-fix packages refresh - 2026-11-04

Packages advanced during finalization to code
`34f4d3c7315d9b23234302bd9001675c7c350229` and site
`a903436984bc0213337f69fb8bb4f5e767cdd4f8`. Merged them as code `f3aaa3d`
and site `41899af`. The code merge was clean. The site's one conflict was in
`llms.txt`; it now preserves both the explicit store-baseline arithmetic and the
incoming rollback-specific document rule, including keeping cache writes closed
when reload throws. Automatically merged cache guides and the spec retain the
same rule. No new behavior was invented to resolve the conflict.

Preserved all incoming fixes: rollback blocks wait for the replacement swap;
outgoing cookies and CSRF mirrors check the captured account generation; built-in
diagnostics use the actual notification/push delegation floors; prototype names
remain app-owned; the added widget and cookie regressions remain intact. The
extra cache-adoption regression still checks the frozen store-20 definition.
The CLI and its example copy now report build `08ffaeec8e81`. No version number
or app schema was changed here. The branch's delta from packages still contains
no runtime, generator or template changes.

Decision: preserve the upstream security fixes and repeat all gates against the
new merged trees. The earlier results above describe the previous base only.
Repeated validation passed on 2026-11-04:

- Root: 117 tests, zero skips, including generated Dart and strict/verbatim TS.
- Core: 622 tests, clean fatal-info analysis, publish dry-run zero warnings.
- Bridge: 36 tests, strict/verbatim TS and pack dry-run passed.
- Optional push: 2 tests, clean fatal-info analysis, publish dry-run zero warnings
  and the existing local path-override hint.
- Site: 50-page build and SEO checks passed after conflict resolution.
- Example debug APK: passed, assembleDebug 43.2 seconds; existing future
  Kotlin-plugin compatibility warning retained. Standalone Windows py Firebase
  audit: PASS for the core graph, manifest and all 19 DEX files.

Logs use `%TEMP%/valence-cache-refresh2-` and the same suffixes as above.
Flutter gates ran sequentially. Diff hygiene passed; the two validation notes are
identical. App evidence and platform limits are unchanged. Only this feature
branch remains unmerged, so no integration rebuild is required. No test-app or
protected-branch writes, version changes, push, publication or new device
acceptance is claimed.

## Lease-diagnostics packages refresh - 2026-11-04

In plain terms: refreshed this cache-adoption follow-up on code packages
`9b156960fd358d327070e7eb026f3ead3ebd5fd8` and site packages
`2f3905fba5a19589c38d81d187a7c8119d07e7bc`. Both merges were clean
(code `cacd4a1`, site `cbdd738`). Preserved upstream revision-20 lease
fields, diagnostics and docs; no lease acquisition or expiry change was added.

The first root run passed 117 of 118 tests: this branch's regression used the
moving starter template as Kundalini's store-19 fixture. The revision-20 template
correctly demanded 21, so its expectation of 20 failed. Commit `778e69b` pins
that historical fixture to 19 and omits the later lease fields. The final full
root run passed all 118 with zero skips, including generated Dart and strict TS.
This correction changes only the fixture, not runtime or app-schema behavior.

Decision: preserve the shipped additive contract, users' data and incoming
security fixes, and refresh the existing follow-up before any new feature.
Every must-have and original queue item is done. All current feature tips except
this branch are ancestors of packages in both repos; archived integration
checkpoints are not unmerged features. The two-unmerged-branch integration
trigger is not met. S1 stays parked and S2 still needs a Play account. S9's
upstream diagnostics are retained without inventing a lease leak or closing F-44.

Read both findings inventories and latest completed reports read-only: Kundalini
19 / App C 105. Kundalini's F-75/F-76 correction adoption remains unverified.
App C's saved audit has 74 passing artifact checks and scoped acceptance=true.
Independently rehashed both archived APKs against its delivery manifest: both
match. Rehashed the raw activation snapshots: both are
`d76bf41f4ef57badf08d57bab4ad1f5d5bd022ddb37aab333d18430755cab3f5`,
with pending 1793805223 and no trial. Its worker receipt correlates PID 7498
callback completion with native SUCCESS. One explicit trigger after timing
readiness proves execution, not natural scheduling or cadence. Historical
reliability findings stay open. Initial null-root sampling, the black grant PNG,
mispositioned early widget PNGs and preparation errors remain qualified. Retained
file totals establish no leak or growth rate. Saved device evidence was read,
not replayed; no new emulator or adopter acceptance is claimed.

Fresh gates on the merged trees, run with Flutter operations sequentially:

- Root: 118 passed, zero skips, generated Dart and strict/verbatim TS included.
- Core: 627 Flutter tests, clean fatal-info analysis, publish dry-run zero warnings.
- Bridge: 36 tests, strict/verbatim TS, npm pack dry-run passed.
- Optional push: 2 tests, clean fatal-info analysis, publish dry-run zero warnings
  and the existing local path-override hint.
- Site: 50-page build and SEO checks passed.
- Example debug APK: passed, assembleDebug 34.2 seconds; existing future Kotlin
  plugin compatibility warning retained. Standalone Windows py Firebase audit:
  PASS for the core graph, manifest and all 19 DEX files.

Logs: %TEMP%/valence-cache-refresh3-{root,root-retry,core,bridge,push,site,apk,firebase}.log.
The initial failing run remains recorded; only the successful retry counts.
Security checklist relative to packages: no runtime, generator, template, package
version or app-schema delta. Signature/check order, nonce, strict decoding,
navigation/subframe lock, atomic writes, keys, account isolation, cache grants
and release-build dev exclusion remain unchanged. Diff hygiene passed.
The matching code/site notes document the same scope. iOS remains experimental
and untested. No test-app or protected-branch writes, push or publication.

## Reviewed lease-diagnostics refresh - 2026-11-04

In plain terms: refreshed the existing cache-adoption follow-up on code packages
`da23d35d239ddf3b3d613cc8bf7c232347012aaa` and site packages
`3e00b75a94d64e6e64e22ec2f48e3366301de4d7`. Both merges were clean
(code `74c8dd0`, site `a980434`). Preserved the incoming reviewer fixes:
observational logging cannot throw through lease acquisition, status and acquisition
share the held-row predicate, and take/release logs bracket the lease primitives.
The docs retain that kind names a trigger class, not an individual foreground run.
No acquisition, renewal or expiry change was introduced by this follow-up.

Decision: preserve security, users' data and the additive contract; refresh this
unmerged follow-up rather than invent a cancellation fix. Every must-have and
original queue item is done. Verified all current feature tips in both repos:
only cache-adoption is unmerged, so the two-branch integration trigger is not met.
S1 stays explicitly parked; S2 still needs a Play account. No schema or package
version changed. The branch delta from packages contains docs and one CLI
regression test, with no runtime, generator or template change.

Read both findings inventories and latest reports read-only: Kundalini 19 / App C
106. Kundalini has not yet verified adoption of the F-75/F-76 corrections. App C's
saved audit has 76 passing checks and scoped acceptance=true; read, not replayed.
Independently rehashed both archived APKs against its delivery manifest: both match.
The two raw activation snapshots hash to
`8fd380725eec472986df178fcce85fa5d326956a1f0d06d1fb5e9ea1a7f83293`,
with final 1793808601 pending and no trial. PID 8068's callback completion and
native SUCCESS correlate with native background enter/take/release/leave logs,
including heldForMs=1330. Foreground refusals in PID 5299 name foreground holders.
These receipts establish current diagnostics and one successful explicitly
triggered execution, not natural cadence, cancellation or expiry correctness.
Schema-16 returned fields remain unchanged; the revision-20 optional fields were
not adopted in this app. F-44 and historical reliability findings remain open.

F-46 records stale lock integrity after replacing a same-path prerelease tarball.
Read the before/after receipts: explicit reinstall matches the new SHA512, and
all five rebuilt web files match the signed builtin. This is snapshot-installation
evidence, not a new runtime defect or a closed public-docs finding. Initial
null-root sampling, the black grant PNG, early off-page widget images, preparation
errors and overlapping doctor/build execution remain qualified. Retained file
totals establish no leak or growth rate. No fresh emulator/adopter acceptance.

Fresh gates on these merged trees passed, Flutter operations sequentially:

- Root: 118 tests, zero skips, generated Dart and strict/verbatim TS included.
- Core: 631 tests, clean fatal-info analysis, publish dry-run zero warnings.
- Bridge: 36 tests, strict/verbatim TS, npm pack dry-run passed.
- Optional push: 2 tests, clean fatal-info analysis, publish dry-run zero warnings
  and the existing local dependency-override hint.
- Site: 50-page build and SEO checks passed.
- Example debug APK: built, assembleDebug 28.8 seconds; existing future Kotlin
  plugin compatibility warning retained. Standalone Windows py Firebase audit:
  PASS for the core graph, manifest and all 19 DEX files.

Logs: %TEMP%/valence-cache-refresh4-{root,core,bridge,push,site,apk,firebase}.log.
Security checklist relative to packages: signature/check order, nonce, strict
decoding, navigation/subframe lock, atomic writes, key handling, account isolation,
cache grants and release-build dev exclusion retain the incoming implementation.
Diff hygiene passed. Matching code/site notes record the same scope. iOS remains
experimental and untested. No test-app or protected-branch writes, push or publication.

## Iteration 107 evidence review - 2026-11-04

In plain terms: the latest app receipts do not establish a new Valence runtime
fix. Read both findings inventories and newest reports, Kundalini 19 / App C 107,
without writing into either app. Kundalini has no newer report verifying adoption
of the F-75/F-76 corrections. App C's saved audit passes all 79 artifact checks
but explicitly sets scoped acceptance=false. Its F-47 reminder warning is fixed
in the app; F-48 missing History API/popstate integration remains open. Android's
activity dump records the detail activity finishing and the retained Photo Picker
resuming. A transitional detail screenshot does not establish the final visible
page. The existing host contract already requires navigable web history.

Decision: preserve security, users' data and the frozen additive runtime rather
than change native Back or lease semantics to compensate for an app issue or an
unattributed timeout. All must-haves and original queue items are done. Checked
current feature tips in both worktrees: cache-adoption alone is unmerged, so the
two-branch integration condition is not met. S1 remains explicitly deferred and
S2 still needs a Play account. Bases remain code packages
`da23d35d239ddf3b3d613cc8bf7c232347012aaa` and site packages
`3e00b75a94d64e6e64e22ec2f48e3366301de4d7`.

Read the saved evidence rather than replaying the device run. Independently
rehashing both archived APKs matches the delivery manifest. Both raw activation
files hash to `48a15908557f6c4e30958c28dca869cdd6a3e25a654d17e57f1a3c96549291da`:
final 1793812346 remains pending with no trial across the isolated worker phase.
Raw worker log lines correlate PID 8696 callback begin/complete, native SUCCESS
and background enter/take/release/leave; the release logs heldForMs=970. The saved
stable SQLite receipt records both outgoing objects, the incoming fixture and
outbox=0 before foreground. This proves one explicitly triggered execution,
not natural cadence, cancellation handling or lease-expiry correctness. F-44 and
historical reliability findings remain open. Later final commit and cleanup are
separate from the worker-phase activation comparison.

The same-page denied/granted reminder receipt verifies that the corrected app
warning clears without a reload. APK builtins predate that web-only correction;
the final signed OTA is the corrected delivery. Initial post-Back OTA polling,
warning-probe activation race and null-root paint sampling remain qualified.
Unchanged local docs/tarballs do not establish adoption of older documentation
corrections. Retained publication size establishes no leak or growth rate.
No fresh emulator acceptance or iOS validation is claimed.
Fresh gates passed on the unchanged packages bases, with Flutter operations
sequential: root 118/118 zero skips (generated Dart and strict TS included), core
631/631 and clean fatal-info analysis, bridge 36/36 with strict/verbatim TS and
pack dry-run, optional push 2/2 and clean fatal-info analysis, both pub dry-runs
zero warnings (push retains its local dependency-override hint), and the 50-page
site build with SEO checks. The example debug APK rebuilt in 20.3 seconds;
the existing future Kotlin plugin compatibility warning remains. Standalone
Windows `py` audit printed PASS for the core graph, manifest and all 19 DEX files.
Logs: %TEMP%/valence-iteration107-{root,core,bridge,push,site,apk,firebase}.log.

This run changes only these matching validation notes. No runtime, generator,
template, schema or version change. Security checklist against the prior branch
tip: verification/check order, nonce, strict decoding, navigation/subframe lock,
atomic writes, keys, account isolation, cache grants and release dev exclusion
are unchanged. Diff hygiene passed. No protected branch, test app or other
builder worktree writes, push or publication.