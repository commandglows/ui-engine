/// A Clerk sign-in, refresh or storage failure.
///
/// [code] is stable for the app to branch on: `not-configured`,
/// `unsupported-platform`, `canceled`, `state-mismatch`, `missing-code`,
/// `invalid_grant` (the session is gone: sign in again), `token-<status>`,
/// `userinfo-<status>`, `network`, or the OAuth `error` Clerk returned.
class ClerkAuthException implements Exception {
  const ClerkAuthException(this.code, this.detail);

  final String code;

  /// Never holds a token.
  final String detail;

  /// The stored session can no longer be used: the user must sign in again.
  bool get requiresSignIn => code == 'invalid_grant';

  bool get isCanceled => code == 'canceled';

  @override
  String toString() => 'ClerkAuthException($code): $detail';
}
