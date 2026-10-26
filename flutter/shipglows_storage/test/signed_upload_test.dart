import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/signed_upload.dart';

/// A backend and a bucket in memory speaking the signed upload protocol.
class _FakeBackend {
  final int partBytes = 4;
  final calls = <String>[];
  final puts = <int>[];
  final stored = <int, Uint8List>{};
  Map<String, Object?>? finished;

  /// Fails the next PUT of each part number listed, once, with [failure].
  final failOnce = <int, Object>{};

  /// Answers the next sign call with this map instead.
  Map<String, Object?>? signAnswer;

  Future<Map<String, Object?>> call(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool slow = false,
  }) async {
    calls.add('$method $path');
    if (method == 'POST' && path == '/up') {
      if (finished != null) return {'result': finished};
      final size = body!['byteSize']! as int;
      return {
        'uploadId': 'u1',
        'parts': [
          for (var start = 0, n = 1; start < size; start += partBytes, n++)
            {
              'partNumber': n,
              'sizeBytes': start + partBytes > size ? size - start : partBytes,
            },
        ],
      };
    }
    final sign = RegExp(r'^/up/u1/parts/(\d+)/sign$').firstMatch(path);
    if (sign != null) {
      final answer = signAnswer;
      if (answer != null) {
        signAnswer = null;
        return answer;
      }
      return {
        'partNumber': body!['partNumber'],
        'sizeBytes': body['sizeBytes'],
        'uploadUrl': 'https://bucket.test/u1/${sign.group(1)}',
        'headers': {'x-amz-checksum-sha256': 'c'},
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
  Uint8List bytesOf(int length) =>
      Uint8List.fromList(List.generate(length, (i) => i % 256));

  SignedUploadClient clientOf(
    _FakeBackend backend, {
    TransferJournal? journal,
    RetryPolicy? retry,
  }) =>
      SignedUploadClient(
        call: backend.call,
        put: backend.put,
        retry: retry ?? RetryPolicy(sleep: (_) async {}),
        journal: journal,
      );

  Future<Map<String, Object?>> upload(
    SignedUploadClient client,
    Uint8List bytes, {
    TransferControl? control,
  }) =>
      client.upload(
        basePath: '/up',
        clientKey: 'key-1',
        fileName: 'clip.mp4',
        mimeType: 'video/mp4',
        byteSize: bytes.length,
        // Chunks that do not line up with the parts.
        openRead: () => Stream.fromIterable([
          bytes.sublist(0, 3),
          bytes.sublist(3),
        ]),
        control: control,
      );

  test('sends each part once and completes with the receipts', () async {
    final backend = _FakeBackend();
    final progress = <int>[];
    final result = await upload(
      clientOf(backend),
      bytesOf(10),
      control: TransferControl(onProgress: (done, _) => progress.add(done)),
    );
    expect(result, {'id': 'asset-1', 'bytes': 10});
    expect(backend.puts, [1, 2, 3]);
    expect(backend.calls.last, 'POST /up/u1/complete');
    expect(progress.last, 10);
  });

  test('a finished session returns its result without sending', () async {
    final backend = _FakeBackend()..finished = {'id': 'asset-0'};
    expect(await upload(clientOf(backend), bytesOf(10)), {'id': 'asset-0'});
    expect(backend.puts, isEmpty);
  });

  test('a transient failure signs the part again and resends it', () async {
    final backend = _FakeBackend();
    backend.failOnce[2] = const BlobTransientFailure('réseau');
    await upload(clientOf(backend), bytesOf(10));
    expect(backend.puts, [1, 2, 2, 3]);
    expect(
      backend.calls.where((call) => call.endsWith('/parts/2/sign')),
      hasLength(2),
    );
  });

  test('a final failure is not retried', () async {
    final backend = _FakeBackend();
    backend.failOnce[2] = StateError('refusé');
    await expectLater(
      upload(clientOf(backend), bytesOf(10)),
      throwsStateError,
    );
    expect(backend.puts, [1, 2]);
  });

  test('a resend with a journal skips the stored parts', () async {
    final backend = _FakeBackend();
    final journal = MemoryTransferJournal();
    backend.failOnce[3] = const BlobTransientFailure('réseau');
    await expectLater(
      upload(
        clientOf(backend, journal: journal, retry: RetryPolicy.none),
        bytesOf(10),
      ),
      throwsA(isA<BlobTransientFailure>()),
    );
    backend.puts.clear();
    await upload(clientOf(backend, journal: journal), bytesOf(10));
    expect(backend.puts, [3]);
  });

  test('a cancellation abandons the session', () async {
    final backend = _FakeBackend();
    // The app's PUT reports the cancellation of its own request.
    backend.failOnce[2] = const BlobTransferCancelled();
    await expectLater(
      upload(clientOf(backend), bytesOf(10)),
      throwsA(isA<BlobTransferCancelled>()),
    );
    await pumpEventQueue();
    expect(backend.calls, contains('DELETE /up/u1'));
  });

  test('a file longer than its parts is refused', () async {
    final backend = _FakeBackend();
    await expectLater(
      clientOf(backend).upload(
        basePath: '/up',
        clientKey: 'key-1',
        fileName: 'clip.mp4',
        mimeType: 'video/mp4',
        byteSize: 8,
        checksumSha256: 'x',
        openRead: () => Stream.value(bytesOf(12)),
      ),
      throwsFormatException,
    );
  });

  test('a sign answer naming the bucket is refused', () async {
    final backend = _FakeBackend()
      ..signAnswer = {
        'partNumber': 1,
        'sizeBytes': 4,
        'uploadUrl': 'https://bucket.test/u1/1',
        'bucket': 'secret',
      };
    await expectLater(
      upload(clientOf(backend), bytesOf(10)),
      throwsFormatException,
    );
  });
}
