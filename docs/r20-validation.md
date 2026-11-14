# R20 development diagnostics - 2026-10-27

## In plain terms

Development startup now names its upstream origin and disabled OTA behavior. Each
ready, signed reload, update check and apply bypass logs the operation it skipped.
A developer can distinguish a successful bridge reply from a real trial commit.
Restart without VALENCE_DEV_URL to validate signed offline starts and rollback.

Branch: codex/r20 in both worktrees. Code base:
ebb0793d576c74c6841686298c9ad828479f02b7; site base:
afe2366c75670aa31811e0b2681fdc313f5d8751. Implementation: code 2be80e8,
site 98cbad0.

## Decision and review

Security first: log only the validated origin, loopback origin, signed schema
context sequence and operation names. Do not include nonce, tokens or request
payloads. Keep compile-time debug guards and every bypass in place. Do not change
the resolved bridge result or mutate OTA evidence to make development look like
signed operation. Ordinary sync continues to use the same data protections.

The runtime owns these diagnostics; no generator or bridge-client behavior needs
to change. The installed guidance template and skill explain how to read them.
Schema numbers, since values and package versions are unchanged. The development
guide already required returning to signed mode for rollback; this change makes
the current runtime mode visible rather than introducing a new validation mode.

Independent security review found no confirmed defect against contracts 3.1 and
2.3-2.4. It checked origin validation, secret leakage, compile-time exclusion and
preserved state behavior; it also ran focused dev CLI tests and example codegen.

## Validation

| Gate | Result |
|---|---|
| Root npm test | 88 passed, zero failed/skipped; generated Dart and TS gates ran |
| Runtime flutter test | 495 passed |
| Runtime dart analyze --fatal-infos . | No issues |
| Example flutter test | 24 passed |
| Define-enabled dev proxy tests | 8 passed |
| Define-enabled dev host-widget regression | 1 passed |
| Bridge tests | 29 passed, zero skipped |
| Bridge strict/verbatim TypeScript and pack dry run | Passed |
| Example dev-web strict/verbatim TypeScript | Passed using bridge's installed compiler |
| Source and vendored codegen --check | Fresh; no writes |
| Built-in signature and file verification | Passed; seq 1793062826, two files |
| Runtime pub publish dry run | Zero warnings |
| Site build and SEO/link checks | 37 pages passed |
| Example debug APK | Built |
| Release APK with dev sentinel; AOT exclusion | Built; upstream, proxy and all five new diagnostic markers absent from all 3 AOT libraries |

The new dev-widget test preserves in-memory and on-disk activation evidence across
startup, page-start, ready, apply, signed reload, background/resume and a periodic
check. It verifies all bypass diagnostics, continued sync and no OTA network
request, no extra WebView load and no nonce in logs. The normal suite also checks
the signed startup log has no dev warning. The first focused run exposed a test
clock mismatch; using a bounded real wait exercises the host's real periodic timer.

One auxiliary npx compiler lookup from the example failed to locate tsc; the exact
same strict/verbatim check passed with the compiler installed in packages/bridge.
No dependency change or suppressed compiler error was used.

Inputs: both test apps' VALENCE_FINDINGS.md, Kundalini iteration 12 and app-a
iteration 11, read-only. Snapshot pairing, retention/tombstone storage and Android
desugaring friction remain separate findings. No new emulator check is claimed.
Firebase delivery still requires a maintainer project; iOS remains experimental
and untested. No push, publication or shared-branch mutation.
