import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

import '../tool/host_file_probe.dart';

void main() {
  test('failed initial inventory never authorizes deletion', () async {
    final root = await Directory.systemTemp.createTemp(
      'valence-probe-inventory',
    );
    final host = Directory('${root.path}/host');
    final server = await ValenceServer.bind(
      config: const ValenceConfig(
        appId: 'test.probe',
        keyring: {},
        bridgeVersion: 1,
      ),
      state: ValenceState(installId: 'probe-test'),
      casDir: Directory('${root.path}/cas'),
      hostDir: _FailFirstList(host),
    );
    try {
      final original = await server.publishHostFile([
        7,
        8,
        9,
      ], contentType: 'image/png');
      final lines = <String>[];
      await checkHostFiles(server, lines);
      expect(lines.any((line) => line.startsWith('FAIL ')), isTrue);
      expect((await server.listHostFiles()).map((f) => f.url), [original]);
      expect(
        File('${host.path}/${original.split('/').last}').readAsBytesSync(),
        [7, 8, 9],
      );
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });

  for (final failRequest in [false, true]) {
    test(
      'probe preserves other publications when request fails=$failRequest',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'valence-probe-test',
        );
        final host = Directory('${root.path}/host');
        final server = await ValenceServer.bind(
          config: const ValenceConfig(
            appId: 'test.probe',
            keyring: {},
            bridgeVersion: 1,
          ),
          state: ValenceState(installId: 'probe-test'),
          casDir: Directory('${root.path}/cas'),
          hostDir: host,
        );
        try {
          final original = await server.publishHostFile([
            1,
            2,
            3,
          ], contentType: 'image/png');
          const concurrentId = '0123456789abcdef01234567';
          var inserted = false;
          final lines = <String>[];
          await HttpOverrides.runZoned(
            () => checkHostFiles(server, lines),
            createHttpClient: (context) {
              if (!inserted) {
                // Another host operation publishes after the initial inventory.
                File('${host.path}/$concurrentId').writeAsBytesSync([4, 5, 6]);
                File(
                  '${host.path}/$concurrentId.t',
                ).writeAsStringSync('image/png');
                inserted = true;
              }
              if (failRequest) throw StateError('injected request failure');
              return _RealHttp().createHttpClient(context);
            },
          );
          expect(inserted, isTrue);
          expect((await server.listHostFiles()).map((f) => f.url).toSet(), {
            original,
            '/_host/f/$concurrentId',
          });
          expect(
            File('${host.path}/${original.split('/').last}').readAsBytesSync(),
            [1, 2, 3],
          );
          expect(File('${host.path}/$concurrentId').readAsBytesSync(), [
            4,
            5,
            6,
          ]);
          if (failRequest) {
            expect(lines, contains('FAIL Bad state: injected request failure'));
          } else {
            expect(lines.where((line) => line.startsWith('FAIL')), isEmpty);
            expect(
              lines,
              contains('PASS reconcile revoked=1 orphan=404 kept=200'),
            );
          }
        } finally {
          await server.close();
          await root.delete(recursive: true);
        }
      },
    );
  }
}

class _RealHttp extends HttpOverrides {}

// Fail one inventory while keeping actual publication I/O and later listings real.
class _FailFirstList implements Directory {
  _FailFirstList(this.inner);
  final Directory inner;
  bool failed = false;

  @override
  String get path => inner.path;

  @override
  bool existsSync() => inner.existsSync();

  @override
  Future<Directory> create({bool recursive = false}) =>
      inner.create(recursive: recursive);

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (!failed) {
      failed = true;
      throw const FileSystemException('injected inventory failure');
    }
    return inner.list(recursive: recursive, followLinks: followLinks);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
