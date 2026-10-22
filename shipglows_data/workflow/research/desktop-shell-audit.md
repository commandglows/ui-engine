---
artifact: research_note
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: ShipGlows UI Engine
created: "2026-10-22"
updated: "2026-10-22"
status: active
source_skill: sg-engineering
scope: desktop-shell-audit
owner: Diane
confidence: medium
risk_level: low
security_impact: none
docs_impact: yes
linked_systems:
  - ../../technical/context.md
  - ../../../flutter/
depends_on: []
supersedes: []
evidence:
  - "2026-10-22: lecture seule des pubspec, lib/ et windows/runner de ContentGlows, CommandGlows, DreamGlows (+ path_flutter), BeatGlows, ShipGlows app, ReplayGlows ; CommunityGlows (Tauri) comme référence. Rien lancé, rien construit."
next_review: "2027-01-22"
next_step: "Choisir le premier candidat (diagnostics ou réglages) et ouvrir sa tâche dans TASKS.md."
---

# Audit des coquilles desktop

Tout ce que chaque app refait hors métier. Hors périmètre (déjà partagés) :
`shipglows_command_bar`, `_command_bar_window`, `_overlay_window`, `_window`,
`_hotkeys`, `_tray`. Le zoom (`shipglows_flutter_zoom`) est partagé mais vit
dans `shipglows-email-engine`.

Abréviations : CTG ContentGlows (`contentglows/app`), CMG CommandGlows
(`commandglows/commandglows_app`), DG DreamGlows (`dreamglows/windows_app` +
`packages/path_flutter`), BG BeatGlows (`beatglows/app_flutter`), SGA ShipGlows
app (`shipglows_app/app`), RG ReplayGlows (`replayglows/app`), CoG
CommunityGlows (Tauri/Vue, référence).

**ReplayGlows n'a pas de cible Windows** (ni `windows/`, ni `window_manager`) :
web + Android seulement, `shipglows_command_bar` en dépendance git.

## 1. Blocs par app

LOC approximatives (`wc -l`) du code de coquille.

