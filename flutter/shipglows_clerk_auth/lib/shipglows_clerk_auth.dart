/// Clerk sign-in for ShipGlows Flutter apps (Android, Windows, and web when
/// the app sets a web callback page).
///
/// Each product has its own Clerk application and one public OAuth client
/// (PKCE required, no secret). The app opens Clerk's hosted sign-in in the
/// system browser — a Custom Tab on Android, the default browser with a
/// loopback listener on Windows, a new tab on web — so no beta Clerk Flutter
/// SDK is involved.
///
/// - [ClerkAuthConfig]: issuer, client id and the app's redirect URIs.
/// - [ClerkAuthClient]: `restore()` at launch, `signIn()`, `accessToken()`
///   (refreshed when needed) and `signOut()`; `session` for the UI.
/// - [ClerkSession]: the signed-in user and its tokens.
/// - [ClerkSessionStore]: where the session is kept; secure storage by
///   default, memory for tests.
/// - [ClerkAuthException]: every failure, with a stable `code`.
library;

export 'src/clerk_auth_client.dart';
export 'src/clerk_auth_config.dart';
export 'src/clerk_auth_exception.dart';
export 'src/clerk_browser.dart';
export 'src/clerk_session.dart';
export 'src/clerk_session_store.dart';
