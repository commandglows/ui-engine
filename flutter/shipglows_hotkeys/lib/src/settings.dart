import 'package:flutter/foundation.dart';

/// Executable names are compared in lower case: « Code.EXE » is « code.exe ».
String shipglowsProcessName(String name) => name.trim().toLowerCase();

Set<String> _names(Iterable<Object?>? names) => {
  for (final name in names ?? const <Object?>[])
    if (name is String && shipglowsProcessName(name).isNotEmpty)
      shipglowsProcessName(name),
};

/// Which programs one binding works in, on top of the app's own
/// [ShipglowsHotkeyBinding.excludeProcesses].
@immutable
class ShipglowsBindingFilter {
  const ShipglowsBindingFilter({
    this.excluded = const {},
    this.only = const {},
  });

  /// Programs (`code.exe`) where a mouse trigger or a double key does nothing.
  final Set<String> excluded;

  /// When not empty, the only programs the trigger works in (a white list).
  final Set<String> only;

  bool get isEmpty => excluded.isEmpty && only.isEmpty;

  ShipglowsBindingFilter copyWith({Set<String>? excluded, Set<String>? only}) =>
      ShipglowsBindingFilter(
        excluded: _names(excluded ?? this.excluded),
        only: _names(only ?? this.only),
      );

  Map<String, Object?> toJson() => {
    if (excluded.isNotEmpty) 'excluded': excluded.toList()..sort(),
    if (only.isNotEmpty) 'only': only.toList()..sort(),
  };

  static ShipglowsBindingFilter fromJson(Object? json) {
    if (json is! Map) return const ShipglowsBindingFilter();
    return ShipglowsBindingFilter(
      excluded: _names(json['excluded'] is List ? json['excluded'] as List : null),
      only: _names(json['only'] is List ? json['only'] as List : null),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShipglowsBindingFilter &&
      setEquals(other.excluded, excluded) &&
      setEquals(other.only, only);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(excluded),
    Object.hashAllUnordered(only),
  );
}

/// What the user decided besides the triggers themselves: the master switch
/// and the programs where triggers stay quiet. Kept next to the triggers by
/// the [ShipglowsHotkeyStore].
@immutable
class ShipglowsHotkeySettings {
  const ShipglowsHotkeySettings({
    this.enabled = true,
    this.excludedProcesses = const {},
    this.filters = const {},
  });

  /// Master switch. Off, nothing is registered with Windows: the key
  /// combinations are free for the other applications again.
  final bool enabled;

  /// Programs where no mouse trigger or double key of the app does anything.
  final Set<String> excludedProcesses;

  /// Per-binding lists, by [ShipglowsHotkeyBinding.id].
  final Map<String, ShipglowsBindingFilter> filters;

  ShipglowsBindingFilter filterOf(String id) =>
      filters[id] ?? const ShipglowsBindingFilter();

  ShipglowsHotkeySettings copyWith({
    bool? enabled,
    Set<String>? excludedProcesses,
    Map<String, ShipglowsBindingFilter>? filters,
  }) => ShipglowsHotkeySettings(
    enabled: enabled ?? this.enabled,
    excludedProcesses: _names(excludedProcesses ?? this.excludedProcesses),
    filters: {
      for (final MapEntry(:key, :value) in (filters ?? this.filters).entries)
        if (!value.isEmpty) key: value,
    },
  );

  /// The filter of [id] replaced; an empty one is forgotten.
  ShipglowsHotkeySettings withFilter(String id, ShipglowsBindingFilter filter) =>
      copyWith(filters: {...filters, id: filter.copyWith()});

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    if (excludedProcesses.isNotEmpty)
      'excluded': excludedProcesses.toList()..sort(),
    if (filters.isNotEmpty)
      'bindings': {
        for (final MapEntry(:key, :value) in filters.entries)
          key: value.toJson(),
      },
  };

  /// Defaults for anything missing or unreadable.
  static ShipglowsHotkeySettings fromJson(Object? json) {
    if (json is! Map) return const ShipglowsHotkeySettings();
    final bindings = json['bindings'];
    return ShipglowsHotkeySettings(
      enabled: json['enabled'] != false,
      excludedProcesses: _names(json['excluded'] is List ? json['excluded'] as List : null),
      filters: {
        if (bindings is Map)
          for (final MapEntry(:key, :value) in bindings.entries)
            if (key is String) key: ShipglowsBindingFilter.fromJson(value),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShipglowsHotkeySettings &&
      other.enabled == enabled &&
      setEquals(other.excludedProcesses, excludedProcesses) &&
      mapEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(
    enabled,
    Object.hashAllUnordered(excludedProcesses),
    Object.hashAllUnordered(filters.entries.map((e) => Object.hash(e.key, e.value))),
  );
}
