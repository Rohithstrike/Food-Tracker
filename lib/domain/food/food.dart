// Food records: identity, names, classification, nutrition per 100 g,
// servings, cooking variants and provenance.
//
// Nutrition values are per 100 g of the food in the state given by
// [Food.state]: raw, cooked, or ready to eat as sold/served. Data status is
// explicit, so sample or estimated values can never be mistaken for
// verified data.

import '../nutrition/nutrition.dart';
import 'serving.dart';

enum FoodCategory {
  dish,
  bread,
  rice,
  curry,
  snack,
  sweet,
  beverage,
  ingredient,
  packaged,
}

enum FoodRegion {
  panIndian,
  southIndian,
  northIndian,
  westernIndian,
  easternIndian,
  northeastIndian,
}

/// Where a food's values came from.
enum DataStatus {
  /// Development sample. NOT real nutrition data.
  sample,

  /// From a documented, licensed source. Requires a [FoodSource].
  verified,

  /// Calculated from a recipe's ingredients, not measured.
  recipeEstimate,

  /// Entered by the user.
  userCustom,
}

/// What the per-100 g values describe.
enum FoodState {
  /// Uncooked weight (for example raw chicken breast).
  raw,

  /// Cooked weight (for example grilled chicken breast).
  cooked,

  /// Ready to eat as sold or served (for example a cooked dish or oil).
  ready,
}

/// How a food record was prepared. A separate record per method is
/// preferred over adjusting numbers, so values stay source-backed.
enum PreparationMethod {
  raw,
  boiled,
  steamed,
  grilled,
  roasted,
  baked,
  panFried,
  deepFried,
  curry,
  other,
}

/// Citation for source-backed data.
final class FoodSource {
  const FoodSource({
    required this.citation,
    this.licenceNote,
    this.recordId,
    this.url,
  });

  final String citation;
  final String? licenceNote;

  /// The record's identifier in the original dataset (e.g. an FDC ID).
  final String? recordId;
  final String? url;
}

/// A way of preparing a food that changes its nutrition, for example
/// "more oil". Changes are per-nutrient multipliers and are ALWAYS estimates.
final class CookingVariant {
  CookingVariant({
    required String id,
    required this.label,
    required Map<NutrientKind, num> factors,
    required this.assumption,
  }) : id = _requireText(id, 'id'),
       factorsPermille = Map<NutrientKind, int>.unmodifiable(
         _toPermille(factors),
       ) {
    if (factorsPermille.isNotEmpty && assumption.trim().isEmpty) {
      throw ArgumentError.value(
        assumption,
        'assumption',
        'must explain how the estimate was made',
      );
    }
  }

  /// Largest multiplier a variant may apply to a nutrient.
  static const double maxFactor = 5.0;

  final String id;
  final String label;

  /// Multipliers in thousandths (1500 means x1.5). Nutrients that are not
  /// listed are unchanged.
  final Map<NutrientKind, int> factorsPermille;

  /// Plain-language explanation of the estimate, shown with results.
  final String assumption;

  /// True when this variant changes any nutrient.
  bool get isEstimate => factorsPermille.isNotEmpty;

  int factorPermilleFor(NutrientKind kind) => factorsPermille[kind] ?? 1000;
}

/// A food record.
final class Food {
  Food({
    required String id,
    required String name,
    List<String> aliases = const <String>[],
    required this.category,
    required this.region,
    required this.per100g,
    List<Serving> servings = const <Serving>[],
    List<CookingVariant> variants = const <CookingVariant>[],
    required this.status,
    this.source,
    String? family,
    String? variety,
    this.preparation,
    this.state = FoodState.ready,
  }) : id = _requireText(id, 'id'),
       name = _requireText(name, 'name'),
       aliases = List<String>.unmodifiable(
         aliases
             .map((String alias) => alias.trim())
             .where((String alias) => alias.isNotEmpty),
       ),
       servings = List<Serving>.unmodifiable(_withGramServing(servings)),
       variants = List<CookingVariant>.unmodifiable(variants),
       family = _optionalText(family),
       variety = _optionalText(variety) {
    _requireUniqueIds(servings.map((Serving s) => s.id), 'serving');
    _requireUniqueIds(variants.map((CookingVariant v) => v.id), 'variant');
    if (status == DataStatus.verified && source == null) {
      throw ArgumentError.value(
        source,
        'source',
        'is required for verified foods',
      );
    }
  }

  final String id;
  final String name;
  final List<String> aliases;
  final FoodCategory category;
  final FoodRegion region;

  /// Nutrition per 100 g, in the state given by [state].
  final NutrientProfile per100g;

  /// Always starts with the built-in 1 g serving.
  final List<Serving> servings;
  final List<CookingVariant> variants;
  final DataStatus status;
  final FoodSource? source;

  /// Groups varieties for search, e.g. "Chicken".
  final String? family;

  /// The specific variety within [family], e.g. "Breast, skinless".
  final String? variety;

  /// How this record was prepared, when known.
  final PreparationMethod? preparation;

  /// What the per-100 g values describe.
  final FoodState state;

  bool get isSample => status == DataStatus.sample;

  /// Lower-case, single-spaced name and aliases, for search.
  List<String> get searchTerms =>
      <String>[name, ...aliases].map(_normalise).toList(growable: false);

  Serving? servingById(String id) {
    for (final Serving serving in servings) {
      if (serving.id == id) {
        return serving;
      }
    }
    return null;
  }

  CookingVariant? variantById(String id) {
    for (final CookingVariant variant in variants) {
      if (variant.id == id) {
        return variant;
      }
    }
    return null;
  }
}

List<Serving> _withGramServing(List<Serving> servings) {
  for (final Serving serving in servings) {
    if (serving.id == Serving.gramId) {
      throw ArgumentError(
        'The 1 g serving is built in and must not be redefined.',
      );
    }
  }
  return <Serving>[Serving.gram(), ...servings];
}

Map<NutrientKind, int> _toPermille(Map<NutrientKind, num> factors) {
  final Map<NutrientKind, int> result = <NutrientKind, int>{};
  for (final MapEntry<NutrientKind, num> entry in factors.entries) {
    final NutrientKind kind = entry.key;
    final num factor = entry.value;
    if (!factor.isFinite || factor < 0 || factor > CookingVariant.maxFactor) {
      throw ArgumentError.value(
        factor,
        'factors.${kind.name}',
        'must be between 0 and ${CookingVariant.maxFactor}',
      );
    }
    final int permille = (factor * 1000).round();
    if (permille != 1000) {
      result[kind] = permille;
    }
  }
  return result;
}

void _requireUniqueIds(Iterable<String> ids, String what) {
  final Set<String> seen = <String>{};
  for (final String id in ids) {
    if (!seen.add(id)) {
      throw ArgumentError('Duplicate $what id: $id');
    }
  }
}

String _requireText(String value, String name) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return trimmed;
}

String? _optionalText(String? value) {
  if (value == null) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _normalise(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
