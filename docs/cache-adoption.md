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

## Latest packages refresh - 2026-11-04

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
