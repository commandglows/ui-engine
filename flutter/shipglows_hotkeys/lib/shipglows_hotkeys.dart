/// System-wide triggers for ShipGlows desktop Flutter apps (Windows; no-op
/// elsewhere): key combinations, a key pressed twice, and mouse gestures
/// (alone or with modifier keys). They fire while the app is in the
/// background or hidden in the tray, each one is tied to an action id, and the
/// user's choices are kept. One trigger per action: one another app owns is
/// reported, never swapped for another.
library;

export 'src/action.dart';
export 'src/diagnostics.dart';
export 'src/hotkey.dart';
export 'src/hotkeys.dart';
export 'src/picker.dart';
export 'src/settings.dart';
export 'src/store.dart';
export 'src/trigger.dart';
