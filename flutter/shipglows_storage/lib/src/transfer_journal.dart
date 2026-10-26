/// Where a store notes how far a transfer went, so the same transfer started
/// again after a cancellation, a lost connection or a restart picks up
/// where it stopped instead of sending everything again. Free of `dart:io`;
/// `FileTransferJournal` keeps notes on disk.
library;

import 'dart:convert';

/// Notes kept per transfer, by an id the store derives from the transfer
/// (only letters and digits). The content is the store's own JSON.
abstract interface class TransferJournal {
  /// The note for [id], or null when there is none or it is unreadable.
  Future<Map<String, Object?>?> read(String id);

  Future<void> write(String id, Map<String, Object?> note);

  /// Removes the note; removing a missing one succeeds.
  Future<void> delete(String id);
}

/// A journal that lasts as long as the app runs: resumes after a
/// cancellation or a lost connection, not after a restart.
class MemoryTransferJournal implements TransferJournal {
  final _notes = <String, String>{};

  @override
  Future<Map<String, Object?>?> read(String id) async {
    final text = _notes[id];
    return text == null ? null : jsonDecode(text) as Map<String, Object?>;
  }

  @override
  Future<void> write(String id, Map<String, Object?> note) async {
    _notes[id] = jsonEncode(note);
  }

  @override
  Future<void> delete(String id) async {
    _notes.remove(id);
  }
}
