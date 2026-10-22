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
