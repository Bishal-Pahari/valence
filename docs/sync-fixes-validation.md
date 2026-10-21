# Sync consistency sprint - 2026-10-21

In plain terms: syncing no longer skips another device's changes or the last page of a catalogue. A new UI cannot activate after only part of its required data arrived. Cleanup cannot remove a candidate's code or data while it becomes pending. Consecutive edits keep insertion order, and an update check waits briefly for ordinary sync instead of repeatedly losing the lease.

## Verified reproductions and fixes

- CR-20261021-1: interleaved pull-through-100, other-device 101 and push echo 102 lost row 101 before the fix. Push echoes now update rows without changing the pull cursor or completion evidence.
- CR-20261021-2 / Shelfkeeper F-29: a 600-row response head with a 500-row first page returned only 500 before the fix. The cursor now follows the last returned row and the test receives all 600.
- CR-20261021-3: HTTP 500, transport failure and budget exhaustion after page one all incorrectly marked a fresh pair complete. Activation tests also incorrectly made the bundle pending. Completion now requires a valid final page or every static chunk; failed pulls retain resumable progress. Added static failure/budget retry tests.
- CR-20261021-4: pausing GC during asset verification let it delete a newly pending manifest/CAS. A controlled directory-create boundary also let GC delete required data after step 7 but before publication. Both failed before the fix. Publication manifests and a revision protect GC snapshots, and the data lease remains held through durable pending state.
- CR-20261021-6: equal timestamps with lexically reversed operation ids reversed edits. Outbox now uses an AUTOINCREMENT ordinal. V1 migration tests preserve ids, values, deletes, stored insertion order and existing cursors; new enqueue, reopen and VACUUM preserve order.
- Shelfkeeper F-30: an update check returned null before the competing sync released. It now waits up to five seconds using a monotonic clock and 25 ms acquisition retries. The same check stages the candidate when the holder releases. Concurrent checks share one request/publication.

Every reported finding was confirmed. Security checks, nonce/decoding, signed formats and package versions are unchanged. The SQLite schema advances to user_version 2 through a data-preserving migration; the CLI seed schema and bundled example seed match it.

## Gates

- npm test: 55 passed, zero skips, including generated Dart/TypeScript and the REST adapter.
- Flutter runtime: 339 passed; Dart analysis clean.
- Bridge: 18 passed; strict TypeScript, build and pack dry run passed.
- Example: 14 tests passed; debug APK built; codegen freshness and signed manifest/file verification passed.
- Site: 25 pages; SEO, links and anchors passed.
- Independent security review: no confirmed findings; migration/static/coalescing coverage gaps were added and independently checked (23 tests passed).

No additional emulator run was performed in this wrap-up; no new device execution is claimed. iOS remains experimental and untested. Existing records already skipped by an older host cannot be inferred from its advanced cursor; republish affected records with higher USNs or provide a new read-only schema. Do not delete queued user data to recover.
