# R27 validation - 2026-10-29

## In plain terms

Firebase is a native dependency opt-in. Core `valence` retains the provider-neutral
push lifecycle, wire messages and background-hint policy; `valence_push` supplies
the Firebase transport. Core-only apps no longer inherit Firebase. Local
notifications and badges remain core dependencies, so their Android setup still
applies. Push adopters add the new package and replace `ValencePush()` with
`createFirebasePush()` after Firebase initialization. Custom transports now use
`ValencePushMessage`, including notification-envelope presence. No wire field,
bridge schema number, package version or manifest format changed.

Decision: prioritize the native dependency boundary and preserve users' data and
shipped signatures. Moving local notifications/badges too would enlarge the
migration without being needed to remove Firebase. The new package has a versioned
core dependency and a development-only sibling override excluded from its upload.
The core example deliberately has no push initialization or dependency; its
existing signed page still exercises the unsupported path. A Dart define cannot
install the adapter.

Base heads: code packages `41fed55615cbece1595766ccb83a31e47c1a0be5`, site packages
`7bfe7bd0a26ef734396537f2279685c329e47ff4`. Implementation commits: code `f234d48`,
site `db6f0eb`; subsequent documentation corrections are on the same R27 branches.

## Gates

| Gate | Result |
| --- | --- |
| Root npm test | 96 passed, zero skipped; generated Dart analyzed/exercised, generated strict TS included |
| Core flutter test --no-pub --concurrency=1 | 532 passed |
| Core dart analyze --fatal-infos . | No issues |
| Firebase adapter flutter test --no-pub | 2 passed, including native-channel conversion and empty-notification sync denial |
| Adapter dart analyze --fatal-infos . | No issues |
| Example flutter test --no-pub | 26 passed |
| Core pub publish --dry-run | 0 warnings |
| Adapter pub publish --dry-run | 0 warnings, 1 local dependency-override hint; override absent from upload |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 29 passed / passed / passed |
| Site build and SEO | 41 pages passed |
| Example debug APK | Passed in 353.1 seconds; 2 GiB Gradle heap, two workers, ActiveProcessorCount=2 |
| Core graph / APK Firebase audit | Passed: no Firebase package, manifest component or SDK class reference in all 19 DEX files |
| Example codegen check / signed built-in verification | No stale files / seq 1793209750 verified |

The initial root run failed while loading the wizard suite because the version
regression test's declaration had accidentally been inserted twice. Removed the
duplicate and reran the entire suite: 96 passed, zero skips. Assertions and
timeouts were unchanged. The initial artifact audit deliberately rejected the
inherited APK, finding Firebase class references before rebuilding.

The APK has the existing app_badge_plus KGP migration warning. No Firebase
KGP warning remains. Android build evidence is separate from device delivery.

Logs are `%TEMP%/valence-r27-*.log`, with Flutter exit codes/timings in
`valence-r27-flutter-results.json`. Adapter publication uses the local unpublished
core override, which pub identifies as a hint. Before publishing the adapter,
the maintainer publishes core first and repeats resolution against that release.

## Security checklist and acceptance limits

Reviewed the package changes against the valence-reviewer checklist: core still
owns nonce/strict dispatch and encoded message caps; the adapter only converts
native envelopes. Empty notifications remain notifications even without text,
so they cannot become data-only commands. Exact one-field hints, HTTPS-only image
metadata, event escaping, passive startup, permission-gated registration, APNs
readiness, tap ordering and cancellation remain covered. The token/lease runtime
regression moved to a provider-neutral transport and still verifies foreground
and background sync without closing the UI store or changing activation state.
OTA verification order, atomic state, navigation locks and account/outbox handling
were not altered. Independent improver review remains required before merge.

Read-only inputs: both apps' VALENCE_FINDINGS.md, Kundalini iteration 13 and app-a
iteration 14. R27 addresses the framework cause of Kundalini F-58; it does not
establish adoption on either app's snapshots or close app-a F-34's remaining
local-notification/desugaring cost. Kundalini's device/verification placeholders
and app-a's incomplete latest native build remain acceptance limits. F-33/F-35
root causes are not inferred here. No new emulator run or test-app modification;
iOS remains experimental and untested. Firebase delivery still needs a maintainer
project. No shared-branch commit/merge, push, publication or package-version bump.
