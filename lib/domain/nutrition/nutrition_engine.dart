// Nutrition calculation, kept separate from the UI.
//
// FORMULA, for each KNOWN nutrient:
//
//   result = per-100 g value
//            x serving weight (g)
//            x quantity
//            x cooking-variant factor
//            / 100
//
// In fixed-point form (all integers):
//
//   resultMilli = per100Milli x servingMg x quantityMilli x factorPermille
//                 / 100,000,000,000
//
// The product is computed with BigInt, so it cannot overflow on any
// platform, and it is ROUNDED ONCE, half-up, to 0.001 of the unit.
// Unknown nutrients stay unknown. Quantity resolution is 0.001.

import '../food/food.dart';
import '../food/serving.dart';
import 'nutrition.dart';

enum NutritionInputError {
  invalidQuantity,
  quantityTooLarge,
  unknownServing,
  unknownVariant,
}

final class NutritionInputException implements Exception {
  const NutritionInputException(this.error, this.message);

  final NutritionInputError error;
  final String message;

  @override
  String toString() => 'NutritionInputException(${error.name}): $message';
}

/// Nutrition for one food at one quantity, serving and variant.
final class CalculatedNutrition {
  CalculatedNutrition({
    required this.foodId,
    required this.servingId,
    required this.variantId,
    required this.quantityMilli,
    required this.totalMilligrams,
    required this.nutrients,
    required this.isSample,
    required this.isEstimate,
    required List<String> assumptions,
  }) : assumptions = List<String>.unmodifiable(assumptions);

  final String foodId;
  final String servingId;
  final String? variantId;

  /// Quantity in thousandths (1500 means 1.5 servings).
  final int quantityMilli;

  /// Total weight eaten, in milligrams.
  final int totalMilligrams;

  /// Known nutrients only; unknown nutrients are absent.
  final NutrientProfile nutrients;

  /// The food is development sample data, not real nutrition.
  final bool isSample;

  /// The result relies on an estimated weight, variant or recipe.
  final bool isEstimate;

  /// Plain-language explanations of samples and estimates.
  final List<String> assumptions;

  double get quantity => quantityMilli / 1000;
}

/// A daily (or meal) total for one nutrient.
final class NutrientTotal {
  const NutrientTotal({required this.amount, required this.missingCount});

  /// Sum of KNOWN values only.
  final NutrientAmount amount;

  /// How many items did not know this nutrient.
  final int missingCount;

  bool get isComplete => missingCount == 0;
}

final class NutritionTotals {
  NutritionTotals._({
    required Map<NutrientKind, NutrientTotal> byKind,
    required this.itemCount,
    required this.isSample,
    required this.isEstimate,
  }) : byKind = Map<NutrientKind, NutrientTotal>.unmodifiable(byKind);

  final Map<NutrientKind, NutrientTotal> byKind;
  final int itemCount;
  final bool isSample;
  final bool isEstimate;

  NutrientTotal operator NutrientKind kind => byKind[kind]!;

  bool get isComplete => byKind.values.every((total) => total.isComplete);
}

abstract final class NutritionEngine {
  /// Largest number of servings in one entry.
  static const int maxQuantity = 10000;

  /// Largest total weight in one entry: 5 kg.
  static const int maxTotalMilligrams = 5000000;

  static final BigInt _denominator = BigInt.from(100000000000);
  static final BigInt _thousand = BigInt.from(1000);

