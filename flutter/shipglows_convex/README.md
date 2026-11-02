# shipglows_convex

Small Convex HTTP client for the ShipGlows Flutter apps (Android, Windows, web).
Queries, mutations, actions and file uploads over the deployment's HTTP API,
with a bearer token. It replaces Firestore where an app uses Convex. No Convex
SDK, no code generation, no Firebase.

## Usage

Token from `shipglows_clerk_auth`. The deployment's auth config must accept
the same Clerk issuer and token audience. For an OIDC client audience, use
`clerk.idToken`; session access tokens require their own matching server config.

```dart
final clerk = ClerkAuthClient(
  config: ClerkAuthConfig.fromEnvironment(
    androidScheme: 'com.example.app',
    desktopPort: 47821,
  ),
);
await clerk.restore();

final convex = ConvexHttpClient(
  deploymentUrl: Uri.parse('https://<deployment>.convex.cloud'),
  token: clerk.idToken, // read before each call, refreshed when needed
);

final notes = await convex.query('notes:list', {'limit': 20});
await convex.mutation('notes:create', {'title': 'Ship it'});

try {
  await convex.mutation('notes:remove', {'id': 'n_1'});
} on ConvexException catch (error) {
  if (error.code == 'no_access') {
    // An app code thrown by the function as a ConvexError.
  }
}

final storageId = await convex.uploadBytes(
  uploadUrlPath: 'files:generateUploadUrl',
  bytes: pngBytes,
  contentType: 'image/png',
);
```

Function names are `module:function`; the ones above are examples.
Timestamps: `convexMillisToDateTime(value)` and `dateTimeToConvexMillis(dt)`.

## Error codes

| `code` | Meaning |
| --- | --- |
| `unauthenticated` | HTTP 401/403, or an auth error from the function. Retried once after `token` runs again. |
| `convex_error` | The function threw a `ConvexError`; its payload is in `data`. |
| app code | A `ConvexError` payload with a string `code` (such as `no_access`) reports that code. |
| `function_error` | Any other function failure; `message` is Convex's. |
| `network` | No connection, or the request timed out (30 s by default, `timeout:`). |
| `bad_response` | Not the expected JSON or HTTP status, or no upload URL or storage id. |

## Not supported

- Realtime subscriptions (no `onUpdate`).
- Pagination cursors beyond plain args: pass a cursor as a string arg.
- `int` beyond 2^53, `Uint8List` and `DateTime` args, `$`-prefixed keys
  (see the dartdoc on `ConvexHttpClient`).
