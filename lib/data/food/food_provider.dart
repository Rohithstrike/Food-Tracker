// Food data providers.
//
// A provider supplies food records from ONE source (sample data, a bundled
// USDA subset, a curated Indian layer, ...). The UI never talks to providers
// directly: it uses FoodRepository, so sources can be added, replaced or
// updated without changing any screen.

import '../../domain/food/food.dart';

/// Describes a data source, its licence and the attribution it requires.
final class DataSourceInfo {
  const DataSourceInfo({
    required this.id,
    required this.name,
    required this.licence,
    this.attribution,
    this.isSample = false,
  });

  /// Short, stable identifier. Every food id from this source must start
  /// with "$id:" so ids stay unique across sources.
  final String id;
  final String name;

  /// Licence summary, e.g. "Public domain (USDA FoodData Central)".
  final String licence;

  /// Text that must be shown where this data appears, when required.
  final String? attribution;

  /// True for development sample data that is NOT real nutrition data.
  final bool isSample;

  String get idPrefix => '$id:';
}

/// A source of food records that are loaded once and searched locally.
/// Bundled, offline datasets implement this.
abstract interface class FoodProvider {
  DataSourceInfo get source;

  /// All foods offered by this provider.
  Future<List<Food>> loadFoods();
}
