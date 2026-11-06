/// Off the web there is no `localStorage`; see `browser_transfer_journal.dart`.
library;

import 'key_value_transfer_journal.dart';
import 'transfer_journal.dart';

/// Fails at construction, not on the first upload, so a wrong platform is
/// found at once: a VM app needs a `FileTransferJournal` instead.
class BrowserTransferJournal implements TransferJournal {
  BrowserTransferJournal({
    String prefix = KeyValueTransferJournal.defaultPrefix,
  }) {
    throw _unsupported();
  }

  static UnsupportedError _unsupported() => UnsupportedError(
        'BrowserTransferJournal needs a browser; use FileTransferJournal',
      );

  @override
  Future<Map<String, Object?>?> read(String id) => throw _unsupported();

  @override
  Future<void> write(String id, Map<String, Object?> note) =>
      throw _unsupported();

  @override
  Future<void> delete(String id) => throw _unsupported();
}
