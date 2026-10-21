## Valence

This app follows the Valence architecture:

- a Flutter host in `<host dir>/`;
- the web UI in `<web app dir>/`, shipped inside the app and as signed over-the-air bundles;
- native SQLite for data;
- a typed bridge between them.

The spec is `valence` [contracts.md](https://github.com/Bishal-Pahari/valence/blob/main/.claude/skills/valence/references/contracts.md). Run `/valence doctor` after any change to the host, the bridge or the data layer.

**Where a change goes:**

| Change | Where | Ships via |
|---|---|---|
| UI, copy, styles, web logic | `<web app dir>/` | OTA bundle (`/valence release`), no store review |
| Data rows or a correction to bundled data | sync API (a new row with a higher `usn`) | sync, no app change at all |
| A new data shape for a read-only bucket | bump its schema in `valence/valence.config.json` `data`, and have the server serve both versions | OTA bundle plus sync |
| A new native capability (camera, share, widget …) | `valence/bridge.schema.json`, then `node valence/valence.mjs codegen`, then the handler in `<host dir>/lib/valence/handlers.dart` | **store release** |
| A new top-level feature area or route | web app | **store release**, because the OTA must not change the app's purpose |

**Rules for every agent and contributor:**

1. **Never edit `*.g.dart` or `bridge.g.ts`.** Edit `valence/bridge.schema.json` and run `node valence/valence.mjs codegen`. CI runs `codegen --check`, which also refuses to change anything a store build already shipped.
2. **The bridge schema is additive only.** Bump `version`, give new methods `since = version`, and add `name.v2` instead of changing a method.
3. **Web code calls native features only through `<web lib>/bridge.g.ts`** (`call`, `has`, `on`, `ready`), never from `@getvalence/bridge` directly: the generated file is what types a call against this app's schema.
   - Guard methods newer than the oldest live host with `has()`.
   - Every browser fallback lives in `<web lib>/shim.ts`.
4. **Durable data goes in native SQLite** (`data.*`, `prefs.*`), never in localStorage or IndexedDB, which are only a cache.
5. **The web app must call `ready()` exactly once per page load, on every path that paints — including the ones that show no data.** A first-run gate, an empty state, a permission prompt, an error screen and an offline screen all paint without the data load ever finishing, and on a fresh install one of them is the whole first launch. If a bundle misses `ready()` twice, devices drop that bundle: healthy code gets rolled back and it looks like the OTA is broken. Put the call where every rendered path reaches it, not at the end of the data load.
6. **No iframes to other origins and no CSP meta tag.** Embeds open externally. The host sends the CSP from the signed manifest; add API origins to `valence.config.json` `web.connect`.
7. **Never put native code in the web output.** That means no `.so`, `.dex`, `.jar`, `.dylib` or `.framework` files; `valence bundle` rejects them.
8. **The signing key lives in `~/.valence/keys/` or the `VALENCE_SIGNING_KEY` CI secret.** Never commit it, print it or paste it into a prompt.
9. **Commit `.valence/baseline.json` after every release.** It keeps `seq` and `floor` increasing across machines. Build the bundle for a store submission with `valence bundle --store`, so the reviewed routes and bridge schema become the baseline.
10. **To roll back, release again from the last good commit.** That gives it a new seq. Pointing the channel at an old seq doesn't revert devices.
11. **Keep `.gitattributes` intact.** The built-in bundle must stay byte-exact, or its signature fails.
12. **First launch must work in airplane mode.** That requires the built-in bundle plus `seed.db`.
13. **The host and bridge runtimes are packages** (`valence` on pub.dev, `@getvalence/bridge` on npm). Never vendor or hand-patch them: `flutter pub upgrade valence` and `npm update @getvalence/bridge` are how a fix arrives. Report a bug in either upstream rather than working around it here.
14. **Keep sync cursors and activation evidence separate.** Use package sync; push echoes do not advance pull cursors, and partial pulls do not satisfy a new required pair. The package migrates outbox insertion order without deleting queued writes. See contracts section 5 before changing adapters.
