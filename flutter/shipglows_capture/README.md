# shipglows_capture

Package de capture partagé des apps ShipGlows. Première brique : la caméra.

- **Rôle** : lister les caméras (avant/arrière du téléphone, webcam, caméra USB), prévisualiser, enregistrer une vidéo avec le son, prendre une photo, libérer la caméra.
- **Plateformes** : Android, iOS, Windows, web, via le plugin `camera` (`camera_windows` sur Windows, déclaré ici).
- **API** : `CameraCaptureController`, `CameraCapturePanel`, `CameraCapturePreview`, `CameraTake`, `CameraFailure` (codes `CAP_CAMERA_*`), `ShipglowsCaptureStrings` FR/EN. Détail dans le README d'ui-engine.
- **Limites** : pas de pause sur Windows ni sur le web ; le fichier de la prise reste où le plugin l'écrit, l'app le déplace ; compilé et lancé dans ContentGlows sous Windows (écran `/capture/camera`), enregistrement Windows pas encore vérifié.
- **Android** : vérifié sur Galaxy S21 (aperçu, vidéo 720p avec le son). Le backend Vulkan d'Impeller n'y affiche pas l'aperçu caméra alors que l'enregistrement marche : l'app doit déclarer `io.flutter.embedding.android.ImpellerBackend` = `opengles` dans son manifeste.
- **Suite prévue** : la capture d'écran (aujourd'hui dans le runner Windows de ContentGlows) une fois sa qualité validée, puis la caméra en incrustation sur l'écran.
