// Local food search: normalisation and ranking.
//
// Matching is done against a food's name, aliases (regional names and
// spelling variations), family and variety. Ranking, best first:
//   100  a term equals the query
//    80  a term starts with the query
//    60  every query word starts a word in the term
//    40  a term contains the query
// Ties: the name matching beats an alias matching, then shorter names,
// then alphabetical order, so results are stable.

import '../../domain/food/food.dart';

/// Lower-case, letters and digits only (any script), single-spaced.
String normaliseSearchText(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

final class FoodSearchIndex {
  FoodSearchIndex(Iterable<Food> foods)
    : _entries = List<_IndexEntry>.unmodifiable(foods.map(_IndexEntry.new));

  final List<_IndexEntry> _entries;

  int get length => _entries.length;

  /// Foods matching [query], best first. Empty queries return nothing.
  List<Food> search(String query, {int limit = 50}) {
    final String q = normaliseSearchText(query);
    if (q.isEmpty || limit <= 0) {
      return const <Food>[];
    }
    final List<String> words = q.split(' ');

    final List<_Scored> scored = <_Scored>[];
    for (final _IndexEntry entry in _entries) {
      final int nameScore = _score(entry.name, q, words);
      int best = nameScore;
      for (final String term in entry.otherTerms) {
        final int s = _score(term, q, words);
        if (s > best) {
          best = s;
        }
      }
      if (best > 0) {
        scored.add(_Scored(entry.food, best, nameScore == best));
      }
    }

    scored.sort((_Scored a, _Scored b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      if (a.nameMatched != b.nameMatched) {
        return a.nameMatched ? -1 : 1;
      }
      final int byLength = a.food.name.length.compareTo(b.food.name.length);
      if (byLength != 0) {
        return byLength;
      }
      return a.food.name.compareTo(b.food.name);
    });

    return scored
        .take(limit)
        .map((_Scored s) => s.food)
        .toList(growable: false);
  }

  static int _score(String term, String q, List<String> words) {
    if (term.isEmpty) {
      return 0;
    }
    if (term == q) {
      return 100;
    }
    if (term.startsWith(q)) {
      return 80;
    }
    final List<String> termWords = term.split(' ');
    final bool allWordsMatch = words.every(
      (String w) => termWords.any((String t) => t.startsWith(w)),
    );
    if (allWordsMatch) {
      return 60;
    }
    if (term.contains(q)) {
      return 40;
    }
    return 0;
  }
}

final class _IndexEntry {
  _IndexEntry(this.food)
    : name = normaliseSearchText(food.name),
      otherTerms = List<String>.unmodifiable(
        <String?>[...food.aliases, food.family, food.variety]
            .whereType<String>()
            .map(normaliseSearchText)
            .where((String t) => t.isNotEmpty),
      );

  final Food food;
  final String name;
  final List<String> otherTerms;
}

final class _Scored {
  _Scored(this.food, this.score, this.nameMatched);

  final Food food;
  final int score;
  final bool nameMatched;
}
