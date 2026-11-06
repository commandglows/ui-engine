import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

/// The behaviour every [BlobStore] shares, run against each implementation.
///
/// [create] returns a store whose keys under [prefix] start empty.
void runBlobStoreContract(
  Future<BlobStore> Function() create, {
  String prefix = 'contract/',
  bool large = false,
}) {
  late BlobStore store;
  late Directory scratch;

  setUp(() async {
    store = await create();
    scratch = await Directory.systemTemp.createTemp('blob_contract_');
  });

  tearDown(() async {
    await for (final info in store.list(prefix)) {
      await store.delete(info.key);
    }
    await scratch.delete(recursive: true);
  });

  Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

  test('put then get returns the same bytes and tag', () async {
    final put = await store.putBytes('${prefix}a/b.txt', bytesOf('bonjour'));
    final got = await store.getBytes('${prefix}a/b.txt');
    expect(utf8.decode(got!.bytes), 'bonjour');
    expect(got.info.bytes, 7);
    expect(got.info.etag, put.etag);
    expect((await store.head('${prefix}a/b.txt'))!.etag, put.etag);
  });

  test('a missing key reads as null and deletes quietly', () async {
    expect(await store.getBytes('${prefix}missing'), isNull);
    expect(await store.head('${prefix}missing'), isNull);
    expect(await store.download('${prefix}missing', File('${scratch.path}/x')),
        isNull);
    expect(File('${scratch.path}/x').existsSync(), isFalse);
    await store.delete('${prefix}missing');
  });

  test('ifAbsent refuses to overwrite', () async {
    await store.putBytes('${prefix}catalog.json', bytesOf('1'),
        condition: WriteCondition.ifAbsent);
    await expectLater(
      store.putBytes('${prefix}catalog.json', bytesOf('2'),
          condition: WriteCondition.ifAbsent),
      throwsA(isA<BlobPreconditionFailed>()),
    );
    expect(utf8.decode((await store.getBytes('${prefix}catalog.json'))!.bytes),
        '1');
  });

  test('ifMatch writes over the expected version only', () async {
    final first = await store.putBytes('${prefix}catalog.json', bytesOf('1'));
    final second = await store.putBytes('${prefix}catalog.json', bytesOf('2'),
        condition: WriteCondition.ifMatch(first.etag));
    await expectLater(
      store.putBytes('${prefix}catalog.json', bytesOf('3'),
          condition: WriteCondition.ifMatch(first.etag)),
      throwsA(isA<BlobPreconditionFailed>()),
    );
    expect(second.etag, isNot(first.etag));
    expect(utf8.decode((await store.getBytes('${prefix}catalog.json'))!.bytes),
        '2');
  });

  test('list returns keys under the prefix in order', () async {
    await store.putBytes('${prefix}files/b', bytesOf('b'));
    await store.putBytes('${prefix}files/a', bytesOf('aa'));
    await store.putBytes('${prefix}other', bytesOf('o'));
    final listed = await store.list('${prefix}files/').toList();
    expect(listed.map((info) => info.key),
        ['${prefix}files/a', '${prefix}files/b']);
    expect(listed.first.bytes, 2);
  });

  test('putFile and download round-trip a file', () async {
    final source = File('${scratch.path}/source.bin')
      ..writeAsBytesSync(List.generate(300000, (i) => i % 251));
    final put = await store.putFile('${prefix}files/source.bin', source);
    final target = File('${scratch.path}/out/copy.bin');
    final got = await store.download('${prefix}files/source.bin', target);
    expect(target.readAsBytesSync(), source.readAsBytesSync());
    expect(got!.bytes, 300000);
    expect(put.bytes, 300000);
  });

  test('download checks the expected SHA-256', () async {
    final bytes = bytesOf('bonjour');
    await store.putBytes('${prefix}files/checked.txt', bytes);
    final good = File('${scratch.path}/good.txt');
    expect(
      await store.download(
        '${prefix}files/checked.txt',
        good,
        expectedSha256: sha256.convert(bytes).toString(),
      ),
      isNotNull,
    );
    expect(good.readAsStringSync(), 'bonjour');
    final bad = File('${scratch.path}/bad.txt');
    await expectLater(
      store.download(
        '${prefix}files/checked.txt',
        bad,
        expectedSha256: sha256.convert(bytesOf('autre')).toString(),
      ),
      throwsA(isA<BlobChecksumMismatch>()),
    );
    expect(bad.existsSync(), isFalse);
  });

  if (large) {
    test('a file over the multipart threshold goes up whole', () async {
      final source = File('${scratch.path}/big.bin');
      final sink = source.openWrite();
      final chunk = Uint8List(1024 * 1024);
      for (var i = 0; i < 70; i++) {
        chunk.fillRange(0, chunk.length, i);
        sink.add(chunk);
      }
      await sink.close();
      await store.putFile('${prefix}files/big.bin', source);
      final target = File('${scratch.path}/big.out');
      final got = await store.download('${prefix}files/big.bin', target);
      expect(got!.bytes, 70 * 1024 * 1024);
      expect(target.lengthSync(), source.lengthSync());
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  test('putFile and download report progress up to the size', () async {
    final source = File('${scratch.path}/progress.bin')
      ..writeAsBytesSync(List.filled(200000, 7));
    final sent = <(int, int)>[];
    await store.putFile(
      '${prefix}files/progress.bin',
      source,
      control: TransferControl(onProgress: (done, total) {
        sent.add((done, total));
      }),
    );
    expect(sent.last, (200000, 200000));
    final received = <int>[];
    await store.download(
      '${prefix}files/progress.bin',
      File('${scratch.path}/progress.out'),
      control: TransferControl(onProgress: (done, _) => received.add(done)),
    );
    expect(received.last, 200000);
  });

  test('a cancelled transfer throws and stores nothing', () async {
    final control = TransferControl()..cancel();
    await expectLater(
      store.putBytes('${prefix}cancelled', bytesOf('x'), control: control),
      throwsA(isA<BlobTransferCancelled>()),
    );
    expect(await store.head('${prefix}cancelled'), isNull);
  });

  test('keys with .. or a leading slash are refused', () async {
    for (final key in ['../x', '/x', 'a//b', r'a\b', '']) {
      await expectLater(store.putBytes(key, bytesOf('x')),
          throwsA(isA<BlobInvalidKey>()));
    }
  });
}
