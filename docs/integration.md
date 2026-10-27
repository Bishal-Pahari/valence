# Integration validation - 2026-10-27

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
