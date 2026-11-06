# shipglows_clerk_auth

Clerk sign-in for ShipGlows Flutter apps (Android, Windows, and web opt-in):
OIDC Authorization Code + PKCE in the system browser, no Clerk SDK.

## Usage

```dart
final clerk = ClerkAuthClient(
  config: ClerkAuthConfig.fromEnvironment(
    androidScheme: 'com.example.app',
    desktopPort: 47821,
    webRedirectPath: '/auth.html', // omit to keep web without Clerk sign-in
  ),
);
await clerk.restore();                  // once at launch
await clerk.signIn();                   // opens Clerk's hosted page (sign-up included)
final token = await clerk.accessToken(); // API access token, refreshed when needed
final idToken = await clerk.idToken();   // id_token for Convex (aud = client id), refreshed when needed
await clerk.signOut();
```

`idToken()` returns `null` when signed out and throws `ClerkAuthException`
(`id-token-unavailable`) rather than returning a stale token. Pass
`forceRefresh: true` to refresh it even when it is still fresh.

The browser keeps its own Clerk session, so `signIn()` can finish with the same
account without asking again. To switch accounts or reauthenticate, call
`signIn(forceLogin: true)`: it sends `prompt=login` and Clerk shows its sign-in
form. The default (`false`) keeps the previous behaviour.

Token and userinfo calls time out after 10 seconds and fail with `network`,
which keeps the stored session. An unreadable stored session (for example after
a Keystore reset) is deleted and reads as signed out; `signOut()` never throws
on storage errors.

## Platforms and setup

Android, Windows and web (opt-in). iOS, macOS and Linux report
`unsupported-platform`.

Register these redirects exactly on the Clerk OAuth application (public client,
PKCE required, scopes `openid profile email offline_access`):

- Android: `<androidScheme>://oauth/clerk`. The app also declares the scheme in
  `AndroidManifest.xml`, on the `CallbackActivity` of `flutter_web_auth_2`:

  ```xml
  <activity
      android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
      android:exported="true"
      android:taskAffinity="">
    <intent-filter android:label="flutter_web_auth_2">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="com.example.app" />
    </intent-filter>
  </activity>
  ```
- Windows: `http://localhost:<desktopPort>/callback`, with a port unique per app.

## Security notes

- The product backend verifies the id_token signature. The client only checks
  `iss`, `aud`, `sub` and `nonce`, to refuse a token that is not for this sign-in.
- `signOut()` revokes the refresh token when the network allows it. Offline, that
  token stays valid on the server although it no longer exists on the device.
- `signOut()` does not end the browser's Clerk session. On a shared computer, the
  next sign-in must use `forceLogin: true`.

## Web (opt-in)

Web needs `webRedirectPath`; without it `supportsPlatform` is false on web and
the app keeps its own sign-in there.

- Redirect URI: `<app origin><webRedirectPath>`, for example
  `http://localhost:3033/auth.html`, registered exactly on the Clerk OAuth
  application (also register `http://127.0.0.1:3033/auth.html` for local dev).
- The browser opens in a new tab; the callback page posts the callback URL back
  to the opener (or stores it in `localStorage` when there is no opener, which
  `flutter_web_auth_2` polls). The page must be served from the app origin.
- Session storage uses `flutter_secure_storage` on web (WebCrypto, stored in
  `localStorage`). It requires HTTPS or `localhost`. Clerk refresh tokens do not
  expire, and script running on the origin can reach this storage: a web app
  needs a strict Content-Security-Policy.
- The browser must allow CORS calls to the Clerk token and userinfo endpoints
  from the app origin.

Callback page, saved as `web/auth.html` in the app (the plugin's own template,
with the same behaviour):

```html
<!DOCTYPE html>
<title>Authentication complete</title>
<p>Authentication is complete. If this does not happen automatically, please close the window.</p>
<script>
  function postAuthenticationMessage() {
    const message = {
      'flutter-web-auth-2': window.location.href
    };

    if (window.opener) {
      window.opener.postMessage(message, window.location.origin);
      window.close();
    } else if (window.parent && window.parent !== window) {
      window.parent.postMessage(message, window.location.origin);
    } else {
      localStorage.setItem('flutter-web-auth-2', window.location.href);
      window.close();
    }
  }

  postAuthenticationMessage();
</script>
```
