# Sync outcomes (R26)

Server and protocol failures now return `SyncResult.reason: "failed"` instead of
`ok`, including anonymous 401, HTTP 403/500, invalid JSON and incomplete paginated
or static pulls. A token-bearing 401 remains `unauthorized` and emits auth expiry;
transport failure remains `offline`. Precedence is unauthorized, offline, failed,
ok. Successfully applied pages remain applied, unacknowledged writes remain queued,
and incomplete runs do not advance the last successful unscoped timestamp.

The existing reason field is an open nullable string: no schema, package version,
CLI behavior or generated shape changes. Codegen and templates already transport
arbitrary strings. A page must treat unknown reasons as incomplete. A positive
changed count is not a full-sync receipt, and scoped success is not global freshness.

Decision: use the existing incomplete marker rather than introduce another failure
flag or infer success from HTTP reachability. Preserve the authenticated-401 gate
and failure precedence so a public server failure never asks users to replace a
valid token. No token, cursor, acknowledgement or bridge-security path changes.

The site guide is `/docs/guides/sync-outcomes/`. Older hosts may still return ok for
these failures, so the new string is not a capability test. iOS is experimental
and untested.
