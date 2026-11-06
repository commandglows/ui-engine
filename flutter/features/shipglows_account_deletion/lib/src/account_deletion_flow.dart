import 'package:shipglows_clerk_auth/shipglows_clerk_auth.dart';

/// Why [runAccountDeletion] stopped. Nothing is deleted before [server].
enum AccountDeletionFailureKind {
  notSignedIn,
  otherAccount,
  reconnection,
  server,
}

/// A failure of [runAccountDeletion]; [cause] is kept for the app's logs.
class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.kind, [this.cause]);

  final AccountDeletionFailureKind kind;
  final Object? cause;

  @override
  String toString() => 'AccountDeletionFailure($kind)';
}

/// How [runAccountDeletion] ended, when it did not fail.
enum AccountDeletionOutcome { deleted, canceled }

/// The session the deletion works on.
class AccountDeletionAuth {
  const AccountDeletionAuth({
    required this.currentSubject,
    required this.reauthenticate,
    required this.signOut,
  });

  /// Signs in through Clerk's hosted page again, without `prompt=login` (see the
  /// README). A canceled sign-in cancels the deletion.
  factory AccountDeletionAuth.clerk(ClerkAuthClient client) =>
      AccountDeletionAuth(
        currentSubject: () => client.session.value?.subject,
        reauthenticate: () async {
          try {
            return (await client.signIn()).subject;
          } on ClerkAuthException catch (error) {
            if (error.isCanceled) return null;
            rethrow;
          }
        },
        signOut: client.signOut,
      );

  /// The signed-in user's Clerk id, or `null`.
  final String? Function() currentSubject;

  /// Asks the user to sign in again and returns the account that came back, or
  /// `null` when they canceled.
  final Future<String?> Function() reauthenticate;

  final Future<void> Function() signOut;
}

/// Reconnects the user, erases the account on the server, then signs out.
///
/// Throws [AccountDeletionFailure]. A failed sign-out after the deletion is not
/// a failure: the account no longer exists.
Future<AccountDeletionOutcome> runAccountDeletion({
  required AccountDeletionAuth auth,
  required Future<void> Function() deleteOnServer,
}) async {
  final subject = auth.currentSubject();
  if (subject == null) {
    throw const AccountDeletionFailure(AccountDeletionFailureKind.notSignedIn);
  }
  final String? reconnected;
  try {
    reconnected = await auth.reauthenticate();
  } on Object catch (error) {
    throw AccountDeletionFailure(
      AccountDeletionFailureKind.reconnection,
      error,
    );
  }
  if (reconnected == null) return AccountDeletionOutcome.canceled;
  if (reconnected != subject) {
    throw const AccountDeletionFailure(AccountDeletionFailureKind.otherAccount);
  }
  try {
    await deleteOnServer();
  } on Object catch (error) {
    throw AccountDeletionFailure(AccountDeletionFailureKind.server, error);
  }
  try {
    await auth.signOut();
  } on Object {
    // The account is gone; the next token refresh drops the local session.
  }
  return AccountDeletionOutcome.deleted;
}
