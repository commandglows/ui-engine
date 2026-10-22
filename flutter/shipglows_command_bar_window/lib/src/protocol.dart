/// Messages between the app's engine and the bar's engine, on top of the
/// overlay channel.
library;

/// App → bar: a new snapshot while the bar is open.
const String snapshotMessage = 'commandBar.snapshot';

/// Bar → app: the entry the user chose.
const String selectMessage = 'commandBar.select';

/// Bar → app: what was typed in the bar, on a choice or when it closed, for
/// the app's search history.
const String queryMessage = 'commandBar.query';
