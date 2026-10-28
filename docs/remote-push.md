# Remote push

Contracts section 6.4. New methods/events use `since: 12`; regenerate the schema and ship
a store build. Remote push is an opt-in **native dependency**: install `valence_push`
only in push hosts. `valence` alone has no Firebase dependencies; local notifications
and badges remain in core. Removing the package and rebuilding the host removes
its Firebase SDKs, unless another app dependency supplies them. A Dart flag or
omitting `push.*` cannot remove installed native SDKs. Review the resolved package
graph and final binary before completing store disclosures.

Android delivery is **blocked: needs Firebase project** for the device check.
iOS/APNs and its rich-image extension are experimental and untested.

The reserved `since: 12` identifies this addition in Valence's template. An app
maintains its own additive schema history; gate calls and events with `has()`
from its regenerated bridge rather than comparing `app.info().bridge` to 12.
Update the generated bridge and `@getvalence/bridge` together: current generated
code supplies both method and event availability tables.

## Configure the native host

Add `valence_push: ^0.4.0-beta.0` to your host's dependencies. For this unreleased
checkout, use a path dependency to `packages/valence_push` and override `valence`
to the matching core checkout. Keep `firebase_core: ^4.14.0` and
`firebase_messaging: ^16.7.0` as direct dependencies when your Dart code imports
them. These versions preserve the registration-token API used here;
Messaging 17 moves to registration/Firebase Installation IDs. Adapt the API and
your send backend together before upgrading that major version.

Use your Firebase project to register your exact Android application id, add
`google-services.json` to `android/app/`, and apply the Google services Gradle
plugin. The example declares plugin 4.4.4 and applies it only when the file exists.
Declare `android.permission.POST_NOTIFICATIONS` in the main Android manifest.
The phone/emulator needs compatible Google Play services. Never put a service
account key in the app, web output, or repository.

Copy `.claude/skills/valence/templates/push_background.dart` to the host's
`lib/push_background.dart`. Before `Valence.open`:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp();
FirebaseMessaging.onBackgroundMessage(pushBackgroundMessage);
final push = createFirebasePush();
final valence = await Valence.open(valenceConfig, push: push);
```

Import `package:valence_push/valence_push.dart` alongside `firebase_core`,
`firebase_messaging`, `valence.dart`, the generated config and your background callback.
The core repository example deliberately includes no push dependency or initialization;
its push methods return `E_UNSUPPORTED`. To enable push, add the package and native
setup above and wire this initialization into your host. Setting `VALENCE_PUSH=true`
on the core example no longer enables Firebase.

Existing unreleased push hosts replace `ValencePush()` with `createFirebasePush()`.
Custom `ValencePushTransport` implementations now exchange `ValencePushMessage`
instead of Firebase `RemoteMessage`; preserve `hasNotification` even for empty
notification envelopes. That native-only flag is excluded from the bridge JSON.
`ValencePushMessage.fromRemote` moves into the adapter's conversion; construct
provider-neutral records directly in custom transports. The background callback's
`ValencePush.handleBackground` API and every bridge signature stay unchanged.

`start` captures notification taps without fetching a token or prompting. Keep
the push object for the lifetime of the host; `await push.dispose()` stops its
listeners when permanently discarding the host. It does not unregister the device.

Firebase native auto-init is separate from the bridge. Supplying a project config
can enable SDK registration before Dart runs, independently of Android notification
permission. For consent-sensitive apps, follow Firebase's auto-init controls in
the native setup guide; a passive `push.permission` check is not a global SDK
privacy switch.

## Use the typed web bridge

```ts
import { call, connect, has, on } from '$lib/valence/bridge.g';

