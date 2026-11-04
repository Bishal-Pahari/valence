# Cache REST responses for offline reads

`http.request` fetches from an existing API. Revision 18 adds `data.cache` to keep
chosen JSON values in native SQLite for the next offline launch (contracts §5.5.1).
This is disposable data. Keep user edits in writable buckets with `data.put`.

Enable a bucket in the **store build**:

```json
{
  "data": { "days": 1 },
  "cache": ["days"],
  "http": { "origins": ["https://api.example.com"] }
}
```

Revision 18 is the package's reserved minimum, not the number every app should
copy. For a **new** declaration use `since >= max(18, shipped store schema
version + 1)` and raise the app schema `version` to at least that number. For
example, an app whose store baseline is 19 declares `since: 20` and `version: 20`.
The starter template uses 18 because it has no previous store baseline.

If `data.cache` already shipped, preserve its recorded `since` and shape. If the
CLI refuses a change, restore the recorded declaration from
`.valence/baseline.json` (`storeSchema.methods["data.cache"]`); do not rename it
to `data.cache.v2` or rebaseline to bypass the refusal. A renamed method does not
delegate to the package implementation. The following declaration is for the
store-19 example:

```json
"data.cache": {
  "since": 20,
  "params": { "bucket": "string", "key": "string", "value": "json?" },
  "returns": "void"
}
```

Regenerate and ship the native host. An OTA cannot add the compiled grant. Removing a grant in a store build
clears that bucket's retained overlays before native startup exposes reads;
underlying server rows, cursors and pending writes remain intact.
Import the app's generated bridge:

```ts
import { call, has } from './bridge.g';

if (has('data.cache')) {
  const response = await call('http.request', {
    url: 'https://api.example.com/day/2026-11-01',
  });
  if (response.status === 200) {
    await call('data.cache', {
      bucket: 'days', key: '2026-11-01', value: JSON.parse(response.body),
    });
  }
}
const day = await call('data.get', { bucket: 'days', key: '2026-11-01' });
```

Read SQLite first for an immediate offline paint, then refresh online. Validate
the API payload before caching it. Handle transport failures by retaining the
previous value. One encoded JSON value may occupy at most 65,536 UTF-8 bytes;
larger values fail `E_TOO_LARGE` without replacing the previous value. The page
must prune stale keys using `data.cache({bucket, key, value: null})`; there is no
automatic TTL or total cache quota. Null removes the overlay and reveals any
server row underneath. There is no literal-null cache value.

`data.list`, `getMany`, `get` and `count` combine cached and synced rows with one
row per key. Cache wins until a pull or seed import replaces that key, including
with a tombstone. Other keys survive. Key pagination and prefix filters span
both sources; concurrent writes are not a multi-page snapshot. List/batch rows
identify cache values with `usn: -2` (local-only). `-1` still means an unsent user
write. Cache values are page-supplied and must not be treated as authenticated
server records by native code. Use the underlying `kv` table for server provenance,
or a bucket without a cache grant.

Caching sends no network request, queues nothing, emits no sync event and changes
no sync cursor, outcome or freshness. Await the write and refetch. `sync.status`
describes server sync, not REST freshness. Cache-only data never satisfies the
OTA updater's synced-pair gate. For an API-only app, keep the bucket schema stable;
an OTA requiring a new schema still needs the normal sync readiness protocol.

A cache grant does **not** remove a bucket from sync. With `sync.base` configured,
normal unscoped sync pulls the active manifest's read-only data pairs, including
cache-enabled buckets. A scoped sync may select fewer buckets. Publish the
normal sync endpoint even when a bucket will contain only REST overlays. For a
new empty `days` bucket at schema 1, the dynamic endpoint answers HTTP 200:

```json
{ "bucket": "days", "schema": 1, "rows": [], "max": 0, "more": false }
```

Keep any existing server history and cursor; never replace a nonempty bucket's
endpoint with this example. Static sync needs the equivalent valid empty index
under the normal static protocol. A 404 makes the run incomplete (`failed`),
without undoing successful work in other buckets or deleting queued edits;
it is not an instruction to skip this bucket. With no `sync.base`, no pull is
attempted. There is no per-bucket cache-only sync exemption in 0.4.

A new data schema starts with no cached values. Old-schema values remain for
rollback until ordinary post-commit garbage collection removes that pair.
**A bundle that fails its trial takes every cached value with it.** The host drops
the whole cache on each of the two strikes, because one strike already puts the last
good bundle back on screen. The reason is that a cache key is not versioned by
anything a rollback moves: `requires.data` is the *bucket* schema, and a release
that changes the shape of a REST payload it caches normally leaves that alone — so
the same bucket, schema and key would hand the reverted bundle the failed one's
shape, through a read that prefers the cached value over the server row. Your
server rows, cursors and queued writes are untouched; the cache costs a refetch,
which is what makes it disposable. The schema-bump sentence above is the other
case: there the old schema's values are still the right shape for the bundle being
reverted to.
Recorded account switch/sign-out clears **all** cached values alongside writable
rows, and emits `sync.changed` for cache-enabled buckets. A refused `E_PENDING`
switch leaves them intact; refresh and first account adoption preserve them.
Record account IDs for account data, and discard responses from fetches started
under a previous account. Writes during a transition fail `E_INTERNAL`.

Unknown buckets and dot-segment keys fail `E_PARAMS`. Writable buckets and buckets
without the compiled cache grant fail `E_DENIED`. Android device acceptance for
this addition is recorded separately from unit checks; iOS remains experimental
and untested.
