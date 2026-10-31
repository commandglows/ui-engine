import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import '../strings.dart';
import 'camera_capture_controller.dart';
import 'camera_take.dart';
import 'capture_camera.dart';

/// The live image of [controller]'s camera, letterboxed, with the recording
/// time while recording; « opening », the failure and its retry, or an
/// « Open camera » button otherwise.
class CameraCapturePreview extends StatelessWidget {
  const CameraCapturePreview({super.key, required this.controller});

  final CameraCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radiusMd),
      child: ColoredBox(
        color: theme.surfaceRaised,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _content(context, theme),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ShipglowsTheme theme) {
    final strings = ShipglowsCaptureStrings.of(context);
    final camera = controller.cameraController;
    final previewing =
        controller.status == CameraStatus.ready || controller.isRecording;
    if (previewing && camera != null && camera.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(child: CameraPreview(camera)),
          if (controller.isRecording)
            Positioned(
              top: theme.spaceMd,
              left: theme.spaceMd,
              child: _RecordingBadge(controller: controller),
            ),
        ],
      );
    }
    switch (controller.status) {
      case CameraStatus.failed:
        final failure = controller.failure;
        return _Message(
          icon: 'warning',
          color: theme.danger,
          text: failure == null
              ? strings.failed
              : strings.failureMessage(failure.code),
          action: strings.retry,
          onAction: controller.open,
        );
      case CameraStatus.closed:
        return _Message(
          icon: 'camera',
          color: theme.textMuted,
          action: strings.openCamera,
          onAction: controller.open,
        );
      default:
        return _Message(
          icon: 'loading',
          color: theme.textMuted,
          text: strings.opening,
        );
    }
  }
}

/// A camera recorder: the preview, the camera choice, record / stop, pause /
/// resume where the platform can, and a photo button. Space starts or stops
/// the video while the panel has the focus. Each finished video or photo
/// goes to [onTake].
///
/// The panel opens the camera when shown ([autoOpen]) and, on phones,
/// releases it while the app is in the background: a video being recorded
/// is then finished and handed to [onTake]. The app owns [controller] and
/// disposes it.
class CameraCapturePanel extends StatefulWidget {
  const CameraCapturePanel({
    super.key,
    required this.controller,
    required this.onTake,
    this.cameraId,
    this.facing,
    this.onCameraChanged,
    this.allowPhoto = true,
    this.autoOpen = true,
  });

  final CameraCaptureController controller;
  final ValueChanged<CameraTake> onTake;

  /// The camera to open first, from a saved [onCameraChanged] choice.
  final String? cameraId;

  /// The facing to open when [cameraId] is absent or gone.
  final CaptureCameraFacing? facing;

  /// The camera opened, to save the user's choice.
  final ValueChanged<CaptureCamera>? onCameraChanged;

  final bool allowPhoto;
  final bool autoOpen;

  @override
  State<CameraCapturePanel> createState() => _CameraCapturePanelState();
}

