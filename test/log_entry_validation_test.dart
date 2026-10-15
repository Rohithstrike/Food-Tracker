import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/food/serving.dart';
import 'package:indian_food_tracker/domain/log/entry_builder.dart';
import 'package:indian_food_tracker/domain/log/log_entry.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition_engine.dart';

// Snapshot validation: stored entries are untrusted, so every inconsistency is
// rejected with a FormatException. Foods here are TEST fixtures with
// placeholder nutrition values.

final LocalDate _day = LocalDate(2026, 10, 12);
final DateTime _morning = DateTime(2026, 10, 12, 8, 30);

NutrientProfile _profile() => NutrientProfile.per100g(
  energyKcal: 100,
  proteinG: 5,
  carbohydratesG: null,
  fatG: null,
  fibreG: null,
  sugarG: null,
  sodiumMg: null,
);

Food _food(String id, {DataStatus status = DataStatus.sample}) => Food(
  id: id,
  name: 'Test $id',
  category: FoodCategory.dish,
  region: FoodRegion.southIndian,
  per100g: _profile(),
  servings: <Serving>[
    Serving(
      id: 'piece',
      singularLabel: 'piece',
      pluralLabel: 'pieces',
      grams: 40,
      weightBasis: ServingWeightBasis.estimated,
    ),
  ],
  status: status,
);

/// Components: [0] base (2 pieces, estimated weight), [1] oil (5 g, always an
/// estimate), [2] extra (10 g of an exact gram serving, NOT an estimate).
LogEntry _entry() => EntryBuilder.build(
  id: 'entry-1',
  date: _day,
  mealSlotId: 'breakfast',
  timestamp: _morning,
  base: FoodPortion(food: _food('t:base'), servingId: 'piece', quantity: 2),
  oil: _food('t:oil'),
  oilGrams: 5,
  extras: <FoodPortion>[
    FoodPortion(
      food: _food('t:extra'),
      servingId: Serving.gramId,
      quantity: 10,
    ),
  ],
);

/// A fresh, mutable copy of the entry as stored JSON.
Map<String, dynamic> _json() =>
    jsonDecode(jsonEncode(_entry().toJson())) as Map<String, dynamic>;

Map<String, dynamic> _component(Map<String, dynamic> json, int index) =>
    (json['components'] as List<dynamic>)[index] as Map<String, dynamic>;

LogEntry _read(Map<String, dynamic> json) => LogEntry.fromJson(json);

Matcher get _rejected => throwsFormatException;

