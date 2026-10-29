# Integration validation - 2026-10-29

## Current packages refresh - 2026-10-29

No must-have item is todo, in progress or awaiting changes. Refreshed
`codex/integration` in both worktrees by fast-forwarding to packages code
`472bd2f13f71702cd4abb59ede590783ecd8104c` and site
`bb8d82fc509825f34d45cfd5ca06d72c7237030b`. Both worktrees were clean before
the refresh. All 23 feature tips are ancestors of packages in both repositories:
the original queue R8, R7, R6, R3, R4, R5, R9, R10, R14, followed by
R15, R16, R17, R19, R20, R21, R22, R23, R24, R25, R26, R27, R28 and R29.
No additional feature merge or conflict resolution was necessary. The earlier
R27/R28/R29 merge order and full source SHAs remain recorded below; the older
queue was already included in their packages base.

The initial refresh reached code `52946e5`; packages then advanced to `d4424de`
while gates ran. That commit changes only the Windows Python audit instructions
in AGENTS.md. Integration fast-forwarded again and repeated the earlier gates.
During closeout, packages advanced to code `472bd2f` / site `bb8d82f` with S3's
plugin-directory documentation. Integration fast-forwarded once more and reran
the complete gate set on those final heads. Earlier successful runs remain
separate evidence below, not substitutes for that final verification.

The refresh includes upstream tooling-age warnings, structured-return matching
for custom notification handlers, required push-envelope metadata, labels for
sync-owned database contention, restored Gradle wiring and plugin distribution
documentation. The new directory distinguishes plugins from add-ons, requires
fragment paths already on disk and makes no claim that a listing is a review.
Schema/builtins 16,
reserved delegation floors and package versions are unchanged.

Decision: retain those upstream fixes and preserve data, shipped custom handlers,
wire signatures, leases, retry budgets and activation checks. A tooling warning
must not reject an existing app-owned method merely because its namespace also
contains built-ins. Explicit push-envelope metadata preserves the data-only sync
boundary. No speculative runtime change is justified by the app stall reports.

Both apps' VALENCE_FINDINGS.md and newest reports (iteration 14) were read
read-only. Kundalini's report is now complete: its installed schema-11 host has
seven OS alarms armed through the package receiver, with inexact timing, but a
reminder firing was not observed. The schema-16 adoption passes app tests but
neither release nor debug APK completed, so its new signed OTA was deliberately
withheld. Its swallowed reminder-read error was an app defect and is reported
fixed there. App-a likewise has no fresh native build or valid boot baseline in
iteration 14; its last proven installed OTA and retained shelf remain iteration
13 evidence. Neither report establishes a cause for the historical lock/ANR
observations. F-62/F-36 still require matched-snapshot adoption; current framework
tests alone cannot close either app's findings.

All gates passed on the final implementation, separately from the older evidence
below. The confirmation after the packages movement passed without changing any
assertion, timeout or source file:

| Gate | Result |
| --- | --- |
| Root npm test | 99 passed, zero skips; generated Dart analyzed/exercised and strict/verbatim generated TypeScript included; 50.8 seconds reported by Node |
| Core flutter test --no-pub --concurrency=1 | 542 passed; 113.7 seconds command wall time |
| Core dart analyze --fatal-infos . | No issues |
| Push-adapter tests / fatal-info analysis | 2 passed / no issues |
| Example flutter test --no-pub | 27 passed |
| Core / adapter pub publish --dry-run | Both zero warnings; adapter retains one documented local-override hint |
| Bridge tests | 29 passed, zero skips |
| Bridge strict/verbatim TypeScript / pack dry run | Passed / passed |
| Site build and SEO | 43 pages passed, including the new plugin directory |
| Example codegen / signed built-in verification | No stale files / seq 1793209750 verified, 2 files |
| Example debug APK | Passed; 135.1 seconds command wall time, 129.6 seconds reported by Gradle |
| Core graph / APK Firebase audit | Explicit PASS: no Firebase dependency, manifest component or SDK reference in all 19 DEX files |
| Both repo diff checks | Passed |

