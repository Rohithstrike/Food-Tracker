import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/data/food/sample_food_provider.dart';
import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/food/serving.dart';
import 'package:indian_food_tracker/domain/log/entry_builder.dart';
import 'package:indian_food_tracker/domain/log/log_entry.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition_engine.dart';
import 'package:indian_food_tracker/features/today/today_models.dart';

// All foods come from the SAMPLE provider: placeholder values, not real
// nutrition data.

Food sampleFood(String localId) =>
    buildSampleFoods().firstWhere((Food f) => f.id == 'sample:$localId');

final DateTime morning = DateTime(2026, 10, 12, 8, 30);
final LocalDate day = LocalDate(2026, 10, 12);

LogEntry idliEntry({
  OilLevel? oilLevel,
  num? oilGrams,
  bool withGhee = false,
  Food? idli,
  String mealSlotId = 'breakfast',
}) => EntryBuilder.build(
  id: 'entry-1',
  date: day,
  mealSlotId: mealSlotId,
  timestamp: morning,
  base: FoodPortion(
    food: idli ?? sampleFood('idli'),
    servingId: 'piece',
    quantity: 2,
  ),
  oil: sampleFood('sunflower_oil'),
  oilGrams: oilGrams ?? oilLevel?.defaultGrams ?? 0,
  extras: <FoodPortion>[
    if (withGhee)
      FoodPortion(food: sampleFood('ghee'), servingId: 'tsp', quantity: 1),
  ],
);

NutrientAmount energyOf(LogEntry entry) =>
    entry.totals[NutrientKind.energy].amount;

