# shipglows_capture

Package de capture partagé des apps ShipGlows. Première brique : la caméra.

- **Rôle** : lister les caméras (avant/arrière du téléphone, webcam, caméra USB), prévisualiser, enregistrer une vidéo avec le son, prendre une photo, libérer la caméra.
- **Plateformes** : Android, iOS, Windows, web, via le plugin `camera` (`camera_windows` sur Windows, déclaré ici).
- **API** : `CameraCaptureController`, `CameraCapturePanel`, `CameraCapturePreview`, `CameraTake`, `CameraFailure` (codes `CAP_CAMERA_*`), `ShipglowsCaptureStrings` FR/EN. Détail dans le README d'app-engine.
- **Limites** : pas de pause sur Windows ni sur le web ; le fichier de la prise reste où le plugin l'écrit, l'app le déplace ; sous Windows, le package fixe le débit H.264 (6 Mb/s en 720p) : sans débit, `camera_windows` faisait planter l'encodeur matériel AMD (division par zéro) dès le début de l'enregistrement.
- **Windows** : vérifié dans ContentGlows (écran `/capture/camera`) avec la caméra virtuelle Windows d'un téléphone : photo, vidéo 720p avec le son. Pas encore essayé avec une vraie webcam. En développement, un hot restart avec la caméra ouverte la laisse ouverte côté natif : chaque ouverture échoue ensuite (« Camera with given device id already exists », écrit dans les logs) jusqu'au redémarrage complet de l'app.
- **Android** : vérifié sur Galaxy S21 (aperçu, vidéo 720p avec le son). Le backend Vulkan d'Impeller n'y affiche pas l'aperçu caméra alors que l'enregistrement marche : l'app doit déclarer `io.flutter.embedding.android.ImpellerBackend` = `opengles` dans son manifeste.
- **Suite prévue** : la capture d'écran (aujourd'hui dans le runner Windows de ContentGlows) une fois sa qualité validée, puis la caméra en incrustation sur l'écran.

## More

Shared capture package, started with the camera: record a video with sound or
take a photo from a phone's front or back camera, a laptop webcam or a USB
camera, on Android, iOS, Windows and the web. Built on the `camera` plugin;
Windows needs `camera_windows`, which the package lists (it is not endorsed
by `camera`). Depends on `shipglows_icons` and `shipglows_theme`. Screen
capture still lives in ContentGlows; it moves here once its Windows quality is
accepted.

- `CameraCaptureController(resolution:, withSound:)`: `open(cameraId:,
  facing:)` lists the cameras (`CaptureCamera`: `id` to save the choice,
  `facing`, the device's own `name` on Windows and the web, `index` when
  several unnamed cameras share a facing) and opens one; `select`,
  `switchCamera`, `refreshCameras` (lists again, keeps the open camera),
  `startRecording`, `pauseRecording` / `resumeRecording`
  (`CameraCaptureController.canPause`: not on Windows nor the web),
  `stopRecording` and `takePhoto` return a `CameraTake` (file, camera,
  duration with pauses left out, `withSound`); `close` releases the camera
  and returns the video being recorded instead of dropping it. One action at
  a time (`isBusy`, `isFinishing` while the stopped video is written);
  `elapsed` ticks four times a second while recording. On Windows it sets
  the H.264 bitrate, which camera_windows leaves unset.
- Failures are `CameraFailure` codes (`CAP_CAMERA_NONE`,
  `CAP_CAMERA_PERMISSION_DENIED`, `CAP_CAMERA_UNSUPPORTED`,
  `CAP_CAMERA_FAILED`), with the plugin's text kept for the logs only. A
  refused microphone keeps the camera and records without sound
  (`soundRefused`).
- `CameraCapturePanel(controller:, onTake:, cameraId:, facing:,
  onCameraChanged:, allowPhoto:)`: preview with the recording time, then
  « Finishing the video… » and « Video done · 0:06 » / « Photo taken » for
  three seconds; the camera list, always shown (plus a switch button for two
  cameras, and a refresh on desktop and the web), record / stop, pause,
  photo; Space starts or stops the video. On phones it releases the
  camera in the background and hands over the video being recorded.
  `CameraCapturePreview(controller:)` is the preview alone.
- The take's file stays where the plugin wrote it: the app moves it.
- Apps declare the permissions: iOS `NSCameraUsageDescription` and
  `NSMicrophoneUsageDescription` in `Info.plist`; Android gets `CAMERA` and
  `RECORD_AUDIO` from the plugin's manifest.
- `ShipglowsCaptureStrings.fr` / `.en`, `ShipglowsCaptureStringsScope`.
- New base icons `camera`, `switchCamera`, `record`, `stop`, `pause`, `play`.

```dart
final camera = CameraCaptureController();

CameraCapturePanel(
  controller: camera,
  cameraId: savedCameraId,
  onCameraChanged: (camera) => saveCameraId(camera.id),
  onTake: (take) => importCapture(take.path, take.kind),
);
```