The initial root run also passed 99 tests with zero skips (454.5 seconds reported
by Node), and the initial native run passed 542 core, 2 adapter and 27 example
tests with clean analyzers. The d4424de confirmation passed 99 root tests with
zero skips (133.6 seconds reported by Node), 542 core tests, 2 adapter tests,
27 example tests and both analyzers. The earlier 42-page site build and 436.3-second
APK build/audit also passed. Those are separate successful runs, not substitutes
for the final-head verification in the table. Its logs and per-command exit
codes/timings are `%TEMP%/valence-integration-20261029-latest-*.log` and
`valence-integration-20261029-latest-results.json`. Earlier evidence remains under
the separate `valence-integration-20261029-current-*` and `-final-*` prefixes.

Native commands ran sequentially. The APK used only command-local Gradle settings:
2 GiB heap, 1 GiB metaspace, two workers and ActiveProcessorCount=2; the daemon
command line confirmed those limits. The existing app_badge_plus KGP migration
warning remains. The audit ran through the real Python 3.13 interpreter located
by `uv python find 3.13`, avoiding Windows Store aliases, and its exit code and
explicit PASS output were captured directly. No cancellation or failed gate
occurred in this refresh. A host-memory sample during the first root run showed
183,984 KiB free of 32,827,764 KiB; this is context, not a proven cause of delay.

Security checklist: the upstream delta preserves canonical OTA verification,
nonce/strict decoding, navigation and subframe locks, atomic state writes and
account/outbox isolation. Required push-envelope metadata keeps notification
messages outside the data-only sync-hint path. Database diagnostics retain fixed
operation labels without SQL, arguments or app data, and preserve transactions,
errors and retry budgets. Release-only development exclusion is unchanged; its
earlier AOT evidence retains its original date and scope. No new independent
review or emulator session is claimed. iOS remains experimental and untested;
Firebase delivery and test-app release acceptance remain open.

Only this integration report is changed in each worktree. No test-app writes,
shared-branch commits/merges, version changes, pushes or publications occurred.

## Adoption follow-up - 2026-10-29

Both apps' findings and newest iteration reports were read without writing to
either app: initially Kundalini iteration 13 and app-a iteration 14, then the new
Kundalini iteration-14 report created during this run. Its day-14 finding F-62
records that the vendored CLI did not recognize `notify.pendingIds`, generated
an abstract app-owned handler at the correct
`since: 16`, and gave no tooling-refresh diagnostic. The app reports that
`create-valence update` restored delegation. This is separate from F-57's
below-reservation declaration and does not demonstrate failure of the current
integrated generator. App-a F-36 still records supplied snapshot tooling rejecting
the live docs' nullable `SyncStatus.reason` addition. Matched artifact adoption
remains necessary; neither finding is closed by framework tests.

Kundalini iteration 14 adopts the guarded ID-only read with the older full-read
fallback and records a Gradle-daemon disappearance followed by a smaller heap
configuration. At read time its device and verification sections contained placeholders;
no completed iteration-14 build or device matrix is inferred from that draft.

No must-have row is `todo`, `codex: in progress` or `codex: changes requested`.
The code/site packages bases remain `41fed55` / `7bfe7bd`; every original queue
tip and R27/R28/R29 tip is an ancestor of the corresponding integration head.
Decision: retain this candidate, preserve data and shipped signatures, and record
the new adoption evidence. Keep this run scoped to integration validation while
there is no eligible must-have item. No branch reassembly is needed while both
bases and all ready tips remain unchanged.
A blanket rejection of unknown names under a built-in namespace would also reject
valid shipped custom methods such as Kundalini's `notify.daily`; any future
diagnostic must preserve that compatibility distinction.

Fresh verification on code `81c452a` / site `b55d0bf`:

| Gate | Result |
| --- | --- |
| Root npm test | 97 passed, zero skipped; generated Dart and strict/verbatim generated TS included; 380.1 seconds reported by Node |
| Core flutter test --no-pub --concurrency=1 | 541 passed; 1331.7 seconds command wall time |
| Core dart analyze --fatal-infos . | No issues; 214.9 seconds |
| Adapter tests / fatal-info analysis | 2 passed / no issues |
| Core / adapter pub publish --dry-run | Both zero warnings; adapter retains the documented local-override hint |
| Example flutter test --no-pub | 27 passed |
| Bridge tests / strict-verbatim TS / pack dry run | 29 passed, zero skipped / passed / passed |
| Site build and SEO | 42 pages passed |
| Example codegen / signed built-in verification | No stale files / seq 1793209750 verified |
| Example debug APK | Passed; 1458.2 seconds command wall time (Gradle reported 1450.6 seconds) |
| Core graph / APK Firebase audit | Passed: no Firebase package, manifest component or SDK reference in all 19 DEX files |

