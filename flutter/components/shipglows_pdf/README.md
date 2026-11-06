# shipglows_pdf

Lecteur PDF partagé pour les apps ShipGlows, extrait du viewer de BeatGlows.

- **Rôle** : affiche un PDF page par page, en défilement complet ou automatique, avec zoom et choix du nombre de pages visibles.
- **API** : `PdfDocumentViewer(path, title, initialPosition, onPositionChanged, toolbarBuilder)` ; `DocumentPosition` (carte sauvegardable de la position de lecture).
- **Dépendances** : `flutter`, `pdfx` 2.11.0. Aucun code d'une app ShipGlows.
- **Limites** : rendu natif via pdfx (non vérifié ici hors tests unitaires) ; libellés en français en dur ; tokens de design copiés en constantes locales ; couleurs issues du `ColorScheme` du thème.
