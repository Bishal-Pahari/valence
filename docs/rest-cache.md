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

Declare the new method in your app's bridge schema. **18 is the revision the name was
reserved in, not the number most apps write.** Declare `max(18, your next schema
version)` and raise `version` to match; `codegen` does that arithmetic and names the
number in its refusal, so take the number it gives you and never lower it again:

```json
"data.cache": {
  "since": 18,
  "params": { "bucket": "string", "key": "string", "value": "json?" },
  "returns": "void"
}
```

**A cache-enabled bucket is still a data bucket, so it is still pulled.** Every bucket in
`data` is requested on every sync, so a bucket declared only to hold REST overlays asks
your sync server for rows it will never have — and a `404 unknown bucket` there fails the
**run**, not just that bucket: any non-200 pull makes the result `reason: "failed"` and
stops `lastSyncedAt` advancing, so every page reading `sync.status` is told the sync
failed even though the other buckets' rows arrived. Serve overlay-only buckets as an empty page
(`{"rows": [], "max": 0, "more": false}`). The reference adapter in
`examples/rest-sync-adapter` serves its one `items` bucket and 404s every other name on
purpose, so an overlay-only bucket has to be added there too, like any other backend.

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

A new data schema starts with no cached values. Old-schema values remain for
rollback until ordinary post-commit garbage collection removes that pair.
**A bundle that is given up on cannot refill the cache on its way out.** Dropping the
overlays is one step of a rollback whose other steps are asynchronous, and the failed
page is still able to call the bridge through all of them, so from just before the drop
until the replacement page starts `data.cache` answers `E_DENIED` and says why.

Recorded account switch/sign-out clears **all** cached values alongside writable
rows, and emits `sync.changed` for cache-enabled buckets. A refused `E_PENDING`
switch leaves them intact; refresh and first account adoption preserve them.
Record account IDs for account data, and discard responses from fetches started
under a previous account. Writes during a transition fail `E_INTERNAL`.

Unknown buckets and dot-segment keys fail `E_PARAMS`. Writable buckets and buckets
without the compiled cache grant fail `E_DENIED`. Android device acceptance for
this addition is recorded separately from unit checks; iOS remains experimental
and untested.
