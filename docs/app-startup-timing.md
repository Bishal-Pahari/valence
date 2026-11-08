# App-owned startup timing - 2026-11-08

In plain terms: the host can finish opening before an app finishes its own media,
reminder and link setup. The startup guide now shows how to time those existing
awaits and the first Flutter frame separately. A first frame can still be a loading
screen; the helper never calls web ready().

## Decision and scope

Security first, then users' data: add fixed-label observation without changing
startup ordering, exception propagation, retries, lease timing or trial deadlines.
The logger cannot replace an initialization error. Labels are enum values and
contain no paths, values, credentials or exception bodies. No runtime, dependency,
schema, template or package version changes are needed. Contracts section 5.1.1,
the source guide and website guide agree. The reviewer checklist applies here to
diagnostic privacy, preserved error behavior and separation from OTA readiness;
no executable security path changed.

Read both findings inventories and newest reports: Kundalini 23 and App C 155.
All must-have and original queue items are already done; this is an R29
documentation follow-up. App C's raw app-phases-initial.txt records runtime open
at 68371ms, then named app setup and a later firstFrame marker. Those boundaries
do not identify a lock owner or ANR cause. The requested example closes the guide
gap, not the startup failure.

App C's saved final-artifact-audit.json has 25 passing checks and fullAcceptance
false. Independently rehashed both archived APKs and verified the five embedded
files in each against their manifest hashes/sizes (builtin 1794126683).
Doctor's JSON rows count 17 PASS / 10 WARN / zero FAIL. Raw worker log lines show
PID7773 begin, background lease entry/take/release/exit, completion and native
SUCCESS at 16:46:04.983-16:46:06.752. The job was explicitly forced after its
recorded eligibility; this is no natural-cadence claim. Saved native SQLite says
stable, outgoing objects match writes, outbox zero before foreground resume.
The activation comparison retains identical pending1794135039/no-trial bytes.
Final saved state has current1794135039, previous1794135029, no pending/trial;
original inspection matches and no iteration fixtures remain.

The MIME verdict returns image/png for the retained 216195-byte PNG, with original
SHA256 0ec1c49d2c866e985dc405776138e138ad3963ad3ebca7dd1b44e37af82c650a.
F-56 is app-owned and repaired in that repo; no source or durable URL was changed
here. F-55's stale migration instruction is already corrected by the included
migration-dependencies branch. Initial startup/renderer/host low-memory failures
remain separate from recovered checks. Canonical-package fresh installation and
Kundalini F-83's rebuilt-host device recheck remain open. F-57 is harness feedback;
the shared harness was not modified. Test app repos were read only.

## Validation

All commands below ran against the combined integration containing this branch.
Flutter commands ran serially.

| Gate | Result |
| --- | --- |
| Root npm test | 123 passed, zero skips; generated Dart analysis/dispatch executed |
| Core tests / fatal-info analysis / pub dry run | 665 passed / clean / zero warnings |
| Push tests / fatal-info analysis / pub dry run | 2 passed / clean / zero warnings, one local-override hint |
| Bridge tests / strict-verbatim TypeScript / pack dry run | 37 passed / passed / passed |
| Documented Dart helper | Extracted verbatim into example, fatal-info analysis clean; temporary file removed |
| Example codegen / tests | clean / 29 passed |
| Example debug APK / standalone Windows py Firebase audit | built (151.7s) / PASS: graph, manifest and 19 DEX files |
| Website build and SEO | 50 pages passed |

The APK build retains its existing Android Kotlin migration warning.

No new emulator acceptance was attempted for this documentation change. iOS
remains experimental and untested. S1 stays parked, S2 needs Play, S10/P1 remain
deferred. Nothing was published or pushed.
