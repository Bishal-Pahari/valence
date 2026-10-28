# Integration validation - 2026-10-29

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