void main() {
  group('LocalDate', () {
    test('is the local calendar day, even late at night', () {
      expect(
        LocalDate.fromDateTime(DateTime(2026, 10, 12, 23, 59)).toIsoString(),
        '2026-10-12',
      );
      expect(
        LocalDate.fromDateTime(DateTime(2026, 10, 13)),
        LocalDate(2026, 10, 13),
      );
    });

    test('rejects dates that do not exist', () {
      expect(() => LocalDate(2026, 2, 30), throwsArgumentError);
      expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
      expect(LocalDate(2028, 2, 29).toIsoString(), '2028-02-29');
    });

    test('parses and prints yyyy-mm-dd', () {
      expect(LocalDate.parse('2026-01-05'), LocalDate(2026, 1, 5));
      expect(LocalDate(2026, 1, 5).toIsoString(), '2026-01-05');
      expect(() => LocalDate.parse('5/1/2026'), throwsFormatException);
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
    });

    test('orders chronologically', () {
      final List<LocalDate> dates = <LocalDate>[
        LocalDate(2026, 10, 12),
        LocalDate(2025, 12, 31),
        LocalDate(2026, 1, 1),
      ]..sort();
      expect(dates.map((LocalDate d) => d.toIsoString()).toList(), <String>[
        '2025-12-31',
        '2026-01-01',
        '2026-10-12',
      ]);
    });
  });

  group('Oil levels', () {
    test('defaults are 0, 2.5, 5 and 10 g', () {
      expect(
        OilLevel.values.map((OilLevel l) => l.defaultGrams).toList(),
        <double>[0, 2.5, 5, 10],
      );
      expect(OilLevel.values.map((OilLevel l) => l.label).toList(), <String>[
        'None',
        'Very little',
        'Normal',
        'High',
      ]);
    });
  });

  group('Building entries', () {
    test('base, oil and extra are each calculated by the engine', () {
      final LogEntry e = idliEntry(oilLevel: OilLevel.normal, withGhee: true);
      expect(
        e.components.map((EntryComponent c) => c.role).toList(),
        <ComponentRole>[
          ComponentRole.base,
          ComponentRole.oil,
          ComponentRole.extra,
        ],
      );
      // 2 idlis (80 g): 112 kcal. Oil 5 g: 45 kcal. Ghee 1 tsp (5 g): 45 kcal.
      expect(energyOf(e), const NutrientAmount.milli(202000));
      expect(
        e.totals[NutrientKind.fat].amount,
        const NutrientAmount.milli(10400),
      );
      expect(
        e.totals[NutrientKind.protein].amount,
        const NutrientAmount.milli(3200),
      );
      expect(e.isSample, isTrue);
    });

    test('added oil is always labelled as an estimate', () {
      final LogEntry e = idliEntry(oilLevel: OilLevel.normal);
      final EntryComponent oil = e.components[1];
      expect(oil.role, ComponentRole.oil);
      expect(oil.isEstimate, isTrue);
      expect(
        oil.nutrition.assumptions.any(
          (String a) => a.contains('Added oil (5 g) is an estimate'),
        ),
        isTrue,
      );
      expect(e.isEstimate, isTrue);
    });

    test('no oil component when oil is None', () {
      final LogEntry e = idliEntry(oilLevel: OilLevel.none, withGhee: true);
      expect(
        e.components.map((EntryComponent c) => c.role).toList(),
        <ComponentRole>[ComponentRole.base, ComponentRole.extra],
      );
      expect(energyOf(e), const NutrientAmount.milli(157000));
    });

    test('an edited oil amount is used and explained', () {
      final LogEntry e = idliEntry(oilGrams: 7.5);
      // 7.5 g oil at 900 kcal per 100 g = 67.5 kcal.
      expect(energyOf(e), const NutrientAmount.milli(179500));
      expect(
        e.assumptions.any((String a) => a.contains('Added oil (7.5 g)')),
        isTrue,
      );
    });

    test('invalid oil input is rejected', () {
      expect(() => idliEntry(oilGrams: -1), throwsArgumentError);
      expect(
        () => EntryBuilder.build(
          id: 'x',
          date: day,
          mealSlotId: 'lunch',
          timestamp: morning,
          base: FoodPortion(
            food: sampleFood('idli'),
            servingId: 'piece',
            quantity: 1,
          ),
          oilGrams: 5,
        ),
        throwsArgumentError,
      );
    });

    test('invalid quantities are rejected by the engine', () {
      expect(
        () => EntryBuilder.build(
          id: 'x',
          date: day,
          mealSlotId: 'lunch',
          timestamp: morning,
          base: FoodPortion(
            food: sampleFood('idli'),
            servingId: 'piece',
            quantity: 0,
          ),
        ),
        throwsA(isA<NutritionInputException>()),
      );
    });

    test('unknown nutrients stay unknown in entry totals', () {
      final LogEntry e = idliEntry(oilLevel: OilLevel.normal, withGhee: true);
      // Idli sugar is unknown; oil and ghee sugar are known zeros.
      expect(e.base.nutrition.nutrients[NutrientKind.sugar], isNull);
      expect(e.totals[NutrientKind.sugar].amount, NutrientAmount.zero);
      expect(e.totals[NutrientKind.sugar].missingCount, 1);
      // No component lists iron.
      expect(e.totals[NutrientKind.iron].missingCount, 3);
      expect(e.totals.isComplete, isFalse);
    });

    test('the snapshot does not change when food data is corrected', () {
      final LogEntry original = idliEntry();
      final Food corrected = Food(
        id: 'sample:idli',
        name: 'Idli (corrected)',
        category: FoodCategory.dish,
        region: FoodRegion.southIndian,
        status: DataStatus.sample,
        servings: <Serving>[
          Serving(
            id: 'piece',
            singularLabel: 'idli',
            pluralLabel: 'idlis',
            grams: 40,
            weightBasis: ServingWeightBasis.estimated,
          ),
        ],
        per100g: NutrientProfile.per100g(
          energyKcal: 999,
          proteinG: null,
          carbohydratesG: null,
          fatG: null,
          fibreG: null,
          sugarG: null,
          sodiumMg: null,
        ),
      );
      final LogEntry rebuilt = idliEntry(idli: corrected);

      expect(energyOf(original), const NutrientAmount.milli(112000));
      expect(original.base.foodName, 'Idli');
      expect(energyOf(rebuilt), const NutrientAmount.milli(799200));
    });
  });

  group('Storage format', () {
    test('round-trips through JSON without losing anything', () {
      final LogEntry e = idliEntry(oilLevel: OilLevel.normal, withGhee: true);
      final String text = jsonEncode(e.toJson());
      final LogEntry restored = LogEntry.fromJson(
        jsonDecode(text) as Map<String, Object?>,
      );

      expect(restored.id, e.id);
      expect(restored.date, e.date);
      expect(restored.mealSlotId, 'breakfast');
      expect(restored.createdAt.isAtSameMomentAs(e.createdAt), isTrue);
      expect(restored.updatedAt.isAtSameMomentAs(e.updatedAt), isTrue);
      expect(
        restored.components.map((EntryComponent c) => c.role).toList(),
        e.components.map((EntryComponent c) => c.role).toList(),
      );
      expect(energyOf(restored), energyOf(e));
      expect(
        restored.totals[NutrientKind.fat].amount,
        e.totals[NutrientKind.fat].amount,
      );
      expect(restored.base.nutrition.nutrients[NutrientKind.sugar], isNull);
      expect(restored.totals[NutrientKind.sugar].missingCount, 1);
      expect(restored.components[1].isEstimate, isTrue);
      expect(restored.assumptions, e.assumptions);
      expect(restored.base.foodName, 'Idli');
      expect(restored.base.dataStatus, DataStatus.sample);
    });

    test('nutrients are stored by stable name; unknowns are absent', () {
      final Map<String, Object?> json = idliEntry().toJson();
      expect(json['schemaVersion'], 1);
      expect(json['date'], '2026-10-12');
      final List<Object?> components = json['components'] as List<Object?>;
      final Map<String, Object?> base =
          components.first as Map<String, Object?>;
      final Map<String, int> nutrients = base['nutrients'] as Map<String, int>;
      expect(nutrients['energy'], 112000);
      expect(nutrients.containsKey('sugar'), isFalse);
    });

    test('unknown or invalid stored data is rejected, not guessed', () {
      Map<String, dynamic> freshJson() =>
          jsonDecode(jsonEncode(idliEntry().toJson())) as Map<String, dynamic>;
      Map<String, dynamic> firstNutrients(Map<String, dynamic> json) =>
          ((json['components'] as List<dynamic>).first
                  as Map<String, dynamic>)['nutrients']
              as Map<String, dynamic>;

      final Map<String, dynamic> newerVersion = freshJson()
        ..['schemaVersion'] = 99;
      expect(() => LogEntry.fromJson(newerVersion), throwsFormatException);

      final Map<String, dynamic> unknownNutrient = freshJson();
      firstNutrients(unknownNutrient)['vitaminZ'] = 1;
      expect(() => LogEntry.fromJson(unknownNutrient), throwsFormatException);

      final Map<String, dynamic> negative = freshJson();
      firstNutrients(negative)['energy'] = -5;
      expect(() => LogEntry.fromJson(negative), throwsFormatException);
    });
  });

  group('Entry rules', () {
    test('an entry needs exactly one base food, listed first', () {
      final LogEntry e = idliEntry(oilLevel: OilLevel.normal, withGhee: true);
      LogEntry withComponents(List<EntryComponent> components) => LogEntry(
        id: 'x',
        date: day,
        mealSlotId: 'lunch',
        createdAt: morning,
        updatedAt: morning,
        components: components,
      );
      expect(() => withComponents(<EntryComponent>[]), throwsArgumentError);
      expect(
        () => withComponents(<EntryComponent>[e.base, e.base]),
        throwsArgumentError,
      );
      expect(
        () => withComponents(<EntryComponent>[e.components[2], e.base]),
        throwsArgumentError,
      );
    });

    test('meal slots are stored by their permanent ids', () {
      expect(defaultMealSlots.map((MealSlot s) => s.id).toList(), <String>[
        'pre_workout',
        'breakfast',
        'mid_morning',
        'lunch',
        'snacks',
        'dinner',
        'late_meal',
      ]);
      for (final MealSlot slot in defaultMealSlots) {
        expect(idliEntry(mealSlotId: slot.id).mealSlotId, slot.id);
      }
    });

    test('moving an entry keeps its id, creation time and snapshot', () {
      final LogEntry e = idliEntry();
      final LogEntry moved = e.copyWith(
        mealSlotId: 'lunch',
        updatedAt: DateTime(2026, 10, 12, 9),
      );
      expect(moved.id, e.id);
      expect(moved.createdAt, e.createdAt);
      expect(moved.mealSlotId, 'lunch');
      expect(energyOf(moved), energyOf(e));
      expect(
        () => e.copyWith(updatedAt: DateTime(2026, 10, 12, 7)),
        throwsArgumentError,
      );
    });
  });
}
