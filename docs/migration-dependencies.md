# Migration dependency guidance - 2026-11-08

In plain terms: the migration page no longer tells current hosts to add the
historical `dbus` override. The source migration guide, contracts section 6 and
website host guide now distinguish the old notification 19.x conflict from the
current built-in reminder stack. Existing app-owned 19.x handlers need review
before upgrading; only overrides added solely for that conflict should be removed,
followed by `flutter pub get` against the app's complete graph.

Branch: `codex/migration-dependencies`, starting at code packages c091bee and site
packages 5c17a0d. This corrects App C iteration 153's migration-docs F-44 (distinct
from its historical sync/lease F-44 label). Evidence: its read-only
`VALENCE_FINDINGS.md`, `ITERATION_153_REPORT.md`, and
`evidence/iteration-153/docs-review153.md`.

Read both findings inventories and the newest reports, Kundalini 23 / App C 153.
App C reports 102 artifact checks with scopedAcceptance=false. Its camera and
host/gallery focus-loss ANRs remain separate from successful media retries;
canonical fresh installation remains unverified. Kundalini F-83 still requires a
rebuilt-host device recheck against the queued lease-clock correction. Neither
report is fresh device acceptance for this branch.

Decision: correct the instructions instead of changing working dependencies.
Security and users' data take priority: no database reset, signing change, lease
change or native rebuild is prescribed by this correction. Package constraints,
schema numbers, runtime versions, codegen and templates stay unchanged because
this is a documentation correction with no behavior change. The Stack baseline
table is unchanged. No new must-have or original rebase-queue item is eligible;
their Status cells are unchanged.

Local evidence: `packages/valence/pubspec.yaml` declares notifications ^22.3.2 and
connectivity ^7.3.2, with no override file in the core package. The local resolved
lock has notifications 22.3.3, connectivity 7.3.2 and dbus 0.8.0. The existing
local-notification guide already describes this compatible stack. This does not
recertify external package registries or an arbitrary adopter's dependency graph.

Independently checked all 52 evidence links in App C's latest report: none are
missing. Its saved audit contains 102 passing checks and scopedAcceptance=false.
These artifact checks do not establish device acceptance.

Security review: verification order, nonce, navigation lock, strict decoding,
atomic writes and key management are untouched. The advice removes only the
obsolete workaround and asks adopters to validate their complete dependency
graph. No new regression test mirrors this prose-only change.

Fresh branch gates passed on November 8:

| Gate | Result |
| --- | --- |
| Root `npm test` | 122 passed, zero skips; generated Dart analysis/dispatch executed |
| Core tests / fatal-info analysis / pub dry run | 663 passed / clean / zero warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / clean / zero warnings, one local-override hint |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 37 passed / passed / passed |
| Example tests / debug APK | 29 passed / built in 17.7s on retry |
| Windows `py tool/check_no_firebase.py` | PASS over core graph, manifest and all 19 DEX files |
| Site build / SEO and links | 50 pages passed |
| Diff hygiene | Passed in both repositories |

The first APK runner stopped on the existing app_badge_plus Kotlin warning
because its PowerShell error preference treated stderr as terminating. That
attempt is not counted as a pass. The corrected runner captured exit 0 and the
APK completion above; the plugin warning remains. Logs:
`%TEMP%/valence-migration-20261108-*.log` (APK result in `example-apk-retry.log`).

No emulator run, publication or push is part of this correction. iOS remains
experimental and untested. Combined integration gates are recorded separately.
