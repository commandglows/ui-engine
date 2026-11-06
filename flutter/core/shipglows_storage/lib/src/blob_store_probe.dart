import 'dart:convert';
import 'dart:typed_data';

import 'blob_store.dart';

/// Writes, reads back and removes a small object under [keyPrefix] on
/// [store], and returns null when all went well or a French reason when
/// not: the « Tester » button of a storage settings page.
Future<String?> testBlobStore(
  BlobStore store, {
  DateTime? now,
  String keyPrefix = '.shipglows-test',
}) async {
  final key = '$keyPrefix/${(now ?? DateTime.now()).microsecondsSinceEpoch}';
  const content = 'ShipGlows';
  final probe = Uint8List.fromList(utf8.encode(content));
  try {
    await store.putBytes(key, probe);
    final read = await store.getBytes(key);
    await store.delete(key);
    if (read == null || utf8.decode(read.bytes) != content) {
      return "L'objet d'essai n'a pas été relu à l'identique.";
    }
    return null;
  } on BlobStoreException catch (error) {
    return error.message;
  }
}