| Bloc | CTG | CMG | DG | BG | SGA | RG | CoG (réf.) |
|---|---|---|---|---|---|---|---|
| Page Paramètres | liste à groupes, 1 630 l. (`settings_screen` + widgets) | hub de pages, ~7 600 l. dont `app_settings.dart` 758 l. (kit de réglages) | dialogue, ~290 l. | éparpillé : boutons d'en-tête + page Stockage 355 l. | panneau, ~400 l. (`settings_panel` + `settings_primitives`) | écran 2 130 l. + `settings_rows` 101 l. | dialogue en cartes, 892 l. |
| Thème clair/sombre/système | oui (SharedPreferences) | oui (local puis Firestore) | oui + 4 préréglages (fichiers .txt) | sombre/clair/contraste, **pas de « système »** (fichiers .txt) | oui, sombre par défaut (SharedPreferences) | oui (Convex + cache local) | Clair/Sombre/Auto (lever/coucher du soleil) |
| Langue | système/en/fr | **non** (FR en dur) | **non** (FR en dur) | **non** (fr_FR fixe) | **non** en live (fr_FR) | oui, en/fr | oui, fr/en |
| À propos / version | ligne « v0.1.0 » **en dur** | non (build info en diagnostic seulement) | version dans le menu tray seulement | non (pubspec 0.1.0 ≠ Runner.rc 1.0.0) | non | « v1.0.0 » en dur + build id | non (diagnostic seulement) |
| Mise à jour | **oui** : `auto_updater` (WinSparkle), 93 l. + Inno Setup + appcast signé DSA | non | non (`onCheckForUpdates` du tray non branché) | non | non | — | non |
| Taille/position fenêtre | `ShipglowsWindowSession` **+ doublon natif** (registre `WindowState\Bounds`) | `ShipglowsWindowSession` | `ShipglowsWindowSession` + registre pour la capture ; min 720×480 Dart ≠ 480×600 natif | `ShipglowsWindowSession` **+ doublon natif** (`WINDOWPLACEMENT` au registre) | `ShipglowsWindowSession` | — | `window-state` |
| Cadre Windows (DWM) suit le thème | non : `UpdateTheme` du gabarit suit le thème **système** | non (idem) | oui, natif : `ApplyWindowChrome` (couleurs de légende en dur en C++, bordure NONE qui peut contrer `ShipglowsWindowFrame`) | non (gabarit) | non (gabarit) | — | sans objet (cadre dessiné) |
| Lancement au démarrage | non | non | non | non | non | — | non |
| Notifications système | non (stub FCM commenté) ; toasts in-app | non ; SnackBars | non ; SnackBars, agenda dans le tray | non ; SnackBar d'annulation | non (stub mort) | Android seulement (FCM + `flutter_local_notifications`) | in-app seulement |
| Journaux / plantages | Sentry (si DSN) + tampon mémoire 250 + rapport copiable, 421 l. | Sentry (si DSN) + tampon 80 + masquage, ~260 l. | **fichier** `dreamglows-crash.log` 256 Ko + rotation, 107 l. | **fichier** `crash.log` 256 Ko, 92 l. (quasi-copie DG) | tampon mémoire 250, 357 l., pas de Sentry | Sentry + tampon 200, 235 l. | bouton « Copier le diagnostic » |
| Connexion | Auth0, protocole `contentglows://`, secure storage | Firebase e-mail/Google + pont d'identité suite, mode local | Google OAuth **loopback** + DPAPI (Agenda) | aucune (clés S3 en secure storage) | Google OAuth **loopback + PKCE** → Firebase | Clerk (web) / Google + Firebase (Android) | Convex Auth, verrou de session + PIN |
| Raccourcis | Ctrl+K, séquences « G puis lettre », aide « ? » 304 l. | Ctrl+K, fiche `/shortcuts` 1 081 l. | Ctrl+K, raccourcis locaux de la capture, **pas d'aide** | gestionnaire `onKeyEvent`, aide F1 127 l. | Ctrl+K, Alt+1..5, **pas d'aide** | registre par page 204 l. + aide 272 l. | ~20 raccourcis modifiables, conflits, Reset |
| Zoom | `FlutterZoomViewport` (Ctrl+molette, Ctrl+0) | idem | idem | idem + `UiScale` 1.2 | idem | non | 75–150 %, Ctrl+= / Ctrl+- / Ctrl+0 |
| Instance unique | native (mutex Auth0 + `WM_COPYDATA`) | non | via `shipglows_tray` | non | non | — | oui (+ liens profonds) |
| Amorçage `main.dart` | 578 l. | 118 + 537 + 439 l. | 85 l. | ~280 l. sur 1 460 | 112 l. | 545 l. | `lib.rs` run() |
| États erreur/vide/chargement | ~1 000 l. | ~2 800 l. (kit `app_components` + `app_primitives`) | `user_facing_error` 58 l. | `feedback.dart` 174 l. + dialogues 108 l. | `safe_error_view` 153 l. | ~480 l. | minimal |
| Accueil / visite guidée | visite 585 l. | onboarding 2 371 l. | mode démo | non | (code mort) | onboarding ~1 900 l. | 2 319 l., versionné |
| Formulaire de retour | 1 044 l. (texte + audio) | non | non | non | (code mort 904 l.) | 1 178 l. (texte + audio) | non |
| Glissement de fenêtre natif | — | — | canal `startWindowDrag` | — | canal `startWindowDrag` | — | — |
| Jetons de design générés | non | non | non | `generate_tokens.py` | `shared-tokens.json` | `generate_tokens.py` (autre JSON) | — |

## 2. Candidats au partage, par gain

Gain ≈ nombre d'apps × code dupliqué (ou manque commun à combler).

