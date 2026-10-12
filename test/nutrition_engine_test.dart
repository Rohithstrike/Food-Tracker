import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/food/serving.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition_engine.dart';

// ALL NUMBERS IN THIS FILE ARE SAMPLE TEST VALUES.
// They are NOT real nutrition data for any food.

NutrientProfile sampleProfile({num? sugarG}) => NutrientProfile.per100g(
  energyKcal: 200,
  proteinG: 5,
  carbohydratesG: 40,
  fatG: 2,
  fibreG: 1.5,
  sugarG: sugarG, // Unknown unless given.
  sodiumMg: 300,
);

Food foodWith({
  String name = 'SAMPLE Food X',
  NutrientProfile? per100g,
  List<Serving> servings = const [],
  List<CookingVariant> variants = const [],
  DataStatus status = DataStatus.sample,
  FoodSource? source,
}) => Food(
  id: 'sample_x',
  name: name,
  category: FoodCategory.dish,
  region: FoodRegion.panIndian,
  per100g: per100g ?? sampleProfile(),
  servings: servings,
  variants: variants,
  status: status,
  source: source,
);

Food sampleFoodA() => Food(
  id: 'sample_a',
  name: 'SAMPLE Food A',
  aliases: const ['  Test   Alias  '],
  category: FoodCategory.snack,
  region: FoodRegion.southIndian,
  status: DataStatus.sample,
  per100g: sampleProfile(),
  servings: [
    Serving(
      id: 'piece',
      singularLabel: 'piece',
      pluralLabel: 'pieces',
      grams: 40,
      weightBasis: ServingWeightBasis.estimated,
    ),
    Serving(
      id: 'bowl',
      singularLabel: 'bowl',
      pluralLabel: 'bowls',
      grams: 150,
      weightBasis: ServingWeightBasis.estimated,
    ),
  ],
  variants: [
    CookingVariant(
      id: 'more_oil',
      label: 'More oil',
      factors: const {NutrientKind.fat: 1.5, NutrientKind.energy: 1.1},
      assumption:
          'SAMPLE assumption: more oil raises fat by 50% and energy by 10%.',
    ),
  ],
);

Food sampleFoodB() => Food(
  id: 'sample_b',
  name: 'SAMPLE Food B',
  category: FoodCategory.beverage,
  region: FoodRegion.panIndian,
  status: DataStatus.sample,
  per100g: NutrientProfile.per100g(
    energyKcal: 100,
    proteinG: 1,
    carbohydratesG: 20,
    fatG: 0,
    fibreG: 0,
    sugarG: 10,
    sodiumMg: 0,
  ),
);

CalculatedNutrition calc(
  Food food,
  String servingId,
  num quantity, {
  String? variantId,
}) => NutritionEngine.calculate(
  food: food,
  servingId: servingId,
  quantity: quantity,
  variantId: variantId,
);

Matcher throwsInput(NutritionInputError error) => throwsA(
  isA<NutritionInputException>().having((e) => e.error, 'error', error),
);

