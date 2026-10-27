/// The texts of the storage errors, in the language the app picks. Free of
/// Flutter, like everything the web can use.
library;

/// The text of each storage error, one field per message: a [String] for a
/// fixed text, a function for one that carries data (a key, a bucket, a
/// detail). [fr] holds the texts the package has always shown, so an app
/// that does nothing keeps them; [en] holds English ones. An app can pass
/// its own values to `BlobStoreException.messageIn`.
class BlobStrings {
  const BlobStrings({
    required this.preconditionFailed,
    required this.accessDenied,
    required this.secretKeyRejected,
    required this.accessKeyUnknown,
    required this.bucketMissing,
    required this.folderNotWritable,
    required this.unreachable,
    required this.interrupted,
    required this.uploadIdMissing,
    required this.uploadAborted,
    required this.assemblyRefused,
    required this.objectChanged,
    required this.storageAnswered,
    required this.folderMissing,
    required this.folderUnreachable,
    required this.unspecifiedFailure,
    required this.transferCancelled,
    required this.invalidKey,
    required this.checksumMismatch,
  });

  /// The object changed since the caller last read it.
  final String preconditionFailed;

  /// Wrong keys or a missing right, with no more precise cause.
  final String accessDenied;

  /// The storage rejected the secret key.
  final String secretKeyRejected;

  /// The storage does not know the access key ID.
  final String accessKeyUnknown;

  /// The bucket does not exist. [bucket] is the bucket's name.
  final String Function(String bucket) bucketMissing;

  /// Writing into the synchronised folder was refused by the system.
  final String folderNotWritable;

  /// The storage cannot be reached over the network.
  final String unreachable;

  /// The exchange broke off. [detail] says what happened.
  final String Function(String detail) interrupted;

  /// The storage's answer to a multipart upload had no upload identifier.
  final String uploadIdMissing;

  /// The storage dropped an upload in progress.
  final String uploadAborted;

  /// The storage refused to assemble the parts of an upload.
  final String assemblyRefused;

  /// The object changed during a download; it is fetched again from zero.
  final String objectChanged;

  /// The storage answered with an unexpected status. [detail] is the status,
  /// with the error code when there is one.
  final String Function(String detail) storageAnswered;

  /// The synchronised folder is missing, as when its drive is not mounted.
  /// [detail] is its path.
  final String Function(String detail) folderMissing;

  /// The synchronised folder cannot be read. [detail] says why.
  final String Function(String detail) folderUnreachable;

  /// A transient failure with no detail to show.
  final String unspecifiedFailure;

  /// The transfer was cancelled by the app.
  final String transferCancelled;

  /// The key is not a valid relative path. [key] is the key as given.
  final String Function(String key) invalidKey;

  /// The downloaded content does not have the expected checksum. [key] is
  /// the object's key.
  final String Function(String key) checksumMismatch;

  /// The French texts, as the package has always written them.
  static const fr = BlobStrings(
    preconditionFailed: "L'objet a été modifié ailleurs entre-temps.",
    accessDenied: 'Accès refusé : vérifiez les clés et le bucket.',
    secretKeyRejected: 'Clé secrète refusée par le stockage.',
    accessKeyUnknown: 'Identifiant de clé inconnu du stockage.',
    bucketMissing: _frBucketMissing,
    folderNotWritable: 'Écriture refusée dans le dossier.',
    unreachable: 'Stockage injoignable.',
    interrupted: _frInterrupted,
    uploadIdMissing: 'Réponse S3 sans identifiant d’envoi.',
    uploadAborted: 'Envoi abandonné par le stockage.',
    assemblyRefused: 'Assemblage de l’envoi refusé.',
    objectChanged: 'Objet modifié, reprise à zéro.',
    storageAnswered: _frStorageAnswered,
    folderMissing: _frFolderMissing,
    folderUnreachable: _frFolderUnreachable,
    unspecifiedFailure: 'Échec du stockage.',
    transferCancelled: 'Transfert annulé.',
    invalidKey: _frInvalidKey,
    checksumMismatch: _frChecksumMismatch,
  );

  /// English texts.
  static const en = BlobStrings(
    preconditionFailed: 'The object was changed elsewhere in the meantime.',
    accessDenied: 'Access denied: check the keys and the bucket.',
    secretKeyRejected: 'The storage rejected the secret key.',
    accessKeyUnknown: 'The storage does not recognise this access key ID.',
    bucketMissing: _enBucketMissing,
    folderNotWritable: 'Writing into the folder was refused.',
    unreachable: 'The storage cannot be reached.',
    interrupted: _enInterrupted,
    uploadIdMissing: 'The storage answer had no upload identifier.',
    uploadAborted: 'The storage aborted the upload.',
    assemblyRefused: 'The storage refused to assemble the upload.',
    objectChanged: 'The object changed; the download starts again.',
    storageAnswered: _enStorageAnswered,
    folderMissing: _enFolderMissing,
    folderUnreachable: _enFolderUnreachable,
    unspecifiedFailure: 'The storage failed.',
    transferCancelled: 'Transfer cancelled.',
    invalidKey: _enInvalidKey,
    checksumMismatch: _enChecksumMismatch,
  );

  static String _frBucketMissing(String bucket) =>
      'Bucket « $bucket » introuvable.';
  static String _frInterrupted(String detail) =>
      'Échange interrompu : $detail';
  static String _frStorageAnswered(String detail) =>
      'Le stockage a répondu $detail.';
  static String _frFolderMissing(String detail) =>
      'Dossier « $detail » introuvable : le lecteur est-il monté ?';
  static String _frFolderUnreachable(String detail) =>
      'Dossier inaccessible : $detail.';
  static String _frInvalidKey(String key) =>
      'Clé de stockage invalide : « $key ».';
  static String _frChecksumMismatch(String key) =>
      'Contenu inattendu pour « $key » : empreinte différente.';

  static String _enBucketMissing(String bucket) =>
      'Bucket "$bucket" not found.';
  static String _enInterrupted(String detail) =>
      'The exchange with the storage was interrupted: $detail';
  static String _enStorageAnswered(String detail) =>
      'The storage answered $detail.';
  static String _enFolderMissing(String detail) =>
      'Folder "$detail" not found: is the drive mounted?';
  static String _enFolderUnreachable(String detail) =>
      'The folder cannot be read: $detail.';
  static String _enInvalidKey(String key) => 'Invalid storage key: "$key".';
  static String _enChecksumMismatch(String key) =>
      'Unexpected content for "$key": the checksum differs.';
}
