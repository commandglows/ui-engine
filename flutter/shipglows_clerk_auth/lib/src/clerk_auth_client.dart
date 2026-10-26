import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'clerk_auth_config.dart';
import 'clerk_auth_exception.dart';
import 'clerk_browser.dart';
import 'clerk_session.dart';
import 'clerk_session_store.dart';

/// Same margin as the access token: an id_token this close to `exp` is
/// refreshed before use.
const _idTokenMargin = Duration(minutes: 2);

/// Signs in with Clerk's hosted pages and keeps the session across launches.
///
/// Call [restore] once at launch, then read [session]. [accessToken] returns
/// a usable token, refreshing it first when it is about to expire. Signing
/// out revokes the refresh token and forgets the session on this device; the
/// browser keeps its own Clerk sign-in, so the next [signIn] may complete
/// without asking again.
class ClerkAuthClient {
  ClerkAuthClient({
    required this.config,
    ClerkSessionStore? store,
    ClerkBrowser browser = const SystemClerkBrowser(),
    http.Client? httpClient,
    DateTime Function()? clock,
  }) : _store = store ?? SecureClerkSessionStore(clientId: config.clientId),
       _browser = browser,
       _http = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final ClerkAuthConfig config;
  final ClerkSessionStore _store;
  final ClerkBrowser _browser;
  final http.Client _http;
  final DateTime Function() _clock;
  final _session = ValueNotifier<ClerkSession?>(null);
  Future<ClerkSession>? _refreshing;

  /// The current session, `null` when signed out.
  ValueListenable<ClerkSession?> get session => _session;

  /// Reads the stored session and refreshes its access token if needed.
  /// Offline, the stored session is kept as is; a revoked one is forgotten.
  Future<ClerkSession?> restore() async {
    final stored = await _store.read();
    _session.value = stored;
    if (stored == null || stored.isAccessTokenFresh(_clock())) {
      return stored;
    }
    try {
      return await _refresh(stored);
    } on ClerkAuthException catch (error) {
      if (error.requiresSignIn) {
        return null;
      }
      return stored;
    }
  }

  /// Opens Clerk's sign-in, then stores the new session.
  Future<ClerkSession> signIn() async {
    _ensureUsable();
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(24);
    final challenge = base64UrlEncode(
      sha256.convert(ascii.encode(verifier)).bytes,
    ).replaceAll('=', '');

    final callback = Uri.parse(
      await _browser.authenticate(
        url: config.authorizeEndpoint.replace(
          queryParameters: {
            'response_type': 'code',
            'client_id': config.clientId,
            'redirect_uri': config.redirectUri,
            'scope': config.scopes.join(' '),
            'state': state,
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
          },
        ),
        callbackScheme: config.callbackScheme,
      ),
    );
    final params = callback.queryParameters;
    final error = params['error'];
    if (error != null) {
      throw ClerkAuthException(
        error,
        params['error_description'] ?? 'Authorization refused.',
      );
    }
    if (params['state'] != state) {
      throw const ClerkAuthException('state-mismatch', 'Unexpected state.');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const ClerkAuthException('missing-code', 'No authorization code.');
    }

    final tokens = await _tokenRequest({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': config.redirectUri,
      'client_id': config.clientId,
      'code_verifier': verifier,
    });
    final accessToken = tokens['access_token'] as String;
    final userInfo = await _userInfo(accessToken);
    final session = ClerkSession(
      subject: userInfo['sub'] as String,
      email: userInfo['email'] as String?,
      name: userInfo['name'] as String?,
      accessToken: accessToken,
      accessTokenExpiresAt: _expiry(tokens),
      refreshToken: tokens['refresh_token'] as String?,
      idToken: tokens['id_token'] as String?,
    );
    await _store.write(session);
    _session.value = session;
    return session;
  }

  /// A usable access token for the product backend, or `null` when signed
  /// out. Throws [ClerkAuthException] when it cannot be refreshed.
  Future<String?> accessToken() async {
    final current = _session.value;
    if (current == null) {
      return null;
    }
    if (current.isAccessTokenFresh(_clock())) {
      return current.accessToken;
    }
    return (await _refresh(current)).accessToken;
  }

