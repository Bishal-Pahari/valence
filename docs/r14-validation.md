# R14 validation - 2026-10-27 refresh

## Current refresh

Merged code `packages` e879260366282c9f504057423d54f682dcb10c81 and site
`packages` f59fbc1568c895d4cd35d385733175397beeef6a into `codex/r14`
(merge commits 42c048d and fa5e816). Preserve schema 14/share.image since 14
and upstream auth.account since 13. Keep the real schema-1 store baseline;
integrate the earlier reserved surfaces before distributing this host.

Resolved source conflicts by retaining account and image-sharing declarations,
regenerated both bridge outputs, synchronized the example's vendored CLI, and
rebuilt the signed example bundle (seq 1793062168, two files). The stale vendored
CLI would otherwise regenerate a custom handler instead of the sharing built-in.
Package versions remain unchanged.

Fresh gates: root 67 tests, zero skipped (generated Dart and TypeScript exercised);
runtime 412 tests; example 17 tests; bridge 21 tests; clean fatal-info Dart
analysis; strict/verbatim bridge and generated TypeScript; bridge build/pack dry
run; clean example codegen; signed bundle verification; zero-warning pub dry run;
29-page site build with SEO/link checks; debug APK built and its embedded manifest
matched the signed source.

Independent review found no R14 defect and separately ran 13 sharing tests,
one generated-dispatch/platform-marshalling test, one compatibility/codegen test,
codegen freshness and signature/file verification. Inherited risk: upstream's
account switch can persist a token before its identity on a secure-write failure.
Merge R7 first and retain its serialized fail-closed account writes during integration.

Both full app findings and newest reports were read read-only: Kundalini iteration
11 and app-a iteration 10. Preserve Kundalini's custom since-3 sharing shape.
App-a F-32 still reproduces in its supplied snapshot pair; this branch's compiling
generated bridge does not prove that the harness snapshots were replaced.
No new emulator check; the Android evidence below is historical. iOS remains
experimental and untested.

## Historical validation - 2026-10-22

In plain terms: the page can share a small PNG/JPEG it renders, or an image already
in its signed bundle, with a caption. The host validates the input and opens native
sharing. The result reports dismissal, target selection or an unavailable outcome,
never delivery. Earlier custom sharing handlers retain their shipped contracts.

## Branch and decisions

Both worktrees use `codex/r14`, based on package `c55446f` and site `5a23a4e`.
The rebase queue was already current on those bases. R14 reserves schema 14 in its
own roadmap Status cell; the shared version table and other items were untouched.
The earlier queued branches must merge first so the schema remains contiguous.
Package versions were not changed.

Security first: accept only canonical base64 up to 128 KiB decoded, or an exact
key in the active verified manifest up to 5 MiB. Never join a web path to a native
directory. Recheck CAS size/hash at use, then share a copy. Validate PNG/JPEG magic,
plain filenames and caption byte length. Strict generated dispatch and nonce checks
remain in place. Native errors expose neither paths nor payloads. Only one share
is active at once. The host wipes its fixed input scratch child before each valid share and refuses a
scratch-directory symlink. Native plugin copies may remain in the OS-managed cache;
the API does not promise immediate erasure or successful delivery.

Data safety: no database, token, sync or updater behavior changed. The Android
example upgraded in place and retained its existing queued note. Developer
compatibility: pre-14 custom `share.image` declarations still generate their own
handlers, even when the overall schema version rises. Only `since >= 14` selects
the package built-in. This avoids breaking Kundalini's existing method.

Inputs read: Kundalini's findings and iteration 10 report, and app-a/Fernwise's
findings and iteration 8 report. Their migration/data, pagination, authentication
and startup observations informed the boundary; neither app repo was written.

## Gates

| Gate | Result |
|---|---|
| Root `npm test` | 60 passed, 0 failed, 0 skipped; generated Dart and strict generated TypeScript exercised |
| Runtime `flutter test` | 393 passed, including 13 new image-sharing tests |
| Runtime `dart analyze --fatal-infos .` | No issues across package and example |
| Example `flutter test` | 17 passed, including strict image dispatch, nonce denial and real plugin marshalling |
| Bridge `node --test test/*.test.ts` | 18 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed; schema-14 generated example also passed strict/verbatim TypeScript |
| Bridge `npm pack --dry-run` | Passed |
| Site `npm run build` | 27 pages; SEO/link/anchor checks passed |
| Example `codegen --check` | No writes |
| Signed example `verify --files` | Passed, seq 1792678913, two files |
| Example `flutter build apk --debug` | Passed |
| Runtime `flutter pub publish --dry-run` | Zero warnings after implementation commit |

Initial checks caught malformed-base64 error mapping, an obsolete test fixture's
hardcoded out-of-range version, and one lint. All were fixed before the passing
full gates. The first pub dry run warned about the uncommitted bundle replacement;
the clean committed implementation passed with zero warnings.

## Android device evidence

Shared `codex-builder` lock acquired and released for both the initial run and final
scratch-cleanup rerun; emulator-5554, API 36. Installed
the debug example with `adb install -r`, without clearing its data. The page
reported bridge 14 and signed bundle 1792678913.

- Bundle image: native sheet displayed the chart thumbnail and `Valence image
  sharing` caption. [Screenshot](r14-evidence/bundle-sheet.png),
  [native hierarchy](r14-evidence/bundle-sheet.xml).
- Inline PNG: native sheet opened with the same chart thumbnail and caption.
  [Screenshot](r14-evidence/inline-sheet.png).
- Backing out of each sheet returned `dismissed (selection is not delivery)`.
- Selecting Print for the bundle image opened Android's PrintActivity and rendered
  the chart from its temporary content URI. [Preview](r14-evidence/print-target.png).
  Returning to the page reported `selected (selection is not delivery)`. No print
  job or message was sent.

The final runtime was rebuilt and reinstalled after the scratch cleanup change; both
sources, dismissal and the Print preview/selection were rechecked. The fixed scratch
child contained only `valence.png` after each share, rather than new UUID directories.

The page was driven through the debug WebView's DevTools socket. A transient ADB
daemon/forward failure recovered on retry; it was not an app failure. The temporary
49314 forward was removed, the example force-stopped, and the emulator lock released.
No emulator reset, other app mutation or external server was needed.

## Review and limits

Independent security review found no confirmed defects in limits, active-manifest
lookup, CAS verification, strict dispatch, error redaction, concurrency or legacy
handler preservation. Its focused runtime tests, focused codegen compatibility test,
source analyzer and codegen freshness check passed. A site heading encoding typo
was corrected. A final contract reconciliation added dedicated input scratch cleanup, preserving
the existing section 4.2 requirement; a regression verifies cleanup stays inside
that child and denied calls do not erase files. Related old no-inline-byte guidance was updated to name the bounded
sharing exception.

iOS remains experimental and untested. Android JPEG format routing is unit-tested;
the device run used PNG. Recipient-specific caption support and delivery are not
claimed. No pushes, publications or merges into shared branches were performed.
