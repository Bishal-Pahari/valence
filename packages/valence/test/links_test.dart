import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

void main() {
  late ValenceLinks links;
  late List<ValenceLink> opened;
  setUp(() {
    opened = [];
    links = ValenceLinks(
      origins: {'https://links.example.com', 'myapp://app'},
      onOpened: opened.add,
    );
  });
  tearDown(() => links.close());

  test('maps only store-approved origins and preserves local query/fragment',
      () {
    final a =
        links.accept('https://links.example.com/plants/fern?q=green#care')!;
    expect(a.path, '/plants/fern?q=green#care');
    expect(links.accept('myapp://app/shelf?sort=new#one')!.path,
        '/shelf?sort=new#one');
    expect(links.accept('myapp://app')!.path, '/');
    for (final url in [
      'https://evil.example.com/shelf',
      'https://links.example.com.evil.com/shelf',
      'http://links.example.com/shelf',
      'myapp://other/shelf',
      'myapp://app:42/shelf',
      'https://user@links.example.com/shelf',
      'file:///shelf',
      'javascript:alert(1)',
      'https://links.example.com//evil.com',
      'myapp://app/_host/secret',
      'myapp://app/%5fhost/secret',
      'myapp://app/a%2fb',
      'myapp://app/a%5cb',
      'myapp://app/%00',
      'myapp://app/%0a',
      'myapp://app/%GG',
      'myapp://app/%FF',
      'myapp://app/a/../shelf',
      'myapp://app/%2e%2e/shelf',
      'https://links.example.com/${'a' * 8192}',
    ]) {
      expect(links.accept(url), isNull, reason: url);
    }
  });

  test(
      'latest pending wins, is consumed once; repeated live taps remain events',
      () {
    links.receive('myapp://app/one');
    links.receive('myapp://app/two');
    links.receive('myapp://other/three');
    expect(opened, isEmpty);
    expect(links.initial()!.path, '/two');
    expect(links.initial(), isNull);
    links.receive('myapp://app/two');
    links.receive('myapp://app/two');
    expect(opened.map((l) => l.path), ['/two', '/two']);
  });

  test(
      'launch/stream duplicate is removed during startup; later URL repetition is preserved',
      () async {
    final stream = StreamController<String>(sync: true);
    final initial = Completer<String?>();
    final start =
        links.start(getInitial: () => initial.future, stream: stream.stream);
    stream.add('myapp://app/launch');
    stream.add('myapp://app/warm');
    initial.complete('myapp://app/launch');
    await start;
    expect(links.initial()!.path, '/warm');
    stream.add('myapp://app/launch');
    expect(opened.single.path, '/launch');
    await links.close();
    stream.add('myapp://app/closed');
    expect(opened.length, 1);
    await stream.close();
  });

  test(
      'dispose during initial lookup drops the result and cancels native delivery',
      () async {
    final stream = StreamController<String>(sync: true);
    final initial = Completer<String?>();
    final start =
        links.start(getInitial: () => initial.future, stream: stream.stream);
    await links.close();
    initial.complete('myapp://app/late');
    await start;
    expect(links.initial(), isNull);
    expect(stream.hasListener, isFalse);
    await stream.close();
  });
}
