# R9 queue refresh - 2026-10-27

Branch: `codex/r9` in both worktrees. Package base: `e879260366282c9f504057423d54f682dcb10c81`;
site base: `f59fbc1568c895d4cd35d385733175397beeef6a`. Merge commits: package `1403eac`,
site `37c3928`. Development documentation follow-ups: package `71226b1`, site `2913b4d`.

## In plain terms

Live development now includes upstream account isolation, event capability metadata, mechanical
doctor checks and real host-widget tests. The generated bridge and installed bridge package
must be compatible before HMR starts; both development guides now say to regenerate and type-check
after upgrades. This responds to app-a F-32 without claiming the harness snapshots were replaced.

## Decisions and review

- Security first: retain all compile-time development exclusions, signature/floor/bad checks,
  nonce and navigation restrictions, strict decoding and activation evidence. No R9 API surface
  was added, so no new schema number or `since` value is needed.
- Preserve upstream template/example schema 13 and `auth.account` since 13. Lowering these to the
  branch's former schema 6 would invalidate upstream account behavior. The roadmap reserves no
  R9-specific number. Preserve the genuine recorded store baseline at schema 1; do not ship this
  intermediate schema-13 host before the earlier reserved surfaces are integrated.
- Merge conflicts retained both doctor and live-development agent instructions, and retained the
  corrected capability-gating advice alongside the development summary in the site's machine index.
- Independent `valence-reviewer` review found no R9-specific confirmed security defect, including
  the merged host-widget interactions and final documentation changes.
- **Inherited HIGH; merge R7 first.** Upstream R13 stores a new token before its identity. If the
  identity write fails, sync can populate the new account's rows under the old recorded identity;
  signing back into that identity can retain the wrong rows/outbox. R9 does not change these auth
  methods; development keeps ordinary sync and bridge access, without a confirmed new amplification.
  R7 contains serialized fail-closed writes: clear the old token, persist the identity, then store
  the new token under the lease. Preserve that implementation when merging R9 and rerun the combined
  auth regression tests and gates. This branch alone is not the account-switch fix.

Read both complete app findings and newest reports, read-only: Kundalini iteration 11 (2026-10-23),
app-a iteration 9 (2026-10-26). Their device observations and unresolved snapshot compatibility remain
separate from this framework refresh. No test-app files or other builders' worktrees were changed.

## Fresh gates

| Check | Result |
|---|---|
| Root `npm test` | 68 passed, zero failed/skipped; generated Dart and TypeScript exercised |
| Runtime `flutter test` | 409 passed |
| Runtime `dart analyze --fatal-infos .` | No issues |
| `test/dev_test.dart` with compile-time dev URL | 7 passed; real host reserved routes and HMR transport included |
| Bridge tests | 21 passed |
| Bridge strict TypeScript, build and pack dry run | Passed |
| Development demo strict TypeScript | Passed |
| Example tests | 16 passed |
| Example `codegen --check` | No writes |
| Built-in signature/file verification | Passed, seq 1792704817, one file |
| Debug APK with dev define | Built; embedded manifest matches current signed source |
| Release APK with sentinel dev define | Built, 47.4 MB; embedded manifest matches current signed source |
| Release AOT exclusion checker | Passed for all 3 AOT libraries |
| Runtime publish dry run | Zero warnings from clean commit 71226b1 |
| Site build and SEO checks | 29 pages passed, including final documentation change |

The release build used
`--dart-define=VALENCE_DEV_URL=http://valence-dev-release-sentinel.invalid:5173`.
`node packages/valence/tool/check-release-dev.mjs` checked the resulting APK against that
exact URL and implementation-specific proxy markers. The first publish dry run saw the pending
example README edit and failed with one dirty-worktree warning; the clean-commit rerun passed
with zero warnings. No failing gate remains.

No new emulator run. The 2026-10-21 HMR device evidence below is historical. React Fast Refresh
and a profile APK were not separately exercised. iOS remains experimental and untested.
Exactly one queue item refreshed. Package versions did not change. Nothing was pushed or published,
and no merge or commit was made to a shared branch.

---

# R9 queue refresh - 2026-10-22

Branch: `codex/r9` in both worktrees. Merged package `packages`
`c55446f3d73afec7672c2615b0ffe70f1a6a074d` and site `packages`
`5a23a4eaf3dc1fdacfb1f961dadbd33b5ed1d390`.

## Decision and scope

Retain the newest shared migration, paging, sync and lifecycle behavior. Security comes first:
the explicit debug define still selects only a signature-verified installed manifest above the
floor and outside the bad set; development preserves pending, trial and failure records.
Normal release activation and strict bridge decoding remain unchanged. User data stays on the
shared database adoption and bounded paging paths rather than carrying branch-local copies.
R9 adds no bridge methods or parameters: both template and example schemas remain version 6,
with the existing since values intact. No new schema reservation is needed.

The site index conflict retained both the development guide and the incoming database,
paging and lifecycle documentation. No package version numbers changed.

Inputs reviewed: Kundalini's VALENCE_FINDINGS.md and ITERATION_10_REPORT.md, and app-a's
VALENCE_FINDINGS.md and ITERATION_8_REPORT.md. Their migration/data and authentication findings
remain distinct from this development-server queue refresh. Neither test app was modified.

Independent security review against the merged branch found no confirmed defects. It traced
compile-time exclusion, signed context and floor/bad checks, activation-record preservation,
reserved route order, nonce/navigation/frame/worker restrictions, strict decoding, credentials,
redirects and child-process shutdown. The reviewer ran the focused CLI test, bridge tests and
example codegen check.

## Fresh gates

