# S7: disposable offline REST cache — 2026-11-01

## In plain terms

An app can keep selected responses from an existing REST API in native SQLite,
then read them offline through the ordinary data bridge. A store build grants
each cache bucket explicitly. Cached values never become server history or
queued user edits. Pulls replace matching cached values, recorded account changes
clear them, and removing a grant clears retained overlays before native reads.

Code base: packages `778b20cdc33f2014ec0ebf72323acd2bdf5e52be`.
Site base: packages `9ed2ee99a4f4c4742da4e1c015e3d654ba6b666c`.
Implementation `778f51a`; adoption docs `71da146`; seed test adapter `e81ce42`.
Site `6b2ffe6`, FAQ follow-up `b380782`. Branch: `codex/s7` in both repos.
Package/release versions are unchanged. Built-in capability/schema revision is
18; existing method/event `since` values are unchanged.

## Decisions and review

Security first: a default-empty compiled `cache` grant controls page writes;
an OTA cannot grant access. Revoking a grant purges its old overlays at native
open, restoring underlying server values. Writable buckets are always refused.
Strict nonce/parameter checks still precede dispatch. Keys are SQL parameters;
dot-segment keys fail, and values are capped at 65,536 encoded UTF-8 bytes.

Preserve data next: a separate migration-3 cache table never alters existing
server rows/cursors or outbox entries. Overlay eviction reveals the underlying
row. Pull rows/tombstones and imported seed rows remove matching overlays in
the same transaction. New data schemas see no copied cache; old-schema cache
remains reversible until ordinary post-commit pair GC. Cache-only pairs are GC
discoverable but never count as synced for OTA activation.

Developer experience: all read APIs share one union and key cursor. Cached
list/batch rows use the new local-only sentinel `usn: -2`; `-1` remains pending.
No method or Row shape changes. Cache writes neither trigger sync nor claim
sync freshness. Retention is page-managed, with no TTL or total cache quota.
Account switches drain in-flight writes, refuse new writes during transition,
and clear all cache atomically with writable rows. The page must still discard
REST responses fetched under an old account; the cache cannot infer provenance.

Independent security review found and resolved a plugin-test fixture typo,
stale REST-adoption advice, a retained-overlay grant-revocation edge case and
two account-clearing documentation qualifications. The follow-up found no
additional concrete defect. The new numeric sentinel was reviewed as additive:
Row.usn remains an integer, existing meanings are preserved and new overlays
require an explicit native grant.

## Test-app context and limits

Read both findings and latest iteration reports read-only: Kundalini 17 and
app-c 27. S7 addresses Kundalini F-71's missing local REST-to-SQLite path. It
does not implement S6's cookie jar, bulk API requests or a sync adapter. Apps
must validate their API payloads and retain only the data they need.

App-c's ordinary-launch recurrence, retained-prior-host timeout with a possible
harness confound, ANR/memory-pressure and transaction findings remain open.
Its new F-38 renderer-marker documentation discrepancy is outside S7. Scoped
native/OTA/worker successes do not close those intermittent findings.

No test-app files were written and no emulator lock was taken. This run does
not claim Android cache device acceptance. The example proves the generated
dispatch and compiled grant in a native wiring test; its checked-in signed
builtin remains the previously verified revision-17 UI. iOS remains
experimental and untested. No protected branch changes, push or publication.

## Gates

Passed 2026-11-01 on the final implementation:

| Gate | Result |
| --- | --- |
| Root `npm test` | 109 passed, zero failures/skips; real generated Dart and strict/verbatim generated TS ran |
| Core `flutter test --concurrency=1` | 573 passed |
| Core fatal-info Dart analysis | No issues |
| Core pub dry-run | 0 warnings |
| Push tests / fatal-info analysis / pub dry-run | 2 passed; no issues; 0 warnings, one local-override hint |
| Bridge tests / strict-verbatim TS / packaging | 29 passed; clean; dry-run passed |
| Example tests / codegen check | 29 passed; written: [] |
| Site build and SEO | 45 pages, clean |
| Root packaging dry-run | Passed |
| Debug APK | Passed, 306.1 seconds |
| Standalone Windows `py` Firebase audit | PASS: core graph and 19 DEX files / manifest contain no Firebase SDK references |

Earlier fixture failures and log-file collisions are excluded. One parallel core
run failed the bounded navigation-widget load deadline during the APK build;
startup itself completed. The unchanged full suite passed all 573 tests with
serial execution. This supports resource contention as an explanation but does
not establish its cause or repair an app finding. Existing plugin Kotlin
migration warnings remain in the APK build. Logs: `%TEMP%/valence-s7-*.log`;
the accepted core log is `valence-s7-serial-core.log`, analysis/pub logs are
`valence-s7-final-analyze.log` / `valence-s7-final-pub.log`, and the final site
log is `valence-s7-final-site.log`. No emulator acceptance is claimed.
