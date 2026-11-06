# shipglows_capture

Package de capture partagé des apps ShipGlows. Première brique : la caméra.

- **Rôle** : lister les caméras (avant/arrière du téléphone, webcam, caméra USB), prévisualiser, enregistrer une vidéo avec le son, prendre une photo, libérer la caméra.
- **Plateformes** : Android, iOS, Windows, web, via le plugin `camera` (`camera_windows` sur Windows, déclaré ici).
- **API** : `CameraCaptureController`, `CameraCapturePanel`, `CameraCapturePreview`, `CameraTake`, `CameraFailure` (codes `CAP_CAMERA_*`), `ShipglowsCaptureStrings` FR/EN. Détail dans le README d'ui-engine.
- **Limites** : pas de pause sur Windows ni sur le web ; le fichier de la prise reste où le plugin l'écrit, l'app le déplace ; sous Windows, le package fixe le débit H.264 (6 Mb/s en 720p) : sans débit, `camera_windows` faisait planter l'encodeur matériel AMD (division par zéro) dès le début de l'enregistrement.
- **Windows** : vérifié dans ContentGlows (écran `/capture/camera`) avec la caméra virtuelle Windows d'un téléphone : photo, vidéo 720p avec le son. Pas encore essayé avec une vraie webcam. En développement, un hot restart avec la caméra ouverte la laisse ouverte côté natif : chaque ouverture échoue ensuite (« Camera with given device id already exists », écrit dans les logs) jusqu'au redémarrage complet de l'app.
- **Android** : vérifié sur Galaxy S21 (aperçu, vidéo 720p avec le son). Le backend Vulkan d'Impeller n'y affiche pas l'aperçu caméra alors que l'enregistrement marche : l'app doit déclarer `io.flutter.embedding.android.ImpellerBackend` = `opengles` dans son manifeste.
- **Suite prévue** : la capture d'écran (aujourd'hui dans le runner Windows de ContentGlows) une fois sa qualité validée, puis la caméra en incrustation sur l'écran.
