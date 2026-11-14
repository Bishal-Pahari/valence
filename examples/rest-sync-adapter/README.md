# Connect an existing REST API

This dependency-free Node 22.18+ example serves one user's writable `items` bucket at schema 1.
It is a reference adapter, not a multi-user production server. It binds only `127.0.0.1`.

Your upstream API must provide a complete authoritative `GET /items` array of objects with stable
string `id` fields, `PUT /items/:id` accepting that object, and `DELETE /items/:id`. PUT/DELETE
must honor `Idempotency-Key` across retries. This matters if the process crashes after the REST
write succeeds but before its local SQLite transaction commits. An absent DELETE must succeed.
If your API paginates snapshots, collect every page before comparing for deletions: a partial
snapshot would incorrectly tombstone unseen records. Adapt `snapshot` and `rest` to your API.

```powershell
$env:UPSTREAM_URL = 'http://127.0.0.1:9000'
$env:ADAPTER_TOKEN = '<a local test bearer token>'
$env:UPSTREAM_TOKEN = '<upstream credential, if needed>'
$env:ADAPTER_DB = 'adapter.db'
node examples/rest-sync-adapter/server.mjs
```

Keep credentials in environment variables, outside the web bundle. Ignore `adapter.db*` in your
app repository. Keep and back up this database: deleting it loses the monotonic clock, tombstones
and acknowledged operation ids. Do not expire tombstones or ids without a retention protocol.
The `ops` table deliberately grows without bound; production needs an explicit client retention
policy before collecting it. Keep one adapter process per database. Requests serialize upstream
refresh and writes, which favors clarity over throughput. Requests and upstream snapshots are
limited to 1 MiB; pushes accept every operation within that byte cap, including backlogs above
200 operations. Larger datasets need a paged snapshot and a bounded push design before deployment.

Run `adb reverse tcp:8787 tcp:8787` on Android. Point a test app at
`sync.base: "http://127.0.0.1:8787"`, `writable: ["items"]` and call
`auth.setToken` with `ADAPTER_TOKEN`. There is no `items` entry in `data`: writable buckets always
use schema 1. For native online RPC also add `"http": {"origins": ["http://127.0.0.1:8787"], …}`
and regenerate the host. `GET /rpc` returns only `{native: true, authenticated: true}` to exercise
`http.request` with no CORS headers or token reflection. Forward loopback on an emulator or a
USB-connected physical device. Use HTTPS for remote services: an explicitly configured HTTP
origin can receive the token in release builds too, regardless of Android's network security
XML. iOS is untested.

The adapter compares the REST snapshot with durable rows, assigns a new USN only to changes,
and retains a deletion as `{k, v: null, u, d: 1}`. A pull is ordered by USN; when there is another
page, `max` is the last row returned, **never the later server head**. Unknown schemas are 404.
Push calls the REST write first, then atomically records both the row and the operation receipt.
A retry of an acknowledged id returns the current winning row without another REST write; reuse
of an id for different content returns 409 for the whole batch, with no acknowledgements in that response. Earlier operations in the batch may already have succeeded; retry their unchanged ids safely. The upstream write response is assumed to accept the
submitted object unchanged; APIs that normalize values must read/map the canonical value before
recording their receipt. Upstream errors never acknowledge that operation; a retry resumes safely.

For production, isolate state and operation ids by authenticated user/tenant, authorize every
bucket and row, use TLS, bound workload and enforce rate limits. Do not share this example's
single-user database among identities. The fixed upstream credential belongs to the server;
an embedded client secret would be recoverable from an APK. The host's native HTTP method is
for user tokens, not for hiding a shared server secret.

Run `node --test examples/rest-sync-adapter/server.test.mjs`. The test starts a real local REST
server, pulls 600 records over two pages, observes a deletion, retries a push after adapter
restart, rejects operation-id reuse, verifies deletion propagation and drains 601 queued writes.
