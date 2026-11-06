/// No file system on this platform.
Future<Object?> readTrayDocument(
  String appFolder, {
  String fileName = 'tray.json',
}) async => null;

Future<bool> writeTrayDocument(
  String appFolder,
  Object document, {
  String fileName = 'tray.json',
}) async => false;
