# R12 validation — 2026-10-21

In plain terms: pages can read many records in one call and display the actual number of queued edits,
including deletes. Releases stay reachable by the recorded store host by default. Channels, older seed
schemas, partial handler tests and mechanical diagnostics now have supported configuration and APIs.

## Changes

| Ledger item | Delivered |
|---|---|
| U-4 | Schema-3 `data.getMany`, maximum 500 input keys, active schema, bound SQL, stable requested order, deduplication and tombstone omission. |
| U-5 | Schema-3 `sync.status`; current outbox count and persisted observations. Optional `SyncResult.pending`. Busy, transport, HTTP and malformed-protocol paths cannot advance the success timestamp. |
| U-7 | Primary-source check dated 2026-10-21; ordinary dependency range `path_provider_android >=2.2.17 <2.3.0`, resolved and device-tested at 2.2.23. Removed the example-only override. Flutter 3.44.2 supports native assets; the reported missing-library root cause remains unverified. |
| U-8 | Validated `ota.channel`, generated `valenceOtaChannel`, host configuration and beta-pointer URL regression. |
| U-9 | Vendored `doctor [--tests]`, built-in/seed/dependency checks, explicit evidence warnings and per-layer test mappings. The wizard includes these checks. |
| U-12 | Explicit additional `seedSchemas`, multiple versioned files, atomic validation and runtime import of every allowed pair. |
| U-14 | OTA defaults to the recorded store schema; explicit overrides and built-in/store defaults remain available. Newer calls still need guards. |
| U-15 | Opt-in generated `BridgeHandlersDefaults`; unsupported handlers dispatch `E_UNSUPPORTED`. Nullable constructor arguments are optional. |

The spec, runtime, generator, templates, signed example, package documentation, workflow and site docs
are updated together. Release version numbers are unchanged.

## Gates

- `npm test`: 52 passed, zero skipped. Generated Dart ran against Flutter; generated TypeScript compiled under strict/verbatim module settings.
- `packages/valence`: `flutter test` 311 passed; `dart analyze --fatal-infos .` clean.
- `packages/bridge`: 18 tests passed; strict `tsc -p tsconfig.json` clean; build and pack dry run include the compiled distribution.
- Example: 13 wiring tests passed; debug APK built; codegen check and built-in signature/file verification passed.
- Site: 24 pages built; SEO/link/anchor checks passed.
- `flutter pub publish --dry-run`: zero warnings. This was validation only.

Independent security review checked the new data/dispatch boundary, baseline compatibility, diagnostic
path containment and constrained command arguments. Its timestamp and seed-import findings were fixed
and rechecked with regressions; no finding remains in that review.

## Android evidence

On emulator-5554, with the shared lock held, the example served signed built-in 1792590042 at bridge 3.
Its initial `data.getMany(['fern', 'missing', 'fern'])` returned one seeded fern row. The UI reported
pending zero. Two taps on Add produced two outbox operations; deleting the newest note produced three
pending operations, including one delete, while only the older live note remained visible. A native
SQLite snapshot confirmed `COUNT(*) = 3`, `SUM(deleted) = 1`. Force-stop/restart preserved the count,
the seeded read and the live note. [The restart screenshot](r12-device.png) shows the bridge results.

The first device launch exposed an inherited example startup issue: it called the first plugin before
initializing the Flutter binding. The example now initializes it before `Valence.open`; the subsequent
launches passed. The `.invalid` sync/OTA endpoints stayed local failures: no successful production
network sync is claimed. Successful timestamps and multi-schema imports are covered by runtime tests.

The example is stopped and the shared lock released. No test-app repositories were modified. iOS is
experimental and untested. No push, merge into a shared branch, release tag or publication was performed.

## Sprint merge refresh ? 2026-10-21

Merged the latest packages branch, preserving both the auth/secure demo and the schema-3 batch/status demo. Rebuilt and signed built-in 1792594935 with the CLI; codegen and signature/file verification pass. Refreshed gates: 52 CLI/wizard tests (zero skipped), 311 Flutter tests, 13 example tests, 18 bridge tests, strict TypeScript, Dart analysis, bridge pack dry run, debug APK and 24-page site/SEO build all pass. Pub dry run after the merge commit reports zero warnings. Independent security review found no confirmed defect in the merge resolution. No additional device run was performed during this refresh.
