import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valence/src/restoration.dart';
import 'package:valence/valence.dart';

void main() {
  test('task snapshot survives port rotation, never crosses a bundle boundary', () {
    final model = ValenceRestoration()..activate(12);
    model.observe('http://127.0.0.1:12000/shelf/fern?q=green#care', 'http://127.0.0.1:12000');
    model.save({'draft': 'नमस्ते', 'scroll': 20});
    final restored = ValenceRestoration()
      ..hydrate(model.snapshot())
      ..activate(12);
    expect(restored.route, '/shelf/fern?q=green#care');
    expect(Uri.parse('http://127.0.0.1:13000${restored.route}').port, 13000);
    expect(restored.restore(), {'draft': 'नमस्ते', 'scroll': 20});
    restored.activate(11);
    expect(restored.route, '/');
    expect(restored.restore(), isNull);
    expect((ValenceRestoration()..hydrate(null)).restore(), isNull);
  });

  test('64 KiB means encoded JSON UTF-8 bytes and rejection preserves previous blob', () {
    final model = ValenceRestoration()..activate(1);
    model.save('a' * 65534); // quotes count too
    expect(model.restore(), 'a' * 65534);
    expect(() => model.save('a' * 65535), throwsA(isA<BridgeError>()));
    expect(model.restore(), 'a' * 65534);
    expect(() => model.save('क' * 21845), throwsA(isA<BridgeError>()));
    final json = <String, Object?>{
      'a': <int>[1]
    };
    model.save(json);
    (json['a']! as List).add(2);
    (model.restore()! as Map)['a'] = false;
    expect(model.restore(), {
      'a': [1]
    });
    model.save(null);
    expect(model.restore(), isNull);
  });

  test('host and off-origin paths cannot be restored or observed', () {
    for (final route in [
      '//evil.invalid/x',
      'https://evil.invalid',
      '/_host/media/abc',
      '/%5fhost/alive',
      '/%255fhost/alive',
      '/%2f_host/alive',
      '/x/../_host/alive',
      '/x/%2e%2e/y',
      '/x\\y',
      '/%5cy',
      '/x%00y',
      '/x?q=%00',
      '/x#%5c',
      '/x//y',
      '/${'x' * 4096}',
    ]) {
      expect(ValenceRestoration.safeRoute(route), isFalse, reason: route);
      final model = ValenceRestoration()..hydrate(jsonEncode({'seq': 1, 'route': route, 'json': 'true'}));
      expect(model.route, '/');
      expect(model.restore(), isNull);
    }
    final model = ValenceRestoration()..activate(1);
    for (final url in [
      'https://evil.invalid/x',
      'http://127.0.0.1:1235/x',
      'data:text/html,x',
      'http://user@127.0.0.1:1234/x',
      'http://127.0.0.1:1234/_host/alive'
    ]) {
      model.observe(url, 'http://127.0.0.1:1234');
      expect(model.route, '/');
    }
    for (final route in ['/', '/shelf/', '/shelf/fern?q=x%20y#details', '/%E0%A4%95']) {
      expect(ValenceRestoration.safeRoute(route), isTrue, reason: route);
    }
  });

  test('corrupt snapshots clear both route and blob', () {
    for (final snapshot in [
      'bad json',
      '[]',
      '{"seq":1,"route":"/shelf","json":"bad"}',
      jsonEncode({'seq': 1, 'route': '/shelf', 'json': jsonEncode('x' * 65535)})
    ]) {
      final model = ValenceRestoration()..hydrate(snapshot);
      expect(model.route, '/');
      expect(model.restore(), isNull);
    }
  });

  testWidgets('Flutter OS snapshot restores task state; new task is empty', (tester) async {
    final model = ValenceRestoration();
    Widget host() => RootRestorationScope(
        restorationId: 'test',
        child: ValenceRestorationScope(model: model, onReady: () => model.activate(7), child: const SizedBox()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    model.observe('http://127.0.0.1:1234/shelf/fern?q=1#care', 'http://127.0.0.1:1234');
    model.save({'draft': 'retained task'});
    await tester.pump();
    final data = await tester.getRestorationData();
    await tester.restartAndRestore();
    expect(model.route, '/shelf/fern?q=1#care');
    expect(model.restore(), {'draft': 'retained task'});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(model.route, '/');
    expect(model.restore(), isNull);
    await tester.restoreFrom(data);
    expect(model.restore(), {'draft': 'retained task'});
  });

  test('a replacement envelope is checked against the bound account and sequence', () {
    final alice = ValenceRestoration()
      ..activate(7)
      ..bindAccount('alice', adopt: true);
    alice.observe('http://127.0.0.1:1/alice', 'http://127.0.0.1:1');
    alice.save({'draft': 'alice'});
    final envelope = alice.snapshot();

    for (final stranger in [
      ValenceRestoration()
        ..activate(7)
        ..bindAccount('bob', adopt: true), // another account
      ValenceRestoration()
        ..activate(6)
        ..bindAccount('alice', adopt: true), // another bundle
      ValenceRestoration()..activate(7), // no account bound at all
    ]) {
      stranger.hydrate(envelope, initial: false);
      expect(stranger.route, '/');
      expect(stranger.restore(), isNull);
    }

    final same = ValenceRestoration()
      ..activate(7)
      ..bindAccount('alice', adopt: true);
    same.hydrate(envelope, initial: false);
    expect(same.route, '/alice');
    expect(same.restore(), {'draft': 'alice'});
  });

  testWidgets('a replacement snapshot is refused after an account switch', (tester) async {
    final model = ValenceRestoration();
    Widget host() => RootRestorationScope(
        restorationId: 'test',
        child: ValenceRestorationScope(model: model, onReady: () => model.activate(7), child: const SizedBox()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    model.bindAccount('alice', adopt: true);
    model.observe('http://127.0.0.1:1234/alice/draft', 'http://127.0.0.1:1234');
    model.save({'draft': "alice's"});
    await tester.pump();
    final alice = await tester.getRestorationData();

    // The host switches account, which §4.4 clears the task snapshot for.
    model.bindAccount('bob');
    model.observe('http://127.0.0.1:1234/bob', 'http://127.0.0.1:1234');
    model.save({'draft': "bob's"});
    await tester.pump();

    await tester.restoreFrom(alice);
    expect(model.route, '/bob');
    expect(model.restore(), {'draft': "bob's"});
  });

  testWidgets('a replacement snapshot from another bundle sequence is refused', (tester) async {
    final model = ValenceRestoration();
    Widget host() => RootRestorationScope(
        restorationId: 'test',
        child: ValenceRestorationScope(model: model, onReady: () => model.activate(7), child: const SizedBox()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    model.observe('http://127.0.0.1:1234/old', 'http://127.0.0.1:1234');
    model.save({'draft': 'from 7'});
    await tester.pump();
    final old = await tester.getRestorationData();

    // An update commits: §4.8 drops task state across a bundle boundary.
    model.activate(8);
    model.observe('http://127.0.0.1:1234/new', 'http://127.0.0.1:1234');
    await tester.pump();

    await tester.restoreFrom(old);
    expect(model.route, '/new');
    expect(model.restore(), isNull);
  });
}
