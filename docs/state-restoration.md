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

Snapshots also follow the native account: switching accounts or signing out clears the route and draft. Same-account refresh and first-account adoption keep the live draft. Startup checks an account fingerprint against secure storage before restoring, so a stale OS snapshot cannot expose the previous user's UI state. The page must redraw its own live account UI after switching; restoration does not erase the DOM.

For custom native hosts, use the Flutter restoration APIs to preserve the runtime's
task-local model; simply calling `Valence.open` does not enable widget restoration.

Android check: install the example APK, tap **Save draft and route**, press Home, wait
for the background snapshot, then `adb shell am kill com.getvalence.valence_example`. Confirm
the PID is gone and reopen its existing task from Recents. Expect
`/shelf/fern?mode=draft#edit` and the saved draft. Repeat with force-stop, removal from
Recents, and Back from a fresh root: those should show `/` and null.

iOS is experimental and untested. Assign a restoration identifier to the
`FlutterViewController` in `ios/Runner/Base.lproj/Main.storyboard`; the example has
`restorationIdentifier="valence.page"`. Follow [Flutter's restoration setup](https://api.flutter.dev/flutter/services/RestorationManager-class.html)
for native embedding and device testing. OS snapshots are best effort on either platform.

Source of truth: contracts §4.7; runtime `restoration.dart` and `app.dart`.

If secure storage cannot confirm the account at startup, the host discards the snapshot and opens the verified root page so public/offline startup still works.

Account-changing calls are serialized in the host, and a refusal does not block later attempts. An app refresh loop must cancel an outstanding refresh when the user changes, or pass the correct explicit account id; a refresh without an id cannot tell the host whose token it is. Interrupted secure writes can leave the new account recorded without a token; retry sign-in to repair it.
