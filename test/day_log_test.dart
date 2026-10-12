import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/data/food/sample_food_provider.dart';
import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/log/day_log.dart';
import 'package:indian_food_tracker/domain/log/entry_builder.dart';
import 'package:indian_food_tracker/domain/log/log_entry.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/features/today/today_models.dart';
import 'package:indian_food_tracker/features/today/today_summary_adapter.dart';

// All foods come from the SAMPLE provider: placeholder values, not real
// nutrition data.

Food sampleFood(String localId) =>
    buildSampleFoods().firstWhere((Food f) => f.id == 'sample:$localId');

final LocalDate day = LocalDate(2026, 10, 12);

LogEntry entry(
  String id,
  String mealSlotId,
  String foodId,
  String servingId,
  num quantity, {
  int minute = 0,
  LocalDate? date,
}) => EntryBuilder.build(
  id: id,
  date: date ?? day,
  mealSlotId: mealSlotId,
  timestamp: DateTime(2026, 10, 12, 8, minute),
  base: FoodPortion(
    food: sampleFood(foodId),
    servingId: servingId,
    quantity: quantity,
  ),
);

/// Breakfast: 2 idlis (112 kcal).
/// Lunch: 1 cup rice (208 kcal) + 1 bowl sambar (90 kcal).
DayLog sampleDay() => DayLog(
  date: day,
  entries: <LogEntry>[
    entry('b1', 'breakfast', 'idli', 'piece', 2),
    entry('l1', 'lunch', 'rice_white_cooked', 'cup', 1, minute: 1),
    entry('l2', 'lunch', 'sambar', 'bowl', 1, minute: 2),
  ],
);

List<String> ids(List<LogEntry> entries) =>
    entries.map((LogEntry e) => e.id).toList();

NutrientProgress progressFor(DailySummary summary, Nutrient nutrient) => summary
    .nutrients
    .firstWhere((NutrientProgress p) => p.nutrient == nutrient);

