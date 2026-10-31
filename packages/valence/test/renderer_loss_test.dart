// A tripwire, not a feature test (contracts §3, "Renderer loss", and §8).
//
// Android's `WebViewClient.onRenderProcessGone` is the one callback that would let the host survive a
// renderer eviction instead of being killed with it, and `webview_flutter_android` exposes nothing of
// the kind. This fails the day it does, so the handler gets written rather than the limitation quietly
// outliving the release notes that promised to revisit it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('webview_flutter_android still exposes no renderer-gone callback', () {
    final config = File('.dart_tool/package_config.json');
    expect(config.existsSync(), isTrue,
        reason: 'run `flutter pub get` before the suite');
    final packages = (jsonDecode(config.readAsStringSync())
        as Map<String, Object?>)['packages'] as List<Object?>;
    final entry = packages
        .cast<Map<String, Object?>>()
        .firstWhere((p) => p['name'] == 'webview_flutter_android');
    final root = Uri.parse(entry['rootUri']! as String);
    final dir = Directory.fromUri(config.parent.uri.resolveUri(root));
    final hits = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('RenderProcessGone'))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty,
        reason: 'webview_flutter_android now reports renderer loss: implement '
            'the Android half of ValenceApp._onRendererLoss and replace the §3 '
            'limitation with the behaviour');
  });
}