| Rang | Candidat | Apps | Code dupliqué | Gain |
|---|---|---|---|---|
| 1 | Diagnostics et plantages | 6 | 90–420 l. par app, 6 variantes | très fort |
| 2 | Kit de réglages + thème + langue + À propos | 6 | 100–750 l. de primitives + stores de thème, 6 variantes | très fort |
| 3 | Cadre DWM qui suit le thème de l'app | 5 Windows | petit, mais faux partout sauf DG (C++ en dur) | fort (bug visible) |
| 4 | Amorçage desktop (fenêtre + session + cadre + zoom + barre flottante) | 5 Windows | 100–300 l. par app, même câblage | fort |
| 5 | Zoom : déplacer dans ui-engine + Ctrl+= / Ctrl+- | 5 | déjà partagé ; manque clavier partout | moyen |
| 6 | États UI (erreur, vide, chargement, confirmation, annulation) | 5 | 60–2 800 l. ; dépend des jetons | moyen (prérequis jetons) |
| 7 | Mise à jour (WinSparkle) | 1 aujourd'hui, 5 à terme | 93 l. + scripts d'installeur/appcast | moyen (manque commun) |
| 8 | Connexion desktop loopback (PKCE, navigateur, DPAPI) | 2–3 (DG, SGA, CMG) | 175–440 l. par app + 155 l. C++ (DG) | moyen |
| 9 | Accueil / visite guidée | 4 | 600–2 400 l., formes différentes | faible à moyen |
| 10 | Formulaire de retour | 2 live (CTG, RG) | ~1 100 l. chacun, même lignée | faible à moyen |
| 11 | Lancement au démarrage | 0 (manque commun) | — | faible, utile aux apps résidentes (CTG, CMG, DG) |
| 12 | Notifications Windows (toast) | 0 (manque commun) | — | faible |

Déjà couverts par un paquet existant, à migrer plutôt qu'à créer :

- **Fiche des raccourcis** : `showCommandBarShortcuts` existe dans
  `shipglows_command_bar` ; remplacerait les aides de CTG, BG, RG, CMG et
  comblerait DG et SGA.
- **Persistance fenêtre** : supprimer les doublons natifs de CTG et BG
  (registre), aligner la taille minimale native de DG.
- **Glissement** : `ShipglowsWindowDragArea` remplace les canaux
  `startWindowDrag` de DG et SGA.
- **Instance unique** : `shipglows_tray` (déjà dans DG) pour CMG et BG ; CTG
  garde son verrou Auth0 (voir TASKS.md).

## 3. Fiche par candidat

### 1. `shipglows_diagnostics` — Dart

- Pose `FlutterError.onError` + `PlatformDispatcher.onError` en chaînant
  l'ancien gestionnaire, sans zone.
- Tampon d'événements en mémoire (taille réglable), masquage des secrets,
  rapport « Copier le diagnostic » (version, build, thème, derniers événements).
- Journal fichier optionnel : 256 Ko, rotation en `.1`, étiquette du moteur
  (principal, capture, barre) comme DG.
- Sentry hors du paquet : simple rappel `onReport` que l'app branche sur son
  `sentry_flutter` (CTG ^9, CMG ^10, RG ^9 : versions différentes).
- Dépendances : `path_provider`. Aucune vers les paquets existants ; la barre
  flottante et l'overlay peuvent l'appeler dans leur `main` secondaire.

### 2. `shipglows_settings` — Dart

- Primitives : section, ligne de choix, interrupteur, curseur, contrôle segmenté
  (base : `app_settings.dart` de CMG, `settings_rows.dart` de RG).
- Gabarit page (hub large) et dialogue (petites apps : DG).
- Sections prêtes : Apparence (clair/sombre/système), Langue, Zoom, À propos
  (version, build, licences, bouton diagnostic), Mises à jour si fournies.
- Store de préférences lu **avant** `runApp` (premier rendu juste, comme RG et
  CoG) ; stockage injectable (fichier, SharedPreferences, nuage).
- Version : `package_info_plus` (lit le VERSIONINFO sur Windows) ou le canal
  `version` déjà natif dans `shipglows_tray` ; supprime les « v0.1.0 » en dur.
- Dépendances : `shipglows_command_bar` (entrée « Paramètres »),
  `shipglows_tray` (menu standard « Paramètres », « Rechercher les mises à
  jour ») en option ; `shipglows_diagnostics` pour le bouton À propos.

### 3. Extension de `shipglows_window` — Dart (FFI DWM existant)

- Ajouter `IMMERSIVE_DARK_MODE`, `CAPTION_COLOR`, `TEXT_COLOR` à
  `applyDwmFrame`, pilotés par la luminosité et les couleurs du thème de
  l'app, réappliqués au changement de thème.
- Supprime `ApplyWindowChrome` de DG (couleurs en dur en C++) et le
  `UpdateTheme` du gabarit dans les 4 autres runners.
