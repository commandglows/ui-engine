/// Where a setting lives.
enum SettingScope {
  /// Kept on this device only, shared by every account on it (window size,
  /// hotkey, last opened tab).
  device,

  /// Owned by the signed-in account and synced to its remote copy (theme,
  /// language, notification choices). Signed out, it lives in a local-only
  /// copy that is never sent anywhere.
  account,
}

/// Turns a setting value into JSON-safe data and back.
///
/// [decode] never throws on bad data: it returns `null`, and the setting falls
/// back to its default.
class SettingCodec<T> {
  const SettingCodec({required this.encode, required this.decode});

  /// JSON-safe form: `null`, bool, num, String, List or Map of those.
  final Object? Function(T value) encode;

  /// Parses [encode] output, or `null` when the stored data is unusable.
  final T? Function(Object? data) decode;

  static final bool_ = SettingCodec<bool>(
    encode: (value) => value,
    decode: (data) => switch (data) {
      final bool value => value,
      'true' => true,
      'false' => false,
      _ => null,
    },
  );

  static final int_ = SettingCodec<int>(
    encode: (value) => value,
    decode: (data) => switch (data) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    },
  );

  static final double_ = SettingCodec<double>(
    encode: (value) => value,
    decode: (data) => switch (data) {
      final num value => value.toDouble(),
      final String value => double.tryParse(value),
      _ => null,
    },
  );

  static final string = SettingCodec<String>(
    encode: (value) => value,
    decode: (data) => data is String ? data : null,
  );

  /// UTC ISO 8601 text; a remote may also hand back a [DateTime].
  static final dateTime = SettingCodec<DateTime>(
    encode: (value) => value.toUtc().toIso8601String(),
    decode: (data) => switch (data) {
      final DateTime value => value.toUtc(),
      final String value => DateTime.tryParse(value)?.toUtc(),
      _ => null,
    },
  );

  /// Stores [Enum.name]; an unknown name decodes to `null`.
  static SettingCodec<E> enumByName<E extends Enum>(List<E> values) =>
      SettingCodec<E>(
        encode: (value) => value.name,
        decode: (data) {
          for (final value in values) {
            if (value.name == data) return value;
          }
          return null;
        },
      );

  /// Stores a custom string id per value (`'7d'` for seven days).
  static SettingCodec<E> byId<E>(List<E> values, String Function(E) id) =>
      SettingCodec<E>(
        encode: id,
        decode: (data) {
          for (final value in values) {
            if (id(value) == data) return value;
          }
          return null;
        },
      );

  static final stringList = SettingCodec<List<String>>(
    encode: (value) => List<String>.of(value),
    decode: (data) =>
        data is List ? List<String>.unmodifiable(data.whereType<String>()) : null,
  );

  /// Free-form JSON object, for settings whose shape the app owns.
  static final jsonMap = SettingCodec<Map<String, Object?>>(
    encode: (value) => Map<String, Object?>.of(value),
    decode: (data) => data is Map
        ? Map<String, Object?>.unmodifiable(data.cast<String, Object?>())
        : null,
  );

  /// Accepts `null` as a value of its own, distinct from the default.
  SettingCodec<T?> nullable() => SettingCodec<T?>(
    encode: (value) => value == null ? null : encode(value),
    decode: (data) => data == null ? null : decode(data),
  );
}

/// One setting, declared once: its stable [id] is the field name in every
/// store (device file, Firestore document, REST payload).
class SettingKey<T> {
  const SettingKey(
    this.id, {
    required this.defaultValue,
    required this.codec,
    this.scope = SettingScope.account,
    this.normalize,
  });

  static SettingKey<bool> boolean(
    String id, {
    required bool defaultValue,
    SettingScope scope = SettingScope.account,
  }) => SettingKey(
    id,
    defaultValue: defaultValue,
    codec: SettingCodec.bool_,
    scope: scope,
  );

  static SettingKey<int> integer(
    String id, {
    required int defaultValue,
    SettingScope scope = SettingScope.account,
    int Function(int value)? normalize,
  }) => SettingKey(
    id,
    defaultValue: defaultValue,
    codec: SettingCodec.int_,
    scope: scope,
    normalize: normalize,
  );

  static SettingKey<String> text(
    String id, {
    required String defaultValue,
    SettingScope scope = SettingScope.account,
    String Function(String value)? normalize,
  }) => SettingKey(
    id,
    defaultValue: defaultValue,
    codec: SettingCodec.string,
    scope: scope,
    normalize: normalize,
  );

  static SettingKey<E> choice<E extends Enum>(
    String id, {
    required List<E> values,
    required E defaultValue,
    SettingScope scope = SettingScope.account,
  }) => SettingKey(
    id,
    defaultValue: defaultValue,
    codec: SettingCodec.enumByName(values),
    scope: scope,
  );

  final String id;
  final T defaultValue;
  final SettingCodec<T> codec;
  final SettingScope scope;

  /// Clamps or repairs a decoded value (a negative step becomes 0).
  final T Function(T value)? normalize;

  bool get isSynced => scope == SettingScope.account;

  /// The value stored as [data], or [defaultValue] when absent or unusable.
  T read(Object? data, {bool present = true}) {
    if (!present) return defaultValue;
    final T? decoded;
    try {
      decoded = codec.decode(data);
    } catch (_) {
      return defaultValue;
    }
    if (decoded == null && null is! T) return defaultValue;
    final value = decoded as T;
    return normalize == null ? value : normalize!(value);
  }

  Object? write(T value) => codec.encode(value);

  @override
  String toString() => 'SettingKey($id)';
}
