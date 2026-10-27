# Update checks after reconnect

The host now retries the signed update check when a connectivity report contains any live interface
and the UI is foregrounded (contracts §2.3 and §4.6). Wi-Fi/cellular handovers count even when
`app.online` stays true. A report containing only `none` does not start a check. Background reports
still update interface state and trigger sync; resume handles update discovery.

This uses `ValenceUpdater.checkForUpdate()`: overlapping checks coalesce, all canonical verification
steps remain in place, and required-data pulls still use the bounded sync lease. A successful check
publishes pending and emits `bundle.updateReady`; it does not reload, activate a trial or commit.
Debug live development continues to suppress signed update checks.

## What the page can say

`bundle.status()` reads the last completed check without making a request. `reason: "offline"` means
"could not check on the last attempt", at `checkedAt`; it stays the last result until another check
completes. Interface availability is a reason to retry, never proof that the pointer server works.
After `app.online`, re-read status for the latest observation, but do not assume that the asynchronous
check has completed. Listen for `bundle.updateReady` to discover a newly pending bundle. An immediate
read can still return the old timestamp; a later read gets the completed result. Do not show an old
failure as a claim that the device is currently offline.

## Adopting it

Upgrade the native `valence` host and rebuild the app. Existing `ValenceApp` hosts, generated
delegations and templates inherit the trigger; no new schema number, CLI change or bridge API is needed.
A custom host should wire its foreground connectivity reports to the same updater API.

## Verification

`packages/valence/test/app_widget_test.dart` exercises real signed bundles, SQLite and the host widget
with a stub WebView. It covers offline-to-pending recovery without reload, mixed interfaces, live
handovers, concurrent-check coalescing, background sync/resume and signature rejection. The existing
disposal test checks that connectivity cannot start work after unmounting. Device evidence is recorded
separately in `r24-validation.md`. iOS is experimental and untested.
