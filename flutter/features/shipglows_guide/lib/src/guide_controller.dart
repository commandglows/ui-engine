import 'dart:async';

import 'package:flutter/foundation.dart';

import 'guide_progress.dart';
import 'guide_step.dart';

/// Runs one tour at a time and keeps every tour's progress.
///
/// Create it once for the app (it outlives screens) and give it to a
/// [GuideScope]. A tour is never resumed on its own at startup: the app
/// starts it ([start], [resume]) or a [GuideTrigger] does on a first visit.
class GuideController extends ChangeNotifier {
  GuideController({
    required Iterable<GuideTour> tours,
    GuideStore? store,
    this.navigate,
    this.location,
  }) : _tours = {for (final tour in tours) tour.id: tour},
       _store = store ?? MemoryGuideStore();

  final Map<String, GuideTour> _tours;
  final GuideStore _store;

  /// Opens a step's route (`router.go`). Without it, the [GuideScope]'s
  /// `navigate` is used while one is mounted; with neither, steps never
  /// navigate.
  final void Function(String route)? navigate;

  /// Current route path, to know whether the user is on a step's route.
  final String? Function()? location;

  void Function(String route)? _scopeNavigate;
  String? Function()? _scopeLocation;
  Object? _scopeOwner;

  /// Called by [GuideScope]: its context-based navigation, used when the
  /// controller has none of its own.
  void attachNavigation(
    Object owner, {
    void Function(String route)? navigate,
    String? Function()? location,
  }) {
    _scopeOwner = owner;
    _scopeNavigate = navigate;
    _scopeLocation = location;
  }

  /// Reverse of [attachNavigation], ignored when another scope took over.
  void detachNavigation(Object owner) {
    if (!identical(_scopeOwner, owner)) return;
    _scopeOwner = null;
    _scopeNavigate = null;
    _scopeLocation = null;
  }

  final _progress = <String, GuideProgress>{};
  GuideTour? _active;
  int _stepIndex = 0;
  bool _disposed = false;

  Iterable<GuideTour> get tours => _tours.values;
  GuideTour? tour(String id) => _tours[id];

  GuideTour? get activeTour => _active;
  bool get isActive => _active != null;
  int get stepIndex => _stepIndex;
  GuideStep? get activeStep => _active?.steps[_stepIndex];
  bool get isFirst => _stepIndex == 0;
  bool get isLast => _active == null || _stepIndex == _active!.steps.length - 1;

  /// Whether the user is on the active step's route (true without a route).
  bool get isOnStepRoute {
    final route = activeStep?.route;
    if (route == null) return true;
    final current = (location ?? _scopeLocation)?.call();
    return current == null || current == route;
  }

  /// Progress loaded so far ([GuideProgress.initial] before [load]).
  GuideProgress progressOf(String tourId) =>
      _progress[tourId] ?? GuideProgress.initial;

  /// Reads a tour's progress from the store, once.
  Future<GuideProgress> load(String tourId) async {
    final cached = _progress[tourId];
    if (cached != null) return cached;
    var progress = await _store.read(tourId) ?? GuideProgress.initial;
    final steps = _tours[tourId]?.steps.length ?? 0;
    if (progress.stepIndex < 0 || progress.stepIndex >= steps) {
      progress = progress.copyWith(stepIndex: 0);
    }
    _progress[tourId] ??= progress;
    _notify();
    return _progress[tourId]!;
  }

  /// Starts a tour (from [step], the beginning by default), replacing the
  /// running one.
  Future<void> start(String tourId, {int step = 0}) async {
    final tour = _tours[tourId];
    if (tour == null) {
      throw ArgumentError.value(tourId, 'tourId', 'Unknown guide tour');
    }
    _active = tour;
    _stepIndex = step.clamp(0, tour.steps.length - 1);
    _openStepRoute();
    _notify();
    await _save(tour.id, GuideProgress(stepIndex: _stepIndex, started: true));
  }

  /// Starts a tour where the user left it, from the beginning once completed.
  Future<void> resume(String tourId) async {
    final progress = await load(tourId);
    await start(tourId, step: progress.completed ? 0 : progress.stepIndex);
  }

  /// Starts a tour the user has never seen, unless another one is running.
  /// Returns whether it started.
  Future<bool> startIfFirstVisit(String tourId) async {
    if (isActive || !_tours.containsKey(tourId)) return false;
    final progress = await load(tourId);
    if (progress.started || progress.completed || isActive) return false;
    await start(tourId);
    return true;
  }

  /// Hides the tour; [resume] picks it up at the same step.
  void pause() {
    if (_active == null) return;
    _active = null;
    _notify();
  }

  /// Ends the tour for good (completed): first-visit triggers skip it.
  Future<void> skip() => _complete();

  Future<void> next() async {
    final tour = _active;
    if (tour == null) return;
    if (isLast) return _complete();
    await _goTo(tour, _stepIndex + 1);
  }

  Future<void> previous() async {
    final tour = _active;
    if (tour == null || isFirst) return;
    await _goTo(tour, _stepIndex - 1);
  }

  /// Opens the active step's route again (the user went elsewhere).
  void openStepRoute() => _openStepRoute();

  /// Forgets a tour's progress, so its first-visit trigger fires again.
  Future<void> reset(String tourId) async {
    if (_active?.id == tourId) _active = null;
    await _save(tourId, GuideProgress.initial);
  }

  /// [reset] for every tour (a « Show tips again » setting).
  Future<void> resetAll() async {
    for (final id in _tours.keys.toList()) {
      await reset(id);
    }
  }

  /// Called by [GuideTarget] when the user taps it: moves on when the active
  /// step asked the user to try it. The tap's own action runs first.
  void targetActivated(String targetId) {
    final step = activeStep;
    if (step == null || step.targetId != targetId || !step.advanceOnTargetTap) {
      return;
    }
    final tour = _active;
    final index = _stepIndex;
    Timer.run(() {
      if (_active == tour && _stepIndex == index) unawaited(next());
    });
  }

  Future<void> _goTo(GuideTour tour, int index) async {
    _stepIndex = index;
    _openStepRoute();
    _notify();
    await _save(tour.id, GuideProgress(stepIndex: index, started: true));
  }

  Future<void> _complete() async {
    final tour = _active;
    if (tour == null) return;
    _active = null;
    _notify();
    await _save(tour.id, const GuideProgress(started: true, completed: true));
  }

  void _openStepRoute() {
    final route = activeStep?.route;
    final go = navigate ?? _scopeNavigate;
    if (route == null || go == null || isOnStepRoute) return;
    go(route);
  }

  Future<void> _save(String tourId, GuideProgress progress) async {
    _progress[tourId] = progress;
    _notify();
    await _store.write(tourId, progress);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
