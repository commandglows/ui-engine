/// A Convex call or upload failure.
///
/// [code] is stable for the app to branch on:
/// - `unauthenticated`: HTTP 401 or 403, or an auth error from the function.
///   The call is retried once after the token provider runs again.
/// - `convex_error`: the function threw a `ConvexError`; its payload is in
///   [data]. A payload with a string `code` (such as `no_access`) reports that
///   string as [code] instead.
/// - `function_error`: any other function failure.
/// - `network`: no connection, or the request timed out.
/// - `bad_response`: not the expected JSON, or an unexpected HTTP status.
class ConvexException implements Exception {
  const ConvexException(this.code, this.message, {this.data});

  final String code;

  /// Never holds a token.
  final String message;

  /// The `ConvexError` payload as plain JSON, or `null`.
  final Object? data;

  @override
  String toString() => 'ConvexException($code): $message';
}
