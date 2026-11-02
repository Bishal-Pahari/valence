# Changelog

## Unreleased: cache selected REST responses offline

Revision 18 adds `data.cache` behind a compiled per-bucket `cache` grant.
Regenerate and ship a store host to opt in. Cached values are disposable overlays
with no server cursor or outbox; pulls replace them and recorded account changes
clear them. Existing synced rows and pending writes survive database migration 3.
Read [the guide](https://getvalence.pages.dev/docs/guides/rest-cache/) before using
account data or changing bucket schemas.

## Unreleased: read pending reminder IDs without large payloads

Schema 16 adds `notify.pendingIds()` for cancellation by difference even when full notification content exceeds the bridge reply cap. Keep `notify.pending()` unchanged. A new declaration needs `since` at least `max(16, shipped store schema version + 1)` and app schema `version` at least that value; preserve an already-shipped declaration unchanged. Update the tooling, regenerate, ship a store build and guard calls with `has()`. Disabled hosts still deny the group. No delivery guarantee is added; iOS remains experimental and untested.

## Unreleased - local reminders

Generated schema-11 clients expose typed notify.* and badge.* calls and notification events through the existing bridge. Guard new calls with has() on older hosts.
