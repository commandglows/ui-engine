import 'package:flutter/widgets.dart';

import 'account_deletion_flow.dart';

/// Texts of the account deletion. The app picks the language.
@immutable
class ShipglowsAccountDeletionStrings {
  const ShipglowsAccountDeletionStrings({
    required this.button,
    required this.title,
    required this.intro,
    required this.paidAccess,
    required this.confirm,
    required this.cancel,
    required this.deleted,
    required this.notSignedIn,
    required this.otherAccount,
    required this.reconnection,
    required this.server,
  });

  static const fr = ShipglowsAccountDeletionStrings(
    button: 'Supprimer mon compte',
    title: 'Supprimer ton compte ?',
    intro:
        'C’est définitif. Tu devras te reconnecter pour confirmer. Seront '
        'effacés :',
    paidAccess:
        'Un accès payé prend fin avec le compte. Nous gardons seulement la '
        'preuve de cet achat. Tes comptes sur nos autres produits ne changent '
        'pas.',
    confirm: 'Supprimer définitivement',
    cancel: 'Annuler',
    deleted: 'Ton compte a été supprimé.',
    notSignedIn: 'Aucun compte connecté à supprimer.',
    otherAccount:
        'Ce n’est pas le compte à supprimer. Rien n’a été supprimé : '
        'reconnecte-toi avec le bon compte.',
    reconnection: 'La reconnexion a échoué. Rien n’a été supprimé.',
    server:
        'La suppression n’a pas abouti. Vérifie ta connexion et réessaie. Si '
        'cela continue, écris-nous.',
  );

  static const en = ShipglowsAccountDeletionStrings(
    button: 'Delete my account',
    title: 'Delete your account?',
    intro:
        'This is permanent. You will sign in again to confirm. This will be '
        'erased:',
    paidAccess:
        'Paid access ends with the account. We keep only the proof of that '
        'purchase. Your accounts on our other products do not change.',
    confirm: 'Delete permanently',
    cancel: 'Cancel',
    deleted: 'Your account has been deleted.',
    notSignedIn: 'No signed-in account to delete.',
    otherAccount:
        'That is not the account to delete. Nothing was deleted: sign in with '
        'the right account.',
    reconnection: 'Signing in again failed. Nothing was deleted.',
    server:
        'The deletion did not finish. Check your connection and try again. If '
        'it keeps failing, write to us.',
  );

  final String button;
  final String title;
  final String intro;
  final String paidAccess;
  final String confirm;
  final String cancel;
  final String deleted;
  final String notSignedIn;
  final String otherAccount;
  final String reconnection;
  final String server;

  /// The message for [kind].
  String failure(AccountDeletionFailureKind kind) => switch (kind) {
    AccountDeletionFailureKind.notSignedIn => notSignedIn,
    AccountDeletionFailureKind.otherAccount => otherAccount,
    AccountDeletionFailureKind.reconnection => reconnection,
    AccountDeletionFailureKind.server => server,
  };
}
