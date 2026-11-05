# Background lock result accuracy

In plain terms: a background sync that meets a SQLite lock keeps reporting the
rows it already committed and the writes still queued. It no longer claims
zero for both just because a later operation failed.

## Decision

Preserve security and user data first: leave lease ownership, acquisition,
renewal, expiry and pre-emption unchanged. Record page progress immediately after
commit, before renewal, and classify background/push locks inside the driver
where that progress exists. Foreground locks and non-lock errors still propagate.
Authorization and offline outcomes retain precedence. Diagnostic sink failures
cannot change recovery, and a cleanup lock cannot hide a primary work error.

The final pending count is an authoritative read. If it also fails, propagate
the error rather than manufacture an empty outbox or return a stale snapshot.
This is an explicit limit on lock recovery, not evidence that WorkManager always
succeeds. No new retry budget, database migration, wire field, schema, package
version or public API is needed. Codegen and templates delegate to the runtime
and need no behavior change.

## Regression evidence

The original result-loss cases failed with expected changed=1 / actual=0 for
both a completed first pair and a first page of an interrupted pair. The initial
reproduction injected the classified exception on the second HTTP request; the
final tests instead inject it at the real second apply transaction over SQLite.
Additional tests cover static chunks, push unauthorized/offline precedence,
throwing diagnostics, unreadable pending status, cleanup-only locks and primary
non-lock errors combined with a cleanup lock. These are deterministic fault
injections, not a physical competing-isolate or WorkManager replay reproduction.

The first attempted test insertion used the wrong working directory and matched
no tests; the next compile failed on an unexported constant. Neither is a red
regression signal. The first implementation omitted HTTP page accounting and
failed the intended regressions; that omission was corrected. An attempted
SQLite trigger raised a constraint error rather than a classified lock and was
replaced with an explicit fault at the database call, without weakening lock
classification. Logs for these attempts remain under the task-specific TEMP
valence-nov6-* names. Full gates are recorded in integration.md after assembly.

## Review

The scoped reviewer found result loss, an unprotected diagnostic and primary
error masking; all were addressed. This review does not establish device
acceptance or close Kundalini F-80 or App C historical reliability findings.
iOS remains experimental and untested. Test app repositories were read-only.
