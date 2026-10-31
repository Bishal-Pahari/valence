# R31 validation - 2026-10-31

In plain terms: a supporting host can distinguish an OTA needing a newer store
build from corrupt bytes, and a signed minimum-host policy can require an update
with a native screen while keeping saved data and queued edits.

## Branches and decisions

Started codex/r31 from code packages d771105ad666e84b29c1545ed7b6db403f79d46a
and site packages 53d3a919b999fe62fee3d3928bbaf3a235068c58. The original
rebase queue is already merged. R31 is the newly eligible Codex must-have;
revision 17 is reserved in its Status cell. Runtime/package versions are unchanged.
Implementation code 7851078fd33f036039f6741b907f8118d98436bc; site documentation
99991db6b982697b515b11262b76a98ef0ad23dd. Later report commits do not change behavior.

Security first: minHost lives only in signed manifest bytes, never in the unsigned
pointer or a page-controlled URL. Canonical verification stops in its existing
order. A check-5 incompatible offer is revalidated through all metadata checks
before its policy can be remembered; this second pass cannot execute a bundle.
Malformed requires.bridge and minHost are refused. Persist exact signed envelopes
atomically, revalidate at Valence.open, and allow only a higher authenticated seq
to supersede policy. Rollout still gates discovery. Older runtimes cannot be forced.

Users' data next: no store/data/outbox reset, no floor/bad/trial mutation on a
refusal; native blocking clears only the serving marker and pauses ready timing.
A newer signed withdrawal recreates the page. Optional fields retain the frozen
BundleStatus shape, and older generated declarations retain rejected. The store
URL comes from compiled appId / numeric iOS ID; open.external's schemes stay frozen.
The example Android applicationId now matches its existing compiled appId;
namespace stays unchanged. Existing demo installs under the old sample package ID
retain their separate data; adopters must keep their own production identity.

## App evidence read, without writes

Read both VALENCE_FINDINGS.md files and newest reports: Kundalini iteration 16,
app-c iteration 13 (still in progress). Kundalini adopts schema-17 link.initial,
records warm/cold/repeated links, rejected destinations, reboot alarm recovery and
a bridge-16-pinned OTA. F-64 retirement is already addressed upstream. App-c 13
records one startup/worker overlap completing in 4804ms, successful settled sync
and an offline write draining after reconnect. This is not completed acceptance
and does not close major F-33; F-27 remains open. No transaction, retry or lease
changes are justified by these observations. R31 does not fix the concurrency report.

## Gates

| Gate | Result |
|---|---|
| npm test | 107 passed, zero skipped; generated Dart compiled and ran |
| Core flutter test --concurrency=1 | 556 passed |
| Core dart analyze --fatal-infos . | No issues |
| Bridge node tests | 29 passed |
| Bridge strict/verbatim TypeScript | Passed with tsconfig.json |
| Example flutter test | 28 passed |
| Push-adapter flutter test / analyzer | 2 passed / no issues |
| Core / push pub publish --dry-run | Zero warnings / zero warnings with existing local-override hint |
| Root / bridge npm pack --dry-run | Passed |
| Site build + SEO | 44 pages passed |
| Example codegen --check / builtin signature | No stale files / seq 1793431100 verified |
| Debug APK | 452.2s first build; 60.8s after sample applicationId correction |
| Windows py Firebase audit | PASS: graph, manifest and all 19 DEX files contain no Firebase SDK references |

Final APK SHA256: 18123186a1fbfd5cdaf3071d733c0fb2bf43e485941b5992c664f8ddb84cb8b3.
Detailed gate logs remain under %TEMP%/valence-r31-*.log. No publication occurred.

## Android device scope

Took and released codex-builder's harness lock on emulator-5554. Installed only
the example. The signed builtin served and called ready. Injected a **cached signed
policy envelope**, seq 1793431101 / minHost 18, into this debug example's own
files/valence directory; this is not a network OTA-policy delivery test. A native
Update required screen replaced the WebView. Repeated a cold start with airplane
mode on: the same native block appeared. Screenshot and accessibility XML are in
[evidence/r31](evidence/r31/offline-blocked.png). The state retained current
1793431100, pending/trial null, trialFails 0, bad empty and floor 0; serving was null.

After restoring connectivity, tapping Open store opened com.android.vending;
ActivityTaskManager recorded an HTTPS play.google.com VIEW launched by
com.getvalence.example. There is no published example listing or verified store
upgrade. Replacing only the cached bytes while retaining the signature produced
`cached store policy refused: check 1: bad manifest signature`, then the normal
signed builtin served and called ready. This negative probe is not a policy
withdrawal: higher signed withdrawal and trial preservation are covered in tests.

Removed the injected cache and remote fixtures, force-stopped only the example,
returned Home, restored airplane mode off and released the lock. No test-app repo
or data was written. The first UI dump was too early (null root), excluded from
acceptance. The first attempted package launch used the sample's mismatched ID;
that exposed the configuration correction above and is not counted as a pass.

## Review and earlier failed attempts

Independent final review has no confirmed remaining findings, with eight focused
R31 Flutter tests passing independently, plus the focused CLI test and codegen
check. Full package gates are separate evidence. Review caught missing cache-open
wiring and malformed requires.bridge acceptance; both were corrected with regressions.

Initial root run failed five stale-template/vendored-generator expectations; fixed
fixtures and byte-identical example CLI, then 107/107 passed. Early widget compile
errors were corrected. The successful withdrawal test initially restarted real
loopback I/O inside the fake async zone and hung cleanup: entering the tap through
runAsync and awaiting the new controller load fixed it. A stopped overlapping core
run caused a Windows sqlite3.dll access failure; the clean serial run passed 556.
The first analyzer run exposed formatting-related fatal infos, fixed. Initial pub
dry-run had dirty-tree/replaced-asset warnings, followed by committed zero-warning
runs. Example initially expected builtins/bridge 16; corrected to 17 and added
strict R31 dispatch assertions, then 28/28 passed. Existing Gradle/Kotlin migration
messages remain; they are not pub-package warnings.

iOS is experimental and untested. Real remote-policy delivery, a published store
upgrade and app-c concurrency acceptance are not established. No protected branch
commit/merge, version bump, push or publication was performed.
