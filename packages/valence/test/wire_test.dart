// Contracts §4.2: strict decoding, the closed error-code set, the reply cap and script building.
//
// These are the pieces `valence codegen` emits calls to, so the generated dispatcher's behaviour is this
// file's behaviour. The generated code itself is compiled and run by the CLI's own test suite.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/codegen.dart';
// BridgeError, BridgeErrorCode and maxMessageBytes belong to the app-facing library, not to codegen.dart:
// a generated file imports both, and the two surfaces deliberately do not overlap.
import 'package:valence/valence.dart';

void main() {
  Matcher throwsParams(String fragment) => throwsA(
        isA<BridgeError>()
            .having((e) => e.code, 'code', BridgeErrorCode.params)
            .having((e) => e.message, 'message', contains(fragment)),
      );

  group('strict decoding', () {
    test('decodeObject accepts an object and rejects everything else', () {
      expect(decodeObject(<String, Object?>{'a': 1}, 'p'), {'a': 1});
      for (final bad in [null, 1, 'x', <Object?>[], true]) {
        expect(() => decodeObject(bad, 'p'), throwsParams('expected an object'));
      }
    });

    test('decodeKeys rejects an unknown field and names it', () {
      expect(() => decodeKeys({'bucket': 'b', 'nope': 1}, {'bucket'}, 'p'), throwsParams('p.nope'));
      decodeKeys({'bucket': 'b'}, {'bucket', 'key'}, 'p'); // a missing optional field is fine
    });

    test('the primitive decoders are exact about type', () {
      expect(decodeString('x', 'f'), 'x');
      expect(() => decodeString(1, 'f'), throwsParams('expected a string'));
      expect(decodeInt(3, 'f'), 3);
      expect(() => decodeInt(3.5, 'f'), throwsParams('expected an int'));
      expect(() => decodeInt('3', 'f'), throwsParams('expected an int'));
      expect(decodeNum(3, 'f'), 3);
      expect(decodeNum(3.5, 'f'), 3.5);
      expect(() => decodeNum('3', 'f'), throwsParams('expected a number'));
      expect(decodeBool(true, 'f'), isTrue);
      expect(() => decodeBool(1, 'f'), throwsParams('expected a bool'));
      expect(() => decodeBool('true', 'f'), throwsParams('expected a bool'));
    });

    test('decodeListOf names the failing index', () {
      expect(decodeListOf<String>(['a', 'b'], 'f', decodeString), ['a', 'b']);
      expect(() => decodeListOf<String>(['a', 2], 'f', decodeString), throwsParams('f[1]'));
      expect(() => decodeListOf<String>('nope', 'f', decodeString), throwsParams('expected a list'));
      expect(decodeListOf<String>(<Object?>[], 'f', decodeString), isEmpty);
    });

    test('a nested failure carries the whole path', () {
      expect(
        () => decodeListOf<String>(
          [
            ['a'],
          ],
          'p.items',
          (e, p) => decodeString(e, p),
        ),
        throwsParams('p.items[0]'),
      );
    });
  });

  group('error codes', () {
    test('the set is closed and matches the spec', () {
      expect(
        {
          BridgeErrorCode.unknown,
          BridgeErrorCode.params,
          BridgeErrorCode.unsupported,
          BridgeErrorCode.denied,
          BridgeErrorCode.cancelled,
          BridgeErrorCode.tooLarge,
          BridgeErrorCode.internal,
        },
        {'E_UNKNOWN', 'E_PARAMS', 'E_UNSUPPORTED', 'E_DENIED', 'E_CANCELLED', 'E_TOO_LARGE', 'E_INTERNAL'},
      );
    });

    test('toString is greppable', () {
      expect(const BridgeError('E_DENIED', 'bad nonce').toString(), 'E_DENIED: bad nonce');
    });
  });

  group('replies (§4.2)', () {
    test('a success reply carries the id and the value', () {
      expect(jsonDecode(replyOk(7, {'a': 1})), {'id': 7, 'ok': true, 'v': {'a': 1}});
      // A void method replies with a null value, not with an absent one.
      expect(jsonDecode(replyOk(7, null)), {'id': 7, 'ok': true, 'v': null});
    });

    test('an error reply carries the code and the message', () {
      expect(jsonDecode(replyError(7, 'E_DENIED', 'nope')), {
        'id': 7,
        'ok': false,
        'e': {'code': 'E_DENIED', 'message': 'nope'},
      });
    });

    test('an over-cap reply becomes E_TOO_LARGE rather than being sent', () {
      // Without the cap a single large reply can kill the WebView mid-trial — and a WebView death while
      // serving a trial spends a strike, so a healthy bundle can be marked bad, which is final.
      final reply = jsonDecode(replyOk(7, 'x' * (maxMessageBytes + 1))) as Map<String, Object?>;
      expect(reply['ok'], isFalse);
      expect((reply['e']! as Map)['code'], 'E_TOO_LARGE');
      expect(reply['id'], 7, reason: 'the id is still in hand, so the page’s promise settles');
    });

    test('the cap is measured in UTF-8 bytes, not characters', () {
      // One Japanese character is 3 UTF-8 bytes. A string a third of the cap long in characters is over it
      // in bytes, and a length check would wave it through.
      final value = 'あ' * 100000;
      expect(value.length, lessThan(maxMessageBytes));
      expect(utf8.encode(value).length, greaterThan(maxMessageBytes));
      final reply = jsonDecode(replyOk(7, value)) as Map<String, Object?>;
      expect(reply['ok'], isFalse);
      expect((reply['e']! as Map)['code'], 'E_TOO_LARGE');
    });

    test('a reply just under the cap is sent intact', () {
      final value = 'x' * (maxMessageBytes - 200);
      final reply = jsonDecode(replyOk(7, value)) as Map<String, Object?>;
      expect(reply['ok'], isTrue);
      expect(reply['v'], value);
    });

    test('the cap is the value from the spec', () {
      expect(maxMessageBytes, 262144);
    });
  });

  group('script building (§4.2)', () {
    test('reply byte cap includes Unicode separator expansion', () {
      final reply = jsonDecode(replyOk(1, '\u2028' * 60000)) as Map;
      expect(reply['ok'], false);
      expect((reply['e'] as Map)['code'], 'E_TOO_LARGE');
    });
    test('error reply cap includes escaped ids and messages and preserves safe correlation', () {
      final hostile = '\u2028' * 60000;
      for (final id in [hostile, 17]) {
        final error = replyError(id, BridgeErrorCode.denied, hostile);
        expect(utf8.encode(bridgeReplyScript(error)).length, lessThan(maxMessageBytes));
        final reply = jsonDecode(error) as Map;
        expect(reply['id'], id == 17 ? 17 : null);
        expect((reply['e'] as Map)['code'], 'E_TOO_LARGE');
      }
    });
    test('both event and reply scripts escape Unicode line separators without changing JSON', () {
      const value = '\u2028\u2029";evil()';
      for (final script in [eventScript('push.received', {'body': value}), bridgeReplyScript(replyOk(1, value))]) {
        expect(script, contains(r'\u2028\u2029'));
        expect(script, isNot(contains('\u2028')));
        expect(script, isNot(contains('\u2029')));
      }
      final reply = bridgeReplyScript(replyOk(1, value));
      expect((jsonDecode(reply.substring(reply.indexOf('(') + 1, reply.length - 1)) as Map)['v'], value);
    });
    test('an event script goes through jsonEncode, so nothing is concatenated raw', () {
      expect(
        eventScript('sync.changed', {'buckets': ['plants']}),
        'window.__valence&&window.__valence.e("sync.changed",{"buckets":["plants"]})',
      );
    });

    test('quotes, backslashes and U+2028 round-trip through a script', () {
      // ES2019 allows a raw U+2028 in a string literal, and jsonEncode escapes quotes and backslashes, so
      // the payload survives runJavaScript unchanged.
      const nasty = 'he said "hi"\\ and   then   </script>';
      final script = eventScript('x.y', {'s': nasty});
      final json = script.substring(script.indexOf(',') + 1, script.length - 1);
      expect((jsonDecode(json) as Map)['s'], nasty);
    });

    test('an event name is encoded too, not interpolated', () {
      expect(eventScript('a"b', const <String, Object?>{}), contains(r'"a\"b"'));
    });

    test('a reply script wraps the reply JSON', () {
      expect(
        bridgeReplyScript('{"id":1,"ok":true,"v":null}'),
        'window.__valence&&window.__valence.r({"id":1,"ok":true,"v":null})',
      );
    });

    test('both scripts guard on window.__valence existing', () {
      // It does not exist until the entry page has loaded, so an event emitted before then must not throw
      // inside the WebView.
      expect(eventScript('a.b', const <String, Object?>{}), startsWith('window.__valence&&'));
      expect(bridgeReplyScript('{}'), startsWith('window.__valence&&'));
    });
  });
}
