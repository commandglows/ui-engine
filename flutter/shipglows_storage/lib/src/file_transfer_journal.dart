import 'dart:convert';
import 'dart:io';

import 'transfer_journal.dart';

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
