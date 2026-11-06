import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

void main() {
  group('French texts stay as they were', () {
    final cases = <(BlobStoreException, String)>[
      (
        const BlobPreconditionFailed(),
        "L'objet a été modifié ailleurs entre-temps.",
      ),
      (const BlobAccessDenied(), 'Accès refusé : vérifiez les clés et le bucket.'),
      (
        const BlobAccessDenied(BlobAccessReason.secretKeyRejected),
        'Clé secrète refusée par le stockage.',
      ),
      (
        const BlobAccessDenied(BlobAccessReason.accessKeyUnknown),
        'Identifiant de clé inconnu du stockage.',
      ),
      (
        const BlobAccessDenied(BlobAccessReason.bucketMissing, 'photos'),
        'Bucket « photos » introuvable.',
      ),
      (
        const BlobAccessDenied(BlobAccessReason.folderNotWritable),
        'Écriture refusée dans le dossier.',
      ),
      (
        const BlobTransientFailure.because(BlobTransientReason.unreachable),
        'Stockage injoignable.',
      ),
      (
        const BlobTransientFailure.because(
          BlobTransientReason.interrupted,
          detail: 'SocketException: reset',
        ),
        'Échange interrompu : SocketException: reset',
      ),
      (
        const BlobTransientFailure.because(BlobTransientReason.uploadIdMissing),
        'Réponse S3 sans identifiant d’envoi.',
      ),
      (
        const BlobTransientFailure.because(BlobTransientReason.uploadAborted),
        'Envoi abandonné par le stockage.',
      ),
      (
        const BlobTransientFailure.because(BlobTransientReason.assemblyRefused),
        'Assemblage de l’envoi refusé.',
      ),
      (
        const BlobTransientFailure.because(BlobTransientReason.objectChanged),
        'Objet modifié, reprise à zéro.',
      ),
      (
        const BlobTransientFailure.because(
          BlobTransientReason.storageAnswered,
          detail: '500 (InternalError)',
        ),
        'Le stockage a répondu 500 (InternalError).',
      ),
      (
        BlobTransientFailure.because(
          BlobTransientReason.folderMissing,
          detail: '/mnt/sync',
        ),
        'Dossier « /mnt/sync » introuvable : le lecteur est-il monté ?',
      ),
      (
        const BlobTransientFailure.because(
          BlobTransientReason.folderUnreachable,
          detail: 'Access denied',
        ),
        'Dossier inaccessible : Access denied.',
      ),
      (const BlobTransientFailure('réseau'), 'réseau'),
      (const BlobInvalidKey('../x'), 'Clé de stockage invalide : « ../x ».'),
      (
        const BlobChecksumMismatch('files/a.mp3'),
        'Contenu inattendu pour « files/a.mp3 » : empreinte différente.',
      ),
      (const BlobTransferCancelled(), 'Transfert annulé.'),
    ];

    for (final (exception, text) in cases) {
      test(text, () {
        expect(exception.message, text);
        expect(exception.toString(), text);
        expect(exception.messageIn(BlobStrings.fr), text);
      });
    }
  });

  test('English texts come from BlobStrings.en', () {
    expect(
      const BlobPreconditionFailed().messageIn(BlobStrings.en),
      'The object was changed elsewhere in the meantime.',
    );
    expect(
      const BlobAccessDenied(BlobAccessReason.bucketMissing, 'photos')
          .messageIn(BlobStrings.en),
      'Bucket "photos" not found.',
    );
    expect(
      const BlobTransientFailure.because(BlobTransientReason.unreachable)
          .messageIn(BlobStrings.en),
      'The storage cannot be reached.',
    );
    expect(
      const BlobTransientFailure.because(
        BlobTransientReason.interrupted,
        detail: 'reset',
      ).messageIn(BlobStrings.en),
      'The exchange with the storage was interrupted: reset',
    );
    expect(
      const BlobInvalidKey('../x').messageIn(BlobStrings.en),
      'Invalid storage key: "../x".',
    );
    expect(
      const BlobTransferCancelled().messageIn(BlobStrings.en),
      'Transfer cancelled.',
    );
  });

  test('free text is shown as given, whatever the language', () {
    const failure = BlobTransientFailure('Catalog busy, retry later.');
    expect(failure.messageIn(BlobStrings.en), 'Catalog busy, retry later.');
    expect(failure.reason, BlobTransientReason.other);
  });

  test('a transient failure without detail uses the generic text', () {
    const failure = BlobTransientFailure.because(BlobTransientReason.other);
    expect(failure.message, 'Échec du stockage.');
    expect(failure.messageIn(BlobStrings.en), 'The storage failed.');
  });

  test('a custom BlobStrings replaces every text', () {
    final custom = BlobStrings(
      preconditionFailed: 'changed',
      accessDenied: 'denied',
      secretKeyRejected: 'secret',
      accessKeyUnknown: 'key',
      bucketMissing: (bucket) => 'no bucket $bucket',
      folderNotWritable: 'read only',
      unreachable: 'offline',
      interrupted: (detail) => 'cut: $detail',
      uploadIdMissing: 'no id',
      uploadAborted: 'aborted',
      assemblyRefused: 'refused',
      objectChanged: 'moved',
      storageAnswered: (detail) => 'answer $detail',
      folderMissing: (detail) => 'missing $detail',
      folderUnreachable: (detail) => 'unreachable $detail',
      unspecifiedFailure: 'failed',
      transferCancelled: 'stopped',
      invalidKey: (key) => 'bad key $key',
      checksumMismatch: (key) => 'bad sum $key',
    );

    expect(const BlobPreconditionFailed().messageIn(custom), 'changed');
    expect(
      const BlobAccessDenied(BlobAccessReason.bucketMissing, 'b').messageIn(custom),
      'no bucket b',
    );
    expect(
      const BlobTransientFailure.because(
        BlobTransientReason.storageAnswered,
        detail: '503',
      ).messageIn(custom),
      'answer 503',
    );
    expect(
      const BlobTransientFailure.because(BlobTransientReason.other)
          .messageIn(custom),
      'failed',
    );
    expect(const BlobInvalidKey('k').messageIn(custom), 'bad key k');
    expect(const BlobTransferCancelled().messageIn(custom), 'stopped');
  });

  test('cause is kept on a transient failure', () {
    final cause = StateError('boom');
    final failure = BlobTransientFailure('x', cause: cause);
    expect(failure.cause, same(cause));
  });
}
