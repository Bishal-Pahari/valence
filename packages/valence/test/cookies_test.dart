// Contracts §4.5.1: the host-managed cookie jar for one compiled origin.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valence/valence.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const jar = ValenceCookieJar(
      origin: 'https://api.test',
      csrfCookie: 'csrftoken',
      csrfHeader: 'X-CSRFToken');

  Matcher error(String code) =>
      throwsA(isA<BridgeError>().having((e) => e.code, 'code', code));

  /// Records what each request carried, and replies with the given Set-Cookie values.
  ({ValenceHttp http, List<http.Request> sent}) api({
    ValenceCookieJar? policy = jar,
    Map<String, String>? data,
    Set<String> origins = const {'https://api.test', 'https://other.test'},
    List<String> setCookie = const [],
    ValenceCookies? cookies,
    DateTime Function()? now,
  }) {
    final sent = <http.Request>[];
    final store = cookies ??
        ValenceCookies(
            jar: policy,
            secure: testSecure(data ?? <String, String>{}),
            now: now ?? DateTime.now);
    return (
      sent: sent,
      http: ValenceHttp(
        origins: origins,
        cookies: store,
        token: () async => null,
        onUnauthorized: () {},
        clientFactory: () => MockClient((request) async {
          sent.add(request);
          return http.Response('ok', 200, headers: {
            if (setCookie.isNotEmpty) 'set-cookie': setCookie.join(', '),
          });
        }),
      ),
    );
  }

  test('no jar means no Cookie sent and every Set-Cookie discarded', () async {
    final data = <String, String>{};
    final a = api(
        policy: null, data: data, setCookie: ['sessionid=abc; Max-Age=600']);
    final first = await a.http.request(url: 'https://api.test/a');
    expect(first.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('set-cookie')),
        reason: 'the page never sees Set-Cookie, jar or no jar');
    await a.http.request(url: 'https://api.test/a');
    expect(a.sent.last.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('cookie')));
    expect(data, isEmpty, reason: 'and nothing reaches secure storage');
  });

  test('a Set-Cookie from the jar origin is replayed on the next request',
      () async {
    final a = api(setCookie: ['sessionid=abc; Path=/; Max-Age=600']);
    await a.http.request(url: 'https://api.test/login');
    await a.http.request(url: 'https://api.test/items');
    expect(a.sent.last.headers['cookie'], 'sessionid=abc');
  });

  test('the configured CSRF cookie is mirrored into the configured header',
      () async {
    final cookies = ValenceCookies(jar: jar, secure: testSecure({}));
    final first =
        api(cookies: cookies, setCookie: ['csrftoken=t-1; Path=/; Max-Age=600']);
    await first.http.request(url: 'https://api.test/form');
    expect(first.sent.single.headers.containsKey('x-csrftoken'), isFalse,
        reason: 'nothing to mirror on the request that obtains the cookie');
    final second = api(cookies: cookies);
    await second.http.request(url: 'https://api.test/submit', method: 'POST');
    expect(second.sent.single.headers['x-csrftoken'], 't-1');
    expect(second.sent.single.headers['cookie'], 'csrftoken=t-1',
        reason: 'both halves of the double-submit pair, which is the point');
  });

  test('the page cannot supply the mirrored header', () async {
    final a = api();
    await expectLater(
        a.http.request(
            url: 'https://api.test/submit',
            method: 'POST',
            headers: {'X-CSRFToken': 'forged'}),
        error(BridgeErrorCode.denied));
    // Case-insensitively, and only for a build that configured the pair.
    await expectLater(
        a.http.request(
            url: 'https://api.test/submit',
            method: 'POST',
            headers: {'x-csrftoken': 'forged'}),
        error(BridgeErrorCode.denied));
    final none = api(policy: const ValenceCookieJar(origin: 'https://api.test'));
    await none.http.request(
        url: 'https://api.test/submit',
        method: 'POST',
        headers: {'X-CSRFToken': 'mine'});
    expect(none.sent.single.headers['x-csrftoken'], 'mine',
        reason: 'with no pair configured the header is the page\'s own again');
  });

  test('no other granted origin is sent the jar, and none fills it', () async {
    final cookies = ValenceCookies(jar: jar, secure: testSecure({}));
    final seeded =
        api(cookies: cookies, setCookie: ['sessionid=abc; Max-Age=600']);
    await seeded.http.request(url: 'https://api.test/login');
    final other = api(cookies: cookies, setCookie: ['sessionid=evil; Max-Age=600']);
    await other.http.request(url: 'https://other.test/x');
    expect(other.sent.single.headers.containsKey('cookie'), isFalse);
    final back = api(cookies: cookies);
    await back.http.request(url: 'https://api.test/items');
    expect(back.sent.single.headers['cookie'], 'sessionid=abc',
        reason: 'the other origin could neither read nor overwrite the jar');
  });

  test('a Domain widening to a parent or sibling host is dropped', () async {
    for (final domain in ['.test', 'evil.test', 'a.api.test']) {
      final a = api(setCookie: ['sessionid=abc; Domain=$domain; Max-Age=600']);
      await a.http.request(url: 'https://api.test/login');
      await a.http.request(url: 'https://api.test/items');
      expect(a.sent.last.headers.containsKey('cookie'), isFalse,
          reason: 'Domain=$domain is not exactly the jar host');
    }
    // The exact host, with or without the leading dot, is host-only and kept.
    final ok = api(setCookie: ['sessionid=abc; Domain=.api.test; Max-Age=600']);
    await ok.http.request(url: 'https://api.test/login');
    await ok.http.request(url: 'https://api.test/items');
    expect(ok.sent.last.headers['cookie'], 'sessionid=abc');
  });

  test('a Path that does not match is not sent', () async {
    final a = api(setCookie: ['scoped=1; Path=/admin; Max-Age=600']);
    await a.http.request(url: 'https://api.test/admin/x');
    await a.http.request(url: 'https://api.test/items');
    expect(a.sent.last.headers.containsKey('cookie'), isFalse);
    await a.http.request(url: 'https://api.test/admin');
    expect(a.sent.last.headers['cookie'], 'scoped=1');
    await a.http.request(url: 'https://api.test/administrator');
    expect(a.sent.last.headers.containsKey('cookie'), isFalse,
        reason: 'a prefix is not a path match without a / boundary');
  });

  test('Max-Age wins over Expires, and zero deletes', () async {
    var clock = DateTime.utc(2026, 11, 2, 12);
    final cookies =
        ValenceCookies(jar: jar, secure: testSecure({}), now: () => clock);
    // Expires in the past, Max-Age in the future: RFC 6265 says Max-Age wins, so it is kept.
    final set = api(cookies: cookies, setCookie: [
      'a=1; Max-Age=600; Expires=Wed, 21 Oct 2015 07:28:00 GMT'
    ]);
    await set.http.request(url: 'https://api.test/x');
    final kept = api(cookies: cookies);
    await kept.http.request(url: 'https://api.test/x');
    expect(kept.sent.single.headers['cookie'], 'a=1');
    // And it expires on its own clock, with nothing from the server needed.
    clock = clock.add(const Duration(seconds: 601));
    final gone = api(cookies: cookies);
    await gone.http.request(url: 'https://api.test/x');
    expect(gone.sent.single.headers.containsKey('cookie'), isFalse);
    // Max-Age=0 is a deletion of a cookie that is already there.
    final again = api(cookies: cookies, setCookie: ['b=2; Max-Age=600']);
    await again.http.request(url: 'https://api.test/x');
    final deleted = api(cookies: cookies, setCookie: ['b=2; Max-Age=0']);
    await deleted.http.request(url: 'https://api.test/x');
    final after = api(cookies: cookies);
    await after.http.request(url: 'https://api.test/x');
    expect(after.sent.single.headers.containsKey('cookie'), isFalse);
  });

  test('a session cookie never reaches storage; an expiring one is reloaded',
      () async {
    final data = <String, String>{};
    final first = api(data: data, setCookie: ['s=1', 'p=2; Max-Age=600']);
    await first.http.request(url: 'https://api.test/x');
    expect(data[secureCookieJarKey], isNotNull);
    expect(data[secureCookieJarKey], contains('"p"'));
    expect(data[secureCookieJarKey], isNot(contains('"s"')),
        reason: 'a session cookie belongs to this process only');
    // A new runtime over the same secure storage: the restart is a new session.
    final restarted = api(data: data);
    await restarted.http.request(url: 'https://api.test/x');
    expect(restarted.sent.single.headers['cookie'], 'p=2');
  });

  test('opted-in sessions survive restart with a fixed receipt deadline',
      () async {
    var clock = DateTime.utc(2026, 11, 2);
    final data = <String, String>{};
    final url = Uri.parse('https://api.test/x');
    ValenceCookies restart(int? days) => ValenceCookies(
        jar: ValenceCookieJar(
            origin: 'https://api.test', sessionCookieDays: days),
        secure: testSecure(data),
        now: () => clock);
    final first = restart(2);
    await first.absorb(url, ['sessionid=abc', 'p=2; Max-Age=864000']);
    final original = data[secureCookieJarKey];
    expect(original, contains('sessionStartedAt'));
    clock = clock.add(const Duration(days: 1));
    final second = restart(30);
    await second.revoke();
    expect(await second.header(url), 'sessionid=abc; p=2');
    expect(data[secureCookieJarKey], original,
        reason: 'a restart or larger policy never renews a stored session');
    clock = clock.add(const Duration(days: 1));
    expect(await restart(30).header(url), 'p=2');
    expect(data[secureCookieJarKey], isNot(contains('sessionid')));
  });

  test('removing or shortening the opt-in revokes only the session grant',
      () async {
    var clock = DateTime.utc(2026, 11, 2);
    final data = <String, String>{};
    final url = Uri.parse('https://api.test/x');
    ValenceCookies restart(int? days) => ValenceCookies(
        jar: ValenceCookieJar(
            origin: 'https://api.test', sessionCookieDays: days),
        secure: testSecure(data),
        now: () => clock);
    await restart(30).absorb(url, ['s=1', 'p=2; Max-Age=864000']);
    clock = clock.add(const Duration(days: 2));
    final shorter = restart(3);
    await shorter.revoke();
    expect(await shorter.header(url), 's=1; p=2');
    final rows =
        (jsonDecode(data[secureCookieJarKey]!) as Map)['cookies'] as List;
    expect(rows.first['expires'],
        DateTime.utc(2026, 11, 5).millisecondsSinceEpoch);
    final removed = restart(null);
    await removed.revoke();
    expect(await removed.header(url), 'p=2');
    expect(data[secureCookieJarKey], isNot(contains('sessionStartedAt')));
    // The next opt-in cannot resurrect the cookie dropped by the intervening build.
    expect(await restart(30).header(url), 'p=2');
  });

  test(
      'an opt-in never extends server expiry or defeats deletion and origin scope',
      () async {
    var clock = DateTime.utc(2026, 11, 2);
    final data = <String, String>{};
    const policy =
        ValenceCookieJar(origin: 'https://api.test', sessionCookieDays: 30);
    final cookies =
        ValenceCookies(jar: policy, secure: testSecure(data), now: () => clock);
    final url = Uri.parse('https://api.test/x');
    await cookies.absorb(url, ['s=1', 'short=2; Max-Age=1']);
    clock = clock.add(const Duration(seconds: 2));
    expect(await cookies.header(url), 's=1');
    expect(await cookies.header(Uri.parse('https://other.test/x')), isNull);
    await cookies.absorb(url, ['s=gone; Max-Age=0']);
    expect(await cookies.header(url), isNull);
    expect(data[secureCookieJarKey], isNull);
    await cookies.absorb(url, ['s=again']);
    final moved = ValenceCookies(
        jar: const ValenceCookieJar(origin: 'https://other.test'),
        secure: testSecure(data));
    await moved.revoke();
    expect(data[secureCookieJarKey], isNull,
        reason:
            'moving the origin revokes even a session discarded by opt-out');
  });

  test('failed session revocation seals the jar without failing startup', () async {
    final data = <String, String>{};
    final url = Uri.parse('https://api.test/x');
    final first = ValenceCookies(
        jar: const ValenceCookieJar(origin: 'https://api.test', sessionCookieDays: 30),
        secure: testSecure(data));
    await first.absorb(url, ['s=1', 'p=2; Max-Age=600']);
    for (final days in [null, 1]) {
      final reduced = ValenceCookies(
          jar: ValenceCookieJar(origin: 'https://api.test', sessionCookieDays: days),
          secure: readOnlySecure(data));
      await reduced.revoke();
      expect(await reduced.header(url), isNull);
      await reduced.absorb(url, ['new=3']);
      expect(await reduced.header(url), isNull);
    }
  });

  test('manual out-of-range session policies seal the jar', () async {
    for (final days in [0, -1, 31]) {
      final data = <String, String>{};
      final cookies = ValenceCookies(
          jar: ValenceCookieJar(
              origin: 'https://api.test', sessionCookieDays: days),
          secure: testSecure(data));
      final url = Uri.parse('https://api.test/x');
      await cookies.absorb(url, ['s=1']);
      expect(await cookies.header(url), isNull);
      expect(data, isEmpty);
    }
  });

  test('a malformed Set-Cookie is skipped and the request still succeeds',
      () async {
    final a = api(setCookie: ['=nonsense', 'good=1; Max-Age=600']);
    final response = await a.http.request(url: 'https://api.test/x');
    expect(response.status, 200);
    await a.http.request(url: 'https://api.test/x');
    expect(a.sent.last.headers['cookie'], 'good=1');
  });

  test('the caps drop the offending cookie and keep the response', () async {
    final cookies = ValenceCookies(jar: jar, secure: testSecure({}));
    final big = api(cookies: cookies, setCookie: [
      'huge=${'x' * ValenceCookies.maxCookieBytes}; Max-Age=600'
    ]);
    expect((await big.http.request(url: 'https://api.test/x')).status, 200);
    final after = api(cookies: cookies);
    await after.http.request(url: 'https://api.test/x');
    expect(after.sent.single.headers.containsKey('cookie'), isFalse);
    // Seventeen small cookies: the first sixteen land, the last is refused.
    final many = api(cookies: cookies, setCookie: [
      for (var i = 0; i < ValenceCookies.maxCookies + 1; i++)
        'c$i=v; Max-Age=600'
    ]);
    expect((await many.http.request(url: 'https://api.test/x')).status, 200);
    final sent = api(cookies: cookies);
    await sent.http.request(url: 'https://api.test/x');
    final names = sent.sent.single.headers['cookie']!.split('; ');
    expect(names, hasLength(ValenceCookies.maxCookies));
    expect(names, isNot(contains('c${ValenceCookies.maxCookies}=v')));
  });

  test('a stored jar from another origin is revoked, and a dropped jar cleared',
      () async {
    final data = <String, String>{};
    final seeded = api(data: data, setCookie: ['sessionid=abc; Max-Age=600']);
    await seeded.http.request(url: 'https://api.test/login');
    expect(data[secureCookieJarKey], contains('https://api.test'));

    // The build moves the jar to another origin: the old cookies go, unread.
    final moved = ValenceCookies(
        jar: const ValenceCookieJar(origin: 'https://other.test'),
        secure: testSecure(data));
    await moved.revoke();
    expect(data[secureCookieJarKey], isNull);

    // And a build that dropped the grant clears it without even loading it.
    data[secureCookieJarKey] =
        jsonEncode({'origin': 'https://api.test', 'cookies': []});
    final dropped = ValenceCookies(jar: null, secure: testSecure(data));
    await dropped.revoke();
    expect(data[secureCookieJarKey], isNull);

    // An unchanged origin keeps them.
    data[secureCookieJarKey] = jsonEncode({
      'origin': 'https://api.test',
      'cookies': [
        {
          'name': 'sessionid',
          'value': 'abc',
          'path': '/',
          'expires':
              DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
        }
      ],
    });
    final same = ValenceCookies(jar: jar, secure: testSecure(data));
    await same.revoke();
    expect(data[secureCookieJarKey], isNotNull);
    expect(await same.header(Uri.parse('https://api.test/x')), 'sessionid=abc');
  });

  test('an undecodable stored jar is an empty jar, not a failed request',
      () async {
    final data = <String, String>{secureCookieJarKey: 'not json'};
    final a = api(data: data);
    expect((await a.http.request(url: 'https://api.test/x')).status, 200);
    expect(a.sent.single.headers.containsKey('cookie'), isFalse);
  });

  test('a revocation that cannot reach storage seals the jar, never the launch',
      () async {
    final url = Uri.parse('https://api.test/x');
    // Valence.open calls revoke() on every launch, so neither of these may throw: a device whose
    // Keystore the OS has invalidated has to be able to start the app at all.
    final broken = ValenceCookies(jar: jar, secure: brokenSecure());
    await broken.revoke();
    await broken.absorb(url, const ['sessionid=abc; Max-Age=600']);
    expect(await broken.header(url), 'sessionid=abc',
        reason: 'an unreadable Keystore has nothing to revoke, so the jar runs in memory');
    final none = ValenceCookies(jar: null, secure: brokenSecure());
    await none.revoke();

    // The state that does matter: a stored jar of another origin that cannot be deleted. The jar is
    // sealed for the launch, so none of those cookies is ever sent and none is taken.
    final data = <String, String>{
      secureCookieJarKey: jsonEncode({
        'origin': 'https://old.test',
        'cookies': [
          {
            'name': 'sessionid',
            'value': 'stale',
            'path': '/',
            'expires': DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          }
        ],
      }),
    };
    final sealed = ValenceCookies(jar: jar, secure: readOnlySecure(data));
    await sealed.revoke();
    expect(await sealed.header(url), isNull);
    await sealed.absorb(url, const ['sessionid=new; Max-Age=600']);
    expect(await sealed.header(url), isNull,
        reason: 'sealed means it absorbs nothing either');
  });

  test('a mirrored header the host controls fails loudly, not silently',
      () async {
    // codegen refuses this, so it can only arrive from a hand-written config. Overwriting the bearer
    // token with a CSRF value would be a credential swap, so the request fails instead.
    for (final header in ['Authorization', 'Cookie', 'Sec-Fetch-Mode']) {
      expect(ValenceHttp.hostControlled(header.toLowerCase()), isTrue);
      final a = api(
          policy: ValenceCookieJar(
              origin: 'https://api.test',
              csrfCookie: 'csrftoken',
              csrfHeader: header));
      await expectLater(a.http.request(url: 'https://api.test/x'),
          error(BridgeErrorCode.internal));
    }
  });

  test('the 8-KiB total cap holds, including across a replacement', () async {
    final cookies = ValenceCookies(jar: jar, secure: testSecure({}));
    final value = 'v' * 3000; // Three of these are over 8192 bytes; two are not.
    final two = api(cookies: cookies, setCookie: ['a=$value; Max-Age=600', 'b=$value; Max-Age=600']);
    await two.http.request(url: 'https://api.test/x');
    final third = api(cookies: cookies, setCookie: ['c=$value; Max-Age=600']);
    expect((await third.http.request(url: 'https://api.test/x')).status, 200);
    final sent = api(cookies: cookies);
    await sent.http.request(url: 'https://api.test/x');
    expect(sent.sent.single.headers['cookie']!.split('; ').map((c) => c.split('=').first),
        unorderedEquals(['a', 'b']),
        reason: 'the third does not fit under the total cap');
    // Replacing "a" with a short value frees room, because the replaced size is subtracted.
    final shrink = api(cookies: cookies, setCookie: ['a=1; Max-Age=600']);
    await shrink.http.request(url: 'https://api.test/x');
    final room = api(cookies: cookies, setCookie: ['c=$value; Max-Age=600']);
    await room.http.request(url: 'https://api.test/x');
    final after = api(cookies: cookies);
    await after.http.request(url: 'https://api.test/x');
    expect(after.sent.single.headers['cookie']!.split('; ').map((c) => c.split('=').first),
        unorderedEquals(['a', 'b', 'c']));
  });

  test('the caps are applied again when the jar is read back from storage', () async {
    // Only the host writes this key, so an over-cap envelope means a restored backup or a future
    // shape. Neither gets to be unbounded.
    final future = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final data = <String, String>{
      secureCookieJarKey: jsonEncode({
        'origin': 'https://api.test',
        'cookies': [
          for (var i = 0; i < 40; i++)
            {'name': 'c$i', 'value': 'v' * 500, 'path': '/', 'expires': future},
        ],
      }),
    };
    final a = api(data: data);
    await a.http.request(url: 'https://api.test/x');
    final names = a.sent.single.headers['cookie']!.split('; ');
    expect(names.length, lessThanOrEqualTo(ValenceCookies.maxCookies));
    expect(a.sent.single.headers['cookie']!.length,
        lessThanOrEqualTo(ValenceCookies.maxJarBytes));
  });

  test('a natural expiry is written through, not left at rest', () async {
    var clock = DateTime.utc(2026, 11, 2, 12);
    final data = <String, String>{};
    final cookies = ValenceCookies(
        jar: jar, secure: testSecure(data), now: () => clock);
    final set = api(cookies: cookies, setCookie: ['a=1; Max-Age=600']);
    await set.http.request(url: 'https://api.test/x');
    expect(data[secureCookieJarKey], contains('"a"'));
    clock = clock.add(const Duration(seconds: 601));
    final gone = api(cookies: cookies);
    await gone.http.request(url: 'https://api.test/x');
    expect(gone.sent.single.headers.containsKey('cookie'), isFalse);
    expect(data[secureCookieJarKey], isNull,
        reason: 'an expired credential does not stay in the Keystore waiting for a Set-Cookie');
  });

  test('the mirrored header is path-matched like the Cookie half', () async {
    // A GET under /a/b with no Path scopes the cookie to /a/b. A later POST to /submit must get
    // neither half: the token alone is a half-pair the server rejects, on a path the page chose.
    final cookies = ValenceCookies(jar: jar, secure: testSecure({}));
    final scoped = api(cookies: cookies, setCookie: ['csrftoken=t-1; Max-Age=600']);
    await scoped.http.request(url: 'https://api.test/a/b/get');
    final off = api(cookies: cookies);
    await off.http.request(url: 'https://api.test/submit', method: 'POST');
    expect(off.sent.single.headers.containsKey('x-csrftoken'), isFalse);
    expect(off.sent.single.headers.containsKey('cookie'), isFalse);
    final on = api(cookies: cookies);
    await on.http.request(url: 'https://api.test/a/b/submit', method: 'POST');
    expect(on.sent.single.headers['x-csrftoken'], 't-1');
    expect(on.sent.single.headers['cookie'], 'csrftoken=t-1');
  });

  test('a Secure cookie is dropped over the cleartext loopback carve-out', () async {
    const loopback = ValenceCookieJar(origin: 'http://127.0.0.1:8787');
    final a = api(
        policy: loopback,
        origins: const {'http://127.0.0.1:8787'},
        setCookie: ['s=1; Secure; Max-Age=600', 'plain=2; Max-Age=600']);
    await a.http.request(url: 'http://127.0.0.1:8787/x');
    await a.http.request(url: 'http://127.0.0.1:8787/x');
    expect(a.sent.last.headers['cookie'], 'plain=2');
  });

  test('a jar the runtime should never have been handed is sealed, not used', () async {
    // codegen refuses each of these; a hand-written ValenceConfig must not get a working jar anyway.
    final bad = <ValenceCookieJar, Set<String>>{
      const ValenceCookieJar(origin: 'http://api.test'): {'http://api.test'},
      const ValenceCookieJar(origin: 'https://API.test'): {'https://api.test'},
      const ValenceCookieJar(origin: 'https://api.test/v1'): {'https://api.test'},
      const ValenceCookieJar(origin: 'not a url'): {'https://api.test'},
      const ValenceCookieJar(origin: 'https://api.test'): {'https://other.test'},
    };
    for (final entry in bad.entries) {
      final cookies = ValenceCookies(
          jar: entry.key, secure: testSecure({}), origins: entry.value);
      expect(cookies.owns(Uri.parse(entry.key.origin)), isFalse,
          reason: '${entry.key.origin} with origins ${entry.value}');
      await cookies.revoke();
      await cookies.absorb(
          Uri.parse('https://api.test/x'), const ['sessionid=abc; Max-Age=600']);
      expect(await cookies.header(Uri.parse('https://api.test/x')), isNull);
    }
    // The loopback carve-out is the one cleartext origin that is allowed.
    final ok = ValenceCookies(
        jar: const ValenceCookieJar(origin: 'http://127.0.0.1:8787'),
        secure: testSecure({}),
        origins: const {'http://127.0.0.1:8787'});
    expect(ok.owns(Uri.parse('http://127.0.0.1:8787/x')), isTrue);
  });

  test('a URL with no origin to compare is refused rather than throwing', () async {
    final cookies = ValenceCookies(jar: jar, secure: testSecure({}));
    for (final url in ['file:///etc/passwd', 'mailto:a@b.test', 'https:///x']) {
      expect(cookies.owns(Uri.parse(url)), isFalse, reason: url);
      expect(await cookies.header(Uri.parse(url)), isNull);
    }
  });

  test('two concurrent first calls both see the stored jar', () async {
    // _load is memoized as a future, not a flag: a flag set before the platform read awaits lets the
    // second caller through on an empty jar, and two bridge messages do dispatch at once.
    final data = <String, String>{
      secureCookieJarKey: jsonEncode({
        'origin': 'https://api.test',
        'cookies': [
          {
            'name': 'sessionid',
            'value': 'abc',
            'path': '/',
            'expires': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
          }
        ],
      }),
    };
    final cookies = ValenceCookies(jar: jar, secure: testSecure(data));
    final url = Uri.parse('https://api.test/x');
    final both = await Future.wait([cookies.header(url), cookies.header(url)]);
    expect(both, ['sessionid=abc', 'sessionid=abc']);
  });

  test('Set-Cookie is stripped from what the page receives with a jar configured', () async {
    final a = api(setCookie: ['sessionid=abc; Max-Age=600', 'other=2']);
    final response = await a.http.request(url: 'https://api.test/x');
    expect(response.headers.keys.map((k) => k.toLowerCase()),
        isNot(anyElement(anyOf('set-cookie', 'set-cookie2'))));
    // And the jar did take them, so the strip is not just an empty response.
    await a.http.request(url: 'https://api.test/x');
    expect(a.sent.last.headers['cookie'], contains('sessionid=abc'));
  });

  test('two real Set-Cookie headers are both absorbed, not joined into one', () async {
    // Every other test here hands MockClient a single pre-joined value. `package:http` exposes
    // multiple headers only through `headersSplitValues`, whose splitter has to get a comma inside an
    // `Expires` date right — so this one goes through a real socket and the real client.
    // TestWidgetsFlutterBinding installs an HttpOverrides that answers 400 without a socket, so this
    // test is the one here that has to take it off.
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <String?>[];
    server.listen((request) {
      seen.add(request.headers.value('cookie'));
      request.response.headers
        ..add('set-cookie', 'a=1; Path=/; Expires=Wed, 21 Oct 2099 07:28:00 GMT')
        ..add('set-cookie', 'b=2; Path=/; Max-Age=600');
      request.response
        ..write('ok')
        ..close();
    });
    final origin = 'http://127.0.0.1:${server.port}';
    final cookies = ValenceCookies(
        jar: ValenceCookieJar(origin: origin), secure: testSecure({}));
    final api = ValenceHttp(
        origins: {origin},
        cookies: cookies,
        token: () async => null,
        onUnauthorized: () {});
    await api.request(url: '$origin/one');
    await api.request(url: '$origin/two');
    expect(seen, [null, anyOf('a=1; b=2', 'b=2; a=1')],
        reason: 'the Expires comma must not have split "a" in half');
  });

  test('clear empties the jar in memory and in secure storage', () async {
    final data = <String, String>{};
    final cookies = ValenceCookies(jar: jar, secure: testSecure(data));
    final seeded =
        api(cookies: cookies, setCookie: ['sessionid=abc; Max-Age=600', 's=1']);
    await seeded.http.request(url: 'https://api.test/login');
    expect(data[secureCookieJarKey], isNotNull);
    await cookies.clear();
    expect(data[secureCookieJarKey], isNull);
    final after = api(cookies: cookies);
    await after.http.request(url: 'https://api.test/x');
    expect(after.sent.single.headers.containsKey('cookie'), isFalse,
        reason: 'the in-memory session cookie goes too');
  });
}
