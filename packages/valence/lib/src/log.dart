import 'package:flutter/foundation.dart';

/// Where the runtime's lines go. Every stop in the update algorithm is logged through this (§2.3).
typedef ValenceLogger = void Function(String message);

/// The default logger: `debugPrint` with a `[valence]` prefix, so the lines are greppable in `adb logcat`.
///
/// An update that declines to apply looks exactly like one that failed, so these lines are the only way
/// to tell them apart on a device. Replace it to route them into your own crash reporter.
void defaultValenceLogger(String message) => debugPrint('[valence] $message');
