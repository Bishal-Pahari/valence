// Run explicitly with -t tool/host_file_probe.dart, never the example entry point.
// The §3 publication lifecycle on a real device: publish, serve, list, revoke, 404 — and the reconcile
// path for a copy whose owning row was never written. It publishes only its own synthetic bytes, and
// revokes every one of them before it finishes, so the probe leaves the host directory as it found it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:valence/valence.dart';

import 'package:valence_example/valence/config.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lines = <String>['release=$kReleaseMode debug=$kDebugMode'];
  final valence = await Valence.open(valenceConfig, hostBuild: 1);
  // `Valence.open` deliberately does not bind the loopback server — `ValenceApp` does, at `bound()`,
  // and the runtime's three `/_host/` methods are a null check in front of the server's own. So the
  // probe binds its own server and calls it directly, which exercises every byte of the §3 lifecycle
  // without `activateForUiStart` counting a trial strike against whatever this device is serving.
  final server = await ValenceServer.bind(
    config: valence.config,
    state: valence.state,
    casDir: Directory('${valence.dir.path}${Platform.pathSeparator}cas'),
    hostDir: Directory('${valence.dir.path}${Platform.pathSeparator}host'),
  );
  final before = (await server.listHostFiles()).map((f) => f.url).toSet();
  try {
    final kept = await server.publishHostFile(utf8.encode('KEPT'),
        contentType: 'image/png');
    final orphan = await server.publishHostFile(utf8.encode('ORPHANED'),
        contentType: 'image/png');
    final origin = server.origin;

    Future<int> status(String url) async {
      final client = HttpClient();
      try {
        final res = await (await client.getUrl(Uri.parse('$origin$url'))).close();
        await res.drain<void>();
        return res.statusCode;
      } finally {
        client.close(force: true);
      }
    }

    lines.add('published served=${await status(kept)}');

    // What the list is for: the app's rows know about `kept` and nothing knows about `orphan`, which no
    // delete path can reach.
    final listed = await server.listHostFiles();
    final mine = listed.where((f) => !before.contains(f.url)).toList();
    lines.add('listed=${mine.length} bytes=${mine.map((f) => f.sizeBytes).join(',')}');
    final rows = {kept};
    var revoked = 0;
    for (final f in mine) {
      if (!rows.contains(f.url) && await server.revokeHostFile(f.url)) revoked++;
    }

    final orphanStatus = await status(orphan);
    final keptStatus = await status(kept);
    lines.add(orphanStatus == 404 && keptStatus == 200 && revoked == 1
        ? 'PASS reconcile revoked=$revoked orphan=404 kept=200'
        : 'FAIL revoked=$revoked orphan=$orphanStatus kept=$keptStatus');

    // Revoking twice is a false rather than an error, which is what lets a delete path be re-run.
    lines.add(await server.revokeHostFile(orphan) == false
        ? 'PASS second revoke is a miss'
        : 'FAIL second revoke claimed a deletion');
    try {
      await server.revokeHostFile('/_host/f/../../../databases/valence.db');
      lines.add('FAIL a path outside a publication was accepted');
    } on ArgumentError {
      lines.add('PASS a non-publication URL is refused');
    }

    lines.add(await server.revokeHostFile(kept) && await status(kept) == 404
        ? 'PASS cleanup revoked the probe\'s own copy'
        : 'FAIL cleanup left bytes behind');
  } finally {
    // Leave nothing behind even if an expectation above threw.
    for (final f in await server.listHostFiles()) {
      if (!before.contains(f.url)) await server.revokeHostFile(f.url);
    }
    lines.add('left=${(await server.listHostFiles()).length} started=${before.length}');
    await server.close();
  }
  for (final line in lines) {
    debugPrint('r35: $line');
  }
  runApp(
    MaterialApp(
      home: Scaffold(body: SafeArea(child: Text(lines.join('\n')))),
    ),
  );
}
