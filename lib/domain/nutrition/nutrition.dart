// Nutrition values stored as fixed-point amounts.
//
// Every amount is an integer number of thousandths of its unit
// ("milli-units"): 1.5 g protein is stored as 1500, and 88 kcal as 88000.
// This avoids floating-point drift when values are scaled and summed.
//
// An UNKNOWN nutrient has no entry at all. A known zero is stored as 0.
// The two are never treated as the same thing.

/// Broad nutrient groups, used for display ordering.
enum NutrientGroup { energy, macronutrient, mineral, vitamin }

/// The nutrients the app tracks. Each has one fixed unit.
///
/// PERSISTENCE CONTRACT: saved entries store nutrients by [Enum.name].
/// Never rename or remove a value; only add new ones at the end.
enum NutrientKind {
  // Core seven (original set).
  energy('Energy', 'kcal', NutrientGroup.energy),
  protein('Protein', 'g', NutrientGroup.macronutrient),
  carbohydrates('Carbohydrates', 'g', NutrientGroup.macronutrient),
  fat('Fat', 'g', NutrientGroup.macronutrient),
  fibre('Fibre', 'g', NutrientGroup.macronutrient),
  sugar('Sugar', 'g', NutrientGroup.macronutrient),
  sodium('Sodium', 'mg', NutrientGroup.mineral),

  // Micronutrients. Shown only when a source provides them.
  iron('Iron', 'mg', NutrientGroup.mineral),
  calcium('Calcium', 'mg', NutrientGroup.mineral),
  potassium('Potassium', 'mg', NutrientGroup.mineral),
  magnesium('Magnesium', 'mg', NutrientGroup.mineral),
  zinc('Zinc', 'mg', NutrientGroup.mineral),
  vitaminA('Vitamin A', '\u00B5g', NutrientGroup.vitamin),
  vitaminC('Vitamin C', 'mg', NutrientGroup.vitamin),
  vitaminD('Vitamin D', '\u00B5g', NutrientGroup.vitamin),
  vitaminB12('Vitamin B12', '\u00B5g', NutrientGroup.vitamin),
  folate('Folate', '\u00B5g', NutrientGroup.vitamin);

  const NutrientKind(this.label, this.unit, this.group);

  final String label;
  final String unit;
  final NutrientGroup group;

  /// The original seven nutrients every food must state explicitly
  /// (as a value, or as explicitly unknown).
  bool get isCore => index <= NutrientKind.sodium.index;
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
    final int step = switch (decimals) {
      0 => 1000,
      1 => 100,
      2 => 10,
      _ => 1,
    };
    final int rounded = (milli + step ~/ 2) ~/ step * step;
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

  /// Values per 100 g of the food, in the state the food declares
  /// (raw, cooked or ready to eat).
  ///
  /// The core seven must be given explicitly: a number when known, or null
  /// when unknown. This prevents a missing value from silently becoming 0.
  /// Micronutrients are optional and are UNKNOWN unless supplied.
  factory NutrientProfile.per100g({
    required num? energyKcal,
    required num? proteinG,
    required num? carbohydratesG,
    required num? fatG,
    required num? fibreG,
    required num? sugarG,
    required num? sodiumMg,
    num? ironMg,
    num? calciumMg,
    num? potassiumMg,
    num? magnesiumMg,
    num? zincMg,
    num? vitaminAUg,
    num? vitaminCMg,
    num? vitaminDUg,
    num? vitaminB12Ug,
    num? folateUg,
  }) {
    return NutrientProfile.fromValues(<NutrientKind, num?>{
      NutrientKind.energy: energyKcal,
      NutrientKind.protein: proteinG,
      NutrientKind.carbohydrates: carbohydratesG,
      NutrientKind.fat: fatG,
      NutrientKind.fibre: fibreG,
      NutrientKind.sugar: sugarG,
      NutrientKind.sodium: sodiumMg,
      NutrientKind.iron: ironMg,
      NutrientKind.calcium: calciumMg,
      NutrientKind.potassium: potassiumMg,
      NutrientKind.magnesium: magnesiumMg,
      NutrientKind.zinc: zincMg,
      NutrientKind.vitaminA: vitaminAUg,
      NutrientKind.vitaminC: vitaminCMg,
      NutrientKind.vitaminD: vitaminDUg,
      NutrientKind.vitaminB12: vitaminB12Ug,
      NutrientKind.folate: folateUg,
    });
  }

  /// Builds a profile from whole-unit values (used by data providers).
  /// Null values are UNKNOWN; they are never stored as zero.
  factory NutrientProfile.fromValues(Map<NutrientKind, num?> values) {
    final Map<NutrientKind, NutrientAmount> known =
        <NutrientKind, NutrientAmount>{};
    for (final MapEntry<NutrientKind, num?> entry in values.entries) {
      final num? value = entry.value;
      if (value != null) {
        known[entry.key] = NutrientAmount.of(value);
      }
    }
    return NutrientProfile(known);
  }

  /// Known amounts only.
  final Map<NutrientKind, NutrientAmount> known;

  /// The amount for [kind], or null when it is unknown.
  NutrientAmount? amountOf(NutrientKind kind) => known[kind];

  /// Index form of [amountOf]: profile[NutrientKind.fat].
  NutrientAmount? operator [](NutrientKind kind) => known[kind];

  bool isKnown(NutrientKind kind) => known.containsKey(kind);

  Set<NutrientKind> get unknownKinds => NutrientKind.values
      .where((NutrientKind kind) => !known.containsKey(kind))
      .toSet();
}
