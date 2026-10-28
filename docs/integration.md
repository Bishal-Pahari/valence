# Integration validation - 2026-10-28

## October 28 afternoon confirmation

**In plain terms.** No eligible must-have item remains to implement. Rechecked
both apps' findings and newest iteration reports (Kundalini 12, app-a 13).
The packages bases are still ebb0793 / afe2366, and every pending branch tip
(R17, R19, R20, R21, R22, R23, R24, R25, R26) is included in both integration
histories. The merge order and source SHAs below remain unchanged.

Fresh required gates passed on code 99c990e / site 8f878d5: root npm test
92 passed with zero skips (generated Dart included), runtime flutter test
528 passed, fatal-info Dart analysis clean, bridge tests 29 passed with zero
skips, strict/verbatim TypeScript passed, and site build/SEO passed 41 pages.
The root command's initial captured output lacked a suite summary; its completed
log later confirmed all 92 tests in 500.9 seconds. A redundant confirmation
attempt was then stopped, including only its verified process descendants.
That cancelled duplicate is not counted as a passing run.

Decision: preserve the tested candidate and user data while improver acceptance
is pending. App-a F-33/F-35 remain unresolved; no blocked operation or ANR cause
has been established. Do not infer a runtime fix from successful later starts.
No behavior, spec, schema or version changed. This confirmation updates reports
only. No new emulator/review session ran; earlier APK, AOT and packaging results
retain their dates and scope. Firebase delivery needs the maintainer project;
iOS remains experimental and untested. No test-app writes, shared-branch
changes, pushes or publications.

## October 28 reconnect gate synchronization

**In plain terms.** Two full runtime runs on the unchanged candidate each
passed 526 tests and failed the same two reconnect widget checks. The focused
foreground check and all 16 widget-file tests passed unchanged. The tests used
a fixed 150 ms real-I/O wait before asserting that signed verification and
SQLite publication had completed; that wait did not establish completion.

The integration now waits up to five seconds for both the expected pending
sequence and the completed ready status in those two checks, retaining failure
diagnostics and all existing assertions. A first revision passed all 528 tests,
but confirmation then failed at an earlier background-sync request assertion
(527 passed). That setup had never established startup sync completion before
reconnect, which can legitimately collide with its lease. The final background
check observes startup sync.done first and then the reconnect request. It still
checks that no update request runs in the background and that resume stages it.
The foreground check also holds a manifest response behind a test-owned gate
and verifies that no pending bundle
is published before the response is released. Pointer counts, signed verification,
completed status, updateReady delivery and no-reload assertions remain checked.

Decision: synchronize these integration tests on the observable result instead
of changing the runtime or extending a blind sleep. Both original full-suite
failures remain recorded here; the passing isolated run alone was insufficient.
This change makes no startup-performance claim and does not close app-a F-33 or
F-35. No spec, schema, package version, runtime, generator or template behavior
changed. There is still no eligible must-have todo item. The newest packages
bases remain ebb0793 / afe2366, and all nine pending tips remain included.

Required gates in this run: root npm test 92 passed, zero skips, including
generated Dart; bridge tests 29 passed, zero skips, and strict/verbatim TypeScript
passed. The final synchronized runtime suite passed all 528 tests; site
production build and SEO checks passed all 41 pages. Fatal-info Dart analysis
found no issues. The final root confirmation also passed all 92 tests with zero
skips. The test-only implementation is commit 703dd80 on codex/integration;
the report commits follow the tested implementation.

Inputs read-only: both apps' VALENCE_FINDINGS.md and newest reports, Kundalini
iteration 12 and app-a iteration 13. Existing merge order and source SHAs below
remain applicable. No new emulator or independent review session ran. Earlier
APK, AOT-exclusion and packaging evidence retains its original scope and date.
Firebase delivery needs the maintainer project; iOS is experimental and untested.

## October 28 iteration-13 startup evidence

**In plain terms.** App-a's latest report adds an unresolved major startup
finding, F-35. Passing integration gates does not establish release acceptance.
The Android exit records confirm an input-focus ANR for PID 3231 (5008 ms),
then initialization/start timeouts for PIDs 6712 and 6744. The initial Flutter
trace was lost; no cause is established. Device load and build memory pressure
are context, not evidence that either caused these failures.

F-33 also recurred on inherited release 12: after OTA 1793173403 committed,
PID 5847 logged three ten-second SQLite lock warnings at 13:29:22. This
supersedes the previous reconciliation's statement that locks did not recur.
Neither the lock holder nor a relationship to the startup failures is known.
The retained guide screenshot does not prove the requested About navigation
finished rendering.

