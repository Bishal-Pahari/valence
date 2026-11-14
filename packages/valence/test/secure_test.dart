// Contracts §4.4: Keystore-backed storage, and the token the page can set but never read back.
import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Matcher throwsDenied(String fragment) => throwsA(
        isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.denied)
            .having((e) => e.message, 'message', contains(fragment)),
      );

  test('a value set by the page is read back and deleted', () async {
    final data = <String, String>{};
    final secure = testSecure(data);
    await secure.set('refresh', 'r-1');
    expect(await secure.get('refresh'), 'r-1');
    expect(data['refresh'], 'r-1', reason: 'and it is in the platform store, not in SQLite');
    await secure.delete('refresh');
    expect(await secure.get('refresh'), isNull);
  });

  test('the reserved prefix is refused on every page-facing method', () async {
    final secure = testSecure({});
    expect(() => secure.get('valence.auth.token'), throwsDenied('reserved'));
    expect(() => secure.set('valence.anything', 'x'), throwsDenied('reserved'));
    expect(() => secure.delete('valence.auth.token'), throwsDenied('reserved'));
    // The bare word is reserved too, so "valence" cannot be used to probe the namespace.
    expect(() => secure.get('valence'), throwsDenied('reserved'));
  });

  test('the token is stored where the page cannot read it', () async {
    final data = <String, String>{};
    final secure = testSecure(data);
    expect(await secure.hasAuthToken(), isFalse);
    await secure.setAuthToken('jwt-1');
    expect(data[secureAuthTokenKey], 'jwt-1');
    expect(await secure.hasAuthToken(), isTrue);
    expect(await secure.authToken(), 'jwt-1', reason: 'the host itself reads it, to attach the header');
    // The whole point: the only read the bridge exposes refuses this key.
    expect(() => secure.get(secureAuthTokenKey), throwsDenied('reserved'));
  });

  test('setting a null or empty token clears it', () async {
    final data = <String, String>{};
    final secure = testSecure(data);
    await secure.setAuthToken('jwt-1');
    await secure.setAuthToken(null);
    expect(data.containsKey(secureAuthTokenKey), isFalse);
    await secure.setAuthToken('jwt-2');
    // An empty string is a logout too: it is what an uninitialised form field sends, and a
    // `Bearer ` header with nothing after it is worse than no header at all.
    await secure.setAuthToken('');
    expect(await secure.hasAuthToken(), isFalse);
  });

  group('a platform that cannot answer (§4.4)', () {
    test('a read is absent rather than an exception', () async {
      final log = LogSpy();
      final secure = brokenSecure(log: log.call);
      expect(await secure.authToken(), isNull);
      expect(await secure.hasAuthToken(), isFalse);
      expect(await secure.get('refresh'), isNull);
      // Otherwise a MissingPluginException is thrown out of the middle of a sync and fails the whole
      // run, including the public buckets that were never authenticated.
      expect(log.has('treating it as absent'), isTrue);
    });

    test('a write says so rather than silently losing the token', () async {
      final secure = brokenSecure();
      expect(
        () => secure.setAuthToken('jwt-1'),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internal)),
      );
      expect(() => secure.set('refresh', 'r-1'), throwsA(isA<BridgeError>()));
    });
  });
}
