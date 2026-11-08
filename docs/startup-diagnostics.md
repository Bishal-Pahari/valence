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

## Time app-owned initialization

An app may await media, reminder or link setup after `Valence.open` and before
`runApp`. Those awaits are outside the runtime phases. Time the existing calls
in their existing order before assigning a cause to the gap.

This helper belongs in your host code. Keep labels fixed at source; never pass
a route, file path, token, user value or exception into the log.

```dart
import 'package:flutter/widgets.dart';

enum AppStartupPhase { media, reminders, links }

void startupLog(String message) {
  try {
    debugPrint(message);
  } catch (_) {
    // Diagnostics must not change startup or replace an initialization error.
  }
}

Future<T> timeAppStartup<T>(
  AppStartupPhase phase,
  Future<T> Function() action,
) async {
  final watch = Stopwatch()..start();
  void report(String status) => startupLog(
    'app-startup: phase=${phase.name} status=$status '
    'phaseMs=${watch.elapsedMilliseconds}',
  );
  report('begin');
  try {
    final result = await action();
    report('complete');
    return result;
  } catch (_) {
    report('failed');
    rethrow;
  } finally {
    watch.stop();
  }
}

void markFirstFlutterFrame() {
  final watch = Stopwatch()..start();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    watch.stop();
    startupLog(
      'app-startup: boundary=firstFrame elapsedMs=${watch.elapsedMilliseconds}',
    );
  });
}
```

For example, wrap an existing `await initializeMedia()` as
`await timeAppStartup(AppStartupPhase.media, initializeMedia)`. Use the same
pattern for your other existing setup calls, preserving their results and order.
After the existing binding initialization, call `markFirstFlutterFrame()`
immediately before your existing `runApp`. The marker's elapsed time starts at
registration, separately from runtime startup and each app phase.

A `begin` without a matching completion locates the last observed await; it
does not prove a deadlock or identify a blocking plugin. A `firstFrame` can be
only a Flutter loading screen. Meaningful web paint and the web app's existing
`ready()` call remain separate observations; do not call `ready()` from this
callback. Keep the failed attempt, process IDs and resource conditions alongside
any successful retry. These observations add no retries or timeout changes and
do not justify clearing the account or database.

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

## A `busy` sync names its holder (S9, revision 20)

A `busy` reply means a run was refused because another one holds the §5.6 sync
lease. The log says which, and for how long it had held it:

```
sync: took the lease kind=background pid=4893 (dated 2951ms ago)
sync: another sync holds the lease; skipping this run holder=background heldForMs=7001 refused=foreground
sync: released the lease kind=background heldForMs=11280
```

