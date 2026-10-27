# Integration validation - 2026-10-27

## In plain terms

R17, R21 and R22-R26 now run together on `codex/integration` in both repositories.
The page can reconstruct a failed sync after navigation, reconnecting checks for
signed updates, seed completion survives database locks, plugin errors identify
native faults, and the example grants local HTTP only to loopback. Live development
binds loopback by default and requires explicit trust for a LAN target. This candidate
is for acceptance by the improver; no shared branch or test-app snapshot changed.

Code base: `ebb0793d576c74c6841686298c9ad828479f02b7`.
Site base: `afe2366c75670aa31811e0b2681fdc313f5d8751`.
Tested implementation: code `08e0d5f`, site `e83cafa`.
The earlier R3-R10/R14 integration is already contained in both bases.

## Merge order and source commits

| Order | Branch | Code source | Code merge | Site source | Site merge |
|---|---|---|---|---|---|
| 1 | codex/r17 | a9922853bb751ac75590cb262d2d732cbed967d1 | 4c75928 | 971e5a93d6ff7e910c1c5640fc856940ea0861a4 | 81d7fd2 |
| 2 | codex/r21 | 92221ea7682259d7fea49b4f8afbb98d5d735610 | bd363aa | d3d0e2b226196d871d53c47224bcf491bc44a444 | 3a3ee1a |
| 3 | codex/r22 | b2e5a4009b44ea8729eafb208ee0be4a5aad876a | 085b7d2 | e84efa7a38d0858491632e429bc659b8252ffb55 | d043fa8 |
| 4 | codex/r23 | 373d29fca370bb03e2f49f148606bda8283950fa | 927efb9 | 0bcc4407a44cc260677dce499efad0cbfe4a6690 | 7081947 |
| 5 | codex/r24 | 23a2783f5c1bb8e68db2f6712a66b6caee542617 | b7261e2 | fcb04f2a5690a22dbf75cbdf1de2f06982aa1440 | 19d365b |
| 6 | codex/r25 | 52fd6e5c382df6582d5955b02586f77c80383c4c | 4bafc5c | 9f614ee0a44a9a4c98e5d07d16cba243151df60c | 8cbed0b |
| 7 | codex/r26 | 7c43658637da1f97a6fe3e80c2669ab83ec347ad | 08e0d5f | 14376728046b8ba6f6c062154d41fa1b41399176 | 9f26cea |

## Decisions and why

Security first, then user data: preserve R18 app-owned plugin stamps and its
own-property/integer checks while adding R17 generated fields and R22 result
decoding. Keep malformed native results at E_INTERNAL, deliberate plugin errors
unchanged, and nonce/strict parameter validation before invocation. The combined
source CLI is copied byte-for-byte into the example.

R21 defaults the server to loopback, retains the emulator target and requires
--allow-lan for every nonlocal address or hostname. The warning names the origin,
cleartext integrity risk and secure storage/SQLite/authentication privileges.
Manual Flutter defines remain direct trust grants; this flag adds no encryption.
The code and site changes merge cleanly with R22 proxy resource cleanup.

Use R26 classification once, under the lease, then R17 atomic observation writes.
The persisted reason and returned result must agree: authenticated rejection,
transport failure, incomplete response, then success. Added regressions check
persisted failed outcomes for anonymous 401/403/500 across driver replacement,
and partial-failure/scoped-recovery status. No cursor, queued write or previous
success timestamp is discarded. Account changes retain their existing clearing.

Preserve both sides of changelog/docs additions. Replace stale anonymous-401 prose
with the combined behavior in the spec and both capability/status guides.
Keep schema 15, all reserved since values and the genuine schema-1 store baseline.
R23 loopback HTTP configuration and R22 guarded haptics remain in the merged web
source. Reuse the previously rebuilt combined signed bundle after verifying
every hash and size against current web source, rather than choosing conflicting
branch manifests. Built-in seq is 1793115254, floor 0, two verified files. Package release
versions did not change.

The fresh integration resolves each conflict before committing. The earlier
validated candidate is ff1028f / d7510ad; this rebuild adds R21 in numeric order.

## Gates

| Gate | Result |
|---|---|
| Root npm test | 90 passed, zero failed/skipped; generated Dart and strict TS ran |
| Runtime flutter test | 526 passed |
| Runtime dart analyze --fatal-infos . | No issues |
| Example flutter test | 26 passed |
| Define-enabled dev proxy suite | 10 passed |
| Bridge tests | 29 passed, zero skips |
| Bridge strict/verbatim TypeScript and pack dry run | Passed |
| Generated example strict/verbatim TypeScript | Passed |
| Source and vendored codegen --check | Fresh, no writes |
| Built-in signature and CAS verification | Passed, seq 1793115254, two files |
| Runtime pub publish dry run | Zero warnings |
| Site build and SEO/link checks | 41 pages passed |
| Debug/release APK, embedded manifests and dev exclusion | Both built; signed bytes match source; dev sentinel/proxy and synthetic diagnostic absent from all 3 release AOT libraries |
| Both worktrees diff --check | Clean |

Android builds emitted existing plugin Kotlin migration notices. Neither build failed;
no dependency versions were changed to suppress notices.

## Review checklist and evidence limits

Local checklist review against contracts 2.2-2.4, 3.1, 4.2-4.6, 4.10, 5.2 and 5.6:
canonical signature/appId/sequence/floor/requires/path/hash verification stays in
the existing verifier; urgency re-verifies local signed metadata and cannot
activate a bundle. Reconnect uses existing updater coalescing and its data lease.
Seed retries only recognized lock failures in bookkeeping after row import.
R21 CLI denial happens before child startup, and the process regression checks
actual loopback/LAN binding arguments through the wizard. Plugin reservations
remain checked across CLI and runtime; cleanup does not
change proxy credentials/navigation/CSP. Atomic state and account transition
protections remain intact. Improver acceptance is still required; this is not
an independent review of the combined candidate.

App inputs were read-only: Kundalini VALENCE_FINDINGS and iteration 12, app-a
VALENCE_FINDINGS and iteration 11. App-a now reports a matched snapshot pair;
Kundalini still records F-52. No snapshot distribution repair is claimed.
App-a F-34 migration/desugaring friction and Kundalini retention/tombstone gaps
remain separate. No emulator run for this integration. Branch-local earlier
device evidence is in the item notes; it is not a combined-device pass. Firebase
delivery still needs the maintainer project; iOS is experimental and untested.
No push, publication, package version change or merge into packages/main.
