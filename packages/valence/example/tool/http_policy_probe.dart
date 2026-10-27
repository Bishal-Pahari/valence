// Run explicitly with -t tool/http_policy_probe.dart, never the example entry point.
// Uses only a synthetic credential, without opening Valence or its secure store.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:valence/valence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const port = int.fromEnvironment('PROBE_PORT', defaultValue: 18783);
  final api = ValenceHttp(
    origins: {'http://10.0.2.2:$port', 'http://127.0.0.1:$port'},
    token: () async => 'r23-synthetic-only',
    onUnauthorized: () {},
  );
  final lines = <String>['release=$kReleaseMode debug=$kDebugMode'];
  for (final host in ['10.0.2.2', '127.0.0.1']) {
    final url = 'http://$host:$port/probe';
    try {
      final response = await api.request(url: url);
      lines.add('$url status=${response.status} body=${response.body}');
    } on BridgeError catch (e) {
      lines.add('$url ${e.code}');
    }
  }
  try {
    await api.request(url: 'http://127.0.0.1:${port + 1}/unlisted');
    lines.add('FAIL: unlisted origin accepted');
  } on BridgeError catch (e) {
    lines.add('unlisted=${e.code}');
  }
  for (final line in lines) {
    debugPrint('r23: $line');
  }
  runApp(
    MaterialApp(
      home: Scaffold(body: SafeArea(child: Text(lines.join('\n')))),
    ),
  );
}
