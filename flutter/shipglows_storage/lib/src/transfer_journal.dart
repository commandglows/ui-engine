/// Where a store notes how far a transfer went, so the same transfer started
/// again after a cancellation, a lost connection or a restart picks up
/// where it stopped instead of sending everything again.
library;

import 'dart:convert';
import 'dart:io';

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

/// A journal of one `<id>.json` file per transfer in [directory] (the app's
/// support folder, say), so a transfer resumes after a restart too.
class FileTransferJournal implements TransferJournal {
  FileTransferJournal(this.directory);

  final Directory directory;

  File _fileOf(String id) {
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'letters and digits only');
    }
    return File('${directory.path}${Platform.pathSeparator}$id.json');
  }

  @override
  Future<Map<String, Object?>?> read(String id) async {
    try {
      final json = jsonDecode(await _fileOf(id).readAsString());
      return json is Map<String, Object?> ? json : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String id, Map<String, Object?> note) async {
    final file = _fileOf(id);
    final partial = File('${file.path}.tmp');
    await directory.create(recursive: true);
    await partial.writeAsString(jsonEncode(note), flush: true);
    await partial.rename(file.path);
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _fileOf(id).delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }
}
