import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';

// =============================================================================
// Meal slots — data-driven so a future Settings milestone can rename,
// reorder and hide them. Logged food will reference [MealSlot.id], never the
// name, so renaming or hiding a slot never affects food history.
// =============================================================================

class MealSlot {
  const MealSlot({
    required this.id,
    required this.name,
    required this.icon,
    required this.position,
    this.isVisible = true,
  });

  /// Permanent identifier. Never changes, even if the user renames the slot.
  final String id;
  final String name;
  final IconData icon;

  /// Display order (lower first).
  final int position;

  /// Hidden slots keep their history; they are only removed from Today.
  final bool isVisible;
}

/// Default meal schedule (approved: seven slots).
const List<MealSlot> defaultMealSlots = [
  MealSlot(
    id: 'pre_workout',
    name: 'Pre-workout',
    icon: CupertinoIcons.bolt,
    position: 0,
  ),
  MealSlot(
    id: 'breakfast',
    name: 'Breakfast',
    icon: CupertinoIcons.sunrise,
    position: 1,
  ),
  MealSlot(
    id: 'mid_morning',
    name: 'Mid-morning',
    icon: CupertinoIcons.sun_min,
    position: 2,
  ),
  MealSlot(
    id: 'lunch',
    name: 'Lunch',
    icon: CupertinoIcons.sun_max,
    position: 3,
  ),
  MealSlot(
    id: 'snacks',
    name: 'Snacks',
    icon: CupertinoIcons.sunset,
    position: 4,
  ),
  MealSlot(
    id: 'dinner',
    name: 'Dinner',
    icon: CupertinoIcons.moon,
    position: 5,
  ),
  MealSlot(
    id: 'late_meal',
    name: 'Late meal',
    icon: CupertinoIcons.moon_stars,
    position: 6,
  ),
];

/// Visible slots in display order.
List<MealSlot> visibleMealSlots(List<MealSlot> slots) {
  final visible = slots.where((slot) => slot.isVisible).toList();
  visible.sort((a, b) => a.position.compareTo(b.position));
  return visible;
}

// =============================================================================
// Nutrients
// =============================================================================

enum Nutrient {
  protein('Protein', AppColors.protein),
  carbohydrates('Carbohydrates', AppColors.carbs),
  fat('Fat', AppColors.fat),
  fibre('Fibre', AppColors.fibre);

  const Nutrient(this.label, this.color);

  final String label;
  final CupertinoDynamicColor color;
}

class NutrientProgress {
  const NutrientProgress({
    required this.nutrient,
    required this.consumedGrams,
    required this.targetGrams,
  }) : assert(consumedGrams >= 0),
       assert(targetGrams >= 0);

  final Nutrient nutrient;
  final double consumedGrams;
  final double targetGrams;

  bool get hasTarget => targetGrams > 0;

  /// 0.0–1.0, clamped. Zero when there is no target (never divides by zero).
  double get fraction =>
      hasTarget ? (consumedGrams / targetGrams).clamp(0.0, 1.0) : 0.0;

  String get semanticsLabel => hasTarget
      ? '${nutrient.label}: ${formatGrams(consumedGrams)} of '
            '${formatGrams(targetGrams)} grams'
      : '${nutrient.label}: ${formatGrams(consumedGrams)} grams, no target';
}

// =============================================================================
// Calories
// =============================================================================

class CalorieProgress {
  const CalorieProgress({required this.consumed, required this.goal})
    : assert(consumed >= 0),
      assert(goal >= 0);

  final int consumed;

  /// Zero means "no goal set".
  final int goal;

  bool get hasGoal => goal > 0;

  int get remaining => hasGoal && consumed < goal ? goal - consumed : 0;

  int get over => hasGoal && consumed > goal ? consumed - goal : 0;

  /// 0.0–1.0, clamped. Exceeding the goal shows a full ring.
  double get fraction => hasGoal ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

  String semanticsLabel({required bool isSample}) {
    final buffer = StringBuffer('Calories: ');
    if (hasGoal) {
      buffer.write(
        '${formatNumber(consumed)} of ${formatNumber(goal)} consumed. ',
      );
      buffer.write(
        over > 0
            ? '${formatNumber(over)} over goal.'
            : '${formatNumber(remaining)} remaining.',
      );
    } else {
      buffer.write('${formatNumber(consumed)} consumed. No daily goal set.');
    }
    if (isSample) {
      buffer.write(' Sample data.');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Meals and the daily summary
// =============================================================================

class MealSummary {
  const MealSummary({required this.itemCount, required this.calories});

  static const MealSummary empty = MealSummary(itemCount: 0, calories: 0);

  final int itemCount;
  final int calories;

  bool get isEmpty => itemCount == 0;

  String get statusText {
    if (isEmpty) {
      return 'Nothing added yet';
    }
    final items = itemCount == 1 ? '1 item' : '$itemCount items';
    return '$items · ${formatNumber(calories)} kcal';
  }
}

/// Everything the Today dashboard displays.
///
/// Calories are DERIVED from the meals, never stored separately, so the
/// total always matches what was logged. When food logging is built, real
/// saved entries replace [DailySummary.sample] — the UI does not change.
class DailySummary {
  const DailySummary({
    required this.calorieGoal,
    required this.meals,
    required this.nutrients,
    required this.isSample,
  });

  final int calorieGoal;

  /// Keyed by [MealSlot.id].
  final Map<String, MealSummary> meals;
  final List<NutrientProgress> nutrients;

  /// True while values are temporary sample data. Shown in the UI.
  final bool isSample;

  MealSummary mealFor(String slotId) => meals[slotId] ?? MealSummary.empty;

  int get caloriesConsumed =>
      meals.values.fold<int>(0, (sum, meal) => sum + meal.calories);

  CalorieProgress get calories =>
      CalorieProgress(consumed: caloriesConsumed, goal: calorieGoal);

  /// TEMPORARY SAMPLE DATA for UI development only.
  /// These are NOT real nutrition values and must never be presented as such.
  factory DailySummary.sample() {
    return const DailySummary(
      calorieGoal: 2000,
      isSample: true,
      meals: {
        'breakfast': MealSummary(itemCount: 2, calories: 380),
        'mid_morning': MealSummary(itemCount: 1, calories: 120),
        'lunch': MealSummary(itemCount: 3, calories: 540),
        'snacks': MealSummary(itemCount: 1, calories: 200),
      },
      nutrients: [
        NutrientProgress(
          nutrient: Nutrient.protein,
          consumedGrams: 58,
          targetGrams: 110,
        ),
        NutrientProgress(
          nutrient: Nutrient.carbohydrates,
          consumedGrams: 162,
          targetGrams: 250,
        ),
        NutrientProgress(
          nutrient: Nutrient.fat,
          consumedGrams: 41,
          targetGrams: 65,
        ),
        NutrientProgress(
          nutrient: Nutrient.fibre,
          consumedGrams: 18,
          targetGrams: 30,
        ),
      ],
    );
  }
}

// =============================================================================
// Formatting
// =============================================================================

/// 1240 -> "1,240".
String formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Grams shown as whole numbers on the dashboard.
String formatGrams(double grams) => formatNumber(grams.round());
