import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:valence/src/image_share.dart';
import 'package:valence/valence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
  late Directory cas;
  late ValenceImageShare service;
  late List<ShareParams> presented;
  ValenceManifest? active;

  Matcher error(String code) =>
      throwsA(isA<BridgeError>().having((e) => e.code, 'code', code));

  ValenceManifest withFile(String path, List<int> bytes, {int? declaredSize}) =>
      ValenceManifest.decode(
        Uint8List.fromList(utf8.encode(jsonEncode({
          'format': 1,
          'appId': 'com.test.app',
          'seq': 1,
          'version': 'test',
          'floor': 0,
          'requires': {'bridge': 14},
          'entry': path,
          'csp': "default-src 'self'",
          'keyId': 'k1',
          'files': {
            path: {
              'h': sha256.convert(bytes).toString(),
              'n': declaredSize ?? bytes.length
            }
          },
        }))),
      );

  setUp(() async {
    cas = await Directory.systemTemp.createTemp('valence-share-test');
    active = null;
    presented = [];
    service = ValenceImageShare(
        manifest: () => active,
        casDir: cas,
        temporaryDirectory: () async => cas,
        present: (params) async {
          presented.add(params);
          return const ShareResult('target', ShareResultStatus.success);
        });
  });
  tearDown(() async => cas.delete(recursive: true));

  test(
      'inline PNG copies bytes, sets MIME/name/caption and reports target selection',
      () async {
    expect(
        await service.share(
            bytes: base64Encode(png),
            fileName: 'chart.png',
            caption: 'My chart'),
        'selected');
    final p = presented.single;
    expect(await p.files!.single.readAsBytes(), png);
    expect(p.files!.single.mimeType, 'image/png');
    expect(p.files!.single.name, 'chart.png');
    expect(p.text, 'My chart');
    expect(p.sharePositionOrigin!.width, greaterThan(0));
  });

  test('JPEG detection supplies a matching default and omits empty caption',
      () async {
    await service.share(bytes: base64Encode([255, 216, 255, 224]), caption: '');
    expect(presented.single.files!.single.mimeType, 'image/jpeg');
    expect(presented.single.files!.single.name, 'image.jpg');
    expect(presented.single.text, isNull);
  });

  test('requires exactly one source', () async {
    await expectLater(service.share(), error(BridgeErrorCode.params));
    await expectLater(service.share(bytes: base64Encode(png), path: 'x.png'),
        error(BridgeErrorCode.params));
    expect(presented, isEmpty);
  });

  test('rejects noncanonical base64, data URLs and unsupported magic before UI',
      () async {
    for (final value in [
      '',
      '<svg/>',
      'data:image/png;base64,AA==',
      'AQ',
      'AB==',
      '____',
      '%2FAA==',
      ' AA==',
      'SGVsbG8='
    ]) {
      await expectLater(
          service.share(bytes: value), error(BridgeErrorCode.params));
    }
    expect(presented, isEmpty);
  });

  test('encoded cap precedes decoding and decoded cap catches padding boundary',
      () async {
    await expectLater(
        service.share(bytes: '!' * 174765), error(BridgeErrorCode.tooLarge));
    await expectLater(
        service.share(bytes: base64Encode(Uint8List(maxInlineShareBytes + 1))),
        error(BridgeErrorCode.tooLarge));
    final exact = Uint8List(maxInlineShareBytes)..setRange(0, png.length, png);
    expect(await service.share(bytes: base64Encode(exact)), 'selected');
    expect(presented, hasLength(1));
  });

  test('rejects names, wrong extensions and UTF-8 caption overflow', () async {
    for (final name in [
      '../x.png',
      '/x.png',
      'x\\y.png',
      '.png',
      'x.svg',
      'x.jpg',
      'x.PNG',
      '${'x' * 81}.png',
      'x.png\n'
    ]) {
      await expectLater(service.share(bytes: base64Encode(png), fileName: name),
          error(BridgeErrorCode.params));
    }
    await expectLater(
        service.share(bytes: base64Encode(png), caption: '界' * 1366),
        error(BridgeErrorCode.tooLarge));
    await service.share(bytes: base64Encode(png), caption: 'a' * 4096);
    expect(presented, hasLength(1));
  });

  test(
      'only the active manifest key selects a CAS hash and is rechecked each share',
      () async {
    active = withFile('assets/chart.png', png);
    final file = File('${cas.path}/${sha256.convert(png)}')
      ..writeAsBytesSync(png);
    expect(await service.share(path: 'assets/chart.png'), 'selected');
    expect(await presented.single.files!.single.readAsBytes(), png);
    expect(presented.single.files!.single.path,
        isNot(contains(sha256.convert(png).toString())),
        reason: 'never shares the CAS path');
    final rotten = Uint8List.fromList(png)..[20] ^= 1;
    await file.writeAsBytes(rotten);
    await expectLater(service.share(path: 'assets/chart.png'),
        error(BridgeErrorCode.internal));
    active = null;
    await expectLater(
        service.share(path: 'assets/chart.png'), error(BridgeErrorCode.denied));
    expect(presented, hasLength(1));
  });

  test('rejects path traversal, native paths, URLs, reserved and absent files',
      () async {
    active = withFile('assets/chart.png', png);
    for (final path in [
      '../chart.png',
      '/assets/chart.png',
      'assets/../chart.png',
      'assets\\chart.png',
      'file:///secret.png',
      'https://host/x.png',
      '_host/media/a',
      'assets/%2e%2e/x.png',
      'unknown.png'
    ]) {
      await expectLater(
          service.share(path: path), error(BridgeErrorCode.denied));
    }
    expect(presented, isEmpty);
  });

  test('missing files and wrong signed size fail without native UI', () async {
    active = withFile('chart.png', png);
    await expectLater(
        service.share(path: 'chart.png'), error(BridgeErrorCode.internal));
    File('${cas.path}/${sha256.convert(png)}').writeAsBytesSync(png);
    active = withFile('chart.png', png, declaredSize: png.length + 1);
    await expectLater(
        service.share(path: 'chart.png'), error(BridgeErrorCode.internal));
    expect(presented, isEmpty);
  });

  test(
      'signed and actual bundle size caps are independent, including exact boundary',
      () async {
    active = withFile('chart.png', png, declaredSize: maxBundleShareBytes + 1);
    await expectLater(
        service.share(path: 'chart.png'), error(BridgeErrorCode.tooLarge));
    active = withFile('chart.png', png);
    File('${cas.path}/${sha256.convert(png)}')
        .writeAsBytesSync(Uint8List(maxBundleShareBytes + 100));
    await expectLater(
        service.share(path: 'chart.png'), error(BridgeErrorCode.tooLarge));
    final exact = Uint8List(maxBundleShareBytes)..setRange(0, png.length, png);
    active = withFile('chart.png', exact);
    File('${cas.path}/${sha256.convert(exact)}').writeAsBytesSync(exact);
    expect(await service.share(path: 'chart.png'), 'selected');
  });

  test(
      'concurrent calls are refused and native failures release the guard without leaking paths',
      () async {
    final pending = Completer<ShareResult>();
    final entered = Completer<void>();
    service = ValenceImageShare(
        manifest: () => active,
        casDir: cas,
        temporaryDirectory: () async => cas,
        present: (_) {
          entered.complete();
          return pending.future;
        });
    final first = service.share(bytes: base64Encode(png));
    await expectLater(
        service.share(bytes: base64Encode(png)), error(BridgeErrorCode.denied));
    await entered.future;
    pending
        .completeError(FileSystemException('private payload', '/secret/path'));
    await expectLater(
        first,
        throwsA(isA<BridgeError>().having(
            (e) => e.message, 'message', 'native image sharing failed')));
    await expectLater(
        service.share(bytes: 'bad'), error(BridgeErrorCode.params));
  });

  test(
      'scratch is wiped before reuse, outside files and denied calls remain untouched',
      () async {
    final outside = File('${cas.path}/unrelated')..writeAsStringSync('keep');
    await service.share(bytes: base64Encode(png), fileName: 'first.png');
    final first = File(presented.single.files!.single.path);
    final stale = Directory('${first.parent.path}/stale')..createSync();
    File('${stale.path}/old.png').writeAsBytesSync(png);
    await expectLater(
        service.share(path: '../secret'), error(BridgeErrorCode.denied));
    expect(first.existsSync(), isTrue,
        reason: 'denied input never erases cache');
    await service.share(bytes: base64Encode(png), fileName: 'second.png');
    expect(first.existsSync(), isFalse);
    expect(stale.existsSync(), isFalse);
    expect(File(presented.last.files!.single.path).existsSync(), isTrue);
    expect(outside.readAsStringSync(), 'keep');
  });

  test('dismissed and unavailable stay distinct from selection', () async {
    for (final status in [
      ShareResultStatus.dismissed,
      ShareResultStatus.unavailable
    ]) {
      service = ValenceImageShare(
          manifest: () => active,
          casDir: cas,
          temporaryDirectory: () async => cas,
          present: (_) async => ShareResult('', status));
      expect(await service.share(bytes: base64Encode(png)), status.name);
    }
  });
}