class _CameraCapturePanelState extends State<CameraCapturePanel>
    with WidgetsBindingObserver {
  CaptureCamera? _reported;
  bool _reopen = false;

  // Desktop windows go inactive on focus loss: only phones release the
  // camera in the background.
  static bool get _releasesInBackground =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  CameraCaptureController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_reportCamera);
    if (widget.autoOpen && _controller.status == CameraStatus.closed) {
      unawaited(
        _controller.open(cameraId: widget.cameraId, facing: widget.facing),
      );
    }
  }

  @override
  void didUpdateWidget(CameraCapturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_reportCamera);
      widget.controller.addListener(_reportCamera);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_reportCamera);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_releasesInBackground) return;
    switch (state) {
      case AppLifecycleState.inactive when !_controller.isRecording:
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_controller.status == CameraStatus.closed) return;
        _reopen = true;
        unawaited(_controller.close().then(_deliver));
      case AppLifecycleState.resumed when _reopen:
        _reopen = false;
        unawaited(_controller.open());
      default:
        break;
    }
  }

  void _reportCamera() {
    final camera = _controller.camera;
    if (_controller.status != CameraStatus.ready || camera == _reported) {
      return;
    }
    _reported = camera;
    widget.onCameraChanged?.call(camera!);
  }

  void _deliver(CameraTake? take) {
    if (take != null && mounted) widget.onTake(take);
  }

  Future<void> _toggleRecording() async {
    if (_controller.isRecording) {
      _deliver(await _controller.stopRecording());
    } else {
      await _controller.startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            unawaited(_toggleRecording()),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: CameraCapturePreview(controller: _controller)),
            SizedBox(height: theme.spaceMd),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _Controls(
                controller: _controller,
                allowPhoto: widget.allowPhoto,
                onToggleRecording: _toggleRecording,
                onPhoto: () async => _deliver(await _controller.takePhoto()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.allowPhoto,
    required this.onToggleRecording,
    required this.onPhoto,
  });

  final CameraCaptureController controller;
  final bool allowPhoto;
  final VoidCallback onToggleRecording;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final strings = ShipglowsCaptureStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final status = controller.status;
    final busy = controller.isBusy;
    final recording = controller.isRecording;
    final canRecord = status == CameraStatus.ready || recording;
    final failure = controller.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: theme.spaceSm,
          runSpacing: theme.spaceSm,
          children: [
            if (controller.cameras.length > 1)
              _CameraChoice(controller: controller),
            if (recording)
              FilledButton.icon(
                onPressed: busy ? null : onToggleRecording,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.danger,
                  foregroundColor: theme.onAccent,
                ),
                icon: const ShipglowsIcon('stop'),
                label: Text(strings.stop),
              )
            else
              FilledButton.icon(
                onPressed: canRecord && !busy ? onToggleRecording : null,
                icon: const ShipglowsIcon('record'),
                label: Text(strings.record),
              ),
            if (recording && CameraCaptureController.canPause)
              IconButton(
                onPressed: busy
                    ? null
                    : status == CameraStatus.paused
                    ? controller.resumeRecording
                    : controller.pauseRecording,
                tooltip: status == CameraStatus.paused
                    ? strings.resume
                    : strings.pause,
                icon: ShipglowsIcon(
                  status == CameraStatus.paused ? 'play' : 'pause',
                ),
              ),
            if (allowPhoto && !recording)
              IconButton(
                onPressed: status == CameraStatus.ready && !busy
                    ? onPhoto
                    : null,
                tooltip: strings.takePhoto,
                icon: const ShipglowsIcon('camera'),
              ),
          ],
        ),
        if (controller.soundRefused) ...[
          SizedBox(height: theme.spaceSm),
          Text(
            strings.noSound,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: theme.warning),
          ),
        ],
        if (failure != null && status != CameraStatus.failed) ...[
          SizedBox(height: theme.spaceSm),
          Semantics(
            liveRegion: true,
            child: Text(
              strings.failureMessage(failure.code),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: theme.danger),
            ),
          ),
        ],
      ],
    );
  }
}

class _CameraChoice extends StatelessWidget {
  const _CameraChoice({required this.controller});

  final CameraCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final strings = ShipglowsCaptureStrings.of(context);
    final enabled = controller.canSwitch;
    if (controller.cameras.length == 2) {
      return IconButton(
        onPressed: enabled ? controller.switchCamera : null,
        tooltip: strings.switchCamera,
        icon: const ShipglowsIcon('switchCamera'),
      );
    }
    return Tooltip(
      message: strings.chooseCamera,
      child: DropdownButton<CaptureCamera>(
        value: controller.camera,
        onChanged: enabled
            ? (camera) {
                if (camera != null) unawaited(controller.select(camera));
              }
            : null,
        items: [
          for (final camera in controller.cameras)
            DropdownMenuItem(
              value: camera,
              child: Text(strings.cameraLabel(camera)),
            ),
        ],
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge({required this.controller});

  final CameraCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final strings = ShipglowsCaptureStrings.of(context);
    final paused = controller.status == CameraStatus.paused;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(ShipglowsScale.radiusFull),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spaceSm,
          vertical: theme.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShipglowsIcon(
              paused ? 'pause' : 'record',
              size: ShipglowsScale.iconSm,
              color: paused ? theme.textMuted : theme.danger,
            ),
            SizedBox(width: theme.spaceXs),
            ValueListenableBuilder<Duration>(
              valueListenable: controller.elapsed,
              builder: (context, elapsed, _) => Text(
                paused
                    ? '${_clock(elapsed)} · ${strings.paused}'
                    : _clock(elapsed),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: theme.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    this.text,
    this.action,
    this.onAction,
  });

  final String icon;
  final Color color;
  final String? text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShipglowsIcon(icon, size: ShipglowsScale.iconLg, color: color),
            if (text != null) ...[
              SizedBox(height: theme.spaceSm),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: theme.text),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: theme.spaceMd),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _clock(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = two(duration.inMinutes.remainder(60));
  final seconds = two(duration.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
