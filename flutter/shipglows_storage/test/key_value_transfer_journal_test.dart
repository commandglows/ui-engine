@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/signed_upload.dart';

/// A string store in memory, standing in for `localStorage`.
class _MapStore implements KeyValueStore {
  final map = <String, String>{};
  bool failWrites = false;
  bool failReads = false;

  @override
  String? read(String key) {
    if (failReads) throw StateError('storage blocked');
    return map[key];
  }

  @override
  void write(String key, String value) {
    if (failWrites) throw StateError('QuotaExceededError');
    map[key] = value;
  }

  @override
  void remove(String key) => map.remove(key);
}

/// A backend and a bucket in memory, as in signed_upload_test.dart: one
/// part is 4 bytes and every PUT is recorded.
class _FakeBackend {
  final puts = <int>[];
  final stored = <int, Uint8List>{};

  /// Fails the next PUT of each part number listed, once.
  final failOnce = <int, Object>{};

  Future<Map<String, Object?>> call(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool slow = false,
  }) async {
    if (method == 'POST' && path == '/up') {
      final size = body!['byteSize']! as int;
      return {
        'uploadId': 'u1',
        'parts': [
          for (var start = 0, n = 1; start < size; start += 4, n++)
            {
              'partNumber': n,
              'sizeBytes': start + 4 > size ? size - start : 4,
            },
        ],
      };
    }
    final sign = RegExp(r'^/up/u1/parts/(\d+)/sign$').firstMatch(path);
    if (sign != null) {
      return {
        'partNumber': body!['partNumber'],
        'sizeBytes': body['sizeBytes'],
        'uploadUrl': 'https://bucket.test/u1/${sign.group(1)}',
        'headers': <String, String>{},
      };
    }
    if (path == '/up/u1/complete') {
      final parts = (body!['parts']! as List).cast<Map<String, Object?>>();
      final whole = BytesBuilder();
      for (final part in parts) {
        whole.add(stored[part['partNumber']]!);
      }
      return {'id': 'asset-1', 'bytes': whole.length};
    }
    return {};
  }

  Future<String> put(
    SignedPartTarget target,
    Uint8List bytes, {
    required void Function(int sent) onSent,
  }) async {
    final number = int.parse(target.url.pathSegments.last);
    puts.add(number);
    final failure = failOnce.remove(number);
    if (failure != null) throw failure;
    stored[number] = bytes;
    onSent(bytes.length);
    return '"etag-$number"';
  }
}

