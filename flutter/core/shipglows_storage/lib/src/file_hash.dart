import 'dart:io';

import 'package:crypto/crypto.dart';

/// The SHA-256 of [file] in lowercase hex, read in chunks so a large file
/// never sits whole in memory.
Future<String> sha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
