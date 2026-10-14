import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/data/food/sample_food_provider.dart';
import 'package:indian_food_tracker/data/log/log_store.dart';
import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/log/entry_builder.dart';
import 'package:indian_food_tracker/domain/log/log_entry.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/features/log/day_log_controller.dart';
import 'package:indian_food_tracker/features/log/default_meal.dart';
import 'package:indian_food_tracker/features/today/today_models.dart';
import 'package:indian_food_tracker/features/today/today_summary_adapter.dart';

// All foods come from the SAMPLE provider: placeholder values, not real
// nutrition data. Per sample serving:
//   1 idli (40 g):   56 kcal, protein 1.6 g, fat 0.2 g, sugar unknown
//   1 cup rice:     208 kcal, protein 4.8 g
//   1 bowl sambar:   90 kcal, protein 4.5 g, sodium unknown
//   5 g oil:         45 kcal, fat 5 g

Food sampleFood(String localId) =>
    buildSampleFoods().firstWhere((Food f) => f.id == 'sample:$localId');

FoodPortion portion(String localId, String servingId, num quantity) =>
    FoodPortion(
      food: sampleFood(localId),
      servingId: servingId,
      quantity: quantity,
    );

DayLogController controllerFor({LogStore? store, DateTime Function()? clock}) {
  int next = 0;
  return DayLogController(
    store: store ?? InMemoryLogStore(),
    clock: clock ?? () => DateTime(2026, 10, 12, 9),
    idGenerator: () => 'e${++next}',
  );
}

int energyOf(DayLogController c) =>
    c.log.totals[NutrientKind.energy].amount.milli;

final class _FailingStore implements LogStore {
  @override
  Future<List<LogEntry>> entriesFor(LocalDate date) async => <LogEntry>[];

  @override
  Future<void> add(LogEntry entry) async {
    throw StateError('Storage unavailable');
  }

  @override
  Future<void> remove(String id) async {}
}

