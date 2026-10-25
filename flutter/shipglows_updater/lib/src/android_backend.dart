import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_version.dart';
import 'update_release.dart';
import 'update_state.dart';
import 'updater_backend.dart';
import 'updater_config.dart';

/// Android outside the Play Store: reads the JSON manifest, downloads the
/// APK into the app cache, then the plugin checks its SHA-256, package name,
/// version and signing certificate before it opens the system installer.
/// Android itself refuses an update signed with another key; the checks
/// give a clear error first and never hand an unverified file over.
final class AndroidUpdaterBackend implements UpdaterBackend {
  AndroidUpdaterBackend({
    required this.manifestUrl,
    this.channel = const MethodChannel('shipglows_updater'),
  });

  /// Installs from here take their updates from the store.
  static const playStore = 'com.android.vending';
  static const _connectTimeout = Duration(seconds: 20);
  static const _idleTimeout = Duration(seconds: 30);

  final Uri manifestUrl;
  final MethodChannel channel;
  ValueSetter<ShipglowsUpdateState> _emit = _ignore;
  AppVersion? _current;
  Directory? _updatesDir;
  ShipglowsRelease? _release;
  Timer? _timer;
  bool _installing = false;

  static void _ignore(ShipglowsUpdateState _) {}

  @override
  AppVersion? get currentVersion => _current;

  @override
  Future<bool> start({
    required ShipglowsUpdaterConfig config,
    required ValueSetter<ShipglowsUpdateState> emit,
    required Future<void> Function()? quitForUpdate,
  }) async {
    final info = await channel.invokeMapMethod<String, Object?>('info');
    if (info == null || info['installer'] == playStore) return false;
    final name = AppVersion.tryParse(info['versionName'] as String?);
    final code = info['versionCode'];
    _current = name == null
        ? null
        : AppVersion(name.parts, build: code is int ? code : name.build);
    _updatesDir = Directory(info['updatesDir']! as String);
    _emit = emit;
    unawaited(_deleteOldDownloads());
    unawaited(check(userInitiated: false));
    _timer = Timer.periodic(
      config.checkInterval,
      (_) => unawaited(check(userInitiated: false)),
    );
    return true;
  }

  /// A background check reports only its result: a failure stays silent and
  /// the row keeps what it showed.
  @override
  Future<void> check({required bool userInitiated}) async {
    if (_installing) return;
    if (userInitiated) _emit(const ShipglowsUpdateChecking());
    try {
      final release = await _fetchManifest();
      final current = _current;
      if (current == null || release.version > current) {
        _release = release;
        _emit(ShipglowsUpdateAvailable(release));
      } else {
        _release = null;
        _emit(ShipglowsUpdateUpToDate(DateTime.now()));
      }
    } on FormatException catch (error) {
      debugPrint('shipglows_updater: bad manifest: $error');
      if (userInitiated) {
        _emit(
          ShipglowsUpdateFailed(
            ShipglowsUpdateError(
              ShipglowsUpdateErrorKind.manifest,
              error.message,
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (userInitiated) {
        _emit(
          ShipglowsUpdateFailed(
            ShipglowsUpdateError(
              ShipglowsUpdateErrorKind.network,
              error.toString(),
            ),
          ),
        );
      }
    }
  }

  @override
  Future<void> install() async {
    if (_installing) return;
    final release = _release;
    if (release == null) return check(userInitiated: true);
    _installing = true;
    try {
      final allowed =
          await channel.invokeMethod<bool>('canRequestInstalls') ?? false;
      if (!allowed) {
        _emit(ShipglowsUpdateNeedsPermission(release));
        await channel.invokeMethod<void>('openInstallPermission');
        return;
      }
      final file = await _download(release);
      await channel.invokeMethod<void>('install', {
        'path': file.path,
        'sha256': release.sha256,
      });
      _emit(ShipglowsUpdateInstalling(release));
    } on PlatformException catch (error) {
      final kind = switch (error.code) {
        'checksum' => ShipglowsUpdateErrorKind.checksum,
        'signature' || 'package' => ShipglowsUpdateErrorKind.signature,
        'downgrade' => ShipglowsUpdateErrorKind.downgrade,
        _ => ShipglowsUpdateErrorKind.install,
      };
      _emit(
        ShipglowsUpdateFailed(
          ShipglowsUpdateError(kind, error.message ?? error.code),
          release: release,
        ),
      );
    } on Exception catch (error) {
      _emit(
        ShipglowsUpdateFailed(
          ShipglowsUpdateError(
            ShipglowsUpdateErrorKind.network,
            error.toString(),
          ),
          release: release,
        ),
      );
    } finally {
      _installing = false;
    }
  }

  @override
  void dispose() => _timer?.cancel();

  Future<ShipglowsRelease> _fetchManifest() async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.getUrl(manifestUrl);
      // The manifest moves on every release: never take a cached copy.
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(_idleTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: manifestUrl);
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_idleTimeout);
      final json = jsonDecode(body);
      if (json is! Map<String, Object?>) {
        throw const FormatException('The update manifest is not an object');
      }
      return ShipglowsRelease.fromJson(json);
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads to `<version>.apk.part`, renamed once complete.
  Future<File> _download(ShipglowsRelease release) async {
    final dir = _updatesDir!;
    await dir.create(recursive: true);
    final name = '${release.version.toString().replaceAll('+', '-')}.apk';
    final target = File('${dir.path}${Platform.pathSeparator}$name');
    final part = File('${target.path}.part');
    _emit(ShipglowsUpdateDownloading(release, null));
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.getUrl(release.url);
      final response = await request.close().timeout(_idleTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: release.url);
      }
      final total = release.size ?? response.contentLength;
      final sink = part.openWrite();
      var received = 0;
      var shown = -1;
      try {
        await for (final chunk in response.timeout(_idleTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            // One state per percent, not one per chunk.
            final percent = received * 100 ~/ total;
            if (percent != shown) {
              shown = percent;
              _emit(
                ShipglowsUpdateDownloading(
                  release,
                  (received / total).clamp(0, 1).toDouble(),
                ),
              );
            }
          }
        }
      } finally {
        await sink.close();
      }
      if (release.size != null && received != release.size) {
        throw HttpException(
          'Received $received bytes, expected ${release.size}',
          uri: release.url,
        );
      }
      if (await target.exists()) await target.delete();
      return part.rename(target.path);
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// APKs from earlier updates: the install that used them is over.
  Future<void> _deleteOldDownloads() async {
    final dir = _updatesDir;
    if (dir == null || !await dir.exists()) return;
    try {
      await for (final entry in dir.list()) {
        await entry.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      debugPrint('shipglows_updater: could not clean $dir: $error');
    }
  }
}
