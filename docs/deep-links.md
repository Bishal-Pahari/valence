# Deep links and routing

Valence maps a link opened by the OS to a path inside your signed web UI. The
WebView stays on its loopback origin. Schema 5 adds `link.initial`, `link.opened`
and the web helper `onLink`. This implements contracts §6.3. Android is the tested
platform; iOS is experimental and untested.

## Choose which links this store build accepts

Add to `valence/valence.config.json`, run codegen and ship a store build:

```json
{ "links": { "origins": ["https://links.example.com", "myapp://app"] } }
```

Use exact lowercase origins, without a trailing slash, wildcard, credentials or
path. HTTPS permits a non-default port; custom schemes require a host and no port.
HTTP and executable/file schemes are rejected. An empty list disables links. This
list is independent of `http.origins` and `web.connect`; an OTA cannot enlarge it.
Native manifest registrations must match it too.

`myapp://app/shelf?sort=new#note` becomes `/shelf?sort=new#note`. The authority
`app` is an allowlisted host, not a path segment. The runtime rejects malformed
URLs, control characters, dot segments, encoded path separators, backslashes,
network paths and `/_host` destinations, and caps URLs at 8 KiB UTF-8.

Links are input, not authorization. Custom schemes can be claimed by other apps.
Use verified HTTPS links for sensitive flows; authenticate actions separately and
validate any login callback against your own state/PKCE flow. Valence does not
extract tokens or call native methods from a link.

## Connect your web router

```ts
import { connect, onLink, ready } from './valence/bridge.g';

await connect();
const stopLinks = onLink();
// Render your router; call ready() on every path that paints.
await ready();
// On root unmount: stopLinks();
```

With no handler, `onLink()` pushes the validated local path with `history.pushState`
and dispatches `popstate`. It does not reload the page or visit the external URL.
Your router must listen to History API navigation. For routers with their own API:

```ts
const stopLinks = onLink(({ path }) => router.navigate(path), reportError);
```

Install one subscription at the app root after `connect()`. Unsupported schemas,
older hosts and browsers without a `link.initial` shim are a no-op. The helper
subscribes before requesting the initial link, drops a delayed initial reply if a
live event arrived, and stops pending navigation after cleanup. A browser shim may
return `{url,path}` or `null` from `link.initial`.

For manual integration, subscribe to `link.opened` before calling
`call('link.initial')`. The call consumes the latest pending accepted link once;
it returns `null` on later calls unless a new runtime has started. Until that call,
links replace the pending mailbox (latest wins). Afterwards they are live events,
including repeated taps on the same URL. The helper reports errors through its
second callback; the default logs a fixed message without URL contents.

## Android native setup

Inside the existing `singleTop`, exported main activity, disable Flutter's default
deep-link routing and add separate filters:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="myapp" android:host="app" />
</intent-filter>
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="links.example.com" />
</intent-filter>
```

Generate the website association document, using colon-separated SHA-256 bytes:

```sh
npx create-valence assetlinks --package com.example.app --fingerprints AA:BB:... --out website/public
```

Replace `AA:BB:...` with the full 32-byte signing certificate fingerprint (not a
Valence Ed25519 key). For Play App Signing, use the app-signing certificate from
Play Console, not the upload certificate. Multiple certificates are comma-separated.
The command writes `website/public/.well-known/assetlinks.json`, refuses invalid
input and existing files, and works without a Valence project. Review it before
uploading; it grants the specified app all URL paths on that host.

Serve it at `https://links.example.com/.well-known/assetlinks.json` with JSON
content type, no redirects and no authentication. This command does not deploy,
edit the native manifest or verify ownership of a domain.

```sh
adb shell pm verify-app-links --re-verify com.example.app
adb shell pm get-app-links com.example.app
adb shell am start -W -a android.intent.action.VIEW -d 'myapp://app/shelf?sort=new#note' com.example.app
adb shell am start -W -a android.intent.action.VIEW -d 'https://links.example.com/shelf' com.example.app
```

Test a cold start, a warm app and repeated taps. For local tests without a hosted
association document, `adb shell pm set-app-links --package com.example.app 2
links.example.com` forces OS approval. This tests intent delivery, not real domain
verification. Reset with state `0` afterwards. Inspect `pm get-app-links` separately
to distinguish a fetched verification result from a forced one.

## iOS setup (experimental, untested)

Set `FlutterDeepLinkingEnabled` to `false` in Info.plist. Add custom schemes to
`CFBundleURLTypes`. For Universal Links, enable Associated Domains with
`applinks:links.example.com` in the signed app's entitlements and configure the
Apple app identifier and provisioning profile accordingly.

```sh
npx create-valence aasa --app-id ABCDE12345.com.example.app --out website/public
```

This writes `.well-known/apple-app-site-association` with `applinks` and `paths:
["*"]`. The 10-character prefix is your Apple Team ID. Serve it over HTTPS with
JSON content type and no redirect. The example includes native setup for the
placeholder domain `links.example.invalid`; it cannot verify against that domain.
No Apple hardware has tested either custom schemes or Universal Links here.

Primary setup references, checked 2026-10-22:
[app_links](https://pub.dev/packages/app_links),
[Android association files](https://developer.android.com/training/app-links/configure-assetlinks),
[Android verification](https://developer.android.com/training/app-links/verify-applinks),
[Apple associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).
