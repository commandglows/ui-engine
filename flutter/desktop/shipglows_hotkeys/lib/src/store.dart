import 'settings.dart';
import 'store_file_stub.dart' if (dart.library.io) 'store_file_io.dart';
import 'trigger.dart';

/// Where [ShipglowsHotkeys] keeps what the user chose: the triggers, and the
/// settings (master switch, programs to leave alone).
///
/// Only choices are kept: an id absent from the map uses its default, an id
/// mapped to null was left unassigned.
abstract interface class ShipglowsHotkeyStore {
  /// The saved choices; empty when there are none or they cannot be read.
  Future<Map<String, ShipglowsTrigger?>> load();

  /// Replaces the saved choices. False when they could not be written.
  Future<bool> save(Map<String, ShipglowsTrigger?> choices);

  /// The saved settings; the defaults when there are none or they cannot be
  /// read.
  Future<ShipglowsHotkeySettings> loadSettings();

  /// Replaces the saved settings. False when they could not be written.
  Future<bool> saveSettings(ShipglowsHotkeySettings settings);
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
  Future<bool> save(Map<String, ShipglowsTrigger?> choices) => _write({
    'hotkeys': {
      for (final MapEntry(:key, :value) in choices.entries)
        key: value?.toJson(),
    },
  });

  @override
  Future<ShipglowsHotkeySettings> loadSettings() async {
    final document = await readHotkeyDocument(appFolder);
    return ShipglowsHotkeySettings.fromJson(
      document is Map ? document['settings'] : null,
    );
  }

  @override
  Future<bool> saveSettings(ShipglowsHotkeySettings settings) =>
      _write({'settings': settings.toJson()});

  /// Changes [part] of the document and keeps the rest as it was.
  Future<bool> _write(Map<String, Object?> part) async {
    final current = await readHotkeyDocument(appFolder);
    return writeHotkeyDocument(appFolder, {
      ...(current is Map ? current.cast<String, Object?>() : const {}),
      'version': 2,
      ...part,
    });
  }
}

/// Choices kept for the life of the process only.
class ShipglowsHotkeyMemoryStore implements ShipglowsHotkeyStore {
  ShipglowsHotkeyMemoryStore([
    Map<String, ShipglowsTrigger?>? choices,
    ShipglowsHotkeySettings? settings,
  ]) : _choices = {...?choices},
       _settings = settings ?? const ShipglowsHotkeySettings();

  Map<String, ShipglowsTrigger?> _choices;
  ShipglowsHotkeySettings _settings;

  @override
  Future<Map<String, ShipglowsTrigger?>> load() async => {..._choices};

  @override
  Future<bool> save(Map<String, ShipglowsTrigger?> choices) async {
    _choices = {...choices};
    return true;
  }

  @override
  Future<ShipglowsHotkeySettings> loadSettings() async => _settings;

  @override
  Future<bool> saveSettings(ShipglowsHotkeySettings settings) async {
    _settings = settings;
    return true;
  }
}
