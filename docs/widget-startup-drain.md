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
