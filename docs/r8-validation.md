# R8 merge refresh - 2026-10-22

## In plain terms

The R8 branch now includes the latest lifecycle, update-status, paging and database-safety
changes from packages at c55446f3d73afec7672c2615b0ffe70f1a6a074d. Appearance is reserved at
bridge schema 7 (event since 7); version-5 paging and version-6 lifecycle remain intact.
The site branch includes its packages base 5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390;
its refreshed docs commit is 75c3971. Package merge commit: 2b77b9c.

Decision: retain the startup guard before resume update/sync work while allowing a scheduled
appearance refresh. Security/state-transition ordering takes priority over appearance delivery.
Keep optional AppInfo.fontScale for source compatibility with old generated schemas. Preserve
example custom methods; regenerate both clients and sign a new built-in rather than resolving
conflicting generated output by choosing one side. The new built-in is seq 1792638425,
requires bridge 7, and signature/file verification passes. Adaptive layout now occupies
contracts section 4.7; lifecycle remains section 4.6.

Fresh input: both apps' VALENCE_FINDINGS.md, Kundalini ITERATION_10_REPORT.md and app-a
ITERATION_7_REPORT.md. App-a's system-bar overlap informs this feature; delayed label painting
is not established as an inset bug. Test-app repositories were read only.

## Fresh gates

- Root npm test: 60 passed, 0 failed, 0 skipped; generated Dart compiled/analyzed/executed
  against a real Flutter toolchain and generated TypeScript passed strict checking.
- Runtime flutter test: 384 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 19 tests passed, strict TypeScript passed, npm pack --dry-run passed.
- Example: 17 tests passed; codegen --check wrote nothing; built-in verification passed.
- Site final npm run build: 27 pages, SEO/link checks passed.
- Example flutter build apk --debug: passed (assembleDebug 249.4 seconds).
- Flutter pub publish --dry-run: 0 warnings.

Independent valence-reviewer pass found no confirmed security/specification defects. It checked
schema/delegations, owning-view metrics, JSON-only publication, nonce/navigation/CSP retention,
resume startup integration, example and docs. It independently passed the optional-field
regression and the example codegen check.

No new emulator run was attempted for this merge refresh (optional for the rebase queue).
The device observations below are historical 2026-10-21 evidence on bridge 5, not a claim
that the combined schema-7 build was device-tested. TalkBack and true split-screen remain
unverified; iOS remains experimental and untested. No package versions changed.

---

# R8 validation — 2026-10-21

## In plain terms

The web page can keep controls clear of system bars and cutouts, follow Android's system text size,
and respond to dark mode, high contrast and reduced motion. Rotation and settings changes update the
existing document. The host supplies CSS values and native text zoom; the page supplies padding and
accessible HTML. Existing pages need the content-padding change described in [the guide](accessibility.md).

Both worktrees use `codex/r8`, created from `packages` at `406d153`. Package implementation commits:
`f88df9c`, `a93e84e`, `11979b8`, `28b718e`. Site commit: `9795cd3`.
No package versions changed. Nothing was pushed or published.

## Required gates

| Command | Result |
|---|---|
| Root `npm test` | 56 passed, 0 failed, 0 skipped; generated Dart analyzed and ran in a real Flutter project |
| `packages/valence`: `flutter test --no-pub` | 343 passed |
| `packages/valence`: `dart analyze --fatal-infos .` | No issues |
| `packages/bridge`: `node --test test/*.test.ts` | 19 passed, 0 skipped |
| `packages/bridge`: `npx -y -p typescript tsc --strict -p tsconfig.json` | Passed |
| Site: `npm run build` | 26 pages, SEO check passed |

Additional gates: example `flutter test --no-pub` (15 passed), example debug APK build,
example `codegen --check` (zero writes), bridge `npm pack --dry-run`, and Flutter
`pub publish --dry-run` (zero warnings). No iOS build or execution was attempted.

