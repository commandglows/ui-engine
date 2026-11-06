import 'dart:io';

import 'android_backend.dart';
import 'updater_backend.dart';
import 'updater_config.dart';
import 'windows_backend.dart';

UpdaterBackend? createPlatformBackend(ShipglowsUpdaterConfig config) {
  if (Platform.isWindows) {
    final feed = httpsUrl(config.windowsFeedUrl);
    return feed == null ? null : WindowsUpdaterBackend(feedUrl: feed);
  }
  if (Platform.isAndroid) {
    final manifest = httpsUrl(config.androidManifestUrl);
    return manifest == null
        ? null
        : AndroidUpdaterBackend(manifestUrl: manifest);
  }
  return null;
}
