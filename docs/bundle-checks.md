# Explicit update checks and completion

A mounted page can miss an offer refused because its host is too old: the check
finishes after the mount read, and no bundle becomes pending. Revision 19 adds
`bundle.check()` and `bundle.checked` to cover that case.

Declare the method with no params and return type `void`. Declare the event with
exact payload `{reason: string, requiredBridge: int?}`. Both have reserved minimum
`since: 19`; for a name new since your last store build, choose a value at least
19 and greater than that build's schema version. Raise your schema version to
cover it, refresh the CLI, regenerate, upgrade the native package and rebuild.
Older hosts need a store release; an OTA cannot add this capability.

For the status re-read recipe below, also declare nullable `requiredBridge: int?` on the return type of `bundle.status` (whatever your app calls that type). A legacy status shape without it preserves its `rejected` projection; the completion event independently carries authenticated `needsStoreUpdate` and `requiredBridge`.

Subscribe before the mount read, and read the authoritative status on completion:

```ts
const refresh = async () => renderStatus(await call('bundle.status'));
const stop = has('bundle.checked')
  ? on('bundle.checked', () => { void refresh(); })
  : on('bundle.updateReady', () => { void refresh(); });
await refresh();
// On an explicit Retry action:
if (has('bundle.check')) {
  await call('bundle.check');
  await refresh();
}
// On unmount: stop();
```

`bundle.checked` reports each completed check, including needsStoreUpdate,
offline and uptodate. It carries the completed reason and nullable authenticated
requiredBridge. It is a prompt to re-read status, not an instruction to apply an
update. It is dropped while no page is loaded; the mount read supplies current
state. Missing or pre-19 app-owned declarations do not receive automatic events.

`bundle.updateReady` still means a verified bundle became pending. A refused
offer does not emit it. Existing subscriptions keep their meaning.

`bundle.check` joins a host check already in flight and waits for discovery and
the native store-policy transition. One joined check emits one completion. It
never applies pending state; the page still chooses when to call applyUpdate.
It keeps rollout, signature, identity, floor, data-readiness and size checks.
A signed minHost can close the page and show Update required, exactly as it can
on resume. A promise resolving does not mean an update was accepted: inspect
status. Unexpected failures remain logged and keep the last completed status.
Do not tie another check directly to the completion event; that creates a loop.

Debug live development skips signed discovery, including explicit checks. Custom
hosts must wire Valence.onCheckForUpdate to their coalesced discovery and native
policy transitions; without an attached host callback the RPC returns
E_UNSUPPORTED. Calling the updater alone does not enforce the native block.

Android widget/runtime and generated-code tests exercise the path. Emulator
acceptance is separate. iOS remains experimental and untested.
