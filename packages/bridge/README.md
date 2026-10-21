# @getvalence/bridge

The web half of the [Valence](https://getvalence.pages.dev) typed bridge. Your web app calls native
methods, subscribes to host events, and the **same build still runs as a plain website**.

This package holds the runtime. The typed surface — which methods exist, what they take and return — is
generated into `bridge.g.ts` by `valence codegen` from your `valence/bridge.schema.json`. You import from
the generated file, not from here.

```bash
npm install @getvalence/bridge
npx valence codegen
```

```ts
import { call, connect, has, on, ready } from '$lib/valence/bridge.g';

await connect();                                  // once at startup, before has()
const plant = await call('data.get', { bucket: 'plants', key: 'fern' });
const off = on('sync.changed', ({ buckets }) => refresh(buckets));
await ready();                                    // on every path that paints, once per page load
```

`connect()` asks the host which bridge version it has, so `has()` can tell you whether a method added in a
later release is available on *this* install. That is what lets one OTA bundle serve old and new hosts.

## Running as a website

Outside the host there is no native side, so `call` routes to a shim you install. Anything unshimmed
rejects with `E_UNSUPPORTED`.

```ts
import { inHost, installShim } from '$lib/valence/bridge.g';

if (!inHost()) {
  installShim({
    'data.get': async ({ bucket, key }) => (await fetch(`/api/${bucket}/${key}`)).json(),
    // A `string?` param is optional *and* nullable in TypeScript, so narrow with `== null`.
    'prefs.set': async ({ key, value }) => {
      if (value == null) localStorage.removeItem(`prefs:${key}`);
      else localStorage.setItem(`prefs:${key}`, value);
    },
  });
}
```

## API

| Export | What it does |
|---|---|
| `call(method, params?)` | Sends one message and resolves its reply. `params` is required whenever any field is required. Rejects with `BridgeError`. |
| `has(method)` | True when this host (or, on the web, your shim) can serve the method. Call `connect()` first. |
| `on(event, fn)` | Subscribes. Returns an unsubscribe that returns **void**, so it is a valid React `useEffect` cleanup. |
| `ready()` | Tells the host this page is on screen. This is what commits a trial bundle — without it every OTA release rolls back. Call it once per page load, from **every path that paints**: a first-run gate, an empty state and an error screen all paint without a data load finishing. |
| `connect()` | Reads the host's bridge version. Call once at startup. |
| `installShim(shim)` | Browser fallbacks for running the same build as a website. |
| `inHost()` | True inside the Valence host, false in a normal browser. |
| `BridgeError` | `code` is one of `E_UNKNOWN`, `E_PARAMS`, `E_UNSUPPORTED`, `E_DENIED`, `E_CANCELLED`, `E_TOO_LARGE`, `E_INTERNAL`. |
| `MAX_MESSAGE_BYTES` | 262144. The per-message cap, in UTF-8 bytes. |
| `createBridge(methodSince)` | Binds a generated method table to the runtime. `valence codegen` emits the only call you need. |

## Two things that bite

**The bridge is not a path for bytes.** Messages are capped at 256 KB of UTF-8 in each direction, because on
Android they travel through Binder, whose transaction buffer is shared across the process; overrunning it
kills the WebView with no error either side can catch. `call` refuses an over-cap message before sending it
and rejects with `E_TOO_LARGE`. Native bytes reach the page over the host's `/_host/` URLs instead.

**A round trip is not free** — budget on the order of 15 ms on mid-range Android. Prefer one `data.list`
with a prefix over N `data.get` calls, and keep per-row fetches off the first-paint path.

## Versioning

Zero runtime dependencies, ESM only, ships `.d.ts`. Type-checks under `--strict --verbatimModuleSyntax`.

The generated `bridge.g.ts` and this package move together: `BRIDGE_VERSION` in the generated file is your
schema's version, independent of this package's version.

MIT. Spec: `contracts.md` §4.

## Call your own API

After codegen, import `call`, `connect` and `has` from your app's `bridge.g.ts`. The schema-4 `http.request` method returns typed `{status, headers, body}`; the generic bridge needs no HTTP-specific transport. Guard it with `has('http.request')` after `connect()`. The native host enforces compiled `web.connect` origins and attaches the user token. A browser shim uses ordinary `fetch` with ordinary CORS rules. [Native HTTP and REST adapters](https://getvalence.pages.dev/docs/guides/your-backend/).
