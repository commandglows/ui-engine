import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Which way a camera looks.
enum CaptureCameraFacing { front, back, external }

/// One camera of the device: a phone's front or back camera, a laptop webcam,
/// a USB camera.
@immutable
class CaptureCamera {
  const CaptureCamera({
    required this.description,
    required this.facing,
    this.name,
    this.index = 0,
  });

  /// [description] as listed by the `camera` plugin. [index] numbers the
  /// unnamed cameras sharing one facing (two back cameras: 1 and 2).
  factory CaptureCamera.fromDescription(
    CameraDescription description, {
    int index = 0,
  }) => CaptureCamera(
    description: description,
    facing: switch (description.lensDirection) {
      CameraLensDirection.front => CaptureCameraFacing.front,
      CameraLensDirection.back => CaptureCameraFacing.back,
      CameraLensDirection.external => CaptureCameraFacing.external,
    },
    name: _displayName(description.name),
    index: index,
  );

  /// The plugin's description, for an app that drives `camera` itself.
  final CameraDescription description;

  final CaptureCameraFacing facing;

  /// The device's own name (« Integrated Camera »), on Windows and the web.
  /// Null on phones, whose cameras only have an id: show the facing instead.
  final String? name;

  /// Position among the unnamed cameras of the same [facing], from 1; 0 when
  /// it is the only one.
  final int index;

  /// Stable id of the camera on this device, to save the user's choice.
  String get id => description.name;

  @override
  bool operator ==(Object other) => other is CaptureCamera && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CaptureCamera($id, $facing)';
}

// Windows lists « display name <device id> »; the web lists the label.
// Phones list bare ids, which are no name.
String? _displayName(String raw) {
  if (kIsWeb) return raw.trim().isEmpty ? null : raw.trim();
  if (defaultTargetPlatform != TargetPlatform.windows) return null;
  final match = RegExp(r'^(.*?)\s*<[^<>]*>$').firstMatch(raw);
  final name = (match?.group(1) ?? raw).trim();
  return name.isEmpty ? null : name;
}
