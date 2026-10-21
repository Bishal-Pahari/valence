# Returning to an interrupted task

Valence keeps a small UI snapshot when Android reclaims a background process. Reopening
the retained task loads its path, query and hash on the current loopback origin. Removing
the task from Recents, force-stopping, or closing it with Back starts fresh. This is UI
continuity, not a database backup. Use `data.put` for durable records and `secure.*` for secrets.

Add the schema-5 built-ins from the template, run codegen, and ship a store build:

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

Source of truth: contracts §4.6; runtime `restoration.dart` and `app.dart`.
