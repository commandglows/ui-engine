import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shipglows_clerk_auth/shipglows_clerk_auth.dart';

const _config = ClerkAuthConfig(
  issuer: 'https://example.clerk.accounts.dev',
  clientId: 'client',
  androidScheme: 'com.example.app',
  desktopPort: 47999,
);

class _FakeBrowser implements ClerkBrowser {
  Uri? lastUrl;

  @override
  Future<String> authenticate({
    required Uri url,
    required String callbackScheme,
  }) async {
    lastUrl = url;
    final state = url.queryParameters['state'];
    return '${_config.androidRedirectUri}?code=abc&state=$state';
  }
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

/// An unsigned JWT: the client reads claims, the backend verifies signatures.
String _jwt(Map<String, Object?> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

Map<String, Object?> _claims({
  String iss = 'https://example.clerk.accounts.dev',
  Object aud = 'client',
  String sub = 'user_1',
  String? nonce,
}) => {
  'iss': iss,
  'aud': aud,
  'sub': sub,
  'nonce': ?nonce,
  'exp': DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000,
};

ClerkAuthClient _signInClient(
  _FakeBrowser browser,
  Map<String, Object?> Function(String? nonce) claims,
) => ClerkAuthClient(
  config: _config,
  store: MemoryClerkSessionStore(),
  browser: browser,
  clock: () => DateTime.utc(2026, 10, 26, 12),
  httpClient: MockClient((request) async {
    if (request.url.path == '/oauth/token') {
      final nonce = browser.lastUrl?.queryParameters['nonce'];
      return _json({
        'access_token': 'at',
        'refresh_token': 'rt',
        'id_token': _jwt(claims(nonce)),
        'expires_in': 86400,
      });
    }
    return _json({'sub': 'user_1'});
  }),
);

Matcher _authError(String code) => isA<ClerkAuthException>().having(
  (error) => error.code,
  'code',
  code,
);

class _ScriptedBrowser implements ClerkBrowser {
  _ScriptedBrowser(this.respond);

  final String Function(Uri url) respond;

  @override
  Future<String> authenticate({
    required Uri url,
    required String callbackScheme,
  }) async => respond(url);
}

void main() {
  final now = DateTime.utc(2026, 10, 26, 12);

  test('signIn exchanges the code with PKCE and stores the session', () async {
    final store = MemoryClerkSessionStore();
    final browser = _FakeBrowser();
    late Map<String, String> tokenBody;
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      browser: browser,
      clock: () => now,
      httpClient: MockClient((request) async {
        if (request.url.path == '/oauth/token') {
          tokenBody = Uri.splitQueryString(request.body);
          return _json({
            'access_token': 'at',
            'refresh_token': 'rt',
            'id_token': _jwt(
              _claims(nonce: browser.lastUrl?.queryParameters['nonce']),
            ),
            'expires_in': 86400,
          });
        }
        expect(request.headers['Authorization'], 'Bearer at');
        return _json({'sub': 'user_1', 'email': 'a@b.c'});
      }),
    );

    final session = await client.signIn();

    expect(browser.lastUrl!.queryParameters['code_challenge_method'], 'S256');
    expect(tokenBody['code_verifier'], isNotEmpty);
    expect(tokenBody['client_id'], 'client');
    expect(tokenBody.containsKey('client_secret'), isFalse);
    expect(session.subject, 'user_1');
    expect((await store.read())!.refreshToken, 'rt');
    expect(client.session.value, same(session));
  });

  test('restore refreshes an expired token and keeps the refresh token', () async {
    final store = MemoryClerkSessionStore();
    await store.write(
      ClerkSession(
        subject: 'user_1',
        accessToken: 'old',
        accessTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
        refreshToken: 'rt',
      ),
    );
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      clock: () => now,
      httpClient: MockClient(
        (_) async => _json({'access_token': 'new', 'expires_in': 3600}),
      ),
    );

    final session = await client.restore();

    expect(session!.accessToken, 'new');
    expect(session.refreshToken, 'rt');
    expect(await client.accessToken(), 'new');
  });

