# Observer and bridge evidence - 2026-11-09

In plain terms: a later successful bridge read does not prove an earlier request
was healthy. The spec and both debugging guides now distinguish promise
settlement, host reply production, reply delivery and external observation.
Use a known non-mutating read as a separate probe; never automatically replay
writes, native actions or network requests after an observer timeout.

Decision: security first, then users' data. A request may already have taken
effect before its observer fails. Correct the diagnostic advice rather than
adding retries, changing deadlines, clearing data or asserting a runtime cause.
The package currently has no per-call transport timeout. There is no executable,
dependency, schema, version, codegen or template change.

## Source evidence

- packages/bridge/src/index.ts: traced() records resolved and rejected promises;
  rawCall() can refuse before native dispatch or run a web shim. Without a
  listener there is no trace. connect() and ready() call rawCall() directly.
- packages/bridge/test/bridge.test.ts already exercises shim tracing,
  E_UNSUPPORTED, safe metadata, listener failures and unsubscribe.
- packages/valence/lib/src/app.dart: _onBridgeMessage awaits dispatch, calls
  _logBridgeError, then attempts runJavaScript. A host error line therefore
  precedes delivery and cannot establish that delivery succeeded.
- Trace metadata identifies a method, not a request id. Overlapping calls need
  app-owned correlation; missing captured output is inconclusive.
- A painted page, live process and absent ANR do not distinguish a failed
  request, lost reply or observer failure. Preserve failures and later
  recoveries as separate records.

No new tests mirror these prose changes. Existing bridge tests and all combined
integration gates verify the underlying behavior. No transport retry or timeout
was introduced.

## Current app evidence

Read both VALENCE_FINDINGS.md inventories and newest reports: Kundalini 24 and
App C 162. All must-haves and original queue items are done; S1 remains parked,
S2 requires Play, and S10/P1 remain deferred.

Kundalini reports a rebuilt-host reproduction of the sibling-isolate contention
window: a background holder for 102.9 seconds, three foreground refusals, no
takeover or negative age. Its report closes F-83, F-58 and F-84 and records a
fresh offline seed install, reconnect and signed two-strike rollback. These are
app-reported results; no fresh device run or independent raw lease trace review
was performed here. Its new F-85 logging lag is already corrected in packages
08f072e, after that app snapshot; the new log wording has package-test coverage,
not a post-fix device check in that report. F-30's background freshness limit and
unconfirmable physical haptics remain qualified.

App C's initial release UI observer failed before its screenshot step; later
painted list/detail/photo observations remain separate. R29 records release
PID4727/open5705ms with no paired named wait. This does not measure web paint,
exclude locks or establish a cause. Historical process-loss and observer findings
remain open. The cold-widget receipt now records same-document/PID list reveal.
Inspected the canonical fresh-offline screenshot: six seed units, zero photos,
no installed widget; its 31425ms observation window is not exact paint latency.

Independently resolved all 45 local App C report links; rehashed both archived
APKs and all five embedded file hashes/sizes each, builtin1794165390:
release 667e27e51d1d452e999c10675725ec0eff279f0011b1da6d2c9f6c9fa3b58cd0;
debug 3889c9e11874ff9a0af959d4b171902b4c93a9c9091f0fa2c456e366e849e4f8.
Saved artifact audit has 106 passing scoped checks. Independently counted
doctor17PASS/10WARN/zeroFAIL. These are saved receipts, not fresh app builds.

Matched four saved PID9308 lease lines against raw worker logcat. The execution
receipt records observed=true/forced=true and an 806.112s observation window:
one explicitly triggered eligible registered execution, not natural cadence or
execution duration. Stable native SQLite receipts record both outgoing objects
matching writes, outbox0 and inbound present before foreground resume.
Independently compared activation files byte for byte: pending1794166220/no trial,
SHA256 8162a593ac0b5efe62c2caf755d57e2a0be02377b75d4a0d7a81d03ca5c2ffb1.
Final native receipts retain the original inspection with outbox0/current fixtures0.

F-27 remains open: saved host publications985884KiB/10155files versus224KiB
source media, with removed fixture publications still answering200. No retention,
leak-rate or startup-cause inference. App C's F-55 capture still shows the old
migration wording; packages already retains the correction explicitly marking
the dbus conflict historical. No additional dependency patch is needed.
Test-app repos stayed read only. No fresh emulator or iOS acceptance is claimed.

## Security checklist

This documentation-only delta changes no executable security or data path.
Canonical verification remains signature over exact bytes, appId, pointer seq,
floor, requires, path/hash/size fields, then per-file hash/size. Nonce validation,
strict decoding, off-origin navigation/subframe denial, atomic state writes,
key handling and release-build dev-mode exclusion are unchanged. Existing
schema numbers and additive compatibility remain intact.

## Validation

All combined gates passed on November 9. Flutter commands ran serially.

Revalidated after packages advanced during final verification to code d0ce45f /
site cdb30e5. Merged each base into the feature branch and integration. Resolved
the spec and website debugging conflicts by retaining the upstream mandatory
store-update drop diagnostic alongside the corrected trace/probe limits.
Upstream lease timing, logger safety, MIME ownership and Windows discovery
corrections are retained. The feature delta against those bases is still prose
only. The intermediate refresh was stopped after root passed and before its
core suite finished because the code base advanced; it supplies no core verdict.
The final full run below completed against both newest bases.

| Gate | Result |
| --- | --- |
| Root npm test | 123 passed, zero skips; generated Dart analysis/dispatch executed |
| Core tests / fatal-info analysis / pub dry run | 666 passed / clean / zero warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / clean / zero warnings, one local-override hint |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 37 passed / passed / passed |
| Example codegen / tests / debug APK | no writes / 29 passed / built, Gradle 21.0s |
| Standalone Windows py Firebase audit | PASS: core graph, manifest and 19 DEX files |
| Website build / SEO | 50 pages passed; corrected debugging guidance in rendered HTML |

The existing app_badge_plus Kotlin migration warning remains; the successful APK
build is not a warning-free build. Logs: %TEMP%/valence-20261109-162-final-<gate>.log;
summary: %TEMP%/valence-20261109-162-final-results.json. Read-only artifact audit:
%TEMP%/valence-iteration162-readonly-audit.py. Only validation notes follow these
gates. No new device acceptance, push, publication or protected-branch mutation.

Combined gate results and exact integration bases/merge order are recorded in
[integration.md](integration.md).
