# Pending-ID adoption documentation - 2026-11-02

App-c iteration 54's F-41 identified an unconditional `since: 16` instruction
that contradicted contracts §§4.1 and 6.5. Read both apps' findings and latest
completed reports, Kundalini 18 / app-c 54, read-only.

Decision: preserve shipped contracts and developer data. A new `notify.pendingIds`
declaration needs `since >= max(16, shipped store schema version + 1)` and app
schema `version` at least that value. An app already at 16 without the method
uses 17 or higher; an already-shipped declaration keeps its original `since`.
There is no baseline rewrite or runtime workaround. Update the tooling,
regenerate, ship a store build, and guard newer calls with `has()`.

Updated the contract's feature paragraph, repository/site notification guides,
package README copies, unreleased bridge changelog, site README and llms.txt.
The repository's stale app.openStore guide now states the same additive rule
with reserved minimum 17, matching the site's existing F-73 correction.
No implementation, template, generated asset, package version or schema value
changed; the existing generator already enforces the rule. No new mirror test
was added for this prose correction.

Branch bases: code packages 90af361 / site packages 6eb2bd6.
Required branch gates passed: 113 root tests, zero skips (both generated-language
checks ran); 603 core Flutter tests; clean fatal-info Dart analysis; 29 bridge
tests, strict/verbatim TypeScript and bridge pack dry run; 45-page site build/SEO.
Core pub dry run passed with zero warnings. Logs: %TEMP%/valence-f41-*.log.
Extended gates on the fresh combined integration are recorded in integration.md.

This is a documentation repair, not app acceptance or a new device run.
Fieldnote's existing since-16 declaration needs no change. Historical intermittent
findings remain open; no test-app finding was edited or closed here. Kundalini
has not accepted S6/S7/S8. S1 remains parked and S2 needs a Play account.
Security-path review: the delta is prose only; canonical verification, nonce,
decoding, navigation, atomic writes, key storage, account isolation and release
dev-mode exclusion remain unchanged. No emulator was used. Android device
acceptance remains separate; iOS is experimental and untested. No protected
branch changes, test-app writes, push or publication.

