# R26 validation - 2026-10-27

In plain terms: a server that answers with an error no longer makes Valence say
the sync succeeded. `failed` covers incomplete server/protocol responses, while
token-bearing 401 remains `unauthorized`. Local changes and pending writes survive.

## Branch and scope

- Code: `codex/r26`, implementation `13ee7c7`, latest upstream merge `5974e04`,
  final classification `91d825a`; based on `packages` at `ebb0793`.
- Site: `codex/r26`, documentation `6ab35c2`, upstream merge `776a976`,
  existing-definition correction `1437672`; based on `packages` at `afe2366`.
- Both apps' findings and newest reports were read: Kundalini iteration 12 and
  app-a iteration 10. App-a F-29 is the motivating reproduction. No test-app files
  were changed. Neither packages nor main was committed to or merged into.
- No package/schema versions changed. The existing nullable string field already
  transports open reason values; codegen and templates need no shape change.

## Decision and review

Use the existing incomplete marker, with precedence `unauthorized`, `offline`,
`failed`, `ok`. Classify once while holding the sync lease so another run cannot
reset attempt flags before the result is chosen. The authenticated-401 gate,
token handling, row/cursor application, acknowledgement policy and timestamp guard
remain unchanged. This protects user data and avoids asking a user to replace a
valid token when an anonymous/public request failed.

The reviewer checked contracts, callers, generated wire shapes, data retention,
authentication and docs. Two contradictory old outcome definitions were corrected;
the final review has no remaining confirmed finding.

**R17 merge requirement:** R17 is a separate unmerged branch that persists the
last reason. Resolve its overlap with R26 by persisting this same classification,
including `failed`, rather than retaining a second unauthorized/offline/ok
expression. Verify failed status after driver replacement when integrating them.
This branch does not claim to implement R17's durable status field.

## Gates

| Check | Result |
|---|---|
| Root `npm test` | 88 passed, zero skips; generated Dart compilation executed |
| Runtime `flutter test` | 511 passed |
| Runtime `dart analyze --fatal-infos .` | No issues |
| Example `flutter test` | 24 passed; generated event serializes `failed` |
| Example codegen freshness | `written: []` |
| Bridge `node --test test/*.test.ts` | 29 passed, zero skips |
| Bridge `npx -y -p typescript tsc --strict -p tsconfig.json` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Runtime `flutter pub publish --dry-run` | Passed, zero warnings |
| Example `flutter build apk --debug` | Passed; existing Kotlin migration advisory remains |
| Site `npm run build` | 38 pages; SEO checks passed |
| Both worktrees `git diff --check` | Passed |

Regression coverage includes anonymous 401/403/500 for public and writable buckets,
invalid bodies/USN order, static index/chunk failure, push failure with pending
writes retained, partial progress, recovery reset, timestamp preservation, reason
precedence, runtime event delivery and generated event serialization.

The first root run had a sync-adapter subprocess failure without a useful cause
in its summary; subsequent complete root runs passed, including that test. A pub
dry run caught an uncommitted source file during commit sequencing; the repeat
from the committed tree passed with zero warnings. No dependency workaround or
test relaxation was introduced. The old successful-pull test fixture was corrected
from `max_usn` to the protocol's required `max` field.

## Limits

No new emulator check was performed; this run's evidence is package, generated
wiring and build evidence. No claim is made about replacement snapshots in the
test apps or Firebase delivery. iOS remains experimental and untested. Nothing
was pushed or published.
