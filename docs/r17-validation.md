# R17 refresh - 2026-10-27

## In plain terms

R17 now includes current packages at code 6917e8d57f4d0873f4d78f134b4aea5bf006af5d
and site d93bf8cee45ed3131b52645f0b988a172fa6a2ad. Both worktrees use codex/r17.
The integration prerequisite is already merged. Merge commits: code 9d647e9,
site 899ed22 then 3a28fb4 (includes the plugin-installation documentation correction
that landed during validation). Code implementation tip after the refresh fixes: 4fe6988.

Preserved both changelog entries when merging; no runtime conflict needed a new
policy. Security first: retain write refusal/draining during account transitions,
identity-before-token adoption and the pending-write guard with an empty writable
set. The extended regression proves that a refused switch retains the previous
sync reason and a forced switch clears it even with no configured writable buckets.
R17 still persists outcomes atomically under the sync lease and reads urgency
from re-verified local signed metadata without activation.

Keep combined schema 15, all earlier reserved since values and the genuine
schema-1 store baseline. Package version numbers were not changed. Updated both
accessibility guides to identify the current template schema, and refreshed the
example CLI so it also carries upstream plugin-path containment. Source and
vendored CLI bytes now match.

Read both app findings and latest reports read-only: Kundalini iteration 12,
app-a iteration 10. K F-52/A F-32 still describe mismatched supplied snapshots;
the current prepack regression passes, but these app artifacts were not replaced.
Anonymous-401 success reporting (R26), reconnect update checks (R24), seed marker
locking (R25) and retention remain separate work. Durable reason describes the
last completed scope, not an authenticated backup receipt.

## Fresh gates

- Root npm test: 87 passed, zero failed/skipped. Generated Dart analysis/execution,
  strict/verbatim TypeScript and the stale-dist bridge packing regression ran.
- Runtime flutter test: 497 passed; dart analyze --fatal-infos .: no issues.
- Example flutter test: 25 passed.
- Bridge tests: 29 passed; strict TypeScript and npm pack --dry-run (with prepack
  rebuilding dist) passed.
- Generated example strict/verbatim TypeScript: passed.
- Source and vendored codegen --check: fresh, zero writes.
- Signed built-in verification: seq 1793064246, two files, passed.
- Define-enabled dev tests: 8 passed. The initial invocation used an emulator
  address for a desktop-bound fixture and failed its upstream request; rerunning
  with the documented http://127.0.0.1:55173 passed.
- Example debug and release APKs: built; embedded manifest and signature bytes
  match signed source in both. Release built with a dev sentinel define; exclusion
  passed across all three AOT libraries. Existing Kotlin compatibility warnings
  did not fail either build.
- Runtime flutter pub publish --dry-run: zero warnings on the committed tree.
  The earlier pre-commit attempt warned about two modified files; clean rerun passed.
- Site build: 38 pages; SEO, links and anchors passed after the final guide edit.

## Review checklist and limits

Reviewed the combined diff against contracts sections 2.2-2.4, 4.2-4.4 and 5.6:
nullable additions and legacy delegations; capability/parameter coherence;
nonce and strict decoding; signed urgency sequence/floor/bad guards; unchanged
activation/rollback; lease-held observation writes and account reset. No new
confirmed defect found in this refresh. This was a local checklist review;
Claude's improver still owns independent acceptance and merging.

No new emulator run. Firebase delivery still needs the maintainer project;
iOS remains experimental and untested. Neither test app nor another builder's
worktree was modified. No push, publication, version bump or shared-branch merge.
Only R17's Status cell is edited in the shared roadmap; this file carries the note.

---

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
