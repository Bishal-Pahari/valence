# Local reminders and badges

Local notifications are built into schema 11. They run from the OS scheduler, including when the page
is closed. Android is the tested platform; iOS paths are experimental and untested.

Opt in in `valence.config.json`, run codegen, and ship a store build:

```json
"notifications": { "enabled": true, "icon": "ic_stat_valence" }
```

The default is disabled. A schema can omit the group. Existing app-specific `notify.daily` handlers
can coexist, but their IDs share the same native scheduler: reserve distinct ID ranges. Custom notification or badge methods declared with since below 11 remain app-owned, with their shipped signatures intact. Only since-11+ declarations use the built-in delegation. Keep a shipped custom method unchanged; use your app adapter to call the native service, or adopt the standard name only if it has never shipped.

## Keeping a shipped custom tap event

A pre-11 `notify.tapped` event stays app-owned, including a string ID. Regenerate with the
updated CLI: `hostNotificationEventFields` in `bridge.g.dart` lets the runtime emit only compatible
since-11+ events and only their declared fields. An omitted or legacy event is not emitted
automatically. Existing generated hosts need codegen and a new store build for this protection.
Do not change the shipped event, its `since`, or the baseline to adopt native scheduling.

An event qualifies for automatic emission at `since: 11` or above with `id` declared `int` — what the
native scheduler actually produces. Anything else stays yours, and codegen **warns rather than
refusing**, naming `notificationEventAdapter`: your shipped event cannot be changed (that is the
additive-only rule), so a refusal would leave you nothing but a rebaseline. Read those warnings —
without an adapter the tap is not delivered at all, and `has('notify.tapped')` is answered from your
schema, so it stays `true` and your page waits for an event that never comes. The host logs that once
per event name too. A field you declare that a response does not carry (`id`, `payload`, `action`) is
left out of the emitted event rather than sent as null, and warned about.

Pass `notificationEventAdapter` to `Valence.open` to convert warm responses into your generated
event script. It replaces automatic warm emission for both taps and actions; return null for
responses your event cannot represent. For example, for the shipped
`notify.tapped {id: string, payload: string?}` and an app payload `{id, p}`:

```dart
import 'dart:convert';

import 'package:valence/valence.dart';

import 'valence/bridge.g.dart';
import 'valence/config.g.dart';

Map<String, Object?>? legacyTap(Map<String, Object?> response) {
  if (response['action'] != null) return null; // No action event shipped in this app.
  final payload = response['payload'];
  if (payload is! String) return null;
  try {
    final app = jsonDecode(payload);
    if (app is! Map || app['id'] is! String || app['p'] is! String) return null;
    return {'id': app['id'], 'payload': payload};
  } on FormatException {
    return null;
  }
}

String? legacyTapScript(Map<String, Object?> response) {
  final tap = legacyTap(response);
  return tap == null ? null : BridgeEvents.notifyTapped(
    id: tap['id'] as String, payload: tap['payload'] as String?,
  );
}

Future<Valence> openHost() => Valence.open(
  valenceConfig, notificationEventAdapter: legacyTapScript,
);

// Call from your app-owned launch accessor after the page subscribes to warm events.
Future<Map<String, Object?>?> legacyInitial(Valence valence) async {
  final response = await valence.notifications.initial();
  return response is Map<String, Object?> ? legacyTap(response) : null;
}
```

The service unwraps its internal envelope before the adapter. Keep the original application ID
inside the application's payload when scheduling; a hashed integer scheduler ID cannot recover it.
Validate the payload's target against your domain before navigation. Neither this example nor the
runtime evaluates a payload as code. The adapter runs after the native envelope/size/ID/action
checks. An adapter exception drops the event and logs a fixed message without private contents.
Use generated builders for escaping — and the runtime checks that you did: an adapter result that is
not something `BridgeEvents` could have produced is dropped with a log, so a hand-concatenated string
whose payload contains a quote never reaches the page as code. Startup buffering remains bounded to
the newest 16 warm events.

