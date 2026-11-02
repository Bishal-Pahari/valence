# Response size grants

`http.request` response bodies default to 65,536 bytes. A native store build can grant
larger responses through optional `http.maxBodyBytes`, an integer from 1 through
262144. Request bodies remain capped at 65,536 bytes and headers at 16 KiB each.

```json
{"http":{"origins":["https://api.example.com"],"maxBodyBytes":196608}}
```

Run `valence codegen` and ship a new host. The generated `ValenceConfig.httpMaxBodyBytes`
is compiled policy: a page, CSP or signed OTA cannot raise it. There is no schema bump,
new method or response field, so `has('http.request')` does not tell you the configured
limit. `valence doctor` reports the effective grant in its **HTTP response limit** row.
The example host grants 196608 bytes; the starter template retains the 65536 default.

The cap counts **decompressed UTF-8 bytes**, not transfer size. A 4.8 KB gzipped API
response that expands to 133,712 bytes needs a grant of at least 133,712. The host reads
with a running byte limit and closes the request client when it refuses more bytes.
It never truncates a successful response. Strict UTF-8 decoding, origin grants,
credential-header denials, unfollowed redirects and the 20-second deadline still apply.

The complete escaped JSON reply, including headers and correlation id, must also fit
the unchanged **262144-byte bridge envelope**. A body within its grant can still get
`E_TOO_LARGE`: quotes, control characters and JavaScript line separators expand when
encoded. Even a 262144-byte plain body leaves no room for the envelope. Size the grant
for real payloads and retain error handling; no maximum body size guarantees delivery.
Use API pagination or `Range` when supported; there is no streaming bridge response.
A write may already have succeeded when its response is refused: use server-enforced
idempotency keys for retried writes.

Android is tested; iOS remains experimental and untested. Unit tests cover gzip,
stream boundaries, request-limit preservation and escaped reply overflow; emulator
evidence is reported separately in the validation note.
