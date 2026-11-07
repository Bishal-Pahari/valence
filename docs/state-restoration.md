# Returning to an interrupted task

Valence keeps a small UI snapshot when Android reclaims a background process. Reopening
the retained task loads its path, query and hash on the current loopback origin. Removing
the task from Recents, force-stopping, or closing it with Back starts fresh. This is UI
continuity, not a database backup. Use `data.put` for durable records and `secure.*` for secrets.

Add the schema-8 built-ins from the template, run codegen, and ship a store build:

```ts
import { call, connect, has } from './valence/bridge.g';

await connect();
if (has('state.restore')) {
  const previous = await call('state.restore');
  // Validate your own blob's shape before using it to fill controls.
}
if (has('state.save')) {
  await call('state.save', { json: { draft: 'Fern care notes', scroll: 120 } });
  // Later: await call('state.save', { json: null });
}
```

Save on meaningful UI changes; a shutdown callback may never run. The limit is 65,536
bytes of compact JSON encoded as UTF-8, including quotes and escapes. `E_PARAMS` leaves
the previous blob intact. `state.restore` returns the latest blob repeatedly, including
in the same process; null means nothing was saved. Navigation tracking is automatic,
including History API and hash changes. Only a bounded local route can be restored;
host-file routes and encoded traversal are refused.

`ValenceApp` installs its own `RootRestorationScope`; no change to `MaterialApp` is needed.
The snapshot uses Flutter's OS task restoration, not SQLite or `state.json`. A newly
verified bundle with a different seq (including rollback) discards both route and blob.
The new page must still call `ready()` after painting; restoration never commits an OTA.
Only the current URL is restored, not the browser's full Back stack.

## A tap beats the saved route

Tapping a reminder, a deep link or a push notification tells the host where to go, and the saved route
only guesses. Both arrive together on a cold start — Android restores the task *and* delivers the
intent — so a host that loads the saved route first shows the screen the user left, then lets the page
correct it: a flash at best, and the wrong screen for good if your router reads the initial URL once at
mount.

So when any launch mailbox holds a destination, the host opens `/` and leaves the destination to your
page, which is the only place that can see all of them (see [deep links](deep-links.md) for the rule
across sources). The log says so:

```
restoration: a link launch destination pre-empts the restored route /shelf/fern?mode=draft#edit; starting at / and keeping the saved draft
```

**Your draft is not dropped.** Only the route goes: `state.restore()` still returns what you saved, so a
half-written form survives a reminder tap. Nothing changes for an ordinary return to a reclaimed task —
no tap, no pre-emption, the route restores as before. Reading the mailbox does not consume it, so
`link.initial()` and `notify.initial()` still answer your page exactly once.

**Two things to know if you use both halves.** This is the one case where the blob outlives its route:
a draft saved at `/day/X` is still returned after a tap sends you to `/day/Y`, so **if your blob only
makes sense at one route, put that route inside the blob and check it against `location` before you
apply it.** And a tap counts as a destination whether or not your payload names one — the host never
parses your payload, so a "backup complete" notification pre-empts the route too, and you land on `/`
with nothing to route to. If your notifications do not name destinations, expect that.

Snapshots also follow the native account: switching accounts or signing out clears the route and draft. Same-account refresh and first-account adoption keep the live draft. Startup checks an account fingerprint against secure storage before restoring, so a stale OS snapshot cannot expose the previous user's UI state. The page must redraw its own live account UI after switching; restoration does not erase the DOM.

For custom native hosts, use the Flutter restoration APIs to preserve the runtime's
task-local model; simply calling `Valence.open` does not enable widget restoration.

Android check: install the example APK, tap **Save draft and route**, press Home, wait
for the background snapshot, then `adb shell am kill com.getvalence.valence_example`. Confirm
the PID is gone and reopen its existing task from Recents. Expect
`/shelf/fern?mode=draft#edit` and the saved draft. Repeat with force-stop, removal from
Recents, and Back from a fresh root: those should show `/` and null.

For the pre-emption, do the same up to the kill and then come back by the link instead of from Recents:
`adb shell am start -a android.intent.action.VIEW -d 'valence-example://app/'`. Expect `/`, the
`pre-empts the restored route` line in logcat, and the draft still there.

iOS is experimental and untested. Assign a restoration identifier to the
`FlutterViewController` in `ios/Runner/Base.lproj/Main.storyboard`; the example has
`restorationIdentifier="valence.page"`. Follow [Flutter's restoration setup](https://api.flutter.dev/flutter/services/RestorationManager-class.html)
for native embedding and device testing. OS snapshots are best effort on either platform.

Source of truth: contracts §4.8; runtime `restoration.dart` and `app.dart`.

If secure storage cannot confirm the account at startup, the host discards the snapshot and opens the verified root page so public/offline startup still works.

Account-changing calls are serialized in the host, and a refusal does not block later attempts. An app refresh loop must cancel an outstanding refresh when the user changes, or pass the correct explicit account id; a refresh without an id cannot tell the host whose token it is. Interrupted secure writes can leave the new account recorded without a token; retry sign-in to repair it.