  test('a revoked refresh token signs the user out', () async {
    final store = MemoryClerkSessionStore();
    await store.write(
      ClerkSession(
        subject: 'user_1',
        accessToken: 'old',
        accessTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
        refreshToken: 'rt',
      ),
    );
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      clock: () => now,
      httpClient: MockClient(
        (_) async => _json({'error': 'invalid_grant'}, 400),
      ),
    );

    expect(await client.restore(), isNull);
    expect(await store.read(), isNull);
  });

  test('offline restore keeps the stored session', () async {
    final store = MemoryClerkSessionStore();
    final stored = ClerkSession(
      subject: 'user_1',
      accessToken: 'old',
      accessTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
      refreshToken: 'rt',
    );
    await store.write(stored);
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      clock: () => now,
      httpClient: MockClient((_) async => throw http.ClientException('off')),
    );

    expect(await client.restore(), same(stored));
  });

  test('signOut forgets the session and revokes the refresh token', () async {
    final store = MemoryClerkSessionStore();
    await store.write(
      ClerkSession(
        subject: 'user_1',
        accessToken: 'at',
        accessTokenExpiresAt: now.add(const Duration(hours: 1)),
        refreshToken: 'rt',
      ),
    );
    Uri? revoked;
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      clock: () => now,
      httpClient: MockClient((request) async {
        revoked = request.url;
        return http.Response('', 200);
      }),
    );
    await client.restore();

    await client.signOut();

    expect(client.session.value, isNull);
    expect(await store.read(), isNull);
    expect(revoked!.path, '/oauth/token/revoke');
  });

  group('id_token checks at sign-in', () {
    test('accepts an audience list and a trailing slash on the issuer', () async {
      final browser = _FakeBrowser();
      final client = _signInClient(
        browser,
        (nonce) => _claims(
          iss: 'https://example.clerk.accounts.dev/',
          aud: ['client', 'other'],
          nonce: nonce,
        ),
      );
      expect((await client.signIn()).subject, 'user_1');
    });

    for (final entry in <String, Map<String, Object?> Function(String?)>{
      'issuer': (nonce) => _claims(iss: 'https://other.dev', nonce: nonce),
      'audience': (nonce) => _claims(aud: 'other', nonce: nonce),
      'subject': (nonce) => _claims(sub: 'user_2', nonce: nonce),
      'nonce': (nonce) => _claims(nonce: 'other'),
      'missing nonce': (nonce) => _claims(),
    }.entries) {
      test('refuses a wrong ${entry.key}', () async {
        final store = MemoryClerkSessionStore();
        final browser = _FakeBrowser();
        final client = ClerkAuthClient(
          config: _config,
          store: store,
          browser: browser,
          httpClient: MockClient((request) async {
            if (request.url.path == '/oauth/token') {
              return _json({
                'access_token': 'at',
                'id_token': _jwt(
                  entry.value(browser.lastUrl?.queryParameters['nonce']),
                ),
              });
            }
            return _json({'sub': 'user_1'});
          }),
        );
        await expectLater(client.signIn(), throwsA(_authError('id-token-invalid')));
        expect(await store.read(), isNull);
      });
    }
  });

  test('checks state before the callback error', () async {
    final client = ClerkAuthClient(
      config: _config,
      store: MemoryClerkSessionStore(),
      browser: _ScriptedBrowser((_) => '${_config.androidRedirectUri}?error=access_denied&state=forged'),
      httpClient: MockClient((_) async => _json({})),
    );
    await expectLater(client.signIn(), throwsA(_authError('state-mismatch')));
  });

  test('concurrent signIn calls share one browser flow', () async {
    var opened = 0;
    final browser = _FakeBrowser();
    final client = _signInClient(browser, (nonce) => _claims(nonce: nonce));
    final counting = ClerkAuthClient(
      config: _config,
      store: MemoryClerkSessionStore(),
      browser: _ScriptedBrowser((url) {
        opened += 1;
        browser.lastUrl = url;
        return '${_config.androidRedirectUri}?code=abc&state=${url.queryParameters['state']}';
      }),
      httpClient: MockClient((request) async {
        if (request.url.path == '/oauth/token') {
          return _json({
            'access_token': 'at',
            'id_token': _jwt(_claims(nonce: browser.lastUrl?.queryParameters['nonce'])),
          });
        }
        return _json({'sub': 'user_1'});
      }),
    );
    client.dispose();
    final sessions = await Future.wait([counting.signIn(), counting.signIn()]);
    expect(opened, 1);
    expect(sessions.first.subject, sessions.last.subject);
  });

  test('a sign-out during a refresh does not restore the session', () async {
    final store = MemoryClerkSessionStore();
    final tokenCalled = Completer<void>();
    final release = Completer<void>();
    final revoked = <String>[];
    await store.write(
      ClerkSession(
        subject: 'user_1',
        accessToken: 'old',
        accessTokenExpiresAt: DateTime.utc(2020),
        refreshToken: 'rt',
      ),
    );
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      browser: _FakeBrowser(),
      httpClient: MockClient((request) async {
        if (request.url.path == '/oauth/token') {
          tokenCalled.complete();
          await release.future;
          return _json({'access_token': 'new', 'refresh_token': 'rotated'});
        }
        revoked.add(Uri.splitQueryString(request.body)['token']!);
        return _json({});
      }),
    );

    final refresh = client.restore();
    await tokenCalled.future;
    await client.signOut();
    release.complete();
    await refresh;

    expect(client.session.value, isNull);
    expect(await store.read(), isNull);
    expect(revoked, containsAll(['rt', 'rotated']));
  });

  test('refuses a refreshed id_token for another user', () async {
    final store = MemoryClerkSessionStore();
    await store.write(
      ClerkSession(
        subject: 'user_1',
        accessToken: 'old',
        accessTokenExpiresAt: DateTime.utc(2020),
        refreshToken: 'rt',
      ),
    );
    final client = ClerkAuthClient(
      config: _config,
      store: store,
      browser: _FakeBrowser(),
      clock: () => DateTime.utc(2026),
      httpClient: MockClient(
        (_) async => _json({
          'access_token': 'new',
          'id_token': _jwt(_claims(sub: 'user_2')),
        }),
      ),
    );
    await client.restore();
    expect((await store.read())?.accessToken, 'old');
  });
}
