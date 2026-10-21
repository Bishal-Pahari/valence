# R5 validation — 2026-10-22

R5 is implemented on `codex/r5` in both designated worktrees. It remains
**blocked: needs Firebase project for the device test**. No live delivery,
notification image display, or OS background execution is claimed. iOS/APNs and
the Notification Service Extension are experimental and untested.

## Implementation

- Schema-5 `push.token`, `push.permission`, consuming `push.initial`, plus
  `push.received`, `push.tapped`, and `push.tokenChanged`.
- Opt-in Firebase adapter; passive bridge startup never requests permission or
  fetches a registration token. Native Firebase auto-init is a separate host
  setting. The ordinary example works without a Firebase project.
- Only exact data-only `{"valence":"sync"}` messages request normal sync. The
  native config/token, sync lease and store rules apply. No payload can select a
  server, activate a bundle, consume a trial or close the database.
- Foreground notification metadata is delivered to the page; FCM handles Android
  background notification images. iOS rich-image templates and setup are supplied.
- Cold/warm tap race handling, bounded JSON events, HTTPS image metadata, and
  escaped Unicode line separators in scripts. Codegen rejects changed built-in
  shapes and still compiles older schemas.
- The signed example bundle includes the push controls and verifies successfully
  at seq 1792611216. Its native push opt-in is `--dart-define=VALENCE_PUSH=true`
  after the maintainer adds the matching Firebase project configuration.

## Gates

| Check | Result |
|---|---|
| `npm test` | 56 passed, zero skipped; includes real generated Dart/strict generated TypeScript gates |
| `packages/valence`: `flutter test` | 355 passed |
| `packages/valence`: `dart analyze --fatal-infos .` | No issues |
| Firebase adapter/integration tests, separately | 2 passed; native channel mapping and token-authenticated foreground/background sync leave bundle state unchanged |
| `packages/valence/example`: `flutter test` | 16 passed; generated dispatch denials include disabled push, bad nonce and malformed params |
| `packages/bridge`: `node --test test/*.test.ts` | 18 passed |
| `packages/bridge`: `npx -y -p typescript tsc --strict -p tsconfig.json` | Passed |
| `packages/bridge`: `npm pack --dry-run` | Passed |
| Site `npm run build` | 26 pages; SEO/link checks passed |
| Example `codegen --check` and signed built-in `verify --files` | Passed; no generated drift |
| `flutter pub publish --dry-run` | Zero warnings |
| Example `flutter build apk --debug` | Passed; final incremental build 26.7 seconds |
| Package/site `git diff --check refs/heads/packages` | Passed |

The first CLI run exposed a schema-4 literal in the doctor compatibility test;
it now replaces the generated version regardless of its number. The first pub
dry run rejected exact Firebase dependency pins; caret ranges now stay on
Core 4/Messaging 16 while allowing compatible fixes. Early integration fixtures
were corrected to the actual `k/v/u/d`, `max`, `more` sync wire format. A late review also found that separator expansion could enlarge an error reply
with a hostile correlation id. Both reply paths now count escaped bytes; oversized
errors use a bounded numeric/null-id fallback, verified through generated dispatch.
One overlapping test attempt hit Windows SQLite DLL contention; final checks ran
after serializing package tests. Final results above replace those earlier runs.

Firebase dependencies require iOS 15.0 even when push is disabled. The example's
Runner target and upgrade docs reflect that. Core 4.14 emits Flutter's warning
about plugins applying Kotlin Gradle Plugin; this needs rechecking before a
future Flutter upgrade. Messaging 17 changes the registration API to FIDs and
is intentionally outside the dependency range. Primary metadata and shipped
package source were checked on 2026-10-22; links are in the remote-push guide.

## Independent review

The read-only reviewer applied `.claude/agents/valence-reviewer.md` to the final
implementation and matching site docs. No confirmed security or compatibility
findings remain. Independently run: 34 combined push/wire/Firebase tests, 16 example tests,
18 bridge tests, 11 CLI compatibility tests, Dart analysis, strict TypeScript,
codegen check and whitespace checks. The reviewer correctly kept device
acceptance blocked rather than counting platform-channel mocks as delivery.

## Intake and scope

Read both apps' `VALENCE_FINDINGS.md`, Kundalini's latest `ITERATION_9_REPORT.md`,
and app-a's latest available handoff (`NEXT.md`, cycle 5) plus its later findings.
The newest app-a harness log (cycle 38) contains only a usage-limit response,
not a newer implementation report. The findings informed strict bridge payloads,
native background sync and honest device claims; unrelated findings were not
silently folded into R5.

No test-app or other builder worktree was written. No emulator was acquired:
without a Firebase project there is no end-to-end push check to run. No release version
numbers were changed, and nothing was pushed, published or merged into `packages`.

Implementation tip: `453d2b5`; site tip: `ffab4fe`, both `codex/r5`. All required gates and the additional APK/pub/pack checks passed. Device acceptance is the only R5 blocker.
