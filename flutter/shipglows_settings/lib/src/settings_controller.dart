import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'setting_key.dart';
import 'settings_remote.dart';
import 'settings_schema.dart';
import 'settings_storage.dart';
import 'sync_status.dart';

/// Reads settings saved by an older version of the app (one secure-storage
/// key per field, a SharedPreferences prefix...), field id to raw value.
/// Called once, on a device that has no settings file yet.
typedef LegacySettingsImport = Future<Map<String, Object?>?> Function();

/// The account whose settings are shown, and the remote copy to sync with.
class SettingsAccount {
  const SettingsAccount({required this.id, this.remote});

  /// Stable account id (Firebase uid, Clerk user id, email).
  final String id;

  /// `null` keeps this account's settings on the device only (no
  /// entitlement, demo).
  final SettingsRemote? remote;
}

/// Batches several changes into one save and one push.
class SettingsEditor {
  SettingsEditor._();

  final Map<SettingKey<Object?>, Object?> _changes = {};

  void set<T>(SettingKey<T> key, T value) => _changes[key] = key.write(value);

  void reset(SettingKey<Object?> key) => _changes[key] = null;
}

/// Holds every setting of an app, saved on the device first, then pushed to
/// the signed-in account's remote, field by field.
///
/// Rules:
/// - A write lands in the device file before [set] returns; a remote failure
///   never rolls it back, it stays pending and is retried (on a timer with
///   backoff, on app resume, on [sync]).
/// - Only the changed fields are pushed, so two screens editing different
///   settings never overwrite each other.
/// - A pending field keeps its device value until the remote accepts it;
///   every other field follows the remote (last write to reach it wins).
/// - Each account has its own device copy: switching account never shows or
///   pushes another account's values. The first sign-in on a device adopts
///   the signed-out values only when the account has no remote copy yet.
class SettingsController extends ChangeNotifier with WidgetsBindingObserver {
  SettingsController({
    required this.schema,
    required SettingsStorage storage,
    this.retryInterval = const Duration(seconds: 30),
    this.maxRetryInterval = const Duration(minutes: 5),
    this.remoteTimeout = const Duration(seconds: 10),
    this.observeAppLifecycle = true,
    DateTime Function()? clock,
    this.onError,
  }) : _storage = storage,
       _clock = clock ?? DateTime.now;

  static const deviceBucket = 'device';
  static const localAccountBucket = 'account.local';

  /// File-safe bucket name of [accountId].
  static String accountBucket(String accountId) =>
      'account.${accountId.replaceAllMapped(RegExp(r'[^A-Za-z0-9_-]'), (m) => '~${m[0]!.codeUnitAt(0).toRadixString(16)}')}';

  final SettingsSchema schema;
  final SettingsStorage _storage;

  /// First retry delay after a failed sync; doubles up to [maxRetryInterval].
  final Duration retryInterval;
  final Duration maxRetryInterval;

  /// Past this delay an offline call is reported as pending instead of
  /// leaving the UI waiting.
  final Duration remoteTimeout;

  /// Syncs again when the app comes back to the foreground.
  final bool observeAppLifecycle;

  final DateTime Function() _clock;

  /// Every swallowed failure (`settings_cloud_push_error`...), for the app's
  /// diagnostics.
  final void Function(String code, Object error)? onError;

  _Bucket _device = _Bucket(deviceBucket);
  _Bucket _account = _Bucket(localAccountBucket);
  String? _accountId;
  SettingsRemote? _remote;

  /// Bumped on every account switch: results of an older sync are dropped.
  int _generation = 0;

  /// Bumped per field on every edit: a push only clears what it sent.
  final Map<String, int> _edits = {};

  SyncStatus _status = const SyncStatus.localOnly();
  Future<void>? _syncing;
  bool _syncAgain = false;
  Timer? _retryTimer;
  Duration? _retryDelay;
  StreamSubscription<RemoteSettings?>? _watch;
  bool _open = false;
  bool _disposed = false;
  final Map<String, _SettingListenable<Object?>> _listenables = {};

  /// Whether [open] finished: before, every setting reads as its default.
  bool get isOpen => _open;

  /// The account shown, or `null` when signed out.
  String? get accountId => _accountId;

  SyncStatus get status => _status;

