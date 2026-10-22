/// No file system on this platform.
Future<Object?> readTrayDocument(String appFolder) async => null;

Future<bool> writeTrayDocument(String appFolder, Object document) async =>
    false;
