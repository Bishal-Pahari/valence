# R6 queue refresh validation ? 2026-10-22

Branch: `codex/r6` in both worktrees. Package base: `c55446f3d73afec7672c2615b0ffe70f1a6a074d`; site base: `5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390`.
Merge commits: package `4048ca0`, site `89e8296`.

## In plain terms

Deep links now include the newest shared runtime fixes and use reserved bridge schema 9. The generated clients, template, example and docs agree. The independent review found two defects that are fixed with regressions: the standalone web helper still used schema 5, and a WebView reload could lose a link before the new page subscribed. Each new page now re-arms the pending mailbox without replaying consumed links.

## Decisions

Retain the shared lifecycle/startup, sync-status and database migration behavior while adding the R6 surface. Derive the invalid-future-version test from the current schema instead of using literal 9. Keep link origins compiled into the store build; links remain untrusted routing input and cannot grant HTTP access, native authority or off-origin navigation. These choices prioritize security and user data over routing convenience. R8 and R7 must merge before R6: this branch reserves schema 9 but does not duplicate their features.

Generated files were regenerated. The example's merged HTML was rebuilt and signed through the normal keyring-matched CLI; obsolete content-addressed assets were removed. No package version changed.

## App evidence read (read only)

- Kundalini: `VALENCE_FINDINGS.md` and newest `ITERATION_10_REPORT.md`. Migration retained existing data with an app-side database move; the 912-row catalogue exposed paging truncation. Batch reads, sync status, cache revalidation and rollback were exercised. Findings F-41?F-48 describe migration/dependency/docs/status gaps.
- App-a: `VALENCE_FINDINGS.md` and newest `ITERATION_7_REPORT.md`. The 0.4 migration retained the shelf; a fresh 54.3 MB seed launch was slow, account switching remained refused, anonymous 401 reporting needed follow-up, and Android insets required correction.

These app reports are historical evidence for their snapshots, not new tests of this branch. Neither app repository was changed.

## Final gates

| Check | Result |
|---|---|
| `npm test` | 61 passed, zero skipped; generated Dart and strict generated TypeScript ran |
| Runtime `flutter test` | 385 passed, including reload mailbox regression |
| `dart analyze --fatal-infos .` | No issues, including example |
| Bridge `node --test test/*.test.ts` | 23 passed, zero skipped |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Bridge build and pack dry run | Passed |
| Example `flutter test` | 17 passed |
| Example debug APK | Built; embedded manifest matches source, seq 1792641283, bridge 9 |
| Example `codegen --check` | No files written |
| Signed built-in `verify` | Passed; seq 1792641283, one file |
| Site `npm run build` | 27 pages; SEO checks passed |
| `flutter pub publish --dry-run` | Zero warnings |

The first CLI run caught a test using literal 9 as an invalid future version. After replacing it with `s.version + 1`, the entire suite passed again. The runtime suite and analyzer were rerun after the mailbox fix; bridge checks and site build were rerun after their final edits.

## Security review

No unresolved confirmed findings after fixes. Reviewed exact compiled origins, URL/path validation and bounds, startup deduplication, repeated intents, page-reload mailbox ownership, disposal, local History API routing, standalone/generated schema gates, strict generated decoders and nonce enforcement, and association-file identity validation/refusal to overwrite. Signature verification order, navigation lock, atomic updater writes and external key handling remain intact.

## Android evidence and limits

Shared lock `codex-builder` acquired and released. The helper's `ensure` timed out because its unqualified ADB commands saw two devices. Explicit `-s emulator-5554` confirmed boot completion and was used for every device action. Only the package example was installed, over its existing install; user data was retained.

- Actual Android package: `com.getvalence.valence_example` (distinct from Valence config appId `com.getvalence.example`).
- Cold VIEW intent `valence-example://app/shelf?sort=new#cold` routed to exactly `/shelf?sort=new#cold`. A read-only WebView inspection confirmed the route, page text, bridge 9 and bundle 1792641283. Activity launch waiting timed out under load, but the page subsequently loaded and routed correctly.
- Two identical warm intents reached the existing activity; two separate `link routed: /shelf` log entries were observed. Page location/text confirmed `/shelf?sort=warm#one`.
- `pm verify-app-links --re-verify` and `pm get-app-links` ran. Placeholder `links.example.invalid` reported state 1024, not verified ownership.
- Forced App Links approval and adversarial-intent device probes did not run: execution policy rejected the commands. Malformed path/origin rejection is covered by the package regressions. Forced HTTPS delivery is not claimed, and real ownership verification needs a controlled HTTPS domain and the actual app-signing certificate.

The temporary WebView debug forward was removed, the example was force-stopped and the lock released. No other app data, network settings or forwards were changed. No pushes, publications or merges into shared branches occurred. iOS custom schemes and Universal Links remain experimental and untested.
