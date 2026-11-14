# R23: native cleartext HTTP in a release build

Date: 2026-10-27. Branch: `codex/r23` in both repositories.
Bases: code `ebb0793d576c74c6841686298c9ad828479f02b7`, site
`afe2366c75670aa31811e0b2681fdc313f5d8751`.

## In plain terms

The example's emulator-host HTTP origin could receive the user's bearer token
from a release build. Android's network security XML did not stop it. The default
demo now uses device loopback with `adb reverse`; production APIs should use HTTPS.
This fixes the reference configuration and the misleading documentation without
changing existing apps' explicitly granted native HTTP capability.

## Decisions

- Security first: remove the off-device cleartext grant from the reference config,
  regenerate the native config, change the page's RPC URL, and rebuild/sign the
  built-in web bundle. Leave the Android XML restricted to loopback.
- Preserve the existing contract: explicit HTTP origins remain supported by
  `ValenceHttp`, including release builds. Silently changing that API would break
  existing configured hosts and local tests. Native token trust belongs to the
  store-compiled origin list, independent of CSP and of the debug-only dev proxy.
- No package/schema version or `since` changes. No new bridge surface, migration,
  writable-data operation or signing-key change. The generated bundle sequence
  advances normally; the recorded store schema and store sequence remain intact.
- Correct the local-testing guide's blanket claim that `10.0.2.2` cannot work.
  Keep recommending loopback forwarding, while describing the transport evidence
  rather than promising an Android policy boundary that this transport bypasses.

## Release-device evidence

Lock acquired as `codex-builder`; `emu.sh ensure` selected `emulator-5554`, Android
API 37. Built the example's unchanged native project with the separate
`tool/http_policy_probe.dart` entry point:

```sh
flutter build apk --release -t tool/http_policy_probe.dart
adb reverse tcp:18783 tcp:18783
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.getvalence.valence_example/.MainActivity
adb logcat -d -v brief -s flutter
```

The probe APK SHA-256 was
`3d84d2eb07c91bb870827afb7ca7abda00fdf16622ac860f6a780644f2fac162`.
`aapt dump xmltree` showed target SDK 36, `usesCleartextTraffic=false` and an
application `networkSecurityConfig` resource. `aapt2 dump resources` resolved that
resource to `res/8G.xml`; dumping it confirmed its only domain exception was
`127.0.0.1`, with subdomains disabled. The policy was present in the release APK.

The probe uses `ValenceHttp`'s default client, its normal origin check and bearer
attachment. It does not open Valence, its database or secure store. Its credential
is the fixed synthetic string `r23-synthetic-only`. Its explicit probe allowlist
contains both addresses on port 18783; this deliberately tests transport behavior,
separately from the narrowed default example config. Port 8787 already belongs to
another local service, so the probe used its own listener instead of touching it.

Logcat, PID 10497:

```text
r23: release=true debug=false
r23: http://10.0.2.2:18783/probe status=200 body=r23-controlled-response
r23: http://127.0.0.1:18783/probe status=200 body=r23-controlled-response
r23: unlisted=E_DENIED
```

The controlled Node HTTP server bound only to `127.0.0.1:18783` and returned the
fixed response above. For each of the two received `/probe` requests it recorded
only `syntheticBearer:true`, comparing the Authorization header to the synthetic
credential without printing it. No real credentials or test-app data were used.
The example was force-stopped, only reverse 18783 removed, the server stopped and
the emulator lock released. No test-app repository or process was changed.

This establishes the behavior on this Android emulator and current Flutter
transport. It does not establish behavior on every platform/version. iOS remains
experimental and untested. This is a native HTTP probe, not new evidence for HMR,
OTA rollback, push delivery or app acceptance.

## Regression and review

The new example regression failed against the old source/generated config with
`the reference app must not grant cleartext token trust off device`. It passes
after narrowing the config. It compares source and generated origin permissions,
rejects off-device cleartext grants, and dispatches emulator-host, LAN and wrong
loopback-port URLs through the actual generated bridge. All return `E_DENIED`
before token lookup. The existing real-loopback integration still proves allowed
RPC, bearer attachment and strict decoding. The contracts §8 matrix records both.

Checklist review: no verification-order, nonce, navigation, strict decoding,
atomic-write, keyring or data-lease code changed. The rebuilt signed built-in
passes full file verification. Existing origin/redirect/credential-denial tests
pass. The diagnostic entry point is opt-in, uses only a synthetic token and is
not imported by the normal application. No independent reviewer ran in this
builder session; the branch awaits the improver's review.

Both app findings and newest reports were consulted read-only: Kundalini
iteration 12 and app-a iteration 10. Their snapshot mismatch remains separate;
no snapshot distribution or app compatibility repair is claimed here.

## Gates

Completed: 88 root tests, zero skips (generated Dart really ran); 494 runtime
tests; 25 example tests; 29 bridge tests; fatal-info Dart analysis; strict bridge
TypeScript; bridge pack dry run; source and vendored `codegen --check`; signed
built-in verification (seq 1793076993, two files). First site build passed 37 pages
and SEO checks; final documentation rebuild also passed 37 pages. Pub publish
dry run passed with **zero warnings** after the implementation commit. Its first
run warned about the then-uncommitted changes and deleted CAS file; the clean
committed run resolved both without changing ignore rules.

Normal debug and release APK builds passed. Both APKs' embedded manifest bytes
match the newly signed source manifest. All three release `libapp.so` files are
free of the diagnostic token/response sentinels. Builds reported existing plugin
Kotlin migration notices; these are separate from the warning-free pub gate.
The normal release APK was restored over the probe install and left stopped,
under a newly acquired/released emulator lock. No normal-app device acceptance
run is claimed.

Security review remains for the improver. Nothing was pushed, published or merged
into shared branches. The queue items are all done and the integration is already
merged; this run completes one new item, R23.