The first npm run found a doctor test that replaced the literal schema-4 version to simulate a broken
host. The schema-5 template made that replacement a no-op. It now matches the generated version
declaration independent of its number; the targeted test and the final full suite pass. A pub dry run
before commits warned about modified/deleted tracked example files; the final clean-state run has no warnings.

## Android evidence

The emulator lock was acquired as `codex-builder` and released. The final debug APK runs signed
built-in bundle **1792604523**, bridge **5**. Its page has a main landmark, a labelled token input,
48px minimum buttons, flexible text and inset padding. These checks used only the framework's own
example; neither test app repository was modified.

- Portrait: viewport 411 × 914 CSS pixels, top inset 50.2857px, bottom 24px. The heading begins at
  74.2857px (24px content padding plus top inset).
- System font size 200%: the system's nonlinear scaler evaluates 16px at **1.75×**. Both the CSS
  value and a fresh `app.info` reply report 1.75. Heading height changes from 33.5952px to 58.8036px,
  a 1.75 ratio. Native Android text zoom supplies this change; CSS does not multiply it again.
- Landscape: viewport 914 × 411, cutout inset moves to the left (50.2857px), top becomes 28.1905px.
  The page's in-memory marker remains **0.5273480429414573** through rotation and theme changes.
- A temporary `wm size 900x1600` override resizes the owning viewport to 609 × 343 in landscape;
  left inset updates to 33.5238px. This is a viewport-resize test, not a true split-screen run.
- Dark mode and disabled transition animations deliver `app.appearance` changes and update root
  attributes. Resuming preserves the marker and emits `app.resumed` without losing native bridge calls.
- Final keyboard test: Android reports `mInputShown=true` and `mIsInputViewShown=true`; viewport height
  drops from **914 to 578**, while the system-bar bottom inset remains **24px**. The labelled input
  stays visible above the IME. The keyboard closes and the viewport returns to 914px.
- Final dark and light screenshots were inspected: status icons follow the system appearance and
  the bottom navigation icon brightness is explicitly selected for both modes.

Snapshots and screenshots are in [r8-evidence](r8-evidence/). Landscape, resize and resume snapshots
come from the first signed probe (1792603719); final dark, keyboard and restored-light snapshots use
1792604523, which adds the semantic landmark/label and the final system-bar treatment.

The example was force-stopped; its existing data was retained. Device size, rotation, font size,
night mode and animation settings were restored to their prior values. Only this run's adb forward
(19388) and screenshot file were removed. No local server was started for this item.

## Review and limits

Independent review covered contracts §4.6, the JSON-only script publication, lifecycle timing,
optional AppInfo growth, generated delegations, nonce/navigation/CSP preservation, example and docs.
It found and resolved: a missing explicit edge-to-edge request, raw versus nonlinear AppInfo scaling,
and Flutter's default light navigation icons in its nominally dark overlay style. No confirmed findings
remain. A screenshot separately exposed the need to rebuild system-bar icon styling on theme changes.

The nonlinear regression supplies raw scale 2 with a 16px evaluated scale of 1.75 through an attached
test view. Other regressions cover logical insets excluding the keyboard, rotation, OS accessibility
snapshots, repeated script execution without compounded iOS scaling, typed subscriptions/unsubscribe,
and old/new generated AppInfo shapes. Overlay rendering has device evidence, rather than a fake-widget
assertion about platform behavior.

iOS is experimental and untested. Its fallback scales rem/em text from the document's original root
font size; fixed pixel fonts do not follow it. Android uses one zoom percentage, rather than a full
nonlinear size mapping. High-contrast payloads are unit-tested; the Android run reported false, so
no device high-contrast behavior is claimed. TalkBack spoken output and true split-screen were not
exercised. The accessibility guide documents semantic HTML, contrast, focus and touch-target checks
for adopters. These signals do not certify an arbitrary page as accessible.

Input context: both apps' `VALENCE_FINDINGS.md`, Kundalini's newest `ITERATION_9_REPORT.md`, and app-a's
latest standalone handoff `NEXT.md` (cycle 5), with its later F-21–F-25 findings in the findings file.
Their update/cache, sync and identity reports were read as context, without widening R8 into those fixes.
