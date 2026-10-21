# R11: native HTTP and an existing REST backend

Validated on 2026-10-21, on `codex/r11`, against `packages` at `46f4f35`.
Package implementation: `f511a08`, example: `ca14ed8`, documentation: `e07670e`.
Website: `38daccb` on the matching branch in `valence-site-codex`.

## In plain terms

A page can now ask its Flutter host to call the app's API, using the token already
stored by login. The host permits only API origins compiled into that store build,
so an over-the-air page cannot authorize a new destination. Existing REST APIs
still need translation for offline SQLite sync; the runnable Node example shows
that translation, including deletes, durable cursors and retry-safe writes.

## Gates

| Check | Result |
|---|---|
| `npm test` | 51 passed, zero skipped; generated Dart compiled and ran against Flutter |
| `flutter test --reporter expanded` in `packages/valence` | 316 passed |
| `dart analyze --fatal-infos .` in `packages/valence` | No issues, including the example |
| Bridge `node --test test/*.test.ts` | 18 passed |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Example `flutter test --reporter expanded` | 13 passed |
| Example `flutter build apk --debug` | Passed |
| Example `codegen --check` | No generated changes |
| `flutter pub publish --dry-run` after committing | Zero warnings |
| Site `npm run build` | 24 pages; SEO checks passed |

## Android check

Took and released the `codex-builder` emulator lock. Installed the example's
debug APK on `valence_test` (API 36), without modifying either test app.
The signed built-in at seq `1792591466` opened with bridge version 4 and the
seed's Boston fern record. The actual WebView dispatcher then:

- stored a local test token through `auth.setToken`;
- called the loopback-only reference adapter at `http://10.0.2.2:8787/rpc`,
  receiving HTTP 200 and `{native: true, authenticated: true}` without CORS headers;
- rejected an unlisted origin and page-supplied Authorization with `E_DENIED`;
- received HTTP 401 after replacing the token, observed exactly one `auth.expired`
  event and confirmed the token was retained;
- exercised the example's HTTP button and verified its displayed HTTP 200 result;
- cleared the test token at the end.

Stopped the owned adapter and example, removed the debug forward and released the
lock. iOS is experimental and untested. Redirect and byte-limit checks ran in the
package tests, including a real redirect target that received zero requests.

## Review and limits

Independent security review covered the compiled origin policy, token precedence,
header controls, redirect refusal, strict decoding, deadline and response limits.
It found a 200-operation adapter limit that would permanently reject larger
outboxes. The limit was removed within the existing 1 MiB request cap; a regression
now sends 601 writes and retries them without repeating upstream writes. The
follow-up review found no remaining confirmed security defects.

The example adapter serves one identity and assumes authoritative complete REST
snapshots and upstream idempotency keys. Requests and snapshots are limited to
1 MiB. Production requires tenant isolation, authorization, TLS and an explicit
workload/retention policy. Native HTTP is bounded text RPC and does not queue or
provide offline access. Adding a method or allowed origin requires a store build.

Both apps' findings and newest iteration reports were consulted: Kundalini's
iteration 9 and app-b's iteration 2. Their pagination, cache and lifecycle findings
remain separate concerns; this branch does not claim to resolve all app findings.
Package version numbers were left unchanged. Nothing was pushed or published.
