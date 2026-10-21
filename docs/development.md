# Develop inside the native host

R9 adds a debug-only development server path. Start with a working signed built-in bundle and
seed, then run from the project root:

```sh
node valence/valence.mjs dev --web-dir web --port 5173
```

This runs `npm run dev -- --host 0.0.0.0 --port 5173 --strictPort` in `web/`. In another terminal,
inside the Flutter host:

```sh
flutter run --debug --dart-define=VALENCE_DEV_URL=http://10.0.2.2:5173
```

On a physical Android phone, use `--device-host 192.168.1.20` to print a LAN command; replace
the address with your computer's reachable address. Allow that port through your local firewall.
`--web-dir` must contain a package.json with a `dev` script. The runner supports Vite-style
arguments, including Vite-based frameworks. For another framework, start its server yourself
and use the same Flutter define. Stop the dev command to stop its process tree.

The WebView loads the host's owned loopback origin. A debug proxy serves HTML and modules from
your chosen development origin, injects the nonce before scripts and carries HMR WebSockets.
Use the ordinary generated `bridge.g.ts` imports, `connect()`, `call()` and `ready()`. No client
or codegen changes are needed. Vite HMR/Fast Refresh retains component state where your
framework supports it. A full browser reload resets page state as usual. A native-code,
schema, plugin or compiled-origin change still needs codegen and a Flutter rebuild.

The signed installed bundle supplies data-schema context; the dev page can read and write real
native SQLite data and call the compiled native methods. Use a separate development app id,
test accounts and test data. The explicit define grants that server's code the full bridge.
Cookies and native tokens are never forwarded to the dev server by the proxy. Main-frame
navigation stays origin-locked; subframes, objects and workers are blocked by CSP. Dev service
workers cannot persist across the switch back to a signed build. Redirects and writes through
the proxy are refused. Requests under `/_host/` keep their ordinary native handling.

OTA checks, trial timers, `ready()` commits and `bundle.applyUpdate` are disabled in this mode;
pending/trial/failure records are preserved. Ordinary sync remains available. A bad installed
bundle or a floor above every available signed bundle must be fixed before development starts.

Profile and release builds ignore `VALENCE_DEV_URL`, even when explicitly supplied. A compile-time
`kDebugMode` guard removes the proxy and upstream URL from release AOT. Run Flutter without the
define to return to signed-bundle testing. Validate offline starts and OTA rollback in that mode;
HMR is development feedback, not a signed-release test.

Android is the target for validation. iOS has the code path but remains experimental and untested.
Source: contracts section 3.1. Release-exclusion evidence is recorded in `docs/r9-validation.md`.
