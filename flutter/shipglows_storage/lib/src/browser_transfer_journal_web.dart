/// The browser side of `browser_transfer_journal.dart`, compiled only where
/// `dart:js_interop` exists.
library;

import 'package:web/web.dart' as web;

import 'key_value_transfer_journal.dart';
import 'transfer_journal.dart';

/// Resume notes in `window.localStorage`, which survives a reload of the
/// page (unlike memory) and is per origin, so two apps on one host need a
/// distinct [prefix]. Storage that is blocked or full degrades to "the
/// transfer starts over", never to a failed upload; see
/// [KeyValueTransferJournal].
class BrowserTransferJournal implements TransferJournal {
  BrowserTransferJournal({
    String prefix = KeyValueTransferJournal.defaultPrefix,
  }) : _journal = KeyValueTransferJournal(_LocalStorage(), prefix: prefix);

  final KeyValueTransferJournal _journal;

  @override
  Future<Map<String, Object?>?> read(String id) => _journal.read(id);

  @override
  Future<void> write(String id, Map<String, Object?> note) =>
      _journal.write(id, note);

  @override
  Future<void> delete(String id) => _journal.delete(id);
}

/// The store itself. Reaching `window.localStorage` can throw on its own
/// (a sandboxed iframe, site data blocked), which the journal absorbs.
class _LocalStorage implements KeyValueStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) =>
      web.window.localStorage.setItem(key, value);

  @override
  void remove(String key) => web.window.localStorage.removeItem(key);
}
