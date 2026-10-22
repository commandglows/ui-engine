import 'tray_config.dart';
import 'store_file_stub.dart' if (dart.library.io) 'store_file_io.dart';

/// Where [ShipglowsTray] keeps the close behavior the user chose (« Ne plus
/// me demander », or the app's settings).
abstract interface class ShipglowsTrayStore {
  /// The saved behavior; null when there is none or it cannot be read.
  Future<ShipglowsTrayCloseBehavior?> load();

  /// False when it could not be written.
  Future<bool> save(ShipglowsTrayCloseBehavior behavior);
}

/// Kept in `%APPDATA%\<appFolder>\tray.json`, next to `hotkeys.json` and the
/// remembered overlay windows.
class ShipglowsTrayFileStore implements ShipglowsTrayStore {
  const ShipglowsTrayFileStore(this.appFolder);

  final String appFolder;

  @override
  Future<ShipglowsTrayCloseBehavior?> load() async {
    final document = await readTrayDocument(appFolder);
    final name = document is Map ? document['closeBehavior'] : null;
    for (final behavior in ShipglowsTrayCloseBehavior.values) {
      if (behavior.name == name) return behavior;
    }
    return null;
  }

  @override
  Future<bool> save(ShipglowsTrayCloseBehavior behavior) =>
      writeTrayDocument(appFolder, {
        'version': 1,
        'closeBehavior': behavior.name,
      });
}

/// Kept for the life of the process only.
class ShipglowsTrayMemoryStore implements ShipglowsTrayStore {
  ShipglowsTrayMemoryStore([this._behavior]);

  ShipglowsTrayCloseBehavior? _behavior;

  @override
  Future<ShipglowsTrayCloseBehavior?> load() async => _behavior;

  @override
  Future<bool> save(ShipglowsTrayCloseBehavior behavior) async {
    _behavior = behavior;
    return true;
  }
}
