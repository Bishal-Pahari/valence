# Changelog

## Unreleased: a link handler is told which arrival it got

`onLink(handler)` now calls the handler with `{url, path, initial}` — the new `ReceivedLink` type, which
extends `AppLink`. `initial` is true for the `link.initial` launch mailbox's reply and false for a live
`link.opened`. The wrapper already distinguished them internally, which is how a live event supersedes a
pending launch reply; it simply did not say so, and §6.3's cross-source "latest event wins" rule is the
page's to enforce. Existing handlers typed `(link: AppLink) => void` still compile and can ignore the
field. Nothing on the wire changed, so no schema moves and no `has()` gate applies.
[Deep links](https://getvalence.pages.dev/docs/guides/deep-links/).

## Unreleased: a busy sync can say who is holding it

Nothing in this package changes. On a host at built-in revision 20, a generated `SyncStatus` that
declares `leaseKind: "string?"` and `leaseAgeMs: "int?"` receives which run holds the sync lease and how
long it has held it, so `reason: "busy"` stops being the end of the story. Both are null whenever a run
starting now would not be refused. Gate on `(info.builtins ?? 0) >= 20`, never on your own schema
number. [Sync outcomes](https://getvalence.pages.dev/docs/guides/sync-outcomes/#busy-finding-out-who-is-holding-the-lease).

## Unreleased: see bridge traffic in a debug panel

`traceBridge(fn)` reports each finished `call()`: method, milliseconds, error code, and for `http.request` the URL without its query plus the status. It never carries params, bodies, headers or query strings, though a path can hold an identifier, so keep it to debug builds. Native HTTP does not appear in a browser network panel, so this is the only way a page can see it. See [Debugging](https://getvalence.pages.dev/docs/guides/debugging/).

## Unreleased: explicit update checks and completed-check notifications

- Schema 19 adds explicit `bundle.check` and `bundle.checked` completion, including offers needing a newer store host. Regenerate and rebuild to opt in; pending-only `bundle.updateReady` is unchanged.

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
