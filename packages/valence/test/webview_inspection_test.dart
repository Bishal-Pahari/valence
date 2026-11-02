import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// §3.1: a release build must never be inspectable. The branch is compiled out, which no widget test can see,
// so hold the guard itself in place, across the whole package.
void main() {
  test('WebView inspection is enabled only behind kDebugMode', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(RegExp(r'enableDebugging\(').allMatches(sources), hasLength(1));
    expect(
      RegExp(r'if \(kDebugMode && controller\.platform is AndroidWebViewController\) \{\s*'
              r'await AndroidWebViewController\.enableDebugging\(true\);')
          .hasMatch(sources),
      isTrue,
    );
  });
}
