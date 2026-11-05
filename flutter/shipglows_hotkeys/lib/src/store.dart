import 'store_file_stub.dart' if (dart.library.io) 'store_file_io.dart';
import 'trigger.dart';

/// Where [ShipglowsHotkeys] keeps the triggers the user chose. Only choices
/// are kept: an id absent from the map uses its default, an id mapped to
/// null was left unassigned.
abstract interface class ShipglowsHotkeyStore {
  /// The saved choices; empty when there are none or they cannot be read.
  Future<Map<String, ShipglowsTrigger?>> load();

  /// Replaces the saved choices. False when they could not be written.
  Future<bool> save(Map<String, ShipglowsTrigger?> choices);
}

/// Choices kept in `%APPDATA%\<appFolder>\hotkeys.json`, next to the
/// remembered overlay windows (`shipglows_overlay_window`). A file written by
/// an earlier version, which only knew key combinations, is read as is.
class ShipglowsHotkeyFileStore implements ShipglowsHotkeyStore {
  const ShipglowsHotkeyFileStore(this.appFolder);

  final String appFolder;

  @override
  Future<Map<String, ShipglowsTrigger?>> load() async {
    final document = await readHotkeyDocument(appFolder);
    final hotkeys = document is Map ? document['hotkeys'] : null;
    if (hotkeys is! Map) return {};
    final choices = <String, ShipglowsTrigger?>{};
    for (final MapEntry(:key, :value) in hotkeys.entries) {
      if (key is! String) continue;
      final trigger = ShipglowsTrigger.fromJson(value);
      // A value this store never wrote is dropped, not read as unassigned.
      if (value == null || trigger != null) choices[key] = trigger;
    }
    return choices;
  }

  @override
  Future<bool> save(Map<String, ShipglowsTrigger?> choices) =>
      writeHotkeyDocument(appFolder, {
        'version': 2,
        'hotkeys': {
          for (final MapEntry(:key, :value) in choices.entries)
            key: value?.toJson(),
        },
      });
}

/// Choices kept for the life of the process only.
class ShipglowsHotkeyMemoryStore implements ShipglowsHotkeyStore {
  ShipglowsHotkeyMemoryStore([Map<String, ShipglowsTrigger?>? choices])
    : _choices = {...?choices};

  Map<String, ShipglowsTrigger?> _choices;

  @override
  Future<Map<String, ShipglowsTrigger?>> load() async => {..._choices};

  @override
  Future<bool> save(Map<String, ShipglowsTrigger?> choices) async {
    _choices = {...choices};
    return true;
  }
}
