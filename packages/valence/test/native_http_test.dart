import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valence/valence.dart';

void main() {
  Matcher error(String code) =>
      throwsA(isA<BridgeError>().having((e) => e.code, 'code', code));
  ValenceHttp api(
          {Set<String> origins = const {'https://api.test'},
          Future<String?> Function()? token,
          void Function()? expired,
          http.Client Function()? factory}) =>
      ValenceHttp(
        origins: origins,
        token: token ?? () async => 'secret',
        onUnauthorized: expired ?? () {},
        clientFactory:
            factory ?? () => MockClient((_) async => http.Response('ok', 200)),
      );

  test(
      'deny every unlisted scheme, host and port before token lookup or transport',
      () async {
    final a = api(token: () async => fail('must not read credentials'));
    for (final url in [
      'https://evil.test',
      'https://api.test.evil.test',
      'https://api.test:444',
      'http://api.test'
    ]) {
      await expectLater(a.request(url: url), error(BridgeErrorCode.denied));
    }
    for (final url in [
      'file:///etc/passwd',
      '/items',
      'https://secret@api.test',
      'https://api.test/#x'
    ]) {
      await expectLater(a.request(url: url), error(BridgeErrorCode.params));
    }
    await expectLater(api(origins: {}).request(url: 'https://api.test'),
        error(BridgeErrorCode.denied));
    await expectLater(
        api(origins: {'https://api.test/path'})
            .request(url: 'https://api.test'),
        error(BridgeErrorCode.denied));
  });

  test(
      'exact origin includes normalized default port and case; token read each time',
      () async {
    var calls = 0;
    final a = api(
        token: () async => 'secret-${++calls}',
        factory: () => MockClient((r) async {
              expect(r.headers['authorization'], 'Bearer secret-$calls');
              expect(r.headers['origin'], isNull);
              expect(r.followRedirects, isFalse);
              return http.Response('ok', 200);
            }));
    await a.request(url: 'https://API.TEST:443/items?q=x');
    await a.request(url: 'https://api.test');
    expect(calls, 2);
  });

  test(
      'text JSON and custom headers round trip; no cookie setting headers returned',
      () async {
    final a = api(
        factory: () => MockClient((r) async {
              expect(r.method, 'POST');
              expect(r.body, '{"name":"नेपाली"}');
              expect(r.headers['x-app'], 'v1');
              return http.Response.bytes(utf8.encode('नेपाली'), 422,
                  headers: {'set-cookie': 'session=secret', 'x-api': 'v2'});
            }));
    final r = await a.request(
        url: 'https://api.test/items',
        method: 'POST',
        headers: {'content-type': 'application/json', 'x-app': 'v1'},
        body: '{"name":"नेपाली"}');
    expect(r.status, 422);
    expect(r.body, 'नेपाली');
    expect(r.headers, {'x-api': 'v2'});
  });

  test('page cannot inject credentials, transport headers or CRLF', () async {
    final a = api(token: () async => fail('must validate first'));
    for (final name in [
      'Authorization',
      'Cookie',
      'Host',
      'Origin',
      'Referer',
      'Content-Length',
      'Transfer-Encoding',
      'Connection',
      'Proxy-Authorization',
      'Sec-Fetch-Site',
      'TE',
      'Expect',
      'Accept-Encoding'
    ]) {
      await expectLater(
          a.request(url: 'https://api.test', headers: {name: 'x'}),
          error(BridgeErrorCode.denied));
    }
    for (final headers in [
      [],
      {'x': 1},
      {'bad\n': 'x'},
      {'x': 'a\r\nb'},
      {'x': 'a\n'},
      {'X': 'a', 'x': 'b'}
    ]) {
      await expectLater(a.request(url: 'https://api.test', headers: headers),
          error(BridgeErrorCode.params));
    }
  });

  test('only the documented methods and body shapes are allowed', () async {
    for (final method in ['CONNECT', 'TRACE', 'get', 'POST\r\nX: y']) {
      await expectLater(api().request(url: 'https://api.test', method: method),
          error(BridgeErrorCode.params));
    }
    for (final method in ['GET', 'HEAD']) {
      await expectLater(
          api().request(url: 'https://api.test', method: method, body: 'x'),
          error(BridgeErrorCode.params));
    }
  });

  test('401 emits once only when a bearer was sent; response remains available',
      () async {
    var events = 0;
    for (final token in ['secret', null, '']) {
      final r = await api(
              token: () async => token,
              expired: () => events++,
              factory: () =>
                  MockClient((_) async => http.Response('login', 401)))
          .request(url: 'https://api.test');
      expect(r.status, 401);
    }
    expect(events, 1);
  });

  test(
      'input and response limits count UTF-8 bytes and bounded streamed chunks',
      () async {
    await expectLater(
        api().request(
            url: 'https://api.test', method: 'POST', body: 'é' * 32769),
        error(BridgeErrorCode.tooLarge));
    await expectLater(
        api().request(url: 'https://api.test', headers: {'x': 'a' * 16384}),
        error(BridgeErrorCode.tooLarge));
    final a = api(
        factory: () => MockClient.streaming((_, __) async =>
            http.StreamedResponse(
                Stream.fromIterable(
                    [List.filled(32768, 65), List.filled(32769, 65)]),
                200)));
    await expectLater(
        a.request(url: 'https://api.test'), error(BridgeErrorCode.tooLarge));
    await expectLater(
        api(
                factory: () => MockClient((_) async =>
                    http.Response('x', 200, headers: {'x': 'a' * 16384})))
            .request(url: 'https://api.test'),
        error(BridgeErrorCode.tooLarge));
  });

  test('binary and transport failures disclose no remote exception text',
      () async {
    for (final client in [
      MockClient((_) async => http.Response.bytes([255], 200)),
      MockClient(
          (_) async => throw const FormatException('secret token and URL'))
    ]) {
      try {
        await api(factory: () => client).request(url: 'https://api.test');
        fail('expected error');
      } on BridgeError catch (e) {
        expect(e.code, BridgeErrorCode.internal);
        expect(e.message, isNot(contains('secret')));
      }
    }
  });

  test(
      'real HTTP redirects are returned without contacting their target or sending credentials',
      () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await source.close(force: true);
      await target.close(force: true);
    });
    var leaks = 0;
    target.listen((r) {
      leaks++;
      r.response.close();
    });
    source.listen((r) {
      r.response.statusCode = 307;
      r.response.headers
          .set('location', 'http://127.0.0.1:${target.port}/private');
      r.response.close();
    });
    final url = 'http://127.0.0.1:${source.port}';
    final r = await api(origins: {url}, factory: http.Client.new)
        .request(url: '$url/redirect');
    expect(r.status, 307);
    expect(leaks, 0);
  });

  test('deadline includes token lookup and never starts a late request',
      () async {
    final token = Completer<String?>();
    final a = api(
        token: () => token.future,
        factory: () => throw StateError('late request started'));
    await expectLater(
        a.request(url: 'https://api.test'), error(BridgeErrorCode.internal));
    token.complete('secret');
    await Future<void>.delayed(Duration.zero);
  }, timeout: const Timeout(Duration(seconds: 30)));
  test('bodyless responses do not use representation Content-Length as body size', () async {
    for (final item in [('HEAD', 200), ('GET', 204), ('GET', 304)]) {
      final response = await api(factory: () => MockClient.streaming((_, __) async =>
        http.StreamedResponse(const Stream.empty(), item.$2,
          contentLength: ValenceHttp.bodyLimit + 1)))
        .request(url: 'https://api.test/large', method: item.$1);
      expect(response.status, item.$2);
      expect(response.body, isEmpty);
    }
  });

  test('ambiguous and unrelated authorities cannot read the token', () async {
    for (final url in [
      'https://%61pi.test/',
      r'https://api.test\@evil.test/',
      r'https://evil.test\@api.test/',
      'https://api.test@evil.test/',
      'https://api.test./',
      'https://[::1]/',
      'https://b\u00fccher.test/',
      'https://xn--bcher-kva.test/',
    ]) {
      await expectLater(api(token: () async => fail('credential read for $url'))
        .request(url: url), throwsA(isA<BridgeError>()));
    }
  });

  test('explicit IPv6 and punycode origins match only themselves', () async {
    for (final origin in ['https://[::1]:444', 'https://xn--bcher-kva.test']) {
      final r = await api(origins: {origin}).request(url: '$origin/path');
      expect(r.status, 200);
    }
  });

}
