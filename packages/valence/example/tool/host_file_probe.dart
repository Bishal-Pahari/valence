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
  final before = (await valence.listHostFiles()).map((f) => f.url).toSet();
  try {
    final kept = await valence.publishHostFile(utf8.encode('KEPT'),
        contentType: 'image/png');
    final orphan = await valence.publishHostFile(utf8.encode('ORPHANED'),
        contentType: 'image/png');
    final origin = valence.server!.origin;

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
    final listed = await valence.listHostFiles();
    final mine = listed.where((f) => !before.contains(f.url)).toList();
    lines.add('listed=${mine.length} bytes=${mine.map((f) => f.sizeBytes).join(',')}');
    final rows = {kept};
    var revoked = 0;
    for (final f in mine) {
      if (!rows.contains(f.url) && await valence.revokeHostFile(f.url)) revoked++;
    }

    final orphanStatus = await status(orphan);
    final keptStatus = await status(kept);
    lines.add(orphanStatus == 404 && keptStatus == 200 && revoked == 1
        ? 'PASS reconcile revoked=$revoked orphan=404 kept=200'
        : 'FAIL revoked=$revoked orphan=$orphanStatus kept=$keptStatus');

    // Revoking twice is a false rather than an error, which is what lets a delete path be re-run.
    lines.add(await valence.revokeHostFile(orphan) == false
        ? 'PASS second revoke is a miss'
        : 'FAIL second revoke claimed a deletion');
    try {
      await valence.revokeHostFile('/_host/f/../../../databases/valence.db');
      lines.add('FAIL a path outside a publication was accepted');
    } on ArgumentError {
      lines.add('PASS a non-publication URL is refused');
    }

    lines.add(await valence.revokeHostFile(kept) && await status(kept) == 404
        ? 'PASS cleanup revoked the probe\'s own copy'
        : 'FAIL cleanup left bytes behind');
  } finally {
    // Leave nothing behind even if an expectation above threw.
    for (final f in await valence.listHostFiles()) {
      if (!before.contains(f.url)) await valence.revokeHostFile(f.url);
    }
    lines.add('left=${(await valence.listHostFiles()).length} started=${before.length}');
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