The corrected startup probe recorded three ready/page-finished successes and
one post-build success. Its observation totals include evidence capture and
are not startup latency measurements. These runs establish readiness signals;
they do not establish ANR absence or long-suspension/socket recovery. F-35
remains open. The bounded Gradle build succeeded, final OTA 1793173711
committed, and the app reports an offline restart retaining 15 plants, 36 shelf
records, identity and its prior receipt. These successes do not close F-33/F-35.

Inputs: both apps' VALENCE_FINDINGS.md; Kundalini iteration 12; app-a iteration
13 and its retained exit records, healthy-OTA log, startup result JSON and final
commit/offline logs, all read-only. App-a's prescribed archive hashes remain
unchanged from iteration 12. No integrated-runtime adoption or new anonymous-401
check is inferred from this report.

Decision: retain the existing integration and reserved schema numbers, keep
the startup finding visible for release acceptance, and preserve user data.
Do not introduce a speculative runtime fix, reset the app, or attribute the
failure to emulator load without a trace identifying the blocked operation.
There is no eligible must-have todo item. Both packages bases remain
ebb0793 / afe2366; all nine pending branch tips remain included in both
integration histories. No new emulator or independent review session ran.
Firebase delivery still needs the maintainer project; iOS remains experimental
and untested. Earlier APK, AOT-exclusion and packaging results retain their
original dates and scope.

Fresh required gates on this unchanged implementation: root npm test 92 passed,
zero skips (generated Dart included); runtime flutter test 528 passed; fatal-info
Dart analysis found no issues; bridge tests 29 passed, zero skips; strict/verbatim
TypeScript passed; site production build and SEO checks passed 41 pages. Both
worktrees pass diff --check. Only this report changed in either repository.

## October 28 app closeout reconciliation

**In plain terms.** App-a has now completed iteration 12 and its final report.
Both apps' findings and latest iteration-12 reports were read without changes.
The local packages bases remain ebb0793 (code) / afe2366 (site), and all nine
ready branch tips remain ancestors of both integration heads. There is no eligible
must-have todo item. Retain this candidate for improver acceptance; do not start
stretch work or change runtime behavior merely to create a new branch.

App-a still observes anonymous shelf HTTP 401 reported as ok in its supplied
snapshot. R26 already addresses that case in this candidate: an incomplete pull
returns and persists failed, while authenticated 401 remains unauthorized and
keeps the credential and queued writes. Its regression covers anonymous 401,
403 and 500 on both public and writable buckets. The app has not yet validated
this integrated runtime; its release-12 result is not evidence that R26 regressed.
R17's persisted reason and builtins fields likewise remain pending integration
acceptance, rather than features already verified by that app's snapshot.

The new app report corrects its apparent blank navigation capture: original PNG
pixels and crops contain the labels, and 13 settled captures pass its pixel
probe. Do not infer a native paint defect or introduce a speculative CSS fix.
The migration setup and status-persistence documentation gaps are reported closed;
mandatory native dependency costs remain. Earlier lock observations were not
reproduced, which does not establish their cause or a permanent fix. TalkBack
remains partial. Matched wizard/bridge composition is confirmed by app-a, while
Kundalini's older mismatched-pair report retains its original snapshot boundary.

Decision: prioritize the existing failure-reporting and user-data protections,
preserve schema 15 and all reserved since values, and carry the corrected app
evidence into the handoff. Read-only retention/tombstone storage and snapshot
revision identity remain separate concerns. No new emulator or independent
review session is claimed; Firebase delivery needs the maintainer project and
iOS remains experimental and untested. The earlier APK, release-exclusion and
packaging results below retain their original scope and were not rerun for this
report-only reconciliation.

Fresh required gates after reading the new report: root npm test 92 passed,
zero skipped (generated Dart included); runtime flutter test 528 passed;
dart analyze --fatal-infos . found no issues; bridge tests 29 passed, zero
skipped; strict/verbatim TypeScript passed; site build and SEO checks passed
41 pages. Both worktrees pass diff --check. Only this report changed.

## 2026-10-28 revalidation

**In plain terms.** The existing nine-branch candidate is still based on the newest
local packages heads: code ebb0793d576c74c6841686298c9ad828479f02b7 and site
afe2366c75670aa31811e0b2681fdc313f5d8751. No must-have item is todo or awaiting
implementation. All nine ready branch tips and both packages heads are ancestors
of the tested integration tips, code c14309d77affc145a0df1e51ae5fdc448fdc3ad4 and
site 3c3aefbd5a45f32cf11445b75184ba2a2d12cb31.
The merge order and source SHAs below remain applicable.

