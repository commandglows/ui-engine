import 'hotkey.dart';
import 'store_file_stub.dart' if (dart.library.io) 'store_file_io.dart';

/// Where [ShipglowsHotkeys] keeps the hotkeys the user chose. Only choices
/// are kept: an id absent from the map uses its candidates, an id mapped to
/// null was left unassigned.
abstract interface class ShipglowsHotkeyStore {
  /// The saved choices; empty when there are none or they cannot be read.
  Future<Map<String, ShipglowsHotkey?>> load();

  /// Replaces the saved choices. False when they could not be written.
  Future<bool> save(Map<String, ShipglowsHotkey?> choices);
}

/// Choices kept in `%APPDATA%\<appFolder>\hotkeys.json`, next to the
/// remembered overlay windows (`shipglows_overlay_window`).
class ShipglowsHotkeyFileStore implements ShipglowsHotkeyStore {
  const ShipglowsHotkeyFileStore(this.appFolder);

  final String appFolder;

  @override
  Future<Map<String, ShipglowsHotkey?>> load() async {
    final document = await readHotkeyDocument(appFolder);
    final hotkeys = document is Map ? document['hotkeys'] : null;
    if (hotkeys is! Map) return {};
    final choices = <String, ShipglowsHotkey?>{};
    for (final MapEntry(:key, :value) in hotkeys.entries) {
      if (key is! String) continue;
      final hotkey = ShipglowsHotkey.fromJson(value);
      // A value this store never wrote is dropped, not read as unassigned.
      if (value == null || hotkey != null) choices[key] = hotkey;
    }
    return choices;
  }

  @override
  Future<bool> save(Map<String, ShipglowsHotkey?> choices) =>
      writeHotkeyDocument(appFolder, {
        'version': 1,
        'hotkeys': {
          for (final MapEntry(:key, :value) in choices.entries)
            key: value?.toJson(),
        },
      });
}

/// Choices kept for the life of the process only.
class ShipglowsHotkeyMemoryStore implements ShipglowsHotkeyStore {
  ShipglowsHotkeyMemoryStore([Map<String, ShipglowsHotkey?>? choices])
    : _choices = {...?choices};

  Map<String, ShipglowsHotkey?> _choices;

  @override
  Future<Map<String, ShipglowsHotkey?>> load() async => {..._choices};

  @override
  Future<bool> save(Map<String, ShipglowsHotkey?> choices) async {
    _choices = {...choices};
    return true;
  }
}
