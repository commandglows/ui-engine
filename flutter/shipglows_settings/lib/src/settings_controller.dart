import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shipglows_sync/shipglows_sync.dart';

import 'setting_key.dart';
import 'settings_remote.dart';
import 'settings_schema.dart';
import 'settings_storage.dart';

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
///   pushes another account's values.
/// - The first sign-in on a device unites the signed-out values with the
///   account's: a value set on one side only is kept; when both sides set a
///   value differently, sync waits for [resolveReview] ([SyncHealth.needsReview])
///   and shows the device values meanwhile. Copies of both sides are kept as
///   a [SyncRecovery] before the merged values are applied.
class SettingsController extends ChangeNotifier
    with WidgetsBindingObserver
    implements SyncSource, SyncReviewHost, SyncRecoveryHost {
  SettingsController({
    required this.schema,
    required SettingsStorage storage,
    this.retryInterval = const Duration(seconds: 30),
    this.maxRetryInterval = const Duration(minutes: 5),
    this.remoteTimeout = const Duration(seconds: 10),
    this.observeAppLifecycle = true,
    this.reviewFirstSync = true,
    this.isTemporaryId,
    SyncProgress? progress,
    DateTime Function()? clock,
    this.onError,
  }) : _storage = storage,
       progress = progress ?? SyncProgress(),
       _ownsProgress = progress == null,
       _clock = clock ?? DateTime.now;

  static const deviceBucket = 'device';
  static const localAccountBucket = 'account.local';

  /// File-safe bucket name of [accountId].
  static String accountBucket(String accountId) =>
      'account.${accountId.replaceAllMapped(RegExp(r'[^A-Za-z0-9_-]'), (m) => '~${m[0]!.codeUnitAt(0).toRadixString(16)}')}';

  /// Bucket of [accountId]'s [SyncRecovery].
  static String recoveryBucket(String accountId) =>
      'recovery.${accountBucket(accountId)}';

  /// `false` keeps the former rule: on a first sign-in, an account that
  /// already has settings replaces the signed-out values without asking.
  final bool reviewFirstSync;

  /// Recognizes the ids of records created offline (`offline-…`). A pending
  /// field holding one stays on the device, shown but not sent, until
  /// [rewriteIds] gives it the server id.
  final TemporaryIdTest? isTemporaryId;

  /// Steps of an account's first sync on this device, for a progress screen.
  final SyncProgress progress;
  final bool _ownsProgress;

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
  StreamSubscription<String>? _storageWatch;

  /// Own writes in flight: a change seen meanwhile is reloaded after them.
  int _writes = 0;
  bool _reloadAfterWrites = false;
  SyncReview? _review;
  bool _resolving = false;
  SyncReviewError? _reviewError;
  SyncRecovery? _recovery;

  /// Whether [open] finished: before, every setting reads as its default.
  bool get isOpen => _open;

  /// The account shown, or `null` when signed out.
  String? get accountId => _accountId;

  @override
  SyncStatus get status => _status;

  @override
  SyncReview? get review => _review;

  @override
  bool get isResolvingReview => _resolving;

  @override
  SyncReviewError? get reviewError => _reviewError;

  @override
  SyncRecovery? get recovery => _recovery;

  /// Loads the device copies (running [importLegacy] on a fresh device).
  ///
  /// With [restoreLastAccount], the last account shown on this device is
  /// shown again right away (without syncing), so its theme paints the first
  /// frame; [setAccount] then confirms it or switches away.
  Future<void> open({
    LegacySettingsImport? importLegacy,
    bool restoreLastAccount = true,
  }) async {
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
      final last = _device.lastAccount;
      if (restoreLastAccount && last != null) {
        final previous = await _load(accountBucket(last));
        if (previous != null) {
          _account = previous;
          _accountId = last;
        }
      }
    }
    _open = true;
    if (observeAppLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    final storage = _storage;
    if (storage is WatchableSettingsStorage) {
      _storageWatch = storage.watch().listen(
        _storageChanged,
        onError: (Object error) =>
            onError?.call('settings_local_watch_error', error),
      );
    }
    _changed();
  }

  /// Reads the shown buckets again, for a change made outside this
  /// controller (another window's engine, another process). Fields pending
  /// here keep their value; every other one takes the stored value.
  Future<void> reload() async {
    final shownDevice = _device;
    final shownAccount = _account;
    final device = await _load(shownDevice.name);
    final account = await _load(shownAccount.name);
    // An account switched meanwhile already loaded its own copy.
    if (!identical(shownAccount, _account) || _disposed) return;
    var changed = false;
    if (device != null) changed = _takeStored(shownDevice, device) || changed;
    if (account != null) changed = _takeStored(shownAccount, account) || changed;
    if (!changed) return;
    _changed();
    if (_account.pending.isNotEmpty) unawaited(sync());
  }

  void _storageChanged(String bucket) {
    if (bucket != _device.name && bucket != _account.name) return;
    if (_writes > 0) {
      _reloadAfterWrites = true;
      return;
    }
    unawaited(reload());
  }

  bool _takeStored(_Bucket shown, _Bucket stored) {
    var changed = false;
    final ids = {...shown.values.keys, ...stored.values.keys};
    for (final id in ids) {
      if (shown.pending.contains(id) ||
          shown.pending.any((entry) => entry.startsWith('$id/'))) {
        continue;
      }
      final value = stored.values[id];
      if (_sameJson(shown.values[id], value)) continue;
      changed = true;
      if (value == null) {
        shown.values.remove(id);
      } else {
        shown.values[id] = value;
      }
    }
    for (final entry in stored.pending) {
      if (shown.pending.add(entry)) changed = true;
    }
    return changed;
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

  /// Sets one nested field of a map setting (`['contentFrequency',
  /// 'linkedin']`), keeping every other field; `null` removes it. With
  /// [SettingKey.mergeFields], only that field is sent.
  Future<void> setField(
    SettingKey<Map<String, Object?>> key,
    List<String> path,
    Object? value,
  ) {
    assert(path.isNotEmpty, 'setField needs a nested field name.');
    final next = _copyJson(get(key)) as Map<String, Object?>;
    _writePath(next, path, value, present: value != null);
    return set(key, next);
  }

  /// Gives the server ids to values that held temporary ones ([ids]:
  /// temporary id to server id), on the device and in pending pushes, then
  /// sends the fields that were waiting for them.
  Future<void> rewriteIds(Map<String, String> ids) async {
    if (ids.isEmpty) return;
    var changed = false;
    for (final bucket in [_device, _account]) {
      var bucketChanged = false;
      for (final entry in bucket.values.entries.toList()) {
        final next = rewriteSyncIds(entry.value, ids);
        if (_sameJson(entry.value, next)) continue;
        bucket.values[entry.key] = next;
        bucketChanged = true;
      }
      if (!bucketChanged) continue;
      changed = true;
      await _persist(bucket, rethrowError: false);
    }
    if (!changed) return;
    _changed();
    unawaited(sync());
  }

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
        if (_remote != null) _markPending(bucket, key, before, encoded);
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
        final generation = _generation;
        _remote = account.remote;
        _recovery ??= await _loadRecovery(account.id);
        if (generation != _generation) return;
        if (_remote != null && _account.syncedAt == null) progress.begin();
        _restartWatch();
        unawaited(sync());
      }
      return;
    }
    final generation = ++_generation;
    _stopRemote();
    _clearReview();
    _recovery = null;
    progress.reset();
    _device.lastAccount = account?.id;
    unawaited(_persist(_device, rethrowError: false));
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
    final recovery = await _loadRecovery(account.id);
    if (generation != _generation) return;
    _account = bucket;
    _accountId = account.id;
    _remote = account.remote;
    _recovery = recovery;
    _setStatus(
      _remote == null ? const SyncStatus.localOnly() : _pendingStatus(bucket),
      notify: false,
    );
    if (_remote != null && bucket.syncedAt == null) progress.begin();
    _changed();
    _restartWatch();
    unawaited(sync());
  }

  /// Deletes the device copy of [accountId] (sign-out with "forget me").
  Future<void> forgetAccount(String accountId) async {
    if (accountId == _accountId) await setAccount(null);
    await _storage.delete(accountBucket(accountId));
    await _storage.delete(recoveryBucket(accountId));
  }

  @override
  Future<bool> resolveReview(SyncChoices choices) async {
    final review = _review;
    final remote = _remote;
    if (review == null || remote == null || _resolving) return false;
    final plan = review.plan(choices);
    if (!plan.isComplete) return false;
    final generation = _generation;
    final bucket = _account;
    _resolving = true;
    _reviewError = null;
    _changed();
    try {
      final document = await remote.fetch().timeout(remoteTimeout);
      if (generation != _generation) return false;
      final deviceNow = _deviceSnapshot(bucket);
      final accountNow = _remoteSnapshot(document);
      if (deviceNow.fingerprint != review.device.fingerprint ||
          accountNow.fingerprint != review.account.fingerprint) {
        _review = SyncReview(
          accountId: review.accountId,
          device: deviceNow,
          account: accountNow,
        );
        _reviewError = SyncReviewError.changed;
        return false;
      }
      // The copies are saved first: if that fails, nothing has changed.
      final recovery = SyncRecovery.of(review, _clock().toUtc());
      await _storage.write(recoveryBucket(review.accountId), recovery.toJson());
      if (generation != _generation) return false;
      _recovery = recovery;
      _adopt(bucket, plan.merged, review.account);
      bucket.seed = false;
      await _persist(bucket);
      if (generation != _generation) return false;
      _review = null;
      _setStatus(_pendingStatus(bucket), notify: false);
    } catch (error) {
      if (generation != _generation) return false;
      onError?.call('settings_review_error', error);
      _reviewError = SyncReviewError.failed;
      return false;
    } finally {
      _resolving = false;
      _changed();
    }
    unawaited(sync());
    return true;
  }

  @override
  Future<bool> restoreRecovery(SyncSide side) async {
    final recovery = _recovery;
    if (recovery == null || recovery.accountId != _accountId || _resolving) {
      return false;
    }
    final bucket = _account;
    final copy = recovery.of(side).fields;
    // Every field is sent, so the account takes the copy as a whole.
    for (final key in schema.inScope(SettingScope.account)) {
      final raw = copy[key.id];
      final encoded = raw == null ? null : key.write(key.read(raw));
      if (encoded == null) {
        bucket.values.remove(key.id);
      } else {
        bucket.values[key.id] = encoded;
      }
      if (_remote != null) {
        bucket.pending.add(key.id);
        _edits[key.id] = (_edits[key.id] ?? 0) + 1;
      }
    }
    bucket.seed = false;
    _clearReview();
    try {
      await _persist(bucket);
    } catch (_) {
      return false;
    }
    _setStatus(
      _remote == null ? const SyncStatus.localOnly() : _pendingStatus(bucket),
      notify: false,
    );
    _changed();
    unawaited(sync());
    return true;
  }

  @override
  Future<void> dropRecovery() async {
    final recovery = _recovery;
    if (recovery == null) return;
    _recovery = null;
    _changed();
    await _storage.delete(recoveryBucket(recovery.accountId));
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
    unawaited(_storageWatch?.cancel());
    if (_open && observeAppLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    for (final listenable in _listenables.values) {
      listenable.dispose();
    }
    if (_ownsProgress) progress.dispose();
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
      // The review being confirmed owns this first sync.
      if (bucket.seed && _resolving) return;
      unawaited(progress.advance(SyncStage.dataReceived));
      var changed = false;
      if (bucket.seed) {
        if (document == null || document.isEmpty) {
          // New account: keep what the user chose while signed out.
          bucket.seed = false;
          for (final key in schema.inScope(SettingScope.account)) {
            if (bucket.values.containsKey(key.id)) {
              bucket.pending.add(key.id);
              _edits[key.id] = (_edits[key.id] ?? 0) + 1;
            }
          }
        } else if (!reviewFirstSync) {
          bucket.seed = false;
          bucket.pending.clear();
        } else {
          final device = _deviceSnapshot(bucket);
          final account = _remoteSnapshot(document);
          final plan = reconcileSnapshots(device, account);
          if (plan.hasConflicts) {
            // Nothing is applied nor sent until the user chooses.
            _review = SyncReview(
              accountId: _accountId!,
              device: device,
              account: account,
            );
            _reviewError = null;
            progress.reset();
            _setStatus(
              SyncStatus(
                health: SyncHealth.needsReview,
                pendingCount: bucket.pending.length,
                lastSyncedAt: bucket.syncedAt,
              ),
            );
            return;
          }
          // Nothing to choose: both sides are united at once.
          bucket.seed = false;
          _clearReview();
          changed = _adopt(bucket, plan.merged, account);
        }
      }
      changed = (document != null && _applyRemote(bucket, document)) || changed;
      unawaited(progress.advance(SyncStage.dataApplied));

      // A field pointing at a record not on the server yet waits for
      // rewriteIds.
      final ready = bucket.pending
          .where((entry) => !_holdsTemporaryId(bucket, entry))
          .toList();
      if (ready.isNotEmpty) {
        final sent = {for (final entry in ready) entry: _edits[entry] ?? 0};
        final changes = _changesFor(bucket, sent.keys);
        final result = await remote.push(changes).timeout(remoteTimeout);
        if (generation != _generation) return;
        sent.forEach((entry, edit) {
          if ((_edits[entry] ?? 0) == edit) bucket.pending.remove(entry);
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
      unawaited(progress.finish());
      final recovery = _recovery;
      if (recovery != null && !recovery.confirmed && bucket.pending.isEmpty) {
        // The reviewed copy reached the account.
        _recovery = recovery.confirm();
        unawaited(_saveRecovery(_recovery!));
      }
    } on SettingsRemoteAuthException catch (error) {
      if (generation != _generation) return;
      onError?.call('settings_cloud_auth_error', error);
      progress.reset();
      _setStatus(_failed(bucket, 'auth', error.message, retryable: false));
    } on TimeoutException catch (error) {
      if (generation != _generation) return;
      onError?.call('settings_cloud_timeout', error);
      progress.reset();
      _setStatus(_failed(bucket, 'timeout', 'The remote did not answer.'));
      _scheduleRetry();
    } catch (error) {
      if (generation != _generation) return;
      onError?.call('settings_cloud_sync_error', error);
      progress.reset();
      _setStatus(_failed(bucket, 'remote_error', '$error'));
      _scheduleRetry();
    }
  }

  /// The account values of [bucket], as compared in a review.
  SyncSnapshot _deviceSnapshot(_Bucket bucket) => SyncSnapshot(
    fields: _accountFields(bucket.values),
  );

  /// [document]'s values, migrated and normalized like stored ones.
  SyncSnapshot _remoteSnapshot(RemoteSettings? document) {
    if (document == null) return const SyncSnapshot();
    final from = document.schemaVersion;
    return SyncSnapshot(
      fields: _accountFields(
        from != null && from < schema.version
            ? schema.migrate(document.values, from)
            : document.values,
      ),
    );
  }

  Map<String, Object?> _accountFields(Map<String, Object?> values) => {
    for (final key in schema.inScope(SettingScope.account))
      if (values[key.id] case final raw?)
        if (key.write(key.read(raw)) case final encoded?) key.id: encoded,
  };

  /// Shows [merged] and marks pending every field the account lacks or holds
  /// differently; returns whether a shown value changed.
  bool _adopt(_Bucket bucket, SyncSnapshot merged, SyncSnapshot account) {
    var changed = false;
    bucket.pending.clear();
    for (final key in schema.inScope(SettingScope.account)) {
      final value = merged.fields[key.id];
      if (!_sameJson(bucket.values[key.id], value)) changed = true;
      if (value == null) {
        bucket.values.remove(key.id);
      } else {
        bucket.values[key.id] = value;
      }
      if (!_sameJson(account.fields[key.id], value)) {
        bucket.pending.add(key.id);
        _edits[key.id] = (_edits[key.id] ?? 0) + 1;
      }
    }
    return changed;
  }

  void _clearReview() {
    _review = null;
    _reviewError = null;
  }

  Future<SyncRecovery?> _loadRecovery(String accountId) async {
    try {
      final data = await _storage.read(recoveryBucket(accountId));
      return data == null ? null : SyncRecovery.fromJson(data);
    } catch (error) {
      onError?.call('settings_recovery_read_error', error);
      return null;
    }
  }

  Future<void> _saveRecovery(SyncRecovery recovery) async {
    try {
      await _storage.write(
        recoveryBucket(recovery.accountId),
        recovery.toJson(),
      );
    } catch (error) {
      onError?.call('settings_recovery_write_error', error);
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
      var encoded = raw == null ? null : key.write(key.read(raw));
      final held = _pendingPaths(bucket, key.id);
      if (held.isNotEmpty) {
        // Nested fields changed here keep their device value.
        encoded = _overlay(encoded, bucket.values[key.id], held);
      }
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

  /// Marks [key] pending: only the nested fields that differ for a
  /// [SettingKey.mergeFields] map, the whole field otherwise.
  void _markPending(
    _Bucket bucket,
    SettingKey<Object?> key,
    Object? before,
    Object? after,
  ) {
    final List<String> entries;
    if (key.mergeFields &&
        before is Map &&
        after is Map &&
        !bucket.pending.contains(key.id)) {
      entries = [
        for (final path in _changedPaths(before, after))
          [key.id, ...path].join('/'),
      ];
    } else {
      bucket.pending.removeWhere((entry) => entry.startsWith('${key.id}/'));
      entries = [key.id];
    }
    for (final entry in entries) {
      bucket.pending.add(entry);
      _edits[entry] = (_edits[entry] ?? 0) + 1;
    }
  }

  /// Nested paths pending under [id] (`['contentFrequency', 'linkedin']`).
  static List<List<String>> _pendingPaths(_Bucket bucket, String id) => [
    for (final entry in bucket.pending)
      if (entry.startsWith('$id/')) entry.substring(id.length + 1).split('/'),
  ];

  bool _holdsTemporaryId(_Bucket bucket, String entry) {
    final test = isTemporaryId;
    if (test == null) return false;
    final (id, path) = _splitEntry(entry);
    return holdsTemporaryId(_readPath(bucket.values[id], path).$2, test);
  }

  /// What [entries] send: whole fields, and partial maps for nested ones.
  static Map<String, Object?> _changesFor(
    _Bucket bucket,
    Iterable<String> entries,
  ) {
    final changes = <String, Object?>{};
    // A whole field sent already carries its nested ones.
    final whole = {
      for (final entry in entries)
        if (!entry.contains('/')) entry,
    };
    final partials = <String, Map<String, Object?>>{};
    for (final entry in entries) {
      final (id, path) = _splitEntry(entry);
      if (path.isEmpty) {
        changes[id] = bucket.values[id];
        continue;
      }
      if (whole.contains(id)) continue;
      final partial = partials.putIfAbsent(id, () => <String, Object?>{});
      changes[id] = partial;
      // A removed nested field is sent as null.
      _writePath(partial, path, _readPath(bucket.values[id], path).$2);
    }
    return changes;
  }

  static (String, List<String>) _splitEntry(String entry) {
    final parts = entry.split('/');
    return (parts.first, parts.sublist(1));
  }

  /// Leaf paths whose content differs between two maps.
  static List<List<String>> _changedPaths(
    Map<Object?, Object?> before,
    Map<Object?, Object?> after,
  ) {
    final paths = <List<String>>[];
    final names = {...before.keys, ...after.keys}.map((name) => '$name');
    for (final name in names) {
      final a = before[name];
      final b = after[name];
      if (a is Map && b is Map) {
        for (final path in _changedPaths(a, b)) {
          paths.add([name, ...path]);
        }
      } else if (!_sameJson(a, b) ||
          before.containsKey(name) != after.containsKey(name)) {
        paths.add([name]);
      }
    }
    return paths;
  }

  /// [remote] with the device's value at each of [paths].
  static Object? _overlay(
    Object? remote,
    Object? device,
    List<List<String>> paths,
  ) {
    final result = remote is Map
        ? _copyJson(remote) as Map<String, Object?>
        : <String, Object?>{};
    for (final path in paths) {
      final (present, value) = _readPath(device, path);
      _writePath(result, path, value, present: present);
    }
    return result;
  }

  /// Whether [path] exists in [value], and what it holds.
  static (bool, Object?) _readPath(Object? value, List<String> path) {
    var current = value;
    for (final name in path) {
      if (current is! Map || !current.containsKey(name)) return (false, null);
      current = current[name];
    }
    return (true, current);
  }

  /// Sets (or, when not [present], removes) [path] in [target].
  static void _writePath(
    Map<String, Object?> target,
    List<String> path,
    Object? value, {
    bool present = true,
  }) {
    var current = target;
    for (final name in path.take(path.length - 1)) {
      final next = current[name];
      final child = next is Map
          ? _copyJson(next) as Map<String, Object?>
          : <String, Object?>{};
      current[name] = child;
      current = child;
    }
    if (present) {
      current[path.last] = value;
    } else {
      current.remove(path.last);
    }
  }

  /// Mutable deep copy of a JSON-safe value.
  static Object? _copyJson(Object? value) => switch (value) {
    final Map<Object?, Object?> map => <String, Object?>{
      for (final entry in map.entries) '${entry.key}': _copyJson(entry.value),
    },
    final List<Object?> list => [for (final item in list) _copyJson(item)],
    _ => value,
  };

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
    health: !retryable
        ? SyncHealth.failed
        // Never read on this device: the shown values are not verified.
        : bucket.syncedAt == null
        ? SyncHealth.unreachable
        : bucket.pending.isNotEmpty
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
    _writes++;
    try {
      await _storage.write(bucket.name, bucket.toJson(schema.version));
    } catch (error) {
      final failure = SettingsStorageException('write', bucket.name, error);
      onError?.call('settings_local_write_error', failure);
      if (rethrowError) throw failure;
    } finally {
      _writes--;
      if (_writes == 0 && _reloadAfterWrites && !_disposed) {
        _reloadAfterWrites = false;
        unawaited(reload());
      }
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
    bucket.lastAccount = data['lastAccount'] is String
        ? data['lastAccount'] as String
        : null;
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

  /// Device bucket only: the account shown last, restored by `open`.
  String? lastAccount;

  Map<String, Object?> toJson(int version) => {
    'v': version,
    'values': values,
    if (pending.isNotEmpty) 'pending': pending.toList()..sort(),
    if (seed) 'seed': true,
    if (revision != null) 'revision': revision,
    if (lastAccount != null) 'lastAccount': lastAccount,
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
