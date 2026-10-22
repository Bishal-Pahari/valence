# Sharing an image

`share.image` (since schema 14, contracts §4.7) opens the native share sheet with
a PNG or JPEG and an optional caption. Regenerate and ship a store build to add it.
Import `call` and `has` from your generated `bridge.g.ts`:

```ts
if (has('share.image')) {
  const outcome = await call('share.image', {
    path: 'assets/chart.png',
    fileName: 'chart.png',
    caption: 'My chart',
  });
  // selected, dismissed or unavailable; selected does not prove delivery.
}
```

Supply exactly one source: `path` is a relative key in the currently served signed
bundle, capped at 5 MiB; `bytes` is canonical padded standard base64, capped at
128 KiB after decoding. To share a canvas, rasterize to PNG/JPEG, then remove the
`data:image/png;base64,` prefix before passing its base64 bytes. The whole message
must still fit the bridge's 256 KiB UTF-8 limit. Larger dynamic images need an
app-specific capability; this API does not upload images or read arbitrary files.

The runtime checks the active manifest, reads only the CAS hash it names, and
verifies size and SHA-256 again. It never shares the CAS path. Only PNG/JPEG magic
is checked; the recipient decides whether it can decode the image. SVG is refused.

`fileName` defaults to `image.png` or `image.jpg`. An explicit name must match
`^[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.(png|jpg|jpeg)$` and the detected format.
`caption` is at most 4096 UTF-8 bytes. Empty captions are omitted; some recipients
ignore captions. The host wipes its dedicated input scratch directory before each
valid share. Native plugin copies live in the app cache and may persist until the
OS or plugin evicts them, so do not share credentials. No storage permission is required.

Handle `E_PARAMS` for bad sources, names or format; `E_TOO_LARGE` for size limits;
`E_DENIED` for off-bundle paths or a second concurrent share; and `E_INTERNAL` for
missing/corrupt bundle data or native failure. Disable the button while sharing.
`unavailable` is an unknown outcome, so do not retry automatically.

Android uses `share_plus`'s share sheet and temporary content URI permission.
The iOS activity-controller path, including its host-owned popover anchor, is
experimental and untested. Receiving apps control what happens after selection.

Older apps, including the test app's custom `share.image`, keep their own handler
when its declared `since` is below 14, even if the overall schema version increases.
Do not rewrite a shipped signature to adopt the built-in. Keep it or add an
app-specific method under another name. The package owns `share.image` declarations
with `since >= 14` and codegen enforces their shape.
