# Periodic sync timing correction - 2026-11-10

In plain terms: a registered Android periodic job does not promise a sync every
15 minutes. That is WorkManager's minimum repeat interval; constraints and
system optimizations can delay or skip runs. Foreground and reconnect sync remain
the path to freshness while the app is open.

Read both apps' findings and newest reports: Kundalini iteration 24 and App C
iteration 191. All 33 must-have roadmap rows are already done, including the
original rebase queue. No item is reassigned or reopened. App C F-61 identifies
the reversed interval wording in the host guide; contracts section 5.6 repeats
it. The correction also reaches the package README and the site's data/sync
guide. The runtime, codegen, templates and schema allocations need no change:
the scheduler is the host application's responsibility, and the faulty promise
was documentation only. Package versions remain unchanged.

Primary evidence, checked November 10:
[Android periodic work](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work#schedule_periodic_work)
defines the minimum interval and explains delayed/skipped runs. The change does
not impose a minimum gap on every observed callback or retry, nor does one
callback establish natural cadence. iOS BGTaskScheduler remains best effort;
iOS is experimental and untested.

Decision: correct the promise instead of increasing scheduling priority, adding
retries or changing data ownership. A scheduler guarantee the OS does not offer
would mislead developers without protecting users' data. Foreground triggers,
the sync lease and background isolation remain intact.

App C reports qualified Android acceptance, with rebuilt Settings continuity in
PID 5122. Its initial offline spinner/UI Automator exit 137 and media CDP timeout
remain separate from successful continuations. Native startup 6432ms is not a
paint measurement or a lock-holder diagnosis. The eligible worker was explicitly
triggered; its 762.208-second observation window proves no execution duration or
cadence. Historical reliability and publication crash-recovery findings remain
open. Kundalini's F-85 log timestamp qualification is already addressed in the
current base; no additional runtime change is inferred from the retrieved report.

Read-only consistency review resolved 51 local report links, rehashed both archived
APKs against their receipts and verified five embedded payload hashes/sizes in
each. All 66 saved audit checks pass; raw callback/SUCCESS and lease lines match
the saved full log. Pending activation bytes before and after the worker match
(SHA256 `354b5ac5b9cfcc9c15f4bfe43275625b9ef914c308a1177c9628fd598def82b3`).
These checks verify saved artifacts, not fresh device acceptance or scheduler
cadence. No test-app script was executed.

Security review: documentation-only changes preserve canonical verification
order, nonce/strict decoding, navigation and subframe locks, atomic state, key
handling, publication authority and release-build exclusion of development mode.
Test app repositories were read only. No fresh emulator/iOS acceptance, push or
publication is claimed.

Initial gates: root 123 tests with zero skips (generated Dart analyzed and
exercised), core 675 tests and fatal-info analysis passed. The first core pub dry
run exited 65 because the changed package README was uncommitted. This is a
packaging-state warning; commit the documentation before rerunning that gate.
Remaining results will be recorded after the gates finish.
