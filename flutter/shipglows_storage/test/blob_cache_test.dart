import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

void main() {
  late Directory directory;
  late MemoryBlobStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('blob_cache_');
    store = MemoryBlobStore();
  });

  tearDown(() => directory.delete(recursive: true));

  Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

  test('fetches once, then serves the local copy', () async {
    await store.putBytes('songs/a.mp3', bytesOf('aaaa'));
    final cache = BlobCache(directory: directory, store: store, maxBytes: 100);
    expect(cache.peek('songs/a.mp3'), isNull);
    final first = await cache.fetch('songs/a.mp3');
    expect(first!.readAsStringSync(), 'aaaa');
    await store.delete('songs/a.mp3');
    final second = await cache.fetch('songs/a.mp3');
    expect(second!.readAsStringSync(), 'aaaa');
    expect(cache.peek('songs/a.mp3'), isNotNull);
  });

  test('a missing object fetches as null', () async {
    final cache = BlobCache(directory: directory, store: store, maxBytes: 100);
    expect(await cache.fetch('none.mp3'), isNull);
  });

  test('drops the least recently used files above the size', () async {
    for (final name in ['a', 'b', 'c']) {
      await store.putBytes('$name.mp3', bytesOf('1234'));
    }
    final cache = BlobCache(directory: directory, store: store, maxBytes: 10);
    await cache.fetch('a.mp3');
    await cache.fetch('b.mp3');
    // a was used before b.
    cache
        .peek('a.mp3')!
        .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
    await cache.fetch('c.mp3');
    expect(cache.peek('a.mp3'), isNull);
    expect(cache.peek('b.mp3'), isNotNull);
    expect(cache.peek('c.mp3'), isNotNull);
  });

  test('keeps the file just fetched even when it alone is too big', () async {
    await store.putBytes('big.mp3', bytesOf('0123456789abcdef'));
    final cache = BlobCache(directory: directory, store: store, maxBytes: 4);
    expect(await cache.fetch('big.mp3'), isNotNull);
    expect(cache.peek('big.mp3'), isNotNull);
  });

  test('a wrong checksum caches nothing', () async {
    await store.putBytes('a.mp3', bytesOf('aaaa'));
    final cache = BlobCache(directory: directory, store: store, maxBytes: 100);
    await expectLater(
      cache.fetch(
        'a.mp3',
        expectedSha256: sha256.convert(bytesOf('bbbb')).toString(),
      ),
      throwsA(isA<BlobChecksumMismatch>()),
    );
    expect(cache.peek('a.mp3'), isNull);
    final good = await cache.fetch(
      'a.mp3',
      expectedSha256: sha256.convert(bytesOf('aaaa')).toString(),
    );
    expect(good, isNotNull);
  });
}
