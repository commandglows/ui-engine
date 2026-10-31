import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'capture_camera.dart';

enum CameraTakeKind { video, photo }

/// A finished video or photo. The file stays where the plugin wrote it (a
/// temporary or app folder): the app moves or copies it where it belongs.
@immutable
class CameraTake {
  const CameraTake({
    required this.kind,
    required this.file,
    required this.camera,
    required this.capturedAt,
    this.duration = Duration.zero,
    this.withSound = false,
  });

  final CameraTakeKind kind;

  /// The recorded file; on the web a blob, read it with [XFile.readAsBytes].
  final XFile file;

  final CaptureCamera camera;

  /// When the recording started, or the photo was taken.
  final DateTime capturedAt;

  /// Recorded time, pauses left out; zero for a photo.
  final Duration duration;

  /// The video has a sound track (false when the microphone was refused).
  final bool withSound;

  String get path => file.path;
}
