# Capability revisions and durable status

Schema 15 adds nullable returned fields. Regenerate the bridge and ship a store
build; an OTA cannot add native support. Existing store baselines stay unchanged.
Old hosts omit these fields, so use nullish fallbacks. Android is the validation
target; iOS remains experimental and untested.

## Gate grown parameters

`app.info().bridge` is your app's schema number. `builtins` is Valence's capability
revision, currently 15, independent of how many custom methods your app added.

```ts
const info = await call('app.info');
if (has('data.list') && (info.builtins ?? 0) >= 5) {
  await call('data.list', { bucket: 'places', after: lastKey, limit: 100 });
}
```

Declaring `builtins: "int?"` on the app.info return type opts into current
parameter shapes for declared built-ins. Codegen rejects a reporting schema that
omits `data.list.after` or `auth.setToken.account/discardPending`. Update those
optional params too, or omit builtins and keep the earlier sibling-method gates.
Methods may still be omitted or disabled: use `has()` and the capability's
permission/opt-in rules. `has('data.count')` remains the compatible cursor gate
for earlier hosts that support paging but have no builtins field.

## Reconstruct the last sync outcome

`sync.status().reason` survives redraws and restarts because it is stored in native
SQLite, atomically with the other sync observations before releasing the lease.
It is null before an attempt, including a migrated database. Busy/skipped runs,
no-server runs and thrown failures retain the previous observation. A completed
scoped run replaces it too; only a successful unscoped run advances lastSyncedAt.
Account switch/sign-out clears it with the account's rows and other observations.

`unauthorized` can now reconstruct a sign-in warning after navigation. The string
set is open: unknown values are not success. This is the last attempted scope,
not an acknowledgement for every bucket. Keep an app-owned receipt if an error
must stay visible until an explicit authenticated check succeeds. Anonymous-401
handling is unchanged. Older hosts still need the documented prefs fallback.

## Read the pending update's urgency

`bundle.status().urgent` is true or false only after re-verifying the pending
bundle's signed local manifest. No pending bundle, failed verification or a
concurrent pending change produces null. It never describes the pointer's offer,
starts a download, or activates a bundle. Both false and true updates remain
eligible for the existing explicit applyUpdate flow and emit updateReady.

The Dart API keeps synchronous `bundleStatus()` for existing callers; generated
schemas declaring urgent use the additive async `bundleStatusWithUrgency()`.
Urgency can change wording or prominence, and never bypasses trial/ready/rollback.

Source of truth: contracts, "Schema 15 returned-field additions (R17)".
