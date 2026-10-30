# Changelog

## Unreleased: read pending reminder IDs without large payloads

Schema 16 adds `notify.pendingIds()` for cancellation by difference even when full notification content exceeds the bridge reply cap. Keep `notify.pending()` unchanged; declare the new method at `since: 16`, regenerate, ship a store build and guard it with `has()`. Disabled hosts still deny the group. No delivery guarantee is added; iOS remains experimental and untested.

## Unreleased - local reminders

Generated schema-11 clients expose typed notify.* and badge.* calls and notification events through the existing bridge. Guard new calls with has() on older hosts.
