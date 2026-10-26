# Permissions

Contracts §4.7. Schema 10 adds `permissions.check`, `permissions.request`,
`permissions.openSettings` and `permissions.changed`. iOS is experimental and untested.

## Enable only what your app uses

Add a store-compiled allowlist to `valence/valence.config.json`:

```json
"permissions": { "kinds": ["camera", "notifications"] }
```

Run `valence codegen`, add the matching native declarations below, and ship a new
store build. Older hosts need the schema additions too; `codegen` does not overwrite
an existing schema. Copy the three methods, event and `PermissionState` type from
the starter schema, assigning the next reserved version for your app. The template retains upstream schema 13; these
permissions additions are since 10; your app's version history is independent. Keep older
methods unchanged. An empty or absent allowlist denies all kinds. An OTA cannot
expand it, even when Android already declares a permission for another native feature.

```ts
import { call, has, on } from './valence/bridge.g';

// Run once on page startup. A check never prompts.
if (has('permissions.check')) {
  const status = await call('permissions.check', { kind: 'camera' });
  renderPermission(status);
}

// Call from an explicit user action after explaining why the feature needs access.
async function enableCamera() {
  if (!has('permissions.request')) return;
  const status = await call('permissions.request', { kind: 'camera' });
  renderPermission(status);
  // Offer a separate settings button for permanentlyDenied; never reopen automatically.
}

const stop = on('permissions.changed', ({ permissions }) => {
  for (const { kind, status } of permissions) renderPermissionFor(kind, status);
});
// Call stop() on component disposal.
// A separate user action may call permissions.openSettings (no params).
```

`renderPermission` and `renderPermissionFor` are your UI functions. The API returns
status strings, not file contents, camera frames, coordinates or contact records.
On iOS the photos permission covers the OS photo library (images and videos); legacy
Android storage is also broader than images. These status calls do not narrow the
OS grant scope.
An OS grant does not implement those features or grant WebView browser APIs access.

## Kinds and native setup

Only copy the rows you enable. Android declarations go directly under `<manifest>`
in `android/app/src/main/AndroidManifest.xml`, outside `<application>`.

| Kind | Android declaration | iOS usage key / CocoaPods macro |
|---|---|---|
| `camera` | `android.permission.CAMERA`; optional camera `<uses-feature>` | `NSCameraUsageDescription` / `PERMISSION_CAMERA=1` |
| `location` | `ACCESS_COARSE_LOCATION` (coarse-only recommended) | `NSLocationWhenInUseUsageDescription` / `PERMISSION_LOCATION_WHENINUSE=1` |
| `notifications` | `POST_NOTIFICATIONS` | No usage key / `PERMISSION_NOTIFICATIONS=1` |
| `contacts` | `READ_CONTACTS` | `NSContactsUsageDescription` / `PERMISSION_CONTACTS=1` |
| `bluetooth` | See the versioned declarations below | `NSBluetoothAlwaysUsageDescription` / `PERMISSION_BLUETOOTH=1` |
| `microphone` | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` / `PERMISSION_MICROPHONE=1` |
| `photos` | See the versioned declarations below | `NSPhotoLibraryUsageDescription` / `PERMISSION_PHOTOS=1` |

Android names in the table use the `android.permission.` prefix. Bluetooth means
scan and connect, not advertising. Through API 30 scanning also needs foreground
location, so also declare `ACCESS_FINE_LOCATION` with `android:maxSdkVersion="30"` and coarse location even if `location` is not exposed
to the page. From API 31 the runtime asks for scan and connect together. If scanning
is used to derive physical location, remove `neverForLocation` and implement the
additional location flow for that feature; this API does not supply it.

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>
<!-- Also declare ACCESS_COARSE_LOCATION for legacy scanning. -->

<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED"/>
```

On Android, photos requests the image permission from API 33. API 32 and earlier use storage; 33 and later
use images; Android 14 and later may return `limited` for user-selected images.
Do not request broad library access just to choose one image: use a system picker
in a separate native method instead. Review the store's photo-access requirements
for your app before declaring broad access.

