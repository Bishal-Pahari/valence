# R15: host widget test harness

Date: 2026-10-22. Branch: `codex/r15` in both worktrees.
Bases: package `c55446f3d73afec7672c2615b0ffe70f1a6a074d`, site
`5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390`.

## In plain terms

The runtime's host widget now has tests that exercise its real lifecycle and navigation callbacks.
They can catch a resume starting work too early, a page navigating outside its allowed origin, or a
ready timer rolling back the wrong bundle. A test-only native WebView platform supplies the callbacks;
signed bundle checks, the activation state machine, SQLite and loopback sockets stay real.

## Decisions

Security first: keep all production trust checks intact. Dispatch tests observe the live nonce and
serialized reply, while strict decoding and nonce denials stay in their existing lower-layer tests.
No production testing switch, alternate host implementation or generator/template fork was added.

User data: the disposal case verifies the socket closes while SQLite remains usable. Test cleanup
closes only its own temporary database after unmounting the widget and draining asynchronous work.

Developer experience: use the existing WebView platform interface as a dev dependency. Unsupported
operations throw; tests observe the real navigation delegate, channel, PopScope and lifecycle observer.
The harness is package-owned and apps need not copy it.

Timing: `Stopwatch` uses elapsed real time. Tests run page-start callbacks in `tester.runAsync` and wait
beyond the real ticker deadlines, including the configured five-second update interval on disposal.
Review caught assertions masked by the no-trial timeout guard; both successful-ready and current-page
tests now reject timeout logs, and current ready must leave `previous` null. A loaded full-suite run
also exposed a fixed-delay startup assertion: it now waits with a bound for the sync request instead of
assuming SQLite has acquired its lease within 150 ms. The held-startup no-work checks remain strict.

## Verification

| Gate | Result |
|---|---|
| `npm test` | 59 passed, zero skipped; generated Dart and strict generated TypeScript ran |
| `flutter test` in runtime | 389 passed, including nine host-widget cases |
| `dart analyze --fatal-infos .` | No issues |
| Bridge `node --test test/*.test.ts` | 18 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Site `npm run build` | 27 pages; SEO checks passed |
| Example `flutter test` | 16 passed |
| Example `codegen --check` | No files written |
| Example `flutter build apk --debug` | Passed |
| `flutter pub publish --dry-run` | Zero warnings |
| Security review | Timer assertion gaps corrected; final review has no remaining findings |
| Both worktrees `git diff --check` | Passed |

Implementation commits: `79ac51b`, `3176d87`, `c691717`; code documentation `d7aa2bf`.
Site commits: `bb5b2ad`, `87695bb`. Raw command logs were moved out of the repositories to
`%TEMP%/valence-r15-20261022/`. The earlier flaky full run and dirty-tree pub warnings are retained
there alongside the final successful results; they are not counted as passing checks.

## Scope and limits

Read the current findings and newest reports for Kundalini (iteration 10) and app-a (iteration 8).
Their data migration, paging, authentication and device timing findings informed the separation of
runtime evidence from device evidence. Both test app repositories remained read-only.

No runtime behavior, bridge schema, package version, CLI, generated output or templates changed.
Docs cover the harness in the spec matrix, skill guidance, repository/package READMEs and the site
guide/host page/llms map. The site generates its full machine-readable docs from the content collection.
No homepage feature claim is needed for package test infrastructure.

No emulator run was needed for this test-only change. Native HTML rendering, JavaScript execution,
device WebView isolation and port-reclamation nonce rotation are not proved by this harness. Android
device evidence remains separate; iOS remains experimental and untested. No shared branches were
modified, and nothing was pushed or published.
