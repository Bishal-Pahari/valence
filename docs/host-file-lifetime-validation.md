# Host-file publication limits - 2026-11-08

In plain terms: removing a source photo does not remove copies already published
to the WebView. The spec, package README, source guide and website now state the
0.4 lifetime, lack of deduplication/quotas/expiry/revocation, and safe URL reuse.
The immutable-cache explanation now describes immutable publications accurately:
the current ids are random, not hashes of the content.

## Decision and evidence

All must-have and original rebase-queue items are done. Read both findings
inventories and newest reports, Kundalini 23 / App C 156. This documentation
follow-up addresses the missing retention explanation in App C F-27; it does not
close the finding or implement cleanup. Security first, then users' data: do not
evict files still referenced by durable rows or reset the owner's database.
Publication is not account-scoped authorization or secure erasure. No executable
runtime, generator, template, dependency, schema or package-version change.

Checked runtime.dart's delegation and server.dart's random-id generation, durable
bytes/MIME writes and serving path. App C's saved publication-lifetime-proof.json
records two fixture URLs still answering 200 after source removal. Its storage
receipt counts 9685 host files / 943660 KiB, versus 224 KiB source media; this is
retained history, not a leak rate or a demonstrated startup cause.

Independently resolved all 56 report links and rehashed both archived APKs:
release 252515c519c6aaab32c37ae31ee548769ad3d8c65e1517851c4759a6509d5232;
debug 89dbf6c5c3053ac2ab0c689c1cb9ba7de5c9e61eef78e851fe70f82e74e1e7df.
Verified all five embedded files per APK against manifest hashes/sizes, builtin
1794139244. The saved audit has 79 passing checks and scopedAcceptance=true.
Inspected fresh-painted.png: canonical release content shows six seed units,
zero photos and no widget. The saved receipt identifies an independent AVD and
offline first launch. This is saved app-run evidence, not a new device execution.
Initial owner startup failures and LOW_MEMORY exits remain separate; Kundalini
F-83 still needs its rebuilt-host device recheck. F-55's migration correction is
already included in integration. Test-app repositories were read only.

## Combined validation

Fresh gates ran on integrations containing this branch; Flutter commands ran
serially. Subsequent changes add only these validation/handoff notes.

| Gate | Result |
| --- | --- |
| Root npm test | 123 passed, zero skips; generated Dart analysis/dispatch executed |
| Core tests / fatal-info analysis / pub dry run | 665 passed / clean / zero warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / clean / zero warnings, one local-override hint |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 37 passed / passed / passed |
| Example codegen / tests / debug APK | no writes / 29 passed / built, Gradle 130.0s |
| Standalone Windows py Firebase audit | PASS: graph, manifest and 19 DEX files |
| Website build / SEO / rendered lifetime guidance | 50 pages passed / passed / present |

Logs: %TEMP%/valence-host-lifetime-*.log. The APK retains its existing Kotlin
migration warning. No new emulator acceptance was attempted; iOS remains
experimental and untested. Security checklist: signature/check ordering, nonce,
strict decoding, navigation lock, MIME/CSP protections, atomic state and key
handling are unchanged. No HTTP deletion route or page-supplied filesystem path
was introduced. S1 stays parked, S2 needs Play, S10/P1 remain deferred. No pushes,
publications, shared-branch commits or test-app writes.