void main() {
  group('Default meal', () {
    test('follows the agreed local-time boundaries', () {
      const List<(int, int, String)> cases = <(int, int, String)>[
        (0, 0, 'late_meal'),
        (4, 59, 'late_meal'),
        (5, 0, 'breakfast'),
        (10, 29, 'breakfast'),
        (10, 30, 'mid_morning'),
        (11, 59, 'mid_morning'),
        (12, 0, 'lunch'),
        (15, 29, 'lunch'),
        (15, 30, 'snacks'),
        (18, 59, 'snacks'),
        (19, 0, 'dinner'),
        (21, 59, 'dinner'),
        (22, 0, 'late_meal'),
        (23, 59, 'late_meal'),
      ];
      for (final (int hour, int minute, String expected) in cases) {
        expect(
          defaultMealSlotIdFor(DateTime(2026, 10, 12, hour, minute)),
          expected,
          reason: '$hour:$minute',
        );
      }
    });

    test('never chooses Pre-workout and always returns a known meal', () {
      final Set<String> ids = defaultMealSlots
          .map((MealSlot s) => s.id)
          .toSet();
      for (int minute = 0; minute < 24 * 60; minute++) {
        final String id = defaultMealSlotIdFor(
          DateTime(2026, 10, 12, minute ~/ 60, minute % 60),
        );
        expect(id, isNot('pre_workout'));
        expect(ids, contains(id));
      }
    });

    test('falls back to the first visible meal other than Pre-workout', () {
      final List<MealSlot> withoutLunch = defaultMealSlots
          .where((MealSlot s) => s.id != 'lunch')
          .toList();
      expect(
        defaultMealSlotFor(withoutLunch, DateTime(2026, 10, 12, 13)).id,
        'breakfast',
      );
      expect(
        defaultMealSlotFor(defaultMealSlots, DateTime(2026, 10, 12, 13)).id,
        'lunch',
      );
    });
  });

  group('DayLogController', () {
    test('starts with an empty log for the local date', () {
      final DayLogController c = controllerFor();
      expect(c.log.isEmpty, isTrue);
      expect(c.log.date, LocalDate(2026, 10, 12));
      expect(energyOf(c), 0);
    });

    test('adds food to each of the seven meals', () async {
      final DayLogController c = controllerFor();
      for (final MealSlot slot in defaultMealSlots) {
        await c.add(mealSlotId: slot.id, base: portion('idli', 'piece', 1));
      }
      for (final MealSlot slot in defaultMealSlots) {
        expect(c.log.entriesFor(slot.id).length, 1, reason: slot.id);
      }
      expect(energyOf(c), 7 * 56000);
    });

    test('entry totals match EntryBuilder, with oil as an estimate', () async {
      final DayLogController c = controllerFor();
      final LogEntry entry = await c.add(
        mealSlotId: 'breakfast',
        base: portion('idli', 'piece', 2),
        oil: sampleFood('sunflower_oil'),
        oilGrams: OilLevel.normal.defaultGrams,
      );
      expect(entry.components.length, 2);
      expect(entry.components[1].role, ComponentRole.oil);
      expect(entry.components[1].isEstimate, isTrue);
      // 112 kcal idli + 45 kcal oil; fat 0.4 g + 5 g.
      expect(energyOf(c), 157000);
      expect(c.log.totals[NutrientKind.fat].amount.milli, 5400);
    });

    test('multiple entries combine correctly', () async {
      final DayLogController c = controllerFor();
      await c.add(mealSlotId: 'breakfast', base: portion('idli', 'piece', 2));
      await c.add(
        mealSlotId: 'lunch',
        base: portion('rice_white_cooked', 'cup', 1),
      );
      await c.add(mealSlotId: 'lunch', base: portion('sambar', 'bowl', 1));

      expect(energyOf(c), 410000);
      expect(c.log.totals[NutrientKind.protein].amount.milli, 12500);

      final DailySummary s = summariseDayLog(
        c.log,
        targets: DailyTargets.placeholder,
      ).summary;
      expect(s.caloriesConsumed, 410);
      expect(s.mealFor('lunch').itemCount, 2);
      expect(s.mealFor('lunch').calories, 298);
      expect(s.isSample, isTrue);
    });

    test('undo removes the right entry and restores totals', () async {
      final DayLogController c = controllerFor();
      await c.add(mealSlotId: 'breakfast', base: portion('idli', 'piece', 1));
      final int before = energyOf(c);
      final LogEntry rice = await c.add(
        mealSlotId: 'lunch',
        base: portion('rice_white_cooked', 'cup', 1),
      );
      await c.add(mealSlotId: 'dinner', base: portion('sambar', 'bowl', 1));
      expect(energyOf(c), 56000 + 208000 + 90000);

      expect(await c.undo(rice.id), isTrue);
      expect(c.log.entries.map((LogEntry e) => e.id).toList(), <String>[
        'e1',
        'e3',
      ]);
      expect(energyOf(c), before + 90000);
      expect(c.log.entriesFor('lunch'), isEmpty);
    });

    test('undo of an unknown entry changes nothing', () async {
      final DayLogController c = controllerFor();
      await c.add(mealSlotId: 'lunch', base: portion('idli', 'piece', 1));
      expect(await c.undo('missing'), isFalse);
      expect(c.log.entries.length, 1);
      expect(energyOf(c), 56000);
    });

    test('unknown nutrients stay unknown in day totals', () async {
      final DayLogController c = controllerFor();
      await c.add(mealSlotId: 'lunch', base: portion('sambar', 'bowl', 1));
      await c.add(mealSlotId: 'lunch', base: portion('idli', 'piece', 1));
      // Sambar sodium and idli sugar are unknown in the sample data.
      expect(c.log.totals[NutrientKind.sodium].missingCount, 1);
      expect(c.log.totals[NutrientKind.sugar].missingCount, 2);
      expect(c.log.totals.isComplete, isFalse);
    });

    test('listeners are notified on add and undo', () async {
      final DayLogController c = controllerFor();
      int calls = 0;
      c.addListener(() => calls++);
      final LogEntry entry = await c.add(
        mealSlotId: 'lunch',
        base: portion('idli', 'piece', 1),
      );
      expect(calls, 1);
      await c.undo(entry.id);
      expect(calls, 2);
    });

    test('a new local day starts empty', () async {
      final InMemoryLogStore store = InMemoryLogStore();
      DateTime now = DateTime(2026, 10, 12, 23, 50);
      final DayLogController c = controllerFor(store: store, clock: () => now);
      await c.add(mealSlotId: 'late_meal', base: portion('idli', 'piece', 1));

      now = DateTime(2026, 10, 13, 0, 5);
      expect(c.checkDate(), isTrue);
      expect(c.log.isEmpty, isTrue);
      expect(c.log.date, LocalDate(2026, 10, 13));

      final LogEntry next = await c.add(
        mealSlotId: 'breakfast',
        base: portion('idli', 'piece', 1),
      );
      expect(next.date, LocalDate(2026, 10, 13));
      expect(c.log.entries.length, 1);
      expect((await store.entriesFor(LocalDate(2026, 10, 12))).length, 1);
    });

    test('entries are saved to and loaded from the store', () async {
      final InMemoryLogStore store = InMemoryLogStore();
      final DayLogController first = controllerFor(store: store);
      final LogEntry entry = await first.add(
        mealSlotId: 'lunch',
        base: portion('idli', 'piece', 2),
      );

      final DayLogController second = controllerFor(store: store);
      await second.load();
      expect(second.log.entries.single.id, entry.id);
      expect(second.log.entries.single.base.foodName, 'Idli');

      await first.undo(entry.id);
      expect(await store.entriesFor(LocalDate(2026, 10, 12)), isEmpty);
    });

    test('a failing store leaves the log unchanged', () async {
      final DayLogController c = controllerFor(store: _FailingStore());
      await expectLater(
        c.add(mealSlotId: 'lunch', base: portion('idli', 'piece', 1)),
        throwsStateError,
      );
      expect(c.log.isEmpty, isTrue);
    });

    test('generated entry ids are unique', () {
      final String Function() next = createEntryIdGenerator();
      final Set<String> ids = <String>{for (int i = 0; i < 1000; i++) next()};
      expect(ids.length, 1000);
    });
  });
}
