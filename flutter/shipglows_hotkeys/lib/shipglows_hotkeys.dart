/// System-wide hotkeys for ShipGlows desktop Flutter apps (Windows; no-op
/// elsewhere): they fire while the app is in the background or hidden in the
/// tray. One combination per action: one another app owns is reported, never
/// swapped for another, and the user's choices are kept.
library;

export 'src/hotkey.dart';
export 'src/hotkeys.dart';
export 'src/store.dart';