| Check | Result |
|---|---|
| Root `npm test` | 61 passed; zero skipped; generated Dart compiled and ran |
| Runtime `flutter test` | 390 passed |
| Runtime `dart analyze --fatal-infos .` | No issues |
| Define-enabled proxy `flutter test` | 7 passed |
| Bridge tests / strict TypeScript | 18 passed / clean |
| Bridge `npm pack --dry-run` | Passed |
| Development demo strict TypeScript | Passed |
| Example tests / `codegen --check` | 16 passed / no writes |
| Debug APK with dev define | Built successfully |
| Release APK with sentinel dev define / AOT exclusion scan | Built (47.3 MB); all 3 AOT libraries passed exclusion |
| Site `npm run build` | 27 pages; SEO checks passed |
| Runtime `flutter pub publish --dry-run` | 0 warnings from clean commit `3c9c20c` |

The release gate built the current merged source with
`--dart-define=VALENCE_DEV_URL=http://valence-dev-release-sentinel.invalid:5173`.
`node packages/valence/tool/check-release-dev.mjs` scanned the resulting APK and reported
`Release exclusion passed for 3 AOT libraries`. The debug and release builds took 403.7 s
and 953.9 s respectively under this host's load; these are build timings, not app benchmarks.
No failing gates remain. No push, publication or merge into a shared branch occurred.

Fresh Android device checks were optional and skipped for this refresh. The 2026-10-21 device
results below are historical, not a claim that HMR was re-exercised after this merge. iOS remains
experimental and untested; React Fast Refresh and a profile APK were not separately exercised.

---

# R9 validation - 2026-10-21

Branch: `codex/r9` in the package and site worktrees. Base: package `406d153` on `packages`.
No version numbers, test-app files or other builders' worktrees were changed.

## In plain terms

Run the web dev server, launch a debug Flutter host with its URL, and edit the page while it
keeps native bridge access. Vite HMR uses the owned loopback origin and retains page state.
Profile and release builds remove the proxy even when given the same URL define.

The runner uses npm with Vite-compatible arguments. Other dev servers can be started manually.
A verified installed bundle supplies schema context; no new bridge IDL or generated-code shape
is needed. Native code, schema and compiled-origin changes still need codegen and a host rebuild.

## Gates

| Check | Result |
|---|---|
| Root `npm test` | 57 passed, zero skipped; generated Dart compiled and ran with Flutter |
| Runtime `flutter test` | 349 passed |
| Runtime `dart analyze --fatal-infos .` | No issues |
| Define-enabled `flutter test --dart-define=VALENCE_DEV_URL=http://127.0.0.1:55173 test/dev_test.dart` | 7 passed |
| Bridge `node --test test/*.test.ts` | 18 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Demo `npx -y -p typescript tsc -p packages/valence/example/dev-web/tsconfig.json --strict` | Passed |
| Example `flutter test` | 14 passed |
| Example `codegen --check` | No writes |
| Example debug APK with dev define | Built |
| Example release APK with sentinel dev define | Built; all 3 AOT libraries passed exclusion scan |
| Site `npm run build` | 26 pages; SEO checks passed |
| Runtime `flutter pub publish --dry-run` | Passed with 0 warnings from a clean package commit |

An earlier publish dry run reported only the dirty-git warning while implementation was
uncommitted. The clean-commit repeat passed with 0 warnings.

## Release exclusion regression

From `packages/valence/example`:

```sh
flutter build apk --release --dart-define=VALENCE_DEV_URL=http://valence-dev-release-sentinel.invalid:5173
```

From the repository root:

```sh
node packages/valence/tool/check-release-dev.mjs packages/valence/example/build/app/outputs/flutter-apk/app-release.apk http://valence-dev-release-sentinel.invalid:5173
```

The checker requires actual `libapp.so` AOT libraries and decompresses each ABI's library from
the APK. It rejects the supplied URL and two implementation-specific proxy error strings.
Result: `Release exclusion passed for 3 AOT libraries`. Compile-time `kDebugMode` guards also
exclude the path in profile builds; a profile APK was not separately built.

## Android device evidence

The shared `valence_test` emulator was locked as `codex-builder`, ensured ready and used only
for `com.getvalence.valence_example`. No test app was installed, cleared or edited.
The final APK repeated the HMR/native-write result. The example and dev server were stopped,
the teaching message was restored, and the emulator lock was released before handoff.

The example ran against Vite 8.3.4 on the computer at port 5173, reached through `10.0.2.2`.
The WebView stayed at its owned `http://127.0.0.1:14757/` origin. Its log recorded:

```text
[vite] connected.
R9 bridge=4
R9 counter=1
[vite] hot updated: /message.js via /main.ts
R9 HMR counter=1; native prefs write succeeded
```

The counter was incremented with an Android tap before editing `message.js`; the edit updated
the label and retained the counter. The accepted callback wrote a JSON string through the
generated `prefs.set` method. An earlier demo passed an object and was correctly rejected with
`E_PARAMS`; the demo now serializes it and has a strict TypeScript gate. That rejection was a
demo mistake, not a relaxed decoder. Vite HMR is exercised here; React Fast Refresh was not
separately exercised. Signed offline/rollback behavior remains covered by existing gates and
must be tested without the dev define.

## Security review

Independent review checked compile-time exclusion, nonce injection, navigation and frame
restrictions, worker CSP, reserved routes, token isolation, redirect denials, process cleanup
and preservation of OTA activation records. Two findings were fixed and regression-tested:

- Preserve the original HTML doctype when injecting the nonce, avoiding quirks mode.
- Enforce the persisted floor at canonical check 4 for development schema context, exclude
  `bad` candidates and preserve pending/trial/failure evidence on refusal or fallback.

The final review reported no remaining confirmed findings. No security verification step was
removed. Public signed-bundle serving retains its existing behavior. iOS remains experimental
and untested; no Apple device execution is claimed.
