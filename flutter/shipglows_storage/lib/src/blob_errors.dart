/// Why a storage call failed. Free of `dart:io`, like everything the web
/// can use.
library;

/// Why a store call failed, with a French message for the user.
sealed class BlobStoreException implements Exception {
  const BlobStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The `WriteCondition` did not hold: someone else wrote the object first.
final class BlobPreconditionFailed extends BlobStoreException {
  const BlobPreconditionFailed()
      : super("L'objet a été modifié ailleurs entre-temps.");
}

/// The credentials are wrong or lack a right; retrying will not help.
final class BlobAccessDenied extends BlobStoreException {
  const BlobAccessDenied([
    super.message = 'Accès refusé : vérifiez les clés et le bucket.',
  ]);
}

/// The place could not be reached or answered oddly; retrying may help.
final class BlobTransientFailure extends BlobStoreException {
  const BlobTransientFailure(super.message, {this.cause});

  /// The error underneath, such as the HTTP client's, for an app that maps
  /// it its own way once retries are spent.
  final Object? cause;
}

/// The key is not a valid relative path.
final class BlobInvalidKey extends BlobStoreException {
  BlobInvalidKey(String key) : super('Clé de stockage invalide : « $key ».');
}

/// What was downloaded does not have the expected SHA-256: the object is
/// not the one asked for, or it was damaged. The target was left untouched;
/// sending again would fetch the same bytes, so it is not retried.
final class BlobChecksumMismatch extends BlobStoreException {
  BlobChecksumMismatch(String key)
      : super('Contenu inattendu pour « $key » : empreinte différente.');
}

/// The transfer was stopped through `TransferControl.cancel`.
final class BlobTransferCancelled extends BlobStoreException {
  const BlobTransferCancelled() : super('Transfert annulé.');
}
