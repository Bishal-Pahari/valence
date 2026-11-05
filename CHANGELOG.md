# Changelog

## Unreleased: a rollback that cannot serve its replacement now says so

When a release is given up on after its ready window, the host drops the trial's cached rows, refuses
the given-up page's `data.cache` writes, and loads `current` in its place. If that last step fails —
nothing left to serve, a socket it cannot bind — the refusal stays up, which is correct and was already
the behaviour. What it did not do was tell anyone: the error escaped a periodic timer as an unhandled
async error, naming neither the rollback nor the trial, and the app sat on the page that had just
failed with its cache closed and no line in the log. The host now catches it and logs
`rollback: serving current after the given-up trial <seq> failed: …`, saying that the page stays on
screen and that `data.cache` stays closed.

**Nothing an app does changes.** The same two writes are refused, the same page stays on screen, and the
same `E_DENIED` is returned. Two properties that shipped argued from the code now have a test: that the
refusal is released by the document *that swap* asked for and not by the given-up page navigating itself,
and that a swap which throws leaves the cache closed.

## Unreleased: four review findings in the same day's own work

A `valence-reviewer` pass over the four commits above found five things; four were real.

- **A pulled row with a negative `usn` is now refused by the row shape** (§5.3). The read union reports
  `usn: -2` for a cache overlay and `-1` for a pending write, and those two numbers are the only way a
  page can tell a local-only row from one the server vouched for — so a pulled row at `-2` would be a
  `kv` row indistinguishable from the page's own cache, and a retention rule written against §5.5.1
  would delete rows it does not own. The incremental path refused it already, through the
  ascending-order check; the **static** variant takes `max_usn` from the index rather than from the rows
  and had no such check. The bound now lives in the decoder, where both paths pass through it. **If you
  run a sync server, no change: a USN counts from 1 and always did.**
- **The REST cache guide's prune example used the wrong field name.** It read `row.k`, which is the
  *sync wire* row of §5.3; the `Row` your bridge returns is `{key, value, usn}`. In TypeScript it did
  not compile, and in plain JavaScript it pruned nothing and never terminated. Fixed to `row.key`.
- **"The widget store bounds key count and value length" was not true of anything.** Valence ships no
  widget store — §6.2 has the *page* build the snapshot — and the sentence was one of four examples
  supporting "every other store bounds itself". While checking it, the surrounding claim turned out to be
  an over-claim too: `prefs.set` has no cap either, so the REST cache is **not** the only unbounded
  store. Both are corrected: the cache is the one where the absence *matters*, because accumulating a row
  per fetched resource is its normal operating mode, and the stores that are bounded are now named
  accurately (`state.save` at 65,536 bytes in place of the invented one).
- **`doctor`'s `REST cache` row cannot FAIL from the CLI**, because an invalid `cache` grant is refused at
  config load before any row exists. Only a library caller reaches that branch. The §8 row said so as
  though it were user-visible behaviour, and now says which it is.

The fifth was reported as impossible sample output in the pinned-bridge warning. It is real output: an
app whose last store build recorded schema 20 declares a built-in reserved at revision 19 as `since: 21`,
because the rule is `max(reserved, baseline + 1)`. The CLI reference now says so beside the sample.

## Unreleased: tell a direct host kill apart from a renderer eviction

No behaviour change; a distinction the spec made in a clause now gets its own case, because an app
reported the wrong one.

Android has two ways of taking your process. The one §3 describes at length is the unhandled renderer
loss: lmkd kills the WebView's sandboxed process, Chromium logs that nothing handled it, and the WebView
kills your host 70 ms later. The other is a **direct** low-memory kill of the host — lmkd names *your*
package, the host's own exit-info reason is `reason=3 (LOW_MEMORY)`, and there is no Chromium
termination line at all. The two lead to different conclusions: the first is a plugin gap native code
could close, the second is the OS reclaiming a large backgrounded process, and no callback or future
shim prevents it.

Observed on a return from native Settings at 533 MB RSS, which is where it is likeliest: an excursion to
another app leaves your process backgrounded and cached, which is what lmkd picks. What you get back is
durable data always — SQLite, the secure store, `state.json`, the outbox — and the route and blob only if
the OS kept the task, because the §4.8 snapshot is best effort. Capture logcat and exit-info **before**
letting the app restart; an ordinary relaunch overwrites them.

contracts §3 and the startup-diagnostics guide.

## Unreleased: four things an app has to get right that the spec only implied

No behaviour change. Each of these cost a test app an iteration and was filed as a possible host defect
first, which is the signal that the rule existed only in somebody's head.

- **Back closes your app if a view has no history entry** (contracts §3). `canGoBack()` sees History API
  entries and nothing else, so a detail screen switched on by component state leaves the back stack
  empty, the else branch runs, and `SystemNavigator.pop()` finishes the activity — the user watches the
  app disappear from a screen that had a list behind it. Nothing in the host can warn you, because
  `onNavigationRequest` never fires for `pushState`, which is the next bullet of the same section.
- **A cold start can carry both a link and a reminder, and the last event wins — not the last `await`**
  (contracts §6.3). `link.initial` and `notify.initial` are separate mailboxes that each answer only
  "did the OS start me with one of these?", so applying them in a fixed order routes to the older
  destination whenever the user's tap was the other one. `onLink()` does the right thing inside its own
  source and cannot see the other mailbox.
- **`timing` describes one request, not the page** (contracts §6.5). Exact-alarm access can be granted or
  revoked between two calls with no reload in between, so a "may be late" warning held in page-level
  state tells a user who has just granted access that their reminders are still inexact.
- **A prerelease tarball replaced at the same path can keep its old lock integrity**, `--force`
  included, so a build can be one snapshot behind with nothing warning about it. Verify the
  `package-lock.json` entry and uninstall before reinstalling. In the 0.3 migration guide.

## Unreleased: say what bounds the REST cache, because nothing does

`data.cache` caps one value at 64 KiB and nothing else: not the number of rows, not the total bytes, not
their age. A page with a grant that never removes stale keys fills the device one value at a time, and the
user's only remedy is clearing app data — which also destroys their synced rows and their unsent writes.
That was true in 0.4 before this change and it is still true after it. What changes is that it is now
said out loud, in the place you are standing when it matters:

- **`valence doctor` has a `REST cache` row** naming your granted buckets and the ceiling that does not
  exist. It passes rather than warns — `doctor` cannot see whether your page prunes, and a warning no
  correct app can clear is a warning nobody reads.
- **The REST cache guide has a section on it** with the prune pattern that works (keep what the UI can
  still reach, write `null` for the rest, at the end of the load that filled the cache), and with the
  measurement nobody had written down: `data.list` returns `usn: -2` for exactly the cache rows, so a page
  can count its own overlay. `data.count` cannot, because it counts the merged view on purpose.
- **Contracts §5.5.1 says why this one store is shaped that way** and what the fix is: a compiled
  per-bucket `maxRows` or one `cacheMaxBytes` with the oldest write evicted first, so an app that never
  prunes degrades into a smaller cache instead of a full disk. That is **not in 0.4** — the cache table
  has no written-at column, so "oldest" does not exist yet and adding it is a database migration.

Nothing to change in your app unless you hold a cache grant, in which case: write the retention rule.
Found by the kundalini test app on its twentieth iteration, after adopting the cache for two buckets and
trying to write exactly that rule.

## Unreleased: the release warning names the events too

`valence bundle --requires-bridge <n>` warns when you pin below your schema version, because a call to a
newer method is then dead in the field. It listed only the methods. An **event** declared above the pin
needs the newer host exactly as much — the older host never emits it — and it failed more quietly: nothing
thrown, nothing logged, a subscription that simply waits for ever. A release that shipped a method and an
event together was warned about half of itself.

Both kinds are now counted and named, with what each one does on the old host:

```
warning: requires.bridge is pinned to 20, below the schema version 21, so 1 method and 1 event need a
newer host than this bundle asks for: bundle.check (throws E_UNSUPPORTED), bundle.checked (never
emitted). Gate every one of them on has(): an ungated call throws E_UNSUPPORTED on an older host, and an
ungated subscription waits for an event that never arrives, which is the failure you are least likely to
notice.
```

Nothing to change in your app: `has()` already answers for an event name, which is what makes the advice
actionable. The singular case also reads as a sentence now — it said "1 method need" and then "every call
to **them**".

## Unreleased: a busy sync can say who is holding it

`sync.status` gains two nullable returned fields at built-in **revision 20**, `leaseKind` and
`leaseAgeMs`: which run holds the §5.6 sync lease — `foreground`, `background` or `push` — and for how
long. The lease row grows a third field, `<epoch ms>:<pid>:<kind>`, appended so an older row still reads. A host older
than revision 20 reads a three-field row as live with no owner and takes it over, which is right — a
downgrade means the writer is gone — though it loses the pid; mutual exclusion is unaffected, because two
hosts of different versions can never run at once.

Until now `reason: "busy"` said a run had been refused and nothing could say by what. App-c spent four
iterations capturing the same shape — a bounded `sync.now` answering busy twenty times after a reconnect,
a WorkManager run cancelled a second in, a relaunch draining the queue first try — and every report said
the same thing about itself: it cannot identify the owning operation and does not prove a lease-expiry
violation. That is a diagnosability bug before it is a lease bug.

Both fields are null **exactly** when a run starting now would not be refused, which includes a lease the
host is about to take over: past its two-minute expiry, dated in the future, or left by a process that is
gone. A held row that records no kind reports `unknown`, never null — null means "nothing would be
refused", and conflating that with "held by something I cannot name" is the bug being fixed. `leaseKind`
is an open set; treat a value you do not recognise as "something holds it".