Cold responses are separate and consumed once: they never also emit a warm event. Apply the same
conversion in your existing cold accessor/replay, as `legacyInitial` illustrates; retain your own
contract for whether that accessor consumes or caches its result. Never initialize
`FlutterLocalNotificationsPlugin` a second time to replace Valence's callback: that bypasses the
runtime's envelope decoder. Old alarms scheduled by a legacy plugin remain the app's migration
responsibility. This adapter handles responses scheduled by Valence's native service.

## Standard notification events

Import `call`, `has` and `on` from your generated `bridge.g.ts`. Guard new calls with `has()` when
the same web bundle serves older store builds. Install listeners before consuming the launch tap:

```ts
on('notify.tapped', ({ id, payload }) => showReminder(id, payload));
on('notify.action', ({ id, action, payload }) => handleAction(id, action, payload));
const initial = has('notify.initial') ? await call('notify.initial') : null; // consumes once
// Validate initial and payload for your own domain before acting. Never evaluate a payload.
if (has('notify.schedule') && await call('notify.permission', { request: true })) {
  const result = await call('notify.schedule', {
    id: 42,
    title: 'Water the fern',
    body: 'Check the soil first',
    at: Date.now() + 60_000,
    exact: true,
    payload: 'plant:fern',
    actions: ['done', 'snooze'],
  });
  // result.timing: exact, inexact, system (iOS), or blocked (nothing scheduled).
}
```

`notify.permission()` only checks. `{request: true}` prompts for notification authorization; it
does not request Android exact-alarm special access. An exact request downgrades to `inexact` if
access is absent or revoked during the call. Even `exact` means the OS accepted that mode, not that
delivery was observed: channel settings, power management and vendor restrictions still apply.
Do not label `inexact` as an on-time reminder. `blocked` adds nothing and leaves any existing ID intact.

