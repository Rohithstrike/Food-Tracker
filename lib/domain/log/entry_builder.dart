// Builds log entries from the user's choices.
//
// Every number comes from the existing NutritionEngine: each component (base
// food, added oil, extras) is calculated with NutritionEngine.calculate, and
// the entry total is NutritionEngine.total of those components. There is no
// second calculation system here.

import '../food/food.dart';
import '../food/serving.dart';
import '../nutrition/nutrition_engine.dart';
import 'log_entry.dart';

/// Preset amounts of added cooking oil.
///
/// These are EDITABLE STARTING POINTS, not nutrition data. Oil added through
/// any level (or an edited gram amount) is always labelled as an estimate.
enum OilLevel {
  none('None', 0),
  veryLittle('Very little', 2.5),
  normal('Normal', 5),
  high('High', 10);

  const OilLevel(this.label, this.defaultGrams);

  final String label;

  /// Default grams of oil for one entry.
  final double defaultGrams;
}

/// A food, a serving, and how many servings.
final class FoodPortion {
  FoodPortion({
    required this.food,
    required this.servingId,
    required this.quantity,
    this.variantId,
  });

  final Food food;
  final String servingId;
  final num quantity;
  final String? variantId;
}

abstract final class EntryBuilder {
  /// Builds one entry: [base] plus optional oil and extras.
  ///
  /// [oilGrams] is the (possibly user-edited) amount of [oil] in grams.
  /// Zero means no oil component. Invalid quantities raise the engine's
  /// NutritionInputException; invalid oil input raises ArgumentError.
  ///
  /// [createdAt] keeps the original creation time when an entry is
  /// rebuilt after an edit; it defaults to [timestamp].
  static LogEntry build({
    required String id,
    required LocalDate date,
    required String mealSlotId,
    required DateTime timestamp,
    DateTime? createdAt,
    required FoodPortion base,
    Food? oil,
    num oilGrams = 0,
    List<FoodPortion> extras = const <FoodPortion>[],
  }) {
    if (!oilGrams.isFinite || oilGrams < 0) {
      throw ArgumentError.value(
        oilGrams,
        'oilGrams',
        'must be zero or a positive number of grams',
      );
    }

    final List<EntryComponent> components = <EntryComponent>[
      _component(ComponentRole.base, base),
    ];

    if (oilGrams > 0) {
      if (oil == null) {
        throw ArgumentError.value(
          oil,
          'oil',
          'is required when oilGrams is above zero',
        );
      }
      final CalculatedNutrition calculated = NutritionEngine.calculate(
        food: oil,
        servingId: Serving.gramId,
        quantity: oilGrams,
      );
      components.add(
        EntryComponent.fromCalculation(
          role: ComponentRole.oil,
          food: oil,
          nutrition: _asEstimate(
            calculated,
            'Added oil (${_formatGrams(oilGrams)} g) is an estimate. '
            'Edit the amount if you know it.',
          ),
        ),
      );
    }

    for (final FoodPortion extra in extras) {
      components.add(_component(ComponentRole.extra, extra));
    }

    return LogEntry(
      id: id,
      date: date,
      mealSlotId: mealSlotId,
      createdAt: createdAt ?? timestamp,
      updatedAt: timestamp,
      components: components,
    );
  }

  static EntryComponent _component(ComponentRole role, FoodPortion portion) =>
      EntryComponent.fromCalculation(
        role: role,
        food: portion.food,
        nutrition: NutritionEngine.calculate(
          food: portion.food,
          servingId: portion.servingId,
          quantity: portion.quantity,
          variantId: portion.variantId,
        ),
      );

  /// Same values, flagged as an estimate with an explanation.
  static CalculatedNutrition _asEstimate(
    CalculatedNutrition calculated,
    String note,
  ) => CalculatedNutrition(
    foodId: calculated.foodId,
    servingId: calculated.servingId,
    variantId: calculated.variantId,
    quantityMilli: calculated.quantityMilli,
    totalMilligrams: calculated.totalMilligrams,
    nutrients: calculated.nutrients,
    isSample: calculated.isSample,
    isEstimate: true,
    assumptions: <String>[...calculated.assumptions, note],
  );

  static String _formatGrams(num grams) => grams == grams.roundToDouble()
      ? grams.round().toString()
      : grams.toString();
}
