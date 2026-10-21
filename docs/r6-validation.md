# R6 validation — 2026-10-22

Branch: `codex/r6` in the package and site worktrees. Base: package `packages`
at `406d153`; implementation commits `cfc523c` (package) and `62ee207` (site).

## In plain terms

Opening an approved OS link can take the user straight to a screen in the signed
web UI, retaining its query and fragment. The store build fixes accepted origins;
links cannot send the WebView outside loopback or authorize a native action.
Schema 5 adds `link.initial` and `link.opened`. `onLink()` connects a web router,
and `assetlinks`/`aasa` write website association files for separate HTTPS hosting.

## Evidence read

Both test-app repositories were read only. Kundalini's `VALENCE_FINDINGS.md` and
`ITERATION_9_REPORT.md` describe the first-run chooser, F-37 through F-40, and the
same-name asset cache failure. App-a has no standalone iteration report; its
latest available report is the cycle-5 summary in `VALENCE_FINDINGS.md`, followed
by findings through F-25, with a cycle-5 `NEXT.md`. These are historical app
results, not fresh validation of this package branch. No app repository changed.

## Gates

| Check | Result |
|---|---|
| `npm test` | 57 passed, zero skipped; generated Dart and strict TypeScript ran |
| Runtime `flutter test` | 343 passed |
| `dart analyze --fatal-infos` | No issues, including example |
| Bridge `node --test test/*.test.ts` | 22 passed |
| Bridge strict TypeScript / build / pack dry run | Passed |
| Example `flutter test` | 15 passed |
| Example `flutter build apk --debug` | Passed |
| Example generated-code freshness | No files written |
| Signed built-in verification | Passed; seq 1792607842, bridge 5 |
| APK's embedded manifest vs source | Same seq 1792607842 and bridge 5 |
| Site `npm run build` | 26 pages; SEO checks passed |
| `flutter pub publish --dry-run` after commit | Zero warnings |

## Security review

Independent review found no unresolved findings. A confirmed AASA validator
defect rejected hyphenated bundle IDs and accepted underscores; the fix accepts
the former and rejects the latter, with regression tests.

- External origins are compiled from `links.origins`; HTTP/CSP trust is separate.
- Raw strings are checked before `Uri.parse` can repair malformed escapes.
- Path validation rejects controls, backslashes, encoded separators, dot segments,
  network references and reserved host destinations. URLs are bounded in UTF-8.
- Startup keeps the latest pending link, deduplicates initial/stream startup
  delivery, and preserves subsequent repeat taps. Dispose cancels delivery.
- The web helper subscribes before reading the initial mailbox, gives live events
  priority over delayed initial replies, and suppresses navigation after cleanup.
- Generated dispatch retains nonce checks and strict decoding; nullable built-in
  return shapes cannot be redefined. Association generators refuse overwrites.
- Manifest signature/check order, navigation lock, nonce, atomic updater state
  and key handling are unchanged. No key or token contents are logged.

## Limits

iOS custom schemes and Universal Links are experimental and untested. The example
uses `links.example.invalid`, so genuine HTTPS ownership verification requires a
maintainer-controlled domain and the real app-signing certificate. A forced
Android approval can prove intent delivery only, not website ownership.

The example intentionally uses the direct wire protocol without a web bundler;
its screen routes accepted link payloads. The package helper's History API,
validation and race behavior are exercised in the bridge tests.
