# R16: mechanical doctor validation

Date: 2026-10-22. Branch: `codex/r16` in both worktrees. Package base:
`c55446f3d73afec7672c2615b0ffe70f1a6a074d`; site base: `5a23a4e`.
Implementation: `dabed30`; site documentation: `bb1775d`.

## In plain terms

Doctor now refuses mechanically broken configurations with a fix and a nonzero exit.
The two entry points share bridge-version, store-baseline, signed OTA compatibility,
database-name, Git private-key and browser/native-origin diagnostics. The example's
vendored CLI is refreshed. No package version or bridge schema surface changes.

## Decisions

Security first: inspect verified OTA manifests before using requirements, reject malformed
bridge numbers, scan binary-classified files for PEM headers, and withhold secret contents.
Native token origins reject raw URL normalization tricks; browser URL paths stay supported.
Tracked and non-ignored files are scanned across the Git worktree. Ignored files and Git
history are outside scope; missing Git is WARN. Key directories resolving inside Git fail.

User data next: doctor never opens, renames or moves the installed database. A configured
path fails because the runtime expects a file name under app support. Actual installed
location and legacy adoption remain WARN, requiring device evidence. A source grep cannot
prove migration or arbitrary hand-written host wiring, so neither receives a false PASS.

Developer experience: every FAIL includes `Fix:`. The baseline must be restored from the
store release rather than rewritten to bypass compatibility. All local OTA manifests are
checked, including historical ones; archive obsolete releases outside `dist-ota`. Missing
store/OTA evidence stays WARN. Runtime behavior, dispatch and bundle verification order
remain unchanged.

## Checks

- `npm test`: 63 passed, zero failed or skipped. Generated Dart and TypeScript checks ran.
- `packages/valence`: `flutter test` 380 passed; `dart analyze --fatal-infos .` clean.
- `packages/bridge`: 18 tests passed; `npx -y -p typescript tsc -p tsconfig.json --strict`
  passed; `npm pack --dry-run` passed.
- Example: 16 tests passed; `codegen --check` wrote nothing; doctor exits 0 with explicit
  WARNs for unverified evidence, including database adoption and missing local OTA artifacts.
- Example `flutter build apk --debug` passed. The first pub dry run warned about the then
  uncommitted example CLI; after committing it, `flutter pub publish --dry-run` passed
  with zero warnings. No package was published.
- Site: `npm run build` passed, 26 pages, SEO checks clean, including the updated `llms.txt`.
- Focused regressions verify failures in both CLI entry points, database traversal/Windows
  paths and reserved names, browser/native origin confusion, baseline/bridge drift,
  signed incompatible and malformed OTA requirements, bad signatures, tracked/untracked
  PEM keys with NUL bytes, linked key directories, unavailable Git and secret withholding.

Security review closed three diagnostic false passes: malformed signed bridge requirements,
native origin whitespace/backslashes and binary-classified PEM files. Final review reports
no remaining confirmed findings. Runtime and bridge sources are unchanged; the review
checked diagnostic ordering and read-only behavior against the package reviewer checklist.

No emulator run: this item changes host-side CLI diagnostics only. No new Android device
behavior is claimed. iOS remains experimental and untested. Both test-app repositories and
the other worktrees were read only. No shared-branch merge, push or publication occurred.