  /// Loads the device copies (running [importLegacy] on a fresh device).
  Future<void> open({LegacySettingsImport? importLegacy}) async {
    final device = await _load(deviceBucket);
    final local = await _load(localAccountBucket);
    if (device == null && local == null && importLegacy != null) {
      final legacy = await importLegacy();
      if (legacy != null && legacy.isNotEmpty) {
        _device = _Bucket(deviceBucket);
        _account = _Bucket(localAccountBucket);
        for (final key in schema.keys) {
          if (!legacy.containsKey(key.id) || legacy[key.id] == null) continue;
          final encoded = key.write(key.read(legacy[key.id]));
          if (encoded == null) continue;
          (key.isSynced ? _account : _device).values[key.id] = encoded;
        }
        await _persist(_device, rethrowError: false);
        await _persist(_account, rethrowError: false);
      }
    } else {
      _device = device ?? _Bucket(deviceBucket);
      _account = local ?? _Bucket(localAccountBucket);
    }
    _open = true;
    if (observeAppLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    _changed();
  }

  /// The value of [key] (its default until set, or when the stored data is
  /// unusable).
  T get<T>(SettingKey<T> key) {
    assert(schema.contains(key), '$key is not in the schema.');
    final values = (key.isSynced ? _account : _device).values;
    return key.read(values[key.id], present: values.containsKey(key.id));
  }

  /// Notifies only when [key] changes value.
  ValueListenable<T> listenable<T>(SettingKey<T> key) {
    assert(schema.contains(key), '$key is not in the schema.');
    final listenable = _listenables.putIfAbsent(
      key.id,
      () => _SettingListenable<T>(this, key),
    );
    return listenable as ValueListenable<T>;
  }

  /// Saves [value] on the device (throws [SettingsStorageException] when that
  /// fails), then pushes it.
  Future<void> set<T>(SettingKey<T> key, T value) =>
      edit((editor) => editor.set(key, value));

  /// Puts [key] back to its default, everywhere.
  Future<void> reset(SettingKey<Object?> key) =>
      edit((editor) => editor.reset(key));

  /// Applies several changes with one device write and one push.
  Future<void> edit(void Function(SettingsEditor editor) changes) async {
    final editor = SettingsEditor._();
    changes(editor);
    var deviceChanged = false;
    var accountChanged = false;
    editor._changes.forEach((key, encoded) {
      assert(schema.contains(key), '$key is not in the schema.');
      final bucket = key.isSynced ? _account : _device;
      final before = bucket.values[key.id];
      if (_sameJson(before, encoded)) return;
      if (encoded == null) {
        bucket.values.remove(key.id);
      } else {
        bucket.values[key.id] = encoded;
      }
      if (key.isSynced) {
        accountChanged = true;
        if (_remote != null) {
          bucket.pending.add(key.id);
          _edits[key.id] = (_edits[key.id] ?? 0) + 1;
        }
      } else {
        deviceChanged = true;
      }
    });
    if (!deviceChanged && !accountChanged) return;
    _changed();
    if (deviceChanged) await _persist(_device);
    if (accountChanged) {
      final account = _account;
      await _persist(account);
      if (account.pending.isNotEmpty && identical(account, _account)) {
        _setStatus(_pendingStatus(account));
        unawaited(sync());
      }
    }
  }

  /// Shows [account]'s settings, or the signed-out copy when `null`.
  Future<void> setAccount(SettingsAccount? account) async {
    if (account?.id == _accountId) {
      if (account != null && !identical(account.remote, _remote)) {
        _remote = account.remote;
        _restartWatch();
        unawaited(sync());
      }
      return;
    }
    final generation = ++_generation;
    _stopRemote();
    if (account == null) {
      final local = await _load(localAccountBucket);
      if (generation != _generation) return;
      _account = local ?? _Bucket(localAccountBucket);
      _accountId = null;
      _remote = null;
      _setStatus(const SyncStatus.localOnly(), notify: false);
      _changed();
      return;
    }
    final bucketName = accountBucket(account.id);
    var bucket = await _load(bucketName);
    if (generation != _generation) return;
    if (bucket == null) {
      final local = await _load(localAccountBucket) ?? _Bucket(localAccountBucket);
      bucket = _Bucket(bucketName)
        ..values.addAll(local.values)
        ..seed = local.values.isNotEmpty && account.remote != null;
      await _persist(bucket, rethrowError: false);
      if (generation != _generation) return;
    }
    _account = bucket;
    _accountId = account.id;
    _remote = account.remote;
    _setStatus(
      _remote == null ? const SyncStatus.localOnly() : _pendingStatus(bucket),
      notify: false,
    );
    _changed();
    _restartWatch();
    unawaited(sync());
  }

  /// Deletes the device copy of [accountId] (sign-out with "forget me").
  Future<void> forgetAccount(String accountId) async {
    if (accountId == _accountId) await setAccount(null);
    await _storage.delete(accountBucket(accountId));
  }

  /// Pulls then pushes now. Never throws: the outcome is in [status].
  Future<void> sync() {
    if (_remote == null || _disposed) return Future.value();
    final running = _syncing;
    if (running != null) {
      _syncAgain = true;
      return running;
    }
    _retryTimer?.cancel();
    final run = _runSync().whenComplete(() {
      _syncing = null;
      if (_syncAgain && !_disposed) {
        _syncAgain = false;
        unawaited(sync());
      }
    });
    _syncing = run;
    return run;
  }

  /// Raw stored values of the shown account and device, for diagnostics.
  Map<String, Object?> debugValues() => {
    ..._device.values,
    ..._account.values,
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  @override
  void dispose() {
    _disposed = true;
    _stopRemote();
    if (_open && observeAppLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    for (final listenable in _listenables.values) {
      listenable.dispose();
    }
    super.dispose();
  }

  Future<void> _runSync() async {
    final generation = _generation;
    final remote = _remote;
    final bucket = _account;
    if (remote == null) return;
    _setStatus(
      SyncStatus(
        health: SyncHealth.syncing,
        pendingCount: bucket.pending.length,
        lastSyncedAt: bucket.syncedAt,
      ),
    );
    try {
      final document = await remote.fetch().timeout(remoteTimeout);
      if (generation != _generation) return;
      if (bucket.seed) {
        bucket.seed = false;
        if (document == null || document.isEmpty) {
          // New account: keep what the user chose while signed out.
          for (final key in schema.inScope(SettingScope.account)) {
            if (bucket.values.containsKey(key.id)) {
              bucket.pending.add(key.id);
              _edits[key.id] = (_edits[key.id] ?? 0) + 1;
            }
          }
        } else {
          bucket.pending.clear();
        }
      }
      var changed = document != null && _applyRemote(bucket, document);

      if (bucket.pending.isNotEmpty) {
        final sent = {for (final id in bucket.pending) id: _edits[id] ?? 0};
        final changes = {for (final id in sent.keys) id: bucket.values[id]};
        final result = await remote.push(changes).timeout(remoteTimeout);
        if (generation != _generation) return;
        sent.forEach((id, edit) {
          if ((_edits[id] ?? 0) == edit) bucket.pending.remove(id);
        });
        if (result != null) changed = _applyRemote(bucket, result) || changed;
      }

      bucket.syncedAt = _clock().toUtc();
      _retryDelay = null;
      await _persist(bucket, rethrowError: false);
      if (generation != _generation) return;
      if (changed) _changed();
      _setStatus(
        bucket.pending.isEmpty
            ? SyncStatus(health: SyncHealth.synced, lastSyncedAt: bucket.syncedAt)
            : _pendingStatus(bucket),
      );
    } on SettingsRemoteAuthException catch (error) {
      if (generation != _generation) return;
      onError?.call('settings_cloud_auth_error', error);
      _setStatus(_failed(bucket, 'auth', error.message, retryable: false));
    } on TimeoutException catch (error) {
      if (generation != _generation) return;
      onError?.call('settings_cloud_timeout', error);
      _setStatus(_failed(bucket, 'timeout', 'The remote did not answer.'));
      _scheduleRetry();
    } catch (error) {
      if (generation != _generation) return;
      onError?.call('settings_cloud_sync_error', error);
      _setStatus(_failed(bucket, 'remote_error', '$error'));
      _scheduleRetry();
    }
  }

  /// Takes the remote value of every field not pending here; returns whether
  /// a value changed.
  bool _applyRemote(_Bucket bucket, RemoteSettings document) {
    final from = document.schemaVersion;
    final values = from != null && from < schema.version
        ? schema.migrate(document.values, from)
        : document.values;
    var changed = false;
    for (final key in schema.inScope(SettingScope.account)) {
      if (bucket.pending.contains(key.id)) continue;
      final raw = values[key.id];
      final encoded = raw == null ? null : key.write(key.read(raw));
      if (_sameJson(bucket.values[key.id], encoded)) continue;
      changed = true;
      if (encoded == null) {
        bucket.values.remove(key.id);
      } else {
        bucket.values[key.id] = encoded;
      }
    }
    bucket.revision = document.revision ?? bucket.revision;
    return changed;
  }

  void _restartWatch() {
    _watch?.cancel();
    _watch = null;
    final stream = _remote?.watch();
    if (stream == null) return;
    final generation = _generation;
    _watch = stream.listen(
      (document) async {
        final bucket = _account;
        if (generation != _generation || document == null || bucket.seed) {
          return;
        }
        if (_applyRemote(bucket, document)) {
          _changed();
          await _persist(bucket, rethrowError: false);
        }
      },
      onError: (Object error) =>
          onError?.call('settings_cloud_watch_error', error),
    );
  }

  void _stopRemote() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryDelay = null;
    _watch?.cancel();
    _watch = null;
    _syncAgain = false;
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final previous = _retryDelay;
    final delay = previous == null
        ? retryInterval
        : Duration(
            microseconds: math.min(
              previous.inMicroseconds * 2,
              maxRetryInterval.inMicroseconds,
            ),
          );
    _retryDelay = delay;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(sync()));
  }

  SyncStatus _pendingStatus(_Bucket bucket) => bucket.pending.isEmpty
      ? SyncStatus(health: SyncHealth.synced, lastSyncedAt: bucket.syncedAt)
      : SyncStatus(
          health: SyncHealth.pending,
          pendingCount: bucket.pending.length,
          lastSyncedAt: bucket.syncedAt,
        );

  SyncStatus _failed(
    _Bucket bucket,
    String code,
    String message, {
    bool retryable = true,
  }) => SyncStatus(
    health: retryable && bucket.pending.isNotEmpty
        ? SyncHealth.pending
        : SyncHealth.failed,
    pendingCount: bucket.pending.length,
    lastSyncedAt: bucket.syncedAt,
    issue: SyncIssue(
      code: code,
      message: message,
      occurredAt: _clock().toUtc(),
      retryable: retryable,
    ),
  );

  void _setStatus(SyncStatus status, {bool notify = true}) {
    if (status == _status) return;
    _status = status;
    if (notify) _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<_Bucket?> _load(String name) async {
    final Map<String, Object?>? data;
    try {
      data = await _storage.read(name);
    } catch (error) {
      // An unreadable file must not block the app: start from defaults.
      onError?.call(
        'settings_local_read_error',
        SettingsStorageException('read', name, error),
      );
      return null;
    }
    if (data == null) return null;
    final bucket = _Bucket.fromJson(name, data);
    final version = data['v'] is int ? data['v'] as int : 1;
    if (version < schema.version) {
      final migrated = schema.migrate(bucket.values, version);
      bucket.values
        ..clear()
        ..addAll(migrated);
      await _persist(bucket, rethrowError: false);
    }
    return bucket;
  }

  Future<void> _persist(_Bucket bucket, {bool rethrowError = true}) async {
    try {
      await _storage.write(bucket.name, bucket.toJson(schema.version));
    } catch (error) {
      final failure = SettingsStorageException('write', bucket.name, error);
      onError?.call('settings_local_write_error', failure);
      if (rethrowError) throw failure;
    }
  }

  static bool _sameJson(Object? a, Object? b) {
    if (identical(a, b) || a == b) return true;
    if (a == null || b == null) return false;
    return jsonEncode(a) == jsonEncode(b);
  }
}

class _Bucket {
  _Bucket(this.name);

  factory _Bucket.fromJson(String name, Map<String, Object?> data) {
    final bucket = _Bucket(name);
    final values = data['values'];
    if (values is Map) bucket.values.addAll(values.cast<String, Object?>());
    final pending = data['pending'];
    if (pending is List) bucket.pending.addAll(pending.whereType<String>());
    bucket.seed = data['seed'] == true;
    bucket.revision = data['revision'] is String ? data['revision'] as String : null;
    bucket.syncedAt = data['syncedAt'] is String
        ? DateTime.tryParse(data['syncedAt'] as String)
        : null;
    return bucket;
  }

  final String name;
  final Map<String, Object?> values = {};

  /// Fields changed here and not accepted by the remote yet.
  final Set<String> pending = {};

  /// The device values were copied from the signed-out copy and must only be
  /// pushed if the remote turns out empty.
  bool seed = false;
  String? revision;
  DateTime? syncedAt;

  Map<String, Object?> toJson(int version) => {
    'v': version,
    'values': values,
    if (pending.isNotEmpty) 'pending': pending.toList()..sort(),
    if (seed) 'seed': true,
    if (revision != null) 'revision': revision,
    if (syncedAt != null) 'syncedAt': syncedAt!.toUtc().toIso8601String(),
  };
}

class _SettingListenable<T> extends ChangeNotifier
    implements ValueListenable<T> {
  _SettingListenable(SettingsController controller, SettingKey<T> key)
    : _controller = controller,
      _key = key,
      _value = controller.get(key) {
    controller.addListener(_update);
  }

  final SettingsController _controller;
  final SettingKey<T> _key;
  T _value;

  @override
  T get value => _value;

  void _update() {
    final next = _controller.get(_key);
    if (SettingsController._sameJson(_key.write(next), _key.write(_value))) {
      return;
    }
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    super.dispose();
  }
}
