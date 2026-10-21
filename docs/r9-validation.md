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
| Root `npm test` | 56 passed, zero skipped; generated Dart compiled and ran with Flutter |
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

The publish dry run is repeated from a clean package commit before handoff. An earlier dry run
reported only the expected dirty-git warning while implementation was uncommitted.

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
