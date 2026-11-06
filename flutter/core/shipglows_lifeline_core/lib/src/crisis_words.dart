import 'package:shipglows_organize/shipglows_organize.dart';

/// Expressions about wanting to die or harming oneself, in [searchKey] form.
const List<String> _crisisExpressions = [
  'mourir',
  'suicid',
  'me tuer',
  'me foutre en l air',
  'en finir',
  'disparaitre',
  'plus envie de vivre',
  'plus vivre',
  'me faire du mal',
  'me faire mal',
  'me mutiler',
  'me scarifier',
  'scarification',
  'want to die',
  'kill myself',
  'end my life',
  'hurt myself',
  'self harm',
  'self-harm',
];

/// Everyday phrases holding one of those expressions, removed before matching.
const List<String> _harmlessPhrases = ['mourir de rire', 'mourir de faim'];

/// Whether free [text] talks about wanting to die or harming oneself.
///
/// Case, accents and apostrophes are ignored. A simple word match: it misses
/// many ways of saying it and can be wrong, so it only ever offers help.
bool mentionsCrisis(String text) {
  var key = searchKey(text).replaceAll(RegExp(r"['’]"), ' ');
  for (final phrase in _harmlessPhrases) {
    key = key.replaceAll(phrase, '');
  }
  return _crisisExpressions.any(key.contains);
}