On Android set `compileSdk` to at least 35 and target a modern SDK (the example uses
Flutter's current SDK values). Camera and microphone declarations can filter devices
in a store listing; add `android:required="false"` hardware features when appropriate.
The complete demonstration declarations are in the example app. A notification grant
does not install receivers or schedule reminders; follow the notification feature's
native setup too.

On iOS, write a concrete explanation for each usage key in `ios/Runner/Info.plist`.
The example uses Swift Package Manager: permission_handler detects these keys at
build time. Notifications are enabled by default with SPM; when unused, set
`PERMISSION_NOTIFICATIONS=0` for the build. With CocoaPods, add only the table's
macros to `GCC_PREPROCESSOR_DEFINITIONS` in each target's build configuration inside
the Podfile's `post_install` hook, preserving `$(inherited)` and existing definitions.
Use the foreground-only location macro, leaving `PERMISSION_LOCATION` disabled;
no background/always location is requested. Rebuild after changing keys or macros.
For flavors, configure the plugin's per-flavor plist selection so development
permissions do not leak into the production binary.

Setup sources, checked 2026-10-22:
[permission_handler 12.0.3](https://pub.dev/packages/permission_handler/versions/12.0.3),
[status definitions](https://pub.dev/documentation/permission_handler/latest/permission_handler/PermissionStatus.html),
[device_info_plus 13.3.0](https://pub.dev/packages/device_info_plus).
The latter reads Android's SDK number to select legacy photos and Bluetooth groups;
no device identifiers cross the bridge. Its native build requirements also apply
(Java 17, Kotlin 2.2+, AGP 8.12.1+, Gradle 8.13+, iOS 13+, Xcode 26.1.1+).

## Interpret the answer honestly

| Status | What the UI should do |
|---|---|
| `granted` | Continue, while handling feature/service availability separately. |
| `denied` | Explain the feature and offer an explicit Request action. This also means not requested yet. |
| `permanentlyDenied` | Offer an explicit App settings action. |
| `restricted` | Explain that OS restrictions prevent access. |
| `limited` | Work within the access granted; never label it full access. |

Android's status check cannot distinguish a permanent denial from an initial denial
or an “Ask every time” reset. `check` therefore may return `denied` even after
`request` returned `permanentlyDenied`; asking again resolves immediately when the
OS will not show a dialog. Do not persist a guessed permanent-denial flag. iOS
provisional notifications map to `limited`. With the recommended coarse-only declaration on Android 12+, approximate foreground
location counts as granted. The plugin checks the whole declared location group:
if another feature declares fine location on Android 12+, an approximate-only grant
can report denied because fine access was not granted. Use a separate native
precision-aware flow for that case. Permission is separate from whether GPS/Bluetooth
is switched on. Where two native permissions are needed, the most restrictive result
wins: restricted, permanentlyDenied, denied, limited, then granted.

Unknown kinds get `E_PARAMS`; known kinds not enabled by this store build get
`E_DENIED`. Unsupported platforms get `E_UNSUPPORTED`. Native failures stay errors;
they never become a grant. Prompts and opening settings require an attached host in
the foreground. Requests are serialized, and a waiting request checks foreground
again before opening a dialog. Calling from a background isolate is unsupported.
`openSettings` returns whether the settings screen opened, not a grant.

Startup silently establishes a baseline. On resume, the host checks configured
kinds without prompting and emits `permissions.changed` for deltas only. Checks and
requests also update that baseline. A failed check is logged independently; another
kind's change still arrives. Check once on every page startup too: events are not a
durable history, and the OS can revoke access while the process is gone.

## Try it

The signed `packages/valence/example` has a Permissions section with a kind selector,
Check, Request, App settings and an event readout. It declares all seven kinds solely
to exercise this API. A production app should copy only the kinds it uses. On Android,
deny and grant a permission, open settings, change it there and return to see a resume
delta. iOS code paths and setup remain experimental and untested.

Android contacts use the platform contacts permission group. Declare only `READ_CONTACTS` for read access; if another native feature declares `WRITE_CONTACTS`, the OS group request may include it and `GET_ACCOUNTS` too if declared. The allowlist gates permission kinds, not individual Android manifest permissions.

Compatibility note (2026-10-22): the host stays on permission_handler 12.x. Its 13.x line brings an SDK-37 Android plugin whose target could not be resolved by the tested Flutter/AGP toolchain. Android check results normalize inferred permanent denial to denied; request preserves the OS answer. Resolved Apple 9.6.x supplies the SPM setup described above.
