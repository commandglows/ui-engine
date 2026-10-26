import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

import 'blob_store_contract.dart';
import 'fake_s3_server.dart';

/// [S3BlobStore] against [FakeS3Server]: retries, multipart resume after a
/// cancellation or an expired upload, download resume after a cut.
void main() {
  late FakeS3Server server;
  late Directory scratch;

  setUp(() async {
    server = await FakeS3Server.start();
    scratch = await Directory.systemTemp.createTemp('s3_transfer_');
  });

  tearDown(() async {
    await server.close();
    await scratch.delete(recursive: true);
  });

  /// A store cutting files over 1 KiB in parts of 1 KiB, never waiting
  /// between retries.
  S3BlobStore storeOn(
    FakeS3Server server, {
    TransferJournal? journal,
    RetryPolicy? retry,
  }) =>
      S3BlobStore(
        (
          endpoint: server.endpoint,
          bucket: 'bucket',
          region: 'auto',
          credentials: (accessKeyId: 'id', secretAccessKey: 'secret'),
        ),
        retry: retry ?? RetryPolicy(sleep: (_) async {}),
        journal: journal,
        multipartThreshold: 1024,
        partBytes: 1024,
      );

  File sourceOf(int bytes) => File('${scratch.path}/source.bin')
    ..writeAsBytesSync(List.generate(bytes, (i) => i % 251));

  List<String> partCalls() =>
      server.calls.where((call) => call.contains('partNumber=')).toList();

  /// Cancels [control] when part [number] arrives, and refuses that part so
  /// it is never stored.
  void cancelAtPart(TransferControl control, int number) {
    server.intercept = (request, body) async {
      if (request.uri.queryParameters['partNumber'] != '$number') return false;
      control.cancel();
      request.response.statusCode = 500;
      await request.response.close();
      return true;
    };
  }

  group('contract on the fake bucket', () {
    late FakeS3Server contractServer;
    setUpAll(() async => contractServer = await FakeS3Server.start());
    tearDownAll(() => contractServer.close());
    runBlobStoreContract(() async => storeOn(contractServer));
  });

  test('a part that fails once is sent again, not the whole file', () async {
    var failed = false;
    server.intercept = (request, body) async {
      if (!failed && request.uri.queryParameters['partNumber'] == '2') {
        failed = true;
        request.response.statusCode = 500;
        await request.response.close();
        return true;
      }
      return false;
    };
    final source = sourceOf(3000);
    final progress = <int>[];
    final put = await storeOn(server).putFile(
      'big.bin',
      source,
      control: TransferControl(onProgress: (done, _) => progress.add(done)),
    );
    expect(put.bytes, 3000);
    expect(server.objects['big.bin']!.bytes, source.readAsBytesSync());
    expect(partCalls().where((call) => call.contains('partNumber=2')),
        hasLength(2));
    expect(partCalls(), hasLength(4));
    expect(progress.last, 3000);
  });

  test('a cancelled upload resumes from the parts already stored', () async {
    final journal = MemoryTransferJournal();
    final source = sourceOf(5000);
    final control = TransferControl();
    cancelAtPart(control, 3);
    await expectLater(
      storeOn(server, journal: journal)
          .putFile('big.bin', source, control: control),
      throwsA(isA<BlobTransferCancelled>()),
    );
    expect(server.objects, isEmpty);
    expect(server.uploads, hasLength(1), reason: 'kept for the resume');

    server.intercept = null;
    server.calls.clear();
    final progress = <int>[];
    await storeOn(server, journal: journal).putFile(
      'big.bin',
      source,
      control: TransferControl(onProgress: (done, _) => progress.add(done)),
    );
    expect(server.objects['big.bin']!.bytes, source.readAsBytesSync());
    expect(server.calls.where((call) => call.contains('?uploads')), isEmpty);
    expect(partCalls().map((call) => call.split('partNumber=')[1][0]),
        ['3', '4', '5']);
    expect(progress.take(2), [1024, 2048],
        reason: 'the stored parts count as sent');
    expect(server.uploads, isEmpty);
  });

  test('a resume the bucket forgot starts over', () async {
    final journal = MemoryTransferJournal();
    final source = sourceOf(3000);
    final control = TransferControl();
    cancelAtPart(control, 2);
    await expectLater(
      storeOn(server, journal: journal)
          .putFile('big.bin', source, control: control),
      throwsA(isA<BlobTransferCancelled>()),
    );
    server.intercept = null;
    server.uploads.clear();
    server.calls.clear();
    await storeOn(server, journal: journal).putFile('big.bin', source);
    expect(server.objects['big.bin']!.bytes, source.readAsBytesSync());
    expect(server.calls.where((call) => call.contains('?uploads')),
        hasLength(1));
  });

  test('without a journal a cancelled upload is aborted', () async {
    final control = TransferControl();
    cancelAtPart(control, 2);
    await expectLater(
      storeOn(server).putFile('big.bin', sourceOf(3000), control: control),
      throwsA(isA<BlobTransferCancelled>()),
    );
    expect(server.uploads, isEmpty);
  });

  test('a download cut short resumes with a range', () async {
    final bytes = Uint8List.fromList(List.generate(4000, (i) => i % 239));
    server.objects['song.mp3'] = (bytes: bytes, etag: '"v1"');
    var cut = false;
    server.intercept = (request, body) async {
      if (!cut && request.method == 'GET') {
        cut = true;
        await FakeS3Server.cutShort(request, bytes, 1500, etag: '"v1"');
        return true;
      }
      return false;
    };
    final target = File('${scratch.path}/out/song.mp3');
    final got = await storeOn(server, journal: MemoryTransferJournal())
        .download('song.mp3', target);
    expect(got!.bytes, 4000);
    expect(target.readAsBytesSync(), bytes);
    expect(File('${target.path}.part').existsSync(), isFalse);
  });

  test('a download resumed on a changed object starts over', () async {
    final journal = MemoryTransferJournal();
    final first = Uint8List.fromList(List.filled(3000, 1));
    server.objects['a.bin'] = (bytes: first, etag: '"v1"');
    server.intercept = (request, body) async {
      await FakeS3Server.cutShort(request, first, 1000, etag: '"v1"');
      return true;
    };
    final target = File('${scratch.path}/a.bin');
    await expectLater(
      storeOn(server, journal: journal, retry: RetryPolicy.none)
          .download('a.bin', target),
      throwsA(isA<BlobTransientFailure>()),
    );
    expect(File('${target.path}.part').lengthSync(), 1000);

    final second = Uint8List.fromList(List.filled(2500, 2));
    server.objects['a.bin'] = (bytes: second, etag: '"v2"');
    server.intercept = null;
    await storeOn(server, journal: journal).download('a.bin', target);
    expect(target.readAsBytesSync(), second);
  });

  test('access denied is not retried', () async {
    server.intercept = (request, body) async {
      request.response.statusCode = 403;
      request.response.write('<Error><Code>AccessDenied</Code></Error>');
      await request.response.close();
      return true;
    };
    await expectLater(
      storeOn(server).getBytes('x'),
      throwsA(isA<BlobAccessDenied>()),
    );
    expect(server.calls, hasLength(1));
  });
}
