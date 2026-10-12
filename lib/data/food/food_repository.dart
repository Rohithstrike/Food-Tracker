// The single entry point the UI uses for food data.
//
// Loads every provider once, checks ids are unique and correctly prefixed,
// and answers search and lookup queries from an in-memory index, so search
// is instant and works offline.

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
  final Map<String, Food> _byId = <String, Food>{};
  final Map<String, DataSourceInfo> _sourceById = <String, DataSourceInfo>{};

  bool get isLoaded => _index != null;

  /// Loads all providers. Safe to call more than once: loading happens once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final Set<String> sourceIds = <String>{};
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
        if (_byId.containsKey(food.id)) {
          throw StateError('Duplicate food id: ${food.id}');
        }
        if (source.isSample && !food.isSample) {
          throw StateError(
            'Food "${food.id}" comes from a sample source and must be '
            'marked as sample data.',
          );
        }
        _byId[food.id] = food;
        _sourceById[food.id] = source;
        all.add(food);
      }
    }
    _index = FoodSearchIndex(all);
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
