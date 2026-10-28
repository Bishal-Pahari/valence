# Startup and database wait diagnostics

R29 implements contracts section 5.1.1. Upgrade the Flutter `valence` runtime and
ship a host build to get these logs. No bridge schema, codegen, template config or
web client change is required; this is native observation, with no version bump.

`Valence.open` logs phase entry and completion using its existing `log` callback
(by default `[valence]` in logcat). Phases are `binding`, `links`, `directories`,
`store`, `state`, `services`, `notifications` when enabled, `seed`, and `push` when
configured. `elapsedMs` is time since `open` began; `phaseMs` is time in that phase.

```
startup: phase=store status=begin elapsedMs=12 phaseMs=0
startup: phase=store status=complete elapsedMs=48 phaseMs=36
startup: phase=state status=begin elapsedMs=48 phaseMs=0
```

`status=failed` names the active phase and the original error is rethrown unchanged.
`startup: complete` establishes that `open` returned; the host widget still has to
start its server, verify/select a bundle, create a WebView and receive `ready()`.
A missing completion identifies the last observed phase, not the cause of a stall.

Runtime database operations pending for ten seconds produce a line every ten
seconds until they finish, followed by `completed` or `failed`:

```
store: waiting operation=store.get id=23 isolate=789 elapsedMs=10002
store: completed operation=store.get id=23 isolate=789 elapsedMs=10831
```

Match the operation id within its isolate. Labels identify reads, writes, seed
import, prefs, opening/configuration, sync status, observation writes and lease
acquisition. Confirmed lock errors and existing lock retries also name the
operation. Waiting does not prove a SQLite lock or identify its holder: sqflite
scheduling and execution can also be pending. Timers depend on the Dart event loop;
a stalled engine may emit no wait line at all. These are diagnostics, not timeouts.
Direct app/plugin queries through `store.db` are outside this instrumentation.

Labels contain no SQL, arguments, paths, keys, values, tokens or account ids.
Concurrent operations have separate ids. Fast operations produce no wait logs;
timers stop on success or error. The first opener of a cached store in an isolate
chooses its logger; direct `ValenceStore.open` callers can supply `log` too.

For a recurrence, capture app-scoped logcat and `adb shell dumpsys activity
exit-info <app-id>` before restarting. Record build/snapshot revision and whether
the emulator had completed booting. Preserve the database and account; a successful
restart does not establish a root cause. Keep captures local and check existing
app/native logs for private data before sharing them.

Decision: instrument pending database futures at their existing boundaries, keeping
transaction executors, lease ownership, lock classification, retries and data
unchanged. The app-a F-33/F-35 evidence establishes symptoms, not a runtime cause.
This change supplies evidence for the next recurrence and does not close them.
Unit tests exercise held futures, concurrent store/sync boundaries, timer cleanup,
error identity/trace, logger failure and startup phase order/failure. Device
validation remains separate; iOS is experimental and untested.
