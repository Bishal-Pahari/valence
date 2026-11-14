# Keep an API session across restarts

Contracts §4.5.1. Session cookies stay in memory by default. If your API allows a
mobile session to survive a process restart, opt in in the native configuration:

```json
"http": {
  "origins": ["https://api.example.com"],
  "cookieJar": {
    "origin": "https://api.example.com",
    "sessionCookieDays": 7
  }
}
```

Run `valence codegen`, rebuild and distribute the host. An OTA cannot enable this.
The bridge schema is unchanged. Add the existing optional `csrf` pair when your
server requires it. Doctor reports both the jar and its session lifetime.

`sessionCookieDays` accepts an integer from 1 to 30. Omit it to keep session cookies
in memory; null, zero and fractions are configuration errors. Enabling it extends
the lifetime requested by a server cookie without expiry, so agree this policy
with the API owner. Server-side expiry can still reject a retained credential.

The deadline starts when the host receives Set-Cookie. Restarts, requests and a
larger configured lifetime never renew it. A fresh Set-Cookie replaces the cookie.
Reducing the setting shortens existing deadlines from the original receipt time.
Removing it drops stored session cookies before the first request, while preserving
cookies with explicit server expiry. Explicit Expires, Max-Age and deletion are
never extended by this option.

Sign-out and an account switch empty the jar, and a response already in flight cannot
refill it, and a request that straddles the change sends no cookie either: each request
carries the jar's generation, a response whose generation has moved on has its
`Set-Cookie` dropped, and the outgoing `Cookie` and CSRF header are omitted when the
generation moved after the request began — otherwise one account's bearer token could go
out beside the next account's session. The page still receives the response.

Cookies remain in the reserved secure-storage key, never readable or writable by
the page. The same one-origin grant, HTTPS rule (loopback excepted), path matching
and limits of 16 cookies, 4096 bytes each and 8 KiB total apply. Sign-out and account
switch clear the jar; moving or removing the jar revokes it. OTA updates preserve
the fixed deadline. A secure-storage failure can leave this process signed in but
does not guarantee persistence across restart; the server remains the authority. If a
shorter or removed session grant cannot be saved, the jar is disabled for that
launch while the app starts. This does not claim durable revocation.

Android is the supported test platform. iOS is experimental and untested.
