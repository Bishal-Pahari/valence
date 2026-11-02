# R33: bounded API session persistence — 2026-11-02

Based on code packages 0302556 / site packages 62f950b. Read both test-app findings
and latest completed reports at intake, Kundalini 18 / app-c 63, read-only.
The original queue is done; refreshed integration first, then selected R33 from
the bottom of the new must-have items. R32 remains for a later run.

## Decision and behavior

Security first: omitted sessionCookieDays preserves memory-only sessions. A compiled
integer 1..30 opts into secure storage for cookies without server expiry. The cap
makes this an explicit bounded extension of the server's session lifetime; the API
owner must permit it. Receipt and deadline are recorded together. Restarts or a
larger policy never extend an existing grant; smaller policies clamp from receipt.
Opt-out removes tagged session cookies while retaining ordinary expiring cookies.
A failed reduction write seals the jar for the launch, without failing startup or
claiming durable revocation. Server expiry/deletion and the existing origin, path,
size/count, reserved-key and account-switch boundaries retain their behavior.

No schema or package version changes. The template deliberately omits the option:
a new host must not acquire credential persistence without asking for it. Codegen
emits the app-specific policy; the runtime owns cookie behavior. The example's
copied CLI is synchronized. No bridge package API change is needed.

## Review and evidence limits

Independent valence-reviewer passes covered the initial change and failed-storage
hardening, with no confirmed unresolved findings. Boundary probes separately
checked 1/30 acceptance and null/0/negative/31/fraction/string/bool refusal.
Runtime regressions cover restart, expiry, shortening, removal, deletion, another
origin, read-only storage, invalid manual policy, account switch and sign-out.
Generated Dart compilation includes the new constructor field; doctor reports
memory-only versus fixed-day persistence.

App-c's current renderer loss and startup ANR remain major release qualifications;
recovered feature successes do not close them. This item has no new emulator
acceptance; iOS remains experimental and untested. No test-app writes, protected
branch changes, push or publication.

## Gates

- Root npm test: 113 passed, zero failures/skips, including generated Dart with
  sessionCookieDays and generated strict/verbatim TypeScript.
- Runtime: 609 tests passed serially; fatal-info analysis clean after fixing two
  formatter-exposed missing-brace infos. The initial failing analysis is retained
  separately and is not counted as passing.
- Core pub dry run: zero warnings after committing the package. A separate initial
  dirty-file warning is retained; it did not pass.
- Push: 2 tests, clean fatal-info analysis, zero-warning pub dry run (one local
  override hint).
- Bridge: 36 tests, strict TypeScript and pack dry run passed.
- Example: 29 tests; debug APK built in 25.7 seconds. Standalone Windows py audit:
  PASS: core graph and 19 DEX files / manifest contain no Firebase SDK references.
- Root pack dry run passed. Site build/SEO: 48 pages passed.

No fresh device acceptance is inferred from these gates. The one-line default
config template stays opt-out; constructor emission is exercised by the generated
Dart gate rather than enabling session persistence in every new project.
