import 'dart:typed_data';

import 'journey_model.dart';

/// What a flattened row shows.
enum JourneyRowKind {
  /// A chapter header.
  header,

  /// One node with the path segments around it.
  node,

  /// The notice of a chapter without nodes.
  emptyChapter,
}

/// One line of the flattened map.
class JourneyRow {
  const JourneyRow._({
    required this.kind,
    required this.chapter,
    required this.chapterIndex,
    this.nodeIndex = -1,
    this.node,
    this.previous,
    this.next,
  });

  /// Kind of row.
  final JourneyRowKind kind;

  /// Owning chapter.
  final JourneyChapter chapter;

  /// Index of [chapter] in the map.
  final int chapterIndex;

  /// Index of [node] in its chapter, or -1.
  final int nodeIndex;

  /// The node of a [JourneyRowKind.node] row.
  final JourneyNode? node;

  /// Node before [node] in the chapter, if any.
  final JourneyNode? previous;

  /// Node after [node] in the chapter, if any.
  final JourneyNode? next;
}

/// Chapters flattened into rows, with O(1) scroll offsets.
///
/// Build once per `chapters` list; rows are lightweight references, so a
/// hundred thousand nodes cost a few megabytes and no widgets until scrolled
/// into view.
class JourneyRows {
  JourneyRows._(this.rows, this._chromeBefore, this._firstRowOfId);

  /// Flattens [chapters].
  factory JourneyRows.from(List<JourneyChapter> chapters) {
    final rows = <JourneyRow>[];
    final firstRowOfId = <String, int>{};
    for (var c = 0; c < chapters.length; c++) {
      final chapter = chapters[c];
      rows.add(
        JourneyRow._(
          kind: JourneyRowKind.header,
          chapter: chapter,
          chapterIndex: c,
        ),
      );
      final nodes = chapter.nodes;
      if (nodes.isEmpty) {
        rows.add(
          JourneyRow._(
            kind: JourneyRowKind.emptyChapter,
            chapter: chapter,
            chapterIndex: c,
          ),
        );
        continue;
      }
      for (var n = 0; n < nodes.length; n++) {
        firstRowOfId.putIfAbsent(nodes[n].id, () => rows.length);
        rows.add(
          JourneyRow._(
            kind: JourneyRowKind.node,
            chapter: chapter,
            chapterIndex: c,
            nodeIndex: n,
            node: nodes[n],
            previous: n > 0 ? nodes[n - 1] : null,
            next: n < nodes.length - 1 ? nodes[n + 1] : null,
          ),
        );
      }
    }
    // chromeBefore[i] = number of header/empty rows strictly before row i.
    final chromeBefore = Int32List(rows.length + 1);
    for (var i = 0; i < rows.length; i++) {
      chromeBefore[i + 1] =
          chromeBefore[i] + (rows[i].kind == JourneyRowKind.node ? 0 : 1);
    }
    return JourneyRows._(rows, chromeBefore, firstRowOfId);
  }

  /// The rows, top to bottom.
  final List<JourneyRow> rows;

  final Int32List _chromeBefore;
  final Map<String, int> _firstRowOfId;

  /// Number of rows.
  int get length => rows.length;

  /// Row index of the first node with [id], or null.
  int? indexOfNode(String id) => _firstRowOfId[id];

  /// Id of the first node in the current state, or null.
  String? get currentNodeId {
    for (final row in rows) {
      if (row.node?.state == JourneyNodeState.current) return row.node!.id;
    }
    return null;
  }

  /// Total number of nodes.
  int get nodeCount => length - _chromeBefore[length];

  /// Height of row [index].
  double extentOf(int index, double headerExtent, double rowExtent) =>
      rows[index].kind == JourneyRowKind.node ? rowExtent : headerExtent;

  /// Scroll offset of the top of row [index].
  double offsetOf(int index, double headerExtent, double rowExtent) {
    final chrome = _chromeBefore[index];
    return chrome * headerExtent + (index - chrome) * rowExtent;
  }

  /// Total content height.
  double totalExtent(double headerExtent, double rowExtent) =>
      offsetOf(length, headerExtent, rowExtent);
}
