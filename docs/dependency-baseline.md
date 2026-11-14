# One dependency baseline (F-45) - 2026-11-04

In plain terms: removed the stale duplicate `the other §6 packages` row from
the copied skill. The surviving row already distinguishes the historical 19.x
notification conflict from the built-in 22.3.2 / connectivity 7.3.2 combination.
The blank line that split the Markdown table is gone too.

Evidence: App C's read-only `evidence/iteration-87/docs-scout-review.md` identifies
both rows and recommends the current local-notification guide. That scoped scout
did not recertify external registries or policies. The retained combination is
also declared by this repository's `packages/valence/pubspec.yaml` and described
in the site's local-notifications guide. No version recommendation is newly
introduced or upgraded here.

Reviewed both findings inventories and newest reports: Kundalini iteration 18
and App C iteration 87. App C records artifact consistency passing but scoped
acceptance failing because Settings survival failed: host PID 6188 was killed
under memory pressure, replacement 7962 was blank, then explicit relaunch
recovered readiness. Recovery does not close F-36. Offline/reconnect passed
without process recovery; this does not close historical F-44. One explicitly
triggered worker execution does not establish natural cadence. F-45 needs copied
tooling adoption before the app can verify the correction.

Decision: remove contradictory instructions rather than change working pins or
runtime behavior. Preserve security boundaries, users' data and shipped schemas.
This documentation-only follow-up changes no spec, package, generator, template,
runtime version or dependency constraint. iOS remains experimental and untested.

Fresh branch gates passed on November 4:

| Gate | Result |
| --- | --- |
| Root `npm test` | 113 passed, no failures or skips; generated Dart and strict/verbatim TS ran |
| Core tests / fatal-info analysis / pub dry run | 604 passed / no issues / zero warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / no issues / zero warnings, one local-override hint |
| Example tests / debug APK | 29 passed / built in 184.9 seconds; existing Kotlin plugin warning |
| Windows `py tool/check_no_firebase.py` | PASS: core graph, manifest and 19 DEX files contain no Firebase SDK references |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 36 passed / passed / passed |
| Root pack dry run | Passed |
| Site build / SEO | 47 pages OK |
| Baseline inspection / diff hygiene | One section-6 row, continuous table / passed |

Logs: `%TEMP%/valence-baseline-*.log`. No emulator acceptance, package publication,
protected-branch change or test-app write. Integration gates are recorded separately.
