# Testing the host widget

The runtime's `packages/valence/test/app_widget_test.dart` pumps the real `ValenceApp`. Run it from
`packages/valence`:

```sh
flutter test test/app_widget_test.dart
```

The test-only WebView platform in `test/webview_stub.dart` captures navigation callbacks, JavaScript
channels, page loads and scripts. Unsupported native operations throw rather than silently succeeding.
The fixture uses real signed bundles, a temporary SQLite database and a real loopback server. OTA and
sync use an in-memory HTTP client; connectivity and external launching use platform-channel stubs.
No signing keys are checked in. No runtime test hooks or bridge schema changes are needed.

The cases cover:

- I-61: resume while startup is held open updates lifecycle state but runs no update, sync or resumed
  event. Releasing startup runs the normal triggers.
- Navigation: same-origin routes work; reserved host documents, another port, another host and
  off-origin subframes are refused. Only allowed main-frame external URLs launch outside the app.
- The JavaScript channel receives the bound server's nonce and returns the serialized bridge reply.
  The back callback consumes WebView history before asking the OS to close the app.
  Strict decoding and nonce rejection remain in the generated-dispatch and wire tests.
- One-shot events flush once, reloads buffer again, and lifecycle state is re-derived rather than
  replayed from a stale queue.
- A ready trial commits; a foreground timeout counts one strike and loads current without consuming
  the next launch's retry. Background time counts nothing. Current and late-ready pages do not commit.
- Disposal cancels lifecycle/connectivity/update/ready triggers, closes the socket and leaves the
  user database open.

Flutter's fake clock does not advance a Dart `Stopwatch`. Page-start callbacks therefore run through
`tester.runAsync`, using a short configured ready timeout and real ticker deadlines. The tests also
wait beyond the configured update interval when checking disposal. File/socket/SQLite work drains
between frames with bounded polling. Do not replace these waits with `pump(Duration(...))`: that could
pass without exercising the real timers. The default Flutter HTTP stub is temporarily removed so the
resume liveness probe really reaches the loopback socket; it is restored after each test.

Keep these tests in the runtime package. App suites test their handlers and generated wiring; they do
not need to copy the host state machine. This harness does not render HTML, execute JavaScript, prove
native WebView isolation, or replace offline/rollback checks on Android. Android device evidence is
separate; iOS remains experimental and untested. See contracts §8 and the
[local testing guide](https://getvalence.pages.dev/docs/guides/local-testing/).