Decision: retain the already combined implementation rather than introduce
unrequested runtime or schema changes. Security and user-data checks take priority
over stretch work while improver acceptance is pending. Package versions and
reserved schema numbers are unchanged. Both apps' findings and newest reports
(Kundalini iteration 12, app-a iteration 11) were reread without modifying them.

All gates were rerun on 2026-10-28:

| Gate | Result |
|---|---|
| Root npm test | 92 passed, zero skipped; compiled generated Dart and strict TS included |
| Runtime flutter test | 528 passed |
| Runtime fatal-info Dart analysis | No issues |
| Example flutter test | 26 passed |
| Define-enabled dev proxy / diagnostic widget | 10 passed / 1 passed |
| Bridge tests / strict-verbatim TypeScript | 29 passed, zero skipped / passed |
| Bridge npm pack dry run | Passed |
| Example generated client / dev-web TypeScript | Passed |
| Source and vendored codegen --check / CLI equality | Fresh / identical |
| Signed built-in and source/CAS hashes and sizes | Verified, seq 1793115254, two files |
| Runtime pub publish dry run | Zero warnings |
| Site production build and SEO checks | 41 pages passed |
| Fresh debug and release APK builds | Passed; signed manifest and signature bytes match source in both |
| Release AOT exclusion | Sentinel URL, proxy/diagnostic strings excluded from all three ABI libraries |
| Release plugin/probe inspection | Registration validation retained; R23 synthetic token and probe markers excluded in all three libraries |

The release build supplied
--dart-define=VALENCE_DEV_URL=http://valence-dev-release-sentinel.invalid:5173;
the repository checker inspected that exact URL. Android builds still emit the
existing plugin Kotlin migration notices. These are not pub dry-run warnings.
The checks above precede documentation-only commits in both worktrees.
No new independent review or emulator session was run: previous review and device
evidence below retain their original dates and limits. Firebase delivery needs
the maintainer project; iOS remains experimental and untested. Snapshot pairing,
read-only retention/tombstone storage, migration desugaring discoverability and
unisolated app lock/paint observations are not closed by these integration gates.
No writes to test apps or other worktrees, shared-branch commits or merges,
version changes, pushes or publications occurred.

## 2026-10-27 integration record

## In plain terms

Nine pending branches run together on `codex/integration` in both repositories.
R19 adds native plugin registration checks to the earlier eight-branch candidate:
a missing plugin or exact method fails at handler construction in every build mode.
Persisted sync failures, reconnect checks, seed recovery, plugin error mapping,
loopback HTTP defaults, development diagnostics and LAN trust remain intact.
This is an integration candidate for improver acceptance.

Code base: `ebb0793d576c74c6841686298c9ad828479f02b7`.
Site base: `afe2366c75670aa31811e0b2681fdc313f5d8751`.
Tested implementation: code `992a2e6`, site `7b559e6`; later report commits are documentation only.
The earlier R8/R7/R6/R3/R4/R5/R9/R10/R14 integration is already in both bases.
Package versions are unchanged. Template/example schema stays 15: appearance since
7, restoration 8, links 9, permissions 10, reminders 11, push 12, account support
13 and image sharing 14. R19 adds no wire surface. The schema-1 store baseline remains intact.

## Merge order and source commits

| Order | Branch | Code source | Code merge | Site source | Site merge |
|---|---|---|---|---|---|
| 1 | codex/r17 | a992285 | 12a349e | 971e5a9 | b2485c0 |
| 2 | codex/r19 | a49246a | 93ec043 | 0ca0392 | 87a2104 |
| 3 | codex/r20 | f8f3f1f | 59b1fae | 98cbad0 | 8e7a380 |
| 4 | codex/r21 | 92221ea | f48484b | d3d0e2b | e552c84 |
| 5 | codex/r22 | b2e5a40 | b559e7b | e84efa7 | 1f8f866 |
| 6 | codex/r23 | 373d29f | 7d327c3 | 0bcc440 | adc3412 |
| 7 | codex/r24 | 23a2783 | 52fc7ce | fcb04f2 | 0287745 |
| 8 | codex/r25 | 52fd6e5 | b5ec252 | 9f614ee | fbd4d4e |
| 9 | codex/r26 | 7c43658 | d927cda | 1437672 | b1698b9 |

R19 documentation follow-ups were carried from its own branches after the ordered
implementation merges: code `ebbd5e0` via `992a2e6`, site `7c31ed4` via `7b559e6`.
These add installation-workflow and machine-documentation instructions only;
the integration trees were byte-identical before and after those carry merges.
Combined sync/spec corrections are in `1bca9b1`; workflow/machine refinements
first landed as `a5117e0` / `0302bb8` before being copied to the R19 branches.

