# Seed import and recovery

The bundled seed provides data before the first network request (contracts section 5.2).
After a successful import, Valence records the host build and asset length in the reserved
`valence.seed.imported` preference. If that marker matches and the extracted seed file exists,
the next launch skips the import. A changed build, changed asset length or missing extracted
file causes another import. Rebuild the host when changing a bundled seed.

Rows and completion bookkeeping are separate. A marker failure does not undo rows that already
committed. For `SQLITE_BUSY` and `SQLITE_LOCKED`, the marker write gets at most five attempts,
with a one-second delay between attempts, matching the database-open backoff. The retry writes
only the marker; it does not repeat the row import. Other failures are reported immediately.
SQLite's own busy timeout can add to the elapsed time, so this is an attempt limit, not a
five-second launch deadline.

Read these log messages separately:

| Message | What it establishes |
| --- | --- |
| `seed: skipped; completion marker matches host build and asset length` | The extracted seed exists and this host's seed already completed. |
| `seed: imported {…}` | How many rows were copied; it does not establish that the completion marker was saved. |
| `seed: completion marker database locked; retrying in one second` | Rows finished importing; the marker is waiting on a database lock. |
| `seed: completion marker recorded after retry` | The marker recovered during this launch. |
| `seed: rows imported; completion marker not recorded` | Startup continues with the imported data. The next launch retries because the old marker remains. |
| `seed: import incomplete` | The row import or its cleanup failed. Earlier pairs may have committed; the marker remains unchanged and the next launch retries. |

On retry, each pair imports only rows above its current local cursor. A seed older than data
synced between launches cannot replace those newer rows or lower the cursor. Import failures
do not clear the store, and a seed never marks a pair as pulled for the OTA data gate.

No schema, generated handler or app configuration change is needed. Upgrade the Flutter runtime
and ship a host build; an OTA web bundle cannot change native seed handling.

Regression tests exercise the real seed import with SQLite and inject marker-only lock and
non-lock failures. Android device checks remain separate; iOS is experimental and untested.
