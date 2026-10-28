# Integration validation - 2026-10-29

## In plain terms

This candidate combines compact native reminder-ID reads with startup phase timings
and named pending database operations. Notification content, reply caps, signed
bundle checks, transaction scopes, retries, leases and user data retain their
existing behavior. Diagnostics provide evidence for a recurrence; they do not
establish or fix the cause of app-a's earlier stalls.

Fresh packages bases: code `41fed55615cbece1595766ccb83a31e47c1a0be5`, site `7bfe7bd0a26ef734396537f2279685c329e47ff4`.
Integrated implementation: code `1f0d7a7c27246ab58750e617fcb3306058be7a05`, site `7b5c6b073bd7a63224958bb5678c9fed8c6a906d`.
Both worktrees use `codex/integration`. The previous integration refs were retained
as `codex/integration-before-r28-20261029` in each repo.

## Merge order and SHAs

The fixed queue was visited in the required order, then all later ready, unmerged
branches were folded lowest-number first. The original queue is already present in
packages. Earlier merged follow-ups remain in the base; no shared branch was changed.

| Order | Code tip | Site tip | Result |
| --- | --- | --- | --- |
| R8 | `91589a47cb80a4b2f2ba8cf1a6d1ce3dc5a4eb4e` | `072552f08d626d2915e63e7fda2c4c183c4380e3` | Already in packages; merge was a no-op |
| R7 | `969b1a4fb03d76d2af85c69987c4ed5eeb0eb840` | `965b8eb83a7412a9ec601919f227c2c0005a9252` | Already in packages; merge was a no-op |
| R6 | `5b64e06051fab10e0a01d8b3215c17f45d81c980` | `388cd9d3c0fd6043cfa21b0a6440916232847742` | Already in packages; merge was a no-op |
| R3 | `db669ddd75ffeb97588fd62304122a58c242f3b0` | `f45ccf28d741a2c6e05c766eeb6bff059900bcc5` | Already in packages; merge was a no-op |
| R4 | `588f8761807b1893933303533a04fa14c9975a6f` | `d8e5dd775dfaf902e206bc2f195c30537f797ba4` | Already in packages; merge was a no-op |
| R5 | `3cc1c0f4d062d13919adcfe5343434e00098fdea` | `57a44b50dfd82800f151823ff1563d8a73340678` | Already in packages; merge was a no-op |
| R9 | `0c1b0fb01a48494991cdae4ab32369fb6a2af7b2` | `2913b4d0a743188808a66bd5b7db416ca870c52f` | Already in packages; merge was a no-op |
| R10 | `f3fcd0dac875fc30af226c7f1bf70750942c0550` | `b905b742ab9d90984d513cdf7b99977eabd929f2` | Already in packages; merge was a no-op |
| R14 | `fa6e16c55d84bb9a3162514a9c09b65cb634fd54` | `fa5e8164a968bd74d943b8a50590dfbd010e08ca` | Already in packages; merge was a no-op |
| R28 | `8d42a82d96ad124c3cbe122280b64a00f43371bb` | `0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65` | Merged first among unmerged later branches |
| R29 | `6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f` | `d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555` | Merged after R28 |

Only the code changelogs conflicted when R29 followed R28; both adopter-facing
entries were retained. R28 had first merged the independently implemented upstream
R28, preserving its signed example, UI control and additional tests. Its reserved
`minSince: 16` floor remains in both CLI copies. Schema and runtime builtins
revision are 16; no package version changed. R29 adds no schema change.

Decision: preserve capability gating, users' data and complete notification fields.
An older host's oversized detailed queue read stops reconciliation; it is never
treated as an empty queue. Each call reads one native snapshot, with no promise
that two calls observe the same queue. Startup logging adds observations rather
than speculative changes to database or activation behavior.

## Gates on the combined implementation

| Gate | Result |
| --- | --- |
| Root `npm test` | 97 passed, zero skipped; generated Dart analyzed and exercised; generated strict TS included |
| Runtime `flutter test --no-pub --concurrency=1` | 542 passed |
| `dart analyze --fatal-infos .` | No issues |
| Example `flutter test --no-pub` | 27 passed |
| Example debug APK build | Passed; command wall time 51.6 seconds |
| `flutter pub publish --dry-run` | Package has 0 warnings |
| Bridge tests | 29 passed, zero skipped |
| Bridge strict/verbatim TypeScript | Passed |
| Bridge pack dry run | Passed |
| Site build and SEO | 42 pages passed |
| Example codegen check / signed builtin verification | No stale files / seq 1793209750 verified |
| Both repo diff checks | Passed |

Logs: `%TEMP%/valence-integration-*.log`; Flutter command exits and elapsed times
are retained in `valence-integration-flutter-results.json`. Remaining Flutter
gates ran sequentially after the root suite. The APK process alone used a 2 GiB
Gradle heap, two workers and `ActiveProcessorCount=2`; no global configuration
or Gradle property file was changed. Existing KGP migration warnings remain.

R28's earlier post-merge root attempt passed 96/97: the unchanged adapter's
601-operation push returned 502 instead of 200. The unchanged focused retry and
complete 97-test rerun then passed. No timeout or assertion was changed and no
cause was established. Those outcomes remain separately recorded in
`docs/r28-validation.md`; they are not counted as an integrated pass. R29's
historical initial widget failures and serial rerun remain in the code repo's
`docs/r29-validation.md`.

## Review and acceptance limits

Independent review of R28, its upstream reconciliation and the combined R28/R29
diff found no confirmed behavioral defect. It checked schema-16 delegation,
nonce and strict decoding, disabled/unavailable notification behavior, reply caps,
native queue changes, logger privacy, timer cleanup, transaction executors,
lease ownership, retries, auth/outbox clearing and original errors. Fixed labels
omit SQL, paths, tokens and app data. Example codegen and diff checks passed in
that review; expensive full gates above belong to this candidate's validation.

Read-only adoption inputs: both apps' `VALENCE_FINDINGS.md`, Kundalini iteration
13 and app-a iteration 14. Kundalini retains device/verification placeholders;
app-a's latest slot lacked a valid Android baseline and cancelled its native
build. Its snapshot/docs mismatch F-36 and F-33/F-35 still require matched
snapshots and device evidence. No finding is closed by inference from these gates.

No new emulator session or app-data reset occurred. Android automated build and
unit evidence is separate from adoption/device acceptance; iOS remains
experimental and untested. Firebase delivery still needs a maintainer project.
No test-app or other builder's worktree writes, shared-branch commits/merges,
pushes or publications occurred. Beta acceptance remains open.
