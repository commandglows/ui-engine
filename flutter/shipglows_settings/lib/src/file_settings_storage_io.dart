import 'dart:convert';
import 'dart:io';

import 'settings_storage.dart';

/// One `<prefix><bucket>.json` file per bucket in [directory], written to a
/// temporary file then renamed over the old one.
class FileSettingsStorage implements SettingsStorage {
  FileSettingsStorage(this.directory, {this.prefix = 'settings.'});

  /// Usually `getApplicationSupportDirectory()`, resolved by the app.
  final Directory directory;
  final String prefix;

  /// Writes to one bucket run one after another.
  final Map<String, Future<void>> _chains = {};

  File _file(String bucket) =>
      File('${directory.path}${Platform.pathSeparator}$prefix$bucket.json');

  @override
  Future<Map<String, Object?>?> read(String bucket) async {
    await _chains[bucket];
    final file = _file(bucket);
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    if (text.trim().isEmpty) return null;
    final data = jsonDecode(text);
    return data is Map ? data.cast<String, Object?>() : null;
  }

  @override
  Future<void> write(String bucket, Map<String, Object?> data) =>
      _enqueue(bucket, () async {
        await directory.create(recursive: true);
        final target = _file(bucket);
        final temp = File('${target.path}.tmp');
        await temp.writeAsString(jsonEncode(data), flush: true);
        if (Platform.isWindows && await target.exists()) {
          // rename() does not replace an existing file on every Windows setup.
          await target.delete();
        }
        await temp.rename(target.path);
      });

  @override
  Future<void> delete(String bucket) => _enqueue(bucket, () async {
    final file = _file(bucket);
    if (await file.exists()) await file.delete();
  });

  Future<void> _enqueue(String bucket, Future<void> Function() action) {
    final previous = _chains[bucket] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => action());
    _chains[bucket] = next;
    return next;
  }
}
