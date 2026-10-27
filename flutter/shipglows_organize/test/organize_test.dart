import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_organize/shipglows_organize.dart';

void main() {
  group('tags', () {
    test('normalize a typed string', () {
      expect(normalizeTags('#Work, work  #ideas'), ['work', 'ideas']);
    });

    test('rename merges into an existing tag', () {
      expect(renameTag(['a', 'b', 'c'], 'a', 'C'), ['c', 'b']);
    });

    test('counts each item once per tag', () {
      expect(
        tagCounts([
          ['b', 'a', 'a'],
          ['a'],
        ]),
        {'a': 2, 'b': 1},
      );
    });
  });

  group('FolderTree', () {
    final tree = FolderTree(const [
      Folder(id: 'p', name: 'Projets'),
      Folder(id: 'c', name: 'Clients', parentId: 'p'),
      Folder(id: 'a', name: 'Acme', parentId: 'c'),
      Folder(id: 'x', name: 'Orphan', parentId: 'gone'),
    ]);

    test('path, label and subtree', () {
      expect(tree.label('a'), 'Projets / Clients / Acme');
      expect(tree.subtreeIds('p'), {'p', 'c', 'a'});
      expect(tree.children(null).map((f) => f.id), ['x', 'p']);
    });

    test('refuses a move into its own subtree', () {
      expect(tree.checkMove('p', 'a'), FolderProblem.cycle);
      expect(tree.checkMove('a', null), isNull);
    });

    test('sibling names are unique ignoring case', () {
      expect(tree.checkName(' clients ', 'p'), FolderProblem.nameTaken);
      expect(tree.checkName('Clients', null), isNull);
    });

    test('a stored cycle falls back to the root', () {
      final broken = FolderTree(const [
        Folder(id: '1', name: 'One', parentId: '2'),
        Folder(id: '2', name: 'Two', parentId: '1'),
      ]);
      expect(broken.children(null).length, 2);
    });
  });

  test('query and filter', () {
    final query = OrganizeQuery.parse('#wo acme');
    expect(query.matches(tags: ['work'], fields: ['Acme deal']), isTrue);
    expect(query.matches(tags: ['home'], fields: ['Acme deal']), isFalse);

    const filter = OrganizeFilter(tags: {'a', 'b'}, tagMatch: TagMatch.any);
    expect(filter.matches(tags: ['b']), isTrue);
    expect(filter.matches(tags: ['c']), isFalse);
  });
}