`at` is a future Unix millisecond instant within 366 days. Reminders are one-shot absolute times,
so a phone timezone change does not move them. For “6 AM local time every day”, calculate a rolling
window using the user's IANA timezone and rebuild it after timezone/settings changes. Cancel obsolete
pending IDs by difference; retain IDs that are still desired. `notify.cancel({id})` also dismisses a
displayed notification, so cancel-all is unsuitable for simply refilling a window. Reboot receivers
restore accepted Android requests when the OS delivers the boot broadcast. Android can defer that delivery; [background restrictions](https://developer.android.google.cn/about/versions/13/behavior-changes-13?hl=en) can require another app start. Force-stop requires opening the app again. Revoking exact access
can remove already scheduled alarms, so refill after permission changes.

`notify.pending()` reads the native queue and returns `{id,title,body,payload}[]`. IDs are
0..2147483647; a repeat ID replaces the request. The queue cap is 64 (replacement is allowed at the
cap). Pending means queued, never delivered. Title/body/payload limits are 256/4096/4096 UTF-8 bytes.

**For the cancel-by-difference above, read `notify.pendingIds()` (schema 16) instead.** It returns the
same native snapshot as bare `int[]`. A full queue of maximum-size requests is about 540 KB, over the
bridge's 256 KB reply cap, so `notify.pending()` is refused with `E_TOO_LARGE` on exactly the apps
that keep the most reminders queued. The IDs are about 400 bytes and cannot grow past the cap.
`notify.pending()` is unchanged and still the right call when the titles or payloads are wanted and
the queue is small.

```ts
const ids = has('notify.pendingIds')
  ? await call('notify.pendingIds', {})
  : (await call('notify.pending', {})).map((r) => r.id);
for (const id of ids) if (!wanted.has(id)) await call('notify.cancel', { id });
```

Actions are the compiled `open`, `done`, `snooze` IDs, with English labels; every action opens the UI.
The app decides what Done and Snooze mean. Reply inputs and custom layouts are deferred.

Declare `notify.pendingIds` with `since: 16`, regenerate and ship a store build.
A host with notifications disabled returns `E_UNSUPPORTED`. Each call reads one native queue
snapshot; two calls can observe different snapshots. Reading IDs never cancels or re-arms requests.

If the older-host `notify.pending()` fallback reports `E_TOO_LARGE`, stop reconciliation and show
the error. Do not treat the failure as an empty queue or cancel unknown/displayed notifications.

For an image, pass base64 PNG/JPEG in `image`: maximum 96 KiB decoded and 1024 pixels per side.
URLs, filesystem paths, SVGs and corrupt pixel data are refused. Header limits precede a bounded
pixel decode so an invalid image cannot silently disappear from an accepted request.
Android uses a big-picture style; iOS uses a private
attachment. iOS source files are pruned to pending IDs and replaced/cancelled files are removed.
The bridge's whole-message limit still applies. Keep images small and size them before encoding.

Create channels before scheduling:

```ts
await call('notify.channels.set', {
  id: 'care', name: 'Plant care', importance: 'high',
  group: 'plants', groupName: 'Plants', sound: 'care_chime',
});
await call('notify.schedule', { id: 43, title: 'Check soil', at: Date.now() + 60_000, channel: 'care', group: 'care_tasks' });
const accepted = await call('badge.set', { n: 3 });
await call('badge.clear');
```

Channel importance is `min`, `low`, `default`, `high`, `max`. Omit sound for the default; use `''`
for silence or a bundled `res/raw` resource name. IDs and resource names are lowercase ASCII
identifiers up to 64 characters. Group names can be human-readable. Existing channel importance and
sound are controlled by Android and the user; use a new ID to introduce another policy. Notification
`group` groups tray entries; channel `group` groups settings. The default channel is `valence_reminders`.
On iOS channel configuration is a validated no-op. Badge count is 0..9999; the boolean reports platform
acceptance, not visible pixels. iOS checks badge authorization separately. Android is best effort,
depends on the launcher, and may need manufacturer permissions and an active notification.

## Android setup

The package depends on `flutter_local_notifications` 22.3.2+, `timezone` 0.11 and `app_badge_plus`
1.3.5+. These resolve together with `connectivity_plus` 7.3.2 without the old dbus override.
App-owned Dart code using an older notification plugin must adopt the 22.x named-parameter API or delegate to the built-in service; preserve any shipped bridge signature. Desugaring is required even for a host which has not enabled local notifications.
In `android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk = 36 // at least 35
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Use the permissions and receivers in the example's AndroidManifest.xml (or the skill's
`templates/notifications.android.xml`): POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED,
ScheduledNotificationReceiver, ScheduledNotificationBootReceiver and ActionBroadcastReceiver.
Missing receivers can produce successful scheduling with no notification ever delivered.
Declare SCHEDULE_EXACT_ALARM only if the product needs exact scheduling and meets Play requirements;
the built-in never declares USE_EXACT_ALARM. Without special access it returns `inexact`.

Bundle a white status drawable `res/drawable/ic_stat_valence.xml`. Keep it and custom raw sounds
through resource shrinking with `res/raw/keep.xml`, for example
`<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_valence,@raw/care_chime"/>`.
See the package [setup](https://pub.dev/packages/flutter_local_notifications#-android-setup) and
[badge permissions](https://pub.dev/packages/app_badge_plus) for launcher-specific permissions.
Run a release build as well as debug when adopting resource shrinking.

## iOS setup (experimental and untested)

Import `UserNotifications` in AppDelegate and set `UNUserNotificationCenter.current().delegate = self`
in `didFinishLaunchingWithOptions`, as in the example. Initialization installs action categories
without prompting; the explicit permission call asks for alert, sound and badge authorization.
The system controls delivery timing. Images use native attachments. No iOS device pass is claimed.

## Verify adoption

Check permission denied and granted; schedule N seconds out and actually observe the notification;
tap its body and each action while the app is warm and after its process is stopped; consume initial
twice and expect null the second time. Check pending/cancel, an image, channels and exact denial.
Keep a future reminder through a timezone/clock change and reboot. Refilling a rolling window should
leave unrelated displayed notifications visible. Unit tests and successful scheduling alone cannot
prove delivery. Contracts §6.5 and §8 define the minimum package and device checks.
