# Example capability revision assertion - 2026-11-05

In plain terms: the example wiring suite still expected built-in revision 19 after
S9 moved the runtime to revision 20. Its isolated `R17 nullable fields marshal
through the generated dispatcher` test failed with `Expected: 19 / Actual: 20`.
The runtime suite already checks revision 20 independently of an app's schema.

The example now compares the dispatched `app.info().builtins` with the runtime's
direct public `appInfo().builtins`. This checks that generated dispatch preserves
the runtime result without duplicating a release-specific capability number in
a marshalling test. Its separate `bridge == hostBridgeVersion` assertion remains.
The isolated test passes after the change.

Decision: preserve the runtime, frozen schema and security checks; correct the
stale test instead of changing the runtime's advertised capabilities. This is a
test correction, so contracts, codegen and templates need no behavior change.
No package or schema version changes. Full combined gates and app evidence are
recorded in [the integration ledger](integration.md).
