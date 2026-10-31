import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'camera_failure.dart';
import 'camera_take.dart';
import 'capture_camera.dart';

/// Where the camera is.
enum CameraStatus {
  /// Not opened yet, or released.
  closed,

  /// Listing the cameras and opening one.
  opening,

  /// Previewing, ready to record or take a photo.
  ready,

  recording,
  paused,

  /// Could not open: see [CameraCaptureController.failure].
  failed,
}

/// Lists the device's cameras, as `availableCameras` does.
typedef CameraLister = Future<List<CameraDescription>> Function();

/// Drives one camera: open, switch, record (pause where the platform can),
/// take a photo, release. One action at a time; an action asked while
/// another runs is ignored ([isBusy]).
///
/// A failure while previewing or recording keeps the camera when it still
/// works and sets [failure]; [CameraStatus.failed] means it could not open.
/// When the microphone is refused, the camera stays usable without sound
/// ([soundRefused]).
class CameraCaptureController extends ChangeNotifier {
  CameraCaptureController({
    this.resolution = ResolutionPreset.high,
    this.withSound = true,
    CameraLister? listCameras,
  }) : _listCameras = listCameras ?? availableCameras;

  final ResolutionPreset resolution;

  /// Record the microphone with the video.
  final bool withSound;

  final CameraLister _listCameras;

  List<CaptureCamera> _cameras = const [];
  CaptureCamera? _camera;
  CameraController? _controller;
  CameraStatus _status = CameraStatus.closed;
  CameraFailure? _failure;
  bool _soundRefused = false;
  String? _cameraError;
  bool _busy = false;
  bool _finishing = false;
  bool _disposed = false;
  int _generation = 0;
  DateTime? _startedAt;
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;

