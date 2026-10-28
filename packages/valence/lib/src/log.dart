import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Where the runtime's lines go. Every stop in the update algorithm is logged through this (§2.3).
typedef ValenceLogger = void Function(String message);

/// The default logger: `debugPrint` with a `[valence]` prefix, so the lines are greppable in `adb logcat`.
///
/// An update that declines to apply looks exactly like one that failed, so these lines are the only way
/// to tell them apart on a device. Replace it to route them into your own crash reporter.
void defaultValenceLogger(String message) => debugPrint('[valence] $message');

int _nextWaitId = 0;

/// New observational diagnostics must not fail work when a custom sink throws.
void diagnosticLog(ValenceLogger log, String message) {
  try {
    log(message);
  } catch (_) {
    // Logging is observational; the original operation owns its result/error.
  }
}

/// Observes a database future without imposing a timeout or changing its result.
/// Labels must be fixed source names, never SQL, arguments or exception text.
Future<T> logDatabaseWait<T>(
    String operation, Future<T> Function() action, ValenceLogger log) async {
  final watch = Stopwatch()..start();
  final id = ++_nextWaitId;
  final isolate = Isolate.current.hashCode;
  var waited = false;
  var completed = false;
  void report(String status) => diagnosticLog(
      log,
      'store: $status operation=$operation '
      'id=$id isolate=$isolate elapsedMs=${watch.elapsedMilliseconds}');
  final timer = Timer.periodic(const Duration(seconds: 10), (_) {
    waited = true;
    report('waiting');
  });
  try {
    final result = await action();
    completed = true;
    return result;
  } finally {
    timer.cancel();
    if (waited) report(completed ? 'completed' : 'failed');
  }
}

/// Phase trace for one open call; never logs native errors or app data.
final class StartupTrace {
  /// Starts the elapsed clock before binding initialization.
  StartupTrace(this.log);

  /// The same destination as the caller's runtime diagnostics.
  final ValenceLogger log;
  final Stopwatch _watch = Stopwatch()..start();
  String? _phase;
  int _started = 0;

  /// Completes the preceding phase, then reports entry before starting work.
  void start(String phase) {
    if (_phase != null) _report('complete');
    _phase = phase;
    _started = _watch.elapsedMilliseconds;
    _report('begin');
  }

  /// Reports that open has returned; this is not WebView or ready evidence.
  void complete() {
    _report('complete');
    diagnosticLog(
        log, 'startup: complete elapsedMs=${_watch.elapsedMilliseconds}');
  }

  /// Reports only the active phase, leaving the caller to rethrow unchanged.
  void fail() => _report('failed');

  void _report(String status) {
    final elapsed = _watch.elapsedMilliseconds;
    diagnosticLog(
        log,
        'startup: phase=$_phase status=$status elapsedMs=$elapsed '
        'phaseMs=${elapsed - _started}');
  }
}
