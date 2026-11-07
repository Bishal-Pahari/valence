# R34 on a device: a tap after an OS kill goes where the user tapped

Android emulator `valence_test` (API 36), `packages/valence/example` debug build,
2026-11-07. Bundle 1793567181, bridge 20, host 1.

## What was checked

| # | Step | Result |
|---|---|---|
| 1 | Launch cold, tap **Save draft and route** | route `/shelf/fern?mode=draft#edit`, `state.restore: {"draft":"fern draft"}` ([screenshot](r34-evidence/before-kill-route-and-draft.png)) |
| 2 | Home, wait, `adb shell am kill com.getvalence.example` | `pidof` empty: the OS reclaimed the process and kept the task |
| 3 | Return by the link, not from Recents: `am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d 'valence-example://app/' -p com.getvalence.example` | **pre-empted** — see the log below |
| 4 | Read the page | route `/`, `state.restore: {"draft":"fern draft"}` ([screenshot](r34-evidence/after-link-preempted.png)) |
| 5 | **Control:** save the route again, Home, `am kill`, relaunch from the launcher with no link | route restored unchanged, no pre-emption line ([log](r34-evidence/control-relaunch.log)) |

Step 3's log, which is the whole item in one line:

```
restoration: a link launch destination pre-empts the restored route /shelf/fern?mode=draft#edit; starting at / and keeping the saved draft
serving bundle 1793567181 on http://127.0.0.1:11441
webview finished http://127.0.0.1:11441/
```

Step 5's, for contrast:

```
serving bundle 1793567181 on http://127.0.0.1:11441
webview finished http://127.0.0.1:11441/shelf/fern?mode=draft#edit
```

## Two things worth knowing for the next run

**`am start` with a custom scheme and no package shows the resolver.** `am start -a VIEW -d
'valence-example://app/'` on its own opened `com.android.internal.app.ResolverActivity` rather than the
app. Adding `-p com.getvalence.example` (and `-c android.intent.category.BROWSABLE`) delivers it
straight to the app, which is what a real tap on a verified link does.

**`am start` can report "Activity not started, its current task has been brought to the front" and still
be the launch under test.** The activity record outlives the killed process, so Android resumes the task
rather than creating a new one — and then recreates the activity from the restoration bucket *with* the
intent. That is precisely the collision R34 is about, and it is what produced the log above. Do not read
that warning as "the link did nothing".

## Not covered here

iOS, which is experimental and untested. The notification and push mailboxes take the same code path
and are covered by unit and widget tests, but only the link half was exercised on the device, because
the example app has no scheduled reminder to tap. A notification cold start on a device is the next
honest step and belongs to whichever test app schedules one.
