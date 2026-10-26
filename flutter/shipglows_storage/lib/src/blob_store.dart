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

import 'blob_errors.dart';
import 'transfer.dart';

export 'blob_errors.dart';

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

/// A place that keeps objects by key.
///
/// The calls that move content take an optional [TransferControl] to follow
/// their progress and cancel them.
abstract interface class BlobStore {
  /// Stores [bytes] under [key] when [condition] holds, and returns what is
  /// now stored.
  ///
  /// Throws [BlobPreconditionFailed] when it does not hold.
  Future<BlobInfo> putBytes(
    String key,
    Uint8List bytes, {
    WriteCondition condition = WriteCondition.always,
    TransferControl? control,
  });

  /// Stores the content of [file] under [key], streamed so a large file
  /// never sits whole in memory.
  Future<BlobInfo> putFile(String key, File file, {TransferControl? control});

  /// The bytes under [key], or null when there is none.
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(
    String key, {
    TransferControl? control,
  });

  /// Writes the object under [key] to [target] and returns what was written,
  /// or null when there is none; [target] is then left untouched.
  Future<BlobInfo?> download(
    String key,
    File target, {
    TransferControl? control,
  });

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
    TransferControl? control,
  }) async {
    checkBlobKey(key);
    control?.check();
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
    control?.report(copy.length, copy.length);
    return (key: key, bytes: copy.length, etag: etag);
  }

  @override
  Future<BlobInfo> putFile(
    String key,
    File file, {
    TransferControl? control,
  }) async =>
      putBytes(key, await file.readAsBytes(), control: control);

  @override
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(
    String key, {
    TransferControl? control,
  }) async {
    checkBlobKey(key);
    control?.check();
    final object = _objects[key];
    if (object == null) return null;
    control?.report(object.bytes.length, object.bytes.length);
    return (
      bytes: Uint8List.fromList(object.bytes),
      info: (key: key, bytes: object.bytes.length, etag: object.etag),
    );
  }

  @override
  Future<BlobInfo?> download(
    String key,
    File target, {
    TransferControl? control,
  }) async {
    final object = await getBytes(key, control: control);
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
