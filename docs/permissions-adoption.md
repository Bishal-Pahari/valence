# Permissions adoption wording - 2026-11-02

App-c iteration 56 identifies a documentation contradiction: the permissions guide
said to copy since 10 rather than the app's next number, while the shipped-schema
additive rule refuses new names at or below the shipped version. Read both test
apps' findings and newest completed reports, Kundalini 18 / app-c 56, read-only.

Decision: preserve shipped contracts and user data before convenience. New
permission methods/events use since >= max(10, shipped store schema version + 1),
and an app schema version at least that high. A shipped schema-10 app adds new
names at 11 or higher. Already-shipped declarations keep their since and shape.
Ten is the starter's introduction version, not a permissions delegation floor:
the existing generator delegates permissions at any valid since. Guard calls and
event subscriptions with has() for older hosts. The guide now guards its event
example too. The general bridge guide distinguishes app history from delegation
floors; the contract, repository guide, package README and machine-readable site
summary agree. No runtime, template, generator, schema or version was changed.

Feature-branch gates on codex/permissions-adoption:

- npm test: 113 passed, zero skips; generated Dart and strict/verbatim TS ran.
- Core flutter test: 603 passed; dart analyze --fatal-infos .: no issues.
- Bridge: 29 tests passed; strict/verbatim TypeScript passed.
- Site npm run build and SEO: 45 pages passed.
- Diff hygiene and the prose/example changes were reviewed.

Logs: %TEMP%/valence-permissions-feature-*.log. No mirror test was added for this
prose-only correction. Full packaging, example and artifact gates are recorded
separately on the combined integration tree.

Security-path checklist: verification order, signatures, strict decoding, nonce,
navigation/subframe locks, atomic writes, key handling, permission allowlist and
foreground checks, account isolation and release-mode development exclusion are
unchanged. No runtime security review or fresh emulator acceptance is claimed.
Historical intermittent findings remain open; a successful attempt cannot close
them. No test-app writes, protected-branch changes, push or publication.
