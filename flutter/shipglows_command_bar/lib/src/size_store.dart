import 'dart:ui' show Size;

/// Where the size the user gave the bar by dragging its edges is kept.
///
/// [read] is called while building, so it must be synchronous and never
/// write. Apps usually back it with `SharedPreferences`.
abstract interface class CommandBarSizeStore {
  /// The saved size, or null for the theme's default size.
  Size? read();

  /// Saves [size]; null forgets it (back to the default size). A failed save
  /// throws; the bar reports it and goes on.
  Future<void> write(Size? size);
}

/// Size kept in memory for the life of the store.
class MemoryCommandBarSize implements CommandBarSizeStore {
  Size? _size;

  @override
  Size? read() => _size;

  @override
  Future<void> write(Size? size) async => _size = size;
}

/// Size read and written through callbacks, for an app that already has its
/// own storage.
class CallbackCommandBarSize implements CommandBarSizeStore {
  const CallbackCommandBarSize({
    required Size? Function() read,
    required Future<void> Function(Size? size) write,
  }) : _read = read,
       _write = write;

  final Size? Function() _read;
  final Future<void> Function(Size? size) _write;

  @override
  Size? read() => _read();

  @override
  Future<void> write(Size? size) => _write(size);
}
