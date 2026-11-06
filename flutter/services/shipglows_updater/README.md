# shipglows_updater

Release updates behind one API, on Windows and Android. Depends on
`auto_updater` (WinSparkle) only; the Android side is the package's own
Kotlin plugin. Debug and profile builds never update (the debug key cannot
take a release APK); web does nothing.

- `ShipglowsUpdater.instance.start(ShipglowsUpdaterConfig(windowsFeedUrl:,
  androidManifestUrl:, checkInterval:), quitForUpdate:)` once after the first
  frame; idempotent, never throws. An empty or non-HTTPS URL turns that
  platform off. `checkNow()` for « Rechercher une mise à jour » (tray
  `onCheckForUpdates`, menu), `install()`, `state` (a
  `ValueListenable<ShipglowsUpdateState>`: idle, checking, up to date,
  available, downloading with progress, needs permission, installing,
  failed with an `ShipglowsUpdateErrorKind`), `currentVersion` (Android).
- Windows: WinSparkle reads the appcast, shows its own window, checks the
  installer's DSA signature against the runner's `DSAPub` resource
  (`DSAPub DSAPEM "winsparkle_dsa_pub.pem"` in `Runner.rc`) and runs it;
  `quitForUpdate` closes the tray first so the installer can replace the
  executable. Taken from ContentGlows (`windows_app_updater.dart`,
  `scripts/package-windows-installer.ps1`, Inno Setup).
- Android: installs from the Play Store (`com.android.vending`) are left to
  the store. Otherwise the app reads `android.json` (`version` `1.2.3+45`,
  `url`, `sha256`, `size`, `publishedAt`, `notesUrl`), compares it with the
  installed `versionName` + `versionCode`, downloads the APK into the cache
  (`shipglows_updates/`, cleared on the next start), and the plugin checks
  SHA-256, package name, a higher `versionCode` and a common signing
  certificate (rotation history included) before it opens the system
  installer through its own `FileProvider`. Without « install unknown apps »
  the state becomes `needsPermission` and the system page opens; `install()`
  again once back. Background checks stay silent on failure.
- The experience, the same on every app: nothing interrupts a session. A
  waiting version is announced at every launch (`ShipglowsUpdateAnnouncer`
  in `MaterialApp.builder`, given the navigator key) until it is installed
  or the person picks « Ne plus me rappeler pour cette version »
  (`skippedVersion` / `onSkipVersion` keep that choice; a newer version is
  announced again). « Plus tard » only closes the dialog. Afterwards a quiet
  `ShipglowsUpdatePill(appName:, compact:)` in the app's chrome (sidebar,
  menu) and `ShipglowsUpdateBadge(child:)` (a dot on the settings icon)
  stay while the update waits.
- `openShipglowsUpdate(context, appName:)` from any entry point:
  `showShipglowsUpdateDialog` on Android (the version and the installed
  one, « Nouveautés » from the manifest's `notes`, what installing does to
  the person's work, then progress, « Masquer » that lets the download carry
  on, the « install unknown apps » step resumed on return, the system
  installer offered again if cancelled, calm errors with « Réessayer »),
  WinSparkle's own window on Windows.
- `ShipglowsUpdateSetting(appName:, strings:)`: the settings row: the state
  as an announced subtitle (or the installed version), « Rechercher une mise
  à jour », « Voir la mise à jour » or « Réessayer »; nothing where the
  updater is inactive. `ShipglowsUpdaterStrings.fr` / `.en` (`{app}`,
  `{version}`, `{current}`, `{percent}`).
- The plugin adds `INTERNET` and `REQUEST_INSTALL_PACKAGES`. A Play Store
  build must remove the second one, which Play restricts:

  ```xml
  <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"
      tools:node="remove" />
  ```

### Publishing

Releases live in one public repository (`dianedef/shipglows-releases`); the
apps' code stays private. `tool/publish-release.ps1 -Repo -App -Apk
-WindowsInstaller -Appcast` puts the files in a versioned release
`<app>-v1.2.3-45` (never replaced; `-Notes` for « Nouveautés »), then
`android.json` and `appcast.xml`
in the rolling `<app>-latest` release, last, so an app never sees a version
whose files are missing. The apps read:

```text
https://github.com/dianedef/shipglows-releases/releases/download/<app>-latest/android.json
https://github.com/dianedef/shipglows-releases/releases/download/<app>-latest/appcast.xml
```

```dart
unawaited(ShipglowsUpdater.instance.start(
  const ShipglowsUpdaterConfig(
    windowsFeedUrl: String.fromEnvironment('WINDOWS_UPDATE_FEED_URL'),
    androidManifestUrl: String.fromEnvironment('ANDROID_UPDATE_MANIFEST_URL'),
  ),
  quitForUpdate: () => ShipglowsTray.instance.quit(),
));
```
