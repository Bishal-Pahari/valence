// Run explicitly with -t tool/http_response_probe.dart, never the example entry point.
// Synthetic local API only; opens no user database or credential store.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:valence/src/wire.dart' show replyOk;
import 'package:valence/valence.dart';

import 'package:valence_example/valence/config.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lines = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final origin = 'http://127.0.0.1:${server.port}';
  final payload = 'a' * 133712;
  server.listen((request) async {
    final body = request.uri.path == '/escaped' ? '\u0000' * 65536 : payload;
    final bytes = gzip.encode(utf8.encode(body));
    request.response.headers.set('content-encoding', 'gzip');
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  });
  ValenceHttp api(int cap) => ValenceHttp(
    origins: {origin},
    maxBodyBytes: cap,
    token: () async => null,
    onUnauthorized: () {},
  );
  try {
    try {
      await api(65536).request(url: origin);
      throw StateError('default grant accepted oversized gzip');
    } on BridgeError catch (e) {
      if (e.code != BridgeErrorCode.tooLarge) rethrow;
      lines.add('PASS default refuses decompressed 133712 bytes');
    }
    final response = await api(
      valenceConfig.httpMaxBodyBytes,
    ).request(url: origin);
    if (response.body != payload) throw StateError('response mismatch');
    final reply = replyOk(1, {
      'status': response.status,
      'headers': response.headers,
      'body': response.body,
    });
    if (jsonDecode(reply)['ok'] != true) throw StateError('reply refused');
    lines.add(
      'PASS compiled ${valenceConfig.httpMaxBodyBytes} grant returns 133712 bytes',
    );
    final escaped = await api(
      valenceConfig.httpMaxBodyBytes,
    ).request(url: '$origin/escaped');
    final refused = replyOk(2, {
      'status': escaped.status,
      'headers': escaped.headers,
      'body': escaped.body,
    });
    if (jsonDecode(refused)['e']['code'] != BridgeErrorCode.tooLarge ||
        utf8.encode(refused).length > maxMessageBytes) {
      throw StateError('escaped envelope exceeded cap');
    }
    lines.add('PASS escaped reply returns bounded E_TOO_LARGE');
    try {
      await api(
        valenceConfig.httpMaxBodyBytes,
      ).request(url: origin, method: 'POST', body: payload);
      throw StateError('request cap raised');
    } on BridgeError catch (e) {
      if (e.code != BridgeErrorCode.tooLarge) rethrow;
      lines.add('PASS request cap remains 65536 bytes');
    }
  } on Object catch (e) {
    lines.add('FAIL $e');
  } finally {
    await server.close(force: true);
  }
  for (final line in lines) {
    debugPrint('r32: $line');
  }
  runApp(
    MaterialApp(
      home: Scaffold(body: SafeArea(child: Text(lines.join('\n')))),
    ),
  );
}
