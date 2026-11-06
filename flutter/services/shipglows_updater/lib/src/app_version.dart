/// A pubspec version, `1.2.3+45`: dotted numbers then an optional build
/// number (the Android `versionCode`, the fourth Windows version field).
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts, {this.build});

  /// Parses `1.2.3`, `1.2.3+45` or `1.2.3.45` (Windows product version, the
  /// fourth field being the build). Throws a [FormatException] otherwise.
  factory AppVersion.parse(String text) {
    final trimmed = text.trim();
    final plus = trimmed.indexOf('+');
    final name = plus < 0 ? trimmed : trimmed.substring(0, plus);
    final buildText = plus < 0 ? null : trimmed.substring(plus + 1);
    final parts = <int>[];
    for (final part in name.split('.')) {
      final value = int.tryParse(part);
      if (value == null || value < 0) {
        throw FormatException('Not a version', text);
      }
      parts.add(value);
    }
    int? build;
    if (buildText != null) {
      build = int.tryParse(buildText);
      if (build == null || build < 0) throw FormatException('Bad build', text);
    } else if (parts.length == 4) {
      build = parts.removeLast();
    }
    return AppVersion(List.unmodifiable(parts), build: build);
  }

  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    try {
      return AppVersion.parse(text);
    } on FormatException {
      return null;
    }
  }

  final List<int> parts;
  final int? build;

  /// Dotted numbers first (missing ones count as 0), then the build number
  /// when both sides have one.
  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    final a = build, b = other.build;
    if (a == null || b == null) return 0;
    return a.compareTo(b);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0 && build == other.build;

  @override
  int get hashCode {
    // `1.2` equals `1.2.0`: trailing zeros must not change the hash.
    var length = parts.length;
    while (length > 0 && parts[length - 1] == 0) {
      length--;
    }
    return Object.hash(Object.hashAll(parts.take(length)), build);
  }

  /// `1.2.3` for people, the build number left out.
  String get display => parts.join('.');

  @override
  String toString() => build == null ? display : '$display+$build';
}
