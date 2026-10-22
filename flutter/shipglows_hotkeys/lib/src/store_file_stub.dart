/// No file system on this platform.
Future<Object?> readHotkeyDocument(String appFolder) async => null;

Future<bool> writeHotkeyDocument(String appFolder, Object document) async =>
    false;
