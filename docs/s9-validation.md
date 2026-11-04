# S9: the sync lease says who is holding it

**Date:** 2026-11-04. **Built-in revision:** 20. **Finding:** app-c F-44 (major as reported).

## What the finding actually said

App-c spent four iterations (62, 84, 86, 87) capturing one shape: a bounded `sync.now` probe after a
reconnect answers `busy` / `pending 1` twenty times in a row, a WorkManager run is seen beginning and
being cancelled about a second later, and a `HOME` / `am kill` / relaunch then drains the queued writes
on the first try.

Every one of those reports says the same thing about itself: **it does not identify the owning operation
and does not prove a lease-expiry violation.** That is the finding's real content. §5.6's lease is a
`prefs` row holding a timestamp and a pid, and the only thing a page or a log could learn from it was the
boolean `busy` — so "a cancelled background isolate did not release its lease" and "a foreground run is
legitimately still working" were indistinguishable from outside, by the page, by the native log, and by
four iterations of evidence.

So this is a diagnosability bug before it is a lease bug, and that is what was fixed.

## What shipped

**The lease row carries the holder's kind.** `valence.sync.lease` is now
`<epoch ms>:<pid>:<kind>` — `foreground`, `background` or `push`. The field is *appended*, so a row
written by a 0.4 host before this revision (`<ms>:<pid>`) and a 0.3 row (`<ms>`) both still parse, and an
older host reading a newer row still finds the pid, the only field its own logic uses. `renewLease`
rewrites the kind too, so a refused run learns who holds it now rather than who took it.

**`SyncStatus` gains `leaseKind: string?` and `leaseAgeMs: int?`,** nullable grown returned fields at
built-in revision 20, gated by `(info.builtins ?? 0) >= 20`.

**The log names the holder.** A refused run prints `holder=`, `heldForMs=` and its own `refused=` kind;
taking and releasing the lease are each one line with the kind and how long it was held; and the
background isolate brackets its whole run with `entered` / `left`.

## The four decisions, and why

1. **A third colon-separated field, not a second `prefs` row.** The lease is written in
   `BEGIN IMMEDIATE` as one row read-then-write, which is what makes it atomic across isolates. A second
   row could disagree with the first, and the disagreement would be invisible — a diagnostics feature
   whose own data can be wrong is worse than none. Appending keeps the read backward compatible in both
   directions.

2. **`leaseKind` and `leaseAgeMs` are non-null on exactly the predicate `acquireLease` refuses on**, from
   one shared helper so the two cannot drift. A lease the host would simply take over — past its
   two-minute expiry, dated in the future, or left by a launch that is gone — reports **free**, because it
   is not what a `busy` answer is about and the next run will take it. Naming a holder the next run
   displaces would send a developer hunting a leak that does not exist, which is the same class of wrong
   answer this item was filed about. The log names those three cases instead, where they belong.

3. **A held row that records no kind reports `"unknown"`, never null.** Null means "a run starting now
   would not be refused". Reporting "free" for a lease that is genuinely held but written by an older host
   would be a lie on the one path where the page is asking *because* it was refused — the exact conflation
   the field exists to end. Security and data honesty before convenience.

4. **Acquisition and expiry are untouched.** Changing lease lifetime or takeover on a
   verification-adjacent path, two weeks from a beta, to address a cause nobody has established, is the
   trade the roadmap exists to refuse. The diagnostics are cheap, additive, and are what turns the next
   reproduction into a diagnosis. If a device run with these fields *does* show a real leak, the leak is a
   0.4 fix written against evidence instead of a plausible story.

## Gates

| Gate | Result |
|---|---|
| `npm test` (both root suites) | 117 / 117, zero skips — the generated-Dart and strict-TS tests both ran |
| `flutter test` (`packages/valence`) | 627 / 627 |
| `dart analyze --fatal-infos .` (`packages/valence`) | clean |
| `flutter pub publish --dry-run` (`packages/valence`) | warning-free on a clean tree |
| `packages/valence_push`: tests, analysis, dry run | 2 / 2, clean, warning-free |
| `packages/bridge`: `node --test`, strict `tsc`, `npm pack --dry-run` | pass |
| Site build + SEO gate | 50 pages, green |

**Test sensitivity was checked, not assumed.** Each of the five new `sync_test.dart` cases was re-run
against a deliberately broken runtime — the kind dropped from the lease value, the pid check removed from
the held-lease predicate, and `'unknown'` replaced by null — and each failed on the behaviour it claims to
cover.

## What is not claimed

**No device run, and no §8 device row.** The diagnostics exist so the *next* reproduction of F-44 on a
real phone can be read; nothing in `flutter test` reproduces a WorkManager cancellation, and because this
change deliberately alters no lease timing there is nothing about a leak for a test to assert. **F-44 is
not closed by this.** It is made diagnosable. The emulator was not taken for this item: there is no
behaviour change a run on it would exercise that the unit suite does not, and the lock is shared with two
test apps.

iOS remains experimental and untested.
