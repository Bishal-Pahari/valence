# S8 validation - 2026-11-02

## In plain terms

A page can now request an update check, and learn when a completed check refused
an offer because its store host is too old. bundle.check joins the same coalesced
UI check used by startup, resume, connectivity and the native blocking screen.
bundle.checked carries reason and nullable requiredBridge after status publication.
bundle.updateReady still means a verified bundle became pending. No pending
bundle is applied automatically.

Decision: security and users' data take priority over a convenient shortcut.
Calling the updater directly would bypass the native minHost teardown/withdrawal
transition; the RPC therefore requires an attached host callback. Missing custom
host support returns E_UNSUPPORTED. Completion is schema-opted and unbuffered,
so an absent/legacy event never receives a new payload and mount reads recover
current state without replaying stale checks. Modern payloads are frozen by
codegen. Both new names reserve minimum since 19; apps already past 19 declare
them above their own recorded store schema instead. No package version changed.
The shared allocation table's stale 17+ entry was left untouched; S8's Status
cell records schema 19, following R31 17 and S7 18.

Branches: codex/s8 in both repos. Bases: code 81e55b9, site 42bde41.
The other builder's S6 commits arrived during this work and were merged, keeping
the cookie-jar implementation, configuration, docs and tests. No conflicts.

Read both app findings and latest completed reports: Kundalini 18 / app-c 46.
F-74 motivates this change; app adoption and device acceptance are not claimed.
F-37's failed bounded sync assertion and same-PID recovery, F-40's external
Camera ANR and the historical renderer-loss failures remain unresolved.
The earlier integration ledger records independently checked saved receipts.

## Review and regression evidence

Independent read-only review found no confirmed defects before or after the S6
merge, including the final guides. Six schema probes and diff checks passed.
It traced the attached UI path, coalescing, policy teardown, status publication,
lease release and authenticated requiredBridge. Security paths retain the
canonical verification order, nonce/navigation lock, strict decoding, message
bounds, compiled grants, account isolation, atomic writes and release dev guard.

Regressions cover a signed incompatible offer emitting completion without
pending/updateReady, shared concurrent checks, invalid signatures withholding
requiredBridge, a signed mid-session block closing the loopback server without
trial strikes, absent/pre-19 declarations, malformed modern fields, unloaded
pages dropping completion, detached/custom hosts refusing explicit checks, and
debug dev mode preserving OTA state while skipping the explicit check.
Generated Dart and TypeScript compile against the real packages.

## Gates

Logs: %TEMP%/valence-s8-*.log. Final executable inputs include S6.

| Gate | Result |
| --- | --- |
| Root npm test | 112 passed, zero failures/skips; generated Dart and strict/verbatim TS ran |
| Core flutter test / fatal-info analysis | 599 passed / no issues |
| Debug dev-mode regression | 1 passed; explicit checks issue no OTA requests or state changes |
| Core pub dry run | 0 warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / no issues / 0 warnings, existing local-override hint |
| Bridge tests / strict-verbatim TS / pack dry run | 29 passed / passed / passed |
| Example tests / codegen --check | 29 passed / written: [] |
| Root pack dry run | Passed |
| Site build / SEO | 46 pages passed on the latest site base |
| Debug example APK | Passed, 71.4 seconds |
| Standalone Windows py Firebase audit | PASS: core graph, manifest and all 19 DEX files contain no Firebase SDK references |

The APK used a 2 GiB heap, two workers and ActiveProcessorCount=2; the existing
app_badge_plus Kotlin compatibility warning remains. The signed example UI was
not changed or re-signed; generated schema/adapters expose the new calls.

Initial root failures were three hardcoded template-schema expectations (18
became 19); focused fixes and the final suite validate those changes. A formatter
removed optional braces in existing test code; those unrelated edits were
restored and new branches fixed before the clean fatal-info run. An initial
focused flutter command used the repository root instead of packages/valence;
it did not run tests and is excluded. The first core suite ran before the last
documentation-only upstream merge; all executable/test inputs remained identical,
and the separately defined dev-mode test passed after that merge.

No emulator lock/device run was attempted. The task makes that check optional;
widget tests do not establish device acceptance. No test-app writes, protected
branch commits/merges, package version changes, push or publication. iOS remains
experimental and untested. Review and green gates do not close app reliability
findings or establish unconditional beta acceptance.
