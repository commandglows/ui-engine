/// A [TransferJournal] kept in a string store such as the browser's
/// `localStorage`, so an upload resumes its missing parts after the page
/// reloads. Free of `dart:io` and `dart:js_interop`; the browser binding
/// lives in `browser_transfer_journal.dart`.
library;

import 'dart:convert';

import 'transfer_journal.dart';

/// A synchronous string store. Synchronous on purpose: `localStorage` is,
/// and a journal read or written in the middle of a part should not wait on
/// a future the upload then has to order.
abstract interface class KeyValueStore {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

/// A journal of one JSON note per transfer in [store], under `'$prefix$id'`.
///
/// The prefix keeps the notes apart from the app's other keys in the same
/// origin. Ids are checked the way `FileTransferJournal` checks them, so a
/// key can never carry a separator or a dot.
///
/// Storage is best effort. A browser store can be full or blocked, and a
/// transfer must not fail because its resume notes could not be kept: a
/// failed write only means that part is sent again after a reload, and a
/// failed read means the transfer starts over.
class KeyValueTransferJournal implements TransferJournal {
  KeyValueTransferJournal(this.store, {this.prefix = defaultPrefix});

  static const defaultPrefix = 'shipglows.transfer.';

  final KeyValueStore store;
  final String prefix;

  String _keyOf(String id) {
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'letters and digits only');
    }
    return '$prefix$id';
  }

  @override
  Future<Map<String, Object?>?> read(String id) async {
    final key = _keyOf(id);
    final String? text;
    try {
      text = store.read(key);
    } catch (_) {
      // Storage blocked or unavailable: nothing to resume from.
      return null;
    }
    if (text == null) return null;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      _forget(key);
      return null;
    }
    // A value that is not a note (a half-written or foreign entry) would
    // break the upload later, so it is dropped now instead.
    if (json is Map<String, Object?>) return json;
    _forget(key);
    return null;
  }

  @override
  Future<void> write(String id, Map<String, Object?> note) async {
    final key = _keyOf(id);
    final text = jsonEncode(note);
    try {
      store.write(key, text);
    } catch (_) {
      // Quota exceeded or storage blocked. The upload goes on and simply
      // will not resume past this point after a reload.
    }
  }

  @override
  Future<void> delete(String id) async {
    _forget(_keyOf(id));
  }

  void _forget(String key) {
    try {
      store.remove(key);
    } catch (_) {
      // Storage blocked: the stale note stays, and a read drops it later.
    }
  }
}
