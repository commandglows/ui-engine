import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

import 'blob_store_contract.dart';

/// The S3 run needs a bucket, given by `SHIPGLOWS_S3_ENDPOINT`,
/// `SHIPGLOWS_S3_BUCKET`, `SHIPGLOWS_S3_REGION`, `SHIPGLOWS_S3_KEY_ID` and
/// `SHIPGLOWS_S3_SECRET` (MinIO in Docker, or an R2 test bucket); it is
/// skipped without them.
void main() {
  group('MemoryBlobStore', () {
    runBlobStoreContract(() async => MemoryBlobStore());
  });

  group('FolderBlobStore', () {
    late Directory root;
    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('folder_store_');
    });
    tearDownAll(() => root.delete(recursive: true));
    runBlobStoreContract(() async => FolderBlobStore(root));

    test('an unmounted folder is reported, not created', () async {
      final gone = Directory('${root.path}/absent');
      await expectLater(
        FolderBlobStore(gone).putBytes('a', Uint8List(1)),
        throwsA(isA<BlobTransientFailure>()),
      );
      expect(gone.existsSync(), isFalse);
    });
  });

  final env = Platform.environment;
  final endpoint = env['SHIPGLOWS_S3_ENDPOINT'];
  group('S3BlobStore', () {
    S3BlobStore? store;
    tearDownAll(() => store?.close());
    runBlobStoreContract(
      () async => store ??= S3BlobStore((
        endpoint: Uri.parse(endpoint!),
        bucket: env['SHIPGLOWS_S3_BUCKET']!,
        region: env['SHIPGLOWS_S3_REGION'] ?? 'auto',
        credentials: (
          accessKeyId: env['SHIPGLOWS_S3_KEY_ID']!,
          secretAccessKey: env['SHIPGLOWS_S3_SECRET']!,
        ),
      )),
      prefix:
          'shipglows-storage-tests/${DateTime.now().millisecondsSinceEpoch}/',
      large: true,
    );
  }, skip: endpoint == null ? 'SHIPGLOWS_S3_ENDPOINT absent' : false);
}
