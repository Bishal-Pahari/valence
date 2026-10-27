# R17 validation - 2026-10-27

## In plain terms

Pages can distinguish Valence's capability revision from the app's schema number,
reconstruct the last sync outcome after navigation, and read whether a pending
update was signed as urgent. All three returned fields are nullable; old hosts and
schemas keep working. Declaring builtins also makes codegen check that declared
built-in methods include their current optional params, preventing a misleading
capability claim over an older strict dispatcher.

Both worktrees use `codex/r17`. Created from `packages`, then fast-forwarded to
the integration prerequisite: code e444a94032800846418a19a47c765b5ef3d47610,
site cf73f2825e848369ff72fa92ad582018bd2376fd. Implementation commits:
code 13d650a2949c0bd743c58c2c9d671dd109f9448f and
site cf9242fec0ada3ed049a8fd7ce25fd1e8b567460.
Merge integration first; R17 must follow reserved schemas 7-14. Template/example
schema is 15 and all earlier since numbers remain unchanged. Package versions
and the genuine schema-1 example store baseline were not changed.

## Decisions

Security: urgency comes only from a re-verified signed local pending manifest,
with floor, bad, sequence and concurrent pending checks. It never downloads,
activates or relaxes ready/rollback. The original synchronous Dart bundleStatus
API stays; only schemas declaring urgent use the additive async snapshot API.

Data: persist reason, offline and any new full-sync timestamp atomically before
releasing the lease. Busy/skipped runs and exceptions preserve the previous
observation; completed scoped runs replace reason without advancing the global
timestamp. Account changes clear reason in the existing clear transaction.
Unknown stored reason strings remain readable. No-server runs preserve history.

Developer experience: old schemas omit new delegations. Reporting builtins opts
into current optional params for declared methods; methods may still be omitted
or disabled. Review reproduced a false-positive gate when builtins was declared
without after. The new codegen rule and regression reject that configuration,
including renamed app.info return types. Older hosts can still use sibling gates.

## Gates

| Gate | Result |
|---|---|
| Root npm test | 86 passed, zero failed/skipped; generated Dart and strict TypeScript exercised |
| Runtime flutter test | 492 passed |
| Runtime dart analyze --fatal-infos . | No issues, including example/plugin |
| Example flutter test | 25 passed |
| Bridge tests | 29 passed |
| Bridge strict/verbatim TypeScript, build and pack dry run | Passed |
| Generated example strict/verbatim TypeScript | Passed |
| Source and vendored codegen --check | Fresh |
| Signed example verification | Passed, seq 1793064246, two files |
| Example debug APK | Built; embedded manifest matches signed source |
| Runtime pub publish dry run | Zero warnings |
| Site build and SEO/link checks | 38 pages passed |

Focused runtime regressions cover revision independence, account clearing,
unauthorized/scoped recovery, busy/error preservation, unknown reason strings,
signed true/false urgency, invalid signatures, floor/bad refusal, wrong signed
sequence and unchanged activation state. Generated dispatch covers all three
fields; codegen covers nullable additions against a recorded schema-14 baseline
and preserves older delegations. Final read-only security review has no remaining
confirmed defects; its independent additive/coherence checks passed.

Initial gate failures were outdated test expectations and reporting fixtures that
removed grown params without dropping builtins. Corrected them and reran the full
root suite successfully. Formatting-only churn was removed before final runtime
tests and analysis. Android emitted the existing Kotlin-plugin compatibility
warnings; these did not fail the build. No dependency upgrades were made.

## Limits

No new emulator run or R17 release APK. Integration's three-ABI release exclusion
evidence remains in docs/integration.md; R17 does not change those compile-time
guards. Both full app findings and newest reports were considered read-only
(Kundalini iteration 11, app-a iteration 10). This does not replace their harness
snapshots or close app-a's reported snapshot mismatch. Firebase delivery still
needs the maintainer's project. iOS remains experimental and untested.
No pushes, publications, shared-branch merges or test-app writes.
