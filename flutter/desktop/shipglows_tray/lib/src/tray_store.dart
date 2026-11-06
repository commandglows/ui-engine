import 'tray_config.dart';
import 'store_file_stub.dart' if (dart.library.io) 'store_file_io.dart';

/// Where [ShipglowsTray] keeps the user's choices: the close behavior
/// (« Ne plus me demander », or the app's settings) and the startup window.
abstract interface class ShipglowsTrayStore {
  /// The saved behavior; null when there is none or it cannot be read.
  Future<ShipglowsTrayCloseBehavior?> load();

  /// False when it could not be written.
  Future<bool> save(ShipglowsTrayCloseBehavior behavior);

  /// The saved startup window; null when there is none or it cannot be read.
  Future<ShipglowsTrayStartupWindow?> loadStartupWindow();

  /// False when it could not be written.
  Future<bool> saveStartupWindow(ShipglowsTrayStartupWindow window);
}

/// Kept in `%APPDATA%\<appFolder>\tray.json`, next to `hotkeys.json` and the
/// remembered overlay windows.
class ShipglowsTrayFileStore implements ShipglowsTrayStore {
  const ShipglowsTrayFileStore(this.appFolder);

  final String appFolder;

  @override
  Future<ShipglowsTrayCloseBehavior?> load() async =>
      _byName(ShipglowsTrayCloseBehavior.values, await _read('closeBehavior'));

  @override
  Future<bool> save(ShipglowsTrayCloseBehavior behavior) =>
      _write('closeBehavior', behavior.name);

  @override
  Future<ShipglowsTrayStartupWindow?> loadStartupWindow() async =>
      _byName(ShipglowsTrayStartupWindow.values, await _read('startupWindow'));

  @override
  Future<bool> saveStartupWindow(ShipglowsTrayStartupWindow window) =>
      _write('startupWindow', window.name);

  Future<Object?> _read(String key) async {
    final document = await readTrayDocument(appFolder);
    return document is Map ? document[key] : null;
  }

  /// Rewrites the file with [key] changed, keeping the other choices.
  Future<bool> _write(String key, String value) async {
    final document = await readTrayDocument(appFolder);
    return writeTrayDocument(appFolder, {
      if (document is Map) ...document,
      'version': 1,
      key: value,
    });
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Kept for the life of the process only.
class ShipglowsTrayMemoryStore implements ShipglowsTrayStore {
  ShipglowsTrayMemoryStore([this._behavior]);

  ShipglowsTrayCloseBehavior? _behavior;
  ShipglowsTrayStartupWindow? _startupWindow;

  @override
  Future<ShipglowsTrayCloseBehavior?> load() async => _behavior;

  @override
  Future<bool> save(ShipglowsTrayCloseBehavior behavior) async {
    _behavior = behavior;
    return true;
  }

  @override
  Future<ShipglowsTrayStartupWindow?> loadStartupWindow() async =>
      _startupWindow;

  @override
  Future<bool> saveStartupWindow(ShipglowsTrayStartupWindow window) async {
    _startupWindow = window;
    return true;
  }
}