  static CalculatedNutrition calculate({
    required Food food,
    required String servingId,
    required num quantity,
    String? variantId,
  }) {
    if (!quantity.isFinite || quantity <= 0) {
      throw const NutritionInputException(
        NutritionInputError.invalidQuantity,
        'Quantity must be a positive number.',
      );
    }
    if (quantity > maxQuantity) {
      throw const NutritionInputException(
        NutritionInputError.quantityTooLarge,
        'Quantity is larger than allowed.',
      );
    }
    final quantityMilli = (quantity * 1000).round();
    if (quantityMilli <= 0) {
      throw const NutritionInputException(
        NutritionInputError.invalidQuantity,
        'Quantity must be at least 0.001.',
      );
    }

    final serving = food.servingById(servingId);
    if (serving == null) {
      throw NutritionInputException(
        NutritionInputError.unknownServing,
        'Unknown serving "$servingId" for ${food.name}.',
      );
    }

    CookingVariant? variant;
    if (variantId != null) {
      variant = food.variantById(variantId);
      if (variant == null) {
        throw NutritionInputException(
          NutritionInputError.unknownVariant,
          'Unknown variant "$variantId" for ${food.name}.',
        );
      }
    }

    final totalMilligrams = _roundHalfUp(
      BigInt.from(serving.milligrams) * BigInt.from(quantityMilli),
      _thousand,
    );
    if (totalMilligrams > maxTotalMilligrams) {
      throw const NutritionInputException(
        NutritionInputError.quantityTooLarge,
        'Total weight is larger than 5 kg.',
      );
    }

    final scaled = <NutrientKind, NutrientAmount>{};
    for (final entry in food.per100g.known.entries) {
      final factor = variant?.factorPermilleFor(entry.key) ?? 1000;
      final numerator = BigInt.from(entry.value.milli) *
          BigInt.from(serving.milligrams) *
          BigInt.from(quantityMilli) *
          BigInt.from(factor);
      scaled[entry.key] =
          NutrientAmount.milli(_roundHalfUp(numerator, _denominator));
    }

    final assumptions = <String>[];
    switch (food.status) {
      case DataStatus.sample:
        assumptions.add(
          'Sample data for development only. '
          'These are not real nutrition values.',
        );
      case DataStatus.recipeEstimate:
        assumptions.add('Nutrition is calculated from a recipe, not measured.');
      case DataStatus.userCustom:
        assumptions.add('Nutrition values were entered by the user.');
      case DataStatus.verified:
        break;
    }
    final estimatedWeight =
        serving.weightBasis == ServingWeightBasis.estimated;
    if (estimatedWeight) {
      assumptions.add(
        'The weight of 1 ${serving.singularLabel} '
        '(${_formatGrams(serving.milligrams)} g) is estimated.',
      );
    }
    final variantEstimate = variant?.isEstimate ?? false;
    if (variantEstimate) {
      assumptions.add(variant!.assumption);
    }

    return CalculatedNutrition(
      foodId: food.id,
      servingId: serving.id,
      variantId: variant?.id,
      quantityMilli: quantityMilli,
      totalMilligrams: totalMilligrams,
      nutrients: NutrientProfile(scaled),
      isSample: food.isSample,
      isEstimate: food.status == DataStatus.recipeEstimate ||
          estimatedWeight ||
          variantEstimate,
      assumptions: assumptions,
    );
  }

  /// Adds up items. Unknown values are NOT treated as zero: each nutrient
  /// total counts how many items were missing it.
  static NutritionTotals total(Iterable<CalculatedNutrition> items) {
    final list = items.toList();
    final sums = {for (final kind in NutrientKind.values) kind: 0};
    final missing = {for (final kind in NutrientKind.values) kind: 0};

    for (final item in list) {
      for (final kind in NutrientKind.values) {
        final amount = item.nutrients[kind];
        if (amount == null) {
          missing[kind] = missing[kind]! + 1;
        } else {
          sums[kind] = sums[kind]! + amount.milli;
        }
      }
    }

    return NutritionTotals._(
      byKind: {
        for (final kind in NutrientKind.values)
          kind: NutrientTotal(
            amount: NutrientAmount.milli(sums[kind]!),
            missingCount: missing[kind]!,
          ),
      },
      itemCount: list.length,
      isSample: list.any((item) => item.isSample),
      isEstimate: list.any((item) => item.isEstimate),
    );
  }

  static int _roundHalfUp(BigInt numerator, BigInt denominator) =>
      ((numerator + denominator ~/ BigInt.two) ~/ denominator).toInt();

  static String _formatGrams(int milligrams) => milligrams % 1000 == 0
      ? '${milligrams ~/ 1000}'
      : (milligrams / 1000).toString();
}