- Dépendances : aucune nouvelle.

### 4. `shipglows_desktop_app` — Dart

- Une fonction d'amorçage : `ShipglowsWindow.ensureInitialized` →
  `ShipglowsWindowSession.restore` → préférences → diagnostics → `runApp`, et
  un `builder` qui pose `ShipglowsWindowFrame` + zoom.
- Hôte de la barre flottante (instantanés avec anti-rebond 150 ms,
  `prepare()` après la première image, `commandBarMain`) : copié aujourd'hui
  dans DG (192 l.) et BG (~90 l.).
- Dépendances : `shipglows_window`, `shipglows_command_bar_window`,
  `shipglows_diagnostics`, `shipglows_settings`, zoom ; `shipglows_tray` en
  option. Paquet de composition : à faire après 1 et 2.

### 5. `shipglows_zoom` — Dart

- Déplacer `shipglows_flutter_zoom` de `shipglows-email-engine` vers
  ui-engine (5 apps en dépendent par chemin).
- Ajouter Ctrl+= / Ctrl+- (absents partout), bornes et pas configurables
  (CoG : 75–150 %, pas de 5).
- Dépendances : aucune ; `shipglows_window` persiste déjà le zoom.

### 6. `shipglows_ui_states` — Dart

- Vue d'erreur (code + réessayer + copier), état vide, squelette de
  chargement, dialogue de confirmation, SnackBar d'annulation.
- Prérequis : jetons de design communs (deux générateurs, deux JSON
  aujourd'hui) ou un thème injecté.
- Dépendances : `shipglows_diagnostics` (copier l'erreur).

### 7. `shipglows_updater` — Dart + natif via `auto_updater` (WinSparkle)

- Reprend `windows_app_updater.dart` de CTG : release Windows seulement, flux
  HTTPS, vérification quotidienne, sortie propre avant mise à jour.
- Fournit le script d'appcast signé et le modèle Inno Setup en gabarit.
- Dépendances : `shipglows_tray` (`onCheckForUpdates` déjà prévu),
  `shipglows_settings` (ligne « Rechercher les mises à jour »).

### 8. `shipglows_desktop_auth` — Dart (+ FFI DPAPI)

- Serveur loopback 127.0.0.1 port aléatoire, PKCE, ouverture du navigateur,
  scellement DPAPI des jetons (DG le fait en C++ dans `credential_channel.cpp`).
- Indépendant du fournisseur (Google/Firebase, Auth0) : rend un code ou des
  jetons, l'app finit la connexion.
- Dépendances : aucune vers ui-engine. Peut relever d'un moteur d'identité
  plutôt que de l'UI.

### 9. `shipglows_tour` — Dart

- Surcouche de visite guidée (étapes, cible, progression sauvée) : base
  `in_app_tour` de CTG ; accueil versionné comme CoG.
- Dépendances : `shipglows_settings` (« Revoir l'accueil »).

### 10. `shipglows_feedback` — Dart

- Formulaire texte + audio, file locale hors ligne ; envoi via une interface
  que l'app implémente (backends différents).
- Dépendances : `shipglows_diagnostics` (joindre le rapport), `record`.

### 11. `shipglows_autostart` — Dart (FFI registre)

- Clé `HKCU\…\Run`, lancement réduit dans la zone de notification.
- Dépendances : `shipglows_tray` (démarrer caché), `shipglows_settings`.

### 12. `shipglows_notifications` — natif Win32 (toasts)

- Toasts Windows avec AppUserModelID (CTG en pose déjà un pour sa Jump List).
- Dépendances : `shipglows_tray` (activation qui ramène la fenêtre).

## 4. Incohérences relevées en passant

- CTG et BG enregistrent la position de la fenêtre deux fois (registre + JSON).
- DG : taille minimale 720×480 (Dart) contre 480×600 (natif) ; bordure DWM
  mise à NONE par le runner et gérée aussi par `ShipglowsWindowFrame`.
- BG : version 0.1.0 (pubspec) contre 1.0.0 (Runner.rc).
- `technical/context.md` dit `shipglows_hotkeys` sans consommateur : SGA en
  dépend directement par chemin.
- ReplayGlows dépend de `shipglows_command_bar` par git, pas par chemin.
