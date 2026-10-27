/// Messages between the app's engine and the launcher's engine, on top of
/// the overlay channel.
library;

/// App → launcher: a new snapshot while the launcher is on screen.
const String snapshotMessage = 'floatingLauncher.snapshot';

/// Launcher → app: the action the user clicked (`{'id': String}`).
const String selectMessage = 'floatingLauncher.select';

/// Launcher → app: the bubble itself was clicked.
const String bubbleMessage = 'floatingLauncher.bubble';