void main() {
  Map<String, Object?> note(String tag) => {
        'parts': {
          '1': {'etag': '"$tag"', 'checksumSha256': 'c', 'bytes': 4},
        },
      };

  group('KeyValueTransferJournal', () {
    test('write, read and delete round trip', () async {
      final store = _MapStore();
      final journal = KeyValueTransferJournal(store);
      expect(await journal.read('abc123'), isNull);

      await journal.write('abc123', note('a'));
      expect(await journal.read('abc123'), note('a'));
      // A new journal over the same store reads it back: a reload.
      expect(
        await KeyValueTransferJournal(store).read('abc123'),
        note('a'),
      );

      await journal.delete('abc123');
      expect(await journal.read('abc123'), isNull);
      // Deleting a missing note succeeds.
      await journal.delete('abc123');
    });

    test('keys are the prefix and the id, and prefixes are isolated', () async {
      final store = _MapStore()..map['unrelated'] = 'keep me';
      final defaults = KeyValueTransferJournal(store);
      final others = KeyValueTransferJournal(store, prefix: 'other.');

      await defaults.write('abc123', note('a'));
      expect(store.map.keys, contains('shipglows.transfer.abc123'));

      expect(await others.read('abc123'), isNull);
      await others.write('abc123', note('b'));
      expect(await defaults.read('abc123'), note('a'));
      expect(await others.read('abc123'), note('b'));

      await others.delete('abc123');
      expect(await defaults.read('abc123'), note('a'));
      expect(store.map['unrelated'], 'keep me');
    });

    test('ids with anything but letters and digits are rejected', () async {
      final store = _MapStore();
      final journal = KeyValueTransferJournal(store);
      for (final id in ['', 'a-b', 'a/b', '../x', 'a.b', 'a b']) {
        await expectLater(journal.read(id), throwsArgumentError, reason: id);
        await expectLater(
          journal.write(id, note('x')),
          throwsArgumentError,
          reason: id,
        );
        await expectLater(journal.delete(id), throwsArgumentError, reason: id);
      }
      expect(store.map, isEmpty);
    });

    test('a corrupt value reads as null and is removed', () async {
      final store = _MapStore()
        ..map['shipglows.transfer.abc123'] = '{"parts": ';
      final journal = KeyValueTransferJournal(store);
      expect(await journal.read('abc123'), isNull);
      expect(store.map.containsKey('shipglows.transfer.abc123'), isFalse);
    });

    test('a value that is not a JSON object reads as null', () async {
      final store = _MapStore()..map['shipglows.transfer.abc123'] = '[1, 2]';
      expect(await KeyValueTransferJournal(store).read('abc123'), isNull);
      expect(store.map, isEmpty);
    });

    test('a throwing write does not throw and stores nothing', () async {
      final store = _MapStore()..failWrites = true;
      final journal = KeyValueTransferJournal(store);
      await expectLater(journal.write('abc123', note('a')), completes);
      expect(store.map, isEmpty);
      expect(await journal.read('abc123'), isNull);
    });

    test('a blocked store reads as nothing and deletes quietly', () async {
      final store = _MapStore()..failReads = true;
      final journal = KeyValueTransferJournal(store);
      expect(await journal.read('abc123'), isNull);
      await expectLater(journal.delete('abc123'), completes);
    });
  });

  test('BrowserTransferJournal refuses to start off the web', () {
    expect(
      () => BrowserTransferJournal(),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('use FileTransferJournal'),
        ),
      ),
    );
  });

  test('a reload resumes the upload with only the missing parts', () async {
    final backend = _FakeBackend();
    final store = _MapStore();
    final bytes = Uint8List.fromList(List.generate(10, (i) => i));

    SignedUploadClient clientOver(KeyValueStore store) => SignedUploadClient(
          call: backend.call,
          put: backend.put,
          retry: RetryPolicy.none,
          journal: KeyValueTransferJournal(store),
        );

    Future<Map<String, Object?>> upload(SignedUploadClient client) =>
        client.upload(
          basePath: '/up',
          clientKey: 'key-1',
          fileName: 'clip.mp4',
          mimeType: 'video/mp4',
          byteSize: bytes.length,
          openRead: () => Stream.value(bytes),
        );

    // Part 3 fails before the page is reloaded; parts 1 and 2 are stored.
    backend.failOnce[3] = const BlobTransientFailure('réseau');
    await expectLater(
      upload(clientOver(store)),
      throwsA(isA<BlobTransientFailure>()),
    );
    expect(backend.puts, [1, 2, 3]);

    // The reload: a new client and a new journal over the same storage.
    backend.puts.clear();
    expect(
      await upload(clientOver(store)),
      {'id': 'asset-1', 'bytes': 10},
    );
    expect(backend.puts, [3]);
  });

  test('a store that cannot keep notes still completes the upload', () async {
    final backend = _FakeBackend();
    final store = _MapStore()..failWrites = true;
    final client = SignedUploadClient(
      call: backend.call,
      put: backend.put,
      retry: RetryPolicy.none,
      journal: KeyValueTransferJournal(store),
    );

    final result = await client.upload(
      basePath: '/up',
      clientKey: 'key-1',
      fileName: 'clip.mp4',
      mimeType: 'video/mp4',
      byteSize: 10,
      openRead: () => Stream.value(Uint8List(10)),
    );
    expect(result, {'id': 'asset-1', 'bytes': 10});
    expect(backend.puts, [1, 2, 3]);
  });
}