void main() {
  group('Valid stored entries', () {
    test('a freshly built entry reads back with identical totals', () {
      final LogEntry original = _entry();
      final LogEntry restored = _read(_json());
      expect(restored.id, original.id);
      expect(restored.components.length, 3);
      for (final NutrientKind kind in NutrientKind.values) {
        expect(
          restored.totals[kind].amount,
          original.totals[kind].amount,
          reason: kind.name,
        );
        expect(
          restored.totals[kind].missingCount,
          original.totals[kind].missingCount,
          reason: kind.name,
        );
      }
    });

    test('the quantity and weight limits themselves are accepted', () {
      final Map<String, dynamic> json = _json();
      _component(json, 0)['quantityMilli'] = NutritionEngine.maxQuantity * 1000;
      _component(json, 0)['totalMilligrams'] =
          NutritionEngine.maxTotalMilligrams;
      expect(() => _read(json), returnsNormally);
    });

    test('a zero recorded weight is accepted for a non-gram serving', () {
      // The engine can round a tiny portion of a light serving to 0 mg.
      final Map<String, dynamic> json = _json();
      _component(json, 0)['totalMilligrams'] = 0;
      expect(() => _read(json), returnsNormally);
    });
  });

  group('Quantities and weights', () {
    test('a zero or negative quantity is rejected', () {
      for (final int bad in <int>[0, -1, -2000]) {
        final Map<String, dynamic> json = _json();
        _component(json, 0)['quantityMilli'] = bad;
        expect(() => _read(json), _rejected, reason: 'quantityMilli $bad');
      }
    });

    test('a quantity above the engine limit is rejected', () {
      final Map<String, dynamic> json = _json();
      _component(json, 0)['quantityMilli'] =
          NutritionEngine.maxQuantity * 1000 + 1;
      expect(() => _read(json), _rejected);
    });

    test('a negative weight is rejected', () {
      final Map<String, dynamic> json = _json();
      _component(json, 0)['totalMilligrams'] = -1;
      expect(() => _read(json), _rejected);
    });

    test('a weight above the engine limit is rejected', () {
      final Map<String, dynamic> json = _json();
      _component(json, 0)['totalMilligrams'] =
          NutritionEngine.maxTotalMilligrams + 1;
      expect(() => _read(json), _rejected);
    });

    test('a gram serving must weigh exactly its quantity', () {
      // Component 1 is the oil: 5 g = 5000 milli-units = 5000 mg.
      final Map<String, dynamic> json = _json();
      expect(_component(json, 1)['servingId'], Serving.gramId);
      expect(_component(json, 1)['totalMilligrams'], 5000);
      _component(json, 1)['totalMilligrams'] = 5001;
      expect(() => _read(json), _rejected);
    });
  });

  group('Consistency between fields', () {
    test('sample status must match the sample flag, both ways', () {
      final Map<String, dynamic> flagOff = _json();
      _component(flagOff, 0)['isSample'] = false;
      expect(() => _read(flagOff), _rejected);

      final Map<String, dynamic> statusChanged = _json();
      _component(statusChanged, 0)['dataStatus'] = 'userCustom';
      expect(() => _read(statusChanged), _rejected);
    });

    test('a recipe estimate must be marked as an estimate', () {
      final Map<String, dynamic> json = _json();
      _component(json, 0)['dataStatus'] = 'recipeEstimate';
      _component(json, 0)['isSample'] = false;
      _component(json, 0)['isEstimate'] = false;
      expect(() => _read(json), _rejected);

      _component(json, 0)['isEstimate'] = true;
      expect(() => _read(json), returnsNormally);
    });

    test('added oil must be marked as an estimate', () {
      final Map<String, dynamic> json = _json();
      expect(_component(json, 1)['role'], 'oil');
      _component(json, 1)['isEstimate'] = false;
      expect(() => _read(json), _rejected);
    });

    test('a yield factor requires an estimated snapshot', () {
      // Component 2 (10 g of an exact serving) is not an estimate.
      final Map<String, dynamic> json = _json();
      expect(_component(json, 2)['isEstimate'], isFalse);
      _component(json, 2)['yieldFactorPermille'] = 1500;
      expect(() => _read(json), _rejected);

      _component(json, 2)['isEstimate'] = true;
      expect(() => _read(json), returnsNormally);
    });

    test(
      'building a component with a yield factor on a non-estimate fails',
      () {
        final CalculatedNutrition exact = NutritionEngine.calculate(
          food: _food('t:exact'),
          servingId: Serving.gramId,
          quantity: 100,
        );
        expect(exact.isEstimate, isFalse);

        EntryComponent build({required CalculatedNutrition nutrition}) =>
            EntryComponent(
              role: ComponentRole.base,
              foodName: 'Test',
              dataStatus: DataStatus.sample,
              foodState: FoodState.ready,
              nutrition: nutrition,
              yieldFactorPermille: 1500,
            );

        expect(() => build(nutrition: exact), throwsArgumentError);
        final CalculatedNutrition estimated = NutritionEngine.calculate(
          food: _food('t:estimated'),
          servingId: 'piece',
          quantity: 1,
        );
        expect(estimated.isEstimate, isTrue);
        expect(build(nutrition: estimated).isEstimate, isTrue);
      },
    );
  });

  group('Broken structure is a FormatException', () {
    test('no components, or no base component', () {
      final Map<String, dynamic> empty = _json()..['components'] = <Object?>[];
      expect(() => _read(empty), _rejected);

      final Map<String, dynamic> oilOnly = _json();
      oilOnly['components'] = <Object?>[_component(oilOnly, 1)];
      expect(() => _read(oilOnly), _rejected);
    });

    test('two base components', () {
      final Map<String, dynamic> json = _json();
      final List<dynamic> components = json['components'] as List<dynamic>;
      components.add(jsonDecode(jsonEncode(components.first)));
      expect(() => _read(json), _rejected);
    });

    test('blank identifiers and names', () {
      final Map<String, dynamic> blankId = _json()..['id'] = '   ';
      expect(() => _read(blankId), _rejected);

      final Map<String, dynamic> blankMeal = _json()..['mealSlotId'] = '';
      expect(() => _read(blankMeal), _rejected);

      final Map<String, dynamic> blankName = _json();
      _component(blankName, 0)['foodName'] = ' ';
      expect(() => _read(blankName), _rejected);
    });

    test('an update time before the creation time', () {
      final Map<String, dynamic> json = _json()
        ..['updatedAt'] = '2000-01-01T00:00:00.000Z';
      expect(() => _read(json), _rejected);
    });

    test('a non-positive yield factor', () {
      final Map<String, dynamic> json = _json();
      _component(json, 1)['yieldFactorPermille'] = 0;
      expect(() => _read(json), _rejected);
    });

    test('errors in a single component can also be read directly', () {
      final Map<String, dynamic> json = _json();
      _component(json, 0)['quantityMilli'] = 0;
      expect(() => EntryComponent.fromJson(_component(json, 0)), _rejected);
    });
  });

  group('Existing rules are unchanged', () {
    test('wrong schema version, unknown or negative nutrients', () {
      final Map<String, dynamic> version = _json()..['schemaVersion'] = 99;
      expect(() => _read(version), _rejected);

      final Map<String, dynamic> unknown = _json();
      (_component(unknown, 0)['nutrients']
              as Map<String, dynamic>)['vitaminZ'] =
          1;
      expect(() => _read(unknown), _rejected);

      final Map<String, dynamic> negative = _json();
      (_component(negative, 0)['nutrients'] as Map<String, dynamic>)['energy'] =
          -5;
      expect(() => _read(negative), _rejected);
    });

    test('building an entry directly still reports ArgumentError', () {
      final LogEntry entry = _entry();
      expect(
        () => LogEntry(
          id: '  ',
          date: _day,
          mealSlotId: 'lunch',
          createdAt: _morning,
          updatedAt: _morning,
          components: entry.components,
        ),
        throwsArgumentError,
      );
      expect(
        () => LogEntry(
          id: 'x',
          date: _day,
          mealSlotId: 'lunch',
          createdAt: _morning,
          updatedAt: _morning,
          components: <EntryComponent>[],
        ),
        throwsArgumentError,
      );
    });
  });
}
