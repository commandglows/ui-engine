/// Free labels typed as a comma list (keywords, topics…): unlike tags they
/// keep their case and inner spaces. Each one is trimmed, empty ones dropped,
/// duplicates (ignoring case) dropped with the first spelling kept, at most
/// [maxCount] when given. Accepts a list or a string split on commas.
List<String> normalizeLabels(Object? raw, {int? maxCount}) {
  final Iterable<Object?> parts = raw is Iterable
      ? raw
      : (raw ?? '').toString().split(',');
  final labels = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    final label = (part ?? '').toString().trim();
    if (label.isNotEmpty && seen.add(label.toLowerCase())) {
      labels.add(label);
    }
    if (maxCount != null && labels.length == maxCount) {
      break;
    }
  }
  return labels;
}
