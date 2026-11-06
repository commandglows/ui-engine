import 'package:path_provider/path_provider.dart';
import 'package:shipglows_settings_core/shipglows_settings_core.dart';

/// `shipglows.<bucket>.json` in the app support folder
/// (`%APPDATA%\<company>\<app>` on Windows).
Future<SettingsStorage> defaultReviewStorage() async =>
    FileSettingsStorage(await getApplicationSupportDirectory(), prefix: 'shipglows.');
