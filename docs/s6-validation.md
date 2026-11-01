# S6 validation: the host-managed cookie jar (contracts §4.5.1)

**Date:** 2026-11-02. **Branch:** `packages`. **Commits:** `e14f2b6` (feature), `81e55b9` (README,
SKILL, changelogs), site `42bde41`. **Finding closed:** K F-66 (major).

## What was being checked

A cookie jar is a credential store, so the properties worth proving are not "does it send a cookie" but
these: that the page cannot see, set or redirect one; that the pair the jar exists to complete actually
completes against a server that refuses every other combination; that the jar goes when the token goes;
and that the parts a fake secure-storage platform cannot speak for — a real Android Keystore round-trip,
and real `package:http` splitting multiple `Set-Cookie` headers — work on a device.

## The server it was checked against

`examples/rest-sync-adapter/server.mjs` gained the double-submit shape, because the jar needed something
real to be wrong against. `GET /csrf` issues `csrftoken=<16 random bytes>; Path=/; Max-Age=600; HttpOnly`;
`POST /csrf/echo` accepts only an `X-CSRFToken` that matches that cookie, compared in constant time, and
answers `403` to every other combination. Both routes stay behind the adapter's bearer gate. The refusals
are unit-tested in `server.test.mjs`: no cookie, no header, either half alone, a wrong header against a
right cookie, and a right value against no cookie — five refusals and one acceptance. **That is what makes
a `200 {"accepted": true}` below evidence rather than an observation:** the only way to get it is for the
host to have sent both halves, matching.

## On the device

Emulator `emulator-5554` (lock held as `builder`, released after). Debug APK of
`packages/valence/example`, built in 144.6 s, installed with `adb install -r`, serving built-in bundle
**1793567181**. The example's `http.cookieJar` grants `http://127.0.0.1:8787` with the
`csrftoken`/`X-CSRFToken` pair — loopback is the one cleartext origin a jar may name, which is why the
demo can use it at all.

The adapter ran on host port **8789** with `adb reverse tcp:8787 tcp:8789`, because another test app held
host 8787. The device still spoke to `127.0.0.1:8787`, so the compiled origin was exercised unchanged.
The tunnel was restored to `tcp:8787 tcp:8787` afterwards.

The page was driven over the WebView devtools protocol (`webview_devtools_remote_<pid>`, available
because this is a debug build) rather than by tapping, so each step's result could be read exactly.

| What | Result |
|---|---|
| `document.cookie`, as the page sees it | `""` |
| `Set-Cookie` in the headers `http.request` returned to the page | **absent** (`setCookieVisibleToPage: false`) |
| `GET /csrf` then `POST /csrf/echo`, page sending neither half | **200 `{"accepted":true}`** — the host completed the pair |
| `POST` again with no new `GET` | **200** — the jar holds the cookie across requests |
| Page supplies `X-CSRFToken` itself | **`E_DENIED: header is controlled by the host`** |
| The pair still completes after that refusal | **200** |
| Sign out (`auth.setToken(null)`, **no account ever recorded**, so no row is cleared), sign back in, `POST` with no `GET` | **403** — the jar was cleared with the token |
| `GET`, `POST` (200), then an account switch `device-a` → `device-b`, then `POST` with no `GET` | **403** — the §5.3 switch cleared it |
| Force-stop, cold relaunch (new pid), `POST` with no `GET` | **200** — the expiring cookie survived a real Keystore round-trip |

The sign-out row is the one worth naming twice: this app had never passed `account`, so that sign-out
clears no rows at all. The jar still went, which is the behaviour §4.5.1 asks for and the one an
implementation that only hooked the account switch would have missed.

## Gates

Root: **111** tests, zero skips (the generated-Dart and generated-TS compile tests ran, not skipped).
`packages/valence`: **593** tests (20 new), clean `dart analyze --fatal-infos`.
`packages/bridge`: 29 tests. `packages/valence/example`: 29 tests, clean analyzer, `doctor` prints the
new `cookie jar` row with the configured origin and pair. Reference adapter: 2 tests.
Site: 45-page build with `check-seo` passing, including the new in-page anchor the accounts guide links to.

## Not claimed

- **iOS**, as everywhere else here: the code path is shared and unverified, with no Apple hardware.
- **A session cookie's device behaviour.** The adapter always sets `Max-Age=600`, so the device run
  exercised the persistent path. That a cookie with no expiry never reaches secure storage and is gone
  after a restart is covered by `cookies_test.dart`, not by a device.
- **A real HTTPS origin.** The device run used the loopback carve-out. The HTTPS requirement is enforced
  at `codegen`, which the CLI test covers; no remote TLS endpoint was exercised.
- **Multiple `Set-Cookie` headers in one response.** The adapter sets one. `headersSplitValues` is what
  splits them, and its lookahead (`,` followed by a cookie-name token) is exercised only in unit tests.