Test suites, analyzers, packaging and site gates passed on their first attempts,
with unchanged assertions and timeouts. Native commands ran serially after root tests. Logs are
`%TEMP%/valence-integration-20261029-refresh-*.log`; native command exit codes and
wall times are in `valence-integration-20261029-refresh-results.json`.
APK timing and its successful exit are in `valence-integration-20261029-refresh-apk-result.json`.

The APK used a command-local 2 GiB Gradle heap, 1 GiB metaspace, two workers and
ActiveProcessorCount=2 with a single-use daemon; no shared Gradle configuration
changed. The existing app_badge_plus KGP warning remains. A planned bounded
cancellation found the verified client had already exited: the original build
completed successfully, no process was stopped, and no smaller-heap retry ran.
The first post-build audit launcher exited 9009 because `python` resolved to the
Windows Store alias. The unchanged audit then passed through the installed
Python 3.13 interpreter located by `uv python find`; no Python installation or
source patch was needed. A thread snapshot was captured near daemon shutdown;
it does not establish a cause for the long build.

The first host-memory sample during generated-Dart analysis showed 261,216 KiB
free of 32,827,764 KiB; this is context, not a demonstrated cause of delay.
No new emulator run or independent review is claimed. Earlier release-AOT/device
evidence below retains its original scope and date.

## In plain terms

Firebase is now an optional native dependency through `valence_push`; hosts using
core alone keep local notifications and badges without Firebase. R28 retains
complete notification content while giving reconciliation a bounded ID read.
R29 names startup phases and pending database operations without changing retries,
transactions, leases or activation. The combined bridge/builtins revision stays
16, including the reserved `notify.pendingIds` delegation floor. No package
version or manifest format changed.

Decision: keep the security policy and lifecycle in core, extract only the
Firebase transport, and preserve users' data and shipped wire signatures. Moving
local notifications and badges too would enlarge the migration without being
needed for R27. Push adopters add the optional package, import its factory and
replace `ValencePush()` with `createFirebasePush()` after Firebase initialization.
The core example intentionally omits Firebase, including Google services setup.
The guide now tells push hosts to add that native setup themselves.

## Bases and merge order

Started fresh from code packages `41fed55615cbece1595766ccb83a31e47c1a0be5` and
site packages `7bfe7bd0a26ef734396537f2279685c329e47ff4`. Both worktrees are on
`codex/integration`. Original queue R8, R7, R6, R3, R4, R5, R9, R10, R14 was
checked in that order: every tip is already an ancestor of packages in both
repos. All later rows except R27/R28/R29 are marked done; those three ready,
unmerged branches were folded in numeric order:

| Item | Code feature tip | Code merge | Site feature tip | Site merge |
| --- | --- | --- | --- | --- |
| R27 | `8296d4e68753185c132c39da3c94369989818f27` | `3c72a8eae96e6e4a34315e262021ab857fc8c0ad` | `c4a8fad9bc2dc04f9b8033080608e1250785e08e` | `68a17e6d26d554420d8d4835ffbac4a9b8f04b3b` |
| R28 | `8d42a82d96ad124c3cbe122280b64a00f43371bb` | `c471abc7132550dd8e38e22bc1730daa71dd452f` | `0cbadc71c2f2d40aa11b5aa6b21cf114ab8ece65` | `b3d2da02b2959194c414165c9ceb3cf2483927ab` |
| R29 | `6e250677b3bc6510f7ef2ea3e7c2ddb4ab1a509f` | `f59c202799da6a43ae94941f97ca7ca0dc40734c` | `d5a98a85ea9e9c41aa3c2cde461e0e92de1aa555` | `7a6d32122aac3354495f2b423222e2e7a72c878b` |

Code changelogs conflicted at R29; site README conflicted at R28. Both sides'
entries were retained. Runtime code merged without conflict. No invented runtime
behavior or schema renumbering was used to resolve the merges. The earlier
integration candidate passed 97 root tests before the final setup-sentence
correction; a fresh assembly includes that correction on R27 and reruns every
gate. Earlier integration is retained at
`codex/integration-before-r27-20261029`; the pre-correction assembly is at
`codex/integration-r27-before-doc-fix-20261029`.