void main() {
  group('Day log', () {
    test('an empty day totals zero and is complete', () {
      final DayLog log = DayLog(date: day);
      expect(log.isEmpty, isTrue);
      expect(log.totals[NutrientKind.energy].amount, NutrientAmount.zero);
      expect(log.totals.isComplete, isTrue);
      expect(log.isSample, isFalse);
      expect(log.mealSlotIds, isEmpty);
    });

    test('meal and day totals come from the entries', () {
      final DayLog log = sampleDay();
      expect(
        log.totalsFor('breakfast')[NutrientKind.energy].amount,
        const NutrientAmount.milli(112000),
      );
      expect(
        log.totalsFor('lunch')[NutrientKind.energy].amount,
        const NutrientAmount.milli(298000),
      );
      expect(
        log.totals[NutrientKind.energy].amount,
        const NutrientAmount.milli(410000),
      );
      expect(log.totalsFor('dinner').itemCount, 0);
      expect(
        log.totalsFor('dinner')[NutrientKind.energy].amount,
        NutrientAmount.zero,
      );
      expect(log.isSample, isTrue);
    });

    test('unknown nutrients are counted, never treated as zero', () {
      final DayLog log = sampleDay();
      // Rice sodium is a known 0; sambar sodium is unknown.
      expect(
        log.totalsFor('lunch')[NutrientKind.sodium].amount,
        NutrientAmount.zero,
      );
      expect(log.totalsFor('lunch')[NutrientKind.sodium].missingCount, 1);
      // Idli and sambar sugar are unknown; rice sugar is a known 0.
      expect(log.totals[NutrientKind.sugar].missingCount, 2);
    });

    test('entries are ordered by time', () {
      final DayLog log = DayLog(
        date: day,
        entries: <LogEntry>[
          entry('l2', 'lunch', 'sambar', 'bowl', 1, minute: 2),
          entry('b1', 'breakfast', 'idli', 'piece', 2),
          entry('l1', 'lunch', 'rice_white_cooked', 'cup', 1, minute: 1),
        ],
      );
      expect(ids(log.entries), <String>['b1', 'l1', 'l2']);
    });

    test('adding returns a new log and keeps the original', () {
      final DayLog log = DayLog(date: day);
      final DayLog added = log.add(
        entry('b1', 'breakfast', 'idli', 'piece', 2),
      );
      expect(log.entries, isEmpty);
      expect(ids(added.entries), <String>['b1']);
    });

    test('entries for another date or with a duplicate id are rejected', () {
      expect(
        () => DayLog(date: day).add(
          entry(
            'x1',
            'lunch',
            'idli',
            'piece',
            1,
            date: LocalDate(2026, 10, 13),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => sampleDay().add(entry('b1', 'dinner', 'idli', 'piece', 1)),
        throwsArgumentError,
      );
    });

    test('replacing an entry can move it to another meal', () {
      final DayLog log = sampleDay();
      final DayLog moved = log.replace(
        log
            .entryById('l2')!
            .copyWith(
              mealSlotId: 'dinner',
              updatedAt: DateTime(2026, 10, 12, 9),
            ),
      );
      expect(ids(moved.entriesFor('lunch')), <String>['l1']);
      expect(ids(moved.entriesFor('dinner')), <String>['l2']);
      expect(
        moved.totals[NutrientKind.energy].amount,
        const NutrientAmount.milli(410000),
      );
      expect(
        () => log.replace(entry('missing', 'lunch', 'idli', 'piece', 1)),
        throwsArgumentError,
      );
    });

    test('removing an entry updates the totals', () {
      final DayLog log = sampleDay().remove('l2');
      expect(ids(log.entries), <String>['b1', 'l1']);
      expect(
        log.totals[NutrientKind.energy].amount,
        const NutrientAmount.milli(320000),
      );
      expect(() => log.remove('missing'), throwsArgumentError);
    });

    test('food in a hidden or custom meal still counts for the day', () {
      final DayLog log = DayLog(
        date: day,
        entries: <LogEntry>[entry('c1', 'custom_slot', 'idli', 'piece', 1)],
      );
      expect(log.mealSlotIds, <String>{'custom_slot'});
      expect(
        log.totals[NutrientKind.energy].amount,
        const NutrientAmount.milli(56000),
      );
    });
  });

  group('Today summary adapter', () {
    test('builds the existing Today summary from logged entries', () {
      final DailySummary s = summariseDayLog(
        sampleDay(),
        targets: DailyTargets.placeholder,
      ).summary;
      expect(s.caloriesConsumed, 410);
      expect(s.calorieGoal, 2000);
      expect(s.mealFor('breakfast').itemCount, 1);
      expect(s.mealFor('breakfast').calories, 112);
      expect(s.mealFor('lunch').itemCount, 2);
      expect(s.mealFor('lunch').calories, 298);
      expect(s.mealFor('dinner').isEmpty, isTrue);
      expect(s.isSample, isTrue);
    });

    test('nutrient progress uses the day totals and targets', () {
      final DailySummary s = summariseDayLog(
        sampleDay(),
        targets: DailyTargets.placeholder,
      ).summary;
      expect(
        s.nutrients.map((NutrientProgress p) => p.nutrient).toList(),
        <Nutrient>[
          Nutrient.protein,
          Nutrient.carbohydrates,
          Nutrient.fat,
          Nutrient.fibre,
        ],
      );
      // Protein: 3.2 + 4.8 + 4.5 g. Carbs: 24 + 44.8 + 12 g.
      // Fat: 0.4 + 0.8 + 3 g. Fibre: 0.8 + 0.8 + 3 g.
      expect(
        progressFor(s, Nutrient.protein).consumedGrams,
        closeTo(12.5, 1e-9),
      );
      expect(progressFor(s, Nutrient.protein).targetGrams, 110);
      expect(
        progressFor(s, Nutrient.carbohydrates).consumedGrams,
        closeTo(80.8, 1e-9),
      );
      expect(progressFor(s, Nutrient.fat).consumedGrams, closeTo(4.2, 1e-9));
      expect(progressFor(s, Nutrient.fibre).consumedGrams, closeTo(4.6, 1e-9));
    });

    test('an empty day is not sample data and shows nothing logged', () {
      final DailySummary s = summariseDayLog(
        DayLog(date: day),
        targets: DailyTargets.placeholder,
      ).summary;
      expect(s.caloriesConsumed, 0);
      expect(s.isSample, isFalse);
      expect(s.mealFor('lunch').isEmpty, isTrue);
    });

    test('missing values stay visible to the UI', () {
      final TodayLogSummary result = summariseDayLog(
        sampleDay(),
        targets: DailyTargets.placeholder,
      );
      expect(result.dayTotals[NutrientKind.sugar].missingCount, 2);
      expect(result.dayTotals.isComplete, isFalse);
    });
  });
}
