// Converts a DayLog into the DailySummary the Today screen already uses.
//
// NOT CONNECTED YET: the Today screen keeps showing its labelled sample data
// until the logging batch wires this in.
//
// Calories per meal are rounded to whole kcal, and the day's calories are
// the sum of those (as the Today screen already derives them). Nutrient
// grams are sums of KNOWN values; [TodayLogSummary.dayTotals] keeps the
// missing counts so the UI can show when values are incomplete.

import '../../domain/log/day_log.dart';
import '../../domain/log/log_entry.dart';
import '../../domain/nutrition/nutrition.dart';
import '../../domain/nutrition/nutrition_engine.dart';
import 'today_models.dart';

/// Daily targets shown on Today.
final class DailyTargets {
  const DailyTargets({
    required this.calorieGoal,
    required this.proteinG,
    required this.carbohydratesG,
    required this.fatG,
    required this.fibreG,
  });

  /// PLACEHOLDER targets until the Settings milestone lets users set them.
  /// They match the values the Today sample data already shows.
  static const DailyTargets placeholder = DailyTargets(
    calorieGoal: 2000,
    proteinG: 110,
    carbohydratesG: 250,
    fatG: 65,
    fibreG: 30,
  );

  final int calorieGoal;
  final double proteinG;
  final double carbohydratesG;
  final double fatG;
  final double fibreG;

  double gramsFor(Nutrient nutrient) => switch (nutrient) {
    Nutrient.protein => proteinG,
    Nutrient.carbohydrates => carbohydratesG,
    Nutrient.fat => fatG,
    Nutrient.fibre => fibreG,
  };
}

/// The Today summary plus the full day totals (with missing counts).
final class TodayLogSummary {
  const TodayLogSummary({required this.summary, required this.dayTotals});

  final DailySummary summary;
  final NutritionTotals dayTotals;
}

TodayLogSummary summariseDayLog(DayLog log, {required DailyTargets targets}) {
  final Map<String, MealSummary> meals = <String, MealSummary>{};
  for (final String slotId in log.mealSlotIds) {
    final List<LogEntry> entries = log.entriesFor(slotId);
    meals[slotId] = MealSummary(
      itemCount: entries.length,
      calories: _wholeKcal(log.totalsFor(slotId)),
    );
  }

  final NutritionTotals day = log.totals;
  final List<NutrientProgress> nutrients = <NutrientProgress>[
    for (final Nutrient nutrient in Nutrient.values)
      NutrientProgress(
        nutrient: nutrient,
        consumedGrams: day.totalOf(_kindFor(nutrient)).amount.toUnits(),
        targetGrams: targets.gramsFor(nutrient),
      ),
  ];

  return TodayLogSummary(
    summary: DailySummary(
      calorieGoal: targets.calorieGoal,
      meals: meals,
      nutrients: nutrients,
      isSample: log.isSample,
    ),
    dayTotals: day,
  );
}

int _wholeKcal(NutritionTotals totals) =>
    totals.totalOf(NutrientKind.energy).amount.toUnits(decimals: 0).round();

NutrientKind _kindFor(Nutrient nutrient) => switch (nutrient) {
  Nutrient.protein => NutrientKind.protein,
  Nutrient.carbohydrates => NutrientKind.carbohydrates,
  Nutrient.fat => NutrientKind.fat,
  Nutrient.fibre => NutrientKind.fibre,
};
