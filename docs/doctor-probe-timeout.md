# Windows Flutter discovery classification - 2026-11-08

In plain terms: a timed-out Windows Flutter lookup was replaced with ENOENT,
so doctor warned that Flutter was unavailable and could exit successfully without
running dependency or mapped-test checks. Discovery now preserves timeout,
signal and execution failures. A missing where.exe is also a failed discovery;
only completed exit 1 without an error or signal means no Flutter match.
No Flutter command starts after failed discovery. Update the vendored CLI;
no host rebuild is needed for this correction.

The regression executes each shipped wrapper with a simulated Windows process
and drives the real diagnose dependency and mapped-test rows. It covers selected
45-second budgets, timeout, signal, access denial, missing discovery utility,
unexpected exit, completed no-match, success and unsafe Flutter arguments.
Both the original timeout defect and missing-utility edge failed their new cases
before the corrections; the final regression passes for both CLI copies.
A read-only review found no remaining concrete issue.

Decision: an unexecuted check cannot become evidence of an absent SDK. Keep the
failure and its recovery instructions, without adding runtime dependencies or
changing versions, schema numbers, signing or bridge behavior.

Final combined-tree gates passed 2026-11-08:

- Root `npm test`: 123 passed, zero skips; generated Dart analyzed/executed.
- Core `flutter test --no-pub --concurrency=1`: 665 passed; fatal-info analysis clean.
- Core pub dry run: zero warnings.
- Push: 2 tests passed, fatal-info analysis clean, pub dry run zero warnings/one local override hint.
- Bridge: 37 tests passed, strict/verbatim TypeScript and pack dry run passed.
- Example: codegen check wrote nothing, 29 tests passed, debug APK built (Gradle 46.7s).
- Windows `py example/tool/check_no_firebase.py`: PASS over the core graph, manifest and 19 DEX files.
- Site: 50-page build and SEO/link checks passed.

These are combined integration results, not separate standalone branch gate runs.
The rebuilt integration trees matched the tested trees byte for byte before
validation-only notes: code a391e2e7fd8586eaf992076639abe1bfe191492b;
site 747192c12e59e219ff13f860c6643dcd0b76c1d8.

The initial combined core gate had 664 passes and one cached-policy widget
pending-timer failure. Unmodified isolated and full-widget retries passed; the
fixture was then aligned with the shared real-I/O mounting/teardown helper.
The final 665-test run above includes that correction. The initial failure is
retained, not counted as a pass. See [fixture evidence](widget-startup-drain.md).
No fresh emulator or iOS acceptance; test-app repositories remained read-only.

