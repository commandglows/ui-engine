/// Notification area (tray) icon for ShipGlows desktop Flutter apps: icon,
/// tooltip, a standard menu each app completes, close-to-tray and single
/// instance. Windows only; elsewhere every call does nothing.
///
/// Menu entries are the shared action menu model of `shipglows_menu`
/// (re-exported here), so the same entries can show in a Flutter menu.
library;

export 'package:shipglows_menu/shipglows_menu_model.dart';

export 'src/tray.dart';
export 'src/tray_close_dialog.dart';
export 'src/tray_config.dart';
export 'src/tray_events.dart';
export 'src/tray_items.dart' hide trayNativeItem;
export 'src/tray_store.dart';
