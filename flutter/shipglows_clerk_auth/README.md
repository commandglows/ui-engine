# shipglows_clerk_auth

Clerk sign-in for native ShipGlows Flutter apps (Android, Windows): OIDC
Authorization Code + PKCE in the system browser, no Clerk SDK.

## Usage

```dart
final clerk = ClerkAuthClient(
  config: ClerkAuthConfig.fromEnvironment(
    androidScheme: 'com.example.app',
    desktopPort: 47821,
  ),
);
await clerk.restore();                  // once at launch
await clerk.signIn();                   // opens Clerk's hosted page (sign-up included)
final token = await clerk.accessToken(); // API access token, refreshed when needed
final idToken = await clerk.idToken();   // id_token for Convex (aud = client id), refreshed when needed
await clerk.signOut();
```

`idToken()` returns `null` when signed out and throws `ClerkAuthException`
(`id-token-unavailable`) rather than returning a stale token.
