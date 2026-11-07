import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Points `path_provider` at a new temporary folder for the current test, and
/// returns it. The previous platform comes back and the folder goes away when
/// the test ends.
Directory useTemporaryAppFolders() {
  final folder = Directory.systemTemp.createTempSync('shipglows_test_');
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FolderPathProvider(folder.path);
  addTearDown(() {
    PathProviderPlatform.instance = previous;
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });
  return folder;
}

// ignore: invalid_use_of_visible_for_testing_member, this package is test code.
class _FolderPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FolderPathProvider(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => path;

  @override
  Future<String?> getLibraryPath() async => path;

  @override
  Future<String?> getDownloadsPath() async => path;

  @override
  Future<String?> getExternalStoragePath() async => path;
}
