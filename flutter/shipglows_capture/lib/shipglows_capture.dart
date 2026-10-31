/// Capture for ShipGlows Flutter apps. First part: the camera, on Android,
/// iOS, Windows and the web, through the `camera` plugin (`camera_windows`
/// on Windows).
///
/// - [CameraCaptureController]: lists the cameras ([CaptureCamera]), opens
///   one, records a video with sound (pause where the platform can,
///   [CameraCaptureController.canPause]), takes a photo, releases the camera;
///   failures as [CameraFailure] codes.
/// - [CameraCapturePanel]: preview, camera choice, record / stop, pause,
///   photo; each [CameraTake] goes to the app, which keeps the file.
/// - [CameraCapturePreview]: the preview alone.
/// - [ShipglowsCaptureStrings] and [ShipglowsCaptureStringsScope]: the texts.
library;

export 'package:camera/camera.dart' show ResolutionPreset, XFile;

export 'src/camera/camera_capture_controller.dart';
export 'src/camera/camera_capture_panel.dart';
export 'src/camera/camera_failure.dart';
export 'src/camera/camera_take.dart';
export 'src/camera/capture_camera.dart';
export 'src/strings.dart';
