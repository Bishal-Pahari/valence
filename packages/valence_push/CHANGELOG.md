# Changelog

## Unreleased: a push-woken sync says so

No API change. The `sync:` callback a host passes to `ValencePush.handleBackground` should now call
`Valence.backgroundSync(config, kind: ValenceSyncKind.push)`, so a run woken by a data-only message is
distinguishable from the periodic job in the sync lease, in `sync.status` and in the log. The template
does this; a host that omits it reports `background`, which is harmless but less useful.

## 0.4.0-beta.0

Extract Firebase into an opt-in transport package. Schema 12 and push wire shapes stay unchanged. Android delivery needs a Firebase project; iOS is experimental and untested.
