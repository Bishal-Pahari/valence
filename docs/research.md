# OTA / hybrid / offline-first mobile frameworks: landscape and gaps

Question: which existing solutions let a mobile app ship changes without store review, and is there room for a new open-source framework that combines (a) offline-first versioned data sync with remote "fix" patches, (b) an OTA web UI (for example Svelte) inside (c) a Flutter shell with (d) a typed native bridge? A second requirement came in during the survey: **one codebase for web and mobile**, so mobile logic and web-app logic stop drifting apart.

Survey done 2026-10-14 against primary sources: policy text, vendor docs and pricing pages, the GitHub API (via `gh api`), the pub.dev API and the npm downloads API. Star counts and download numbers are snapshots from that day. **unverified** marks anything not confirmed from a primary source.

This file is internal planning material.

---

## 0. Headline findings

1. **Policy permits the plan, within limits.** Apple's licence agreement (DPLA §3.3.1(B)) allows downloaded *interpreted* code if it does not change the app's primary purpose, does not bypass OS security, and does not create a storefront. Google Play exempts code that runs "in a virtual machine or an interpreter … (such as JavaScript in a webview or browser)". Downloading native code is forbidden on both stores. A web-UI OTA layer is therefore allowed. The real App Store risks are **4.2 (a "repackaged website")** and **4.7.2 (exposing native APIs to downloaded mini apps needs Apple's permission)**.
2. **Code push is commoditised for React Native, Capacitor and Flutter.** There are several options: Expo EAS Update, Hot Updater (MIT, self-hosted), Capgo (MPL-2.0 plugin with an AGPL-3.0 backend), Shorebird (Flutter, with a custom Dart interpreter on iOS) and Microsoft's archived code-push-server. Signing, rollback and staged rollout are standard features in the products that are still maintained.
3. **The Capacitor commercial tier is collapsing.** Ionic stopped new sales of Appflow, Portals and its other commercial products on 2025-02-11, and existing customers keep access "through December 31, 2027". Microsoft retired App Center CodePush on 2025-03-31. Both moves leave room for self-hostable open-source alternatives.
4. **Server-driven UI for Flutter exists but is not web UI.** rfw (from Google) is "relatively stable" but explicitly warns against moving the whole app onto it. Stac (MIT; replaces the discontinued `mirai` package) is the most active option. DivKit's Flutter package has not been updated since 2024-12. None of these lets you reuse a Svelte web app.
5. **Offline sync is commoditised separately**: PowerSync (Flutter, web and Capacitor SDKs; FSL-licensed service), Drift and sqflite for local SQLite, RxDB, and ElectricSQL. **No OTA framework ships a data-sync or data-patch layer**, and no sync engine ships UI OTA.
6. **No open-source package combines Flutter shell + OTA web bundles (signed, staged, rollback) + offline versioned data sync + typed bridge.** The closest matches are Capacitor+Capgo+PowerSync (not Flutter; three products glued together) and the WeChat/uni-app mini-program pattern (closed or China-centric, no Flutter). The gap is real, but the pieces are each commodities. The novelty is in the **integration and the contracts**: the bundle manifest, the bridge IDL, and data patches versioned against bundle versions.
---

## 1. Policy limits (exact text)

### 1.1 Apple

Sources: App Store Review Guidelines (page shows "Last Updated: June 8, 2026") https://developer.apple.com/app-store/review/guidelines/ and the Apple Developer Program License Agreement https://developer.apple.com/support/terms/apple-developer-program-license-agreement/ (retrieved 2026-10-14; the latest attachment is dated October 13, 2026).

Numbering note: the "interpreted code" rule is **not** in the Review Guidelines. It is in the **DPLA, §3.3.1 "APIs and Functionality", item B "Executable Code"**. Older versions numbered it 3.3.2 and required execution "by Apple's built-in WebKit framework or JavaScript Core". The current text found on the page has **no WebKit/JavaScriptCore wording**. The WebKit requirement now sits in guideline 2.5.6 (web browsing must use WebKit, with entitlement exceptions in the EU and Japan).

| Rule | Exact text |
|---|---|
| **DPLA 3.3.1(B) Executable Code** | "Except as set forth in the next paragraph, an Application may not download or install executable code. Interpreted code may be downloaded to an Application but only so long as such code: (a) does not change the primary purpose of the Application by providing features or functionality that are inconsistent with the intended and advertised purpose of the Application (b) does not bypass signing, sandbox, or other security features of the OS; and (c) for Applications distributed on the App Store, does not create a store or storefront for other Applications." (The next paragraph is the carve-out for learning-to-program apps.) |
| **Guideline 2.5.2** | "Apps should be self-contained in their bundles, and may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features or functionality of the app, including other apps. Educational apps designed to teach, develop, or allow students to test executable code may, in limited circumstances, download code provided that such code is not used for other purposes. Such apps must make the source code provided by the app completely viewable and editable by the user." |
| **Guideline 2.5.6** | "Apps that browse the web must use the appropriate WebKit framework and WebKit JavaScript. You may apply for an entitlement to use an alternative web browser engine in your app. Learn more about these entitlements for the EU and Japan." |
| **Guideline 4.2 Minimum Functionality** | "Your app should include features, content, and UI that elevate it beyond a repackaged website. If your app is not particularly useful, unique, or "app-like," it doesn't belong on the App Store. If your App doesn't provide some sort of lasting entertainment value or adequate utility, it may not be accepted. …" |
| **4.2.2** | "Other than catalogs, apps shouldn't primarily be marketing materials, advertisements, web clippings, content aggregators, or a collection of links." |
| **4.2.3(ii)** | "If your app needs to download additional resources in order to function on initial launch, disclose the size of the download and prompt users before doing so." |
| **4.7 Mini apps, mini games, …** | "Apps may offer certain software that is not embedded in the binary, specifically HTML5 and JavaScript mini apps and mini games, streaming games, chatbots, and plug-ins. … You are responsible for all such software offered in your app, including ensuring that such software complies with these Guidelines and all applicable laws. … You must also ensure that the software adheres to the additional rules that follow in 4.7.1 through 4.7.5." |
| **4.7.2** | "Your app may not extend or expose native platform APIs or technologies to the software without prior permission from Apple." |
| **4.7.3** | "Your app may not share data or privacy permissions to any individual software offered in your app without explicit user consent in each instance." |
| **4.7.4** | "You must provide an index of software and metadata available in your app. It must include universal links that lead to all of the software offered in your app." |
| **4.7.5** | "Your app must provide a way for users to identify software that exceeds the app's age rating, and use an age restriction mechanism based on verified or declared age to limit access by underage users." |

### 1.2 Google Play

Source: Device and Network Abuse policy, https://support.google.com/googleplay/android-developer/answer/9888379 (retrieved 2026-10-14).

> "An app distributed via Google Play may not modify, replace, or update itself using any method other than Google Play's update mechanism. Likewise, an app may not download executable code (such as dex, JAR, .so files) from a source other than Google Play. This restriction does not apply to code that runs in a virtual machine or an interpreter where either provides indirect access to Android APIs (such as JavaScript in a webview or browser)."

The same page also lists as a violation "Apps or third-party code (for example, SDKs) containing a webview with added JavaScript Interface that loads untrusted web content (for example, http:// URL) or unverified URLs obtained from untrusted sources". **A JS bridge must only be attached to first-party, verified origins or local bundles.**

### 1.3 What this means for the framework

| Allowed | Not allowed / risky |
|---|---|
| HTML/CSS/JS bundles downloaded and executed in WKWebView / Android WebView (DPLA 3.3.1(B); Play's interpreter exemption) | Downloading native code (`.so`, dex, JAR, dylib, frameworks) on either store |
| Data/content updates (SQLite rows, JSON blobs, remote "fix" patches that are *data*) | OTA changes that alter the app's **primary or advertised purpose** (DPLA (a)) |
| A bridge from **your own** first-party web UI to native APIs | A storefront of third-party mini apps (DPLA (c)). 4.7 applies to third-party mini apps: 4.7.2 requires Apple's permission before exposing native APIs to them, plus a content index (4.7.4) and age gating (4.7.5) |
| Dart patches via an interpreter (Shorebird's iOS approach, §2.1) | A thin shell around the website: 4.2 "repackaged website" rejection. The shell must add real native value (offline, widgets, notifications, native screens) |
| | A JS interface on webviews that load untrusted or http URLs (Play) |

Inference (not policy text): 4.7 is written for *third-party* software offered inside the app. A first-party web UI that is the app's own interface sits under DPLA 3.3.1(B) and 4.2, not 4.7. If the framework later lets **other developers'** mini apps run inside the host (a "super app" model), 4.7.1–4.7.5 apply in full.

---

## 2. Code push / OTA updates

| Product | Stack | Licence | Pricing (primary) | Signing | Rollback | Staged rollout | Self-host | Status / adoption |
|---|---|---|---|---|---|---|---|---|
| **Shorebird** | Flutter (Dart) | CLI and updater dual MIT / Apache-2.0 (`LICENSE-MIT`, `LICENSE-APACHE` in [repo](https://github.com/shorebirdtech/shorebird)); engine and framework forks public; **Dart SDK fork private** ([architecture](https://docs.shorebird.dev/code-push/system-architecture/)) | Free $0 / 5,000 patch installs/mo; Pro $20 / 50,000; Business $400 / 1,000,000; overage "$1 per 2,500 installs"; Enterprise custom ([pricing](https://shorebird.dev/pricing)) | RSA keypair; signature verified on device at launch ([patch signing](https://docs.shorebird.dev/code-push/guides/patch-signing/)) | yes ([FAQ](https://docs.shorebird.dev/code-push/faq/)) | yes, app-managed beta/stable tracks + device group 1–100 ([guide](https://docs.shorebird.dev/code-push/guides/percentage-based-rollouts/)) | no (hosted service; self-hosting unverified) | 3,040 stars, v1.6.128 on 2026-10-11; `shorebird_code_push` 202,756 pub.dev downloads/30d |
| **Expo EAS Update** | React Native | `expo` MIT ([repo](https://github.com/expo/expo)); EAS service proprietary | Free 1,000 MAU; Starter $19 + usage (3,000 MAU); Production $199 + usage (50,000 MAU); overage graduated from $0.005/MAU; bandwidth $0.10/GiB ([pricing](https://expo.dev/pricing)) | not on the intro page (expo-updates code signing: unverified) | "republish" a previous update ([docs](https://docs.expo.dev/eas-update/introduction/)) | yes, percentage rollouts ([docs](https://docs.expo.dev/eas-update/introduction/)) | the docs mention "a self-hosted update service" | expo repo 52,702 stars |
| **Microsoft App Center CodePush** | React Native (and Cordova) | MIT | n/a | — | — | — | standalone `code-push-server` | **Retired 2025-03-31**; [code-push-server](https://github.com/microsoft/code-push-server) **archived** (985 stars, last push 2025-05-20): "CodePush, along with other App Center features, was also retired on March 31, 2025". [react-native-code-push](https://github.com/microsoft/react-native-code-push) also archived (9,116 stars). The community fork [lisong/code-push-server](https://github.com/lisong/code-push-server) (MIT, 1,864 stars, last push 2026-02-15) is still around. |
| **Hot Updater** (gronxb) | React Native | MIT ([LICENSE](https://github.com/gronxb/hot-updater)) | free, self-hosted on "Cloudflare, Supabase, AWS, Firebase, Vercel, Azure or a custom server" ([docs](https://hot-updater.dev/docs/get-started/introduction)) | a "Bundle Signing" guide exists (details unverified) | yes ([site](https://hot-updater.dev/)) | a "Rollout & Cohorts" guide exists (details unverified) | yes | 1,767 stars, **v1.0.0 on 2026-10-11** |
| **Ionic Appflow Live Updates** | Capacitor/Cordova | proprietary | not listed | — | — | — | no | **New sales discontinued 2025-02-11**: "discontinued new customer sales for all Ionic commercial products and services"; existing customers have access "through December 31, 2027" ([Ionic post](https://ionic.io/blog/?p=6282)). Capacitor's own docs still point only to Appflow ([deploying updates](https://capacitorjs.com/docs/guides/deploying-updates)). |
| **Capgo** | Capacitor | plugin [capacitor-updater](https://github.com/Cap-go/capacitor-updater) **MPL-2.0** (872 stars, 8.52.1 on 2026-09-30); backend [capgo](https://github.com/Cap-go/capgo) **AGPL-3.0** (211 stars) | Solo $12/mo yearly ($14 monthly), 2,000 MAU; Maker $33 ($39), 10,000 MAU; Team $83 ($99), 100,000 MAU; Enterprise $208+ ($249+), 1M+ MAU ([pricing](https://capgo.app/pricing/)) | optional end-to-end encryption with a public key; checksums ([README](https://github.com/Cap-go/capacitor-updater)) | "Reset the app to last working bundle" | channels | yes: "the whole stack is open source so you can self-host at any time" | `@capgo/capacitor-updater` **1,552,457 npm downloads** (2026-09-12..10-11) |
| **Re.Pack** (Callstack) | React Native build tool (Rspack/webpack) | MIT ([repo](https://github.com/callstack/repack)) | free | — | — | — | n/a | "Leverage Module Federation v2 to split JS or Hermes bytecode bundle into smaller chunks and download on-demand from a server" ([site](https://re-pack.dev/)). This is a micro-frontend loader, not an update service. 1,946 stars, 5.4.2 on 2026-10-09. |

### 2.1 Shorebird on iOS (how it stays compliant)

- "uses a custom interpreter designed specifically for physical arm64 iOS devices to execute updated Dart code over-the-air" ([FAQ](https://docs.shorebird.dev/code-push/faq/)).
- A linker step reuses unchanged functions from the AOT binary, so "typically 98% or higher" of code still runs AOT ([architecture](https://docs.shorebird.dev/code-push/system-architecture/)).
- Patches cannot change native code, native plugins, the Flutter version or (by default) assets ([FAQ](https://docs.shorebird.dev/code-push/faq/)).
- **No Flutter web support**: "Code Push isn't needed for Flutter web" ([FAQ](https://docs.shorebird.dev/code-push/faq/)).

### 2.2 One codebase for web and mobile (OTA products)

| Product | Web + mobile from one codebase? |
|---|---|
| Shorebird | Only in the sense that Flutter targets web; Shorebird itself is not used on web. Flutter web is a canvas app, not an SEO-friendly website. |
| Expo EAS Update | Expo targets web through React Native for Web (unverified on primary page in this survey); OTA covers native only. |
| Capgo / Capacitor | **Yes.** The same web build is the website and the app's `webDir` ([config](https://capacitorjs.com/docs/config)). OTA ships that same bundle. |
| Hot Updater / CodePush / Re.Pack | React Native only; web reuse depends on RN-Web (not covered). |

---

## 3. Server-driven UI (SDUI)

| Option | Platform | Licence | Status (primary) | Adoption |
|---|---|---|---|---|
| **rfw** (Remote Flutter Widgets, from Google) | Flutter | BSD (flutter/packages; unverified per-package) | 1.1.4 on 2026-09-17. README: "This package is relatively stable." and "you will slowly be tempted to move your whole application to this model. This won't work." ([README](https://github.com/flutter/packages/tree/main/packages/rfw)) | pub.dev 697 likes, 19,596 downloads/30d ([pub](https://pub.dev/packages/rfw)) |
| **Stac** (replaces `mirai`) | Flutter | MIT | 1.6.0 on 2026-09-13; Dart DSL that "compiles down to JSON"; "Smart caching" of screens; Stac Console at console.stac.dev ([repo](https://github.com/StacDev/stac)). The `mirai` package is marked **discontinued, replacedBy `stac`** in the pub.dev API (https://pub.dev/api/packages/mirai). | 924 stars; 192 likes, 13,540 downloads/30d ([pub](https://pub.dev/packages/stac)) |
| **Duit** (`flutter_duit`) | Flutter | MIT | 4.4.1 on 2026-03-16; "Support for different network protocols (http, websocket)", "Actions & Events API" ([pub](https://pub.dev/packages/flutter_duit)) | 61 stars; 149 downloads/30d |
| **DivKit** (Yandex) | Android, iOS, Web (Flutter package separate) | Apache-2.0 ([LICENSE](https://github.com/divkit/divkit)) | Core 33.6.0 on 2026-10-05. Site lists "Android, iOS and Web" only ([divkit.tech](https://divkit.tech/)). The `divkit` Flutter package was last published **2024-12-10** (0.6.0). | 2,686 stars; Yandex products listed as users ([divkit.tech](https://divkit.tech/)); Flutter pkg 831 downloads/30d |
| **Fair** (58.com) | Flutter (Dart → JS/JSON) | BSD-3-Clause | last push 2024-10-25; pub 4.0.0 on 2024-06-26 (**stale**) | 2,740 stars |
| **dart_eval / flutter_eval** | Flutter (Dart interpreter, code push) | BSD-3-Clause | dart_eval 0.8.5 on 2026-05-12 | 400 stars; 4,078 downloads/30d |
| **WebF** (successor to Kraken) | Flutter renders HTML/CSS/JS with its own engine | **GPL-3.0** ([repo](https://github.com/openwebf/webf)) | 0.24.27 on 2026-04-13; Kraken (Apache-2.0, 4,927 stars) dormant since 2022-12 | 2,516 stars |
| **Airbnb Ghost Platform** | in-house (web, iOS, Android) | not open source | "A Deep Dive into Airbnb's Server-Driven UI System", Ryan Brooks, 2021-06-29, https://medium.com/airbnb-engineering/a-deep-dive-into-airbnbs-server-driven-ui-system-842244c5f5 (returned 403 to the fetcher; details **unverified** from primary) | — |
| **Lyft** | in-house | not open source | "The Journey to Server Driven UI At Lyft Bikes and Scooters", https://eng.lyft.com/the-journey-to-server-driven-ui-at-lyft-bikes-and-scooters-c19264a0378e (403 to the fetcher; content **unverified**) | — |
| **Nubank BDC / Catalyst** | in-house, **Flutter** | not open source | BDC: "Server Driven UI is a way for building an app interface from the backend", Flutter components, Clojure backend (2023-01-20, https://building.nu.com/server-driven-ui-framework-at-nubank/). Catalyst: "a very small client-side interpreter" in Flutter (Rafael Ring, QCon London 2026-03-18, https://www.infoq.com/presentations/mobile-server-driven-ui-scale) | InfoQ talk: 14,000+ screens, >90% of app screens, lead time from 4–5 weeks to about 20 minutes |

**Takeaway.** SDUI solves "change layout without release" well for Flutter, and Nubank proves it at scale. It does **not** solve "one codebase for web and mobile": the SDUI JSON or DSL is a third UI language, not the web app. WebF is the one Flutter project that renders real web code natively, but it is GPL-3.0, which rules it out for many commercial embeddings.

---

## 4. Web-in-native hybrids with offline support

| Option | Model | Licence | Offline story | Status / adoption |
|---|---|---|---|---|
| **Hotwire Native** (37signals) | Native shell + **server-rendered** HTML, Bridge Components ("an extension of a Stimulus Controller") | MIT | Not covered on the site ([native.hotwired.dev](https://native.hotwired.dev/)); remote-first by design | iOS 311 stars (1.3.1, 2026-08-14), Android 168 stars (1.3.2, 2026-10-12) |
| **Capacitor** | Bundled web assets served from a local scheme (`iosScheme` default `capacitor`, `androidScheme` default `https`, host `localhost`) ([config](https://capacitorjs.com/docs/config)) | MIT | Offline by default (assets are in the bundle); data layer is up to the developer | 16,862 stars, 8.5.3 on 2026-10-07; `@capacitor/core` **22,007,725 npm downloads/month** |
| **Cordova** | Bundled web assets | Apache-2.0 | same as Capacitor | cordova-android 3,793 stars, 15.1.0 on 2026-07-22 |
| **flutter_inappwebview** | Flutter WebView plugin | Apache-2.0 | `InAppLocalhostServer` serves bundled assets on `http://localhost:8080` by default ([docs](https://inappwebview.dev/docs/in-app-localhost-server)) | 3,783 stars; **last stable 6.1.5 on 2024-10-08**, latest 6.2.0-beta.3 on 2026-02-04 (maintenance risk); 2,854 likes, 1,147,867 downloads/30d |
| **webview_flutter** (Flutter team) | official WebView plugin | BSD (unverified) | none built-in | 4.14.1 on 2026-07-07; 3,550,237 downloads/30d |

### 4.1 Service workers in WKWebView

- Service Worker API in WKWebView is available "starting from iOS 14.0+" and requires **App-Bound Domains** (or being the default browser) ([inappwebview service-worker docs](https://inappwebview.dev/docs/service-worker)).
- Set up: list up to 10 domains under the `WKAppBoundDomains` Info.plist key ([WebKit blog, 2020-06-26](https://webkit.org/blog/10882/app-bound-domains/)), and set `limitsNavigationsToAppBoundDomains = true`.
- Side effect: with App-Bound Domains on, JS injection, user scripts and `window.webkit.messageHandlers` are restricted for non-app-bound content ([WebKit blog](https://webkit.org/blog/10882/app-bound-domains/)). Developers report other webviews in the app being downgraded ([Apple forums 770366](https://developer.apple.com/forums/thread/770366), [745775](https://developer.apple.com/forums/thread/745775)) and intermittent SW failures on iOS 15 ([702755](https://developer.apple.com/forums/thread/702755)). These are forum reports, not Apple policy.
- Service workers do not run on custom schemes such as `capacitor://` (**unverified**; widely reported, no primary statement found).

**Design consequence.** Do **not** rely on service workers for offline in the shell. Serve the downloaded, verified bundle from local storage (a local HTTP server or a custom scheme handler) and keep the data layer in native SQLite behind the bridge. That is what Capacitor+Capgo and WeChat do.

### 4.2 JS-bridge mini-program pattern

| Platform | Primary evidence | Notes |
|---|---|---|
| **WeChat Mini Programs** | The rendering layer is "rendered using WebView" and "The logic layer uses the JsCore thread to run JS scripts", communicating via the native client ([framework doc](https://developers.weixin.qq.com/miniprogram/en/dev/framework/quickstart/framework.html)). Updates: an async check at every cold start, applied on the next cold start; sync updates "will block the startup process"; `wx.getUpdateManager` for forced updates ([update mechanism](https://developers.weixin.qq.com/miniprogram/en/dev/framework/runtime/update-mechanism.html)) | The reference design: split logic/view, packaged code, versioned updates, local fallback on failure |
| **Alipay Mini Programs** | Docs at https://opendocs.alipay.com/mini/framework/overview (page body did not render to the fetcher) | architecture details **unverified** |
| **Grab / Gojek** | No public developer docs found. A Grab careers listing mentions a "MiniApp Platform" team ([grab.careers](https://www.grab.careers/en/jobs/744000148837829/software-engineer-full-stack/)) | **unverified** |
| **Telegram Mini Apps** | Web app loaded from a URL; `telegram-web-app.js` exposes `window.Telegram.WebApp`; `initData` checked with HMAC-SHA-256 or an Ed25519 signature; CloudStorage (1,024 keys), DeviceStorage (5 MB), SecureStorage (Keychain/Keystore, 10 items) ([docs](https://core.telegram.org/bots/webapps)) | Remote-hosted; offline not described. SDK [tma.js](https://github.com/Telegram-Mini-Apps/tma.js) MIT, 1,205 stars |
| **uni-app** (DCloud) | "one codebase, running on multiple platforms at once": iOS, Android, HarmonyOS, Web and many mini-program platforms ([uni-app docs](https://uniapp.dcloud.net.cn/tutorial/app-wgt-update.html)) | Apache-2.0, 41,611 stars. Its wgt hot-update mechanism was not on the fetched page (**unverified**). Vue-based, China-centric ecosystem. |
| **Taro** (JD) | MIT, 37,707 stars ([repo](https://github.com/NervJS/taro)) | Mini programs + H5 + RN from one codebase |

---

## 5. Offline-first data layer (for the gap analysis)

| Option | Flutter | Web/JS | Capacitor | Licence | Notes |
|---|---|---|---|---|---|
| **PowerSync** | yes | yes | yes ([pricing](https://www.powersync.com/pricing)) | client SDKs open source; service **FSL-1.1-ALv2** ([LICENSE](https://github.com/powersync-ja/powersync-service)); "Open Edition" free self-host | Cloud: Free, Pro from $49/mo, Team from $599/mo. `powersync` pub 37,289 downloads/30d. Postgres/Mongo/MySQL → SQLite. Row sync, not "versioned blob + fix patch". |
| **Drift** | yes | (wasm) | — | MIT | 3,291 stars; 1,536,333 pub downloads/30d. Local only, no sync. |
| **sqflite** | yes | — | — | (BSD, unverified) | 3,292,123 pub downloads/30d. Local only. |
| **RxDB** | — | yes | yes (unverified) | Apache-2.0 (core) | 23,408 stars |
| **ElectricSQL** | — | yes | — | Apache-2.0 | 10,398 stars |
| **Brick** | yes | — | — | (no SPDX on GitHub) | 520 stars; offline-first REST/GraphQL/Supabase |
| **Realm Dart** | yes | — | — | Apache-2.0 | last push 2025-10-23. Atlas Device Sync deprecation date **unverified** in this survey. |
| **Replicache** | — | yes | — | — | **archived** on GitHub |

None of these models the target pattern exactly: **a bundled SQLite seed, key-value blobs keyed by update sequence number, incremental "give me everything after USN n", and remote fix patches applied as data**. PowerSync is the closest general engine, but it is row and bucket based and expects a Postgres-style source.

---

## 6. Gap analysis: does anything combine all four?

Target: (1) offline-first versioned data sync and patch layer, (2) OTA web-UI bundles with signing, rollback and staged rollout, (3) a typed native bridge, (4) Flutter shell. Plus (5) one codebase for web and mobile.

| Closest match | (1) data sync / patches | (2) OTA web bundles | (3) typed bridge | (4) Flutter shell | (5) web = mobile code | Missing |
|---|---|---|---|---|---|---|
| **Capacitor + Capgo + PowerSync** | yes (PowerSync, separate product, FSL service) | yes (encryption, channels, rollback) | partial: plugins have TS definitions; no IDL-generated host contract (unverified) | **no** (native shell is Swift/Kotlin) | **yes** | Flutter; one integrated contract; data patches versioned with bundles |
| **Shorebird + Stac/rfw + PowerSync** | yes (separate) | no web UI; Dart patches + SDUI JSON | n/a (it is all Dart) | yes | **no** (Flutter web ≠ the existing web app) | web UI reuse; Svelte |
| **flutter_inappwebview + DIY** | DIY | DIY (localhost server only) | **no** (`callHandler` is untyped JSON) | yes | yes | everything except the webview; plugin maintenance risk (no stable release since 2024-10) |
| **Hotwire Native** | no (server-rendered) | n/a (always live from server) | Bridge Components (Stimulus), typing unverified | no | yes | offline; Flutter |
| **WeChat / Alipay mini programs** | platform storage only | yes (platform-managed) | proprietary API | no | partial (custom DSL, not standard web) | open source; Flutter; you don't own the host |
| **uni-app / Taro** | no | uni-app wgt (unverified) | framework APIs | no | yes | Flutter; non-China ecosystem; data sync |
| **WebF** | no | possible (loads remote JS) | Dart↔JS module API (unverified) | yes | yes (real web code) | GPL-3.0; no OTA/sign/rollout tooling; data sync |

**Answer: no open-source package found that does all four.** The search for Flutter-plus-webview OTA frameworks on GitHub (`gh search repos`: "flutter webview hot update bundle", "flutter miniapp webview", "flutter hybrid offline package webview") returned nothing relevant. The only hit for "flutter mini program" was [zhaomenghuan/flutter-mini-program](https://github.com/zhaomenghuan/flutter-mini-program) (178 stars), which parses HTML/CSS/JS into Flutter widgets, not a WebView OTA host.

---

## 7. Adoption signals (snapshot 2026-10-14)

| Package | Metric | Source |
|---|---|---|
| `@capacitor/core` | 22,007,725 npm downloads (2026-09-13..10-12) | https://api.npmjs.org/downloads/point/last-month/@capacitor/core |
| `@capgo/capacitor-updater` | 1,552,457 npm downloads (2026-09-12..10-11) | https://api.npmjs.org/downloads/point/last-month/@capgo/capacitor-updater |
| `expo-updates`, `react-native-code-push`, `cordova`, `@hot-updater/react-native`, `@callstack/repack`, `@hotwired/hotwire-native-bridge`, `@telegram-apps/sdk` | **not retrieved**: the npm downloads API returned 504 repeatedly | — |
| `webview_flutter` | 3,550,237 pub downloads/30d | https://pub.dev/packages/webview_flutter |
| `sqflite` / `drift` | 3,292,123 / 1,536,333 pub downloads/30d | pub.dev |
| `flutter_inappwebview` | 1,147,867 pub downloads/30d, 2,854 likes | https://pub.dev/packages/flutter_inappwebview |
| `shorebird_code_push` | 202,756 pub downloads/30d | https://pub.dev/packages/shorebird_code_push |
| `powersync` | 37,289 pub downloads/30d | https://pub.dev/packages/powersync |
| `rfw` / `stac` | 19,596 / 13,540 pub downloads/30d | pub.dev |
| GitHub stars | expo 52,702 · uni-app 41,611 · taro 37,707 · rxdb 23,408 · capacitor 16,862 · electric 10,398 · react-native-code-push 9,116 (archived) · kraken 4,927 · cordova-android 3,793 · flutter_inappwebview 3,783 · drift 3,291 · shorebird 3,040 · fair 2,740 · divkit 2,686 · webf 2,516 · repack 1,946 · lisong/code-push-server 1,864 · hot-updater 1,767 · tma.js 1,205 · code-push-server 985 (archived) · stac 924 · capacitor-updater 872 · hotwire-native-ios 311 · capgo 211 · hotwire-native-android 168 · flutter_duit 61 | `gh api repos/<owner>/<repo>` |
| Known users (primary) | Nubank (Flutter SDUI: 14,000+ screens); Yandex products (DivKit); Basecamp/HEY are Hotwire's makers (not stated as Native users on the site) | §3, §4 |

---

## Verdict

**Is the gap real?** Yes, but it is an **integration gap**, not a technology gap. Every layer already exists as a maintained product. No open-source project ships them together with Flutter as the shell, and the incumbents are leaving. Ionic stopped commercial sales (access ends 2027-12-31), App Center CodePush shut down 2025-03-31, and flutter_inappwebview has had no stable release since 2024-10.

**Already commoditised (do not rebuild):**
- OTA bundle delivery with channels, rollback, encryption or signing, and percentage rollout: Capgo (MPL/AGPL, self-hostable), Hot Updater (MIT), Shorebird (Dart). Copy their manifest/rollback semantics; reuse code where licences allow.
- Local SQLite in Flutter (sqflite, Drift) and general sync engines (PowerSync, Electric, RxDB).
- Flutter WebViews (webview_flutter, flutter_inappwebview) and local asset serving.
- SDUI for native screens (rfw, Stac).
- One codebase for web and mobile through a web UI in a shell (Capacitor proves it).

**Genuinely new (where an open framework could own the space):**
1. **A Flutter-hosted, Capacitor-style runtime for web bundles**: signed bundle manifest, atomic swap, boot-time health check with auto-rollback, staged rollout, and a self-hostable static server (S3/R2), with no SaaS dependency. Nothing on pub.dev does this today.
2. **A schema-first typed bridge**: one IDL generating Dart host stubs and TypeScript client types, with capability negotiation by host version. That also makes Apple 4.7.2 and 4.7.3 auditable if third-party mini apps are ever allowed.
3. **A "versioned blob + USN + fix patch" data protocol** as a first-class layer: bundled SQLite seed, incremental pull by update sequence number, and signed data patches whose compatibility is declared against **bundle version and host version** together. Code OTA and data OTA then roll out and roll back as one unit. No existing OTA tool versions data, and no sync engine versions UI.
4. **A web-equals-mobile story with offline that does not depend on WKWebView service workers.** The same Svelte build runs as the website (online, with an optional SW) and inside the shell, where the bridge serves data from native SQLite. A bridge shim falls back to `fetch` and IndexedDB on the web. This addresses the "two codebases" pain directly.

Risks to keep in front of the design: Apple 4.2 (the shell must add native value beyond the website), Play's rule against JS interfaces on untrusted origins (attach the bridge only to verified local bundles or allow-listed origins), and the legal line in DPLA 3.3.1(B) (OTA must not change the app's advertised purpose).
