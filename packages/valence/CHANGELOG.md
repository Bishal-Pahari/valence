# Changelog


## Unreleased: bounded session-cookie persistence

- Native `http.cookieJar.sessionCookieDays` opts into 1–30 days for session cookies across restarts. Off by default; run codegen and rebuild the host. Deadlines never renew on reload; sign-out and account-switch clearing still apply. [Guide](https://getvalence.pages.dev/docs/guides/persistent-sessions/).