Gate on `(app.info().builtins ?? 0) >= 20`, declare the two fields, regenerate and ship a store build.
**They are a diagnostic, not a schedule:** a page cannot release another run's lease, and lease expiry and
takeover are deliberately unchanged by this release. [Sync
outcomes](https://getvalence.pages.dev/docs/guides/sync-outcomes/#busy-finding-out-who-is-holding-the-lease).

## Unreleased: tell two copies of the CLI apart

`valence version --build` appends a digest of the CLI file — `0.4.0-beta.0+build.54954a1846cf` — and
`doctor` opens with a `CLI build` row carrying the same pair and the path it read. The version names a
*release*, so a vendored `valence/valence.mjs` and a newer published one can report the same string while
generating different code, which is how a built-in the newer copy knows about becomes *your* method in
silence. Plain `valence version` is unchanged and still one machine-readable line. The digest is a flag,
never a gate: nothing signs or refuses on it, and what it points at is `npx create-valence update`.

## Unreleased: four fixes from two independent reviews

- **A sign-out or an account switch can no longer be undone by a response already in flight.** An
  `http.request` begun as one user could deliver its `Set-Cookie` after that user signed out, which
  refilled the cookie jar the sign-out had just emptied — in memory, and in the Keystore once
  `sessionCookieDays` was on — so the next request carried the previous user's session beside the new
  user's bearer token. Each request now carries the jar's generation and a response whose generation
  has moved on has its cookies dropped. Your page still receives the response.
- **A renderer recovery in the background no longer spends a trial's strike.** The ready window counts
  foreground time and is stopped by the pause transition, so a page loaded after the app was already
  backgrounded started a clock nothing would stop: background time then exhausted the window and
  counted a failure against a release that was never on screen. Such a page arms the window and the
  resume starts it.
- **A bundle being rolled back cannot refill the cache on its way out.** Giving up on a trial drops
  every `data.cache` overlay, but the failed page is alive through the rest of the rollback, so a
  late REST response could write its shapes straight back for the previous bundle to read. From just
  before the drop until the replacement page starts, `data.cache` answers `E_DENIED` and says why.
- **`codegen` no longer throws on a payload field named after an `Object` member.** An event declaring
  `constructor` or `toString` was accepted and then crashed the generator — and the additive-only rule
  left no way to remove the field.

## Unreleased: two confusing numbers, named properly

- **A built-in's reserved revision is not the `since` to declare,** and the docs now say so where
  `data.cache` is introduced: declare `max(18, your next schema version)`, which is what `codegen`
  computes for you. The refusal that follows a *changed* built-in now tells you to restore the
  recorded `since` instead of offering a `.v2` rename, which for a reserved name would quietly make
  you reimplement a package feature.
- **A cache-enabled bucket is still pulled.** Declaring a bucket purely to hold REST overlays makes
  the device ask your sync server for it on every sync, and a `404` there makes the whole run report
  `failed` and stops sync freshness advancing — the other buckets' rows still arrive, but your page is
  told the sync failed. Serve overlay-only buckets as an empty page. Said on the REST cache guide,
  the config reference and in the spec.

## Unreleased: response size grants

Optional compiled `http.maxBodyBytes` accepts 1..262144 decompressed response bytes (default 65536). Regenerate and ship a host for larger REST responses. Request and escaped reply limits stay unchanged; doctor reports both limits.

## Unreleased: bounded session-cookie persistence

- Native `http.cookieJar.sessionCookieDays` opts into 1–30 days for session cookies across restarts. Off by default; run codegen and rebuild the host. Deadlines never renew on reload; sign-out and account-switch clearing still apply. [Guide](https://getvalence.pages.dev/docs/guides/persistent-sessions/).

## Unreleased: debugging tools and a web app checklist

- `chrome://inspect` works in debug builds.
- `traceBridge()` in `@getvalence/bridge` lets a debug build see native requests, without params, bodies, headers or query strings.
- New docs: [Debugging](https://getvalence.pages.dev/docs/guides/debugging/) and the [Web app checklist](https://getvalence.pages.dev/docs/guides/web-app-checklist/).

## Unreleased: explicit update checks and completed-check notifications

- Schema 19 adds explicit `bundle.check` and `bundle.checked` completion, including offers needing a newer store host. Regenerate and rebuild to opt in; pending-only `bundle.updateReady` is unchanged.

## Unreleased: a cookie jar for one origin, so a CSRF-protected API is reachable

Nothing changes unless you ask for it. If you do not add `http.cookieJar`, `http.request` behaves
exactly as it did: no cookie is sent, every `Set-Cookie` is discarded, and nothing is stored.

- **A session-cookie or CSRF-protected API was unreachable, not just awkward.** `http.request`
  forbids your page from sending `Cookie` — a page that can set one for the origin the host trusts
  with your bearer token can forge one — and it kept no cookies of its own. So the default shape of a
  Django `POST` (a `csrftoken` cookie plus a matching `X-CSRFToken` header), and the Rails
  equivalent, could not be completed at all: the host had neither half of the pair and no app code
  could supply either. That is two of the most widely deployed server frameworks.
- **The opt-in is one origin in your config.** `"http": { "origins": [...], "cookieJar": { "origin":
  "https://api.example.com", "csrf": { "cookie": "csrftoken", "header": "X-CSRFToken" } } }`. The host
  then replays that origin's cookies and sets the header from the cookie it holds. Your page is
  unchanged, and still cannot read a cookie, set one, or send one anywhere — including the mirrored
  header, which it gets `E_DENIED` for, because a value it chose would not match what the server is
  about to compare. Drop `csrf` if you only need a session cookie replayed.
- **Four things `codegen` refuses rather than warns about,** because each is configuration that reads
  as working and is not: an origin that is not also in `http.origins` (the jar would never fill), more
  than one origin, a cleartext origin that is not loopback (a jar replays a credential on every
  request, which is a stronger claim than a token you grant per call), and a mirrored header the host
  already sets. `valence doctor` gains a **cookie jar** row so you can see the live answer.
- **It behaves like a browser where that is safe, and more strictly where it is not.** Host-only by
  `Domain`, so a cookie never reaches a sibling subdomain; `Path` matched properly; `Max-Age` over
  `Expires`; at most 16 cookies, 4096 bytes each and 8 KiB in all, with anything over a cap dropped and
  logged rather than failing your request. A cookie with **no** expiry is a session cookie and never
  leaves memory, so a restart is a new session. One with an expiry lives in the same
  Keystore/Keychain storage as your token.
- **It is cleared when the user signs out,** and before the token is written — so a device whose
  Keystore cannot delete the jar fails the sign-out with the user still signed in, rather than leaving
  their session cookie for whoever signs in next. Every path that signs a user out clears the jar in the
  same step — `auth.setToken(null)`, including the sign-out of an app that never passed an `account` and so
  clears no rows, and an account switch, under the same sync lease. A token refresh for the same
  account clears nothing. It **survives an OTA update**, deliberately: the origin is compiled into your
  native build and no manifest can change it, so signing a user out of their session for a UI update
  would cost something and protect nothing. Drop or move `cookieJar` in a later store build and the old
  origin's cookies are revoked on the next launch.

## Unreleased: five fixes from an independent review

Nothing here needs anything from your app; regenerate and rebuild as usual.

- **A blocked host could put your bundle back on the loopback port.** When a signed
  `minHost` policy blocks the app mid-session, the host takes the page down and closes the
  little local server that was serving the bundle. It kept *referencing* that server
  though, and the resume path deliberately rebinds a server whose liveness probe fails,
  because iOS reclaims listening sockets while an app is suspended — so a deliberately
  closed server looked exactly like a reclaimed one. Backgrounding a blocked app and
  coming back bound a new listener and served the bundle again, behind the blocking
  screen. It does not any more.
- **Two overlapping update checks could spend a trial attempt.** Five things trigger an
  update check — start-up, resume, the foreground ticker, a connectivity report, and the
  blocking screen's "Check again" — and two of them overlapping after a signed withdrawal
  each ran the whole transition. That meant two activations, and the second read the
  first's own in-progress activation as a previous crash: a strike against a release that
  never failed, plus a duplicate server, ticker and connectivity subscription. The check
  is now coalesced, so a second caller joins the run in flight.
- **A notification event could be typed as something the runtime never sends.** An event
  qualified for automatic emission on its `since` and its `id` alone, so a schema
  declaring `payload: int` or `action: bool` generated cleanly and then received the
  string the runtime actually sends — through generated types saying otherwise, which is
  a lie nothing could catch, because the types come from the same wrong declaration.
  Every response field you declare must now be typed to hold what the response fills
  (`payload` is `string` or `string?`; `action` is `string?` on `notify.tapped`, which is
  the event chosen *because* the action is null). A mismatch makes the event your own and
  warns, naming both types, with `notificationEventAdapter` as the move. Still a warning
  and never a refusal, because the additive-only rule means a refusal would leave such an
  app nothing but a rebaseline.
- **A failed trial left its cached REST values behind.** `data.cache` values are keyed by
  bucket, data schema and key — and none of those moves when a bundle is rolled back, so
  the previous bundle came back and read values in the failed one's shape, through a read
  that prefers the cached value over the server row. The host now drops the cache on each
  of the two strikes. Your server rows, cursors and queued writes are untouched; the
  cache costs a refetch, which is what makes it disposable.
- **`doctor`'s retirement warning can now be cleared.** The `oldest servable bundle` row
  warns while a servable bundle still calls a method you retired, and it used to refuse to
  measure that against the published floor — the only supported way to make an old bundle
  unservable. The warning was therefore unclearable by any action: publishing a floor above
  every referencing bundle moved nothing, and the only thing that silenced it was deleting
  release manifests. The references are now split by the floor. At or above it, they break
  on every device and the row warns with a count and the seq to publish above. Entirely
  below it, the row passes and says what is left: an install that has never committed that
  floor is still on an older bundle, and nothing in your checkout can see it.

**If a built-in is refused for its `since`, the message now gives you the number to
write.** A built-in's reserved `since` is a floor at which the package implements the
method for you — not the number to declare. For an app already past it, the additive-only
rule needs a higher one, and the old refusal named only one of the two numbers, which read
like "the package has not shipped this yet". Both refusals now name
`max(reserved, your baseline + 1)`, and the forcing-an-update guide no longer prints a
reserved number as a literal.


## Unreleased: cache selected REST responses offline

Revision 18 adds `data.cache` behind a compiled per-bucket `cache` grant.
Regenerate and ship a store host to opt in. Cached values are disposable overlays
with no server cursor or outbox; pulls replace them and recorded account changes
clear them. Existing synced rows and pending writes survive database migration 3.
Read [the guide](https://getvalence.pages.dev/docs/guides/rest-cache/) before using
account data or changing bucket schemas.

## Unreleased: what happens when the OS kills the WebView

**Read this before you ship to a cheap phone.** Your page does not run in your app's process. The
WebView gives it one of its own, at a lower priority, and when memory runs short Android kills that one
first. The hook that would let a host survive it is `WebViewClient.onRenderProcessGone` — and
`webview_flutter_android` 4.14.1, still the newest release, does not expose it. So the unhandled path
runs: the WebView kills your app process about 70 ms later, with no Dart frame in between, and the user
is back on the launcher. **Valence 0.4 cannot prevent that on Android.** Closing it needs native code —
`valence` becoming a Flutter plugin with its own `WebViewClient` — which is priced for 0.5 rather than
rushed into a beta. Two apps hit it on an emulator under deliberate pressure.

What did change:

- **Where a platform reports the loss, the host recovers from it.** That is iOS today, which blanks the
  WebView rather than killing the app: the host reloads the same bundle at the route you were on, emits
  nothing the page has to handle, and stops after three recoveries so a device that is genuinely out of
  memory is not kept in a reload loop. iOS stays experimental and untested on hardware.
- **Where the loss is reported, it can no longer roll back a good release.** The ready timer belongs to
  the page that died; left running it timed out and spent a trial strike (§2.4), and two of those revert
  a release that was never at fault. It now stops on the loss and starts fresh with the reloaded page,
  and if the content process dies past the cap the host clears the trial marker so the *next* launch
  does not spend the strike either. **On Android it still costs one**, and nothing in this release can
  change that: the host process dies with the page, so the next launch genuinely cannot tell an eviction
  from a bundle that crashed the app — which is the check that makes rollback work at all. Two evictions
  during the same trial can therefore retire a healthy release on that install. It is one more reason
  the native shim matters, and one more reason to roll out to 10% first.
- **The log and `exit-info` tell you it was this**, not an ANR and not your own crash: a renderer
  exiting `LOW_MEMORY` followed within the same second by the host at `SIGNALED/9`. The
  [startup diagnostics guide](https://getvalence.pages.dev/docs/guides/startup-diagnostics/) shows both
  captures and the two neighbours it is confused with.
- **The limitation cannot rot quietly.** A test fails the day `webview_flutter_android` exposes a
  renderer-gone callback, so the Android handler gets written instead of this paragraph surviving.

Nothing to change in your app or your bundle. Keep anything the user would miss in SQLite, which
survives either outcome.

## Unreleased: `http.request` says which failure it was, and `doctor` answers two open questions

**Three failure codes instead of one.** `http.request` had a single `E_INTERNAL` for "the device has no
network", "your server broke" and "that was not UTF-8". It now answers **`E_TIMEOUT`** for the 20-second
deadline and **`E_OFFLINE`** when the OS reports no network interface at all, keeping `E_INTERNAL` for
what it cannot honestly distinguish — captive-portal Wi-Fi, a firewall, a server that is down. `E_OFFLINE`
is read at the instant the request failed, from the same value `app.online` carries, so a page no longer
samples a second source at another instant and hopes they agree. **If you matched `E_INTERNAL` to mean
"offline", change it:** this is the last release in which adding a code is free.

**Sizes in every size refusal.** `E_TOO_LARGE` now names the observed size and the limit, because
"paginate or give up?" is the question a cap raises and a bare refusal cannot answer it. A streamed
response reports the bytes read before reading stopped, and says that is a floor. `Range` is not on the
header deny-list, which is how a page reads a representation larger than 64 KiB; there is no streaming
form, so an API offering only one large representation and no `Range` cannot be read by this method.

**A session-cookie API is out of scope, and the docs now say so.** There is no cookie jar, so a
cookie-paired CSRF token cannot be completed — which makes the default Django `POST` shape (`csrftoken`
cookie plus `X-CSRFToken`) and the Rails equivalent structurally unreachable from a Valence page. Nothing
could predict it before you shipped against such an API. Use bearer tokens, header keys, a `csrf_exempt`
endpoint, or your own adapter in front.

**`doctor`'s `oldest servable bundle` row answers its own sentence.** It used to report the lowest
`requires.bridge` across servable bundles and then say a retirement is safe "only once no bundle at or
above that line calls the method", leaving that unanswered. It now searches every servable bundle's files
and either reports that nothing references a retired method or **warns** naming the newest bundle that
does. It discounts the `METHOD_SINCE` table codegen writes into every bundle — the trap that makes a
hand-written scan wrong in the unsafe direction — and never claims absence: a name your page assembles at
runtime, or a file that will not decode, is reported as unknown.

**A deleted mapped test is named rather than reported as an errno.** `doctor --tests` used to fail with
`ENOENT … lstat '<path>'`, which reads like a broken checkout. The usual cause is the supported one: a
retirement makes a method's native code and its tests deletable, and nothing prunes
`.valence/test-matrix.json` for you.


## Unreleased - store-host update policy

Corrections to the policy above, before any of it is released:

- The iOS store destination could never resolve. The runtime passes `defaultTargetPlatform.name`, which
  Flutter spells `iOS`, and the comparison was against `'ios'` — so a blocked iOS user saw a screen with
  no button at all. Fixed, and the test now uses the value the runtime actually passes.
- A policy discovered mid-session took the page out of the widget tree but left the WebView controller
  and the loopback server alive, so the old page's timers kept firing and its own CSP-allowed origins
  stayed reachable behind the blocking screen. It is now torn down, as the cold-start path always did.
- The signed policy envelope was cached for **every** manifest that passed step 4, so any install that
  had ever discovered one release re-verified an Ed25519 signature before every first frame, for ever, to
  learn that no policy applied. A withdrawal is now recorded as the seq alone: the downgrade defence
  stays, and an unblocked install verifies nothing at launch.
- **`--min-host` does not carry forward, unlike `--floor`.** That is deliberate — omitting it is how a
  mistaken requirement is withdrawn — but it meant your next ordinary `bundle` silently unblocked every
  device the previous release was holding. `baseline.json` now records the last signed value and the
  release that drops it warns, naming the number to pass again.
- New **`store listing`** `doctor` row. The Android destination is built from the Valence `appId` while
  the Play listing is keyed on the Android `applicationId`; they are independently editable and nothing
  compared them, so a mismatch sent the blocking screen's only button to a listing that does not exist.
- **A known limit, documented rather than fixed:** a policy has no freshness bound. The bytes are signed,
  but the unsigned pointer still selects which signed release a device evaluates, so a held or cached
  pointer keeps a device on a block you have already withdrawn, offline and across restarts. Freezing a
  pointer is therefore a denial of service and not only staleness. Do not sign a `--min-host` you have
  not verified. A real fix needs a signed freshness field and is not in 0.4.

- Supporting hosts distinguish an update needing a newer store build from rejected bytes.
- Optional signed `minHost` requires a store upgrade with a native offline-persistent
  screen, preserving rows, pending edits and trial attempts. A newer signed release
  can withdraw it. Older runtimes cannot enforce this policy.
- Revision 17 adds `app.openStore`, fixed to compiled store identity, and nullable
  `requiredBridge` / `minHost` status fields. Regenerate and ship a store host before
  relying on these; existing schemas keep their legacy rejected reason.


## Unreleased: retire a bridge method you no longer call

A method of your own that nothing calls any more — the classic case is a hand-written
reminder method replaced by the built-in `notify.schedule` — can now be marked
`"retired": true` in `bridge.schema.json`:

```json
"notify.daily": { "since": 1, "retired": true, "params": { "hour": "int" }, "returns": "void" }
```

It still cannot be *removed*: an old bundle on an old phone is entitled to the method it
was built against. So nothing on the wire moves — the name, its `since`, its params and
its return type stay in the schema and in the baseline, and `has()` still answers true.
What changes is your host: `codegen` keeps the method in the `BridgeHandlers` interface
and implements it in the generated `ValenceBuiltins` with `E_UNSUPPORTED`, **so you can
delete your own handler and the native code behind it** — which was the whole point. The
generated TypeScript marks it `@deprecated` — a label on the `Methods` entry, not a
compiler error at a `call()` site — and the permanent "this CLI has no built-in by that
name" warning stops, because a retirement is exactly the statement that warning asks for. Marking and unmarking are both additive against a recorded store baseline.

You cannot retire a built-in, `app.ready`/`app.info`, or a plugin method; `codegen`
refuses each by name. **Delete the page-side calls first:** `has()` still answers true,
so a bundle that still calls a retired method gets `E_UNSUPPORTED`. `doctor` has a new
`oldest servable bundle` row — it passes with the lowest `requires.bridge` across the
built-in bundle and every local release, and names any retired method beside it. That is
the number which says whether a retirement is safe, and it was arithmetic by hand across
`baseline.json` and `dist-ota/manifests/` before. It does not subtract the floor you
published, because a floor only binds a device that has already committed a bundle
carrying it. It only sees the releases on this machine, and warns rather than guessing
when `baseline.json` records a release whose manifest is not in your checkout.

## Unreleased: preserve custom notification event payloads

Native scheduling no longer emits integer IDs over a legacy string-ID notification event in
regenerated hosts. Refresh tooling, regenerate config and ship a store build. Hosts retaining
pre-11 events pass `notificationEventAdapter` to `Valence.open` and reuse their conversion for
consume-once cold responses. Keep shipped schemas and baselines intact. See the local-reminder
migration recipe; automatic modern events emit only their declared fields.

## Unreleased: preserve custom deep links during migration

Updating 0.3 tooling now preserves a custom `link.initial` declared before schema 9,
including a nullable string return. Keep its handler, event emitter, routing adapter
and shipped baseline; no rebaseline or signature change is needed. Schema-9 built-ins
still delegate with strict nullable `{url, path}` checks. See the migration guide.

## Unreleased: the plugin directory

There is now a page that says which plugins and add-on packages exist:
[the plugin directory](https://getvalence.pages.dev/docs/guides/plugin-directory/).
No third-party plugin is published yet, and the page says so — what it mainly does is
name the two shapes a package can take, because they are installed differently and
nothing said so before:

- a **plugin** brings its own namespace (a `valence.plugin.json` fragment, a
  `ValencePlugin`, web types) and needs a `plugins` entry with your own `since` stamp,
  codegen and a registration;
- an **add-on** implements something core already owns and needs neither. `valence_push`
  is the first one: `push.*` is a core namespace, so the package supplies a
  `ValencePushTransport` and is a pub dependency plus a constructor argument.

Nothing changes in the runtime or the CLI. Distribution was always ordinary pub and npm
publishing — there is no registry, resolver or marketplace, `plugins[].path` always names
a file already on disk, and a listing is a hand-maintained docs row that records a
package exists, not that anyone read it. A plugin is trusted native code with host
privileges, so audit one like any native dependency. Contracts §4.10 now states this.

If you are publishing a plugin, the directory lists what a listing asks for: published
pub and npm halves, a fragment that declares **no** `since`, an unreserved lower-camel
namespace, `valence.plugin.json` shipped inside the npm package, native setup notes at
the path `setup` names, an honest platform claim, and a licence.

## Unreleased: a stale generator says so, and a push transport must state `hasNotification`

If your vendored `valence/valence.mjs` is older than the runtime you are reading about, a real built-in
is to it just an unknown name in an area the package owns — so it generated that name as *your* method,
silently, and your host stopped compiling with `Missing concrete implementation of
'BridgeHandlers.notifyPendingIds'`. That reads as "the package has not shipped this yet", which is the
one conclusion that sends you off to reimplement a built-in by hand. Two apps hit this in one week, from
both directions: a whole method (`notify.pendingIds`, schema 16) and one documented optional field
(`SyncStatus.reason`, schema 15).

- `codegen` now **warns** when a method's area is one the package ships built-ins in but the name is one
  it has never heard of, and names `npx create-valence update`. `doctor`'s `generated code` row turns to
  `WARN` with the same sentence. A warning and not an error, because an app-owned `notify.daily` from
  before schema 11 is still supported: if the method really is yours, nothing is wrong.
- When a built-in's returned type is declared with a field the generator has no entry for, the rejection
  **names that field** and the same command, instead of only blaming your schema for declaring what the
  docs told you to.
- **Habit worth forming:** run `npx create-valence update` before trusting a `since` for any built-in,
  and check the generated `ValenceBuiltins` carries the delegation rather than an abstract member.

**You must change this if you wrote your own push transport.** `ValencePushMessage`'s `hasNotification`
is now a **required** argument with no default. Hosts using `valence_push` are unaffected — it already
passes it. `false` is the permissive answer, because it is the half of the data-only check that lets a
payload trigger a sync, and core no longer derives it for you now that the transport is yours. The
default meant a transport that never considered the field turned every notification carrying
`{"valence":"sync"}` into a background sync. Pass `message.notification != null`, or your provider's
equivalent; omitting it is a compile error rather than a silent fail-open.

Also fixed: an app-owned method under a built-in's name that differed only in its **return type** was
refused as a renumbered built-in, because the signature comparison looked only at the params — so
`notify.pending` returning `string[]` could not be declared at all, against §6.5's promise to preserve
it. Sync's own lease and observation writes now carry the `database locked` label §5.1.1 promises rather
than only a timing line. The remote-push guide carries the Google services Gradle wiring again, the last
in-repo copy of which the Firebase split removed.

## Unreleased: Firebase is an opt-in native package

Core-only Valence hosts no longer depend on Firebase. Remote push hosts must add
`valence_push: ^0.4.0-beta.0`, import `package:valence_push/valence_push.dart` and
replace `ValencePush()` with `createFirebasePush()` after Firebase initialization.
Keep direct Firebase dependencies when importing their APIs. Rebuild the native
host; an OTA cannot install or remove SDKs. Custom transports now exchange
`ValencePushMessage` rather than `RemoteMessage` and preserve `hasNotification`.
The Firebase-specific `ValencePushMessage.fromRemote` constructor is removed;
custom transports construct the provider-neutral record directly.

Bridge schema/signatures, background sync, notification data, caps and consent
rules are unchanged. Local notifications and badges remain core dependencies;
Android desugaring is still needed for local notifications. The core example has
no Firebase dependency, and `VALENCE_PUSH=true` no longer enables it: follow the
remote-push guide to add the native package and initialization. Firebase's iOS
15.0 minimum applies to push hosts. Device delivery still needs a Firebase project;
iOS is experimental and untested. This supersedes the earlier SDK-disclosure
mitigation below. Audit other app dependencies and final binaries independently.

## Unreleased: `notify.pendingIds()`, because a full reminder queue cannot be read back

Schema **16** adds one method: `notify.pendingIds() -> int[]`, the native pending queue with the IDs
and nothing else.

`notify.pending()` is the only thing the docs give a page for discovering pending reminder IDs, which
is what the documented cancel-and-refill-by-difference workflow needs. It carries each request's
title, body and payload, and those are capped at 256, 4096 and 4096 bytes, so a full queue of 64
maximum-size requests is about 540 KB — over the 256 KB bridge reply cap. The reply is replaced with
`E_TOO_LARGE`, so the workflow broke on exactly the apps that keep the most reminders queued. Sixty
four integers are about 400 bytes and no field can grow them past the cap.

```ts
const ids = has('notify.pendingIds')
  ? await call('notify.pendingIds', {})
  : (await call('notify.pending', {})).map((r) => r.id);
for (const id of ids) if (!wanted.has(id)) await call('notify.cancel', { id });
```

**Nothing you have shipped changes.** `notify.pending()` keeps every field and every meaning it has:
trimming it was the other option and was rejected, because an absent body and an empty one would
have become the same answer, silently, on the method whose whole purpose is reconciliation.

**To adopt it:** add `"notify.pendingIds": { "since": 16, "params": {}, "returns": "int[]" }` to your
schema, raise your schema `version` to at least 16, regenerate, and ship a store build — an OTA
cannot add a native method. Gate it with `has('notify.pendingIds')`. Both methods read one native
snapshot, and both return an empty list on a host whose notification service could not start.
`app.info().builtins` is now 16.

## Unreleased: startup timings and named database waits

Native startup reports phase entry, completion and elapsed milliseconds through
the existing logger. Database operations still pending after ten seconds name
their operation and report completion or failure. No schema or app configuration
change is needed; ship an updated Flutter host. These diagnostics preserve retries,
transactions and user data. They provide evidence for a recurrence and do not
establish a cause or fix for earlier Android stalls.

## Unreleased: say which SDKs every Valence binary carries

The docs said a host that does not configure push needs no Firebase. That is true of the runtime and
false of the binary: `firebase_core` and `firebase_messaging` are unconditional dependencies of the
`valence` package, alongside `flutter_local_notifications` and `app_badge_plus`, so an offline app
with no account, no push and no reminders still ships them. `FirebaseInitProvider` runs on every
launch and logs that it found no default options, and FCM registers a service in the merged manifest.

Play's Data safety form and Apple's privacy manifest ask about SDKs that are **present**, not SDKs
that are reached, so if you are submitting a Valence app, declare them as present and unused: no
token is registered and nothing is collected without a configured push adapter. You cannot remove
them — `dependency_overrides` re-points a package, it does not drop one.

No code changed. Moving push into a separate `valence_push` package that an app adds when it declares
`push.*` is the real fix and is not in 0.4. The store-policy, remote-push and contracts text now say
all of this where an adopter will read it.

## Unreleased: codegen refuses a built-in declared below its reserved since

A built-in's `since` is the version the runtime reserved for that name, not a number your app
chooses — the delegation is only generated at or above it. Declaring one below made the name
app-owned silently: codegen emitted an abstract handler, `ValenceBuiltins` did not satisfy it, the
host stopped compiling with a message that looked like the package had forgotten to ship something,
and writing the handler by hand compiled and reimplemented a built-in.

`codegen` now refuses it and names the number to use. Four names carry a floor, because they were in
use as app-owned methods before the built-ins existed: `notify.*` and `badge.*` at 11, `push.*` at
12, and `share.image` at 14. Every other built-in still delegates at any `since`.

Only a declaration carrying the built-in's **own signature** is refused — that is what copying the
template and renumbering it produces. A method of your own under one of those names, with its own
params and return, keeps its abstract handler exactly as before, and so does a name your recorded
store schema already shipped.

If codegen now fails for you, raise that method's `since` to the number the message gives. Your
schema's own `version` is unaffected. The permissions guide, which told you to assign your app's next
version to copied built-ins, is corrected, and the bridge guide has the floors in one table.

## Unreleased: a sync scoped to nothing can no longer report success

`sync.now({ buckets })` naming only buckets the host does not have — a typo, or a
bucket a newer bundle renamed — attempted nothing and reported `reason: "ok"`, and
persisted that over a stored `unauthorized`. A page's "sign in again" banner reads
`sync.status()`, so one scoped call could make a refused account look healthy.

A scoped run that matches no read pair, no writable bucket and no outbox bucket now
reports `failed`, logs the names it was given, and writes no observation, so the last
real outcome stands. A scope that does match any bucket is unchanged. Upgrade the
native host package; no schema or app change is needed.

## Unreleased: a missing notification icon no longer takes the app down

- A native notification service that refuses to start no longer throws out of `Valence.open`. The
  host logs the native code and the reason and runs with notifications unavailable: `notify.schedule`
  reports `blocked`, `notify.pending` is empty, `badge.set` is false, and the rest of the app is
  unaffected. A host that cannot post a notification is still an app.
- The usual cause is Android's release resource shrinker. `notifications.icon` is named only as a
  string in `valence.config.json`, so nothing references the drawable and R8 deletes it — which no
  debug-build check can see. `valence doctor` now has a `notification icon` row that fails when the
  drawable is missing from `android/app/src/main/res` or when `res/raw/keep.xml` does not name it.
  If you have notifications enabled, add `res/raw/keep.xml` with
  `tools:keep="@drawable/<your icon>"` and run a release build.
- The notifications guide says this where the icon is introduced, as a requirement rather than a tip,
  and now shows the three-line adapter for delegating a shipped custom `notify.*` method to the
  built-in scheduler — there is no separate service class to import.

## Unreleased: a replaced OS snapshot cannot cross an account or a bundle

A replacement task snapshot handed to an already-running host is now checked against the
account fingerprint and bundle seq that startup verified, and dropped whole on a mismatch.
Before this, restoring a snapshot saved under one account after switching to another served
the first account's route and draft through `state.restore()`, and an older bundle's blob
skipped the seq check. Upgrade the native host package; no schema, config or app handler
change is needed.

## Unreleased: native plugin registration checks

Regenerated handlers reject missing plugin namespaces and exact native methods at startup
in every build mode. Register the matching plugin instances, regenerate with matching
tooling/runtime snapshots, test your real app handlers and rebuild the host. Doctor lists
requirements as a warning; native setup and successful behavior still need testing.

## Unreleased: development mode identifies skipped OTA operations

Debug hosts now log the upstream origin and disabled OTA behavior at startup. Calls to ready,
signed reload, update checks and applyUpdate log their development bypass rather than appearing
silent. Restart without VALENCE_DEV_URL to validate signed offline starts and rollback. No
schema, package version or host setup changes are required.

## Unreleased: check for updates after reconnect

- A live connectivity report while the app is foregrounded now retries the signed update check,
  including Wi-Fi/cellular handovers. Concurrent checks coalesce; data requirements retain their lease
  and verification. Background reconnects sync only and defer the update check to resume.
- `bundle.status` describes the last completed attempt until another one completes. Read `offline` as
  "could not check on the last attempt", rather than a claim about the current connection.
- Upgrade the native host package to get the trigger; no schema bump or app handler change is needed.

## Unreleased: local native HTTP stays on loopback in the example

- The example's native HTTP demo now uses `http://127.0.0.1:8787` with
  `adb reverse tcp:8787 tcp:8787`. Regenerate and rebuild the host when copying this
  config change, and rebuild its signed web bundle for the matching button URL.
  A release-device probe confirmed that Android's loopback-only network security
  XML does not block native Dart HTTP to a compiled cleartext origin. Those origins
  can receive the host token in release builds; use HTTPS for remote APIs.

## Unreleased: explicit LAN development trust

- `valence dev` now binds loopback by default. A LAN address or hostname requires
  `--allow-lan`; that mode binds all interfaces and names the cleartext full-bridge
  risk before starting. Add the flag to existing physical-device dev commands.
  Manual Flutter defines remain explicit trust grants; release/profile exclusion
  is unchanged. Refresh vendored tooling when upgrading.


## Unreleased: capability and status fields

Schema 15 adds nullable builtins, persisted sync reason and signed pending urgency. Regenerate and ship a store build; declaring builtins also requires current optional params on declared built-ins. Earlier hosts and schemas keep working. Account changes clear the new sync observation.

## Unreleased: seed completion survives database locks

- Seed completion markers retry `SQLITE_BUSY` and `SQLITE_LOCKED` without importing the rows
  again. Logs separate a row-import failure from a failed marker write and report recovery.
  Exhausted retries retain rows and retry on the next launch against current cursors.
- A matching completion marker and extracted seed now skip the unchanged import on later
  launches. Upgrade the Flutter runtime and ship a host build; no schema or codegen change.

## Unreleased: failed syncs report failure

- Server and protocol failures now return `SyncResult.reason: "failed"`, including
  anonymous 401, HTTP 403/500 and invalid response bodies. A token-bearing 401 still
  reports `unauthorized`. Partial changes remain applied and unacknowledged writes
  stay queued; an incomplete run never advances the last successful sync timestamp.
  No schema bump is needed: the reason field is an open string set. Freshness UI
  should treat every non-`ok` reason as incomplete.

## Unreleased: a published plugin installs without editing it

- **A `plugins` entry can be `{path, since}`,** stamping each of a fragment's methods and events with
  an app bridge version. `since` is an app version, so no fragment shipped in a pub package could
  carry a number right for every app that installs it: a published plugin was installable only by
  editing a file inside `~/.pub-cache` or copying the fragment into your repo and re-stamping it per
  app. Nothing changes for a fragment that stamps itself; the two forms are exclusive per entry, and a
  stamp naming something the fragment does not declare is an error. The example's haptics plugin now
  uses the published form, which is the shape to copy.

## Unreleased: hardening the two newest trust boundaries

Review of the combined feature merge found no broken security path in live development (R9) or native
plugins (R10) — release builds really do exclude the dev server, and a plugin really cannot redefine a
built-in. These are the gaps around them.

- **An event over the 256 KB cap is now dropped instead of sent.** Replies were measured and events were
  not, because every built-in payload is small and host-bounded. Plugins made an event payload arbitrary,
  and an oversized one kills the WebView — which, if a trial bundle is on screen, spends one of its
  strikes and can get a healthy bundle marked bad.
- **A plugin fragment path must stay inside the project.** `..` was accepted, so a build could depend on
  a file outside the repo and the reviewed schema recorded in `.valence/baseline.json` would have no
  source in it.
- **The dev-server guard now has a test.** Release exclusion rests on each read of `VALENCE_DEV_URL`
  being a `kDebugMode` compile-time constant. Removing one left every suite green, with the dev proxy
  live in the release snapshot; a package test now fails instead, and the release workflow says to run
  `check-release-dev.mjs` against the artefact you submit.
- `check-release-dev.mjs` also reads app bundles (`base/lib/<abi>/libapp.so`), not just APKs. It is the
  bundle you upload to Play.

## Unreleased: three more ways an account switch could leak across accounts

All three are §4.4 hardening, found by review of the account work. None needs an app change.

- **A `data.put` during a switch is now refused** with `E_INTERNAL`, for the whole transition including
  the wait for the sync lease. The lease ordered a switch against sync and nothing ordered it against a
  local write, so a write from the outgoing account's page could commit after the clear and be pushed
  under the incoming account's token. A write already running is now allowed to finish before the clear
  rather than after it. If you fire writes while awaiting `auth.setToken`, disable the form for the
  duration and make a refused write again afterwards — nothing was stored.
- **The `E_PENDING` guard no longer depends on having a writable bucket.** A host whose `writable` set
  had become empty skipped the outbox check entirely, so a switch succeeded silently over queued writes
  and kept them — to be pushed under the new account's token the day a writable bucket came back.
- **The account id is written before the token on every path**, not just on a switch. On an adoption the
  old order could lose the id and keep the token, which made the next sign-in as somebody else look like
  another adoption rather than a switch — leaving the first account's rows and queued writes in place
  under the second account's token.

## Unreleased: the bridge tarball is built from its own source

`@getvalence/bridge` ships compiled output (`dist/`), which is build output and not in git. Nothing made
`npm pack` or `npm publish` rebuild it, so either could tarball a stale `dist/` under a current version
number — two different APIs behind one version string. A `prepack` hook now runs the build, so the
published package always matches the source it claims to be.

If you ever saw `TS2554: Expected 1 arguments, but got 2` inside your generated `bridge.g.ts`, that was
this: your installed bridge predated event gating while your generated file expected it. Upgrade the
package rather than silencing the error — JavaScript drops the extra argument, which would leave `has()`
answering `false` for every event on every host. The release recipe no longer needs a separate
`npm run build`.

## Unreleased: task restoration

Task restoration now checks the native account before loading a restored route, clears drafts on account switch/sign-out and refuses late route captures from the previous account. Refresh and first-account adoption keep the live draft.

Schema 8 adds `state.save({json})` and `state.restore()` for a task-local UI blob (65,536 JSON UTF-8 bytes). ValenceApp restores the local path/query/hash after OS process reclamation. Explicit task closure starts fresh; a different bundle seq clears the snapshot. Save promptly and keep durable records in SQLite. iOS is experimental and untested.

## Unreleased: deep links

Open local screens from Android App Links or custom schemes with schema-9
`link.initial`, `link.opened` and the web `onLink()` helper. Regenerate the bridge,
compile `links.origins` and add matching native registrations in a store build.
Existing hosts remain supported; OTA cannot expand accepted origins. New
`assetlinks` and `aasa` commands write website association documents for separate
HTTPS hosting. iOS is experimental and untested. See [setup](docs/deep-links.md).

## Unreleased - permissions (R3)

- Added schema-9 permission checks, serialized foreground requests, app settings and resume changes. Hosts opt in with `permissions.kinds`, native declarations, codegen and a store build. Android checks preserve uncertain denial; iOS remains experimental and untested.

## Unreleased - local reminders

Schema 11 adds built-in local reminders: notify.schedule/cancel/pending/channels.set, notify.permission, consuming notify.initial, notify.tapped/notify.action and best-effort badge.set/clear. Opt in with notifications.enabled, regenerate, install native receivers/icon/desugaring and ship a store build. Exact requests report downgrades honestly; one-shot epoch times need no device timezone lookup. Images are bounded PNG/JPEG bytes; every action opens the UI. iOS is experimental and untested. Android hosts now need core library desugaring even when the feature is disabled, because the native plugin ships with the runtime. Existing custom notification IDs must be coordinated; pre-schema-11 custom methods retain their shipped shapes and app-owned handlers.


## Unreleased - remote push

Remote push is opt-in in schema 12: `push.token`, passive/explicit `push.permission`, consuming `push.initial`, `push.received`, `push.tapped` and `push.tokenChanged`. Firebase runs only in configured hosts; exact data-only sync hints use the existing native sync without touching OTA state. Android notification images use FCM background display; foreground messages reach the page. **Device validation is blocked: needs Firebase project. iOS/APNs is experimental and untested.** Existing hosts must add the additive schema, regenerate, configure Firebase and ship a store build. Unicode line separators are escaped in event/reply scripts without changing JSON values.

## Unreleased: live development

- `valence dev` starts a Vite-compatible development script and prints the Flutter debug command.
- Debug builds can proxy the explicitly chosen server through the owned loopback origin, with
  the typed bridge and HMR WebSockets working together. No schema or version bump is required.
- Release/profile builds exclude the path even with the define supplied. Dev mode preserves
  OTA trial state, disables updates and blocks workers. Use separate dev app ids and test accounts.

## Unreleased: image sharing

Schema-14 `share.image` shares a PNG/JPEG with a caption from capped inline bytes
or the active signed bundle. Regenerate and ship a store build to add it; use
`has()` on older hosts. Existing custom methods declared before schema 14 keep
their signature and handlers. Results describe native selection, not delivery.
The iOS path is experimental and untested. Package versions are unchanged.

Sync correctness: pull cursors advance only through returned rows, never push echoes or a later server-head max. Fresh pairs satisfy OTA activation only after all pages or static chunks complete. Progress resumes after an interruption. Pending publication retains the data lease; GC protects in-flight manifests and retries stale snapshots. Step 7 waits up to five seconds for ordinary sync. Outbox operations use a durable insertion ordinal; database version 2 migrates legacy queued ids, values and deletes without changing bucket cursors or user rows.

## Unreleased

### System layout and accessibility

ValenceApp now requests edge-to-edge layout and publishes system-bar/cutout insets as CSS variables. Existing pages must apply them to content and fixed controls. Android text zoom follows system font size. Codegen supports optional AppInfo.fontScale without changing old schemas; schema 7 adds app.appearance (dark mode, high contrast, reduced motion). Add its schema entry, regenerate and ship a host update. iOS root-font scaling is experimental and untested; the guide covers its limits.
## Unreleased: account switching is safe

Schema version 13. `auth.setToken` takes two more params and `auth.account()` is new, because a token is
replaced far more often than a user changes and the host could not tell the two apart.

- **`auth.setToken(token, {account})`** records your own opaque id for the user beside the token. The
  same id again is a refresh and does nothing else. A **different** id, or `auth.setToken(null)` with an
  id recorded, is an account switch.
- **A switch refuses to run over queued writes.** It throws the new **`E_PENDING`** and changes nothing —
  not the token, not the id, not a row. The host attaches whatever token is stored at the moment it makes
  the request, so a switch over a full outbox would have pushed user A's rows under user B's credentials
  from a background sync minutes later. `{discardPending: true}` is the only way past, and it deletes
  those writes unsent.
- **A switch clears every writable bucket** — rows, `max_usn` cursor and the whole outbox, in one
  transaction, under the sync lease, *before* the new token is stored — and emits `sync.changed` for
  them. Read-only buckets, prefs and your own `secure.*` keys are untouched. The wipe is local: no
  tombstone is pushed, so user A's rows stay on your server.
- **Nothing changes for an app that does not pass `account`.** Sign-out keeps the 0.3 behaviour exactly
  (the token goes, the rows stay), and the first call that names an id when none is recorded *adopts* it
  and clears nothing — otherwise upgrading would wipe the data of the user holding the phone.
- **`null` is the sign-out; an empty string is not.** `auth.setToken('')` clears the token and no data,
  exactly as before. And check your `auth.expired` handler before you adopt `account`: if it signs the
  user out, that call becomes a wipe of the user who is about to log straight back in. Refresh the
  token instead, which is what the 401 rule has always asked for.
- **Gate the params on `has('auth.account')`,** never on `app.info().bridge`. They are params, so they
  have no `since` of their own, and an older host rejects them with `E_PARAMS`. `valence codegen` refuses
  to emit them without `auth.account` declared beside them.

**What you must do:** nothing, unless your app can be used by more than one person on one device. Then
add the two params and `auth.account` to `valence/bridge.schema.json` at your next version, regenerate,
and pass `account` on sign-in.

## Unreleased: lifecycle, connectivity and update status

Bridge version 6. Three events and two methods for the three questions a page in a browser tab answers
from the platform and a page in the host cannot.

- **`app.lifecycle`** fires on the way *out* as well as in, with four states — `foreground`,
  `background`, `inactive`, `detached` — mapped from Flutter's five. Android delivers `hidden` and then
  `paused` for one backgrounding, so both are `background` and only changes are emitted. Persist on
  `background`: `detached` usually never arrives, because the engine is tearing down and there may be no
  WebView left to run the script. `app.resumed` is unchanged.
- **`app.online`** reports what the OS says about network *interfaces* — the same source as the
  "connectivity came back" sync trigger — and is explicitly **not** reachability. Use it to decide
  whether to *try*; use `SyncResult.reason` or `sync.status().offline` to say whether the last attempt
  worked.
- **`app.state()`** returns both current values, for a page that mounts after the transition: a cold
  start from a notification tap, or the reload an applied update does.
- **`sync.done`** carries the whole `SyncResult` after every completed run the host made on its own,
  including `changed: 0`, `busy` and `unauthorized`. `sync.changed` is silent when a run moved nothing,
  and most runs move nothing, so a "last synced" line could previously only be updated by a sync the page
  asked for itself.
- **`bundle.status()`** says why an update declined, from a closed set: `idle`, `unconfigured`,
  `uptodate`, `rollout`, `bad`, `offline`, `rejected`, `toobig`, `waitingForData`, `busy`, `ready`,
  alongside `serving`, `pending`, `trial`, `offered` and `checkedAt`. It never starts a request.
  `rejected` means a published release is unservable on every device and is worth an alert of your own;
  `waitingForData` is a healthy state that can last for days on an offline device, and is the one four
  hosts mistook for "no update".
- **`bundle.updateReady` now fires for every pending bundle,** not only one released with `--urgent`.
  It is the push signal that pairs with `bundle.status()`, and `bundle.applyUpdate` has never required
  `urgent`, so gating the event on the flag left a page with nothing but polling — and polling on
  resume races the update check, which finishes a few hundred milliseconds after the read. The result
  was that a page learned about an update on the resume *after* the one that found it.
  **What you must do:** nothing, unless you relied on the event meaning "urgent". Read
  `bundle.status()` on mount and re-read it on `bundle.updateReady`; `urgent` is now purely the
  release's request to be offered mid-session, which your page decides how to honour.
- **A data-cap stop reports `toobig`, not `waitingForData`.** When the configured `dataSizeCap` ran out
  *inside* a pair's pull rather than before it, `bundle.status().reason` blamed unavailable data for
  what was the app's own limit — and sent you to inspect a server that was answering correctly.
- **`has()` now answers for events too, not only methods.** `on()` for an event an older host has never
  heard of subscribes happily and then never fires: nothing throws, nothing logs, and the feature behind
  the listener quietly stops happening. Gate the *feature*, not the subscription. On the web `has()` is
  false for every event, since there is no host to emit one, so one branch covers both an old host and
  the website build. **What you must do:** regenerate — `bridge.g.ts` now passes `EVENT_SINCE` to
  `createBridge` alongside `METHOD_SINCE`, and that second argument is **required**. Upgrading the
  package without regenerating is a build error naming the file to regenerate, rather than `has()`
  quietly answering `false` for every event on every host.
- **Two new `codegen` refusals, both closing a silent gate.** Declaring `data.list`'s `after` without
  also declaring `data.count` is refused: the sibling *is* the gate, so without it `has('data.count')`
  is false on every host you will ever ship — including the ones that accept the cursor — and a page
  following the docs never pages at all. And one name may no longer be both a method and an event,
  because `has()` resolves a name to one answer and would otherwise report `false` for an event your
  host really does emit.
- **`data.list`'s `after` cursor advances past an empty first key.** `''` is a valid key — `data.put`
  refuses only `.` and `..` — and the host was reading `after: ''` as "no cursor", so a bucket whose
  first key was empty returned that same row on every page and could never be read completely.

**What you have to change in your own host:** nothing, if you leave the schema alone. To take the five,
add them to `bridge.schema.json` with `since: 6`, raise `version` to 6 and regenerate — the `valence`
package implements all of it, so no handler is yours to write. A page must treat a `reason` it does not
recognise as "no update right now" rather than an error, because a newer host can return one that did
not exist when the bundle was built.

## Unreleased: offline tooling

- Add schema-3 data.getMany and sync.status, and optional SyncResult.pending. Regenerate an additive schema and guard the new methods on older hosts.
- Seed multiple declared read-only schemas using seedSchemas and versioned files; the runtime imports each declared pair.
- OTA bundle bridge requirements now default to the recorded store baseline. Guard newer methods; explicitly pin lower if older store builds remain supported. Built-in/store defaults still use the current schema.
- Compile ota.channel and generate opt-in BridgeHandlersDefaults for test doubles.
- Run mechanical doctor diagnostics and mapped unit tests without an interactive session. Unexecuted evidence stays WARN.
- Constrain path_provider_android to the pre-JNI range >=2.2.17 <2.3.0 while compatibility is validated (U-7, 2026-10-21).

Newest first. One version for `create-valence`, `@getvalence/bridge` and the `valence` pub package.

## Unreleased

### Reusable native plugins

`doctor` checks the combined app/plugin schema against the store baseline, so
a shipped plugin is accepted while changing or removing it still fails. After
upgrading tooling or the bridge, regenerate and type-check with a matching
CLI/bridge snapshot pair.

`ValencePlugin` packages can contribute namespaced schema fragments, native
handlers and setup notes, with matching npm types. Config `plugins` lists the
fragments; codegen and bundle merge them before compatibility checks. Conflicts,
reserved namespaces and changes to shipped definitions fail. Generated dispatch
still checks the nonce and strictly decodes parameters/results. Native additions
need a store build. The built-in open group uses the plugin API, and the example
haptic handler is a separate local package. Existing wire shapes stay unchanged.

### Calling your own backend

Call your API with `http.request` (schema 4): the host enforces compiled `http.origins` origins, attaches the stored token, and never follows redirects. Existing hosts need codegen and a store build to add the capability or origins. A reference Node REST-to-sync adapter demonstrates durable pagination, tombstones and idempotent pushes. iOS remains experimental and untested.

Everything below is unpublished. Two headlines: an app can finally log a user
in, and the runtime is two published packages instead of generated code. Under
them are the test-week fixes, logged by four independent teams who built Android
apps from the public docs and wrote down what broke. The version for this batch
is the maintainer's call.

### Logging a user in, at last

Until now an app with private synced data had no auth story at all: four test
apps needed one, none got past it cleanly, and the workarounds all came down to
a token in the `prefs` table — plain text, inside a database meant to be backed
up — that the background sync could not reach anyway.

0.4 adds the smallest thing that actually works, **bring your own token**. You
keep your own login: the web app authenticates against your API however it
already does, then hands the host the token.

```ts
await call('auth.setToken', { token });
```

From then on the host attaches `Authorization: Bearer` to every pull and push of
a **writable** bucket, including the runs it makes by itself on resume, on
reconnect and in the background — which is the whole point, because those happen
while your JavaScript is not running. Public read-only buckets stay
unauthenticated, so a CDN can still serve them.

- **The token is stored in the Android Keystore** (an AES-GCM record with a
  hardware-wrapped key, `minSdk 23`) or the **iOS Keychain** (experimental and
  untested, like every iOS path here), never in SQLite.
- **The page can never read it back.** It lives under the reserved `valence.`
  prefix, which `secure.get` refuses, so `auth.setToken` and `auth.hasToken`
  are the whole surface. There is deliberately no `auth.getToken`.
- **A 401 is reported as a 401:** the new `auth.expired` event fires once per
  sync run and `SyncResult.reason` is `"unauthorized"` — not `"ok"`, which a
  freshness indicator reads as "up to date", and not `"offline"`, which would
  have the page wait for connectivity it has. The token is kept, because a
  refresh flow usually has to present the expired one, and queued writes stay
  queued.
- **`secure.get` / `secure.set` / `secure.delete`** are open to your app for
  other short secrets. `secure.set` takes a non-null value on purpose:
  `secure.delete` is the only delete, so clearing a credential says so at the
  call site.
- **`ValenceConfig.authToken` still wins when you set it**, so a host with its
  own refresh loop in Dart is unaffected.

**To take it, add five methods and `auth.expired` at `since: 2` and bump your
schema `version` to 2** — they are built-ins, so there is no handler to write.
That moves `requires.bridge` to 2, so the next OTA release needs the matching
store build; `valence bundle --requires-bridge 1` buys one more release for the
hosts already out there. The [Login and secrets](https://getvalence.pages.dev/docs/guides/auth/)
page has the details, including what Valence deliberately does not do: it is not
an identity provider, there is no per-request scoping, and logging out does not
wipe the rows already on the device.

### The runtime is two packages now

The biggest change since 0.1. `/valence init` used to **generate** about 1,500
lines of Flutter host into every app, plus a `client.ts` into every web app.
Every app therefore carried its own copy of the OTA verification, the rollback
state machine and the bridge trust boundary — and during test week one bug in
the rollback loop had to be fixed by hand in four separate apps.

- **[`valence`](https://pub.dev/packages/valence) on pub.dev is the whole Flutter
  host:** the loopback server and its nonce, the canonical check order, the
  activation state machine and its rollback, signature and manifest
  verification, the SQLite store and its pragmas, the seed import, sync with its
  lease, strict bridge decoding, and the WebView with its navigation lock, back
  gesture and console capture. The contracts §8 matrix is its own test suite.
- **[`@getvalence/bridge`](https://www.npmjs.com/package/@getvalence/bridge) on
  npm is the whole web client:** `call`, `has`, `on`, `ready`, `connect`,
  `installShim`, `inHost` and `BridgeError`. ESM, zero runtime dependencies.
- **`valence codegen` emits only the app-specific half** — the typed method and
  event tables, the payload types, `bridgeDispatch`, `BridgeEvents`,
  `valenceConfig`, and a `ValenceBuiltins` base class that delegates `app.*`,
  `data.*`, `prefs.*`, `sync.*`, `open.external` and `bundle.*` to the runtime.
  Your `main.dart` is about twenty lines and your handlers class holds only
  methods that are genuinely native to your app.
- **A fix now ships once.** `flutter pub upgrade valence` and
  `npm update @getvalence/bridge` are how it reaches you.
- **The wizard, the skill and the builder agent add the packages** instead of
  generating code, and the reviewer treats a vendored or reimplemented runtime
  as a finding in its own right.
- **A built-in method may be omitted from your schema but not redefined.** An
  app that never syncs can drop `sync.now`. One that keeps the name and changes
  the shape would compile and then pass the wrong arguments to the runtime, so
  `codegen` refuses it and names the shape it must keep.

**Migrating from 0.3 is one documented pass** —
[docs/migrating-from-0.3.md](docs/migrating-from-0.3.md). Your SQLite data, your
outbox, every pair's `max_usn`, `state.json` (including a device mid-trial), your
CAS files, your `installId` and your signing key all carry over untouched; the
package's test suite covers that. If your 0.3 host named its database something
other than `valence.db`, one config line keeps it. Swapping the runtime is a
store release, because `lib/` changed.

### One OTA could retire the bundle inside your APK, silently

- **`valence bundle --floor N` now refuses an `N` above your store build's
  `seq`.** The floor applies to the built-in bundle too, which the spec left to
  inference. That bundle is the one artifact every device is guaranteed to
  have — what a wiped or offline phone falls back to, and the only code a store
  review ever saw — so raising the floor past it retired **both** fallbacks a
  device had, from the client side, with no store release. §2.4's ladder was left
  with `current` and nothing underneath, and if that bundle later failed a check
  the only recovery was a store release above the floor: a full review cycle,
  which is exactly what OTA exists to avoid.

  Nothing warned. `verify` was happy, `doctor` was green, and `baseline.json`
  held the number that made it checkable in the file the CLI had just written.

  **What you must do:** nothing, unless a build starts failing — in which case
  the message names your store build's seq and the two ways forward. Raising the
  floor *to* that seq is still allowed and is almost always what you want: it
  strands every OTA below it and keeps the APK runnable. If you already have a
  floor above your store seq, you get a warning rather than a refusal, because
  the floor carries forward on its own and refusing would make every later
  release unbuildable.
- **The reference REST adapter refuses item keys of `.` and `..`.** Those two
  survive `encodeURIComponent`, so URL resolution strips them as dot segments:
  `/items/..` resolves to `/`. An accepted push would have sent an authenticated
  `PUT` or `DELETE` to the upstream's root or collection endpoint. Found by an
  independent review.

### Smaller things the migration got wrong

- **Migration step 2 now covers the `pub add` failure.** An app using
  `flutter_local_notifications` cannot resolve `valence`, because
  `connectivity_plus` wants `dbus ^0.8.0` and the notifications plugin's Linux
  implementation wants `^0.7.8` — two Linux-only packages an Android build never
  compiles. The host guide documented it; the migration page, which is where you
  are standing when it happens, did not. The `dependency_overrides` fix is now
  next to the `flutter pub add` line.
- **`BridgeError`'s import is in the docs.** 0.3 generated it into your
  `bridge.g.dart`; 0.4 imports it from the package without re-exporting, so every
  file that throws one stops compiling with *"The name 'BridgeError' isn't a
  class"*. Add `import 'package:valence/valence.dart';` — the migration page's
  `handlers.dart` example now shows it.
- **`lastSyncedAt` reads `null` after migrating, and the docs say so.**
  `sync.status` is new in 0.4, so no 0.3 host wrote the timestamp: a migrated
  device reports `null` while holding a complete database, and the honest
  rendering of that is "Never synced" under current data. Treat `null` as "not
  known yet" rather than "never". It self-corrects on the first 0.4 sync.
- **A resume can arrive before start-up finishes.** On Android the lifecycle
  observer fires during the first launch, so a resume handler can run before the
  server, the store or the active bundle exists — and worse, can start an update
  check alongside the UI-start transition still in flight. `ValenceApp` now
  ignores a resume until start-up completes (it runs the same triggers itself at
  the end of start-up anyway), and §3 states the rule for hosts that build their
  own WebView.

### A bucket over 500 rows can finally be read completely

- **`data.list` takes an `after` cursor, and there is a new `data.count`**
  (schema version 5). `after` is the last key of the previous page, and the scan
  resumes strictly after it, so a bucket of any size has a complete read.

  The clamp itself was right — an unbounded reply kills the WebView, and that can
  roll back a healthy release — but with no way to page past it, **a bucket over
  500 rows had no complete read at all.** And the damage was not a short list: a
  truncated list is indistinguishable from a short one, so a stored key that
  happened to fall outside the first page read as a key the device had never held.
  One test app showed a first-run location chooser to a device that had been
  configured for days, because the user's saved place was row 600 of 912. A prefix
  is not a general answer; those keys were GeoNames ids and one prefix covered
  about 900 of them.

  `data.count(bucket, prefix?)` answers "how many does this device hold?" and "is
  this key space empty?" with one indexed count instead of paging every row's
  JSON.

  **What you must do:** regenerate, and page anywhere you call `data.list` without
  an explicit `limit`. **`has('data.list')` cannot gate `after`** — it is a new
  *parameter* on a method that has existed since version 1, so it is true on a
  host that will reject the unknown field with `E_PARAMS`. Gate on
  `has('data.count')`, the sibling method that ships in the same version.
  **Not on `app.info().bridge >= 5`:** that field is your app's *own* schema
  `version`, which you number yourself, so it is already above 5 in any app
  that has added five methods of its own — and the comparison is then true on
  exactly the hosts that reject the param. A grown param's only honest gate is
  a sibling method or event at the same version.
- **A built-in can now grow an optional *param*,** not just an optional returned
  field. Before this, a built-in's params were compared literally, so adding one
  would have failed the next `codegen` in every existing app — and `--rebaseline`,
  which overwrites the schema your store build recorded, would have been the only
  way through. An app that has not declared `after` keeps generating code that
  compiles; declaring it at the wrong type, under another name, or on a different
  built-in is still refused, and your own methods still may not grow a param once
  a store build has recorded them.

### Upgrading could silently start your users on an empty database

Found by an independent team migrating a live app holding 30.8 MB of synced
data. **If you are on 0.3, read this before you ship the upgrade.**

- **The package now moves a 0.3 database out of the documents directory.** 0.4
  opens `<applicationSupportDirectory>/<databaseName>`. 0.3's spec never named a
  directory — it said only "outside `valence/`" — so a 0.3 host could equally
  have used `getApplicationDocumentsDirectory()`, and on Android those are two
  different places (`files` and `app_flutter`).

  The bug: such a host, migrated exactly as documented, created a **new, empty**
  database beside the full one and showed the user a fresh install. No error, no
  warning, and `host.database` could not fix it, because that setting names the
  file and the problem was the directory.

  The package now looks for the database in the documents directory when the
  support directory has none, and moves it before opening anything — the `-wal`
  and `-shm` sidecars included, and the `.db` last. Moving the `.db` alone would
  discard every commit still in the write-ahead log, which for a syncing app is
  the last sync. It never overwrites a database that is already there, and it
  logs one line saying what it moved.

  **What you must do:** upgrade the package, then confirm your row counts on a
  device carrying real data — install over the top with `adb install -r`, never
  uninstall first. If you already wrote a move of your own in `main()`, you can
  delete it; the package will find nothing to do.

### A background sync could fail the launch that migrated the database

- **A locked database open is retried, and a blocked background run reports
  `busy` instead of failing.** A schema migration runs in `BEGIN EXCLUSIVE`, and
  the launch that runs it is the launch WorkManager fires your already-registered
  periodic job on — so on every app update the UI isolate and the background
  isolate race for the file, and the loser gets
  `DatabaseException(database is locked (code 5 SQLITE_BUSY))`. The sync lease
  cannot help, because the lease lives inside the database being opened.

  The package now retries a locked open five times a second apart;
  `Valence.backgroundSync` then returns `reason: "busy"` rather than throwing,
  because nothing was attempted and the isolate holding the file is itself about
  to sync. `Valence.open` still rethrows, because an app with no store cannot
  start. A failed open is also no longer cached, which used to leave every later
  call in that isolate failing against a database that was by then healthy.

  **What you must do:** nothing. `busy` in a background run on an upgrade launch
  is expected and not a bug to chase.
- **The host guide's `backgroundSync` example now compiles.**
  `Workmanager().executeTask` wants a `Future<bool>` and `backgroundSync` returns
  a `ValenceSyncResult`, so the one-line example did not build. The guide shows
  the whole callback, and says to return `true` even for an offline or empty run —
  `false` is WorkManager backoff, and the package already has better triggers
  (resume, connectivity) waiting.

### An OTA release could silently not happen, and the rollback could not tell

Found by an independent team's deliberate-break test, and the most important fix
in this batch. **Read the first bullet even if you read nothing else here.**

- **Bundle files are no longer served `Cache-Control: immutable`.** They go out
  `no-cache` with the file's sha256 as an `ETag`, and a revalidation that matches
  is a `304` with no body.

  The bug: a bundle file's URL does not change between releases. The path comes
  from your web build and the host keeps its port across launches, so
  `/assets/index-Ba1jK_XS.js` means *different bytes in every release that emits
  that name*. Told it could keep its copy for a year, the WebView did: the new
  bundle downloaded, verified and activated, and the page on screen was still the
  old one. Worse, the update log said `committed` — a trial only asks that *some*
  page call `ready()`, and the old page obliged. The rollback that protects you
  from a bad release was being satisfied by the release it was testing.

  **What you must do:** nothing, if you use the `valence` package — upgrade it.
  If you wrote your own host, change that header. Content-hashed file names are
  not a defence: anything copied verbatim out of `public/` keeps its name.
- **`valence bundle` warns when your output registers a service worker.** A
  service worker answers from Cache Storage without asking the host's server, so
  a precaching build reopens exactly the hole above. Inside the app you do not
  need one — the bundle is already on the device. Register it only when
  `inHost()` is false.
- **`ready()` is owed by every path that paints, not by your data load.** The
  rule was always "after the first meaningful paint", and everybody implements
  that at the end of the data load, because that is usually where the first paint
  is. A first-run gate, an empty state, a permission prompt and an error screen
  all paint without that load finishing — and on a fresh install one of them can
  be the whole first launch. The bundle then never reports ready, and two
  launches later healthy code is rolled back and it looks like the OTA is broken.

  **What you must do:** check which of your screens reach the call. Putting it in
  a `finally`, or in a mount effect every rendered path reaches, is enough. The
  docs and the startup example now show that shape.

### A sync that was blocked said it had succeeded

- **`SyncResult` has a new `reason`:** `"ok"`, `"busy"` or `"offline"`. A run the
  one-at-a-time lease refused to start used to come back `{changed: 0, offline:
  false}` — bit for bit "you are already up to date" — so an app showing
  freshness showed a confident "just synced" over data nothing had looked at.
- **A lease left by a launch that is gone is taken over, not waited out.** The
  lease now records the owning process. It only ever separates the UI and
  background isolates, which share a process, so a foreign owner can only be a
  crash or a force-stop; before this the next launch was blocked for the full two
  minutes, across several launches and resumes, each one reporting that same
  false freshness. Worst right after a crash, which is when a user is least
  forgiving.

  **What you must do, to take `reason`:** add `"reason": "string?"` to your
  `SyncResult` type in `bridge.schema.json` and run `codegen`. It is optional —
  leave it out and nothing changes. It counts as additive even against a schema a
  `--store` build already recorded, so you do not need `--rebaseline`.

  **It is nullable on purpose.** A method carries `since` and is gated by
  `requires.bridge`; a field on a type carries neither, and your host ships in the
  APK while your page ships in a bundle. So a bundle that reads `reason` will land
  on hosts built before the field existed, and those hosts do not send it. Drop
  the null check only once the store build that has it is the oldest you support.
  This is the first time a built-in has grown a field, and the rule is general.

### Also in the host

- **Garbage collection is scheduled for the first post-frame callback**, not run
  inside the transition. Step 1 already pays for a manifest decode, a signature
  verify and a per-file hash in front of the first frame, and this also stops a
  two-strike marking from deleting CAS files under the trial page still on
  screen. It takes the sync lease before touching read-only pairs.
- **A refused built-in bundle is remembered** (`state.builtinRefused`), so a
  broken store build stops re-verifying an Ed25519 signature on every launch,
  and logs the refusal once per process rather than once per launch.
- **The host logs every bridge error it returns.** A handler that threw used to
  be invisible to everybody: the page's `await call(...)` rejected inside an
  effect nobody awaited, and nothing reached a log or a screen.

### Found by an independent review of the new packages

Each of these has a regression test, and the spec carries the rule.

- **A writable bucket is pulled as well as pushed**, at schema 1. It can never
  appear in a bundle's `requires.data`, so pulling only those pairs left user
  data push-only: a second device never saw a row, and a reinstall came back
  empty.
- **A mid-session reload runs §2.4 step 4 only.** Re-running the UI-start
  transitions made `bundle.applyUpdate` spend a strike on the bundle it was
  promoting, and made a ready timeout re-serve the failing trial rather than
  `current` — so the user saw the broken bundle twice, 15 s apart.
- **Garbage collection keeps the files of a download in flight.** Step 6 writes
  into the content-addressed store before step 8 writes the manifest that keeps
  them, so a collection in that window could delete what had just been fetched,
  and nothing re-fetched it.
- **A corrupt file of the bundle being *served* is re-fetched** by a repair pass
  before step 1. There is no step 6 to reach for a bundle that is already
  `current`, so a rotted entry page was a permanent blank screen.
- **A refused built-in bundle is remembered by its manifest bytes and the host's
  bridge version**, not by its seq, so the host upgrade that fixes a check-5
  mismatch is not skipped by the record meant to save work.
- **The seed is extracted once per host build**, not on every launch in front of
  the first frame.
- **The reserved `valence.` pref prefix is enforced in the store**, so an app
  that defines its own settings method cannot become a route to the sync lease.

### You may need to change your host

- **`bad` is final, in every path.** A bundle marked bad could come straight
  back as a trial, so the two-strike rollback never stuck and a phone could
  serve a broken UI for ever. Marking a trial bad now also drops a `pending`
  holding the same seq, promotion checks `bad`, and the update check stops on
  `trial` as well as on `current`.
- **§2.3 step 7 pulls.** It used to read as a passive check, which can never
  pass: ordinary sync only fetches the pairs the *active* bundle reads, so a
  read-only schema bump — or a brand-new bucket — had no route onto the device
  and the update parked for ever with nothing logged. The updater now takes the
  sync lease and pulls each missing `(bucket, schema)` pair itself.
- **Garbage collection runs after any transition that changed the kept set**,
  not only after a commit. A store release is the event most likely to make an
  old read-only pair collectable, and a commit-only GC never saw it.
- **An unusable built-in bundle is defined.** If it fails its checks nothing is
  promoted, it is never added to `bad`, and with no `current` the host surfaces
  the failed check instead of leaving a blank WebView.
- **SQLite pragmas go through `rawQuery`, and the database is never closed.**
  The documented `execute` form crashed on the first launch of a real Android
  host.
- **The Android back gesture** goes back through WebView history and closes the
  app only when there is none left.
- **Bridge messages are bounded** (`MAX_MESSAGE_BYTES`), in both directions,
  with a new `E_TOO_LARGE`. An oversized base64 image used to kill the WebView
  uncatchably.
- **`/_host/` is reserved** for the host's own routes, with a 404 for an unknown
  id rather than the SPA entry page, and `nosniff` + `default-src 'none';
  sandbox` on the response.

### CLI

- `bundle --store` no longer rewrites the recorded store schema when the change
  is not additive; `--rebaseline` is the deliberate way through, and either way
  the build prints what it recorded.
- `bundle --store` warns when a release channel still points below the seq it
  just wrote (cut the OTA release *after* the store build).
- `bundle --builtin/--store` refuses `--requires-bridge` above the schema
  version, which would make a host refuse its own built-in bundle.
- `bundle` warns when `requires.bridge` rises above the bridge version of the
  last store build, and separately when it is pinned below the schema version.
- `bundle` refuses a bundle file under `_host/` and warns on a relative asset
  base in the entry page.
- `verify --files` says the directory is wrong instead of naming the first file
  as missing.

### Docs and spec

- §6 has an Android half at last: §6.1 for local notifications and §6.2 for the
  home-screen widget, including that a widget is the one screen a Valence app
  **cannot** change over the air.
- Every stop in the update algorithm logs its step and what it is waiting for.
- Buckets are key-value only, and that is now said on the first page.
- **Android is tested; iOS is experimental and untested.**

Firebase dependencies now require iOS 15.0 or later, even with push disabled. Upgrade Runner/extension target settings; iOS remains experimental and untested.

Bridge success and error reply caps now include Unicode separator escaping; oversized errors retain only safe numeric correlation ids.
