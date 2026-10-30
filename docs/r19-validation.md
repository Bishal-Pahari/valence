# R19 validation - 2026-10-27

## In plain terms

Regenerated handlers refuse to start with a plugin that the schema declares but
the app has not registered. They also refuse a registered plugin version missing
one of the exact declared methods. The failure names what to register and rebuild.
Doctor names requirements without pretending to execute Dart registration.

Branch: `codex/r19` in both repositories. Code base `ebb0793d576c74c6841686298c9ad828479f02b7`,
site base `afe2366c75670aa31811e0b2681fdc313f5d8751`.
Implementation commits: code `8cbb844`, documentation `29571f0`; site `e577ba1`.

## Decisions and security review

Security first: preserve generated nonce and strict parameter decoding, frozen
built-in shapes, reserved namespaces, fragment containment and app-owned stamps.
The merged wire schema, store baseline and all `since` values are unchanged.
No package release version changed. Manifest verification, navigation, state writes,
account handling, secrets and sync were not modified.

Namespace-only validation would miss a registered plugin whose installed version
lacks a declared method. Generate both `hostPluginNamespaces` and
`hostPluginMethods`; retain event-only namespaces even when their method set is
empty. The runtime factory validates both sets after snapshotting registrations.
Use `StateError`, not a debug assertion, so this failure cannot disappear in
profile or release builds. Extra native methods still have no generated cases.

Keep the original registry constructor for older generated handlers and direct
native callers. The new `checked` factory is additive. Existing callers still
receive `E_UNSUPPORTED` for a missing direct invocation. Newly generated
`ValenceBuiltins` always uses the checked factory. Upgrade the unreleased runtime
and tooling together before regenerating.

Doctor cannot prove an arbitrary Dart constructor's runtime behavior by searching
source. Its new row is WARN for configured plugins and lists requirements plus
the real app-handler construction test to run. No plugins is PASS. This does not
prove initialization, permission setup, emitted events or platform behavior.

Review of the final diff found no confirmed security defect. Regression coverage
includes absent namespace, missing exact method, event-only plugin, extra methods,
legacy direct calls, compiled generated-handler refusal and existing strict
dispatch/nonce checks. The runnable example constructs its real handlers and
invokes its haptics plugin in the native suite.

## Gates

| Gate | Result |
|---|---|
| Root `npm test` | 90 passed, zero failed/skipped; generated Dart compilation and strict TS ran |
| Runtime `flutter test` | 495 passed |
| Runtime `dart analyze --fatal-infos .` | No issues |
| Example `flutter test` | 24 passed |
| Bridge tests | 29 passed |
| Bridge strict TypeScript and pack dry run | Passed |
| Source and vendored example `codegen --check` | Fresh, zero writes; CLIs identical |
| Signed built-in verification | Passed, seq 1793062826, two files |
| Runtime pub publish dry run | Zero warnings |
| Example debug APK | Built successfully; existing KGP warnings retained |
| Site build and SEO/link checks | 37 pages passed |
| Both worktrees `diff --check` | Clean |

Read both apps' findings and newest reports read-only: Kundalini iteration 12
and app-a iteration 11. App-a's matched snapshots resolve its F-32; Kundalini's
F-52 describes an earlier mismatched pair. No supplied snapshots were rewritten.
R24-R26 already address reconnect, seed bookkeeping and failed sync reporting.
Migration build friction and retention observations remain outside R19.

No new emulator run. Android device acceptance remains separate from host tests;
iOS is experimental and untested. No shared-branch commit/merge, push, publication
or test-app modification. The new branch must join the pending numeric-order
integration before improver acceptance.
