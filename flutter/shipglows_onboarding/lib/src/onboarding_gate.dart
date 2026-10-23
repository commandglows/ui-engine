import 'dart:async';

import 'package:flutter/widgets.dart';

/// Where the "introduction seen" flags are kept, one boolean per key.
abstract interface class OnboardingCompletionStore {
  FutureOr<bool> read(String key);
  FutureOr<void> write(String key, bool completed);
}

/// Forgets everything when the app closes.
class MemoryOnboardingCompletionStore implements OnboardingCompletionStore {
  final _flags = <String, bool>{};

  @override
  bool read(String key) => _flags[key] ?? false;

  @override
  void write(String key, bool completed) => _flags[key] = completed;
}

/// Backs the flags with the app's storage, for example:
///
/// ```dart
/// CallbackOnboardingCompletionStore(
///   onRead: (key) async =>
///       (await SharedPreferences.getInstance()).getBool(key) ?? false,
///   onWrite: (key, done) async =>
///       (await SharedPreferences.getInstance()).setBool(key, done),
/// )
/// ```
class CallbackOnboardingCompletionStore implements OnboardingCompletionStore {
  const CallbackOnboardingCompletionStore({
    required this.onRead,
    required this.onWrite,
  });

  final FutureOr<bool> Function(String key) onRead;
  final FutureOr<void> Function(String key, bool completed) onWrite;

  @override
  FutureOr<bool> read(String key) => onRead(key);

  @override
  FutureOr<void> write(String key, bool completed) => onWrite(key, completed);
}

/// Whether the introduction is due for the current account: shown once per
/// [scope] (the signed-in user id) and [version]. Raise [version] to show a
/// reworked introduction to everyone again.
class OnboardingGate extends ChangeNotifier {
  OnboardingGate({
    required this.store,
    this.version = 1,
    this.keyPrefix = 'onboarding',
  });

  final OnboardingCompletionStore store;
  final int version;
  final String keyPrefix;

  String? _scope;
  bool _pending = false;
  bool _disposed = false;

  /// Store key of [scope]: `onboarding_completed:v1:<scope>`.
  String keyFor(String scope) => '${keyPrefix}_completed:v$version:$scope';

  /// The introduction must be shown now.
  bool get pending => _pending;

  String? get scope => _scope;

  /// Follows the signed-in account; null (signed out) never shows it. Setting
  /// the same scope again does nothing, so token refreshes keep the flow.
  Future<void> setScope(String? scope) async {
    if (scope == _scope) return;
    _scope = scope;
    _set(false);
    if (scope == null) return;
    final done = await store.read(keyFor(scope));
    if (_disposed || _scope != scope) return;
    _set(!done);
  }

  /// Finished or skipped: not shown again for this account.
  Future<void> complete() async {
    _set(false);
    final scope = _scope;
    if (scope != null) await store.write(keyFor(scope), true);
  }

  /// Shows it again (Preferences › Replay the introduction).
  void replay() {
    if (_scope != null) _set(true);
  }

  void _set(bool pending) {
    if (_pending == pending || _disposed) return;
    _pending = pending;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Shows [introduction] above [child] while [pending], for example from
/// `MaterialApp.builder`.
class OnboardingOverlay extends StatelessWidget {
  const OnboardingOverlay({
    super.key,
    required this.pending,
    required this.introduction,
    required this.child,
  });

  final bool pending;
  final Widget introduction;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (child != null) Positioned.fill(child: child!),
        if (pending) Positioned.fill(child: introduction),
      ],
    );
  }
}
