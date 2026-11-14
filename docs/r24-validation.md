# R24 validation — 2026-10-27

R24 retries signed update discovery on foreground live-interface reports, including Wi-Fi/cellular
handovers. It uses the existing updater instead of adding a page-triggered API. Implementation:
`e882410`; adoption/spec documentation: `e31ddd8`; site: `fcb04f2`, all on `codex/r24`.
Bases: code `ebb0793d576c74c6841686298c9ad828479f02b7`, site
`afe2366c75670aa31811e0b2681fdc313f5d8751`. The earlier queue and integration are already marked done.

## Decisions and review

- Security: call the existing signed, coalesced updater. No changes to verification order, the nonce,
  navigation, development-mode guard, atomic state writes, trial activation or commit. Discovery emits
  pending readiness without reloading the running page.
- Data: keep the bounded step-7 sync lease and missing-pair pull path. Background reports retain the
  existing sync behavior but leave update discovery to resume. A busy check can wait five seconds and
  stop; reconnect is an attempt, not a guarantee of immediate recovery or a new retry scheduler.
- Developer experience: no bridge/API/schema/package-version change. Existing generated hosts and
  templates inherit this through `ValenceApp`. Neither CLI copy needs a change.
- Status wording: `offline` describes the completed check at `checkedAt` until another check completes.
  A live interface does not prove reachability. An immediate page read can race the asynchronous check;
  `bundle.updateReady` is still the signal for a newly pending bundle.
- The review found no confirmed security/correctness defect. Its home-FAQ documentation gap was fixed.
  Both complete app findings ledgers and newest reports were read without edits: Kundalini iteration 12
  and app-a iteration 10. Older missing-pair, shared-database, startup, rollback and identity constraints
  still use the established updater/sync paths. Snapshot replacement remains outside this item.

## Gates

| Check | Result |
|---|---|
| `npm test` | 88 passed, zero skips; generated Dart and TypeScript checks ran |
| Package `flutter test --no-pub --reporter expanded` | 498 passed |
| `dart analyze --fatal-infos .` | No issues |
| Bridge `node --test test/*.test.ts` | 29 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Bridge `npm pack --dry-run` | Passed; prepack rebuilt dist |
| Site `npm run build` | 38 pages; SEO checks passed, including updated home FAQ |
| Example `flutter test --no-pub --reporter expanded` | 24 passed |
| Source CLI and example vendored CLI `codegen --check` | Both returned `written: []` |
| Signed built-in verification | seq 1793062826, two files, passed |
| `flutter pub publish --dry-run` | Zero warnings after committing package files |
| Example `flutter build apk --debug --no-pub` | Passed; existing Kotlin migration notice remains |
| Embedded debug-APK manifest versus verified source | SHA-256 matched |
| Both worktrees `git diff --check` | Passed |

The reconnect regression was also run against the unchanged base host: it failed at the pointer-request
assertion, expected 2 and got 1. The restored implementation passed all four new widget cases in the
full package run. They exercise offline-to-verified-pending recovery without reload, none/mixed reports,
live handovers and concurrent coalescing, background sync with update deferral to resume, and invalid
signature rejection. Existing disposal coverage checks that reports cannot start work after unmount.

An initial dry run warned about the uncommitted package files; the final clean-tree dry run above
supersedes it. An initial regression command had a Windows quoting error and did not execute a test;
the corrected run produced the assertion failure above. Neither failed invocation is counted as a gate.

## Android evidence and its limits

The shared emulator lock was acquired before use and released afterward. Only the example package
`com.getvalence.valence_example` was installed and controlled; no test app files were changed.

The example served its existing signed built-in on port 13882. The emulator displayed a recurring
"isn't responding" dialog, making the runtime lifecycle inactive. After choosing Wait, a Wi-Fi report
at 10:18:42.318 was followed at 10:18:42.320 by
`update: connectivity came back in the foreground`. The check completed with a five-second pointer
timeout at 10:18:46.787. Earlier inactive connectivity reports triggered sync without the new update
trigger. See [selected host log](evidence/r24-android.log).

This proves device wiring of the foreground trigger, not a clean end-to-end update or stable startup.
The checked-in OTA URL is deliberately `.invalid`; no successful device download/pending transition is
claimed. The ANR cause is unisolated and no claim is made that R24 caused or fixes it. Verified-pending
success, no reload, coalescing and rejection are deterministic widget evidence. No new release APK was
built, and reconnect-under-dev-define behavior relies on the unchanged early dev guard and existing
guard tests. iOS remains experimental and untested.

Airplane mode was restored to off, Wi-Fi enabled, the example force-stopped and the emulator lock
released. No push, publication, version bump or merge into a shared branch occurred.