await connect();
if (has('push.initial')) {
  const stop = on('push.tapped', ({ message }) => showMessage(message));
  const initial = await call('push.initial');
  if (initial) showMessage(initial);
  // Call stop() when this root subscription is discarded.
}
```

`showMessage` is your app's display handler, not a native command. Render title,
body and data as text. Never evaluate scripts, insert raw HTML or blindly navigate
to a URL in a push. Nothing in a payload grants access to the bridge or selects a
sync server. Use your router only after validating the app's own route identifier.

| Call | Behavior |
|---|---|
| `push.permission()` | Checks without prompting. Returns `notDetermined`, `denied`, `authorized`, or `provisional`. |
| `push.permission({request: true})` | Requests alert/badge/sound permission. Call from an explicit user action. |
| `push.token()` | Returns an FCM installation registration token, or null without authorization/provisional permission, or before iOS has an APNs token. Does not request permission. |
| `push.initial()` | Consumes the latest pre-subscription tap, then enables live `push.tapped`. A second call returns null. |

`push.received` and `push.tapped` carry `{message}`. The message is
`{id, data, title, body, image}`; all fields except `data` can be null.
`push.tokenChanged` carries `{token}`. Foreground received events and live token
events are best effort. Check `push.token` after resume/reconnect as well as
subscribing to rotations. Send registrations to your own authenticated backend;
the token is an installation address, not a login credential. Unlink it on logout
in your backend and honor provider invalid-registration responses. Do not log it.

An Android permission denial may need the user to visit system settings; repeated
requests cannot override the OS. Permission status is separate from network
availability and does not promise delivery.

## Display an image

Send an FCM HTTP v1 notification from your trusted server with
`android.notification.image` set to an HTTPS image URL. The Android FCM SDK
displays it in the background notification tray; expanding the notification may
be needed to see the image. On the foreground path Valence delivers metadata to
the page for an in-app presentation; it does not create a second system alert.
Image loading and delivery can fail independently. HTTPS `image` metadata crosses
the bridge, not image bytes. The signed page's CSP still governs web image loads.

Push hosts installing `valence_push` need an iOS deployment target of **15.0 or later**
for Firebase. Raise Runner and extension target settings in those hosts. Core-only
hosts no longer inherit that Firebase requirement; other plugins still set their own minima.

On iOS, upload the APNs key to Firebase, add the Firebase project plist to Runner,
enable Push Notifications plus Remote notifications/Background fetch, and keep
Firebase method swizzling enabled. Add a Notification Service Extension target,
link Firebase Messaging into that target, and use the supplied
`templates/NotificationService.swift`. Set the extension's principal class to
`$(PRODUCT_MODULE_NAME).NotificationService` and extension point to
`com.apple.usernotifications.service`. Send `aps.mutable-content: 1` and
`apns.fcm_options.image` with a URL including a supported file extension. A
minimal extension plist is supplied next to the Swift template. Provision both
targets in Xcode. These paths have not been built or tested on Apple hardware.

## Wake sync without loading the UI

Send a **data-only** FCM HTTP v1 message:

```json
{
  "message": {
    "token": "installation-registration-token",
    "data": {"valence": "sync"},
    "android": {"priority": "high"},
    "apns": {
      "headers": {"apns-push-type": "background", "apns-priority": "5"},
      "payload": {"aps": {"content-available": 1}}
    }
  }
}
```

Only that exact one-field data map and no notification object triggers sync.
Other messages and extra configuration fields are ignored as commands. The
top-level entry-point callback uses `Valence.backgroundSync(valenceConfig)` with
the host's compiled config and stored bearer token. It does not call
`Valence.open`, start a WebView/server, activate an update, close SQLite, or commit
a trial. The existing sync lease and normal cursor/outbox rules still apply.

Delivery is best effort. The OS may delay or drop the hint, especially after
force-stop, under battery restrictions, or after high-priority abuse. Background
work must finish within the provider's execution window (roughly 30 seconds).
Normal resume/periodic sync remains the correctness path. A busy lease means no
sync was attempted; never display it as “up to date.”

## Device acceptance still required

With a maintainer-owned Firebase project: deny then grant permission; register;
send a foreground notification; background the app and send an image notification;
tap it both warm and after process death; send a data-only sync hint and verify a
known server row/outbox acknowledgement without any bundle-state transition;
check token persistence/rotation and normal offline launch. Do not use force-stop
as a test of guaranteed silent delivery. Until those pass, R5 is blocked for
device validation, not ready to merge as a completed roadmap item.

Primary references checked 2026-10-22:
[Flutter message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[native setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[Messaging 16.7](https://pub.dev/packages/firebase_messaging/versions/16.7.0),
[image payloads](https://firebase.google.com/docs/cloud-messaging/android/send-image).

Host-to-page push events are capped at 256 KiB including script escaping. Successful and error replies count Unicode separator escapes before enforcing their JSON byte cap. An oversized error returns E_TOO_LARGE with a finite numeric correlation id, or null for an invalid/oversized id.
