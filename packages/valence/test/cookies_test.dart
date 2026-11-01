// Contracts §4.5.1: the host-managed cookie jar for one compiled origin.
import 'dart:convert';

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
