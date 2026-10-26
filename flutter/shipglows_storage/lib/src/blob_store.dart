/// Where an app keeps files away from this computer: one interface, a store
/// per kind of place (S3-compatible bucket, synchronised folder), and an
/// in-memory store for tests.
///
/// A key is a relative path with forward slashes, such as
/// `files/ab/ab12….mp3`; it never starts with `/` and never holds `..`.
/// Every write names a [WriteCondition] so an index such as `catalog.json`
/// can be replaced only when nobody else changed it in between.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What a stored object is: its key, its size in bytes and its version tag.
///
/// The [etag] is opaque: compare it, pass it back in [WriteCondition.ifMatch],
/// never parse it.
typedef BlobInfo = ({String key, int bytes, String etag});

/// When a write may happen.
sealed class WriteCondition {
  const WriteCondition();

  /// Write whatever is there.
  static const always = AlwaysWrite();

  /// Write only when no object has the key.
  static const ifAbsent = WriteIfAbsent();

  /// Write only when the object still has [etag].
  const factory WriteCondition.ifMatch(String etag) = WriteIfMatch;
}

/// See [WriteCondition.always].
final class AlwaysWrite extends WriteCondition {
  const AlwaysWrite();
}

/// See [WriteCondition.ifAbsent].
final class WriteIfAbsent extends WriteCondition {
  const WriteIfAbsent();
}

/// See [WriteCondition.ifMatch].
final class WriteIfMatch extends WriteCondition {
  const WriteIfMatch(this.etag);

  final String etag;
}

/// Why a store call failed, with a French message for the user.
sealed class BlobStoreException implements Exception {
  const BlobStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The [WriteCondition] did not hold: someone else wrote the object first.
final class BlobPreconditionFailed extends BlobStoreException {
  const BlobPreconditionFailed()
      : super("L'objet a été modifié ailleurs entre-temps.");
}

/// The credentials are wrong or lack a right; retrying will not help.
final class BlobAccessDenied extends BlobStoreException {
  const BlobAccessDenied([
    super.message = 'Accès refusé : vérifiez les clés et le bucket.',
  ]);
}

/// The place could not be reached or answered oddly; retrying may help.
final class BlobTransientFailure extends BlobStoreException {
  const BlobTransientFailure(super.message);
}

/// The key is not a valid relative path.
final class BlobInvalidKey extends BlobStoreException {
  BlobInvalidKey(String key) : super('Clé de stockage invalide : « $key ».');
}

/// A place that keeps objects by key.
abstract interface class BlobStore {
  /// Stores [bytes] under [key] when [condition] holds, and returns what is
  /// now stored.
  ///
  /// Throws [BlobPreconditionFailed] when it does not hold.
  Future<BlobInfo> putBytes(
    String key,
    Uint8List bytes, {
    WriteCondition condition = WriteCondition.always,
  });

  /// Stores the content of [file] under [key], streamed so a large file
  /// never sits whole in memory.
  Future<BlobInfo> putFile(String key, File file);

  /// The bytes under [key], or null when there is none.
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(String key);

  /// Writes the object under [key] to [target] and returns what was written,
  /// or null when there is none; [target] is then left untouched.
  Future<BlobInfo?> download(String key, File target);

  /// What is stored under [key], or null when there is none.
  Future<BlobInfo?> head(String key);

  /// Removes [key]; removing a missing key succeeds.
  Future<void> delete(String key);

  /// Every object whose key starts with [prefix], in key order.
  Stream<BlobInfo> list(String prefix);
}

/// Throws [BlobInvalidKey] unless [key] is a relative forward-slash path
/// with no empty, `.` or `..` part.
void checkBlobKey(String key) {
  if (key.isEmpty ||
      key.contains('\\') ||
      key.split('/').any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw BlobInvalidKey(key);
  }
}

/// A store that keeps everything in memory, for tests.
class MemoryBlobStore implements BlobStore {
  final _objects = <String, ({Uint8List bytes, String etag})>{};

  @override
  Future<BlobInfo> putBytes(
    String key,
    Uint8List bytes, {
    WriteCondition condition = WriteCondition.always,
  }) async {
    checkBlobKey(key);
    final current = _objects[key];
    final allowed = switch (condition) {
      AlwaysWrite() => true,
      WriteIfAbsent() => current == null,
      WriteIfMatch(:final etag) => current?.etag == etag,
    };
    if (!allowed) throw const BlobPreconditionFailed();
    final copy = Uint8List.fromList(bytes);
    final etag = sha256.convert(copy).toString();
    _objects[key] = (bytes: copy, etag: etag);
    return (key: key, bytes: copy.length, etag: etag);
  }

  @override
  Future<BlobInfo> putFile(String key, File file) async =>
      putBytes(key, await file.readAsBytes());

  @override
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(String key) async {
    checkBlobKey(key);
    final object = _objects[key];
    if (object == null) return null;
    return (
      bytes: Uint8List.fromList(object.bytes),
      info: (key: key, bytes: object.bytes.length, etag: object.etag),
    );
  }

  @override
  Future<BlobInfo?> download(String key, File target) async {
    final object = await getBytes(key);
    if (object == null) return null;
    await target.parent.create(recursive: true);
    await target.writeAsBytes(object.bytes, flush: true);
    return object.info;
  }

  @override
  Future<BlobInfo?> head(String key) async => (await getBytes(key))?.info;

  @override
  Future<void> delete(String key) async {
    checkBlobKey(key);
    _objects.remove(key);
  }

  @override
  Stream<BlobInfo> list(String prefix) async* {
    final keys = _objects.keys.where((key) => key.startsWith(prefix)).toList()
      ..sort();
    for (final key in keys) {
      final object = _objects[key]!;
      yield (key: key, bytes: object.bytes.length, etag: object.etag);
    }
  }
}
