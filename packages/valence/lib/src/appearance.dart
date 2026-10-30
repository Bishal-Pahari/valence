import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'wire.dart';

/// System layout/preferences for one owning Flutter view (contracts §4.7).
///
/// Custom hosts may publish [script] after load and on metrics/settings changes.
/// This reads system values, independently of a Material theme or a SafeArea.
final class ValenceAppearance {
  /// Takes a snapshot from the owning view, in logical pixels.
  ValenceAppearance.fromMediaQuery(MediaQueryData data)
      : insets = data.viewPadding,
        fontScale = data.textScaler.scale(16) / 16,
        darkMode = data.platformBrightness == Brightness.dark,
        highContrast = data.highContrast,
        reducedMotion = data.disableAnimations || data.accessibleNavigation;

  /// System bars and cutouts, excluding the software keyboard.
  final EdgeInsets insets;

  /// System text scaling evaluated at 16 logical pixels.
  final double fontScale;

  /// System dark-mode preference.
  final bool darkMode;

  /// System high-contrast preference, where the OS reports it.
  final bool highContrast;

  /// The OS requests disabled animations or accessible navigation.
  final bool reducedMotion;

  /// Android WebView's single integer text-zoom percentage.
  int get textZoom => (fontScale * 100).round();

  /// The schema-7 `app.appearance` event payload.
  Map<String, Object> get payload => {
        'darkMode': darkMode,
        'highContrast': highContrast,
        'reducedMotion': reducedMotion,
      };

  /// Whether an appearance event (rather than just layout publication) is needed.
  bool samePreferences(ValenceAppearance other) =>
      darkMode == other.darkMode &&
      highContrast == other.highContrast &&
      reducedMotion == other.reducedMotion;

  /// Publishes only host-owned values; no page text is interpolated into JS.
  ///
  /// Android text zoom is applied natively. The experimental iOS fallback scales
  /// rem/em text once against the document's original computed root font size.
  String script({required bool scaleRootFont, required bool emitEvent}) {
    final values = jsonEncode({
      'top': insets.top,
      'right': insets.right,
      'bottom': insets.bottom,
      'left': insets.left,
      'fontScale': fontScale,
      ...payload,
    });
    return '''(() => {
const v = $values;
const root = document.documentElement;
if (!root) return;
for (const side of ['top', 'right', 'bottom', 'left']) {
  root.style.setProperty('--valence-inset-' + side, v[side] + 'px');
}
root.style.setProperty('--valence-font-scale', String(v.fontScale));
for (const key of ['darkMode', 'highContrast', 'reducedMotion']) {
  root.dataset['valence' + key[0].toUpperCase() + key.slice(1)] = String(v[key]);
}
${scaleRootFont ? '''if (!root.hasAttribute('data-valence-base-font-size')) {
  root.setAttribute('data-valence-base-font-size', String(parseFloat(getComputedStyle(root).fontSize)));
}
root.style.fontSize = (Number(root.getAttribute('data-valence-base-font-size')) * v.fontScale) + 'px';
root.style.webkitTextSizeAdjust = '100%';''' : ''}
${emitEvent ? eventScript('app.appearance', payload) : ''}
})();''';
  }
}
