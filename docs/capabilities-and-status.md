# Capability revisions and durable status

Schema 15 adds nullable returned fields. Regenerate the bridge and ship a store
build; an OTA cannot add native support. Existing store baselines stay unchanged.
Old hosts omit these fields, so use nullish fallbacks. Android is the validation
target; iOS remains experimental and untested.

## Gate grown parameters

`app.info().bridge` is your app's schema number. `builtins` is Valence's capability
revision, currently 20, independent of how many custom methods your app added.

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
must stay visible until an explicit authenticated check succeeds. An anonymous
401 is stored as `failed`, without emitting `auth.expired`; the stored reason
matches the returned result. See [Sync outcomes](sync-outcomes.md).
Older hosts still need the documented prefs fallback.

## Read the pending update's urgency

`bundle.status().urgent` is true or false only after re-verifying the pending
bundle's signed local manifest. No pending bundle, failed verification or a
concurrent pending change produces null. It never describes the pointer's offer,
starts a download, or activates a bundle. Both false and true updates remain
eligible for the existing explicit applyUpdate flow and emit updateReady.

The Dart API keeps synchronous `bundleStatus()` for existing callers; generated
schemas declaring urgent use the additive async `bundleStatusWithUrgency()`.
Urgency can change wording or prominence, and never bypasses trial/ready/rollback.

## Revision 20: who holds the sync lease

Two more nullable returned fields, on `SyncStatus`: `leaseKind` and `leaseAgeMs`.
`reason` says a run was refused; these say by what, and for how long — `leaseAgeMs`
counting from when the holder took the lease, so it only increases while one run
holds it. `leaseKind`
is `foreground`, `background`, `push`, or `unknown` for a held lease written by an
older host — an open set, so treat an unrecognised value as "something holds it".
Both are null whenever a run starting now would **not** be refused, including a
lease the host is about to take over: past its two-minute expiry, dated in the
future, or left by a process that is gone. Gate on `(info.builtins ?? 0) >= 20`.

They are for reporting a stuck-looking sync accurately, not for deciding a holder
has leaked — a page cannot release another run's lease, and expiry and takeover are
unchanged. The host log carries the same facts: a refused run prints the holder,
its age and its own kind, each run prints taking and releasing the lease, and the
background isolate brackets its run, so a lease a torn-down isolate never released
is a missing line. See [Sync outcomes](sync-outcomes.md).

Source of truth: contracts, "Schema 15 returned-field additions (R17)" and
"Revision 20 returned-field additions (S9)".
