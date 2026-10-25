import 'updater_backend.dart';
import 'updater_config.dart';

/// Web: the browser serves the latest version, nothing to install.
UpdaterBackend? createPlatformBackend(ShipglowsUpdaterConfig config) => null;
