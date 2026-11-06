/// Manual order of items, started from the DreamGlows actions.
///
/// A rank is a base-62 string (`0-9A-Za-z`, compared by code units, no
/// trailing `0`): a new key always fits between two others, so a move rewrites
/// one item. Ranked items come first in rank order, unranked ones follow in
/// their given order. Contract shared with the TypeScript twin of DreamGlows
/// (`path-core/src/action-rank.ts`, fixture `action-rank-v1.json`): keep both
/// identical to the character.
library;

const _digits =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// Longest rank accepted by [isRank].
const rankMaxLength = 64;
final _rankPattern = RegExp(r'^[0-9A-Za-z]*[1-9A-Za-z]$');

/// A usable rank; anything else is ignored by ordering and kept as stored.
bool isRank(Object? value) =>
    value is String &&
    value.length <= rankMaxLength &&
    _rankPattern.hasMatch(value);

String _midpoint(String a, String? b) {
  if (b != null) {
    var n = 0;
    while (n < b.length && (n < a.length ? a[n] : '0') == b[n]) {
      n++;
    }
    if (n > 0) {
      return b.substring(0, n) +
          _midpoint(a.length > n ? a.substring(n) : '', b.substring(n));
    }
  }
  final low = a.isEmpty ? 0 : _digits.indexOf(a[0]);
  final high = b != null ? _digits.indexOf(b[0]) : _digits.length;
  if (high - low > 1) return _digits[(low + high + 1) ~/ 2];
  if (b != null && b.length > 1) return b.substring(0, 1);
  return _digits[low] + _midpoint(a.isEmpty ? '' : a.substring(1), null);
}

/// A key strictly between [before] and [after] (either may be null); throws
/// `RangeError('invalid-rank')` on an unusable or unordered bound.
String rankBetween([String? before, String? after]) {
  if ((before != null && !isRank(before)) ||
      (after != null && !isRank(after)) ||
      (before != null && after != null && before.compareTo(after) >= 0)) {
    throw RangeError('invalid-rank');
  }
  return _midpoint(before ?? '', after);
}

/// Ranked items by rank, then unranked items in their given order.
/// [rankOf] returns the stored value; one failing [isRank] counts as none.
List<T> orderByRank<T>(Iterable<T> items, Object? Function(T item) rankOf) {
  final indexed = [
    for (final (index, item) in items.indexed)
      (item: item, index: index, rank: _usable(rankOf(item))),
  ];
  indexed.sort((x, y) {
    final a = x.rank, b = y.rank;
    if (a != null && b != null && a != b) return a.compareTo(b);
    if (a != null && b == null) return -1;
    if (a == null && b != null) return 1;
    return x.index - y.index;
  });
  return [for (final entry in indexed) entry.item];
}

String? _usable(Object? rank) => isRank(rank) ? rank as String : null;

/// The rank changes (`id`, `rank`) that move [id] to [toIndex] of [ordered]
/// (already in [orderByRank] order; [toIndex] counts the list without the
/// moved item). One change inside the ranked part; inside the unranked tail,
/// the items passed are ranked first. Throws `RangeError('item-not-found')`
/// when [id] is not in [ordered].
List<({String id, String rank})> planRankMove<T>(
  List<T> ordered,
  String id,
  int toIndex, {
  required String Function(T item) idOf,
  required Object? Function(T item) rankOf,
}) {
  String? rankAt(T item) => _usable(rankOf(item));
  final from = ordered.indexWhere((item) => idOf(item) == id);
  if (from < 0) throw RangeError('item-not-found');
  final rest = [
    for (final item in ordered)
      if (idOf(item) != id) item,
  ];
  final target = toIndex.clamp(0, rest.length);
  if (target == from) return const [];
  var ranked = 0;
  while (ranked < rest.length) {
    final rank = rankAt(rest[ranked]);
    if (rank == null ||
        (ranked > 0 && rank.compareTo(rankAt(rest[ranked - 1])!) <= 0)) {
      break;
    }
    ranked++;
  }
  String? bound(int index, String? above) {
    for (var i = index; i < rest.length; i++) {
      final rank = rankAt(rest[i]);
      if (rank != null && (above == null || rank.compareTo(above) > 0)) {
        return rank;
      }
    }
    return null;
  }

  final changes = <({String id, String rank})>[];
  final anchor = target < ranked ? target : ranked;
  var previous = anchor > 0 ? rankAt(rest[anchor - 1]) : null;
  for (var i = ranked; i < target; i++) {
    previous = rankBetween(previous, bound(target, previous));
    changes.add((id: idOf(rest[i]), rank: previous));
  }
  changes.add((id: id, rank: rankBetween(previous, bound(target, previous))));
  return changes;
}
