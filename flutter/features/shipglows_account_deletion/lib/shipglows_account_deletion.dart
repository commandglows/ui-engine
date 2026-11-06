/// Shared account deletion for ShipGlows Flutter apps. The app provides the
/// call that erases its data; the package handles the rest.
///
/// - [ShipglowsDeleteAccountButton]: button, confirmation and error message.
/// - [runAccountDeletion]: the sequence without a widget.
/// - [AccountDeletionAuth]: the session the sequence works on.
/// - [ShipglowsAccountDeletionStrings]: the texts, in French or English.
library;

export 'src/account_deletion_flow.dart';
export 'src/delete_account_button.dart';
export 'src/strings.dart';
