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
            'id_token': 'it',
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
}