## Gates on the final combined implementation

Validated implementation heads: code `f59c202799da6a43ae94941f97ca7ca0dc40734c`,
site `7a6d32122aac3354495f2b423222e2e7a72c878b`. Only this report is committed
subsequently; runtime, generated code, signed assets and site content stay as tested.

| Gate | Result |
| --- | --- |
| Root npm test | 97 passed, zero skipped; generated Dart analyzed/exercised and generated strict TS included |
| Core flutter test --no-pub --concurrency=1 | 541 passed |
| Core dart analyze --fatal-infos . | No issues |
| Firebase adapter flutter test --no-pub | 2 passed |
| Adapter dart analyze --fatal-infos . | No issues |
| Example flutter test --no-pub | 27 passed |
| Core flutter pub publish --dry-run | 0 warnings |
| Adapter flutter pub publish --dry-run | 0 warnings, 1 documented local dependency-override hint; override excluded from upload |
| Bridge tests | 29 passed, zero skipped |
| Bridge strict/verbatim TypeScript / pack dry run | Passed / passed |
| Site build and SEO | 42 pages passed |
| Example debug APK | Passed, 68.4 seconds command wall time |
| Core graph / APK Firebase audit | Passed: no Firebase dependency, manifest component or SDK class reference in all 19 DEX files |
| Example codegen / signed built-in | No stale files / seq 1793209750 verified |
| Both repo diff checks | Passed |

Flutter gates ran sequentially after the root suite. Only the APK command used a
2 GiB Gradle heap, two workers and ActiveProcessorCount=2, without global Gradle
configuration changes. Its existing app_badge_plus KGP migration warning remains.
Adapter publication uses the development override for unpublished core; publish
core first and repeat resolution against that release before publishing the adapter.

Logs: `%TEMP%/valence-integration-r27-*.log`; command exit codes and timings are in
`valence-integration-r27-results.json`. The earlier pre-documentation-correction
97-test root pass is retained separately in `valence-integration-r27-root-before-doc-fix.log`.

The distinct initial R27 root failure (duplicate version-test declaration), its
correction and complete passing rerun are recorded in [R27 validation](r27-validation.md).
The audit first rejected the inherited Firebase-containing APK, then passed both
rebuilt candidates. Earlier separate attempts for [R28](r28-validation.md) and
[R29](r29-validation.md) remain recorded there; none is counted as a current pass.
No assertion or timeout was weakened. All current gates passed on their first
attempt after the final assembly. Beta acceptance remains open.

## Review and acceptance limits

The package checklist covers nonce/strict decoding, message caps and JSON escaping,
HTTPS-only image metadata, exact data-only sync hints including empty-notification
denial, passive startup and permission/APNs-gated registration, tap races and
subscription disposal. Runtime sync tests preserve the native token, lease, UI
store and activation state. R29's fixed labels omit SQL, paths, tokens and app
data, preserve transaction executors/original errors, and cancel observation
timers. Canonical OTA verification order, navigation lock, atomic state and
account/outbox boundaries remain unchanged. Independent improver review is still
required before merging into packages.

Read-only inputs: both apps' VALENCE_FINDINGS.md and newest reports, Kundalini 13
and app-a 14. Kundalini completed report 13 during this run: it now records startup
recovery after keep.xml and a queue readback, with 114 web tests and 35 native tests
rerun at iteration-14 startup. F-58 still records Firebase in its supplied binary.
Reminder firing, OTA, rollback and fresh install are explicitly unverified in that
iteration. This newer evidence supersedes the placeholder limitation recorded in
the earlier R27 validation note; no full device matrix is inferred.

App-a's last native build remains cancelled without a completed APK, its F-36
snapshot/docs mismatch still needs matched snapshots, and F-33/F-35 causes and
adoption acceptance remain open. R27 removes the framework dependency cause; it
does not close F-34's local-notification/desugaring cost or prove either app has
adopted this candidate. No new emulator session, app-data reset or test-app write
occurred. Android build/unit evidence is separate from delivery/device acceptance;
iOS remains experimental and untested. Firebase delivery still needs a maintainer
project. No shared-branch commit/merge, push, publication or package-version bump.
