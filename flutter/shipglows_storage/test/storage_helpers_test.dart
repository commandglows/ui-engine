import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

void main() {
  test('endpoints must be https, except on this computer', () {
    expect(parseS3Endpoint('https://a.r2.cloudflarestorage.com').host,
        'a.r2.cloudflarestorage.com');
    expect(parseS3Endpoint('http://localhost:9000').port, 9000);
    expect(() => parseS3Endpoint('http://example.com'), throwsFormatException);
    expect(() => parseS3Endpoint('ftp://x'), throwsFormatException);
  });

  test('the connection test writes, reads and removes a probe', () async {
    final blobs = MemoryBlobStore();
    expect(await testBlobStore(blobs), isNull);
    expect(await blobs.list('').toList(), isEmpty);
  });
}
