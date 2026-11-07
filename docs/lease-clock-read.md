# Queued lease clock correction (K F-83) - 2026-11-08

In plain terms: a foreground sync could take a live sibling's lease because it
compared a newer database row with a clock sampled before the database wait.
The clock now comes from after the transactional lease query. Rebuild the native
host; apps need no schema, web code, generated code or configuration change.

## Decision and scope

Security first, then users' data: fix the demonstrated comparison error while
preserving current packages' two-minute TTL, bounded same-process clock tolerance,
foreign-process recovery and existing lease row format. A same-process future
row less than the TTL ahead stays held; at least the TTL ahead remains recoverable. Do not make same-process leases immortal:
a cancelled isolate can leave one behind, and that would remove its recovery path.
The read, decision and write remain inside the existing transaction. Both new
lease timestamps use the same post-read sample. Diagnostics measure acquisition
age as before. No migration, new API, package version, CLI or template change.
Generated hosts already import this runtime; copying the fix into codegen would
give every app its own runtime again.

All must-have items and the original rebase queue are done. Both worktrees started
this follow-up on codex/lease-clock-read from current packages: code 84e0dec,
site 9afafc0. During gates packages moved to code 74ea9bf / site b877d97,
including another F-83 fix, cleanup corrections and F-84 documentation. Merged
both bases into this branch. Retained upstream policy and corrections, with one
post-query clock sample and these additional transaction-queue regressions.
This is an S9 correctness follow-up, not a new optional feature.
No other roadmap Status cell changes. There is one new follow-up branch;
the integration still needs refreshing because packages moved under rule 0b.

## Reproduction and regression

Command, from packages/valence:

```text
flutter test --no-pub test/lease_clock_test.dart --reporter expanded
```

Before the fix, the first regression failed against the real SQLite transaction
queue with a controlled clock that only advanced:

```text
sync: taking over a lease (kind=foreground, written -11000ms ago): dated in the future, so the clock moved
Expected: false
  Actual: <true>
the sibling is still holding the lease
```

The transaction barrier models a sibling renewal committing while the contender
waits; no timing sleeps or production test hook. The fixed test also checks the
row stays byte-identical on refusal, age stays 11000ms and acquisition succeeds
after the holder releases. A second test queues an empty acquisition for three
minutes, then verifies its new timestamps start after the wait, age is zero and
a second driver is refused. Existing sync tests retain the expiry, future-row,
foreign-owner, renewal, failed-run cleanup and diagnostics coverage.
Initial focused tests before the concurrent packages merge: 75 passed (both new
regressions plus sync_test.dart). The final merged core gate below supersedes
that narrower result.

Independent security checklist: no correctness/security blocker. Reviewed
transaction boundaries, refusal writes, both new timestamps, TTL/rollback/owner
recovery, call sites, cleanup and test barriers. A documentation section-symbol
typo was corrected. The review was static; its observed focused test result is
not a second independent execution. A second review of the merged delta found
no correctness/security blocker; it identified the inherited exact-TTL wording
ambiguity, now corrected to match the existing at-least-TTL recovery boundary.
The queue regressions cover transaction waiting, not a distinction between
transaction-entry and post-query sampling; static inspection verifies the latter.

## Test-app evidence, read only

Read both VALENCE_FINDINGS.md inventories and newest reports: Kundalini 23 and
App C 144. Kundalini's report supplies new major F-83 evidence; the local
regression reproduces its failure class, not the exact Android scheduling trace.
Kundalini reports F-81 fixed and correct link/notification pre-emption. Its
page-age correction matters: log delivery time is not status-read time. Its
release checklist still has partial first-install-offline and unconfirmable
haptics scope; F-83 has no app-layer workaround. Doctor artifact independently
counts 21 PASS / 6 WARN / 0 FAIL. F-84 is a separate minor CLI-versus-snapshot
identity documentation finding, addressed by the merged packages changes.

App C 144 remains an incomplete Android regression. Independently checked all 22
report evidence links, counted doctor 16 PASS / 10 WARN / 1 FAIL, and rehashed
both archived APKs:

- release: 9d427c494fcaba0832d3997f0bfb8d20e4e1bbdc5272a658fbf3251abdc28deb
- debug: 21682e7bd4278308c3e684379500e281cd7654b0a031f63f12141c847995b83b

Independently extracted both builtin manifests (1794082626) and verified all five
files' sizes and hashes in each. Reviewed saved R27 exclusion, R29 wait/completion
and cleanup receipts. R29's completed Valence.open at 28631ms is not painted-page
acceptance. The key scan hit its 180s timeout without an assertion; successful
builds do not erase it. Nonstreaming install succeeded after streamed install
failed, but readiness still failed. No current native/offline/OTA/isolated-worker
or row/photo retention acceptance follows. No Valence cause for those startup
failures is established. Iteration144 overwrote iteration143's old ignored release
archive path before correcting its destination; the earlier receipt remains
historical evidence, not proof that the older binary is still at that path.

Sources: valence-test-kundalini/{VALENCE_FINDINGS.md,ITERATION_23_REPORT.md,
test-evidence/iteration-23/doctor.json}; valence-test-app-c/{VALENCE_FINDINGS.md,
ITERATION_144_REPORT.md,evidence/iteration-144/{doctor.txt,archived-release.json,
archived-debug.json,embedded-file-integrity.json,r27-core-only.json,
r29-device-proof.json,scoped-cleanup.json,install-debug-no-streaming-execution.json}}.

## Gates

Full validation is in progress; this branch is not yet marked ready.

No fresh emulator acceptance is claimed. iOS remains experimental and untested.
No test-app writes, protected-branch commits, version changes, pushes or releases.
