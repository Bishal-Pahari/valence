# Renderer and external-activity diagnostics - 2026-11-01

## In plain terms

App-c F-38 was a documentation defect: the website named `trial` as the marker
cleared at the renderer recovery cap. Contracts section 3 and `ValenceApp` clear
`serving`, retaining `trial` and its failure count for retry on the next launch.
The guide now says that and distinguishes reloads from the error view at the cap.
No runtime, bridge, generator, template, package or schema version changes.

Read both apps' findings and latest reports: Kundalini iteration 17 and app-c
iteration 37. Kundalini has not accepted S7 and its cookie-paired CSRF limitation
remains open; this change does not address either. All must-have items are done
or ready, and the existing integration includes their tips. S1 remains parked,
S2 requires a Play account, and the other builder explicitly names S6 next.

## Evidence and decision

- `packages/valence/lib/src/app.dart`, `_onRendererLoss`, stops the ready timer,
  clears/saves `serving` at the cap and drops the controller. It does not clear
  `trial`. Existing `app_widget_test.dart` coverage rereads persisted state and
  asserts retained trial, unchanged strikes and null serving.
- App-c iteration 37's `settings-before-pid.txt` and `settings-return-pid.txt`
  both contain 4829. This successful observation does not close F-35 or F-36.
- `camera-retry-lastanr.txt` names an input-dispatch ANR in
  `com.android.camera2/com.android.camera.CaptureActivity` at 18:45:58. The saved
  `photos-settled.json` separately reports three images with positive decoded
  dimensions. Failed capture and successful retry remain separate results.
- Earlier app-c logs include both direct host low-memory kills and Chromium
  termination following renderer eviction. Exit-info alone is insufficient to
  distinguish them. The spec and both diagnostic guides now require full logs
  correlated by PID/time and avoid claiming that app memory use is ruled out.

Decision: correct the documented state transition and improve evidence
interpretation, preserving security and users' data. Do not change rollback
strikes, navigation locks, lease handling or credential storage on these
observations. Document external-camera capture/retry without promising automatic
media recovery. No emulator run or test-app write is part of this change. iOS
remains experimental and untested on hardware.

Integration gate results are recorded in `docs/integration.md` after merging this
branch with the existing feature branches. Prior app-runner tests are not counted
as package gates.
