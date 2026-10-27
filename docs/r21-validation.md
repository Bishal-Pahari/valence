# R21: explicit LAN development trust

Date: 2026-10-27. Branch: `codex/r21` in both worktrees.
Code base: `ebb0793d576c74c6841686298c9ad828479f02b7`.
Site base: `afe2366c75670aa31811e0b2681fdc313f5d8751`.
Implementation: code `369fdf4`, site `e1aea8a`.

## In plain terms

The normal dev command now listens only on the development computer and keeps
the emulator target. A physical-device address or hostname needs `--allow-lan`.
LAN mode states that cleartext server code receives the full native bridge,
including secure storage, SQLite and authentication changes. Existing physical-
device commands need the flag; refresh vendored tooling when upgrading.

## Decisions and why

Security first: bind 127.0.0.1 by default rather than leaving the server reachable
on every interface after selecting an emulator target. Permit only exact
10.0.2.2, 127.0.0.1 and case-insensitive localhost without LAN opt-in. Other
hostnames require it even when their current DNS answer is loopback: resolving
then trusting a name would create a grant that outlives the answer checked.
Conservative aliases such as numeric shorthand need opt-in; malformed hosts
remain rejected even with consent. No DNS lookup or dependency was added.

Explicit LAN mode binds 0.0.0.0 and prints the selected origin and named risks
before spawning the script. The flag is valid only for dev. The package script
is trusted local code and can ignore runner arguments; this does not sandbox it.
A direct Flutter define remains an explicit trust grant, with no added runtime
LAN permission. The flag supplies neither transport integrity nor authentication.
Keep an isolated development network, separate app id and test data.

No change to canonical verification, nonce injection, navigation/CSP, strict
decoding, atomic state, key handling, account transitions, data access rules,
compile-time release exclusion, schema numbers or package release versions.
The CLI, spec, workflow/template guidance, changelogs, package README, vendored
example CLI and both development guides agree. The site CLI reference includes
the new flag. Codegen output and signed example assets remain unchanged.

## Regression evidence

The old packages devPlan accepted 192.168.1.20 without consent, bound 0.0.0.0
and exposed no named LAN warning. Focused regressions now pass. The real CLI
through bin/valence.mjs refuses that target before its child can create a
launch marker. A harmless npm child records the actual arguments: default
127.0.0.1, explicit LAN 0.0.0.0. The flag also passes before the dev command.
Tests cover host lookalikes, other hostnames, emulator/local targets, malformed
hosts, unsafe ports, unchanged package files and missing dev scripts.

## Gates

| Check | Result |
|---|---|
| Root npm test | 89 passed, zero failed/skipped; generated Dart and strict TS ran |
| Runtime flutter test | 494 passed |
| Runtime fatal-info Dart analysis | No issues |
| Example flutter test | 24 passed |
| Define-enabled dev tests | 8 passed |
| Bridge tests | 29 passed |
| Bridge strict/verbatim TS and pack dry run | Passed |
| Generated example strict/verbatim TS | Passed |
| Source/vendored codegen --check | Fresh, no writes |
| Built-in signature and CAS verification | Passed, seq 1793062826, two files |
| Pub publish dry run | Zero warnings |
| Site build and SEO checks | 37 pages passed |
| Debug/release APK and release exclusion | Both built; signed bytes match source; dev sentinel/proxy absent from all 3 release AOT libraries |
| Diff whitespace checks | Clean |

Android builds emitted existing plugin Kotlin migration notices; both completed.

## Review and limits

Local security checklist review against contracts 3.1, 4.2 and the R21 matrix:
no off-device origin is silently local; consent precedes spawn; warnings name
LAN mode and privileges; only validated numeric ports/fixed options enter the
Windows npm shell command. Device host text enters only the printed Flutter
command and retains its restricted hostname grammar. Source/vendored copies
match. No confirmed defect remains in this review; independent acceptance
belongs to the improver.

Both app findings were read-only inputs, with Kundalini iteration 12 and app-a
iteration 11. No test-app, snapshot or other worktree was modified. No new
emulator or physical-LAN HMR run; the process regression uses a harmless
argument-recording npm child. Runtime proxy coverage is separate from a
network attacker simulation. Android builds are compilation evidence. iOS
remains experimental and untested. Nothing was pushed or published.
