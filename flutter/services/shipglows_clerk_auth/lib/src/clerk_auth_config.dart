import 'package:flutter/foundation.dart';

/// One product's Clerk OAuth client.
///
/// [issuer] is the instance's Frontend API URL (`https://<slug>.clerk.accounts.dev`
/// in development, `https://clerk.<domain>` in production). The redirect URIs
/// below must be registered, exactly, on the Clerk OAuth application.
class ClerkAuthConfig {
  const ClerkAuthConfig({
    required this.issuer,
    required this.clientId,
    required this.androidScheme,
    required this.desktopPort,
    this.webRedirectPath,
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
  });

  /// Reads `CLERK_OIDC_ISSUER` and `CLERK_OIDC_CLIENT_ID` from the
  /// `--dart-define` values; the app gives its own scheme and port.
  factory ClerkAuthConfig.fromEnvironment({
    required String androidScheme,
    required int desktopPort,
    String? webRedirectPath,
  }) => ClerkAuthConfig(
    issuer: const String.fromEnvironment(issuerEnvironmentName),
    clientId: const String.fromEnvironment(clientIdEnvironmentName),
    androidScheme: androidScheme,
    desktopPort: desktopPort,
    webRedirectPath: webRedirectPath,
  );

  static const issuerEnvironmentName = 'CLERK_OIDC_ISSUER';
  static const clientIdEnvironmentName = 'CLERK_OIDC_CLIENT_ID';

  final String issuer;
  final String clientId;

  /// Private-use URI scheme, reverse-DNS and lowercase: usually the Android
  /// application id. A scheme cannot contain `_`; drop it when the id has one
  /// (`com.shipglows.app` for `com.contentflow.contentflow_app`).
  final String androidScheme;

  /// Loopback port for desktop, unique per app so two apps never collide.
  final int desktopPort;

  /// Web callback page, relative to the app origin (for example `/auth.html`).
  /// Opt-in: null keeps the web target without Clerk sign-in. The page must
  /// be registered as `<origin><webRedirectPath>` on the Clerk application.
  final String? webRedirectPath;
  final List<String> scopes;

  bool get isConfigured =>
      issuer.trim().startsWith('https://') && clientId.trim().isNotEmpty;

  /// Android and Windows today.
  static bool get supportsCurrentPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Whether this build can sign in: the native platforms above, or web when
  /// [webRedirectPath] is set. The other targets keep their own sign-in.
  bool get supportsPlatform =>
      supportsCurrentPlatform || (kIsWeb && webRedirectPath != null);

  String get androidRedirectUri => '$androidScheme://oauth/clerk';
  String get desktopRedirectUri => 'http://localhost:$desktopPort/callback';

  String get _base => issuer.trim().replaceFirst(RegExp(r'/+$'), '');
  Uri get authorizeEndpoint => Uri.parse('$_base/oauth/authorize');
  Uri get tokenEndpoint => Uri.parse('$_base/oauth/token');
  Uri get revokeEndpoint => Uri.parse('$_base/oauth/token/revoke');
  Uri get userInfoEndpoint => Uri.parse('$_base/oauth/userinfo');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get redirectUri {
    if (kIsWeb) {
      return '${Uri.base.origin}${webRedirectPath ?? ''}';
    }
    return _isAndroid ? androidRedirectUri : desktopRedirectUri;
  }

  /// What the browser helper waits for: the scheme on Android, the loopback
  /// origin on desktop. On web the helper ignores it (the callback page posts
  /// back to the app origin) but still requires a valid URL scheme, so the
  /// page's own scheme is given.
  String get callbackScheme {
    if (kIsWeb) {
      return Uri.base.scheme;
    }
    return _isAndroid ? androidScheme : 'http://localhost:$desktopPort';
  }
}
