import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why the camera cannot be used, by what the user can do about it.
enum CameraFailureCode {
  /// No camera on this device, or none left after one was unplugged.
  noCamera('CAP_CAMERA_NONE'),

  /// The user or a policy refused the camera.
  permissionDenied('CAP_CAMERA_PERMISSION_DENIED'),

  /// The platform has no camera support here (macOS, Linux).
  unsupported('CAP_CAMERA_UNSUPPORTED'),

  /// The camera failed: in use by another app, unplugged, driver error.
  failed('CAP_CAMERA_FAILED');

  const CameraFailureCode(this.code);

  /// Stable code for diagnostics, in the `CAP_*` family of the capture flows.
  final String code;
}

/// A camera failure with its [code] for the user and the plugin's [detail]
/// for the logs (never shown as is: it can hold a device id).
@immutable
class CameraFailure implements Exception {
  const CameraFailure(this.code, [this.detail]);

  /// Maps an error of the `camera` plugin or of the platform.
  factory CameraFailure.from(Object error) => switch (error) {
    final CameraFailure failure => failure,
    CameraException(:final code, :final description) => CameraFailure(
      _permissionCodes.contains(code)
          ? CameraFailureCode.permissionDenied
          : CameraFailureCode.failed,
      '$code: $description',
    ),
    MissingPluginException(:final message) => CameraFailure(
      CameraFailureCode.unsupported,
      message,
    ),
    _ => CameraFailure(CameraFailureCode.failed, '$error'),
  };

  final CameraFailureCode code;
  final String? detail;

  /// The microphone was refused: the plugin reports it while opening the
  /// camera with sound.
  static bool isMicrophoneRefusal(Object error) =>
      error is CameraException && _microphoneCodes.contains(error.code);

  @override
  String toString() =>
      'CameraFailure(${code.code}${detail == null ? '' : ', $detail'})';
}

const _permissionCodes = {
  'CameraAccessDenied',
  'CameraAccessDeniedWithoutPrompt',
  'CameraAccessRestricted',
};

const _microphoneCodes = {
  'AudioAccessDenied',
  'AudioAccessDeniedWithoutPrompt',
  'AudioAccessRestricted',
};
