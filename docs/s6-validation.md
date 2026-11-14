# S6 validation: the host-managed cookie jar (contracts §4.5.1)

**Date:** 2026-11-02. **Branch:** `packages`. **Commits:** `e14f2b6` (feature), `81e55b9` (README,
SKILL, changelogs), `17148e3` (adapter, example, this record), plus the review fixes below; site
`42bde41`. **Finding closed:** K F-66 (major).

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

## The reviewer pass

An independent `valence-reviewer` pass over the new write path returned **no critical and no high**
finding, and confirmed the core property with file-and-line evidence: every path that can emit a
`Cookie` header or the mirror sits inside the exact-origin gate, redirects are still unfollowed,
`Set-Cookie` is stripped unconditionally, the key is unreadable through `secure.get`, `E_PENDING` is
raised before the clear so a refused switch moves no cookie, Dart's `Uri.origin` and Node's
`URL.origin` normalise identically (so a case or `:443` difference cannot split the two comparisons),
and the CLI's host-header list is set-for-set identical to the package's today. It also checked
something that looks like a bug and is not: `copyWith` has no `cookieJar` parameter, so
`cookieJar: cookieJar` reads the field and preserves the jar.

**Two MEDIUMs, both real, both fixed.**

1. **A failed Keystore delete during a sign-out was not durable.** The clear ran *after* the token
   writes, so a delete that failed left the token gone and the cookies on disk under a matching origin.
   The next launch restored them, and the next sign-in — an adoption, because the recorded id went with
   the token — would have carried the previous user's session under the new user's bearer. Fixed by
   clearing **before** the token writes on both the sign-out and the switch path, which is the order
   §5.3 already prescribes for rows, for the reason it already states: the failure between two steps has
   to be the recoverable one. A sign-out now fails with the user still signed in, holding their own
   cookies.
2. **The jar origin had no runtime validation,** while the CSRF header deliberately had a runtime
   backstop — so a hand-written `ValenceConfig` got the cleartext credential replay `codegen` refuses,
   or a silently dead jar from a mixed-case origin. `ValenceCookies` now applies the same three rules
   itself and seals rather than throwing, since a misconfigured jar is not a reason an app cannot start.

**Eight LOWs, all fixed.** `csrfValue` was not path-matched, so the mirror could go to a path the cookie
was scoped away from. A natural expiry left the credential at rest until the next `Set-Cookie` happened
along. The post-token header-limit refusal named a total that included the bearer token and the jar,
which a page could binary-search. The reload from storage enforced none of the caps and treated an
envelope with no recorded origin as this build's. The load was memoized as a flag set before its await,
so two concurrent first calls could race. `Secure` was parsed and discarded, which matters precisely
because the loopback carve-out is cleartext. §4.5.1 claimed "every path that clears the bearer token"
when §4.4 is explicit that an empty-string token is not a sign-out. And the site guide's "`Path` is
matched as a browser matches it" overstated a jar that holds one cookie per name, not one per name and
path.

The last LOW listed five behaviours the §8 row claimed and no test covered: the 8-KiB total cap and its
replacement arithmetic, `Set-Cookie` stripping with a jar actually configured, the `doctor` row, and
`headersSplitValues` against a real multi-header response. All are now tested — the last through a real
loopback `HttpServer` with a comma inside an `Expires` date, which is the case that splitter can get
wrong, and which needed `HttpOverrides.global = null` because the test binding answers 400 without a
socket. The reviewer also observed that the adapter and example half of S6 was uncommitted while it ran;
that is commit `17148e3`, made before the review returned.

## Gates

Root: **113** tests, zero skips (the generated-Dart and generated-TS compile tests ran, not skipped).
`packages/valence`: **603** tests (30 new), clean `dart analyze --fatal-infos`.
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
- **A re-run after the review fixes.** The device table above was taken on the tree as of `17148e3`,
  before the two MEDIUMs were fixed. What it shows is unaffected — the clear happened on both paths,
  and the fix changed only its order relative to the token writes — but no device run exercised the
  fixed order, and the emulator lock was released before the review returned. The reordering is covered
  by `runtime_test.dart` and by 603 passing core tests, not by a device.
- **Multiple `Set-Cookie` headers in one response** on a device. Covered by a real loopback
  `HttpServer` in `cookies_test.dart`, with the awkward `Expires` comma; the adapter sets one, so the
  device run exercised the single-header path.
