/// System-wide hotkeys for ShipGlows desktop Flutter apps (Windows; no-op
/// elsewhere): they fire while the app is in the background or hidden in the
/// tray, take the first free combination of a list, report the ones another
/// app owns, and keep the user's choices.
library;

export 'src/hotkey.dart';
export 'src/hotkeys.dart';
export 'src/store.dart';
