# Forcing an update

A release that needs a newer native host can now say so separately from corrupted
bytes. This follows contracts 2.3, 2.5 and 4.6. iOS remains experimental and untested.

## Offer an update without blocking use

Ship the new store build first, wait until it is available, then cut an OTA release.
`requires.bridge` remains the minimum bridge needed to execute that UI. A supporting
host reports `reason: "needsStoreUpdate"` and `requiredBridge` when it is too old.
The existing signed UI keeps working. Signature, identity, sequence, floor, metadata
and file failures continue to mean `rejected`.

To opt in, add nullable `requiredBridge: "int?"` and `minHost: "int?"` to your
BundleStatus type; declare `app.openStore` with `since: 17`, no params, `returns:
"void"`; increase your own schema above its last store baseline (at least 17),
regenerate and ship a store build. Do not change existing method shapes or since
values. `app.info().builtins >= 17` identifies the new runtime revision; older
schemas without requiredBridge keep the legacy rejected reason. A new declaration
does not upgrade a previously installed runtime.

```ts
const status = await call('bundle.status');
if (status.reason === 'needsStoreUpdate') {
  // Show an update prompt, and call this from the user's button:
  if (has('app.openStore')) await call('app.openStore');
}
```

## Require a store update

First ship the supporting host to users. When retiring hosts below bridge 18:

```sh
node valence/valence.mjs bundle --min-host 18
node valence/valence.mjs pointer --seq <new-seq> --rollout 100
```

Upload files, signed manifest and signature, then the pointer last. `minHost` is a
positive integer in the signed manifest. It is the app's generated host bridge
version, not Valence's package version or Android version. It is separate from the
bundle's UI compatibility requirement; a pinned `--requires-bridge 17` can coexist
with `--min-host 18`. A built-in cannot demand a version above its own host.

Once an eligible supporting host verifies a policy above its version, it shows a
native **Update required** screen with **Open store** and **Check again**, replacing
the web view. It retains users' rows and queued edits. A pending/trial bundle is
not consumed and blocking does not count a failed trial. Exact signed policy bytes
are cached and verified on restart, so a network failure does not remove a block.
`BundleStatus.minHost` retains that policy even when the last attempt is offline.

Android's destination is fixed from the compiled application ID at
`https://play.google.com/store/apps/details?id=<appId>`. A page and the manifest
cannot choose another URL. For iOS configure `"store": {"iosAppId": "123456789"}`
in valence.config.json before codegen; without it app.openStore returns
E_UNSUPPORTED. Launch failure returns E_INTERNAL and the native screen allows a
retry. iOS is experimental and untested. No Play account, store publication or
remote device upgrade has been verified by package tests.

## Withdraw a mistaken policy

Sign a **higher sequence** release omitting `--min-host`, or using a lower value,
and publish its pointer. A verified newer manifest supersedes the previous policy.
Changing the unsigned pointer alone, replaying an older signed manifest, a bad
signature, malformed metadata or an offline request cannot clear it. The host's
Check again button discovers a signed withdrawal and recreates the web page.
Upgrading the host to a sufficient bridge version also unblocks use.

This is an availability policy with consequences: do not require a store build
that users cannot install yet. Staged rollout still controls discovery; an offline
phone that has never received the policy cannot be forced, nor can an older runtime
that ignores minHost. This is not a replacement for server-side authorization or
store review. Data and the outbox are retained throughout.
