import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

void main() {
  group('RetryPolicy', () {
    final waits = <Duration>[];
    final policy = RetryPolicy(
      attempts: 3,
      firstDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 3),
      sleep: (wait) async => waits.add(wait),
    );

    setUp(waits.clear);

    test('tries a transient failure again, then gives up', () async {
      var tries = 0;
      await expectLater(
        policy.run<void>(() async {
          tries++;
          throw const BlobTransientFailure('réseau');
        }),
        throwsA(isA<BlobTransientFailure>()),
      );
      expect(tries, 3);
      expect(waits, hasLength(2));
    });

    test('returns the first success', () async {
      var tries = 0;
      final result = await policy.run(() async {
        if (++tries < 2) throw const BlobTransientFailure('réseau');
        return 'ok';
      });
      expect(result, 'ok');
      expect(tries, 2);
    });

    test('a final failure is not retried', () async {
      var tries = 0;
      await expectLater(
        policy.run<void>(() async {
          tries++;
          throw const BlobAccessDenied();
        }),
        throwsA(isA<BlobAccessDenied>()),
      );
      expect(tries, 1);
    });

    test('waits double up to the cap, minus at most a quarter', () {
      for (final (attempt, full) in [(2, 1000), (3, 2000), (4, 3000)]) {
        final wait = policy.delayBefore(attempt).inMilliseconds;
        expect(wait, inInclusiveRange(full * 3 ~/ 4, full));
      }
    });

    test('a cancelled control stops before the next try', () async {
      final control = TransferControl();
      var tries = 0;
      await expectLater(
        policy.run<void>(() async {
          tries++;
          control.cancel();
          throw const BlobTransientFailure('réseau');
        }, control: control),
        throwsA(isA<BlobTransferCancelled>()),
      );
      expect(tries, 1);
    });
  });

  group('FileTransferJournal', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('journal_');
    });
    tearDown(() => directory.delete(recursive: true));

    test('keeps a note across instances, then forgets it', () async {
      await FileTransferJournal(directory).write('abc123', {'etag': '"v1"'});
      final journal = FileTransferJournal(directory);
      expect(await journal.read('abc123'), {'etag': '"v1"'});
      await journal.delete('abc123');
      await journal.delete('abc123');
      expect(await journal.read('abc123'), isNull);
    });

    test('an unreadable note reads as none', () async {
      File('${directory.path}/bad.json').writeAsStringSync('{');
      expect(await FileTransferJournal(directory).read('bad'), isNull);
    });

    test('ids are letters and digits only', () async {
      await expectLater(
        FileTransferJournal(directory).read('../x'),
        throwsArgumentError,
      );
    });
  });
}
