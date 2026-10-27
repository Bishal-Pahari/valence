import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

void main() {
  testWidgets('owning view insets use logical pixels and exclude the keyboard',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.viewPadding =
        const FakeViewPadding(top: 48, right: 12, bottom: 24, left: 8);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.reset);
    final portrait =
        ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(tester.view));
    expect(portrait.insets, const EdgeInsets.fromLTRB(4, 24, 6, 12));
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.viewPadding = const FakeViewPadding(left: 48, right: 24);
    final landscape =
        ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(tester.view));
    expect(landscape.insets, const EdgeInsets.fromLTRB(24, 0, 12, 0));
  });

  testWidgets(
      'system appearance and font scale ignore app theme and update live',
      (tester) async {
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearAllTestValues);
    final initial =
        ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(tester.view));
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    dispatcher.textScaleFactorTestValue = 1.75;
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      highContrast: true,
      disableAnimations: true,
    );
    final changed =
        ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(tester.view));
    expect(changed.payload,
        {'darkMode': true, 'highContrast': true, 'reducedMotion': true});
    expect(changed.textZoom, 175);
    expect(changed.fontScale, 1.75);
    expect(changed.samePreferences(initial), isFalse);
    final same =
        ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(tester.view));
    expect(changed.samePreferences(same), isTrue);
    dispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    expect(
        ValenceAppearance.fromMediaQuery(MediaQueryData.fromView(tester.view))
            .reducedMotion,
        isTrue);
  });

  test(
      'publication executes without compounding iOS scale or touching navigation/nonce',
      () async {
    final appearance = ValenceAppearance.fromMediaQuery(const MediaQueryData(
      viewPadding: EdgeInsets.fromLTRB(4, 24, 6, 12),
      textScaler: TextScaler.linear(1.5),
      platformBrightness: Brightness.dark,
    ));
    // Exercise the actual emitted JS. Node is also required for this repo's CLI gates.
    final result = await Process.run('node', [
      '-e',
      '''
const assert = require('node:assert/strict');
const values = {}, attributes = {}, events = [];
const root = {
  style: {setProperty: (key, value) => { values[key] = value; }}, dataset: {},
  hasAttribute: key => Object.hasOwn(attributes, key),
  setAttribute: (key, value) => { attributes[key] = value; },
  getAttribute: key => attributes[key]
};
global.document = {documentElement: root};
global.window = {__valence: {e: (name, payload) => events.push([name, payload])}};
global.getComputedStyle = () => ({fontSize: root.style.fontSize || '16px'});
${appearance.script(scaleRootFont: true, emitEvent: true)}
${appearance.script(scaleRootFont: true, emitEvent: false)}
assert.equal(root.style.fontSize, '24px');
assert.equal(values['--valence-inset-top'], '24px');
assert.equal(values['--valence-inset-right'], '6px');
assert.equal(values['--valence-inset-bottom'], '12px');
assert.equal(values['--valence-inset-left'], '4px');
assert.equal(root.dataset.valenceDarkMode, 'true');
assert.deepEqual(events, [['app.appearance', {darkMode:true, highContrast:false, reducedMotion:false}]]);
root.style.fontSize = '16px';
${appearance.script(scaleRootFont: false, emitEvent: false)}
assert.equal(root.style.fontSize, '16px'); // Android uses native zoom only.
console.log(JSON.stringify(values));
'''
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
        jsonDecode(result.stdout as String), contains('--valence-font-scale'));
  });
}