void main() {
  group('Calculation', () {
    test('100 g equals the per-100 g values', () {
      final r = calc(sampleFoodA(), Serving.gramId, 100);
      expect(
        r.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(200000),
      );
      expect(
        r.nutrients[NutrientKind.sodium],
        const NutrientAmount.milli(300000),
      );
      expect(r.totalMilligrams, 100000);
    });

    test('household unit: 2 pieces of 40 g', () {
      final r = calc(sampleFoodA(), 'piece', 2);
      expect(r.totalMilligrams, 80000);
      expect(
        r.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(160000),
      );
      expect(
        r.nutrients[NutrientKind.protein],
        const NutrientAmount.milli(4000),
      );
      expect(r.nutrients[NutrientKind.fibre], const NutrientAmount.milli(1200));
    });

    test('fractional household quantity: 1.5 bowls of 150 g', () {
      final r = calc(sampleFoodA(), 'bowl', 1.5);
      expect(r.totalMilligrams, 225000);
      expect(
        r.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(450000),
      );
      expect(r.nutrients[NutrientKind.fat], const NutrientAmount.milli(4500));
      expect(
        r.nutrients[NutrientKind.carbohydrates],
        const NutrientAmount.milli(90000),
      );
    });

    test('grams: 250 g', () {
      final r = calc(sampleFoodA(), Serving.gramId, 250);
      expect(
        r.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(500000),
      );
      expect(
        r.nutrients[NutrientKind.sodium],
        const NutrientAmount.milli(750000),
      );
    });

    test('cooking variant changes only the listed nutrients', () {
      final r = calc(sampleFoodA(), 'piece', 1, variantId: 'more_oil');
      expect(
        r.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(88000),
      );
      expect(r.nutrients[NutrientKind.fat], const NutrientAmount.milli(1200));
      expect(
        r.nutrients[NutrientKind.protein],
        const NutrientAmount.milli(2000),
      );
      expect(
        r.nutrients[NutrientKind.carbohydrates],
        const NutrientAmount.milli(16000),
      );
    });

    test('exact grams without a variant is not an estimate', () {
      final r = calc(sampleFoodA(), Serving.gramId, 100);
      expect(r.isEstimate, isFalse);
    });

    test('a variant makes the result an estimate and explains it', () {
      final r = calc(sampleFoodA(), Serving.gramId, 100, variantId: 'more_oil');
      expect(r.isEstimate, isTrue);
      expect(
        r.assumptions,
        contains(
          'SAMPLE assumption: more oil raises fat by 50% and energy by 10%.',
        ),
      );
    });

    test('an estimated serving weight is flagged', () {
      final r = calc(sampleFoodA(), 'piece', 1);
      expect(r.isEstimate, isTrue);
      expect(r.assumptions.any((a) => a.contains('estimated')), isTrue);
    });

    test('sample food results are labelled as sample data', () {
      final r = calc(sampleFoodA(), Serving.gramId, 100);
      expect(r.isSample, isTrue);
      expect(r.assumptions.any((a) => a.contains('Sample data')), isTrue);
    });
  });

  group('Unknown vs zero', () {
    test('an unknown nutrient stays unknown after scaling', () {
      final r = calc(sampleFoodA(), 'piece', 3);
      expect(r.nutrients[NutrientKind.sugar], isNull);
      expect(r.nutrients.unknownKinds, contains(NutrientKind.sugar));
    });

    test('a known zero stays a known zero', () {
      final r = calc(sampleFoodB(), Serving.gramId, 250);
      expect(r.nutrients[NutrientKind.fat], NutrientAmount.zero);
      expect(r.nutrients.isKnown(NutrientKind.fat), isTrue);
    });

    // Updated in Batch 1: micronutrient kinds were added. They are unknown
    // unless supplied, so the "exactly which kinds" check now applies to the
    // core seven, and unsupplied micronutrients must also be unknown.
    test('profile reports exactly which kinds are unknown', () {
      Set<NutrientKind> core(Set<NutrientKind> kinds) =>
          kinds.where((NutrientKind k) => k.isCore).toSet();
      expect(core(sampleProfile().unknownKinds), {NutrientKind.sugar});
      expect(core(sampleProfile(sugarG: 0).unknownKinds), isEmpty);
      expect(sampleProfile().unknownKinds, contains(NutrientKind.iron));
      expect(sampleProfile().isKnown(NutrientKind.iron), isFalse);
    });
  });

  group('Rounding', () {
    Food oneKcalFood() => foodWith(
      per100g: NutrientProfile.per100g(
        energyKcal: 1,
        proteinG: null,
        carbohydratesG: null,
        fatG: null,
        fibreG: null,
        sugarG: null,
        sodiumMg: null,
      ),
    );

    test('rounds once, half up, to 0.001 of the unit', () {
      // 1 kcal per 100 g x 0.15 g = 0.0015 kcal -> 0.002 kcal.
      expect(
        calc(
          oneKcalFood(),
          Serving.gramId,
          0.15,
        ).nutrients[NutrientKind.energy],
        const NutrientAmount.milli(2),
      );
      // 1 kcal per 100 g x 0.14 g = 0.0014 kcal -> 0.001 kcal.
      expect(
        calc(
          oneKcalFood(),
          Serving.gramId,
          0.14,
        ).nutrients[NutrientKind.energy],
        const NutrientAmount.milli(1),
      );
    });

    test('display rounding is half up', () {
      expect(const NutrientAmount.milli(1239500).toUnits(decimals: 0), 1240);
      expect(const NutrientAmount.milli(1239499).toUnits(decimals: 0), 1239);
      expect(const NutrientAmount.milli(1234449).toUnits(decimals: 1), 1234.4);
      expect(const NutrientAmount.milli(1234450).toUnits(decimals: 1), 1234.5);
      expect(() => NutrientAmount.zero.toUnits(decimals: 4), throwsRangeError);
    });

    test('large values stay exact (no overflow)', () {
      final big = foodWith(
        per100g: NutrientProfile.per100g(
          energyKcal: 900,
          proteinG: null,
          carbohydratesG: null,
          fatG: null,
          fibreG: null,
          sugarG: null,
          sodiumMg: null,
        ),
        variants: [
          CookingVariant(
            id: 'max',
            label: 'Max',
            factors: const {NutrientKind.energy: 5.0},
            assumption: 'SAMPLE upper-bound factor for testing.',
          ),
        ],
      );
      // 900 kcal/100 g x 5000 g x 5.0 = 225,000 kcal.
      final r = calc(big, Serving.gramId, 5000, variantId: 'max');
      expect(
        r.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(225000000),
      );
    });
  });

  group('Invalid input', () {
    test('zero, negative, NaN and infinite quantities are rejected', () {
      for (final q in <num>[0, -1, double.nan, double.infinity]) {
        expect(
          () => calc(sampleFoodA(), Serving.gramId, q),
          throwsInput(NutritionInputError.invalidQuantity),
          reason: 'quantity $q',
        );
      }
    });

    test('quantities below 0.001 are rejected', () {
      expect(
        () => calc(sampleFoodA(), Serving.gramId, 0.0004),
        throwsInput(NutritionInputError.invalidQuantity),
      );
    });

    test('quantity and total weight limits', () {
      expect(
        () => calc(sampleFoodA(), 'piece', 20000),
        throwsInput(NutritionInputError.quantityTooLarge),
      );
      expect(
        () => calc(sampleFoodA(), Serving.gramId, 6000),
        throwsInput(NutritionInputError.quantityTooLarge),
      );
      expect(() => calc(sampleFoodA(), Serving.gramId, 5000), returnsNormally);
    });

    test('unknown serving is rejected', () {
      expect(
        () => calc(sampleFoodA(), 'ladle', 1),
        throwsInput(NutritionInputError.unknownServing),
      );
    });

    test('unknown variant is rejected', () {
      expect(
        () => calc(sampleFoodA(), 'piece', 1, variantId: 'air_fried'),
        throwsInput(NutritionInputError.unknownVariant),
      );
    });
  });

  group('Validation', () {
    test('negative or invalid nutrient values are rejected', () {
      expect(() => NutrientAmount.of(-1), throwsArgumentError);
      expect(() => NutrientAmount.of(double.nan), throwsArgumentError);
    });

    test('serving weight must be positive, finite and at most 5 kg', () {
      for (final grams in <num>[0, -5, double.nan, 6000]) {
        expect(
          () => Serving(
            id: 'bad',
            singularLabel: 'bad',
            pluralLabel: 'bad',
            grams: grams,
            weightBasis: ServingWeightBasis.estimated,
          ),
          throwsArgumentError,
          reason: 'grams $grams',
        );
      }
    });

    test('the 1 g serving is built in and cannot be redefined', () {
      expect(sampleFoodA().servings.first.id, Serving.gramId);
      expect(() => foodWith(servings: [Serving.gram()]), throwsArgumentError);
    });

    test('duplicate serving ids are rejected', () {
      Serving cup() => Serving(
        id: 'cup',
        singularLabel: 'cup',
        pluralLabel: 'cups',
        grams: 200,
        weightBasis: ServingWeightBasis.estimated,
      );
      expect(() => foodWith(servings: [cup(), cup()]), throwsArgumentError);
    });

    test('verified foods require a source', () {
      expect(() => foodWith(status: DataStatus.verified), throwsArgumentError);
      expect(
        () => foodWith(
          status: DataStatus.verified,
          source: const FoodSource(citation: 'TEST citation only'),
        ),
        returnsNormally,
      );
    });

    test('variant factors and assumptions are validated', () {
      for (final factor in <num>[-0.5, 6]) {
        expect(
          () => CookingVariant(
            id: 'v',
            label: 'V',
            factors: {NutrientKind.fat: factor},
            assumption: 'SAMPLE',
          ),
          throwsArgumentError,
          reason: 'factor $factor',
        );
      }
      expect(
        () => CookingVariant(
          id: 'v',
          label: 'V',
          factors: const {NutrientKind.fat: 1.2},
          assumption: '  ',
        ),
        throwsArgumentError,
      );
    });

    test('food names must not be empty', () {
      expect(() => foodWith(name: '   '), throwsArgumentError);
    });

    test('serving labels use singular and plural', () {
      final piece = sampleFoodA().servingById('piece')!;
      expect(piece.labelFor(1), 'piece');
      expect(piece.labelFor(2), 'pieces');
    });

    test('search terms are normalised', () {
      expect(sampleFoodA().searchTerms, ['sample food a', 'test alias']);
    });
  });

  group('Totals', () {
    test('sums known values and counts missing ones', () {
      final totals = NutritionEngine.total([
        calc(sampleFoodA(), 'piece', 1), // Sugar unknown.
        calc(sampleFoodB(), Serving.gramId, 100), // Fat is a known zero.
      ]);
      expect(totals.itemCount, 2);
      expect(
        totals[NutrientKind.energy].amount,
        const NutrientAmount.milli(180000),
      );
      expect(totals[NutrientKind.energy].isComplete, isTrue);
      expect(totals[NutrientKind.fat].amount, const NutrientAmount.milli(800));
      expect(totals[NutrientKind.fat].isComplete, isTrue);
      expect(
        totals[NutrientKind.sugar].amount,
        const NutrientAmount.milli(10000),
      );
      expect(totals[NutrientKind.sugar].missingCount, 1);
      expect(totals.isComplete, isFalse);
      expect(totals.isSample, isTrue);
    });

    test('an empty day totals zero and is complete', () {
      final totals = NutritionEngine.total(const []);
      expect(totals.itemCount, 0);
      expect(totals[NutrientKind.energy].amount, NutrientAmount.zero);
      expect(totals.isComplete, isTrue);
      expect(totals.isSample, isFalse);
    });
  });
}
