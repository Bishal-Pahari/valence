# Legacy link migration correction

Branch: `codex/link-compat`, based on packages code
`472bd2f13f71702cd4abb59ede590783ecd8104c` and site
`bb8d82fc509825f34d45cfd5ca06d72c7237030b`.

## Evidence and decision

The 2026-10-29 test period uses Kundalini and app-c (Fieldnote). Read their
VALENCE_FINDINGS.md and newest iteration reports: Kundalini 14 and app-c 1
(the latter completed on 2026-10-30). The previous integration notes concern
app-a; they are historical evidence, not acceptance for this period's app-c.
All R1-R29 roadmap entries and the original rebase queue are already done.

App-c F-26 establishes a migration blocker: updating tooling rejects its shipped
since-2 `link.initial(): string?`, because codegen claims every declaration of
that name as the package's nullable structured return. A schema-3 fixture with a
recorded store baseline reproduced the exact error before the fix. The app's
local compatibility regression independently records the same cutoff workaround.

Decision: give `link.initial` the schema-9 delegation floor, using the existing
reserved-since mechanism. Preserve the shipped method, custom event and baseline.
This prioritizes existing contracts and users' data over replacing their API.
Renumbering or rebaselining would hide a wire break; a new runtime adapter is
unnecessary because codegen already supports app-owned handlers. Package and
schema versions stay unchanged. The example's vendored CLI stays byte-identical.

The spec, copied app instructions, both migration guides, site bridge/deep-link
guides and changelogs explain which handlers to retain. Legacy routing keeps its
own adapter; `onLink` expects the modern shape. Leave `links.origins` empty while
app-owned native listeners deliver links. No package implementation changed.

## Regression and security checklist

- The reproduction failed with the reported nullable-string rejection, then
  passed after adding the floor. Codegen/check retains the original baseline;
  repeating `bundle --store` retains its schema. Method/event removal, return
  changes, since changes and event payload changes remain refused.
- A modern declaration delegates at 9. A modern shape below 9 without a recorded
  baseline is refused with the reserved number; a redefinition at 9 is refused.
- Read-only `codegen --check` using the patched framework CLI against app-c's
  current files passed with `written: []`. Existing unknown-name warnings for
  its custom share/auth/notification methods remain warnings. No app file changed.
- Generating Dart and TS from the modern template before/after the change gives
  byte-identical output. The dispatch nonce check, strict params, result encoding
  and event generation are unchanged. The origin allowlist and runtime link
  validation are unchanged; documentation distinguishes legacy listeners.
- No changes to signing/verification order, navigation/subframes, atomic writes,
  key handling, sync, storage, OTA or the release-build dev guard. This is a focused
  checklist review, not an independent runtime security review or device pass.

## Remaining app evidence

App-c reports scoped Android acceptance including R3 prompts, R4 delivery/cold
tap, R10 plugin calls, R28's full queue, retained-data migration, signed OTA and
two-failure rollback. Those are app results, not gates rerun here. Its capture
records a recovered 12191ms store.open and a separate background BEGIN EXCLUSIVE
SQLITE_BUSY retry; it does not establish a new corrective runtime change.
F-27's host-file API recipe remains a documentation gap. F-29's original mixed
camera/deep-link task stack remains an app regression target, not an isolated
package defect; the clean-task notification adapter path passed in the app.

Kundalini still has schema-16 source/tests but an installed schema-11 host and
unobserved delivery in its latest iteration. Its schema-16 OTA remains withheld.
Do not change database ownership, retry budgets or data on these observations.
Keep the feature freeze, S1 deferral, S2 account blocker and post-beta scope.
iOS remains experimental and untested.

## Validation

Completed 2026-10-30 (Asia/Katmandu), on implementation commit `5028f9b` and
site commit `f494813`. Both packages bases remained unchanged through validation.

| Gate | Result |
|---|---|
| Root `npm test` | 101 passed, zero failures/skips; generated Dart compile/dispatch and strict/verbatim TS included |
| Core `flutter test --concurrency=1` | 542 passed |
| Core `dart analyze --fatal-infos .` | No issues |
| Core `flutter pub publish --dry-run` | Zero warnings |
| Push adapter tests / fatal-info analysis | 2 passed / no issues |
| Push adapter pub dry run | Zero warnings, one local-override hint |
| Bridge `node --test test/*.test.ts` | 29 passed, zero failures/skips |
| Bridge TypeScript | `npx -y -p typescript tsc -p tsconfig.json --strict --verbatimModuleSyntax` passed |
| Bridge `npm pack --dry-run` | Passed |
| Example `flutter test` | 27 passed |
| Example `codegen --check` | Passed, `written: []` |
| Example `flutter build apk --debug` | Exit 0; final run 41.1 seconds, Kotlin-plugin warning for app_badge_plus retained |
| `py example/tool/check_no_firebase.py` | PASS: core graph and all 19 DEX files / manifest contain no Firebase SDK references |
| Site `npm run build` | 43 pages; SEO/link/anchor checks passed |
| App-c read-only codegen / modern output comparison | Passed as described above |

The initial root run passed 100/101 tests and caught the example's stale vendored
CLI. Synchronized it and reran the complete suite successfully. The initial APK
runner used PowerShell's Stop preference, which aborted on Flutter's stderr
Kotlin-plugin warning before recording the native exit code. A standalone rerun
preserved stderr, returned 0 and printed the built APK path; the separate Python
audit then passed. Neither interrupted run is counted as a pass.

No emulator session, test-app writes, package/schema-version changes, protected
branch changes, pushes or publications. The single corrective branch needs review
and merge; it does not trigger the two-unmerged-branch integration rule.
