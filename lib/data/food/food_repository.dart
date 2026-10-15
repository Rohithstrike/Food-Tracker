// The single entry point the UI uses for food data.
//
// Loads every provider once, checks ids are unique and correctly prefixed,
// and answers search and lookup queries from an in-memory index, so search
// is instant and works offline.
//
// LOADING IS ATOMIC: the catalogue is built in temporary structures and only
// published once EVERY provider has loaded and passed validation. A failed
// load publishes nothing, and calling load() again starts a fresh attempt.

import 'dart:async';

import '../../domain/food/food.dart';
import 'food_provider.dart';
import 'food_search.dart';

/// A search result together with the source it came from.
final class FoodSearchResult {
  const FoodSearchResult({required this.food, required this.source});

  final Food food;
  final DataSourceInfo source;
}

final class FoodRepository {
  FoodRepository(List<FoodProvider> providers)
    : _providers = List<FoodProvider>.unmodifiable(providers);

  final List<FoodProvider> _providers;

  Future<void>? _loading;
  FoodSearchIndex? _index;
  Map<String, Food> _byId = const <String, Food>{};
  Map<String, DataSourceInfo> _sourceById = const <String, DataSourceInfo>{};

  /// True once a complete catalogue has been published.
  bool get isLoaded => _index != null;

  /// Loads all providers.
  ///
  /// Concurrent and repeated calls share one attempt, and a successful load
  /// happens only once. If the attempt fails, nothing is published, the error
  /// is rethrown, and the next call starts a new attempt.
  Future<void> load() {
    final Future<void>? inFlight = _loading;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<void> attempt = _loadAtomically();
    _loading = attempt;
    // Registered before the caller can listen, so a failed attempt is
    // cleared before any caller's error handling runs.
    unawaited(
      attempt.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_loading, attempt)) {
            _loading = null;
          }
        },
      ),
    );
    return attempt;
  }

  Future<void> _loadAtomically() async {
    final _Catalogue catalogue = await _build();
    _byId = Map<String, Food>.unmodifiable(catalogue.byId);
    _sourceById = Map<String, DataSourceInfo>.unmodifiable(
      catalogue.sourceById,
    );
    _index = catalogue.index;
  }

  /// Builds a complete, validated catalogue without touching published state.
  Future<_Catalogue> _build() async {
    final Set<String> sourceIds = <String>{};
    final Map<String, Food> byId = <String, Food>{};
    final Map<String, DataSourceInfo> sourceById = <String, DataSourceInfo>{};
    final List<Food> all = <Food>[];

    for (final FoodProvider provider in _providers) {
      final DataSourceInfo source = provider.source;
      if (!sourceIds.add(source.id)) {
        throw StateError('Duplicate data source id: ${source.id}');
      }
      for (final Food food in await provider.loadFoods()) {
        if (!food.id.startsWith(source.idPrefix)) {
          throw StateError(
            'Food id "${food.id}" must start with "${source.idPrefix}".',
          );
        }
        if (byId.containsKey(food.id)) {
          throw StateError('Duplicate food id: ${food.id}');
        }
        if (source.isSample && !food.isSample) {
          throw StateError(
            'Food "${food.id}" comes from a sample source and must be '
            'marked as sample data.',
          );
        }
        byId[food.id] = food;
        sourceById[food.id] = source;
        all.add(food);
      }
    }
    return _Catalogue(
      byId: byId,
      sourceById: sourceById,
      index: FoodSearchIndex(all),
    );
  }

  FoodSearchIndex _requireIndex() {
    final FoodSearchIndex? index = _index;
    if (index == null) {
      throw StateError('FoodRepository.load() must complete first.');
    }
    return index;
  }

  int get foodCount => _requireIndex().length;

  List<FoodSearchResult> search(String query, {int limit = 50}) =>
      _requireIndex()
          .search(query, limit: limit)
          .map(
            (Food food) =>
                FoodSearchResult(food: food, source: _sourceById[food.id]!),
          )
          .toList(growable: false);

  Food? foodById(String id) {
    _requireIndex();
    return _byId[id];
  }

  DataSourceInfo? sourceOf(String foodId) {
    _requireIndex();
    return _sourceById[foodId];
  }

  /// All varieties in a family (e.g. every "Chicken" record), by name.
  List<Food> varietiesOf(String family) {
    _requireIndex();
    final String wanted = normaliseSearchText(family);
    final List<Food> result = _byId.values
        .where(
          (Food food) =>
              food.family != null &&
              normaliseSearchText(food.family!) == wanted,
        )
        .toList();
    result.sort((Food a, Food b) => a.name.compareTo(b.name));
    return List<Food>.unmodifiable(result);
  }
}

/// A fully built catalogue, ready to publish.
final class _Catalogue {
  const _Catalogue({
    required this.byId,
    required this.sourceById,
    required this.index,
  });

  final Map<String, Food> byId;
  final Map<String, DataSourceInfo> sourceById;
  final FoodSearchIndex index;
}
