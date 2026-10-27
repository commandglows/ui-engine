@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/signed_upload.dart';

void main() {
  test('a note survives a new journal, as after a reload', () async {
    const prefix = 'test.browser.';
    final journal = BrowserTransferJournal(prefix: prefix);
    await journal.delete('abc123');
    expect(await journal.read('abc123'), isNull);

    final note = {
      'parts': {
        '1': {'etag': '"e1"', 'checksumSha256': 'c', 'bytes': 4},
      },
    };
    await journal.write('abc123', note);

    expect(
      await BrowserTransferJournal(prefix: prefix).read('abc123'),
      note,
    );

    await BrowserTransferJournal(prefix: prefix).delete('abc123');
    expect(await journal.read('abc123'), isNull);
  });
}
