import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_undo_trash/shipglows_undo_trash.dart';

void main() {
  test('a const empty journal accepts its first entry', () {
    const journal = UndoJournal<int>();

    final next = journal.append(1);

    expect(next.entries, [1]);
    expect(next.append(2, replaceLast: true).entries, [2]);
    expect(next.undo().append(3).entries, [3]);
  });
}
