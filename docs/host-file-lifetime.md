# Published host files in 0.4

`valence.publishHostFile(bytes, contentType: ...)` writes a durable copy and returns
a relative `/_host/f/<id>` URL. Each call uses a new random id, including calls with
identical bytes. Persist and reuse the returned URL for that publication instead
of publishing again whenever a row is read or an image renders.

**Pass the type the bytes actually are** (C F-56). A picker's `imageQuality` is a
re-encode request, not a guarantee, so a gallery pick can come back as PNG bytes in
a `.jpg` path — and a `contentType` taken from the extension then publishes
`image/jpeg` over `89 50 4E 47`. `nosniff` keeps that safe, which is why it is a
correctness bug and not a security one: the browser believes the header, the image
decodes by luck, and everything that reads the stated type is wrong. Derive it from
the leading bytes. Because a published id is immutable, a correction is a new id:
the old URL keeps serving the same bytes under the type it was born with.

The published copy is independent of the original file and any SQLite row. Removing
either does not revoke the URL. Restarting, rebinding the server, committing or
rolling back an OTA, bundle garbage collection and signing out do not collect it.
There is no built-in quota, age limit, expiry, eviction or public revocation/cleanup
API in 0.4. HTTP `private, max-age=31536000, immutable` controls browser reuse;
it promises neither disk cleanup after a year nor recall of cached bytes.

Do not treat a published URL as account-scoped authorization or promise that a
photo's Remove action erases published copies. Avoid publishing sensitive material
that requires revocation or secure erasure. No supported cleanup recipe currently
provides those guarantees. Sweeping `host/` by age can break URLs still held by
durable rows; resetting app data also destroys the database and unsent writes.
A bounded lifecycle needs a reference and revocation design before an eviction
policy can safely remove files.

The security rules in [contracts section 3](../.claude/skills/valence/references/contracts.md)
still apply: native bytes only, host-minted ids, strict path validation, allowed
non-scriptable MIME types, `nosniff`, sandbox CSP and blocked main-frame navigation.
There is no HTTP upload or delete endpoint. These protections do not supply
retention or per-account access control.
