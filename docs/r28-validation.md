# R28 validation - 2026-10-29

## In plain terms

`notify.pendingIds()` reads native queued IDs without title, body or payload,
so reconciliation still works when a full-content reply exceeds the bridge cap.
The reply cap and `notify.pending` content remain unchanged. Reading does not
cancel or re-arm requests. Disabled hosts still deny the group, and an unavailable
native service returns an empty list.

Both apps' findings and newest reports were read without modifying them:
Kundalini iteration 13 and app-a iteration 14. Kundalini's reminder reconciliation
motivates this path, but its report retains device/verification placeholders.
App-a's snapshot/docs mismatch F-36, startup F-35 and lock warnings F-33 still
need matched-snapshot adoption and device evidence. These tests do not close them.

## Concurrent upstream implementation and decisions

Started on code `131f7ef45a39de17ff7ada2f706817e96de28152` and site
`61c06d1bacf9e900df7c90af7833622f5b8a131a`. While validation ran, packages
independently gained R28 at code `41fed55615cbece1595766ccb83a31e47c1a0be5`
and site `7bfe7bd0a26ef734396537f2279685c329e47ff4`. Those heads were merged
into `codex/r28` in both repos. The upstream signed example bundle, control and
new regressions were preserved; duplicated guide text was consolidated.

Decision: the new builtin has `minSince: 16`, matching its reserved capability
revision, rather than inheriting the older notification group's floor of 11.
This refuses a new matching declaration below the documented version before
an adopter mistakenly expects the native delegation. Existing recorded methods
and older app-owned different signatures retain the existing compatibility rules.
No package version changed. The schema and runtime capability revision are 16.

Reconciliation stops if an older host's full-content fallback returns
`E_TOO_LARGE`; it never treats that error as an empty queue. Each invocation reads
one native snapshot, with no promise that two separate calls observe identical
queues. User data and displayed notifications take priority over a refill.

## Validation

The original branch passed 96 root tests with zero skips (generated Dart included),
533 runtime tests serially, 27 example tests, fatal-info Dart analysis, 29 bridge
tests, strict/verbatim TypeScript, bridge pack dry run, zero-warning pub dry run,
41-page site/SEO build and a debug APK build in 225.8 seconds. An initial example
run exposed two stale revision-15 expectations; they were corrected to 16 before
the passing rerun. The new full-queue regression passed in that initial run too.

Post-merge gates passed on the heads above:

| Gate | Result |
| --- | --- |
| Root `npm test` | 97 passed, zero skipped; generated Dart analyzed and exercised |
| Runtime `flutter test --no-pub --concurrency=1` | 533 passed |
| `dart analyze --fatal-infos .` | No issues |
| Example `flutter test --no-pub` | 27 passed |
| Example `flutter build apk --debug --no-pub` | Passed, 2295.6 seconds |
| `flutter pub publish --dry-run` | 0 warnings |
| Bridge tests / strict-verbatim TS / pack dry run | 29 passed / passed / passed |
| Site build and SEO | 41 pages passed |
| Example codegen check / signed builtin verification | No stale files / seq 1793209750 verified |

The first post-merge root run passed 96/97 tests: the unchanged REST adapter's
601-operation push returned 502 instead of 200. The unchanged adapter-only retry
passed, followed by the complete 97-test passing rerun. Cause remains unestablished;
no assertion or timeout was changed. The earlier failure remains recorded rather
than counted as a pass. A cosmetic duplicate test setup deletion was removed.

The APK process used `GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx2048m
-Dorg.gradle.workers.max=2` and `JAVA_TOOL_OPTIONS=-XX:ActiveProcessorCount=2`.
Existing KGP migration warnings remain; no global environment or Gradle property
file was changed. Logs are retained in `%TEMP%/valence-r28-rebased-*.log`
(passing root: `root-retry`); initial logs use `valence-r28-*.log`.

## Security review and limitations

Independent review of both the original and reconciled diffs found no confirmed
behavioral defect. Focused schema testing passed, and example `codegen --check`
and both repo diff checks passed. The reviewer checked nonce/strict params,
shape freezing, schema reservation, disabled/unavailable behavior, reply cap,
native queue reads, generated marshalling and documentation agreement.

The real-runtime example regression covers 64 maximum-size reminders, ID
2147483647, a native queue change, no mutation on read, wrong nonce, extra params
and disabled-host denial. The original detailed call still returns `E_TOO_LARGE`.
OTA verification order, navigation lock, atomic state and database writes are
outside this read-only feature and unchanged by its diff.

No new emulator session or device-delivery claim. iOS remains experimental and
untested. No test-app or other builder's worktree writes, shared-branch commits
or merges, pushes or publications occurred.
