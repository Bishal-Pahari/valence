# R32 validation ? 2026-11-02

## Decision

Raise only the compiled response grant. `http.maxBodyBytes` is an optional integer
1..262144 (default 65536), emitted as `ValenceConfig.httpMaxBodyBytes`. Requests stay
65536 bytes, headers stay 16 KiB and the final escaped bridge envelope stays 262144
bytes. This preserves the bridge trust boundary and existing request behavior. Native
constructor validation also refuses invalid manually constructed grants. No schema,
reserved since value or package version changes.

The running response cap measures decompressed UTF-8 bytes, including gzip. A compressed
Content-Length cannot refuse a representation by pretending it is the decompressed size.
JSON escaping, headers and reply overhead can still make an in-grant body undeliverable;
that produces bounded E_TOO_LARGE, never truncation or a larger Binder message. Origin,
credential, redirect, deadline and cookie paths remain intact. Security review found no
confirmed actionable defect after checking config/codegen/doctor/runtime and generated
strict params, request preservation, gzip and escaped envelope tests.

Read both test apps' findings and newest completed reports at intake: Kundalini 18 and
app-c 64. Kundalini's large rashifal response supports this need; app-c's current busy
sync expectation failed before later recovery, without proving its original COMMIT
exception or a lock owner. Historical renderer/startup/worker findings remain qualified.
Both app repositories were read-only.

## Feature gates

| Gate | Result |
|---|---|
| npm test | 114 pass, zero failures/skips, generated Dart and TS compile checks executed |
| Core flutter test --concurrency=1 | 606 pass |
| Core dart analyze --fatal-infos . | No issues |
| Core publish dry run | 0 warnings |
| Push tests / analysis / publish dry run | 2 pass / no issues / 0 warnings, 1 existing override hint |
| Bridge tests / strict verbatim TS / pack dry run | 36 pass / pass / pass |
| Example flutter test | 29 pass |
| Example debug APK / standalone Windows py Firebase audit | pass / PASS over core graph, manifest and all 19 DEX files |
| Root pack dry run | pass |
| Site build and SEO | 48 pages pass |
| Example codegen --check | pass |

Initial root run failed only the example CLI byte mirror; copied the source CLI exactly
and the complete rerun passed. Initial analysis found a local closure style and a relative
lib import in the new probe; both corrected, clean fatal-info rerun passed. The initial
focused-test compile omitted the internal replyOk import; corrected before the passing
17-test focused run. A first format command used repository paths from the package cwd;
correct root invocation formatted the intended files. These attempts are not counted as passes.

## Android example probe

Took codex-builder emulator lock, ensured emulator-5554, built the dedicated example
entry point `tool/http_response_probe.dart`, installed the example debug package and
launched its namespaced MainActivity. Inspected [screenshot](evidence/r32/probe.png)
and [logcat](evidence/r32/probe-logcat.txt):

- Default grant refuses a gzip response expanding to 133712 bytes.
- Generated example grant 196608 returns all 133712 bytes and the successful reply fits.
- A 65536-byte control-character response becomes bounded E_TOO_LARGE after escaping.
- A 133712-byte POST request is still refused by the unchanged request cap.

A first launch named the package instead of the namespaced activity and failed before
execution; corrected launch produced all four PASS lines. Stopped only the example app
and released the lock. Probe uses synthetic loopback data and opens no user database or
credential store. This is a native HTTP/envelope probe, not a full WebView end-to-end or
release-build acceptance test. iOS remains experimental and untested.

Raw full-gate logs are retained locally in `%TEMP%/valence-r32/`; durable probe receipts
are linked above. Protected branches, test apps and package versions were not changed;
no push, publication or deployment was performed.
