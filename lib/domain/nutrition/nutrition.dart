// Nutrition values stored as fixed-point amounts.
//
// Every amount is an integer number of thousandths of its unit
// ("milli-units"): 1.5 g protein is stored as 1500, and 88 kcal as 88000.
// This avoids floating-point drift when values are scaled and summed.
//
// An UNKNOWN nutrient has no entry at all. A known zero is stored as 0.
// The two are never treated as the same thing.

/// The nutrients the app tracks. Each has one fixed unit.
enum NutrientKind {
  energy('Energy', 'kcal'),
  protein('Protein', 'g'),
  carbohydrates('Carbohydrates', 'g'),
  fat('Fat', 'g'),
  fibre('Fibre', 'g'),
  sugar('Sugar', 'g'),
  sodium('Sodium', 'mg');

  const NutrientKind(this.label, this.unit);

  final String label;
  final String unit;
}

/// A non-negative nutrient amount, in thousandths of its unit.
final class NutrientAmount {
  const NutrientAmount.milli(this.milli)
      : assert(milli >= 0, 'Nutrient amounts cannot be negative.');

  /// Converts a value in whole units (for example 1.5 g) to a fixed-point
  /// amount. Resolution is 0.001 of the unit; finer detail is rounded.
  factory NutrientAmount.of(num value) {
    if (!value.isFinite || value < 0 || value > maxUnits) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a finite number between 0 and $maxUnits',
      );
    }
    return NutrientAmount.milli((value * 1000).round());
  }

  static const NutrientAmount zero = NutrientAmount.milli(0);

  /// Upper bound for a single input value, in whole units.
  static const int maxUnits = 1000000;

  static const List<int> _roundingSteps = [1000, 100, 10, 1];

  /// Amount in thousandths of the unit.
  final int milli;

  NutrientAmount operator +(NutrientAmount other) =>
      NutrientAmount.milli(milli + other.milli);

  /// Value in whole units, rounded half-up to [decimals] places (0 to 3).
  /// Intended for display: calories usually use 0, grams 1.
  double toUnits({int decimals = 3}) {
    if (decimals < 0 || decimals > 3) {
      throw RangeError.range(decimals, 0, 3, 'decimals');
    }
    final step = _roundingSteps[decimals];
    final rounded = (milli + step ~/ 2) ~/ step * step;
    return rounded / 1000;
  }

  @override
  bool operator ==(Object other) =>
      other is NutrientAmount && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => 'NutrientAmount(${toUnits()})';
}

/// A set of nutrient amounts. Kinds without an entry are UNKNOWN.
final class NutrientProfile {
  NutrientProfile(Map<NutrientKind, NutrientAmount> known)
      : known = Map<NutrientKind, NutrientAmount>.unmodifiable(known);

  /// Values per 100 g of the food as eaten.
  ///
  /// Every nutrient must be given explicitly: a number when known, or null
  /// when unknown. This prevents a missing value from silently becoming 0.
  factory NutrientProfile.per100g({
    required num? energyKcal,
    required num? proteinG,
    required num? carbohydratesG,
    required num? fatG,
    required num? fibreG,
    required num? sugarG,
    required num? sodiumMg,
  }) {
    final values = <NutrientKind, num?>{
      NutrientKind.energy: energyKcal,
      NutrientKind.protein: proteinG,
      NutrientKind.carbohydrates: carbohydratesG,
      NutrientKind.fat: fatG,
      NutrientKind.fibre: fibreG,
      NutrientKind.sugar: sugarG,
      NutrientKind.sodium: sodiumMg,
    };
    return NutrientProfile({
      for (final entry in values.entries)
        if (entry.value != null) entry.key: NutrientAmount.of(entry.value!),
    });
  }

  /// Known amounts only.
  final Map<NutrientKind, NutrientAmount> known;

  /// The amount for [kind], or null when it is unknown.
  NutrientAmount? operator NutrientKind kind => known[kind];

  bool isKnown(NutrientKind kind) => known.containsKey(kind);

  Set<NutrientKind> get unknownKinds => {
        for (final kind in NutrientKind.values)
          if (!known.containsKey(kind)) kind,
      };
}