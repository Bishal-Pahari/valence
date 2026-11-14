# R25 validation — 2026-10-27

## In plain terms

The seed's data and its completion marker now have separate outcomes. A locked marker retries
without copying rows again, and the log says whether bookkeeping recovered or needs another
launch. A completed, unchanged seed is explicitly skipped on later launches.

Branch: `codex/r25` in both worktrees. Code base: `ebb0793d576c74c6841686298c9ad828479f02b7`;
site base: `afe2366c75670aa31811e0b2681fdc313f5d8751`. Implementation: `c5b0fd6`;
code documentation: `aa9a794`; site: `9f614ee`. The rebase queue and R14 are already merged;
this branch starts from packages, not from the separate R17 or R26 branches.

## Evidence and decisions

- Read the two test apps' findings and latest reports read-only: Kundalini iteration 12 and
  app-a iteration 10. R25 addresses Kundalini F-56. The reports' unmatched CLI/bridge snapshots
  are separate distribution evidence; neither test app nor its snapshots were modified here.
- The deterministic reproduction runs `flutter test test/seed_runtime_test.dart --reporter expanded`
  inside `packages/valence`. Before the fix, a marker-only lock left imported data present but
  the marker null; only one write was attempted. Five initial tests failed. The completed-seed
  case also exposed a second import on an unchanged launch. After the fix and an additional
  upgrade regression, all six pass.
- **Data first:** retry only the marker, after import returned successfully. Repeating the import
  as part of each retry would add database work and widen its collision window. Keep the old
  marker on failure; test recovery after a newer sync proves the older seed does not replace
  those rows or lower their cursor.
- **Bounded retry:** use the same five attempts and one-second intervals as database opening.
  Non-lock failures are not retried. SQLite's busy timeout can add elapsed time; this does not
  promise a five-second launch deadline. A generic retry abstraction would add no value here.
- **Honest diagnostics:** distinguish incomplete import (possibly some pairs committed), failed
  marker persistence, successful marker recovery, and an actual skip. Startup still retains
  the store when import/bookkeeping fails.
- **Honor the existing completion stamp:** the old code used a matching marker only to skip
  extraction, then still attached/imported/stamped every launch. It now skips the import too,
  as section 5.2 and the method's own comment intended. Tests cover host-build, asset-length
  and missing-extracted-file invalidation, plus retaining an old marker on an upgrade failure.
- No wire or config shape changed. Schema numbers, `since`, package versions and CLI version
  are unchanged. The fix belongs in the runtime; generating a copy into each app would violate
  the package boundary. Existing generated sources remain fresh. The template and skill point
  to the recovery guide; the site guide, navigation, data guide, offline guide, README and
  machine-readable summary are updated. Home-page/FAQ product claims need no change.

## Final gates

| Gate | Result |
| --- | --- |
| Root `npm test` | 88 passed, zero skips; generated Dart and TypeScript checks ran |
| Runtime `flutter test` | 500 passed, including six new seed regressions |
| Runtime `dart analyze --fatal-infos .` | No issues |
| Example `flutter test` | 24 passed |
| Bridge `node --test test/*.test.ts` | 29 passed, zero skips |
| Bridge `npx -y -p typescript tsc --strict -p tsconfig.json` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Example `node valence/valence.mjs codegen --check` | No files written |
| Example built-in `verify` with its files | Passed; sequence 1793062826, two files |
| Example `flutter build apk --debug` | Passed; final APK includes explicit skip logging |
| `flutter pub publish --dry-run` | Zero warnings after committing; no publication |
| Site `npm run build` | 38 pages; SEO checks passed |
| `git diff --check` | Passed |

The first analysis run found a missing brace in the new test fixture; fixed before the clean
final analysis. The first pub dry-run warned about uncommitted tracked changes; the clean-tree
rerun has zero warnings. Android build output still contains the upstream Firebase/Kotlin
plugin migration warning; it did not fail the build and no dependencies were changed.

## Android smoke check

Took the `codex-builder` emulator lock, ensured `valence_test` (`emulator-5554`), installed the
debug example, and cleared only `com.getvalence.valence_example`'s disposable data. No test-app
data, process, tunnel or repository was changed. An early capture preceded Flutter startup;
the completed first-import trace is PID 8694 and the subsequent relaunch is PID 8910.

First completed launch:

```text
seed: imported {plants: 3}
update: installed the built-in bundle 1793062826 as current
serving bundle 1793062826 on http://127.0.0.1:13882
webview finished http://127.0.0.1:13882/
ready: app.ready from a page that is not serving a trial; nothing to commit
```

After force-stop and relaunch:

```text
seed: skipped; completion marker matches host build and asset length
serving bundle 1793062826 on http://127.0.0.1:13882
webview finished http://127.0.0.1:13882/
ready: app.ready from a page that is not serving a trial; nothing to commit
```

The example's placeholder sync/OTA hosts failed DNS and push reported unconfigured, as expected;
the seed and built-in still reached ready. This was not an airplane-mode or real database-lock
collision test. Lock contention is deterministic fault-injection coverage against the real
runtime/SQLite import, not claimed Android contention evidence. Stopped the example and released
the lock. Raw traces were captured under the system temp directory as
`valence-r25-device-first-complete.log` and `valence-r25-device-relaunch.log`.

## Review checklist and limits

Reviewed the package diff against the reviewer checklist and contracts sections 5.2 and 8:
the reserved marker remains host-only, only recognized SQLite lock errors retry, completion
follows successful import, no store is cleared/closed, and no signing, verification, nonce,
navigation, atomic OTA state, token or release-dev boundary changed. All new behavior is native
runtime behavior with regression tests in that layer. No independent security review is claimed;
this change does not modify a security path and still awaits the improver's branch review.

Unchanged limits: same-build/same-length seed replacement does not invalidate this existing
stamp format; rebuild with a changed host build. This item does not retry row imports within a
launch or change retention/tombstone semantics. R17/R26 still require their own merges; no
combined feature validation is claimed. No iOS hardware test was possible; iOS is experimental
and untested. No version bump, push, publication or merge into a shared branch occurred.