  /// A usable id_token for the product backend (Convex checks it), or `null`
  /// when signed out. Refreshes first when the stored id_token is missing or
  /// its `exp` falls within the freshness margin. A refresh that returns no
  /// id_token keeps the previous one only while it is still valid; otherwise
  /// this throws [ClerkAuthException] rather than sending a stale token.
  Future<String?> idToken() async {
    final current = _session.value;
    if (current == null) {
      return null;
    }
    final stored = current.idToken;
    if (stored != null && _isIdTokenFresh(stored, _clock())) {
      return stored;
    }
    final refreshed = await _refresh(current);
    final fresh = refreshed.idToken;
    if (fresh != null && _isIdTokenFresh(fresh, _clock())) {
      return fresh;
    }
    throw const ClerkAuthException(
      'id-token-unavailable',
      'No fresh id_token after refresh.',
    );
  }

  /// Revokes the refresh token (best effort) and forgets the session.
  Future<void> signOut() async {
    final current = _session.value ?? await _store.read();
    _session.value = null;
    await _store.clear();
    final refreshToken = current?.refreshToken;
    if (refreshToken == null) {
      return;
    }
    try {
      await _http.post(
        config.revokeEndpoint,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'token': refreshToken,
          'token_type_hint': 'refresh_token',
          'client_id': config.clientId,
        },
      );
    } on Exception {
      // Offline: the token stays valid server-side but no longer exists here.
    }
  }

  void dispose() => _session.dispose();

  /// One refresh at a time; concurrent callers share it.
  Future<ClerkSession> _refresh(ClerkSession current) {
    return _refreshing ??= _doRefresh(current).whenComplete(
      () => _refreshing = null,
    );
  }

  Future<ClerkSession> _doRefresh(ClerkSession current) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null) {
      await _forget();
      throw const ClerkAuthException('invalid_grant', 'No refresh token.');
    }
    try {
      final tokens = await _tokenRequest({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId,
      });
      final refreshed = current.copyWith(
        accessToken: tokens['access_token'] as String,
        accessTokenExpiresAt: _expiry(tokens),
        refreshToken: tokens['refresh_token'] as String?,
        idToken: tokens['id_token'] as String?,
      );
      await _store.write(refreshed);
      _session.value = refreshed;
      return refreshed;
    } on ClerkAuthException catch (error) {
      if (error.requiresSignIn) {
        await _forget();
      }
      rethrow;
    }
  }

  Future<void> _forget() async {
    _session.value = null;
    await _store.clear();
  }

  Future<Map<String, dynamic>> _tokenRequest(Map<String, String> body) async {
    final http.Response response;
    try {
      response = await _http.post(
        config.tokenEndpoint,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
    } on Exception catch (error) {
      throw ClerkAuthException('network', error.runtimeType.toString());
    }
    final json = _decode(response.body);
    if (response.statusCode != 200) {
      final error = json?['error'];
      throw ClerkAuthException(
        error is String ? error : 'token-${response.statusCode}',
        '${json?['error_description'] ?? 'Token request refused.'}',
      );
    }
    if (json == null || json['access_token'] is! String) {
      throw const ClerkAuthException('token-invalid', 'No access token.');
    }
    return json;
  }

  Future<Map<String, dynamic>> _userInfo(String accessToken) async {
    final http.Response response;
    try {
      response = await _http.get(
        config.userInfoEndpoint,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } on Exception catch (error) {
      throw ClerkAuthException('network', error.runtimeType.toString());
    }
    final json = _decode(response.body);
    if (response.statusCode != 200 || json == null || json['sub'] is! String) {
      throw ClerkAuthException(
        'userinfo-${response.statusCode}',
        '${json?['error_description'] ?? 'Profile unavailable.'}',
      );
    }
    return json;
  }

  DateTime _expiry(Map<String, dynamic> tokens) {
    final seconds = tokens['expires_in'];
    return _clock().toUtc().add(
      Duration(seconds: seconds is int ? seconds : 3600),
    );
  }

  void _ensureUsable() {
    if (!config.isConfigured) {
      throw const ClerkAuthException(
        'not-configured',
        'CLERK_OIDC_ISSUER / CLERK_OIDC_CLIENT_ID missing.',
      );
    }
    if (!ClerkAuthConfig.supportsCurrentPlatform) {
      throw const ClerkAuthException(
        'unsupported-platform',
        'Clerk native sign-in runs on Android and Windows.',
      );
    }
  }

  static bool _isIdTokenFresh(String jwt, DateTime now) {
    final expiresAt = _jwtExpiry(jwt);
    return expiresAt != null &&
        now.toUtc().add(_idTokenMargin).isBefore(expiresAt);
  }

  /// The `exp` claim of a JWT, or `null` when it cannot be read.
  static DateTime? _jwtExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      return null;
    }
    final payload = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(payload)));
      final exp = claims is Map ? claims['exp'] : null;
      if (exp is! num) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  static String _randomUrlSafe(int byteLength) {
    final random = math.Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
