import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_organize/shipglows_organize.dart';

void main() {
  test('nameKey ignores case, accents and spaces', () {
    expect(nameKey('  Élodie   Ça '), 'elodie ca');
    expect(compareNames('b', 'Á'), greaterThan(0));
  });

  test('checkNameAmong refuses empty and taken names', () {
    const names = ['Rock', 'Jazz'];
    expect(checkNameAmong(names, '  '), FolderProblem.emptyName);
    expect(checkNameAmong(names, ' rock '), FolderProblem.nameTaken);
    expect(checkNameAmong(names, 'rock', exceptName: 'Rock'), isNull);
    expect(checkNameAmong(names, 'Blues'), isNull);
  });

  test('duplicateAliases keeps the smallest id of each name', () {
    final items = [('b', 'Muse'), ('a', 'muse '), ('c', 'Björk')];
    expect(
      duplicateAliases(items, id: (item) => item.$1, name: (item) => item.$2),
      {'b': 'a'},
    );
  });
}
