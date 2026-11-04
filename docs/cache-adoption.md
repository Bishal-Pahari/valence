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
for new apps with no store baseline; generated shapes and all versions are unchanged.
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

Feature bases: code e36d2aec4f567295ddc6eaff4da18f7cd8e5fd5a and site
a3a32082310d5d031b3a430d26e8f66684949fa5, newest local packages when started.
All pre-existing feature tips were checked as ancestors of packages in both repos;
the original rebase queue is done. This follow-up is the only unmerged feature
branch, so the later-branch two-unmerged integration trigger is not met.
Implementation commits: code 60f5419 / site 1bc68bf, codex/cache-adoption.

## Validation

All gates passed on 2026-11-04:

- Root npm test: 116 passed, zero skips; generated Dart and strict/verbatim TS ran.

- Core: 617 Flutter tests passed; fatal-info analysis clean.
- Core publish dry-run: zero warnings after committing the README.
- Bridge: 36 tests passed, strict/verbatim TypeScript passed, npm pack dry-run passed.
- Optional push: 2 tests passed, fatal-info analysis clean, publish dry-run zero
  warnings (one existing local path-override hint).
- Site: npm run build plus SEO passed, 50 pages.
- Example debug APK: passed, assembleDebug 187.3 seconds; existing future Kotlin
  plugin compatibility warning remains. Windows py Firebase audit: PASS, core
  graph plus manifest and all 19 DEX files contain no Firebase SDK references.
- Diff hygiene passed. The initial root run caught an unsynchronized example CLI;
  it was copied before the final run. No failed check is counted as a pass.

Logs: %TEMP%/valence-cache-root-final.log, valence-cache-core.log,
valence-cache-core-publish-final.log, valence-cache-bridge.log,
valence-cache-push.log, valence-cache-site.log and valence-cache-apk.log.

Security-path checklist: the diagnostic branch still refuses the same edits;
normal additive growth remains ahead of the refusal, and legacy app-owned methods
retain their existing advice. Verification order, signatures, strict decoding,
nonce, navigation/subframe locks, atomic state writes, key handling, compiled
cache grants, account clearing and release-mode development exclusion are unchanged.
No fresh emulator or independent security-review acceptance is claimed. iOS remains
experimental and untested. No test-app writes, protected-branch changes, package
version changes, pushes or publication.