  /// Recorded time of the current video, pauses left out; updated four times
  /// a second while recording.
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// The platforms the camera plugin runs on: Android, iOS, Windows, web.
  static bool get isSupportedPlatform =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.windows => true,
        _ => false,
      };

  /// Pause and resume a video: not on Windows (Media Foundation) nor the web.
  static bool get canPause =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  List<CaptureCamera> get cameras => _cameras;
  CaptureCamera? get camera => _camera;
  CameraStatus get status => _status;
  CameraFailure? get failure => _failure;
  bool get isBusy => _busy || _status == CameraStatus.opening;
  bool get isRecording =>
      _status == CameraStatus.recording || _status == CameraStatus.paused;

  /// The microphone was refused: videos are recorded without sound.
  bool get soundRefused => _soundRefused;

  /// The plugin's controller of the open camera, for its preview.
  CameraController? get cameraController => _controller;

  /// A camera of the list can be chosen now (or the list refreshed).
  bool get canChoose =>
      !isBusy &&
      (_status == CameraStatus.ready ||
          _status == CameraStatus.failed ||
          _status == CameraStatus.closed);

  /// Another camera can be switched to now.
  bool get canSwitch => _cameras.length > 1 && canChoose;

  /// The video was stopped and the plugin is finishing its file.
  bool get isFinishing => _finishing;

  /// Lists the cameras and opens [cameraId] if present, else the first one
  /// facing [facing], else the first listed. Reopening keeps the current
  /// camera when no choice is given.
  Future<void> open({String? cameraId, CaptureCameraFacing? facing}) async {
    if (_disposed || isBusy || isRecording) return;
    final generation = ++_generation;
    _failure = null;
    _set(CameraStatus.opening);
    try {
      final descriptions = await _listCameras();
      if (generation != _generation) return;
      _cameras = _numbered(descriptions);
      if (_cameras.isEmpty) {
        throw const CameraFailure(CameraFailureCode.noCamera);
      }
      await _openCamera(
        _pick(cameraId: cameraId ?? _camera?.id, facing: facing),
        generation,
      );
    } catch (error) {
      if (generation != _generation) return;
      debugPrint('shipglows_capture: camera open failed: $error');
      await _release();
      _failure = CameraFailure.from(error);
      _set(CameraStatus.failed);
    }
  }

  /// Opens [camera] instead of the current one.
  Future<void> select(CaptureCamera camera) async {
    if (!canChoose || (camera == _camera && _status == CameraStatus.ready)) {
      return;
    }
    await open(cameraId: camera.id);
  }

  /// Lists the cameras again, for one plugged in or removed since. The open
  /// camera stays; when it is gone, another one opens.
  Future<void> refreshCameras() async {
    if (_disposed || !canChoose) return;
    _busy = true;
    _notify();
    List<CameraDescription>? descriptions;
    try {
      descriptions = await _listCameras();
    } catch (_) {
      // Keep the current list; opening says what is wrong.
    } finally {
      _busy = false;
    }
    if (_disposed) return;
    if (descriptions != null) _cameras = _numbered(descriptions);
    final current = _camera;
    final kept = _cameras.where((camera) => camera == current).firstOrNull;
    if (kept == null || _status != CameraStatus.ready) {
      await open(cameraId: kept?.id);
      return;
    }
    _camera = kept;
    _notify();
  }

  /// Opens the next camera of the list.
  Future<void> switchCamera() async {
    if (!canSwitch) return;
    final next = (_cameras.indexOf(_camera!) + 1) % _cameras.length;
    await open(cameraId: _cameras[next].id);
  }

  Future<void> startRecording() => _act(() async {
    if (_status != CameraStatus.ready) return;
    try {
      await _controller!.startVideoRecording();
    } catch (error) {
      // Some platforms ask for the microphone only now.
      if (_soundRefused || !CameraFailure.isMicrophoneRefusal(error)) rethrow;
      _soundRefused = true;
      await _openCamera(_camera!, ++_generation);
      await _controller!.startVideoRecording();
    }
    _startedAt = DateTime.now();
    _clock
      ..reset()
      ..start();
    elapsed.value = Duration.zero;
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => elapsed.value = _clock.elapsed,
    );
    _set(CameraStatus.recording);
  });

  Future<void> pauseRecording() => _act(() async {
    if (!canPause || _status != CameraStatus.recording) return;
    await _controller!.pauseVideoRecording();
    _clock.stop();
    _set(CameraStatus.paused);
  });

  Future<void> resumeRecording() => _act(() async {
    if (_status != CameraStatus.paused) return;
    await _controller!.resumeVideoRecording();
    _clock.start();
    _set(CameraStatus.recording);
  });

  /// Ends the video and returns it; null when nothing was recording or the
  /// plugin could not finish the file ([failure] says why).
  Future<CameraTake?> stopRecording() async {
    CameraTake? take;
    await _act(() async {
      if (!isRecording) return;
      _finishing = true;
      _stopClock();
      _notify();
      final XFile file;
      try {
        file = await _controller!.stopVideoRecording();
      } finally {
        _finishing = false;
      }
      elapsed.value = _clock.elapsed;
      take = CameraTake(
        kind: CameraTakeKind.video,
        file: file,
        camera: _camera!,
        capturedAt: _startedAt ?? DateTime.now(),
        duration: elapsed.value,
        withSound: withSound && !_soundRefused,
      );
      _set(CameraStatus.ready);
    });
    return take;
  }

  /// Takes a photo while previewing (not while recording).
  Future<CameraTake?> takePhoto() async {
    CameraTake? take;
    await _act(() async {
      if (_status != CameraStatus.ready) return;
      final capturedAt = DateTime.now();
      final file = await _controller!.takePicture();
      take = CameraTake(
        kind: CameraTakeKind.photo,
        file: file,
        camera: _camera!,
        capturedAt: capturedAt,
      );
    });
    return take;
  }

  /// Releases the camera so another app can use it. A video being recorded
  /// is finished first and returned, never dropped.
  Future<CameraTake?> close() async {
    if (_disposed) return null;
    final take = isRecording ? await stopRecording() : null;
    ++_generation;
    await _release();
    _set(CameraStatus.closed);
    return take;
  }

  /// Forgets the last [failure] once the user has seen it.
  void clearFailure() {
    if (_failure == null || _status == CameraStatus.failed) return;
    _failure = null;
    _notify();
  }

  /// Releases the camera; a video still recording is lost: call [close]
  /// first to keep it.
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _stopClock();
    _controller?.removeListener(_onCameraValue);
    final controller = _controller;
    if (controller != null) unawaited(_disposeQuietly(controller));
    _controller = null;
    elapsed.dispose();
    super.dispose();
  }

  Future<void> _openCamera(CaptureCamera camera, int generation) async {
    await _release();
    _camera = camera;
    _cameraError = null;
    CameraController controller;
    try {
      controller = await _initialized(camera, sound: withSound && !_soundRefused);
    } catch (error) {
      if (_soundRefused || !CameraFailure.isMicrophoneRefusal(error)) rethrow;
      _soundRefused = true;
      controller = await _initialized(camera, sound: false);
    }
    if (generation != _generation || _disposed) {
      await _disposeQuietly(controller);
      return;
    }
    _controller = controller..addListener(_onCameraValue);
    _set(CameraStatus.ready);
  }

  Future<CameraController> _initialized(
    CaptureCamera camera, {
    required bool sound,
  }) async {
    final controller = CameraController(
      camera.description,
      resolution,
      enableAudio: sound,
      videoBitrate: _windowsVideoBitrate(resolution),
    );
    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      await _disposeQuietly(controller);
      rethrow;
    }
  }

  // camera_windows gives the H.264 encoder no bitrate unless asked. With none,
  // a recording on an AMD GPU crashed the app inside the hardware encoder
  // (division by zero). Other platforms pick their own bitrate.
  static int? _windowsVideoBitrate(ResolutionPreset resolution) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;
    return switch (resolution) {
      ResolutionPreset.low => 1000000,
      ResolutionPreset.medium => 2500000,
      ResolutionPreset.high => 6000000,
      ResolutionPreset.veryHigh => 12000000,
      ResolutionPreset.ultraHigh || ResolutionPreset.max => 35000000,
    };
  }

  // Releasing a camera that failed or vanished can throw too; the camera is
  // gone either way and the first error is the one worth reporting.
  static Future<void> _disposeQuietly(CameraController controller) async {
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _release() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    _stopClock();
    controller.removeListener(_onCameraValue);
    await _disposeQuietly(controller);
  }

  // Runs one action; a failure keeps the camera when it still works.
  Future<void> _act(Future<void> Function() action) async {
    if (_disposed || _busy || _controller == null) return;
    _busy = true;
    _failure = null;
    _notify();
    try {
      await action();
    } catch (error) {
      if (!_disposed) {
        _failure = CameraFailure.from(error);
        _syncWithCamera();
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  // Errors reported by the plugin outside an action (camera unplugged,
  // taken by another app).
  void _onCameraValue() {
    final value = _controller?.value;
    if (value == null || value.errorDescription == _cameraError) return;
    _cameraError = value.errorDescription;
    if (_cameraError == null) return;
    debugPrint('shipglows_capture: camera error: $_cameraError');
    _failure = CameraFailure(CameraFailureCode.failed, _cameraError);
    _syncWithCamera();
    _notify();
  }

  void _syncWithCamera() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) {
      _stopClock();
      _status = _controller == null ? _status : CameraStatus.failed;
      return;
    }
    if (value.isRecordingVideo) {
      _status = value.isRecordingPaused
          ? CameraStatus.paused
          : CameraStatus.recording;
    } else {
      _stopClock();
      _status = CameraStatus.ready;
    }
  }

  void _stopClock() {
    _ticker?.cancel();
    _ticker = null;
    _clock.stop();
  }

  CaptureCamera _pick({String? cameraId, CaptureCameraFacing? facing}) {
    for (final camera in _cameras) {
      if (camera.id == cameraId) return camera;
    }
    for (final camera in _cameras) {
      if (camera.facing == facing) return camera;
    }
    return _cameras.first;
  }

  static List<CaptureCamera> _numbered(List<CameraDescription> descriptions) {
    final cameras = [
      for (final description in descriptions)
        CaptureCamera.fromDescription(description),
    ];
    final unnamed = <CaptureCameraFacing, int>{};
    for (final camera in cameras) {
      if (camera.name == null) {
        unnamed.update(camera.facing, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final seen = <CaptureCameraFacing, int>{};
    return [
      for (final camera in cameras)
        if (camera.name == null && unnamed[camera.facing]! > 1)
          CaptureCamera.fromDescription(
            camera.description,
            index: seen.update(camera.facing, (n) => n + 1, ifAbsent: () => 1),
          )
        else
          camera,
    ];
  }

  void _set(CameraStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