The previous candidate `c0d8aa8` / `31046b0` is retained in both repositories on
`codex/integration-before-r19`, including its earlier merge ledger and gate history.

## Decisions and conflict resolution

Security first, then user data: R19 generates required namespaces and exact method
names. A namespace check alone would accept an installed plugin version missing
a declared method. Event-only fragments must still register their owner. The
checked runtime factory throws an ordinary StateError, not a stripped assertion.
Older generated code and direct registry callers retain their original constructor;
extra native methods remain unreachable through generated dispatch.

Preserve nonce and strict parameter checks before invocation, R22 malformed-return
E_INTERNAL mapping and deliberate plugin errors. The compiled regression now expects
R19 startup refusal while retaining R22 malformed-value and deliberate E_DENIED/
E_PARAMS checks. Doctor lists requirements as WARN: source inspection cannot prove
which native instances an app constructs. Test construction of real app handlers.
Native initialization, permissions and successful platform behavior remain separate.

R17 and R26 share one lease-held failure classification and atomic observation
write. Authenticated rejection outranks transport failure, then incomplete server
responses, then success. Persisted and returned outcomes agree, including anonymous
401, and failed/scoped runs preserve prior success timestamps. Keep their previously
combined source and regressions rather than choosing either conflict side. Account
clearing, outbox contents and cursors retain their existing protections.

Preserve all docs/changelog sections, R18 app-owned plugin stamps and own-property/
integer checks, R20 diagnostics, R21 LAN trust and R24 widget regressions. Regenerate
from the combined source CLI and copy it byte-for-byte into the example. Resolve
generated conflicts from source rather than hand-editing output. The previous
combined signed example is retained only after matching every source file's hash,
size and CAS bytes: seq 1793115254, floor 0, two files. Embedded debug/release
manifest and signature bytes also match source. HTTP remains loopback-only. Clean
the test-matrix table separator and retain the complete R17 regression row.

## Gates

| Gate | Result |
|---|---|
| Root npm test | 92 passed, zero failed/skipped; generated Dart and strict TS ran; final workflow-doc rerun also passed |
| Runtime flutter test | 528 passed, no rerun needed |
| Runtime dart analyze --fatal-infos . | No issues |
| Example flutter test | 26 passed |
| Define-enabled development proxy tests | 10 passed |
| Define-enabled development widget regression | 1 passed |
| Bridge tests | 29 passed, zero skips |
| Bridge strict/verbatim TypeScript and pack dry run | Passed |
| Generated example and dev-web strict/verbatim TypeScript | Passed |
| Source/vendored codegen --check and CLI equality | Fresh, zero writes; identical CLIs |
| Signed source, CAS and built-in verification | Passed; seq 1793115254, two files |
| Runtime pub publish dry run | Zero warnings |
| Site build and SEO/link checks | Final machine-doc build: 41 pages passed |
| Debug/release APKs | Both built; embedded signed manifest/signature match source |
| Release AOT inspection | Dev URL/proxy and all five diagnostics excluded from all 3 libraries; plugin registration diagnostic retained; actual R23 synthetic token/response sentinels absent |
| Both worktrees diff --check | Clean |

The direct-file TypeScript invocation initially needed the current compiler's
`--ignoreConfig` flag; rerunning with that flag passed. No error was suppressed.
Android builds emitted existing plugin Kotlin migration notices. No dependency
versions changed to hide them. No test skip or device pass is inferred from a build.

## Review checklist and evidence limits

Independent review found no confirmed defects in R19, the integration or site docs.
It separately passed 8 focused plugin/compiled-Dart tests, 1 generated client test,
5 native-plugin tests, 16 incomplete-sync regressions, 1 persisted-reason regression,
codegen freshness and fatal-info Dart analysis. It reviewed standalone R19 source;
executable checks ran on integration.

The canonical verification order, manifest/download/message caps, nonce/navigation
locks, reserved owners, atomic state, key handling and account protections remain
in their existing implementations. The final diff against the previous integration
contains R19 and documentation refinements; the previous eight branches' runtime
behavior and combined failure regressions are unchanged. Native setup and successful
platform behavior are outside the declaration check.

Inputs read-only: both apps' VALENCE_FINDINGS.md, Kundalini iteration 12 and app-a
iteration 11. App-a's matched snapshots resolve F-32; Kundalini's F-52 describes
an earlier mismatched pair. Snapshot replacement, retention/tombstone storage and
migration desugaring friction remain outside R19. No supplied snapshot was modified.

No new emulator session. Earlier Android evidence is historical; the integrated
device acceptance matrix remains separate. Firebase delivery needs the maintainer
project. iOS is experimental and untested. No test-app/other-worktree writes,
shared-branch commits/merges, pushes, publications or deployments occurred.