`kind` is `foreground` (UI start, resume, reconnect, `sync.now`, or an update
check's data pull), `background` (the periodic job) or `push`. The same two facts
reach the page through `sync.status().leaseKind` and `.leaseAgeMs`.

**It names the class of run, not the individual run.** The UI isolate has one
sync driver, so two foreground triggers overlapping — the UI-start sync and the
connectivity sync, which fire milliseconds apart on a reconnect — read
`holder=foreground refused=foreground`. That rules out the background isolate,
which is usually what the question is about; to tell the two foreground triggers
apart, read the trigger lines immediately above (`sync: connectivity came back`,
`update: ...`) and match the refused run's `heldForMs` against the holder's
take-time, found as described next.

**Date a hold from `(dated <n>ms ago)`, not from the `took the lease` line's own
timestamp** (K F-85). The line is written after the time it records: the row
insert, the commit and the hops back out all sit in between. Without the trail,
bracketing `took` and `released` understates the hold — on a loaded device the two
lines sat 91 ms apart around a hold the host correctly reported as
`heldForMs=3039`, a factor of 33. It is not the database wait: the clock is
sampled after that wait on purpose (K F-83), and the store's own `waiting` line
is what reports it. The trail never goes negative.

Every `heldForMs` — on a refusal and on a release alike — is measured from when
the holder took the lease, so subtracting it from its own line's timestamp lands on
the take-time: the `took the lease` line's timestamp **minus its own trail**.
Before `0.4.0-beta.0` the refusal lines measured from
the host's internal lease renewal, which happens after every applied page, so
during a long sync the number counted up from zero again on each page and a
refusal could report tens of milliseconds for a lease minutes old (K F-81). Only
the release line was right. In logs from an older build, date the holder from its
`took the lease` line and ignore the refusals' number.

**The pair of lines is the signal.** A `took the lease` with no matching
`released the lease` is a run torn down while holding it — a cancelled WorkManager
job runs no cleanup — and the background isolate brackets its whole run too:

```
sync: background isolate entered kind=background pid=4893
sync: background isolate left kind=background pid=4893
```

An `entered` with no `left`, followed by `busy` replies naming
`holder=background`, is a lease a cancelled isolate did not give back. The next
run takes it over once it passes the two-minute expiry, so it is slow rather than
permanent — but it is now visible in the log rather than inferred from a `busy`.
That is what makes it reportable; include these lines, `dumpsys activity
exit-info` and the PID.

One line per refusal, not per retry, so the account-switch wait and the update
check's five-second wait do not fill the log. The take and release lines come from
the lease primitives, so the paths that acquire without a full run — step 7's pull,
the GC's pair step, the account switch — are bracketed too.

No lease deadline or takeover rule changed. A lease past its expiry, dated in the
future, or left by a process that is gone is taken over as before, and **each of
the three now says which it was**:

```
sync: taking over a lease (kind=background, written 183001ms ago): past its 2-minute expiry
```

One thing to know about a `heldForMs` above 120000 on a release line: the lease
had already expired and may have been taken over mid-run, and the release deletes
the row unconditionally — so it clears the new holder's lease out from under it.
That is pre-existing behaviour, not new here, and this number is the first thing
that makes it visible.

## A WebView eviction writes no host line, and that is the signature

S5, contracts section 3 ("Renderer loss"). The WebView runs the page in a separate,
lower-priority process. Android kills that one first under memory pressure, and
because `webview_flutter_android` 4.14.1 — the newest release — exposes no
`onRenderProcessGone`, the WebView then kills the host process about 70 ms later
with no Dart frame in between. There is no failed phase, no exception and no ANR to
find. Read it out of exit-info instead: a renderer at `reason=3 (LOW_MEMORY)` and
the host at `reason=2 (SIGNALED) status=9`, `importance=400`, in the same second.

```
lowmemorykiller: Kill '…SandboxedProcessService0:0' (19933) … min watermark is breached
chromium: [ERROR:…/aw_browser_terminator.cc:124] Render process (19933) kill (OOM or
          update) wasn't handed by all associated webviews, killing application.
```

Correlate full logcat timestamps and PIDs with exit-info. The Chromium termination
line establishes unhandled renderer loss for that process; the exit reasons alone
do not establish the cause. An ANR names the affected package in
`dumpsys activity anr`; a direct lmkd kill of the host names the host package in the
`lowmemorykiller` line. A renderer callback cannot prevent a direct host kill.
Neither a successful restart nor this signature establishes a Valence memory leak
or rules out memory use by the app.

**A direct host kill is a separate case and the log is what separates them.** When
lmkd names *your* package and the host's own exit reason is `reason=3 (LOW_MEMORY)`
with no Chromium termination line, the renderer was not the cause and no callback
could have helped — the OS reclaimed a backgrounded process. It is likeliest during
an excursion to another app (native Settings, a picker, the camera), and the user
comes back to a cold start. Capture logcat and exit-info before letting the app
restart; an ordinary relaunch overwrites the evidence. Durable data survives either
way; the task snapshot behind `state.restore` is best effort (contracts section 4.8),
so a dropped task starts at `/` with null. Nothing keeps the process alive
(app-c F-50).

0.4 cannot prevent it on Android; the shim is priced for 0.5. Because no host code
runs, `serving` survives in `state.json` and the next UI start cannot tell the
eviction from a bundle that crashed the app, so an eviction during a trial spends
one of its two section 2.4 strikes. Where a platform reports the loss — iOS, as a
`webContentProcessTerminated` resource error — the host reloads the same manifest at
the same route, counts no strike, and at the cap drops the controller and clears
`serving`, retaining `trial` and its failure count for retry on the next launch.
At the cap the host shows its error view; below it the page sees a reload. A recovery
while the app is backgrounded arms the ready window without starting it, and the resume
starts it: the window counts foreground time and is stopped by the pause transition,
already delivered by then, so a clock started there would run unwatched and spend a
strike on a release that was never on screen.
A resume that reclaims the same port reloads the page when none is
loaded. Unit tests cover all three; the Android half is unobservable from Dart by
construction, and a tripwire test fails when the plugin exposes the callback.

For a recurrence, capture app-scoped logcat and `adb shell dumpsys activity
exit-info <app-id>` before restarting. Record build/snapshot revision and whether
the emulator had completed booting. Preserve the database and account; a successful
restart does not establish a root cause. Keep captures local and check existing
app/native logs for private data before sharing them.

## External camera and picker failures

Record the foreground activity's package and the package named in the ANR before
recovery. An input-dispatch ANR in `com.android.camera2`, as in app-c iteration 37,
is external camera evidence, not proof of a Valence host ANR or renderer eviction.
Preserve full logcat, exit-info and the ANR record, exclude the failed capture,
then verify that a separate retry returns a decodable image. Success on retry does
not identify or repair the first failure. Preserve host data/account and record
any process stop or reset. Custom media handlers own their cancellation/error
results; no automatic recovery is added by these diagnostics.

Decision: instrument pending database futures at their existing boundaries, keeping
transaction executors, lease ownership, lock classification, retries and data
unchanged. The app-a F-33/F-35 evidence establishes symptoms, not a runtime cause.
This change supplies evidence for the next recurrence and does not close them.
Unit tests exercise held futures, concurrent store/sync boundaries, timer cleanup,
error identity/trace, logger failure and startup phase order/failure. Device
validation remains separate; iOS is experimental and untested.
