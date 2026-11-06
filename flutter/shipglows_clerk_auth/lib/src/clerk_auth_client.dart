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

/// Bound on each Clerk token and userinfo call. A timeout is a `network`
/// failure, never `invalid_grant`, so the stored session is kept.
const _requestTimeout = Duration(seconds: 10);

/// Signs in with Clerk's hosted pages and keeps the session across launches.
///
/// Call [restore] once at launch, then read [session]. [accessToken] returns
/// a usable token, refreshing it first when it is about to expire. Signing
/// out revokes the refresh token and forgets the session on this device; the
/// browser keeps its own Clerk sign-in, so the next [signIn] may complete
/// without asking again (on a shared computer, use `forceLogin: true`).
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
       _ownsHttp = httpClient == null,
       _clock = clock ?? DateTime.now;

  final ClerkAuthConfig config;
  final ClerkSessionStore _store;
  final ClerkBrowser _browser;
  final http.Client _http;
  final bool _ownsHttp;
  final DateTime Function() _clock;
  final _session = ValueNotifier<ClerkSession?>(null);
  Future<ClerkSession>? _refreshing;
  Future<ClerkSession>? _signingIn;

  /// Bumped by [signOut], so a refresh already in flight cannot restore the
  /// session afterwards.
  int _signOutCount = 0;

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
    } on ClerkAuthException {
      // Offline keeps the stored session; a revoked one or a sign-out cleared it.
      return _session.value;
    }
  }

  /// Opens Clerk's sign-in, then stores the new session.
  ///
  /// The browser keeps its own Clerk session, so by default Clerk may finish
  /// silently with the same account. Pass [forceLogin] `true` to send
  /// `prompt=login`, which makes Clerk show its sign-in form even when the
  /// browser is already signed in. Use it to switch accounts or to
  /// reauthenticate before a sensitive action. A call made while another
  /// sign-in is open joins it instead of opening a second browser flow.
  Future<ClerkSession> signIn({bool forceLogin = false}) {
    return _signingIn ??= _doSignIn(forceLogin: forceLogin).whenComplete(
      () => _signingIn = null,
    );
  }

  Future<ClerkSession> _doSignIn({required bool forceLogin}) async {
    _ensureUsable();
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(24);
    final nonce = _randomUrlSafe(24);
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
            'nonce': nonce,
            if (forceLogin) 'prompt': 'login',
          },
        ),
        callbackScheme: config.callbackScheme,
      ),
    );
    final params = callback.queryParameters;
    // Checked first: an error from another flow must not be taken for this one.
    if (params['state'] != state) {
      throw const ClerkAuthException('state-mismatch', 'Unexpected state.');
    }
    final error = params['error'];
    if (error != null) {
      throw ClerkAuthException(
        error,
        params['error_description'] ?? 'Authorization refused.',
      );
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
    final subject = userInfo['sub'] as String;
    final idToken = tokens['id_token'] as String?;
    if (idToken != null) {
      _checkIdToken(idToken, subject: subject, nonce: nonce);
    }
    final session = ClerkSession(
      subject: subject,
      email: _stringOrNull(userInfo['email']),
      name: _stringOrNull(userInfo['name']),
      accessToken: accessToken,
      accessTokenExpiresAt: _expiry(tokens),
      refreshToken: tokens['refresh_token'] as String?,
      idToken: idToken,
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
  /// its `exp` falls within the freshness margin, or always with
  /// [forceRefresh]. A refresh that returns no id_token keeps the previous one
  /// only while it is still valid; otherwise this throws [ClerkAuthException]
  /// rather than sending a stale token.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final current = _session.value;
    if (current == null) {
      return null;
    }
    final stored = current.idToken;
    if (!forceRefresh &&
        stored != null &&
        _isIdTokenFresh(stored, _clock())) {
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
    _signOutCount += 1;
    final current = _session.value ?? await _store.read();
    _session.value = null;
    await _store.clear();
    final refreshToken = current?.refreshToken;
    if (refreshToken != null) {
      await _revoke(refreshToken);
    }
  }

  Future<void> _revoke(String refreshToken) async {
    try {
      await _http.post(
        config.revokeEndpoint,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'token': refreshToken,
          'token_type_hint': 'refresh_token',
          'client_id': config.clientId,
        },
      ).timeout(const Duration(seconds: 5));
    } on Exception {
      // Offline: the token stays valid server-side but no longer exists here.
    }
  }

  void dispose() {
    _session.dispose();
    if (_ownsHttp) {
      _http.close();
    }
  }

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
    final signOutCount = _signOutCount;
    try {
      final tokens = await _tokenRequest({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId,
      });
      if (signOutCount != _signOutCount) {
        // Signed out meanwhile: keep nothing, and revoke a rotated token.
        final rotated = tokens['refresh_token'];
        if (rotated is String) {
          await _revoke(rotated);
        }
        throw const ClerkAuthException('signed-out', 'Signed out during refresh.');
      }
      final idToken = tokens['id_token'];
      if (idToken is String) {
        _checkIdToken(idToken, subject: current.subject);
      }
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
      response = await _http
          .post(
            config.tokenEndpoint,
            headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ClerkAuthException('network', 'timeout');
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
      response = await _http
          .get(
            config.userInfoEndpoint,
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ClerkAuthException('network', 'timeout');
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
    if (!config.supportsPlatform) {
      throw const ClerkAuthException(
        'unsupported-platform',
        'Clerk sign-in is not available on this platform.',
      );
    }
  }

  /// Refuses an id_token that does not belong to this client, instance, user
  /// and sign-in. The signature is verified by the product backend, which never
  /// trusts this check. `nonce` is only known at sign-in, not on refresh.
  void _checkIdToken(String jwt, {required String subject, String? nonce}) {
    final claims = _jwtClaims(jwt);
    final audience = claims?['aud'];
    final audiences = audience is List ? audience : [audience];
    final issuer = claims?['iss'];
    final valid =
        claims != null &&
        issuer is String &&
        _withoutTrailingSlash(issuer) == _withoutTrailingSlash(config.issuer) &&
        audiences.contains(config.clientId) &&
        claims['sub'] == subject &&
        (nonce == null || claims['nonce'] == nonce);
    if (!valid) {
      throw const ClerkAuthException(
        'id-token-invalid',
        'The id_token does not match this sign-in.',
      );
    }
  }

  static String _withoutTrailingSlash(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static String? _stringOrNull(Object? value) =>
      value is String ? value : null;

  static bool _isIdTokenFresh(String jwt, DateTime now) {
    final expiresAt = _jwtExpiry(jwt);
    return expiresAt != null &&
        now.toUtc().add(_idTokenMargin).isBefore(expiresAt);
  }

  /// The `exp` claim of a JWT, or `null` when it cannot be read.
  static DateTime? _jwtExpiry(String jwt) {
    final exp = _jwtClaims(jwt)?['exp'];
    if (exp is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
  }

  /// The payload of a JWT, unverified, or `null` when it cannot be read.
  static Map<String, dynamic>? _jwtClaims(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      return null;
    }
    final payload = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(payload)));
      return claims is Map<String, dynamic> ? claims : null;
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
