# R5 queue refresh validation - 2026-10-26

R5 is refreshed on `codex/r5` in both designated worktrees. Package base:
`e879260366282c9f504057423d54f682dcb10c81`; site base:
`f59fbc1568c895d4cd35d385733175397beeef6a`. Implementation merge: `b3f2c8e`;
legacy fixture correction: `6790ec0`; site merge: `38c707a`.

## Decisions and scope

Security first, then users' data, then developer compatibility:

- Keep upstream schema **13** and `auth.account` since **13**, with every R5
  method/event since **12**, the number reserved for push. Lowering the combined
  schema to 12 invalidates the upstream account API. This explicitly departs from
  the queue's request to set the whole schema to 12. This intermediate host must
  not be published until the earlier reserved surfaces are integrated.
- Preserve the real example schema-1 store baseline from `packages`, rather than
  record the incomplete combined surface as an already-shipped schema-13 host.
- Preserve upstream account/outbox protections, shared database lifetime, locked
  open handling, native token use, and lease-protected background sync. Push data
  remains untrusted; only an exact data-only sync hint can trigger ordinary sync.
  No payload can change config, navigate, activate an OTA bundle or acknowledge
  a trial. Nonce checks, strict decoders and bounded escaped envelopes remain.
- Resolve source conflicts by combining push with upstream account exports and
  current lifecycle/capability guidance. Regenerate both bridge outputs with
  method and event tables. The signed built-in is seq **1793038082**, bridge 13,
  one file. Its signature, file hash and size verify; codegen has no drift.
- Keep app-owned pre-12 push handlers custom. The legacy fixture removes newer
  account declarations before lowering its schema to 11. Regression coverage
  checks combined schema 13, account since 13, push since 12 and legacy delegation.
- Both push guides now explain app-owned schema numbering and updating codegen
  together with the web bridge package, prompted by app-a F-32.

## Merge dependency and inherited limits

Merge R8, R7, R6, R3 and R4 before R5, as the queue requires. R7 contains a fix for
an inherited HIGH account-switch partial secure-write failure and serializes auth calls.
If the new bearer write succeeds and the account-id write fails on the base,
sync can use the new bearer under the previous identity.
R5 retains the `packages` auth method bodies unchanged; this standalone branch is
not a substitute for that earlier fix. Keep the earlier R7 account-write ordering
when merging. Review this integration again after the earlier branches land.

Neither this refresh nor passing gates establishes Firebase delivery. Device
acceptance remains **blocked: needs Firebase project**. No live delivery, image
display, token rotation, or OS push-background execution is claimed. A sync hint
completing is not proof of authenticated backup; anonymous writable-bucket 401
reporting and sync-status outcome persistence remain inherited limitations.

## Gates

| Check | Result |
|---|---|
| Root `npm test` | 68 passed, zero failed/skipped; real generated Dart and strict generated TS exercised |
| Runtime `flutter test` | 415 passed |
| Runtime `dart analyze --fatal-infos .` | No issues, includes example |
| Example `flutter test` | 18 passed |
| Bridge `node --test test/*.test.ts` | 21 passed |
| Bridge strict `tsc -p tsconfig.json` | Passed |
| Bridge build and `npm pack --dry-run` | Passed |
| Site `npm run build` | 29 pages; SEO/link checks passed |
| Example codegen check and signed built-in verification | Passed |
| Runtime `flutter pub publish --dry-run` | Zero warnings after implementation commit |
| Example `flutter build apk --debug` | Passed; embedded built-in manifest matches signed source |
| Both `git diff --check refs/heads/packages` | Passed |

The first root run loaded the pre-correction legacy fixture and failed it; the
complete rerun passed all 68 tests. The first pub dry run warned only about the
uncommitted merge; the committed implementation passed with zero warnings.
The Firebase Core Kotlin Gradle Plugin compatibility warning remains a future
build-toolchain limitation; no dependency or release version was changed here.

## Independent review and intake

The read-only `valence-reviewer` pass found the legacy fixture issue, now fixed,
and no additional confirmed R5 security defects. It independently passed 89
focused runtime tests, 16 CLI schema/builtin/push checks, all 21 bridge tests,
strict TypeScript, Dart analysis, codegen check and built-in verification.
The account-switch issue above is an inherited dependency on the earlier queue.

Both complete app findings and newest reports were read only: Kundalini
`ITERATION_11_REPORT.md`, app-a `ITERATION_9_REPORT.md`. Their device observations
remain historical evidence. The app-a supplied wizard/bridge tarball mismatch
is not resolved merely by testing matching source here; harness snapshots were
not replaced. No test app or other builder's worktree was written.

No emulator was acquired because there is no configured Firebase project to test
end-to-end push. iOS/APNs and its service extension remain experimental and
untested. Exactly one queue item was refreshed. Nothing was pushed, published,
or merged into `packages` or `main`; no release versions changed.
