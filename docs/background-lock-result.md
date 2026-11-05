# Background lock result correction ? 2026-11-06

In plain terms: keep the packages classifier, and add committed-page accounting
and explicit work/cleanup error precedence on top. This supersedes the rejected
candidate 8c6d186; that candidate and integration remain preserved on
codex/background-lock-result-before-20261106-review and
codex/integration-before-20261106-review in both repositories.

## Decision and scope

Start from code packages 0fe3391 / site packages 0c46890. Preserve the busy branch
around acquireLease: a locked acquisition attempted no sync work. A lock during
work returns failed, unless an earlier unauthorized/offline outcome takes
precedence. Count HTTP pages and static chunks immediately after commit, before
lease renewal. Public pullPair retains its API; only private helpers receive the
callback. Codegen and templates already delegate to the runtime and need no
change. No package versions or schema numbers change.

Security and users' data first: no pre-emption, lease-policy change, migration,
retry increase, outbox mutation, activation change or verification simplification.
Keep packages' release-only lock policy: log safely, retain the completed result,
and let the existing TTL handle a row that could not be cleared. Preserve a
primary non-lock failure and its original stack across cleanup errors. A non-lock
cleanup failure after a primary lock surfaces rather than being recovered.
The runtime's existing final-read lock backstop remains: it cannot recover counts
that were unreadable. This is narrower than the rejected candidate's claim that
such a failure always propagates; that unrelated policy change is dropped.

## Regression loop and qualifications

On unmodified packages runtime, runtime_test.dart --plain-name 'background lock
preserves committed progress' passed the completed-pair case but failed the
interrupted-pair case: expected changed=1, actual=0. This identifies the requested
accounting seam without speculative root-cause hypotheses. These tests inject a
classified lock at the real next SQLite transaction, not at an HTTP boundary.
Additional cases cover static chunks, renewal after commit, authorization/offline
precedence, error identity during cleanup, release-only outcome and safe logging.
The acquisition-busy and mid-run-failed tests from packages are retained.

The first test invocation ran from the repo root and found no pubspec; the next
ran before the insertion matched and found no tests. Neither is a red signal.
The first full focused run exposed an incomplete existing fake (delete was
unimplemented, formerly swallowed); its delete now succeeds as intended. A
release-only test initially left a non-writable outbox bucket, which correctly
made its work incomplete; that unrelated fixture was removed so it tests a
completed run. The first full core run passed 647 tests; fatal-info analysis then found a missing
brace in the new logger test. That style issue was corrected before the final
gates. No production assertion or timeout was weakened. Logs remain at
TEMP/valence-nov6-review-*.log. Full gates are recorded in integration.md.

Read-only inputs: both apps' VALENCE_FINDINGS.md inventories and latest completed
reports, Kundalini 21 and app-c 128. App-c reports scoped acceptance=true, Settings
painted in PID 5500, and one explicitly triggered ready worker in PID 9090. Those
are app-reported evidence, not fresh device validation of this branch. Kundalini
F-80 contention and historical reliability findings remain open. No emulator
session or iOS validation; iOS remains experimental and untested.
