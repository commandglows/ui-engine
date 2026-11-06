import 'dart:async';
import 'dart:math';
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

  /// Runs inside each PUT before it answers, to hold a part in flight.
  Future<void> Function(int number)? holdPut;

  /// PUTs in flight now, and the most there were at once.
  int inFlight = 0;
  int maxInFlight = 0;

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
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await holdPut?.call(number);
      final failure = failOnce.remove(number);
      if (failure != null) throw failure;
      stored[number] = bytes;
      onSent(bytes.length);
      return '"etag-$number"';
    } finally {
      inFlight--;
    }
  }
}

void main() {
  Uint8List bytesOf(int length) =>
      Uint8List.fromList(List.generate(length, (i) => i % 256));

  SignedUploadClient clientOf(
    _FakeBackend backend, {
    TransferJournal? journal,
    RetryPolicy? retry,
    int partConcurrency = 3,
  }) =>
      SignedUploadClient(
        call: backend.call,
        put: backend.put,
        retry: retry ?? RetryPolicy(sleep: (_) async {}),
        journal: journal,
        partConcurrency: partConcurrency,
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

  /// [bytes] through [uploadSignedParts] directly, in parts of 4 bytes.
  Future<List<SignedPartReceipt>> sendParts(
    _FakeBackend backend,
    Uint8List bytes, {
    int partConcurrency = 3,
    TransferControl? control,
    Map<int, SignedPartReceipt> stored = const {},
    void Function(SignedPartReceipt receipt)? onStored,
  }) =>
      uploadSignedParts(
        parts: [
          for (var start = 0, n = 1; start < bytes.length; start += 4, n++)
            (number: n, bytes: min(4, bytes.length - start)),
        ],
        source: Stream.fromIterable([bytes.sublist(0, 3), bytes.sublist(3)]),
        totalBytes: bytes.length,
        sign: (number, checksum, size) async => (
          url: Uri.parse('https://bucket.test/u1/$number'),
          headers: const <String, String>{},
        ),
        put: backend.put,
        retry: RetryPolicy(sleep: (_) async {}),
        control: control,
        stored: stored,
        onStored: onStored,
        partConcurrency: partConcurrency,
      );

  test('sends each part once and completes with the receipts', () async {
    final backend = _FakeBackend();
    final progress = <int>[];
    final result = await upload(
      clientOf(backend, partConcurrency: 1),
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
    await upload(clientOf(backend, partConcurrency: 1), bytesOf(10));
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
      upload(clientOf(backend, partConcurrency: 1), bytesOf(10)),
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
        clientOf(
          backend,
          journal: journal,
          retry: RetryPolicy.none,
          partConcurrency: 1,
        ),
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

  test('parts go up several at a time', () async {
    final backend = _FakeBackend();
    final secondStarted = Completer<void>();
    backend.holdPut = (number) async {
      if (number == 2) secondStarted.complete();
      // Sequential parts never start part 2 while part 1 waits: the timeout
      // fails the test instead of hanging it.
      if (number == 1) {
        await secondStarted.future.timeout(const Duration(seconds: 2));
      }
    };
    final result = await upload(clientOf(backend), bytesOf(10));
    expect(result, {'id': 'asset-1', 'bytes': 10});
    expect(backend.puts.toSet(), {1, 2, 3});
  });

  test('never more than partConcurrency parts go up at once', () async {
    final backend = _FakeBackend()
      ..holdPut = (_) => Future<void>.delayed(const Duration(milliseconds: 5));
    await upload(clientOf(backend, partConcurrency: 2), bytesOf(40));
    expect(backend.puts, hasLength(10));
    expect(backend.maxInFlight, 2);
  });

  test('a failed part stops new parts and rethrows that error', () async {
    final backend = _FakeBackend()..failOnce[3] = StateError('refusé');
    backend.holdPut =
        (_) => Future<void>.delayed(const Duration(milliseconds: 5));
    await expectLater(
      sendParts(backend, bytesOf(40), partConcurrency: 2),
      throwsStateError,
    );
    expect(backend.puts.length, lessThan(10));
  });

  test('a cancellation midway, then a resume, re-sends only the missing parts',
      () async {
    final backend = _FakeBackend()
      ..failOnce[3] = const BlobTransferCancelled();
    final journal = <int, SignedPartReceipt>{};
    await expectLater(
      sendParts(
        backend,
        bytesOf(40),
        partConcurrency: 2,
        onStored: (receipt) {
          journal[receipt.number] = receipt;
        },
      ),
      throwsA(isA<BlobTransferCancelled>()),
    );
    final storedBefore = backend.stored.keys.toSet();
    expect(journal.keys.toSet(), storedBefore);
    expect(storedBefore, isNot(contains(3)));

    backend.puts.clear();
    final receipts = await sendParts(
      backend,
      bytesOf(40),
      partConcurrency: 2,
      stored: journal,
    );
    final missing = {for (var n = 1; n <= 10; n++) n}.difference(storedBefore);
    expect(backend.puts.toSet(), missing);
    expect(backend.puts, hasLength(missing.length));
    expect(
      receipts.map((receipt) => receipt.number),
      [for (var n = 1; n <= 10; n++) n],
    );
  });

  test('receipts come back in part order even when parts finish out of order',
      () async {
    final backend = _FakeBackend();
    final finished = <int>[];
    backend.holdPut = (number) async {
      // Part 1 is the slowest, part 3 the quickest.
      await Future<void>.delayed(Duration(milliseconds: 10 * (4 - number)));
      finished.add(number);
    };
    final receipts = await sendParts(backend, bytesOf(12));
    expect(finished, [3, 2, 1]);
    expect(receipts.map((receipt) => receipt.number), [1, 2, 3]);
    expect(
      receipts.map((receipt) => receipt.etag),
      ['"etag-1"', '"etag-2"', '"etag-3"'],
    );
  });
}
