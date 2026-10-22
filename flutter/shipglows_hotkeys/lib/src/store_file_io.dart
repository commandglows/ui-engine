import 'dart:convert';
import 'dart:io';

File? _file(String appFolder) {
  final roaming = Platform.environment['APPDATA'];
  if (roaming == null || roaming.isEmpty || appFolder.isEmpty) return null;
  return File('$roaming\\$appFolder\\hotkeys.json');
}

/// The decoded file; null when it is missing or not JSON.
Future<Object?> readHotkeyDocument(String appFolder) async {
  final file = _file(appFolder);
  if (file == null) return null;
  try {
    return jsonDecode(await file.readAsString());
  } on Object {
    return null;
  }
}

/// Writes [document] through a temporary file, so a crash never leaves half a
/// file.
Future<bool> writeHotkeyDocument(String appFolder, Object document) async {
  final file = _file(appFolder);
  if (file == null) return false;
  try {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
      flush: true,
    );
    await temporary.rename(file.path);
    return true;
  } on Object {
    return false;
  }
}
