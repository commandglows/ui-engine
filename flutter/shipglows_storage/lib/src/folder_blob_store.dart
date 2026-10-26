/// [BlobStore] on a folder that another program keeps in sync with the
/// cloud (Icedrive, OneDrive, Dropbox, a network share).
///
/// Each object is a plain file at its key under the folder. Writes go to a
/// file named with [FolderBlobStore.incomingSuffix] first and are renamed in
/// place, so the sync client never uploads half a file. The tag of an object is the SHA-256 of
/// its bytes, which the sync client keeps when it copies the file elsewhere.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'blob_store.dart';

class FolderBlobStore implements BlobStore {
  FolderBlobStore(this.root, {this.incomingSuffix = '.shipglows-incoming'});

  /// The synchronised folder.
  final Directory root;

  /// Ending of a file still being written; [list] skips such files. An app
  /// keeps the one it used before so its leftovers stay hidden.
  final String incomingSuffix;

  /// Serialises conditional writes in this process; another computer is the
  /// sync client's business.
  Future<void> _writing = Future.value();

  File _fileOf(String key) {
    checkBlobKey(key);
    return File([root.path, ...key.split('/')].join(Platform.pathSeparator));
  }

  @override
  Future<BlobInfo> putBytes(
    String key,
    Uint8List bytes, {
    WriteCondition condition = WriteCondition.always,
  }) {
    final File file;
    try {
      file = _fileOf(key);
    } on BlobInvalidKey catch (error) {
      return Future.error(error);
    }
    final result = _writing.then((_) async {
      await _ensureRoot();
      if (condition is! AlwaysWrite) {
        final current = await _infoOf(key, file);
        final allowed = switch (condition) {
          AlwaysWrite() => true,
          WriteIfAbsent() => current == null,
          WriteIfMatch(:final etag) => current?.etag == etag,
        };
        if (!allowed) throw const BlobPreconditionFailed();
      }
      await _replace(file, (partial) => partial.writeAsBytes(bytes, flush: true));
      return (
        key: key,
        bytes: bytes.length,
        etag: sha256.convert(bytes).toString(),
      );
    });
    _writing = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<BlobInfo> putFile(String key, File source) async {
    final file = _fileOf(key);
    await _ensureRoot();
    late Digest digest;
    var bytes = 0;
    await _replace(file, (partial) async {
      final output = _DigestSink<Digest>();
      final hasher = sha256.startChunkedConversion(output);
      final sink = partial.openWrite();
      try {
        await for (final chunk in source.openRead()) {
          bytes += chunk.length;
          hasher.add(chunk);
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      hasher.close();
      digest = output.events.single;
    });
    return (key: key, bytes: bytes, etag: digest.toString());
  }

  @override
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(String key) async {
    final file = _fileOf(key);
    try {
      final bytes = await file.readAsBytes();
      return (
        bytes: bytes,
        info: (
          key: key,
          bytes: bytes.length,
          etag: sha256.convert(bytes).toString(),
        ),
      );
    } on PathNotFoundException {
      return null;
    } on FileSystemException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<BlobInfo?> download(String key, File target) async {
    final file = _fileOf(key);
    if (!await file.exists()) return null;
    await target.parent.create(recursive: true);
    try {
      await _replace(target, (partial) => file.copy(partial.path));
    } on PathNotFoundException {
      return null;
    }
    return _infoOf(key, target);
  }

  @override
  Future<BlobInfo?> head(String key) => _infoOf(key, _fileOf(key));

  @override
  Future<void> delete(String key) async {
    try {
      await _fileOf(key).delete();
    } on PathNotFoundException {
      // Already gone.
    } on FileSystemException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Stream<BlobInfo> list(String prefix) async* {
    if (!await root.exists()) return;
    final found = <(String, File)>[];
    final rootLength = root.absolute.path.length + 1;
    await for (final entity
        in root.absolute.list(recursive: true, followLinks: false)) {
      if (entity is! File || entity.path.endsWith(incomingSuffix)) continue;
      final key = entity.path
          .substring(rootLength)
          .replaceAll(Platform.pathSeparator, '/');
      if (key.startsWith(prefix)) found.add((key, entity));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (key, file) in found) {
      final info = await _infoOf(key, file);
      if (info != null) yield info;
    }
  }

  Future<BlobInfo?> _infoOf(String key, File file) async {
    try {
      final output = _DigestSink<Digest>();
      final hasher = sha256.startChunkedConversion(output);
      var bytes = 0;
      await for (final chunk in file.openRead()) {
        bytes += chunk.length;
        hasher.add(chunk);
      }
      hasher.close();
      return (key: key, bytes: bytes, etag: output.events.single.toString());
    } on PathNotFoundException {
      return null;
    } on FileSystemException catch (error) {
      throw _failure(error);
    }
  }

  Future<void> _ensureRoot() async {
    // A missing root is an unmounted drive, not a folder to create: creating
    // it would fill the local disk behind the sync client's back.
    if (!await root.exists()) {
      throw BlobTransientFailure(
        'Dossier « ${root.path} » introuvable : le lecteur est-il monté ?',
      );
    }
  }

  /// Writes [target] through a temporary file next to it.
  Future<void> _replace(
    File target,
    Future<void> Function(File partial) write,
  ) async {
    final partial = File('${target.path}$incomingSuffix');
    try {
      await target.parent.create(recursive: true);
      await write(partial);
      await partial.rename(target.path);
    } on FileSystemException catch (error) {
      try {
        await partial.delete();
      } on FileSystemException {
        // Nothing was written.
      }
      if (error is PathNotFoundException) rethrow;
      throw _failure(error);
    }
  }

  static BlobStoreException _failure(FileSystemException error) =>
      error.osError?.errorCode == 5 || error.osError?.errorCode == 13
          ? const BlobAccessDenied('Écriture refusée dans le dossier.')
          : BlobTransientFailure('Dossier inaccessible : ${error.message}.');
}

/// Keeps what it is given, to read a chunked hash.
class _DigestSink<T> implements Sink<T> {
  final events = <T>[];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
