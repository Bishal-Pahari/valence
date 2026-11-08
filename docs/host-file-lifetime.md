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
either does not revoke the URL, and nothing collects these copies on its own:
restarting, rebinding the server, committing or rolling back an OTA, bundle garbage
collection and signing out all leave them, and there is no quota, age limit, expiry
or automatic eviction. **The absence of automatic collection is deliberate.** A
published URL lives in durable rows the host cannot read, so a host-side sweep by
age or size would blank images the app still references, with nothing in either log.

What 0.4 provides is the explicit half:

```dart
// In the same operation that deletes the row or file that owned the URL.
await valence.revokeHostFile(url);
```

`revokeHostFile(url)` takes the relative URL `publishHostFile` returned, deletes
that publication's bytes and MIME sidecar, and returns whether a copy was there to
delete — so revoking twice is a `false` rather than an error, and a delete path can
be re-run after a crash. Anything that is not one of this host's publication URLs
throws `ArgumentError`: the id is matched against the same pattern that minted it
and the file path is rebuilt from the match, so nothing a caller wrote is ever
joined to a directory. The bytes are deleted before the sidecar, because a serve
needs both — a kill between the two deletes leaves a URL that already 404s.

`listHostFiles()` returns every publication still on disk, each with its relative
URL, `sizeBytes` and `modified` time. That is the reconcile path for a copy whose
owning row never got written — a crash between the publish and the insert, which no
delete path can reach: compare the listing with the app's own rows and revoke what
nothing references. It reads the directory and the entries' sizes, not the sidecars,
so it reports no content types.

Both calls are native-only by decision. There is no bridge method for either,
because publishing is native-only too, so the page never holds the authority to
delete bytes out of app-private storage or to enumerate what is there; it asks one
of the app's own methods, which decides.

A revoked URL 404s, but the WebView's cache is not the disk. HTTP
`private, max-age=31536000, immutable` controls browser reuse, so a document that
already loaded a publication may keep rendering it from cache after the file is
gone, and bytes the page copied into a canvas, an object URL or its own storage were
never the host's to recall. Revocation reclaims disk and ends new reads; it is not
secure erasure of what the page already has. A page that must stop showing an image
drops the URL from its row and re-renders.

So revoke the publication in the same operation that deletes the row, and a photo's
Remove action can honestly say it removed the copy. Do not treat a published URL as
account-scoped authorization, and avoid publishing material that needs guarantees
this page withholds. Do not sweep `host/` by age — durable rows may still hold those
URLs — and do not reset app data to reclaim space, which also destroys the database
and unsent writes.

The security rules in [contracts section 3](../.claude/skills/valence/references/contracts.md)
still apply: native bytes only, host-minted ids, strict path validation, allowed
non-scriptable MIME types, `nosniff`, sandbox CSP and blocked main-frame navigation.
There is no HTTP upload or delete endpoint. These protections do not supply
retention or per-account access control.
