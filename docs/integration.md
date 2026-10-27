# Integration validation - 2026-10-27

## In plain terms

The nine finished feature branches now run together on `codex/integration` in
both repositories. Account-safe task restoration, accessibility, deep links,
permissions, local reminders, push, live development, native plugins and image
sharing share one generated bridge. This is a local integration candidate for
review; `packages` and the test-app snapshots were not changed.

Code base: `e879260366282c9f504057423d54f682dcb10c81`.
Site base: `f59fbc1568c895d4cd35d385733175397beeef6a`.
Tested implementation: code `a49a529`, site `ac08d67`.

## Merge order and source commits

| Order | Branch | Code source | Code merge | Site source | Site merge |
|---|---|---|---|---|---|
| 1 | codex/r8 | 003215c | 6bd072b | 2959842 | 4c5d462 |
| 2 | codex/r7 | 969b1a4 | 972c39d | 965b8eb | c008513 |
| 3 | codex/r6 | 5b64e06 | 6d3af32 | 388cd9d | e6cf7c6 |
| 4 | codex/r3 | db669dd | 0cb6363 | f45ccf2 | 4ed48c0 |
| 5 | codex/r4 | 588f876 | 1404594 | d8e5dd7 | aaee33e |
| 6 | codex/r5 | 3cc1c0f | dd80dd3 | 57a44b5 | e3d2b40 |
| 7 | codex/r9 | 0c1b0fb | 01a89c0 | 2913b4d | cbf19d1 |
| 8 | codex/r10 | f3fcd0d | 90b40dc | b905b74 | 06d431f |
| 9 | codex/r14 | fa6e16c | bfa4153 | fa5e816 | 8e66a80 |

The combined template/example report schema **14**. Appearance stays since 7;
state since 8; links since 9; permissions since 10; reminders/badges since 11;
push since 12; account support since 13; image sharing since 14. R9/R10 add no
base-schema surface. The example's genuine schema-1 store baseline stays intact.
No package release versions changed.

## Conflict decisions

Security takes precedence over convenience. Preserve R7's serialized account
operations and fail-closed secure-write sequence: clear writable rows under the
sync lease, delete the old token, record the new identity, invalidate restoration,
then store the new token. Keep R8's owning Flutter view when attaching the widget,
R3's detach-based permission denial and R4's queued notification flush.

Preserve app-owned notification methods below since 11, push methods below 12,
and image sharing below 14. Plugin delegation still runs after nonce and strict
parameter decoding. Combined review found that the new `share` namespace was
missing from plugin reservations: a plugin could claim `share.image` yet generated
code would call the core implementation. Both registries now reserve `share`;
CLI and runtime regressions cover refusal.

Move the example's haptic declaration entirely into R10's plugin fragment, retaining
its since-1 shape. Merge config allowlists and all event handlers, regenerate the
bridge, synchronize the example CLI, and sign the combined example rather than
choosing one branch's generated files. Fix branch-local test assumptions about
schema 13 and startup call order without removing their assertions. Give the
colliding contract sections unique numbers: accessibility 4.7, restoration 4.8,
permissions 4.9, plugins 4.10 and sharing 4.11; update active documentation links.

## Gates

| Gate | Result |
|---|---|
| Root `npm test` | 85 passed, zero failed/skipped; generated Dart and strict TypeScript ran |
| Runtime `flutter test` | 489 passed |
| Define-enabled dev proxy suite | 7 passed |
| Runtime `dart analyze --fatal-infos .` | No issues, including example/plugin |
| Example `flutter test` | 24 passed |
| Bridge tests | 29 passed |
| Bridge strict/verbatim TypeScript, build, pack dry run | Passed |
| Generated example strict/verbatim TypeScript | Passed |
| Example source and vendored `codegen --check` | Fresh |
| Signed example verification | Passed; seq 1793062826, two files |
| Runtime pub publish dry run | Zero warnings |
| Site build and SEO/link checks | 37 pages passed |
| Debug/release APK and release exclusion | Both built; manifests match signed source; dev URL/proxy strings absent from all 3 release AOT libraries |

Android builds emitted existing KGP compatibility warnings for app_badge_plus and
firebase_core plus deprecation notes; these did not fail either build. No dependency
versions were changed to suppress them. The release APK is 51,455,784 bytes.

Independent security review rechecked the combined account/restoration/widget,
permission, appearance, notification and development guards plus legacy and
plugin dispatch. No confirmed behavioral defect remains after the namespace fix.
Focused review checks passed (runtime subsets 10 and 4, account/widget regression
1, generator subset 7 and updated namespace regression 1). One additional reviewer
Flutter launch failed before execution because Windows held sqlite3.dll open;
the full runtime gate and subsequent define-enabled tests passed separately.

## Evidence limits

Read both complete app findings and newest reports read-only: Kundalini iteration
11 and app-a iteration 10. App-a F-32 still describes a mismatched supplied
CLI/bridge snapshot pair; these local generated-code gates do not prove those
snapshots were repackaged. R17's returned-field additions remain separate work.

No new emulator session. Earlier individual-branch Android evidence is historical;
the integrated device acceptance matrix has not run. Push delivery still needs
the maintainer's Firebase project. iOS remains experimental and untested.
No pushes, publications, shared-branch merges or writes to test-app repositories.
