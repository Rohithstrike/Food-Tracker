// Shared text and quantity rules for food search and food details.
//
// Keeping these in one place means the search list, the detail sheet and
// later the logging flow all describe foods and amounts the same way.

import '../../domain/food/food.dart';
import '../../domain/food/serving.dart';
import '../../domain/nutrition/nutrition.dart';

/// The food used for "Added oil".
/// SAMPLE data until a licensed dataset replaces it.
const String defaultOilFoodId = 'sample:sunflower_oil';

/// Shown when the search field is empty.
const String searchHint = 'Try idli, chicken or roti';

/// Shown wherever sample foods appear.
const String sampleDataNotice =
    'Sample data for development. These are not real nutrition values.';

/// Grams added or removed per tap on the oil stepper.
const num oilStepGrams = 0.5;

/// Upper limit for added oil in one entry.
const num maxOilGrams = 50;

String stateLabel(FoodState state) => switch (state) {
  FoodState.raw => 'Raw',
  FoodState.cooked => 'Cooked',
  FoodState.ready => 'Ready to eat',
};

/// One-line description for search results, e.g.
/// "Ready to eat · 140 kcal per 100 g · Sample".
String describeFood(Food food) {
  final NutrientAmount? energy = food.per100g.amountOf(NutrientKind.energy);
  final List<String> parts = <String>[
    stateLabel(food.state),
    if (energy != null)
      '${formatAmount(energy, NutrientKind.energy)} kcal per 100 g'
    else
      'Energy not available',
    if (food.isSample) 'Sample',
  ];
  return parts.join(' \u00B7 ');
}

/// Label for a serving choice: "Grams", "Idli", "Bowl", ...
String servingChipLabel(Serving serving) {
  if (serving.id == Serving.gramId) {
    return 'Grams';
  }
  final String label = serving.singularLabel;
  return label.substring(0, 1).toUpperCase() + label.substring(1);
}

/// The serving a food opens with: its first household serving if it has
/// one, otherwise grams.
String defaultServingId(Food food) {
  for (final Serving serving in food.servings) {
    if (serving.id != Serving.gramId) {
      return serving.id;
    }
  }
  return Serving.gramId;
}

num defaultQuantityFor(String servingId) =>
    servingId == Serving.gramId ? 100 : 1;

num quantityStepFor(String servingId) => servingId == Serving.gramId ? 10 : 0.5;

num maxQuantityFor(String servingId) => servingId == Serving.gramId ? 2000 : 20;

/// 1 -> "1", 1.5 -> "1.5", 1240 -> "1,240".
String formatQuantity(num value) {
  if (value == value.roundToDouble()) {
    return _thousands(value.round());
  }
  return value.toStringAsFixed(1);
}

/// Display text for a nutrient amount: whole kcal, otherwise one decimal
/// (trailing ".0" removed).
String formatAmount(NutrientAmount amount, NutrientKind kind) {
  if (kind == NutrientKind.energy) {
    return _thousands(amount.toUnits(decimals: 0).round());
  }
  final double value = amount.toUnits(decimals: 1);
  if (value == value.roundToDouble()) {
    return _thousands(value.round());
  }
  return value.toStringAsFixed(1);
}

/// Milligrams of food as a gram figure, e.g. 80000 -> "80".
String formatWeight(int milligrams) => formatQuantity(milligrams / 1000);

String _thousands(int value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits.substring(i, i + 1));
  }
  return buffer.toString();
}
