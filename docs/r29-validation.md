# R29 validation - 2026-10-28

## In plain terms

Startup now identifies the phase it entered and how long it took. Database work
that stays pending names the operation instead of leaving only sqflite's generic
lock warning. This supplies evidence for a recurrence; it does not establish or
fix the cause of app-a F-33/F-35. The database, account, transaction bodies,
lease ownership, retry budgets and original errors retain their behavior.

Base: code `131f7ef45a39de17ff7ada2f706817e96de28152`, site
`61c06d1bacf9e900df7c90af7833622f5b8a131a`. Both branches are `codex/r29`.
Implementation: `87d6e2a`; code documentation: `3e475d3`; site: `d5a98a8`.
No package version, bridge schema, builtins revision or generator behavior change.
The skill and adopter template explain evidence capture; codegen continues to
import the runtime rather than copying these diagnostics into each app.

The prior queue's eighteen checked feature tips (R8, R7, R6, R3, R4, R5, R9, R10,
R14, R17, R19-R26) are ancestors of `packages` in both repos. No queue branch
needed another merge. R29 is the only new unmerged ready candidate from this run,
so the two-branch integration trigger has not been reached.

## Gates

| Gate | Result |
| --- | --- |
| Root `npm test` | 95 passed, zero skipped; generated Dart analyzed and exercised against the runtime, generated TS package binding included |
| Runtime `flutter test --no-pub --concurrency=1` | 542 passed, including nine new diagnostics/startup regressions |
| `dart analyze --fatal-infos .` | No issues, including the final added regressions |
| `flutter pub publish --dry-run` | Package has 0 warnings |
| Bridge `node --test test/*.test.ts` | 29 passed, zero skipped |
| Bridge `npx -y -p typescript tsc -p tsconfig.json --strict --verbatimModuleSyntax` | Passed |
| Bridge `npm pack --dry-run` | Passed |
| Site `npm run build` | 42 pages built; SEO checks passed |
| Example `flutter test --no-pub` | 26 passed |
| Example `flutter build apk --debug --no-pub` | Passed, 1,218.4 seconds; new `app-debug.apk` produced |
| Both repos `git diff --check` | Passed |

Logs are retained locally under `%TEMP%/valence-r29-*.log` (the completed runtime
rerun is `valence-r29-runtime-serial.log`). The initial focused runtime/diagnostics
run passed 77 tests. An early analyzer invocation found two style issues (an
unbraced conditional and a relative lib import); both were corrected before the
clean analysis and complete gates above.

The first full runtime attempt was interrupted after 32 passes and two widget
failures: navigation teardown reported a pending garbage-collection lease timer
(including a sqflite timer), and trial fallback observed a third loopback load
where two were expected. The original runtime log is retained separately as
`valence-r29-runtime.log`; it is not counted as a pass. No source fix, timeout
increase or assertion relaxation was made for those failures. The unchanged
cases then passed in the complete serial rerun. Two additional diagnostic tests
were added between runs. Host snapshots showed less than 1 GiB free out of roughly
32 GiB, but a cause for those failures was not established. No default-concurrency
full-suite pass is claimed.

The APK build used process-scoped `GRADLE_OPTS` setting
`-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2` and
`JAVA_TOOL_OPTIONS=-XX:ActiveProcessorCount=2`; the build's own daemon log confirmed
the 2 GiB heap and this worktree's Android directory. Existing KGP plugin migration
warnings remain. PowerShell rendered the JVM environment acknowledgement as a
`NativeCommandError` record; Flutter ultimately reported a built APK and exited 0.
No Gradle property file, global environment or other builder's process was changed.

## Security review and limits

The required independent security pass and follow-up found no confirmed defect.
The review checked transaction boundaries and `txn` executors, account clearing,
lease timestamps/ownership, retries/cache invalidation, database lifetime,
timer cleanup, error identity/stack and fixed labels without private arguments.
OTA verification order, nonce/strict decoding, navigation and atomic state
writes are unchanged. The new regressions also check cached-store logger
ownership and a wrapper-level locked-open error without printing SQL or paths.
Review did not run a second set of expensive gates; results above are the branch's
executed validation.

Decision: observe futures at existing database boundaries and report startup
entry before work begins. Timer output depends on the event loop and does not
identify a lock holder. Direct app/plugin calls through `store.db` need their
own diagnostics. First-opener logger ownership is documented and tested. Open
completion is separate from server/WebView startup and ready/commit evidence.

Read-only adoption inputs: Kundalini `VALENCE_FINDINGS.md` and newest iteration 13,
app-a `VALENCE_FINDINGS.md` and newest iteration 14. Kundalini's report retains
device/verification placeholders; app-a's latest slot lacked a booted Android
baseline and cancelled its release build. Its F-36 archive/docs mismatch and
F-33/F-35 still need matched-snapshot adoption and device evidence. This run
does not certify those apps or close their findings.

No new emulator session, data clearing, test-app writes, shared-branch commits
or merges, pushes or publications. Android build/unit evidence is separate from
device acceptance. iOS remains experimental and untested.
