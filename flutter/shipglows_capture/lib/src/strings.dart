import 'package:flutter/widgets.dart';

import 'camera/camera_failure.dart';
import 'camera/capture_camera.dart';

/// Texts of the capture widgets. The app picks the language: [en], [fr], or
/// its own values, once for the app with [ShipglowsCaptureStringsScope].
@immutable
class ShipglowsCaptureStrings {
  const ShipglowsCaptureStrings({
    required this.frontCamera,
    required this.backCamera,
    required this.externalCamera,
    required this.chooseCamera,
    required this.switchCamera,
    required this.refreshCameras,
    required this.openCamera,
    required this.opening,
    required this.record,
    required this.stop,
    required this.pause,
    required this.resume,
    required this.paused,
    required this.takePhoto,
    required this.finishing,
    required this.videoDone,
    required this.photoDone,
    required this.retry,
    required this.noSound,
    required this.noCamera,
    required this.permissionDenied,
    required this.unsupported,
    required this.failed,
  });

  /// Names of the cameras that have none of their own (phones).
  final String frontCamera;
  final String backCamera;
  final String externalCamera;

  final String chooseCamera;
  final String switchCamera;

  /// Lists the cameras again, for one plugged in since.
  final String refreshCameras;

  final String openCamera;
  final String opening;
  final String record;
  final String stop;
  final String pause;
  final String resume;

  /// Shown on the preview while the video is paused.
  final String paused;

  final String takePhoto;

  /// Shown on the preview while the stopped video is being written.
  final String finishing;

  /// Shown on the preview for a moment once a take is done.
  final String videoDone;
  final String photoDone;

  final String retry;

  /// The microphone was refused: videos are recorded without sound.
  final String noSound;

  /// One message per [CameraFailureCode], saying what to do.
  final String noCamera;
  final String permissionDenied;
  final String unsupported;
  final String failed;

  static const en = ShipglowsCaptureStrings(
    frontCamera: 'Front camera',
    backCamera: 'Back camera',
    externalCamera: 'External camera',
    chooseCamera: 'Choose camera',
    switchCamera: 'Switch camera',
    refreshCameras: 'Refresh the camera list',
    openCamera: 'Open camera',
    opening: 'Opening camera…',
    record: 'Record',
    stop: 'Stop',
    pause: 'Pause',
    resume: 'Resume',
    paused: 'Paused',
    takePhoto: 'Take photo',
    finishing: 'Finishing the video…',
    videoDone: 'Video done',
    photoDone: 'Photo taken',
    retry: 'Try again',
    noSound: 'Microphone denied: the video is recorded without sound.',
    noCamera: 'No camera found. Connect one, then try again.',
    permissionDenied:
        'Camera access denied. Allow it in the system settings, then try again.',
    unsupported: 'The camera is not available on this device.',
    failed: 'The camera is not responding. Another app may be using it.',
  );

  static const fr = ShipglowsCaptureStrings(
    frontCamera: 'Caméra avant',
    backCamera: 'Caméra arrière',
    externalCamera: 'Caméra externe',
    chooseCamera: 'Choisir la caméra',
    switchCamera: 'Changer de caméra',
    refreshCameras: 'Actualiser la liste des caméras',
    openCamera: 'Ouvrir la caméra',
    opening: 'Ouverture de la caméra…',
    record: 'Enregistrer',
    stop: 'Arrêter',
    pause: 'Pause',
    resume: 'Reprendre',
    paused: 'En pause',
    takePhoto: 'Prendre une photo',
    finishing: 'Finalisation de la vidéo…',
    videoDone: 'Vidéo terminée',
    photoDone: 'Photo prise',
    retry: 'Réessayer',
    noSound: 'Micro refusé : la vidéo est enregistrée sans son.',
    noCamera: 'Aucune caméra trouvée.',
    permissionDenied: 'Accès à la caméra refusé dans les réglages du système.',
    unsupported: "La caméra n'est pas disponible sur cet appareil.",
    failed:
        'La caméra ne répond pas. Elle est peut-être utilisée par une autre app.',
  );

  /// The [ShipglowsCaptureStringsScope] above [context]; without one, [fr]
  /// when the app locale is French, [en] otherwise.
  static ShipglowsCaptureStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShipglowsCaptureStringsScope>()
          ?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

  /// The camera's own name, else its facing, numbered when several share it.
  String cameraLabel(CaptureCamera camera) {
    final name = camera.name;
    if (name != null) return name;
    final facing = switch (camera.facing) {
      CaptureCameraFacing.front => frontCamera,
      CaptureCameraFacing.back => backCamera,
      CaptureCameraFacing.external => externalCamera,
    };
    return camera.index == 0 ? facing : '$facing ${camera.index}';
  }

  String failureMessage(CameraFailureCode code) => switch (code) {
    CameraFailureCode.noCamera => noCamera,
    CameraFailureCode.permissionDenied => permissionDenied,
    CameraFailureCode.unsupported => unsupported,
    CameraFailureCode.failed => failed,
  };
}

/// The app's own [ShipglowsCaptureStrings] for every capture widget below
/// it, set once (in `MaterialApp.builder`, say) instead of per call.
class ShipglowsCaptureStringsScope extends InheritedWidget {
  const ShipglowsCaptureStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final ShipglowsCaptureStrings strings;

  @override
  bool updateShouldNotify(ShipglowsCaptureStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
