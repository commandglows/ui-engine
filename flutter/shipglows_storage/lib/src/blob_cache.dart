/// Objects of a [BlobStore] kept on this computer up to a size: fetched on
/// demand, the least recently used dropped first.
library;

import 'dart:io';

import 'blob_store.dart';
import 'transfer.dart';

/// A local copy of a store's objects in [directory], at most [maxBytes].
///
/// Each object is a file at its key under [directory]. Using a file stamps
/// its modification time, which is what eviction orders by (access times are
/// unreliable on Windows and on disks mounted without them).
class BlobCache {
  BlobCache({
    required this.directory,
    required this.store,
    required this.maxBytes,
  });

  final Directory directory;
  final BlobStore store;

  /// Largest total size of the cached files; the file just fetched is kept
  /// even when it alone is larger.
  final int maxBytes;

  /// Downloads under way by key, so two callers share one.
  final _downloads = <String, Future<BlobInfo?>>{};

  File _fileOf(String key) {
    checkBlobKey(key);
    return File(
      [directory.path, ...key.split('/')].join(Platform.pathSeparator),
    );
  }

  /// The cached copy of [key], or null; it is not marked as used.
  File? peek(String key) {
    final file = _fileOf(key);
    return file.existsSync() ? file : null;
  }

  /// The local copy of [key], downloaded first when missing (checked against
  /// [expectedSha256] when given), then marked as just used, and the cache
  /// trimmed to [maxBytes]. Null when the store has no such object.
  ///
  /// A copy already cached is trusted as it is.
  Future<File?> fetch(
    String key, {
    String? expectedSha256,
    TransferControl? control,
  }) async {
    final file = _fileOf(key);
    if (!await file.exists()) {
      final got = await _downloads.putIfAbsent(
        key,
        () => store
            .download(
              key,
              file,
              control: control,
              expectedSha256: expectedSha256,
            )
            // A block, not an arrow: remove returns this very future, which
            // whenComplete would then wait for, forever.
            .whenComplete(() {
              _downloads.remove(key);
            }),
      );
      if (got == null) return null;
    }
    await _touch(file);
    await evictToFit(keep: file);
    return file;
  }

  /// Removes the cached copy of [key]; a missing one succeeds.
  Future<void> remove(String key) async {
    try {
      await _fileOf(key).delete();
    } on PathNotFoundException {
      // Not cached.
    }
  }

  /// Deletes the least recently used files until the cache holds at most
  /// [maxBytes], never [keep]. Files still being written (`.part`,
  /// `.shipglows-incoming`) are left alone.
  Future<void> evictToFit({File? keep}) async {
    if (!await directory.exists()) return;
    final files = <({File file, int bytes, DateTime used})>[];
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File ||
          entity.path.endsWith('.part') ||
          entity.path.endsWith('.shipglows-incoming')) {
        continue;
      }
      try {
        final stat = await entity.stat();
        files.add((file: entity, bytes: stat.size, used: stat.modified));
        total += stat.size;
      } on FileSystemException {
        // Gone meanwhile.
      }
    }
    if (total <= maxBytes) return;
    files.sort((a, b) => a.used.compareTo(b.used));
    final kept = keep?.absolute.path;
    for (final entry in files) {
      if (total <= maxBytes) break;
      if (entry.file.absolute.path == kept) continue;
      try {
        await entry.file.delete();
        total -= entry.bytes;
      } on FileSystemException {
        // In use or gone: try the next one.
      }
    }
  }

  static Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on FileSystemException {
      // Read-only: it is evicted a little earlier, nothing worse.
    }
  }
}
