# Cached update-blocker widget test teardown - 2026-11-08

In plain terms: the integration gate found a pending database diagnostics timer in
the cached-policy cold-start widget case. The blocker can paint before its startup
sync completes. That test mounted in fake time and disposed without the shared
helper's final I/O drain. It now follows the helper: mount in `tester.runAsync`,
dispose, drain real I/O, then let fixture teardown close its test-owned database.

The first full core run failed this case: 664 passed, one failed. The unmodified
case passed in isolation and all 31 widget cases passed on a separate retry, so
this is a timing-sensitive harness failure, not a deterministic runtime leak
reproduction. The patched isolated case passes. Final combined-tree gates are
recorded in [integration validation](integration.md).

Decision: preserve runtime diagnostics and users' data paths. This is a test
fixture correction; production code, lease policy, schema, package versions,
signed assets and native update blocking are unchanged. The policy assertions
still require a visible blocker, no WebView and exactly unchanged activation state.
No fresh emulator or iOS acceptance is claimed.

+Final combined-tree gates passed 2026-11-08:

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
