# Safe areas, text size and accessibility

The host supplies system layout values. Your page still needs accessible HTML and responsive CSS.
This guide implements contracts §4.7. Android is the validation target; iOS is experimental and untested.

## Keep controls clear of system bars

Use this viewport and apply the host variables to content, including fixed headers and footers:

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
```

```css
body {
  margin: 0;
  padding: calc(16px + var(--valence-inset-top, 0px))
           calc(16px + var(--valence-inset-right, 0px))
           calc(16px + var(--valence-inset-bottom, 0px))
           calc(16px + var(--valence-inset-left, 0px));
}
.fixed-footer { padding-bottom: var(--valence-inset-bottom, 0px); }
```

ValenceApp requests edge-to-edge mode. Insets are logical CSS pixels for the owning Flutter view's
system bars and cutouts, refreshed after page load, rotation, multi-window resize and resume.
They exclude the keyboard; the WebView resizes when it opens. Do not wrap ValenceApp in SafeArea
or apply both these variables and CSS env(safe-area-inset-*) to the same edge. Backgrounds can extend
under bars; content padding is your choice. Initial variables arrive after document load: keep the
0px fallbacks, and avoid a slow-loading external asset that delays that callback.

## Respect text size and appearance

Android WebView textZoom follows the system font scale without reloading the page. Use rem/em text,
flexible heights, wrapping and scrollable forms. Do not multiply text by --valence-font-scale again:
Android already applies native zoom. Its percentage approximates nonlinear system scaling at a 16px
reference size. The experimental iOS path scales the original computed root font size instead and
disables additional WebKit text autosizing; fixed pixel fonts do not follow that fallback.
Do not disable pinch zoom with user-scalable=no or a maximum-scale restriction.

Add fontScale: "num?" to your schema's AppInfo type and regenerate. Existing fields and app.info's
signature stay unchanged. Older hosts omit it; use (await call('app.info')).fontScale ?? 1.
Old app schemas can leave the field out. A host update needs a store build.

Add app.appearance at since above your shipped bridge version (the combined template is version 15; appearance remains since 7),
with payload {darkMode: "bool", highContrast: "bool", reducedMotion: "bool"}. Subscribe during
bootstrap before ready().

Gate appearance-dependent features with `has('app.appearance')`. On an older host or in a browser,
keep CSS media-query fallbacks active. `app.info().bridge` is your app's own schema number;
comparing it with appearance's reserved version 7 does not prove appearance support.

Keep the code generator and installed bridge package on a matching snapshot. Event-aware generated
code passes both method and event tables to `createBridge`; an older bridge accepting only the method
table cannot compile it. Update the tooling and bridge together, then regenerate. Editing generated
code to suppress that mismatch loses the event capability check this guide relies on.

```ts
import { on, ready } from './lib/bridge.g';

const off = on('app.appearance', ({ darkMode, highContrast, reducedMotion }) => {
  // Update your theme/motion settings; the host already publishes CSS attributes below.
  console.log({ darkMode, highContrast, reducedMotion });
});
// Paint a usable screen, then call ready(), including on empty and error paths.
// Call off() when your app root unmounts.
```

An initial snapshot follows every document load; later events report changed OS preferences, including
on resume. Dark mode comes from system brightness, not MaterialApp's theme. High contrast follows what
Flutter receives from the OS; some Android versions do not report every contrast setting. Reduced motion
is true for disabled animations or accessible navigation. The root also has literal true/false attributes:

```css
:root[data-valence-dark-mode="true"] { color-scheme: dark; }
:root[data-valence-dark-mode="false"] { color-scheme: light; }
:root[data-valence-high-contrast="true"] { color: CanvasText; background: Canvas; }
:root[data-valence-reduced-motion="true"] * {
  animation: none !important;
  transition: none !important;
  scroll-behavior: auto !important;
}
```

Use browser prefers-color-scheme, prefers-contrast and prefers-reduced-motion queries as fallbacks outside
the host. No bridge runtime change or untyped window event listener is needed; generated on() carries the
payload type. Custom Flutter hosts can use ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(view))
and publish its script after load and on system changes. Pass the owning FlutterView to Valence.attach(host, flutterView: view) for matching app.info text scaling; custom hosts must also apply Android native text zoom.

## Check the actual page

- Use landmarks (header, nav, main), headings in order, real buttons and links, explicit input labels,
  alt text for informative images and visible keyboard focus. Use aria-live for short asynchronous
  status updates without announcing an entire data table. Avoid placeholder-only labels.
- With TalkBack on, move through every control, submit a form, return from a nested route and open a
  dialog. Check spoken names, roles, state, focus order and focus restoration. WebView renders the HTML
  accessibility tree; a host preference event cannot supply missing semantics.
- Keep normal text contrast at least 4.5:1, large text at least 3:1 and meaningful control boundaries at
  least 3:1. Provide roughly 48 CSS-pixel touch targets with space between adjacent controls.
- On Android, test system text size at 100%, 150% and 200%, dark/light mode, reduced animation, portrait,
  landscape and split screen. Check fixed controls, cutouts, keyboard overlap and long translated text.
  Do not clip content or require a reload after a setting change.

The signed example displays the initial appearance payload and inset values, uses the padding variables
and 48px buttons, and reports fontScale through app.info. Android device evidence belongs in the item
validation record; unit tests are not evidence that TalkBack or iOS was exercised.

References: [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), [Android touch targets](https://developer.android.com/guide/topics/ui/accessibility/apps#touch-targets), and [WebView textZoom](https://pub.dev/documentation/webview_flutter_android/latest/webview_flutter_android/AndroidWebViewController-class.html).
